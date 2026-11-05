-- Stage22 synthetic transaction tests, including mock native transport.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local Core=require("p4_offer_executor")
local Native=require("p4_native_offer")
local number=0
local function test(name,fn)
 local ok,reason=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(reason)) end
 number=number+1
end
local function fixture()
 local state={tradeOpen=true,contextOK=true,marketFresh=true,
   session="sess",ourSig="own-empty",theirSig="target-a",
   ownItems={},ourSlots=0,theirSlots=1,theirResolved=true,
   ourAccepted=false,theirAccepted=false}
 local proposal={session="sess",id="Mortal",page="godly",checkerId="3",
   qty=1,ourSig="own-empty",theirSig="target-a",
   permit="fake-issued-by-verified-planner"}
 local permit=function(p,o,t)
   return p.permit=="fake-issued-by-verified-planner"
      and p.theirSig==o.theirSig and p.ourSig==o.ourSig
 end
 local core=Core.new("sess",{validatePermit=permit})
 local root={Visible=true}
 function root:IsA(kind) return kind=="GuiObject" end
 local h={config={root=root,session="sess"}}
 local obs={capture=function()return state,{authorizesAccept=false}end}
 local sends=0
 local native=Native.new({observer=obs,handle=h,session="sess",
     ownInventory={unmapped=0,unpriced=0,badQty=0,
       items={{id="Mortal",page="godly",checkerId="3",name="Mortal",
          qty=1,type="Knife",cat="Weapons"}}},
     sendOnce=function(id,cat)
       assert(id=="Mortal" and cat=="Weapons")
       sends=sends+1
       return true
     end})
 return {state=state,proposal=proposal,core=core,native=native,
   getSends=function()return sends end}
end
local function dispatched(f)
 local command,intent=Core.prepare(f.core,f.proposal,f.state,1)
 assert(command=="DISPATCH",tostring(intent))
 local receipt=Native.execute(f.native,intent)
 assert(receipt.status=="SENT_ONCE",receipt.reason)
 assert(Core.dispatched(f.core,intent,receipt,1.03)=="WAIT")
 return intent
end
test("permitted one-copy offer is SENT_ONCE, not confirmed",function()
 local f=fixture()
 dispatched(f)
 assert(f.getSends()==1)
 assert(Core.observe(f.core,f.state,1.1)=="HOLD")
 assert(f.core.mode=="SENT")
end)
test("independent later UI observation verifies exactly one inserted copy",function()
 local f=fixture();dispatched(f)
 f.state.ourSig="own-one"
 f.state.ownSlots=nil
 f.state.ourSlots=1
 f.state.ownItems={{slot=1,id="Mortal",qty=1}}
 assert(Core.observe(f.core,f.state,1.4)=="VERIFIED")
 assert(f.core.mode=="IDLE" and f.getSends()==1)
end)
test("old Stage17 review is not permit and cannot place item",function()
 local f=fixture();f.proposal.permit=nil
 local action,why=Core.prepare(f.core,f.proposal,f.state,1)
 assert(action=="HOLD" and why=="independent-permit-unverified")
 assert(f.getSends()==0)
end)
test("untrusted permit checker returning false blocks",function()
 local f=fixture();f.core.validatePermit=function()return false end
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
 assert(f.getSends()==0)
end)
test("cannot act with an accepted trade",function()
 local f=fixture();f.state.theirAccepted=true
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
end)
test("cannot offer with expired market",function()
 local f=fixture();f.state.marketFresh=false
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
end)
test("cannot act on unresolved opponent inventory",function()
 local f=fixture();f.state.theirResolved=false
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
end)
test("stale opponent signature rejected before request",function()
 local f=fixture();f.state.theirSig="target-b"
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
end)
test("previously offered stack cannot silently grow",function()
 local f=fixture();f.state.ourSlots=1
 f.state.ownItems={{slot=1,id="Mortal",qty=1}}
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
end)
test("native token replay never sends twice",function()
 local f=fixture()
 local command,intent=Core.prepare(f.core,f.proposal,f.state,1)
 assert(command=="DISPATCH")
 assert(Native.execute(f.native,intent).status=="SENT_ONCE")
 assert(Native.execute(f.native,intent).status=="BLOCKED")
 assert(f.getSends()==1)
end)
test("native refuses opponent swap between permit and send",function()
 local f=fixture()
 local _,intent=Core.prepare(f.core,f.proposal,f.state,1)
 f.state.theirSig="target-b"
 assert(Native.execute(f.native,intent).status=="BLOCKED")
 assert(f.getSends()==0)
end)
test("native rejects local accept after permit",function()
 local f=fixture();local _,intent=Core.prepare(f.core,f.proposal,f.state,1)
 f.state.ourAccepted=true
 assert(Native.execute(f.native,intent).status=="BLOCKED")
 assert(f.getSends()==0)
end)
test("native rejects own inventory not proving exact item",function()
 local f=fixture();local _,intent=Core.prepare(f.core,f.proposal,f.state,1)
 f.native.config.ownInventory.items[1].checkerId="9"
 assert(Native.execute(f.native,intent).status=="BLOCKED")
 assert(f.getSends()==0)
end)
test("native rejects missing ownership metadata",function()
 local f=fixture();local _,intent=Core.prepare(f.core,f.proposal,f.state,1)
 f.native.config.ownInventory.badQty=1
 assert(Native.execute(f.native,intent).status=="BLOCKED")
 assert(f.getSends()==0)
end)
test("native rejects invisible root",function()
 local f=fixture();local _,intent=Core.prepare(f.core,f.proposal,f.state,1)
 f.native.config.handle.config.root.Visible=false
 assert(Native.execute(f.native,intent).status=="BLOCKED")
 assert(f.getSends()==0)
end)
test("native send callback failure is uncertain and never retried",function()
 local f=fixture();local _,intent=Core.prepare(f.core,f.proposal,f.state,1)
 local attempts=0
 f.native.config.sendOnce=function()attempts=attempts+1;error("remote failed")end
 local receipt=Native.execute(f.native,intent)
 assert(receipt.status=="ATTEMPT_UNCERTAIN")
 assert(Core.dispatched(f.core,intent,receipt,1.02)=="ESCALATE")
 assert(Native.execute(f.native,intent).status=="BLOCKED")
 assert(attempts==1)
end)
test("time expiration blocks claiming a silently dropped send",function()
 local f=fixture();dispatched(f)
 assert(Core.observe(f.core,f.state,2.6)=="ESCALATE")
 assert(f.core.mode=="ESCALATE")
 assert(f.getSends()==1)
end)
test("opponent changes after send => escalation, not another offer",function()
 local f=fixture();dispatched(f)
 f.state.theirSig="changed"
 assert(Core.observe(f.core,f.state,1.1)=="ESCALATE")
 assert(f.getSends()==1)
end)
test("unexpected extra weapon => escalation",function()
 local f=fixture();dispatched(f)
 f.state.ourSig="wrong-own-change"
 f.state.ourSlots=1;f.state.ownItems={{slot=1,id="Other",qty=1}}
 assert(Core.observe(f.core,f.state,1.1)=="ESCALATE")
end)
test("invalid quantity or extra slot prevents preparing",function()
 local f=fixture();f.proposal.qty=2
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
 f=fixture();f.state.ourSlots=4
 f.state.ownItems={
   {slot=1,id="X1",qty=1},{slot=2,id="X2",qty=1},
   {slot=3,id="X3",qty=1},{slot=4,id="X4",qty=1}}
 assert(Core.prepare(f.core,f.proposal,f.state,1)=="HOLD")
end)
test("closed trade after send never proves placement",function()
 local f=fixture();dispatched(f)
 f.state.tradeOpen=false
 assert(Core.observe(f.core,f.state,1.1)=="STOP")
 assert(f.getSends()==1)
end)
test("uncertain receipt cannot be treated as verified",function()
 local f=fixture();local _,intent=Core.prepare(f.core,f.proposal,f.state,1)
 assert(Core.dispatched(f.core,intent,
     {status="ATTEMPT_UNCERTAIN",attempted=true},1.02)=="ESCALATE")
end)
print("PASS",number,"Stage22 single-item placement and native transport tests")
