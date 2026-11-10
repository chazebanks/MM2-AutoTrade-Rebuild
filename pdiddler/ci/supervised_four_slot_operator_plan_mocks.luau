-- Execute the ACTUAL protected TradeIO, P3/P4 binding and manual 1..4 slot plan.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local planText=fs.readFile("pdiddler/supervised/supervised_four_slot_operator_plan.lua")
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
 local plan=luau.load(planText,{environment=env,injectGlobals=true})()
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
 return {module=module,plan=plan,io=io,gate=gate,remote=remote,p3=outgoing,scanner=scanner,
    ctx=ctx,players=players,lp=lp,p=p,pg=pg,screen=screen,
    trade=trade,ours=own,theirs=their,ownAccepted=ownAccepted,
    theirAccepted=theirAccepted,name=name,add=add,sends=sends}
end
local function arm(keys)
 return {armed=true,manualOfferOnly=true,noAutomaticAcceptAcknowledged=true,weaponKeys=keys}
end
local function getBound(x)
 local b,err=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 eq(b~=nil,true,"requires valid original P3/P4 bound session "..tostring(err and err.reason))
 return b
end
local function simulateOffer(x,handler)
 x.remote.FireServer=function(_,key,category)
  table.insert(x.sends,{key,category})
  if handler then handler(key,category,#x.sends)
  else x.add(x.ours,#x.sends,key,1) end
 end
end
local function run(x,keys,wait)
 local b=getBound(x)
 local approval=arm(keys)
 return x.plan.run(b,x.io,x.gate,approval,{wait=wait or function()end}),approval,b
end
-- Human-approved two item pass through exact original protected OfferItem.
do
 local x=fixture()
 simulateOffer(x)
 x.add(x.theirs,1,"Emberbow",6)
 local r,approval,b=run(x,{"Iceblaster","Batwing"})
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","2-item actual client plan")
 eq(r.offerAttempts,2,"two guarded remote attempts")
 eq(r.clientVisibleAddedSlots,2,"two GUI confirmed distinct slots")
 eq(#x.sends,2,"two physical sends")
 eq(x.sends[1][1],"Iceblaster","first selected weapon")
 eq(x.sends[2][1],"Batwing","second selected weapon")
 eq(x.sends[1][2],"Weapons","weapon category")
 eq(r.tradeOutcome,"UNKNOWN","not completed trade")
 eq(r.authorizesTrade,false,"no autonomous trading")
 eq(r.authorizesAccept,false,"never final Accept")
 eq(r.mayReportProfit,false,"never completed profit")
 eq(approval.armed,false,"approval consumed")
 eq(approval._consumed,true,"one-shot marked")
 eq(x.gate.checkOutbound,nil,"gate cleared at end")
 local r2=x.plan.run(b,x.io,x.gate,arm({"Laser"}),{wait=function()end})
 eq(r2.reason,"PLAN_ONE_SHOT_ALREADY_SPENT","cannot send twice same bound")
 eq(#x.sends,2,"no duplicate remote after replay")
end
-- 4 separate items, even when received side has >4 COPIES in a single slot.
do
 local x=fixture()
 x.add(x.theirs,1,"Emberbow",12)
 simulateOffer(x)
 local r=run(x,{"Iceblaster","Batwing","Laser","Luger"})
 eq(r.offerAttempts,4,"four items allowed")
 eq(r.clientVisibleAddedSlots,4,"four physical GUI slots")
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","4-slot outcome")
 eq(#x.sends,4,"physical cap exactly four")
end
-- One item with no mirrored GUI change must STOP: never auto-retry.
do
 local x=fixture()
 simulateOffer(x,function() end)
 local r=run(x,{"Iceblaster","Batwing"})
 eq(r.status,"STOPPED","no GUI proof stops")
 eq(r.reason,"ITEM_GUI_CONFIRMATION_TIMEOUT","bounded five-poll wait")
 eq(r.offerAttempts,1,"at most one remote")
 eq(r.clientVisibleAddedSlots,0,"no confirmed GUI")
 eq(#x.sends,1,"never retry unconfirmed event")
end
-- An opponent offer change must STOP without sending item 2.
do
 local x=fixture()
 simulateOffer(x,function(key,cat,index)
  x.add(x.ours,index,key,1)
  x.add(x.theirs,1,"Emberbow",2)
 end)
 local r=run(x,{"Iceblaster","Batwing"})
 eq(r.status,"STOPPED","partner offered revision change stops")
 eq(r.reason,"PARTNER_OFFER_REVISION_OR_SLOT_CHANGED","reason exact")
 eq(#x.sends,1,"never send second after opponent mutation")
end
-- Malicious late partner switch inside the actual TradeIO gate must fail.
do
 local x=fixture()
 simulateOffer(x)
 local original=x.io.offerItem
 x.io.offerItem=function(item)
  x.name.Text="SwitchedPartner"
  return original(item)
 end
 local r=run(x,{"Iceblaster","Batwing"})
 eq(r.status,"STOPPED","wrong partner at dispatch")
 eq(r.reason,"GUARDED_OFFER_REMOTE_DENIED_OR_UNCONFIRMED","guard denial classified")
 eq(#x.sends,0,"no physical item remotely sent")
 eq(x.gate.checkOutbound,nil,"gate cleared after remote denial")
end
-- Wrong item quantity or wholly different own offer after dispatch.
do
 local x=fixture()
 simulateOffer(x,function(_,_,i) x.add(x.ours,i,"SomeOtherGun",3) end)
 local r=run(x,{"Iceblaster","Batwing"})
 eq(r.status,"STOPPED","unexpected offer stops")
 eq(r.reason,"UNEXPECTED_OWN_OFFER_MUTATION","unapproved GUI item rejected")
 eq(#x.sends,1,"never send second when GUI item wrong")
end
-- Session epoch change after first GUI replication blocks second item.
do
 local x=fixture()
 simulateOffer(x)
 local mutated=false
 local r=run(x,{"Iceblaster","Batwing"},function()
  if not mutated then
   mutated=true;x.ctx.epoch=200
  end
 end)
 eq(r.status,"STOPPED","P3 stale session stop")
 eq(#x.sends,1,"no second item on stale epoch")
end
-- Opponent accept state changing exactly before remote should fail closed.
do
 local x=fixture()
 simulateOffer(x)
 local prior=x.io.offerItem
 x.io.offerItem=function(item)
  x.theirAccepted.Visible=true
  return prior(item)
 end
 local r=run(x,{"Iceblaster"})
 eq(r.status,"STOPPED","no offer after opponent accepted")
 eq(#x.sends,0,"zero remote after accepted")
end
-- Own offer must begin empty; don't overwrite live negotiations.
do
 local x=fixture()
 x.add(x.ours,1,"Laser",1)
 simulateOffer(x)
 local r=run(x,{"Iceblaster"})
 eq(r.status,"BLOCKED","own nonempty preflight")
 eq(r.reason,"OWN_OFFER_MUST_START_EMPTY","no rebalance without approval")
 eq(#x.sends,0,"no remote sent to nonempty offer")
end
-- Explicit manual arm and no-auto-Accept acknowledgement are mandatory.
do
 for _,mutation in ipairs({
  function(a)a.armed=false end,
  function(a)a.manualOfferOnly=false end,
  function(a)a.noAutomaticAcceptAcknowledged=false end,
 }) do
  local x=fixture()
  local bound=getBound(x)
  local approval=arm({"Iceblaster"})
  mutation(approval)
  local r=x.plan.run(bound,x.io,x.gate,approval,{wait=function()end})
  eq(r.status,"BLOCKED","missing explicit approval")
  eq(r.reason,"OPERATOR_EXPLICIT_ARM_REQUIRED","missing approval reason")
  eq(#x.sends,0,"zero remote without explicit approval")
 end
end
-- Reject Gingerscope and all malformed / duplicate or oversized plans.
do
 local keysList={
  {"Gingerscope"},{"Ginger_scope"},{"Iceblaster","Iceblaster"},
  {"Iceblaster","Batwing","Laser","Luger","Frostsaber"},
  {"Iceblaster",false},{"Iceblaster","Bad Name"},
  {"Iceblaster\nAccept"},
 }
 for _,keys in ipairs(keysList) do
  local x=fixture()
  local bound=getBound(x)
  local r=x.plan.run(bound,x.io,x.gate,arm(keys),{wait=function()end})
  eq(r.status,"BLOCKED","reject unsafe operator keys")
  eq(#x.sends,0,"zero remote for unsafe operator keys")
 end
end
-- P3/4 source explicitly carries no market price authority.
do
 local x=fixture()
 simulateOffer(x)
 local b=getBound(x)
 local original=b.capture
 b.capture=function()
  local value=original()
  value.pricesAuthenticated=true
  return value
 end
 local r=x.plan.run(b,x.io,x.gate,arm({"Iceblaster"}),{wait=function()end})
 eq(r.reason,"SNAPSHOT_AUTHORITY_MISMATCH","no false source authority")
 eq(#x.sends,0,"no remote with forged authority")
end

-- Failure to schedule the next readback must not throw or lose the result
-- after one physical send; the arm stays consumed and no resend occurs.
do
 local x=fixture()
 simulateOffer(x)
 local b=getBound(x)
 local a=arm({"Iceblaster","Batwing"})
 local ok,r=pcall(x.plan.run,b,x.io,x.gate,a,{wait=function()
  error("fake executor wait failed")
 end})
 eq(ok,true,"scheduler failure caught by controller")
 eq(r.status,"STOPPED","scheduler failure bounded")
 eq(r.reason,"GUI_REPLICATION_WAIT_FAILED","scheduler reason")
 eq(r.offerAttempts,1,"one attempted offer only")
 eq(#x.sends,1,"no duplicate remote after scheduler crash")
 eq(a._consumed,true,"approval remains spent")
 eq(x.gate.checkOutbound,nil,"no stale gate after scheduling failure")
end
-- A forged or incomplete slot snapshot must not turn missing arrays into
-- an apparently valid empty own offer.
do
 local x=fixture()
 local b=getBound(x)
 local old=b.capture
 b.capture=function()
  local r=old()
  r.ours=nil
  return r
 end
 local r=x.plan.run(b,x.io,x.gate,arm({"Iceblaster"}),{wait=function()end})
 eq(r.status,"BLOCKED","incomplete slot snapshot denied")
 eq(r.reason,"PHYSICAL_SLOT_SNAPSHOT_UNREADABLE","missing-array reason")
 eq(#x.sends,0,"no sends for incomplete snapshots")
end


-- Raw MM2 keys do not always equal the visible weapon label. Known prior
-- client example: game key Scythe is displayed as Batwing. Do not fake
-- an item identity match or require the human to choose an unsafe alias key.
do
 local x=fixture()
 simulateOffer(x,function(key,category,index)
  x.add(x.ours,index,key=="Scythe" and "Batwing" or key,1)
 end)
 local b=getBound(x)
 local a=arm({"Iceblaster","Scythe"})
 a.expectedDisplayNames={"Iceblaster","Batwing"}
 a.expectedChromaFlags={false,false}
 local r=x.plan.run(b,x.io,x.gate,a,{wait=function()end})
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","separate raw and display alias approved")
 eq(r.clientVisibleAddedSlots,2,"two physical GUI aliases confirmed")
 eq(x.sends[2][1],"Scythe","outgoing remote uses raw game key, never display Batwing")
end
-- Chroma variants must be explicitly approved as Chroma and still bound to
-- a distinct physical slot; a naked display label does not establish type.
do
 local x=fixture()
 simulateOffer(x,function(_,_,i)x.add(x.ours,i,"Fang",1,true)end)
 local b=getBound(x)
 local a=arm({"ChromaFang"})
 a.expectedDisplayNames={"Fang"}
 a.expectedChromaFlags={true}
 local r=x.plan.run(b,x.io,x.gate,a,{wait=function()end})
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","explicit chroma variant accepted")
 eq(x.sends[1][1],"ChromaFang","raw Chroma key dispatched")
end
-- Unknown/mismatched visual identity NEVER triggers a second send.
do
 local x=fixture()
 simulateOffer(x,function(key,_,i)x.add(x.ours,i,key=="Scythe" and "NotBatwing" or key,1)end)
 local b=getBound(x)
 local a=arm({"Iceblaster","Scythe"})
 a.expectedDisplayNames={"Iceblaster","Batwing"}
 a.expectedChromaFlags={false,false}
 local r=x.plan.run(b,x.io,x.gate,a,{wait=function()end})
 eq(r.status,"STOPPED","wrong alias must stop")
 eq(r.reason,"UNEXPECTED_OWN_OFFER_MUTATION","wrong alias visible")
 eq(#x.sends,2,"do not retry dispatched but unconfirmed second item")
end
-- Protected visible-name cannot be laundered through ordinary raw key.
do
 local x=fixture()
 local b=getBound(x)
 local a=arm({"Iceblaster"})
 a.expectedDisplayNames={"Gingerscope"}
 local r=x.plan.run(b,x.io,x.gate,a,{wait=function()end})
 eq(r.status,"BLOCKED","outgoing protected display block")
 eq(#x.sends,0,"no Gingerscope by display alias")
end
-- Size mismatches, forged chroma flags, control characters, and duplicate
-- visible variants fail BEFORE the guarded OfferItem remote.
do
 local alter={
  function(a)a.expectedDisplayNames={"Iceblaster","Batwing"} end,
  function(a)a.expectedDisplayNames={"Iceblaster\nBad"} end,
  function(a)a.expectedChromaFlags={true,false}end,
  function(a)a.expectedDisplayNames={"Laser","Laser"}end,
 }
 for i,change in ipairs(alter) do
  local x=fixture()
  local b=getBound(x)
  local a=arm({"Iceblaster"})
  if i==4 then a=arm({"Iceblaster","Batwing"}) end
  change(a)
  local r=x.plan.run(b,x.io,x.gate,a,{wait=function()end})
  eq(r.status,"BLOCKED","reject malformed alias config "..i)
  eq(#x.sends,0,"no physical remote on bad alias "..i)
 end
end


-- A displayed numbered step precedes each physical send; step i+1 only
-- appears after i real GUI slots are present, not after a timer.
do
 local x=fixture()
 simulateOffer(x)
 local bound=getBound(x)
 local steps={}
 local a=arm({"Iceblaster","Batwing","Laser"})
 local r=x.plan.run(bound,x.io,x.gate,a,{
  wait=function()end,
  onBeforeItem=function(i,total,priorSlots)
   steps[#steps+1]={i,total,priorSlots,#x.sends}
   return true
  end,
 })
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","guided offer succeeds")
 eq(#steps,3,"three separate on-screen instructions")
 for i,row in ipairs(steps) do
  eq(row[1],i,"numbered current item")
  eq(row[2],3,"fixed approved total")
  eq(row[3],i-1,"previous physical slot observed first")
  eq(row[4],i-1,"no premature remote before instruction")
 end
end
do
 local x=fixture()
 simulateOffer(x)
 local bound=getBound(x)
 local r=x.plan.run(bound,x.io,x.gate,arm({"Iceblaster","Batwing"}),{
  wait=function()end,
  onBeforeItem=function(i) return i==1 end,
 })
 eq(r.status,"STOPPED","missing second instruction stops")
 eq(r.reason,"ONSCREEN_STEP_UNAVAILABLE","specific UI reason")
 eq(r.offerAttempts,1,"one attempt")
 eq(r.clientVisibleAddedSlots,1,"one confirmed slot")
 eq(#x.sends,1,"no second remote")
 eq(x.gate.checkOutbound,nil,"no orphaned remote approval")
end
do
 local x=fixture()
 simulateOffer(x)
 local b=getBound(x)
 local ok,r=pcall(x.plan.run,b,x.io,x.gate,arm({"Iceblaster"}),{
  wait=function()end,
  onBeforeItem=function()error("guide failed")end,
 })
 eq(ok,true,"failed UI callback caught")
 eq(r.status,"STOPPED","UI exception stops")
 eq(r.reason,"ONSCREEN_STEP_UNAVAILABLE","UI failure reason")
 eq(r.offerAttempts,0,"no remote attempted")
 eq(#x.sends,0,"no concealed mutation")
end


-- A first physical offer can yield a transient GUI snapshot whose ItemName
-- label is not yet rendered. Do NOT submit another item; poll read-only for
-- reconciliation, then accept ONLY a fully verified snapshot.
do
 local x=fixture()
 local b=getBound(x)
 local calls=0
 local realCapture=b.capture
 b.capture=function()
  calls+=1
  if #x.sends==1 and calls==5 then
   return {status="REJECTED",reason="PHYSICAL_GUI_SLOTS_NOT_RECONCILED"}
  end
  return realCapture()
 end
 simulateOffer(x)
 local approval=arm({"Iceblaster","Batwing"})
 local result=x.plan.run(b,x.io,x.gate,approval,{wait=function()end})
 eq(result.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","transient GUI snapshot reconciles")
 eq(result.offerAttempts,2,"each verified item sent exactly once")
 eq(#x.sends,2,"no duplicate dispatch on transient snapshot")
end
-- Persistently malformed live GUI must stop with the specific safe reason
-- and NEVER claim a confirmed slot or issue a second remote.
do
 local x=fixture()
 local b=getBound(x)
 local orig=b.capture
 b.capture=function()
  if #x.sends>0 then
   return {status="REJECTED",reason="PHYSICAL_GUI_SLOTS_NOT_RECONCILED"}
  end
  return orig()
 end
 simulateOffer(x)
 local result=x.plan.run(b,x.io,x.gate,arm({"Iceblaster","Batwing"}),{
  wait=function()end
 })
 eq(result.status,"STOPPED","permanently unreadable GUI stopped")
 eq(result.reason,"P3_P4_LIVE_SNAPSHOT_REJECTED","preserve status contract")
 eq(result.snapshotRejectReason,"PHYSICAL_GUI_SLOTS_NOT_RECONCILED","specific sanitized cause survives")
 eq(result.offerAttempts,1,"one remote attempted")
 eq(result.clientVisibleAddedSlots,0,"no falsely confirmed slot")
 eq(#x.sends,1,"never retry first or dispatch second item")
end
-- Acceptance/partner changes are NOT render transients. They stop
-- immediately after the first physical send, even if GUI later looks valid.
do
 local x=fixture()
 local b=getBound(x)
 local orig=b.capture
 b.capture=function()
  if #x.sends>0 then
   return {status="REJECTED",reason="ACCEPT_ALREADY_SET"}
  end
  return orig()
 end
 simulateOffer(x)
 local waits=0
 local result=x.plan.run(b,x.io,x.gate,arm({"Iceblaster","Batwing"}),{
  wait=function()waits+=1 end
 })
 eq(result.status,"STOPPED","accept flag after send stops")
 eq(result.snapshotRejectReason,"ACCEPT_ALREADY_SET","precise accept state preserved")
 eq(waits,1,"fatal acceptance never retried")
 eq(#x.sends,1,"no second send after accept")
end
-- Never serialize arbitrary or identifying text from an untrusted
-- observer rejection reason.
do
 local x=fixture()
 local b=getBound(x)
 local orig=b.capture
 b.capture=function()
  if #x.sends>0 then
   return {status="REJECTED",reason="PLAYER=TrustedAlt/Secret"}
  end
  return orig()
 end
 simulateOffer(x)
 local result=x.plan.run(b,x.io,x.gate,arm({"Iceblaster"}),{
  wait=function()end
 })
 eq(result.reason,"P3_P4_LIVE_SNAPSHOT_REJECTED","untrusted cause generic")
 eq(result.snapshotRejectReason,"UNKNOWN_SNAPSHOT_REJECTION","identity not copied")
end

print("[PASS] P3/P4 guarded physical multi-slot approved plan",tests)
print("[PASS] four distinct physical slots, no auto Accept, no duplicate sends, Gingerscope protected")
