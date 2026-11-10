-- Execute the ACTUAL supervised P3/P4 handoff and ACTUAL guarded P4 TradeIO.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local tests=0
local function eq(x,w,tag)
 tests+=1
 assert(x==w,tostring(tag)..": "..tostring(x).." != "..tostring(w))
end
local function node(class,name)
 local x={ClassName=class,Name=name,Visible=true,Enabled=true,
   Text="",children={},attributes={}}
 function x:IsA(k)
  return k==self.ClassName or
   (k=="GuiObject" and (class=="Frame" or
    class=="TextLabel" or class=="TextButton"))
 end
 function x:FindFirstChild(k)return self.children[k]end
 function x:GetDescendants()return {}end
 function x:GetAttribute(k)return self.attributes[k] end
 function x:GetFullName()return self.Name end
 function x:put(item)
  item.Parent=self
  self.children[item.Name]=item
  return item
 end
 return x
end
local function fixture()
 local players={}
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 local container=screen:put(node("Frame","Container"))
 local trade=container:put(node("Frame","Trade"))
 local a=trade:put(node("Frame","YourOffer"))
 local own=a:put(node("Frame","Container"))
 local ownAccepted=a:put(node("Frame","Accepted"))
 ownAccepted.Visible=false
 local b=trade:put(node("Frame","TheirOffer"))
 local their=b:put(node("Frame","Container"))
 local theirAccepted=b:put(node("Frame","Accepted"))
 theirAccepted.Visible=false
 local name=b:put(node("TextLabel","Username"))
 name.Text="TrustedAlt"
 local lp={Name="MainAccount",UserId=1,Parent=players}
 players.LocalPlayer=lp
 local p={Name="TrustedAlt",DisplayName="Alt",UserId=2,Parent=players}
 function players:FindFirstChild(k)
  if k==p.Name and p.Parent==players then return p end
 end
 function lp:FindFirstChildOfClass(kind)
  if kind=="PlayerGui" then return pg end
 end
 local sends={}
 local remote=node("RemoteEvent","OfferItem")
 function remote:FireServer(raw,cat)
  sends[#sends+1]={raw,cat}
 end
 local folder=node("Folder","Trade")
 folder:put(remote)
 local replicated=node("ReplicatedStorage","ReplicatedStorage")
 replicated:put(folder)
 local service={Players=players,ReplicatedStorage=replicated,
    VirtualInputManager={},GuiService={}}
 local game={
  GetService=function(_,k)return service[k] end,
 }
 local env={game=game,task={wait=function()end}}
 local module=luau.load(handoffText,{environment=env,injectGlobals=true})()
 local iomod=luau.load(ioText,{environment=env,injectGlobals=true})()
 local gate={}
 local io=iomod.new({resolveOfferEntry=function()return nil end},gate)
 local scanner={state="whitelist",object=p}
 function scanner.isWhitelisted(uid)
  return uid==2 and scanner.state=="whitelist"
 end
 function scanner.getRecord(uid)
  if uid==2 then return {state=scanner.state,player=scanner.object}end
 end
 local outgoing={session=18,paused=true,resumed=0}
 function outgoing.isPaused() return outgoing.paused end
 function outgoing.resume(reason)
  outgoing.resumed+=1
  if screen.Enabled then return false,"still-open" end
  outgoing.paused=false
  return true,"resumed"
 end
 local ctx={targetName="TrustedAlt",job="Job-A",epoch=18}
 ctx.getJobId=function()return ctx.job end
 ctx.getP3Session=function()return ctx.epoch end
 local function add(root,i,key,qty,chroma,emptyLabel)
  local slot=root:put(node("Frame","NewItem"..i))
  local itemName=slot:put(node("Frame","ItemName"))
  if not emptyLabel then
   local label=itemName:put(node("TextLabel","Label"))
   label.Text=key
  end
  local c=slot:put(node("Frame","Container"))
  local q=c:put(node("TextLabel","Amount"))
  q.Text="x"..tostring(qty or 1)
  if chroma then
   local tags=slot:put(node("Frame","Tags"))
   tags:put(node("Frame","Chroma"))
  end
  return slot
 end
 return {module=module,io=io,p3=outgoing,scanner=scanner,
    ctx=ctx,players=players,lp=lp,p=p,pg=pg,screen=screen,
    trade=trade,ours=own,theirs=their,ownAccepted=ownAccepted,
    theirAccepted=theirAccepted,name=name,add=add,sends=sends}
end
local f=fixture()
local bound,reason=f.module.bind(f.scanner,f.p3,f.io,f.players,f.lp,f.ctx)
eq(type(bound),"table","valid P3/P4 live binding")
eq(reason,nil,"no bind error")
local empty=bound.capture()
eq(empty.status,"CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT","live empty two-sided read")
eq(empty.physicalOwnSlots,0,"empty physical own")
eq(empty.physicalTheirSlots,0,"empty physical their")
eq(empty.authorizesOffer,false,"never auto offer")
eq(empty.authorizesAccept,false,"never auto accept")
eq(empty.pricesAuthenticated,false,"no stale prices elevated")
eq(empty.requestOriginBound,false,"P3 request origin not authenticated")
eq(empty.tradeOutcome,"UNKNOWN","unknown settlement")
eq(#f.sends,0,"does not fire remote")
f.add(f.ours,1,"Iceblaster",5)
f.add(f.theirs,1,"Emberbow",6)
local stacked=bound.capture()
eq(stacked.status,"CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT","real I/O stacked snapshot")
eq(stacked.physicalOwnSlots,1,"5 copies are ONE physical slot")
eq(stacked.physicalTheirSlots,1,"6 copies are ONE physical slot")
eq(stacked.ours[1].quantity,5,"own stacked qty")
eq(stacked.theirs[1].quantity,6,"their stacked qty")
eq(stacked.ours[1].rawItemIdAuthenticated,false,"GUI label is not verified raw ID")
eq(#f.sends,0,"still no remote")
for _,case in ipairs({
 {"wrong partner",function(x)x.name.Text="WrongPerson"end,"TRADE_PARTNER_WRONG_OR_AMBIGUOUS"},
 {"not paused",function(x)x.p3.paused=false end,"PART3_NOT_PAUSED"},
 {"not whitelist",function(x)x.scanner.state="blacklist"end,"PART3_CONTACT_NOT_ELIGIBLE"},
 {"scanner wrong actor",function(x)x.scanner.object={}end,"PART3_SCANNER_RECORD_CHANGED"},
 {"P3 epoch changed",function(x)x.ctx.epoch=19 end,"JOB_OR_EPOCH_CHANGED"},
 {"job changed",function(x)x.ctx.job="Job-B" end,"JOB_OR_EPOCH_CHANGED"},
 {"hidden trade",function(x)x.trade.Visible=false end,"NO_VISIBLE_TRADE"},
 {"already accepted ours",function(x)x.ownAccepted.Visible=true end,"ACCEPT_ALREADY_SET"},
 {"already accepted theirs",function(x)x.theirAccepted.Visible=true end,"ACCEPT_ALREADY_SET"},
 {"their accept missing",function(x)
      x.trade.children.TheirOffer.children.Accepted=nil
    end,"ACCEPT_UNKNOWN"},
 {"unlabeled visible physical",function(x)x.add(x.ours,1,"Unknown",1,false,true)
    end,"PHYSICAL_GUI_SLOTS_NOT_RECONCILED"},
 {"5th physical",function(x)x.add(x.ours,5,"Another",1)
    end,"MORE_THAN_FOUR_PHYSICAL_SLOTS"},
 {"own protected asset",function(x)x.add(x.ours,1,"Gingerscope",1)
    end,"PROTECTED_GINGERSCOPE_IN_OWN_OFFER"},
 {"invalid stack",function(x)x.add(x.ours,1,"Iceblaster",1000001)
    end,"INVALID_GUI_SLOT_OR_STACK"},
}) do
 local x=fixture()
 local b,why=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 if not b then eq(why.status,"REJECTED","early reject "..case[1])
 else
  case[2](x)
  local r=b.capture()
  eq(r.status,"REJECTED","reject "..case[1])
  eq(r.reason,case[3],"precise block "..case[1])
  eq(r.authorizesAccept,false,"no accept "..case[1])
  eq(#x.sends,0,"no offer "..case[1])
 end
end
-- Wrong partner on the INITIAL bind must also block.
do
 local x=fixture()
 x.name.Text="OtherAccount"
 local b,r=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 eq(b,nil,"not bound wrong partner")
 eq(r.reason,"TRADE_PARTNER_WRONG_OR_AMBIGUOUS","wrong-partner initial gate")
end
-- Only P3 resume AFTER trade closes; no stale-session resume.
do
 local x=fixture()
 local b=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 local ok,why=b.resumeAfterClose()
 eq(ok,false,"never resume while trade open")
 eq(why,"TRADE_STILL_OPEN","trade still open")
 x.screen.Enabled=false
 ok,why=b.resumeAfterClose()
 eq(ok,true,"resume after trade close")
 eq(why,"P3_RESUMED_CLIENT_ONLY","resume status")
 eq(x.p3.resumed,1,"one P3 resume call")
 ok,why=b.resumeAfterClose()
 eq(ok,false,"never double resume")
 eq(x.p3.resumed,1,"still only one resume")
end
do
 local x=fixture()
 local b=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 x.screen.Enabled=false;x.ctx.epoch+=1
 local ok,why=b.resumeAfterClose()
 eq(ok,false,"stale P3 session never resumes")
 eq(why,"JOB_OR_EPOCH_CHANGED","stale epoch reason")
 eq(x.p3.resumed,0,"no stale resume")
end
-- An item label cannot be allowed to change during one capture. Test with the
-- REAL original TradeIO signatures while mutating the underlying GUI tree.
do
 local x=fixture()
 x.add(x.ours,1,"Iceblaster",1)
 local b=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 local prior=x.io.readSide
 local reads=0
 x.io.readSide=function(trade,side)
   reads+=1
   if reads==3 then
    x.ours.children.NewItem1.children.ItemName.children.Label.Text="Batwing"
   end
   return prior(trade,side)
 end
 local r=b.capture()
 eq(r.status,"REJECTED","midcapture mutation rejected")
 eq(r.reason,"OFFER_CHANGED_DURING_CAPTURE","revoked stale offer signature")
end
-- Incoming Gingerscope is permitted as an unpriced GUI observation.
do
 local x=fixture()
 x.add(x.theirs,1,"Gingerscope",2)
 local b=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 local r=b.capture()
 eq(r.status,"CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT","incoming protected candidate can be read")
 eq(r.theirs[1].quantity,2,"incoming quantity")
end
print("[PASS] actual guarded TradeIO + live P3/P4 session bridge:",tests)
print("[PASS] four PHYSICAL slots (stacks allowed), no remote, no Accept, stale session fails closed")
