-- Stage27 actual Stage22 + Stage10 pure/native mock integration.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local Lab=require("p4_stage27_lab_core")
local Offer=require("p4_offer_executor")
local OfferNative=require("p4_native_offer")
local Remove=require("p4_removal_executor")
local RemoveNative=require("p4_native_removal")
local count=0
local function check(name,fn)
 local ok,reason=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(reason)) end
 count=count+1
end
local Node={};Node.__index=Node
function Node.new(name,kind,parent)
 local obj=setmetatable({Name=name,kind=kind or "Frame",
  Parent=parent,Visible=true,Enabled=true,children={}},Node)
 if parent then parent.children[name]=obj end
 return obj
end
function Node:FindFirstChild(name)return self.children[name] end
function Node:IsA(kind)
 return self.kind==kind or (kind=="GuiObject" and self.kind~="ScreenGui")
end
local function fixture()
 local root=Node.new("Trade")
 local side=Node.new("YourOffer","Frame",root)
 local container=Node.new("Container","Frame",side)
 local slot=Node.new("NewItem1","Frame",container)
 Node.new("ActionButton","TextButton",Node.new("Container","Frame",slot))
 local now=1
 local obs={session="s1",tradeOpen=true,contextOK=true,
  marketFresh=true,ourSig="own-none",theirSig="their-one",
  ourSlots=0,theirSlots=1,theirResolved=true,ownItems={},
  ourAccepted=false,theirAccepted=false}
 local observer={capture=function()return obs,{authorizesAccept=false}end}
 local handle={config={session="s1",root=root}}
 local owned={unmapped=0,badQty=0,unpriced=0,items={
  {id="TestGodly",page="godly",checkerId="23",
   name="Test Godly",cat="Weapons",type="Knife",qty=1}}}
 local offerEvents,removeEvents=0,0
 local offerHandle=OfferNative.new({observer=observer,handle=handle,
   session="s1",ownInventory=owned,
   sendOnce=function(id,kind)
    assert(id=="TestGodly" and kind=="Weapons")
    offerEvents=offerEvents+1;return true
   end})
 local removeHandle=RemoveNative.new({observer=observer,handle=handle,
   session="s1",clickOnce=function(button,intent)
     assert(button.Name=="ActionButton" and intent.id=="TestGodly")
     removeEvents=removeEvents+1;return true
   end})
 local lab
 local offerState=Offer.new("s1",{validatePermit=function(p,o,t)
  return lab and Lab.validateManualPermit(lab,p,o,t)==true
 end})
 lab=Lab.new({session="s1",observer=observer,handle=handle,
  clock=function()return now end,
  item={id="TestGodly",page="godly",checkerId="23",price=50},
  offerCore=Offer,offerNative=OfferNative,offerState=offerState,
  offerHandle=offerHandle,
  removeCore=Remove,removeNative=RemoveNative,
  removeState=Remove.new("s1"),removeHandle=removeHandle})
 return {lab=lab,obs=obs,now=function(n)now=n end,root=root,
   adds=function()return offerEvents end,
   removes=function()return removeEvents end}
end
local function addConfirmed(f)
 assert(Lab.add(f.lab)=="WAIT")
 f.now(1.1)
 f.obs.ourSlots=1
 f.obs.ourSig="own-one"
 f.obs.ownItems={{slot=1,id="TestGodly",qty=1}}
 assert(Lab.poll(f.lab)=="VERIFIED")
end
check("cannot place without explicit Lab.add",function()
 local f=fixture()
 assert(f.lab.phase=="READY_ADD" and f.adds()==0)
 assert(Lab.poll(f.lab)=="HOLD")
 assert(f.adds()==0 and f.removes()==0)
end)
check("manual first click dispatches exactly one item",function()
 local f=fixture()
 assert(Lab.add(f.lab)=="WAIT")
 assert(f.lab.phase=="VERIFY_ADD" and f.adds()==1)
 assert(not f.lab.addVerified and not f.lab.removeVerified)
 assert(Lab.add(f.lab)=="HOLD")
 assert(f.adds()==1)
end)
check("physical add proof required after separate later observation",function()
 local f=fixture()
 addConfirmed(f)
 assert(f.lab.phase=="READY_REMOVE")
 assert(f.lab.addVerified and not f.lab.removeVerified)
 assert(f.adds()==1 and f.removes()==0)
end)
check("one removal click then independent empty-offer proof",function()
 local f=fixture();addConfirmed(f)
 assert(Lab.remove(f.lab)=="WAIT")
 assert(f.removes()==1 and not f.lab.removeVerified)
 assert(Lab.remove(f.lab)=="HOLD")
 f.now(1.3)
 f.obs.ourSlots=0;f.obs.ourSig="own-empty-after-removal";f.obs.ownItems={}
 assert(Lab.poll(f.lab)=="VERIFIED")
 assert(f.lab.phase=="DONE" and f.lab.removeVerified)
 assert(f.adds()==1 and f.removes()==1)
end)
check("opponent must first visibly offer an eligible weapon",function()
 local f=fixture();f.obs.theirSlots=0
 assert(Lab.add(f.lab)=="STOP")
 assert(f.adds()==0 and f.lab.phase=="MANUAL_RECOVERY")
end)
check("missing counterpart identity blocks add",function()
 local f=fixture();f.obs.theirResolved=false
 assert(Lab.add(f.lab)=="STOP" and f.adds()==0)
end)
check("source expired blocks native Add",function()
 local f=fixture();f.obs.marketFresh=false
 assert(Lab.add(f.lab)=="STOP" and f.adds()==0)
end)
check("accepted opponent blocks Add",function()
 local f=fixture();f.obs.theirAccepted=true
 assert(Lab.add(f.lab)=="STOP" and f.adds()==0)
end)
check("accepted local side blocks Add",function()
 local f=fixture();f.obs.ourAccepted=true
 assert(Lab.add(f.lab)=="STOP" and f.adds()==0)
end)
check("changed partner signature after sent causes no retry",function()
 local f=fixture();assert(Lab.add(f.lab)=="WAIT")
 f.obs.theirSig="changed"
 assert(Lab.poll(f.lab)=="STOP")
 assert(f.adds()==1 and f.lab.phase=="MANUAL_RECOVERY")
end)
check("a successful remote dispatch is not placement proof",function()
 local f=fixture();assert(Lab.add(f.lab)=="WAIT")
 f.now(1.10)
 assert(Lab.poll(f.lab)=="HOLD")
 assert(not f.lab.addVerified and f.removes()==0)
end)
check("uncertain physical add never retries",function()
 local f=fixture()
 f.lab.offerHandle.config.sendOnce=function()error("remote not working")end
 assert(Lab.add(f.lab)=="STOP")
 assert(Lab.add(f.lab)=="HOLD" and f.adds()==0)
end)
check("before confirmed ADD, REMOVE cannot execute",function()
 local f=fixture()
 assert(Lab.remove(f.lab)=="HOLD" and f.removes()==0)
end)
check("unexpected offered weapon blocks physical REMOVE",function()
 local f=fixture();addConfirmed(f)
 f.obs.ownItems={{slot=1,id="Other",qty=1}}
 assert(Lab.remove(f.lab)=="STOP" and f.removes()==0)
end)
check("opponent Accept blocks removal click",function()
 local f=fixture();addConfirmed(f);f.obs.theirAccepted=true
 assert(Lab.remove(f.lab)=="STOP" and f.removes()==0)
end)
check("physical remove is protective if market expires meanwhile",function()
 local f=fixture();addConfirmed(f);f.obs.marketFresh=false
 assert(Lab.remove(f.lab)=="WAIT" and f.removes()==1)
end)
check("same signature without deletion never proves REMOVE",function()
 local f=fixture();addConfirmed(f)
 assert(Lab.remove(f.lab)=="WAIT")
 f.now(1.12)
 assert(Lab.poll(f.lab)=="HOLD")
 assert(not f.lab.removeVerified)
end)
check("removal timeout cannot retry click",function()
 local f=fixture();addConfirmed(f)
 assert(Lab.remove(f.lab)=="WAIT")
 f.now(3.5)
 assert(Lab.poll(f.lab)=="STOP")
 assert(f.removes()==1 and f.lab.phase=="MANUAL_RECOVERY")
end)
check("stopping cannot authorize additional actions",function()
 local f=fixture();Lab.stop(f.lab)
 assert(Lab.add(f.lab)=="HOLD" and Lab.remove(f.lab)=="HOLD")
 assert(f.adds()==0 and f.removes()==0)
end)
check("report exposes neither identities nor completion claims",function()
 local f=fixture();addConfirmed(f)
 local r=Lab.report(f.lab)
 assert(r.itemPrice==50 and r.addVerified==true)
 assert(r.authorizesAccept==false and r.serverCompletionProven==false)
 assert(r.partnerUserId==nil and r.localUserId==nil and r.jobId==nil)
end)
print("PASS",count,"Stage27 real Stage22 ADD and Stage10 REMOVE manual-lab transaction regressions")
