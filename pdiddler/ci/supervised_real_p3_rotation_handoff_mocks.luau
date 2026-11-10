-- Execute the ACTUAL supervised P3/P4 handoff and ACTUAL guarded P4 TradeIO.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local coordinatorText=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
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
  if self.other and k==self.other.Name and self.other.Parent==players then return self.other end
 end
 function players:GetPlayerByUserId(uid)
  if p.UserId==uid and p.Parent==players then return p end
  if self.other and self.other.UserId==uid and self.other.Parent==players then return self.other end
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
 local coordinator=luau.load(coordinatorText,{environment=env,injectGlobals=true})()
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
 local outgoing={session=18,paused=false,resumed=0,state={processed={},active=nil}}
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
 return {module=module,coordinator=coordinator,io=io,p3=outgoing,scanner=scanner,
    ctx=ctx,players=players,lp=lp,p=p,pg=pg,screen=screen,
    trade=trade,ours=own,theirs=their,ownAccepted=ownAccepted,
    theirAccepted=theirAccepted,name=name,add=add,sends=sends}
end
local function bind(x)
 local controller,reason=x.coordinator.new(
   x.scanner,x.p3,x.module,x.io,x.players,x.lp,
   {getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session}
 )
 eq(type(controller),"table","valid P3 controller instance: "..tostring(reason and reason.reason))
 return controller
end
local function acceptP3(x)
 x.p3.state.processed[x.p.UserId]="trade-open"
 x.p3.state.active=nil
 x.p3.paused=true
end
do
 local x=fixture()
 local manager=bind(x)
 local idle=manager.poll()
 eq(idle.status,"P3_ROTATING","genuine outgoing queue observed as active")
 eq(idle.requestOriginBound,false,"no server provenance")
 eq(#x.sends,0,"no physical remotes when scanning")
 acceptP3(x)
 local observed=manager.poll()
 eq(observed.status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","P3 processed outcome attached to P4")
 eq(observed.ownPhysicalSlots,0,"empty own side")
 eq(observed.theirPhysicalSlots,0,"empty partner side")
 eq(observed.authorizesAccept,false,"final Accept always false")
 eq(observed.authorizesOffer,false,"not a plan to send")
 eq(observed.contactOrigin,"P3_CLIENT_PROCESSED_TRADE_OPEN_UNATTESTED","P3 source labeled unauthenticated")
 x.add(x.ours,1,"Iceblaster",1).children.Container.children.Amount.Text=""
 x.add(x.theirs,1,"Emberbow",8)
 local snapshot=manager.poll()
 eq(snapshot.status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","real IO reads current two sides")
 eq(snapshot.ownPhysicalSlots,1,"singleton one PHYSICAL slot")
 eq(snapshot.theirPhysicalSlots,1,"stack 8 one PHYSICAL slot")
 eq(#x.sends,0,"coordinator neither offers nor accepts")
 local resumed,reason=manager.resumeAfterClose()
 eq(resumed,false,"cannot resume while original trade window open")
 eq(reason,"TRADE_STILL_OPEN","existing PR199 closure gate retained")
 x.screen.Enabled=false
 resumed,reason=manager.resumeAfterClose()
 eq(resumed,true,"P3 resumes only after trade root closes")
 eq(reason,"P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED","explicit resume reason")
 eq(x.p3.resumed,1,"exactly one original P3 resume")
 resumed,reason=manager.resumeAfterClose()
 eq(resumed,false,"never double resume")
 eq(x.p3.resumed,1,"no double original resume")
 -- A later unsolicited trade window with the SAME old processed map entry
 -- must NOT be attributed to the previous P3 outgoing request.
 x.screen.Enabled=true
 x.p3.paused=true
 local old=manager.poll()
 eq(old.status,"P3_PAUSED_UNATTRIBUTED","sticky trade-open key not reused")
 eq(old.reason,"P3_NO_FRESH_ACCEPTED_TARGET","old outcome consumed")
 eq(#x.sends,0,"zero spoofable offers")
end
-- The coordinator can consume a SECOND newly processed partner later, but
-- must never reuse the old one, and must verify the exact live player object.
do
 local x=fixture()
 local manager=bind(x)
 acceptP3(x)
 local first=manager.poll()
 eq(first.status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","first session bound")
 x.screen.Enabled=false
 local ok=manager.resumeAfterClose()
 eq(ok,true,"first done")
 x.players.other={Name="SecondAlt",DisplayName="Clone",UserId=3,Parent=x.players}
 x.name.Text="SecondAlt"
 x.p3.state.processed[3]="trade-open"
 x.screen.Enabled=true
 x.p3.paused=true
 local second=manager.poll()
 eq(second.status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","second uniquely new processed target bound")
 eq(#x.sends,0,"no P4 offer in second session")
end
do
 local x=fixture()
 x.p3.state.processed[2]="trade-open"
 x.p3.paused=true
 local manager=bind(x)
 local status=manager.poll()
 eq(status.status,"P3_PAUSED_UNATTRIBUTED","preexisting processed id never retroactively binds")
 eq(status.reason,"P3_NO_FRESH_ACCEPTED_TARGET","historical record quarantined")
end
do
 local x=fixture()
 local manager=bind(x)
 x.p3.paused=true
 local result=manager.poll()
 eq(result.status,"P3_PAUSED_UNATTRIBUTED","unproven pause stays unattributed")
 eq(result.reason,"P3_NO_FRESH_ACCEPTED_TARGET","pause alone not enough")
end
do
 local x=fixture()
 local manager=bind(x)
 acceptP3(x)
 x.name.Text="WrongPlayer"
 local result=manager.poll()
 eq(result.status,"P3_PAUSED_UNATTRIBUTED","wrong GUI partner refused")
 eq(result.reason,"P3_TRADE_WINDOW_PARTNER_NOT_EXACT","wrong partner explicitly identified")
 eq(#x.sends,0,"no offer to wrong partner")
end
do
 local x=fixture()
 local manager=bind(x)
 x.p3.state.processed[2]="trade-open"
 x.p3.state.processed[3]="trade-open"
 x.p3.paused=true
 local result=manager.poll()
 eq(result.status,"P3_PAUSED_UNATTRIBUTED","two fresh trade-open outcomes ambiguous")
 eq(result.reason,"P3_MULTIPLE_NEW_TRADE_OUTCOMES","never choose arbitrary partner")
end
do
 local x=fixture()
 local manager=bind(x)
 acceptP3(x)
 x.p3.state.active=x.p
 local result=manager.poll()
 eq(result.reason,"P3_ACTIVE_PLAYER_NOT_RELEASED","waits for real P3 release")
 eq(#x.sends,0,"no offers during transitional pause")
end
do
 local x=fixture()
 local manager=bind(x)
 acceptP3(x)
 x.scanner.state="blacklist"
 local result=manager.poll()
 eq(result.reason,"P3_SCANNER_TARGET_NOT_CURRENT","P3 whitelist revoked")
 eq(#x.sends,0,"no offers to blacklist")
end
do
 local x=fixture()
 local manager=bind(x)
 acceptP3(x)
 x.theirAccepted.Visible=true
 local result=manager.poll()
 eq(result.reason,"P3_TO_P4_BOUND_HANDOFF_REFUSED","preaccepted GUI rejected via original guard")
 eq(#x.sends,0,"no offers with acceptance indicator")
end
for _,mutate in ipairs({
 function(x)x.ctx.epoch=20 end,
 function(x)x.ctx.job="Job-B" end,
 function(x)x.p3.session=21 end
}) do
 local x=fixture()
 local manager=bind(x)
 acceptP3(x)
 mutate(x)
 local result=manager.poll()
 eq(result.status,"BLOCKED","P3 epoch/job invalidated")
 eq(result.reason,"P3_JOB_OR_EPOCH_CHANGED","exact stale reason")
 eq(#x.sends,0,"stale P3 no offer")
end
do
 local x=fixture()
 local manager=bind(x)
 eq(manager.stop(),true,"stopped explicitly")
 local result=manager.poll()
 eq(result.status,"BLOCKED","stopped can never bind")
 eq(result.reason,"CONTROLLER_STOPPED","stopped status")
end
print("[PASS] real P3 paused rotation to original P4 GUI observer, ",tests)
print("[PASS] no offer/request/Accept, exact fresh processed user, safe P3 resumption")
