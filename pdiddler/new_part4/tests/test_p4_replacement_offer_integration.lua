-- Stage22 replacement runtime: synthetic ONE permitted offer and independent GUI verification.
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
 s:Add(n("Frame","Container")):Add(n("TextLabel","Amount",{Text=quantity}))
 if chroma then s:Add(n("Frame","Tags")):Add(n("ImageLabel","Chroma")) end
 return s
end
slot(ourSide,1,"Immortal","Immortal","x2",false)
local opponentSlot=slot(theirSide,1,"WatergunChroma","Watergun","",true)
local function inventory(id,page,checkerId,name,qty,typ)
 return {unmapped=0,unpriced=0,badQty=0,
   items={{id=id,page=page,checkerId=checkerId,name=name,qty=qty,
           cat="Weapons",type=typ or "Gun"}}}
end
local own=inventory("Immortal","godly","1032","Immortal",2)
own.items[2]={id="Mortal",page="godly",checkerId="1031",name="Mortal",qty=1,cat="Weapons",type="Knife"}
local other=inventory("WatergunChroma","chroma","810","Chroma Watergun",1)
local status={claimed=0,released=0,remotes=0}
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
  assert(filename=="p4_observer_contract" or filename=="p4_native_observer"
      or filename=="p4_offer_executor" or filename=="p4_native_offer")
  local f=assert(io.open(dir.."/"..filename..".lua","r"))
  local text=f:read("*a");f:close();return text
 end}
local module=assert(loadfile(dir.."/PDIDDLER_PART4_REPLACEMENT.lua"))()
local sendCount=0
local issued=0
local capability={
 enabled=true,
 nextProposal=function(observation,report)
    issued=issued+1
    if issued>1 then return nil end
    return {session=observation.session,id="Mortal",page="godly",
       checkerId="1031",qty=1,
       ourSig=observation.ourSig,theirSig=observation.theirSig,
       permit="test-fixture-permit"}
 end,
 validatePermit=function(proposal,observation)
    return proposal.permit=="test-fixture-permit"
      and proposal.ourSig==observation.ourSig
      and proposal.theirSig==observation.theirSig
 end,
 sendOnce=function(id,kind)
    assert(id=="Mortal" and kind=="Weapons")
    sendCount=sendCount+1
    return true -- mock dispatch only; GUI changes in a later separate tick
 end
}
local c=module.run(scanner,profile,capability)
assert(c.state.active==true)
assert(c.state.lastObservation and c.state.lastObservation.contextOK)
assert(c.state.lastObservation.ourSlots==1 and c.state.lastObservation.theirSlots==1)
assert(c.state.lastObservation.ourSig~="" and c.state.quoteSafe==false)
assert(c.state.authorizesTrade==false and c.state.authorizesAccept==false)
assert(status.claimed==1 and status.released==0)
assert(sendCount==1)
assert(c.state.placementStatus:find("await-independent",1,true))
local oldSig=c.state.lastObservation.ourSig
-- A genuinely different UI snapshot is needed: a successful sendOnce is not
-- enough to satisfy the Stage22 executor.
slot(ourSide,2,"Mortal","Mortal","",false)
local ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(c.state.lastObservation.ourSig~=oldSig)
assert(c.state.placementStatus:find("VERIFIED",1,true))
assert(sendCount==1)
assert(c.state.authorizesTrade==false and c.state.authorizesAccept==false)
-- Trade close must release Part3 status owner and never imply completion.
screen.Enabled=false
ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(c.state.active==false and status.released==1)
assert(c.state.authorizesAccept==false)
c.stop()
ok,why=coroutine.resume(co);assert(ok,tostring(why))
assert(not c.isAlive())
assert(sendCount==1)
print("PASS",1,"Stage22 native-mock replacement integration: permitted ADD verified without Accept")
