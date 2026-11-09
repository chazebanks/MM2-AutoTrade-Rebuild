-- Stage88 ACTUAL Lua5.4 wrapper execution, mocked Roblox API.
-- REAL Stage87 contact eligibility, controller and Stage88 scanner presentation
-- are executed. The 63KB native scanner is mocked (Luau + external Roblox).
local PROBE="pdiddler/new_part4/STAGE88_CONTACT_READONLY_PREVIEW.lua"
local P3=os.getenv("STAGE88_P3_PINNED") or "/tmp/stage88/p3.lua"
local ELIG=os.getenv("STAGE88_ELIGIBILITY_PINNED") or "/tmp/stage88/outgoing_eligibility.lua"
local VIEW="pdiddler/presentation/pdiddler3_scanner_view_contact_v1.lua"
local KEY="GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW"
local failures=0
local groups=0
local now=1000
local function group(label,fn)
 local ok,why=pcall(fn)
 if not ok then error("STAGE88 "..label.." FAILED: "..tostring(why)) end
 groups=groups+1
 print("PASS "..label)
end
local function read(path)
 local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s
end
local rawView=read(VIEW)
local rawP3=read(P3)
local rawElig=read(ELIG)
local exports={}
local function runCase(mode)
 mode=mode or {}
 now=1000
 local clock=os.clock
 os={clock=function()return now end}
 local env={PDIDDLER_STAGE88_CONTACT_READONLY_ARMED=mode.armed~=false}
 local spool={}
 local sent={trade=0,accept=0,decline=0,teleport=0,requests=0,price=0,http=0}
 local summaries,states={},{}
 local clip=nil
 getgenv=function()return env end
 warn=function()end
 setclipboard=function(value)clip=value end
 local lp={UserId=42,Name="test_self"}
 local other={UserId=99,Name="test_other"}
 local players={LocalPlayer=lp}
 lp.Parent=players;other.Parent=players
 function players:GetPlayers()return {lp,other} end
 local gui={Enabled=true}
 function gui:FindFirstChild()return nil end
 function lp:FindFirstChildOfClass(n)assert(n=="PlayerGui");return gui end
 local profileInv={
  fingerprint="test_own_fp",unmapped=0,badQty=0,unpriced=1,
  items={{id="test_ours",type="Knife",cat="Weapons",page="godly",
   qty=1,checkerId="UNPRICED"}}
 }
 local targetInv={
  fingerprint="test_theirs_fp",unmapped=0,badQty=0,unpriced=1,
  items={{id="test_theirs",type="Gun",cat="Weapons",page="ancient",
   qty=1,checkerId="UNPRICED"}}
 }
 if mode.malformed then targetInv.items[1].qty=0 end
 local record={state="whitelist",player=other,inv=targetInv}
 local scanner={
  getVerificationState=function(id)
   assert(id==other.UserId)
   return {player=other,record=record,scanning=false,retryScheduled=false}
  end,
  getOwnInventory=function()return profileInv end,
  setOutgoingState=function(p,state,reason)
   assert(p==other)
   states[#states+1]={state=state,reason=reason}
   local view=dofile(VIEW)
   local rowState,detail=view.row(record,{state=state,reason=reason},nil,
    {version="STAGE88_NO_VERIFIED_QUOTE",isFresh=function()return false end},
    {reprice=function()error("real quote forbidden")end})
   assert(detail:find("Contact only:",1,true))
   assert(detail:find("PRICES UNVERIFIED",1,true))
   assert(detail:find("Total value: UNVERIFIED",1,true))
   return true
  end,
  setOutgoingSummary=function(counts)
   local view=dofile(VIEW)
   local line=view.summary(1,0,0,counts,{isFresh=function()return false end})
   assert(line:find("Contact candidates:",1,true))
   assert(line:find("PRICES UNVERIFIED",1,true))
   summaries[#summaries+1]=counts
  end
 }
 local fakeScannerCode="--mock scanner Luau, exercised separately\n"..string.rep("-",700)
 local gameObj={PlaceId=mode.wrongGame and 202 or 142823291,JobId="test_job"}
 function gameObj:IsLoaded()return true end
 local svc={Players=players,HttpService={
  JSONEncode=function(_,r)
   assert(r.currentPricesVerified==false)
   assert(r.authorizesTrade==false and r.authorizesAccept==false)
   assert(r.actualSendRequests==0 and r.actualOffers==0)
   assert(r.actualAccepts==0 and r.actualDeclines==0 and r.actualTeleports==0)
   for k,v in pairs(r) do
    for _,private in ipairs({"test_self","test_other","test_ours","test_theirs"}) do
     assert(not tostring(k):find(private,1,true))
     assert(not tostring(v):find(private,1,true))
    end
   end
   return '{"schema":"stage88-mock","status":"'..r.status..'"}'
  end
 }}
 function gameObj:GetService(name)return assert(svc[name]) end
 function gameObj:HttpGet(url)
  sent.http=sent.http+1
  assert(url:find("raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/",1,true))
  if mode.badSource then error("fake unavailable source") end
  if url:find("scanner_MODULE",1,true) then
   assert(url:find("7a289d62ef3f0be0a299506eb451c57435493be3",1,true))
   return fakeScannerCode
  elseif url:find("scanner_view_contact_v1",1,true) then
   assert(url:find("a00be9c54825b9b91fcfa394dc11d300fcce3575",1,true))
   return rawView
  elseif url:find("P3_ELIGIBILITY_NO_LEGACY_PROFIT",1,true) then
   assert(url:find("f1a0492ab5959f31be3544bf04ee8a514e09255f",1,true))
   return rawP3
  elseif url:find("outgoing_eligibility",1,true) then
   assert(url:find("f1a0492ab5959f31be3544bf04ee8a514e09255f",1,true))
   return rawElig
  end
  error("unexpected URL")
 end
 task={
  spawn=function(fn)spool[#spool+1]=fn end,
  wait=function(seconds)
   now=now+(seconds or 0.5)
   if mode.flipSession and now>1002 then gameObj.JobId="other_job" end
   if mode.tradeOpen and now>1001 then
    function gui:FindFirstChild(name)
     if name~="TradeGUI" then return nil end
     return {Enabled=true,FindFirstChild=function(_,key)
      if key=="Container" then
       return {FindFirstChild=function(_,name)
        if name=="Trade" then return {Visible=true} end
       end}
      end
     end}
    end
   end
  end
 }
 game=gameObj
 loadstring=function(src,name)
  if name=="=scanner" then
   assert(src==fakeScannerCode)
   return function(profile,strict,view)
    assert(profile.isFresh()==false)
    assert(strict.reprice()==nil)
    assert(type(view.row)=="function" and type(view.summary)=="function")
    return scanner
   end
  end
  return load(src,name)
 end
 if mode.oldOwner then env.PDIDDLER_OUTGOING_SESSION={active=true} end
 local ok,result=pcall(dofile,PROBE)
 assert(ok,result)
 if mode.armed==false or mode.wrongGame or mode.oldOwner then
  assert(result==nil and sent.http==0)
  return nil,sent,states,summaries,clip,env
 end
 assert(type(result)=="table" and result==env[KEY])
 for _,worker in ipairs(spool) do worker() end
 assert(result.report.readOnly==true)
 assert(result.report.authorizesTrade==false)
 assert(result.report.authorizesAccept==false)
 assert(result.report.mayReportProfit==false)
 assert(result.report.maySendDiscordWebhook==false)
 assert(result.report.serverCompletionProven==false)
 assert(result.report.actualSendRequests==0 and result.report.actualOffers==0)
 assert(result.report.actualTeleports==0 and result.report.actualAccepts==0)
 assert(result.report.currentPricesVerified==false)
 assert(result.report.sourcePublisherFresh==false)
 return result,sent,states,summaries,clip,env
end

group("unarmed wrapper does not fetch or mount scanner",function()
 runCase({armed=false})
end)
group("wrong game and existing owner cannot start",function()
 runCase({wrongGame=true})
 runCase({oldOwner=true})
end)
group("real stage87 stale-market contact path reaches and displays eligible player",function()
 local r,s,states,counts,clip=runCase()
 assert(r.report.status=="CLIENT_CONTACT_READINESS_OBSERVED",r.report.reason)
 assert(r.report.reachable==1 and r.report.unknown==0 and r.report.unprofitable==0)
 assert(r.report.ownContactEvidenceReady==true)
 assert(#states>0 and states[1].state=="reachable")
 assert(#counts>0 and counts[1].reachable==1)
 assert(s.http==4)
 assert(clip:find("[GINGERSCOPE STAGE88 CONTACT PREVIEW]",1,true))
end)
group("malformed target remains unknown and cannot be promoted to contact",function()
 local r,s,states=runCase({malformed=true})
 assert(r.report.status=="CLIENT_CONTACT_READINESS_OBSERVED")
 assert(r.report.reachable==0 and r.report.unknown==1)
 assert(#states>0 and states[1].state=="unknown")
end)
group("failed immutable source bootstrap cannot send request",function()
 local r,s=runCase({badSource=true})
 assert(r.report.status=="INCONCLUSIVE")
 assert(r.report.actualSendRequests==0 and s.http==1)
end)
group("job changed during observation holds, no stale contacts",function()
 local r,s=runCase({flipSession=true})
 assert(r.report.status=="HELD",r.report.status)
 assert(r.report.reason=="job-player-or-gui-changed")
end)
group("new visible trade GUI immediately holds same preview",function()
 local r,s=runCase({tradeOpen=true})
 assert(r.report.status=="HELD",r.report.reason)
 assert(r.report.reason=="trade-gui-active")
end)
group("attempted same-client rerun is refused without another fetch",function()
 local r,s,states,c,clip,env=runCase()
 local before=s.http
 local r2=dofile(PROBE)
 assert(r2==r and s.http==before)
end)
group("old price-age authorization remains FALSE in GUI and outcome",function()
 local r,s,states,counts=runCase()
 assert(r.report.status=="CLIENT_CONTACT_READINESS_OBSERVED")
 assert(r.report.sourcePublisherFresh==false and r.report.currentPricesVerified==false)
 assert(r.report.authenticatedOwnedInventory==false)
 assert(r.report.numericSupremeCheckerIdVerified==false)
 assert(r.report.mayUseForStrategyLearning==false)
end)
print("STAGE88_NATIVE_WRAPPER_LUA_PASS groups="..groups)
