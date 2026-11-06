-- Stage23 replacement integration: actual Stage17 review, explicit policy approval, Stage11 defensive recovery.
local dir=arg[1] or "pdiddler/new_part4"
local env={}
getgenv=function() return env end
loadstring=load

local Node={};Node.__index=Node
function Node.new(kind,name,props)
 local o=setmetatable({ClassName=kind,Name=name,Children={},attrs={},
    Parent=nil,Visible=true,Enabled=true},Node)
 for k,v in pairs(props or {}) do o[k]=v end
 return o
end
function Node:Add(n) n.Parent=self; self.Children[#self.Children+1]=n;return n end
function Node:IsA(k)
 if self.ClassName==k then return true end
 if k=="GuiObject" then return self.ClassName=="Frame" or self.ClassName=="TextLabel"
   or self.ClassName=="TextButton" or self.ClassName=="ImageLabel" end
 return false
end
function Node:FindFirstChild(name,recursive)
 for _,v in ipairs(self.Children) do if v.Name==name then return v end end
 if recursive then for _,v in ipairs(self.Children) do local got=v:FindFirstChild(name,true);if got then return got end end end
 return nil
end
function Node:FindFirstChildOfClass(name)
 for _,v in ipairs(self.Children) do if v:IsA(name) then return v end end
 return nil
end
function Node:GetAttribute(k)return self.attrs[k] end
local function n(k,name,props)return Node.new(k,name,props) end
local Players=n("Players","Players")
local localPlayer=Players:Add(n("Player","Self",{UserId=111}))
local partner=Players:Add(n("Player","Opponent",{UserId=222}))
Players.LocalPlayer=localPlayer
function Players:GetPlayers()return {localPlayer,partner} end
function Players:GetPlayerByUserId(uid)
 if tonumber(uid)==222 then return partner end
end
local gui=localPlayer:Add(n("PlayerGui","PlayerGui"))
local screen=gui:Add(n("ScreenGui","TradeGUI"))
local root=screen:Add(n("Frame","Container")):Add(n("Frame","Trade"))
local ourSide=root:Add(n("Frame","YourOffer"))
local theirSide=root:Add(n("Frame","TheirOffer"))
ourSide:Add(n("Frame","Accepted",{Visible=false}))
theirSide:Add(n("Frame","Accepted",{Visible=false}))
ourSide:Add(n("Frame","Container"))
theirSide:Add(n("Frame","Container"))
theirSide:Add(n("TextLabel","Username",{Text="(Opponent)"}))
local function slot(side,i,id,label,quantity,chroma)
 local container=side:FindFirstChild("Container")
 local s=container:Add(n("Frame","NewItem"..i))
 s.attrs.ItemId=id
 s:Add(n("Frame","ItemName")):Add(n("TextLabel","Label",{Text=label}))
 local cell=s:Add(n("Frame","Container"))
 cell:Add(n("TextLabel","Amount",{Text=quantity}))
 cell:Add(n("TextButton","ActionButton"))
 if chroma then s:Add(n("Frame","Tags")):Add(n("ImageLabel","Chroma")) end
 return s
end
local opponentSlot=slot(theirSide,1,"WatergunChroma","Watergun","",true)
local function inventory(id,page,checkerId,name,qty,typ)
 return {unmapped=0,unpriced=0,badQty=0,
   items={{id=id,page=page,checkerId=checkerId,name=name,qty=qty,
           cat="Weapons",type=typ or "Gun"}}}
end
local own=inventory("Immortal","godly","1032","Immortal",2)
own.items[2]={id="Mortal",page="godly",checkerId="1031",name="Mortal",qty=1,cat="Weapons",type="Knife"}
local other=inventory("WatergunChroma","chroma","810","Chroma Watergun",1)
local status={claimed=0,released=0,remotes=0,removals=0}
local scanner={
 getRecord=function(uid) assert(uid==222);return {state="whitelist",inv=other} end,
 getOwnInventory=function()return own end,
 claimStatusOwner=function(which)assert(which=="P4");status.claimed=status.claimed+1 end,
 releaseStatusOwner=function(which)assert(which=="P4");status.released=status.released+1 end,
}
local profile={isFresh=function()return true end}
local co
task={
 spawn=function(fn)
   co=coroutine.create(fn)
   local ok,why=coroutine.resume(co)
   assert(ok,tostring(why))
 end,
 wait=function()
   coroutine.yield()
 end
}
game={PlaceId=142823291,JobId="job-synthetic",
 GetService=function(_,service)assert(service=="Players");return Players end,
 HttpGet=function(_,url)
  local filename=url:match("([^/]+)%.lua$")
  local okNames={
    p4_observer_contract=true,p4_native_observer=true,
    p4_offer_executor=true,p4_native_offer=true,
    p4_risk_review=true,p4_dual_perspective=true,
    p4_strategy_permit=true,p4_coordinator=true,
    p4_safety_core=true,p4_removal_executor=true,
    p4_native_removal=true,p4_stability_gate=true}
  assert(okNames[filename],"unknown pinned module "..tostring(filename))
  local f=assert(io.open(dir.."/"..filename..".lua","r"))
  local text=f:read("*a");f:close();return text
 end}
local module=assert(loadfile(dir.."/PDIDDLER_PART4_REPLACEMENT.lua"))()
local sendCount=0
local approveCount=0
local now=.0
local epoch=1800000010
local G="godly:1031:checker-id"
local R="chroma:810:checker-id"
local function sourceContext()
 return {session="1:1",now=epoch,ownFingerprint="my-current-scan",
   opponentFingerprint="their-current-scan",
   ownInventory={[G]=1},opponentInventory={[R]=1},
   rawOwn={[G]={id="Mortal",page="godly",checkerId="1031",
      qty=1,type="Knife",cat="Weapons"}},
   market={sourceId="synthetic-source",verified=true,
      observedAt=epoch-300,validUntil=epoch+300,
      items={
        [G]={valueCents=13500,demand=3,stability="stable",
             verified=true,tradable=true},
        [R]={valueCents=230000,demand=5,stability="stable",
             verified=true,tradable=true}
      }}}
end
local capability={
 enabled=true,
 strategy={
   source=function()return "synthetic-source" end,
   wall=function()return epoch end,
   context=sourceContext,
   choose=function()
     return {give={{id=G,qty=1}},receive={{id=R,qty=1}}}
   end,
   approve=function(candidate,review,ctx,o)
     approveCount=approveCount+1
     assert(review.case~="BLOCKED")
     assert(review.reviewOnly==true and review.authorizesTrade==false)
     assert(review.authorizesAccept==false)
     return {allowed=true,session=o.session,
       ourSig=o.ourSig,theirSig=o.theirSig,
       source=ctx.market.sourceId,
       candidateKey=G.."#1=>"..R.."#1"}
   end
 },
 sendOnce=function(id,kind)
   assert(id=="Mortal" and kind=="Weapons")
   sendCount=sendCount+1
   return true
 end,
 recovery={
   enabled=true,
   clock=function()return now end,
   clickOnce=function(button,intent)
     assert(intent.kind=="REMOVE_ONE")
     assert(intent.id=="Mortal" and intent.slot==1)
     assert(button.Name=="ActionButton")
     status.removals=status.removals+1
     local container=ourSide:FindFirstChild("Container")
     for index,node in ipairs(container.Children) do
       if node.Name=="NewItem1" then
         table.remove(container.Children,index)
         node.Parent=nil
         return true
       end
     end
     return false
   end
 }
}
local c=module.run(scanner,profile,capability)
assert(c.state.active==true)
assert(c.state.lastObservation and c.state.lastObservation.contextOK)
assert(c.state.lastObservation.ourSlots==0 and c.state.lastObservation.theirSlots==1)
assert(c.state.authorizesTrade==false and c.state.authorizesAccept==false)
assert(approveCount==1)
assert(sendCount==1)
assert(status.removals==0)
assert(c.state.placementStatus:find("await-independent",1,true))
-- Independent GUI replication of the one-copy ADD, not the mock sender's ack.
slot(ourSide,1,"Mortal","Mortal","",false)
now=.12
local ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(c.state.lastObservation.ourSlots==1)
assert(c.state.placementStatus:find("VERIFIED",1,true))
assert(sendCount==1 and status.removals==0)
-- The opponent edits the offer AFTER placement. Stage23 must latch recovery
-- and use Stage11+14 to remove the local item without sending another ADD.
opponentSlot:FindFirstChild("Container"):FindFirstChild("Amount").Text="x2"
now=.24
ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(c.state.recoveryStatus:find("HOLD:",1,true))
assert(sendCount==1 and status.removals==0)
for _,t in ipairs({.32,.40,.48}) do
 now=t
 ok,why=coroutine.resume(co);assert(ok,tostring(why))
end
assert(status.removals==1,"expected one Stage11 defensive removal")
assert(sendCount==1,"never resend the offer")
now=.56
ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(c.state.authorizesTrade==false and c.state.authorizesAccept==false)
assert(status.removals==1)
-- Trade close must release Part3 status owner and never imply completion.
screen.Enabled=false
ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(c.state.active==false and status.released==1)
assert(c.state.authorizesAccept==false)
c.stop()
ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(not c.isAlive())
assert(sendCount==1 and status.removals==1)
print("PASS",1,"Stage23 actual Stage17 approval to Stage22 ADD to Stage11 removal")
