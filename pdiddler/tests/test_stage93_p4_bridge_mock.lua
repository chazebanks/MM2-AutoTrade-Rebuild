-- Stage93: execute the ACTUAL one-request native wrapper under fake Roblox.
-- The original 63KB scanner is mocked, actual Stage87 P3/controller loaded.
-- No real MM2 remote or online game access.
local SOURCE="pdiddler/new_part4/STAGE93_P4_OFFER_OBSERVER_BRIDGE.lua"
local P3=os.getenv("STAGE93_PINNED_P3") or "/tmp/stage93/p3.lua"
local CONTROLLER=os.getenv("STAGE93_PINNED_CONTROLLER") or "/tmp/stage93/controller.lua"
local VIEW=os.getenv("STAGE93_PINNED_VIEW") or "/tmp/stage93/view.lua"
local KEY="GINGERSCOPE_STAGE93_SINGLE_REQUEST_DIAGNOSTIC"
local groups=0
local function group(name,fn)
 local ok,e=pcall(fn)
 if not ok then error("FAIL "..name.." "..tostring(e)) end
 groups=groups+1
 print("PASS "..name)
end
local function read(file)
 local f=assert(io.open(file,"rb"))
 local s=f:read("*a");f:close();return s
end
local textP3=read(P3)
local textController=read(CONTROLLER)
local textView=read(VIEW)
local textP4contract=read(os.getenv("STAGE93_PINNED_P4CONTRACT") or "/tmp/stage93/p4contract.lua")
local textP4native=read(os.getenv("STAGE93_PINNED_P4NATIVE") or "/tmp/stage93/p4native.lua")
local function scenario(mode)
 mode=mode or {}
 local elapsed=5000
 local function node(kind,name,parent)
  local n={ClassName=kind,Name=name,Parent=parent,Visible=true,Enabled=true,children={},order={}}
  function n:IsA(value)
   if value==self.ClassName then return true end
   if value=="GuiObject" then
    return self.ClassName=="Frame" or self.ClassName=="TextLabel"
      or self.ClassName=="TextButton"
   end
   if value=="GuiButton" then return self.ClassName=="TextButton" end
   return false
  end
  function n:FindFirstChild(child) return self.children[child] end
  function n:GetAttribute(k)return nil end
  function n:GetChildren()return self.order end
  function n:GetDescendants()
   local out={}
   local function visit(o)
    for _,c in ipairs(o.order) do out[#out+1]=c;visit(c) end
   end
   visit(self)
   return out
  end
  if parent then
   parent.children[name]=n
   parent.order[#parent.order+1]=n
  end
  return n
 end
 local env={PDIDDLER_STAGE93_ONE_REQUEST_ARMED=mode.armed~=false,
            PDIDDLER_STAGE93_TARGET_USERNAME=mode.user or "test_partner"}
 if mode.owner then env.PDIDDLER_OUTGOING_CONTROLLER={} end
 if mode.oldStage89 then env.GINGERSCOPE_STAGE89_SINGLE_REQUEST_DIAGNOSTIC={} end
 if mode.oldStage90 then env.GINGERSCOPE_STAGE90_CARD_LAYOUT_AUDIT={} end
 if mode.oldStage91 then env.GINGERSCOPE_STAGE91_SINGLE_REQUEST_DIAGNOSTIC={} end
 if mode.oldStage92 then env.GINGERSCOPE_STAGE92_SINGLE_REQUEST_DIAGNOSTIC={} end
 _G.getgenv=function()return env end
 _G.warn=function(v)env.lastWarning=tostring(v) end
 _G.setclipboard=function(s)env.clipboard=s end
 _G.os.clock=function()return elapsed end
 local playerList={}
 local players={Name="Players"}
 function players:IsA(v)return v=="Players" end
 local lp={Name="test_self",UserId=1,Parent=players}
 function lp:IsA(v)return v=="Player" end
 players.LocalPlayer=lp
 local target={Name=mode.actualTargetName or "test_partner",UserId=2,Parent=players}
 function players:GetPlayers()
  if mode.ambiguousName then
   local other={Name=target.Name:upper(),UserId=3,Parent=players}
   function other:IsA(k)return k=="Player" end
   return {lp,target,other}
  end
  return {lp,target}
 end
 function lp:FindFirstChildOfClass(k)
  assert(k=="PlayerGui")
  return self.gui
 end
 function target:IsA(k) return k=="Player" end
 function players:FindFirstChild(name)
  if name==target.Name then return target end
  return nil
 end
 function players:GetPlayerByUserId(uid)
  if mode.targetReplace then return {Name=target.Name,UserId=2,Parent=players} end
  if uid==target.UserId and target.Parent==players then return target end
  return nil
 end
 local pg=node("PlayerGui","PlayerGui",nil);pg.Parent=lp;lp.gui=pg
 local screen=node("ScreenGui","MM2Gui",pg)
 local gameBranch=node("Frame","Game",screen)
 local board=node("Frame","Leaderboard",gameBranch)
 local cont=node("Frame","Container",board)
 local request=node("Frame","TradeRequest",cont)
 local popup=node("Frame","Popup",board)
 local pcont=node("Frame","Container",popup)
 local username=node("TextLabel","Username",pcont)
 username.Text=mode.wrongHeader and "wrong_person" or target.Name
 local action=node("Frame","Action",pcont)
 local button=node("TextButton","Trade",action)
 button.Text="Trade";button.AbsolutePosition={X=120,Y=240}
 button.AbsoluteSize={X=80,Y=35}
 if mode.alternativeCard then
  popup.Visible=false
  local card=node("Frame","SelectedPlayerCard",board)
  local controls=node("Frame","SelectedCardControls",card)
  local pbtn=node("TextButton","Profile",controls)
  pbtn.Text="Profile"
  local b=node("TextButton","Trade",controls)
  b.Text="Trade";b.AbsolutePosition={X=120,Y=240}
  b.AbsoluteSize={X=80,Y=35}
  button=b
  local headerParent=mode.siblingOutside and board or controls
  local header=node("TextLabel","CardUsername",headerParent)
  header.Text=mode.altWrongUser and "wrong_person" or target.Name
  header.AbsolutePosition={X=125,Y=165}
  header.AbsoluteSize={X=100,Y=25}
  if mode.headerFar then header.AbsolutePosition={X=600,Y=450} end
  if mode.alternativeHidden then card.Visible=false end
  if mode.alternativeExtraTrade then
   local another=node("TextButton","AnotherTrade",card)
   another.Text="Trade"
  end
 end
 if mode.noCard then popup.Visible=false end
 if mode.preexistingPending then
  local s=node("Frame","SendingRequest",request)
  local u=node("TextLabel","Username",s);u.Text="test_partner"
 end
 if mode.preexistingIncoming then node("Frame","ReceivingRequest",request) end
 local targetReceived=false
 local summary={remoteInvocations=0,mouseDown=0,mouseUp=0,sourceFetches=0,
                noActions=true}
 local tradeGui=nil
 local tradeLabel=nil
 local tradeCreatedAt=nil
 local addedOffer=false
 local mutatedOwn=false
 local theirOfferContainer=nil
 local ourOfferContainer=nil
 local function spawnTradeWindow()
  if tradeGui then return end
  tradeGui=node("ScreenGui","TradeGUI_Phone",pg)
  tradeCreatedAt=elapsed
  local c=node("Frame","Container",tradeGui)
  local tr=node("Frame","Trade",c)
  local their=node("Frame","TheirOffer",tr)
  theirOfferContainer=node("Frame","Container",their)
  local ours=node("Frame","YourOffer",tr)
  ourOfferContainer=node("Frame","Container",ours)
  tradeLabel=node("TextLabel","Username",their)
  tradeLabel.Text=mode.tradePartnerWrong and "another_player"
   or mode.tradePartnerBlank and "" or "("..target.Name..")"
  if mode.tradeHeaderMissing then
   tradeLabel.Visible=false
  end
  if mode.doubleTradeGui then
   local g2=node("ScreenGui","TradeGUI",pg)
   local co=node("Frame","Container",g2)
   node("Frame","Trade",co)
  end
 end
 local fakeScanner={}
 local ourInventory={fingerprint="test_own_fp",unmapped=0,badQty=0,unpriced=1,
  items={{id="test_ours",type="Knife",cat="Weapons",page="godly",qty=1}}}
 local theirInv={fingerprint="test_their_fp",unmapped=0,badQty=0,unpriced=1,
  items={{id="test_theirs",type="Gun",cat="Weapons",page="ancient",qty=1}}}
 if mode.invalidInventory then theirInv.items[1].qty=0 end
 fakeScanner.getOwnInventory=function()
  summary.remoteInvocations=summary.remoteInvocations+1
  return ourInventory
 end
 fakeScanner.setOutgoingState=function()return true end
 fakeScanner.getVerificationState=function(uid)
  assert(uid==target.UserId)
  return {player=target,record={player=target,state="whitelist",inv=theirInv},
   scanning=false,retryScheduled=false}
 end
 local fakeScannerContent="-- original game scanner unavailable in Lua5.4\n"..string.rep("-",1000)
 local gameObj={PlaceId=mode.wrongPlace and 1 or 142823291,JobId="job_test"}
 function gameObj:IsLoaded()return true end
 local virtualInput={}
 function virtualInput:SendMouseButtonEvent(x,y,buttonIndex,pressed,gameArg,flags)
  assert(buttonIndex==0 and gameArg==gameObj and flags==0)
  assert(x==172 and y==281.5,"GUI inset must be applied for tablet input")
  if pressed then
   summary.mouseDown=summary.mouseDown+1
   if mode.failDown then error("mock input error after dispatch") end
   if mode.pendingAfterTap~=false then
    local send=node("Frame","SendingRequest",request)
    local u=node("TextLabel","Username",send);u.Text=target.Name
   end
  else
   summary.mouseUp=summary.mouseUp+1
   if mode.failUp then error("mock release error") end
  end
 end
 local httpService={}
 function httpService:JSONEncode(data)
  assert(data.authorizesAccept==false and data.authorizesTrade==false)
  assert(data.currentPricesVerified==false)
  assert(data.serverCompletionProven==false and data.tradeOutcome=="UNKNOWN")
  assert(data.actualAccepts==0 and data.actualOffers==0)
  assert(data.actualAccepts==0 and data.actualOffers==0
      and data.actualDeclines==0 and data.actualTeleports==0)
  for key,value in pairs(data) do
   assert(not tostring(key):find(target.Name,1,true))
   assert(not tostring(value):find(target.Name,1,true))
  end
  return '{"stage":"89","status":"'..data.status..'"}'
 end
 local guiService={
  GetGuiInset=function()
   if mode.noGuiInset then error("native inset missing") end
   return {X=12,Y=24}
  end
 }
 local services={Players=players,VirtualInputManager=virtualInput,
                 GuiService=guiService,HttpService=httpService}
 function gameObj:GetService(name)
  return assert(services[name],"unexpected game service "..name)
 end
 function gameObj:HttpGet(url)
  summary.sourceFetches=summary.sourceFetches+1
  assert(url:find("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/",1,true)==1)
  if mode.sourceFailure then error("mock source download") end
  if url:find("scanner_MODULE",1,true) then
   assert(url:find("7a289d62ef3f0be0a299506eb451c57435493be3",1,true))
   return fakeScannerContent
  elseif url:find("scanner_view_contact_v1",1,true) then
   assert(url:find("a00be9c54825b9b91fcfa394dc11d300fcce3575",1,true))
   return textView
  elseif url:find("P3_ELIGIBILITY_NO_LEGACY_PROFIT",1,true) then
   assert(url:find("f1a0492ab5959f31be3544bf04ee8a514e09255f",1,true))
   return textP3
  elseif url:find("p4_observer_contract.lua",1,true) then
   assert(url:find("1971b93d324f0275e6a9affb472ac3e804439ed8",1,true))
   return textP4contract
  elseif url:find("p4_native_observer.lua",1,true) then
   assert(url:find("1971b93d324f0275e6a9affb472ac3e804439ed8",1,true))
   return textP4native
  elseif url:find("outgoing_eligibility",1,true) then
   assert(url:find("f1a0492ab5959f31be3544bf04ee8a514e09255f",1,true))
   return textController
  end
  error("unreviewed dependency")
 end
 _G.game=gameObj
 _G.loadstring=function(s,name)
  if name=="=stage93-scanner" then
   assert(s==fakeScannerContent)
   return function(profile,strict,view)
    assert(profile.isFresh()==false)
    assert(strict.reprice()==nil)
    assert(type(view.row)=="function")
    return fakeScanner
   end
  end
  return load(s,name)
 end
 _G.task={
  spawn=function(fn)fn()end,
  wait=function(dt)
   elapsed=elapsed+(dt or 0.1)
   if mode.sessionChange and elapsed>5002 then gameObj.JobId="new_job" end
   if mode.tradeAfterRequest and summary.mouseDown>0 and elapsed>5003.5 then spawnTradeWindow() end
   if mode.altOfferChange and tradeCreatedAt and not addedOffer
      and elapsed>tradeCreatedAt+1 then
    addedOffer=true
    local slot=node("Frame","NewItem1",theirOfferContainer)
    local nm=node("Frame","ItemName",slot)
    local label=node("TextLabel","Label",nm);label.Text="Mock Test Weapon"
    local ct=node("Frame","Container",slot)
    local amount=node("TextLabel","Amount",ct);amount.Text=""
   end
   if mode.ourOfferChange and tradeCreatedAt and not mutatedOwn
      and elapsed>tradeCreatedAt+1 then
    mutatedOwn=true
    local slot=node("Frame","NewItem1",ourOfferContainer)
    local nm=node("Frame","ItemName",slot)
    local label=node("TextLabel","Label",nm);label.Text="Mock Own Weapon"
    local ct=node("Frame","Container",slot)
    local amount=node("TextLabel","Amount",ct);amount.Text=""
   end
  end
 }
 local ok,r=pcall(dofile,SOURCE)
 assert(ok,r)
 return r,summary,env,target,request
end
local function safe(r,s)
 if r then
  assert(r.report.authorizesTrade==false and r.report.authorizesAccept==false)
  assert(r.report.mayReportProfit==false and r.report.maySendDiscordWebhook==false)
  assert(r.report.currentPricesVerified==false)
  assert(r.report.itemIdentityVerified==false and r.report.marketPricesVerified==false)
  assert(r.report.cardLayout=="UNVERIFIED" or r.report.cardLayout=="DIRECT_POPUP" or r.report.cardLayout=="ALTERNATIVE_EMBEDDED_CARD")
  assert(r.report.actualOffers==0 and r.report.actualAccepts==0)
  assert(r.report.actualDeclines==0 and r.report.actualTeleports==0)
 end
 assert(s.mouseDown<=1,"more than one physical request tap")
 assert(s.mouseUp<=1,"more than one release")
end
group("not armed, wrong game and owner block before download",function()
 for _,m in ipairs({{armed=false},{wrongPlace=true},{owner=true},{oldStage89=true},{oldStage90=true},{oldStage91=true},{oldStage92=true}}) do
  local r,s=scenario(m)
  assert(r==nil and s.sourceFetches==0 and s.mouseDown==0)
  safe(r,s)
 end
end)
group("real Stage87 partner and own candidate + exact manual card gives ONE request",function()
 local r,s,e=scenario({})
 assert(r.report.status=="CLIENT_PENDING_ONLY_NO_TRADE",r.report.reason.." | "..tostring(e.lastWarning))
 assert(r.report.requestTapCount==1 and s.mouseDown==1 and s.mouseUp==1)
 assert(r.report.clientPendingExactTargetObserved==true)
 assert(r.report.exactTargetClientBound==true)
 assert(r.report.visibleCardExactNameMatched==true)
 assert(r.report.cardLayout=="DIRECT_POPUP")
 assert(r.report.ownContactEvidenceReady==true)
 assert(e.clipboard:find("[GINGERSCOPE STAGE93 SINGLE REQUEST]",1,true))
 safe(r,s)
end)
group("Stage90 observed embedded card: exact username + one paired Trade button yields one attempt",function()
 local r,s=scenario({alternativeCard=true})
 assert(r.report.status=="CLIENT_PENDING_ONLY_NO_TRADE",r.report.reason)
 assert(r.report.cardLayout=="ALTERNATIVE_EMBEDDED_CARD")
 assert(r.report.requestTapCount==1 and s.mouseDown==1 and s.mouseUp==1)
 safe(r,s)
end)
group("embedded-card fail-closed: wrong exact username, unrelated board row, hidden, distant or second Trade control",function()
 for _,m in ipairs({
  {alternativeCard=true,altWrongUser=true},
  {alternativeCard=true,siblingOutside=true},
  {alternativeCard=true,alternativeHidden=true},
  {alternativeCard=true,headerFar=true},
  {alternativeCard=true,alternativeExtraTrade=true},
 }) do
  local r,s=scenario(m)
  assert(r.report.status=="INCONCLUSIVE",r.report.reason)
  assert(r.report.requestTapCount==0 and s.mouseDown==0)
  safe(r,s)
 end
end)
group("Stage93 native-looking request to exact matching trade GUI remains observer-only",function()
 local r,s=scenario({alternativeCard=true,tradeAfterRequest=true})
 assert(r.report.status=="CLIENT_P4_OBSERVER_BOUND_NO_OFFER_CHANGE",r.report.reason)
 assert(r.report.cardLayout=="ALTERNATIVE_EMBEDDED_CARD")
 assert(r.report.exactPartnerTradeGuiObserved==true and r.report.tradeWindowObserved==true)
 assert(r.report.stage9ObserverBound==true and r.report.stage9Frames>=1)
 assert(r.report.requestTapCount==1 and s.mouseDown==1 and s.mouseUp==1)
 assert(r.report.authorizesTrade==false and r.report.authorizesAccept==false)
 safe(r,s)
end)
group("wrong partner and ambiguous trade GUI never report exact target",function()
 for _,m in ipairs({
  {alternativeCard=true,tradeAfterRequest=true,tradePartnerWrong=true},
  {alternativeCard=true,tradeAfterRequest=true,doubleTradeGui=true},
 }) do
  local r,s=scenario(m)
  assert(r.report.status=="INCONCLUSIVE")
  assert(r.report.exactPartnerTradeGuiObserved==false)
  assert(r.report.requestTapCount==1 and s.mouseDown==1)
  safe(r,s)
 end
end)
group("unverified or missing partner header remains inconclusive and no action",function()
 for _,m in ipairs({
  {alternativeCard=true,tradeAfterRequest=true,tradePartnerBlank=true},
  {alternativeCard=true,tradeAfterRequest=true,tradeHeaderMissing=true},
 }) do
  local r,s=scenario(m)
  assert(r.report.status=="INCONCLUSIVE")
  assert(r.report.tradeWindowObserved==true)
  assert(r.report.unverifiedPartnerHeaderObserved==true)
  assert(r.report.exactPartnerTradeGuiObserved==false)
  safe(r,s)
 end
end)

group("Stage93 bridge uses original Stage9 capture to detect only alt GUI offer change",function()
 local r,s=scenario({alternativeCard=true,tradeAfterRequest=true,altOfferChange=true})
 assert(r.report.status=="CLIENT_P4_GUI_OFFER_MUTATION_OBSERVED",r.report.reason)
 assert(r.report.exactPartnerTradeGuiObserved==true)
 assert(r.report.stage9ObserverBound==true and r.report.stage9Frames>=2)
 assert(r.report.theirGuiOfferMutationObserved==true)
 assert(r.report.theirGuiOfferAddObserved==true)
 assert(r.report.ourGuiOfferStayedUnchanged==true)
 assert(r.report.itemIdentityVerified==false and r.report.marketPricesVerified==false)
 assert(r.report.requestTapCount==1 and s.mouseDown==1 and s.mouseUp==1)
 safe(r,s)
end)
group("Stage93 rejects unexpected own GUI offer mutation without any scripted offer",function()
 local r,s=scenario({alternativeCard=true,tradeAfterRequest=true,ourOfferChange=true})
 assert(r.report.status=="INCONCLUSIVE",r.report.reason)
 assert(r.report.reason=="OUR_GUI_OFFER_CHANGED_UNEXPECTEDLY")
 assert(r.report.ourGuiOfferStayedUnchanged==false)
 assert(r.report.actualOffers==0 and r.report.actualAccepts==0)
 safe(r,s)
end)
group("capitalization variants still bind unique exact Roblox username",function()
 local r,s=scenario({user="TEST_PARTNER"})
 assert(r.report.status=="CLIENT_PENDING_ONLY_NO_TRADE" and s.mouseDown==1)
 safe(r,s)
 local r2,s2=scenario({user="TestCaseAlias90190",actualTargetName="testcasealias90190"})
 assert(r2.report.status=="CLIENT_PENDING_ONLY_NO_TRADE" and s2.mouseDown==1)
 safe(r2,s2)
end)
group("wrong username and ambiguous folded username never tap",function()
 local r,s=scenario({user="not_the_target"})
 assert(r.report.status=="HELD" and s.mouseDown==0)
 safe(r,s)
 local r2,s2=scenario({ambiguousName=true})
 assert(r2.report.status=="HELD" and s2.mouseDown==0)
 safe(r2,s2)
end)
group("GUI inset unavailable blocks before any physical Trade tap",function()
 local r,s=scenario({noGuiInset=true})
 assert(r.report.status=="HELD" and r.report.reason=="GUI_INSET_UNAVAILABLE")
 assert(r.report.requestTapCount==0 and s.mouseDown==0)
 safe(r,s)
end)
group("no pending confirmation never causes a second click",function()
 local r,s=scenario({pendingAfterTap=false})
 assert(r.report.status=="UNCERTAIN")
 assert(r.report.requestTapCount==1)
 assert(s.mouseDown==1 and s.mouseUp==1)
 safe(r,s)
end)
group("uncertain down dispatch or release never retried",function()
 local r,s=scenario({failDown=true})
 assert(r.report.status=="UNCERTAIN")
 assert(s.mouseDown==1 and s.mouseUp==0)
 r,s=scenario({failUp=true})
 assert(r.report.status=="UNCERTAIN" and s.mouseDown==1 and s.mouseUp==1)
 safe(r,s)
end)
group("operator must open exact target card, no wrong person tap",function()
 local r,s=scenario({wrongHeader=true})
 assert(r.report.status=="INCONCLUSIVE" and s.mouseDown==0)
 r,s=scenario({noCard=true})
 assert(r.report.status=="INCONCLUSIVE" and s.mouseDown==0)
 safe(r,s)
end)
group("preexisting incoming or pending requests strictly block",function()
 for _,m in ipairs({{preexistingIncoming=true},{preexistingPending=true}}) do
  local r,s=scenario(m)
  assert(r.report.status=="HELD" and s.mouseDown==0)
  safe(r,s)
 end
end)
group("malformed target inventory does not grant send permit",function()
 local r,s=scenario({invalidInventory=true})
 assert(r.report.status=="INCONCLUSIVE" and s.mouseDown==0)
 safe(r,s)
end)
group("game job change during readiness denies tap",function()
 local r,s=scenario({sessionChange=true,invalidInventory=true})
 assert(r.report.status=="HELD" and s.mouseDown==0)
 safe(r,s)
end)
group("server player object changed fails exact identity before dispatch",function()
 local r,s=scenario({targetReplace=true})
 assert(r.report.status=="HELD" and s.mouseDown==0)
 safe(r,s)
end)
group("source fetch failure fails closed with no physical input",function()
 local r,s=scenario({sourceFailure=true})
 assert(r.report.status=="INCONCLUSIVE" and s.mouseDown==0)
 safe(r,s)
end)
group("same client session cannot send a second request",function()
 local r,s,e=scenario({})
 local before=s.mouseDown
 local nextResult=dofile(SOURCE)
 assert(nextResult==r and s.mouseDown==before)
 safe(r,s)
end)
print("STAGE93_ACTUAL_WRAPPER_MOCK_PASS groups="..groups)
