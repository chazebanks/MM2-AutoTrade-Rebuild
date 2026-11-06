-- Stage28 integration: actual Stage9 GUI reader into new passive timeline.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local Native=require("p4_native_observer")
local Contract=require("p4_observer_contract")
local Timeline=require("p4_stage28_accept_timeline")
local tests=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(err)) end
 tests=tests+1
end
local N={};N.__index=N
function N.new(kind,name,props)
 local v=setmetatable({ClassName=kind,Name=name,Children={},
  attrs={},Parent=nil,Visible=true,Enabled=true},N)
 for k,x in pairs(props or {}) do v[k]=x end
 return v
end
function N:Add(k) k.Parent=self;self.Children[#self.Children+1]=k;return k end
function N:FindFirstChild(k,recursive)
 for _,child in ipairs(self.Children) do if child.Name==k then return child end end
 if recursive then for _,child in ipairs(self.Children) do
  local out=child:FindFirstChild(k,true);if out then return out end
 end end
end
function N:FindFirstChildOfClass(c)
 for _,child in ipairs(self.Children) do
  if child:IsA(c) then return child end
 end
end
function N:IsA(c)
 if self.ClassName==c then return true end
 return c=="GuiObject" and
  (self.ClassName=="Frame" or self.ClassName=="TextLabel"
   or self.ClassName=="TextButton" or self.ClassName=="ImageLabel")
end
function N:GetAttribute(k)return self.attrs[k] end
local function node(k,name,props)return N.new(k,name,props)end
local function slot(side,idx,name,id)
 local s=side:FindFirstChild("Container"):Add(node("Frame","NewItem"..idx))
 s.attrs.ItemId=id
 s:Add(node("Frame","ItemName")):Add(node("TextLabel","Label",{Text=name}))
 s:Add(node("Frame","Container")):Add(node("TextLabel","Amount",{Text=""}))
 return s
end
local function inventory(id,name,checker,page)
 return {items={{id=id,name=name,checkerId=checker,page=page,qty=1,
     cat="Weapons",type="Knife"}},unmapped=0,unpriced=0,badQty=0}
end
local function setup()
 local players=node("Players","Players")
 local me=players:Add(node("Player","Local",{UserId=11}))
 local partner=players:Add(node("Player","Partner",{UserId=22}))
 players.LocalPlayer=me
 function players:GetPlayerByUserId(n)if n==22 then return partner end end
 local pg=me:Add(node("PlayerGui","PlayerGui"))
 local screen=pg:Add(node("ScreenGui","TradeGUI"))
 local root=screen:Add(node("Frame","Container")):Add(node("Frame","Trade"))
 local our=root:Add(node("Frame","YourOffer"))
 local their=root:Add(node("Frame","TheirOffer"))
 local ownAccept=our:Add(node("Frame","Accepted",{Visible=false}))
 local theirAccept=their:Add(node("Frame","Accepted",{Visible=false}))
 our:Add(node("Frame","Container"))
 their:Add(node("Frame","Container"))
 their:Add(node("TextLabel","Username",{Text="(Partner)"}))
 slot(our,1,"Mortal","Mortal")
 slot(their,1,"Nightblade","Nightblade")
 local game={PlaceId=142823291,JobId="same-job"}
 local h=Native.new({
  game=game,players=players,root=root,session="native-s1",
  jobId="same-job",localUserId=11,partnerUserId=22,
  ownInventory=inventory("Mortal","Mortal","1031","godly"),
  opponentInventory=inventory("Nightblade","Nightblade","105","godly"),
  contract=Contract,marketFresh=function()return true end
 })
 local s=Timeline.new("native-s1",1)
 return {h=h,s=s,screen=screen,our=our,their=their,
     ownAccept=ownAccept,theirAccept=theirAccept,game=game}
end
local function poll(f,t)
 local o,d=Native.capture(f.h)
 return Timeline.ingest(f.s,o,d,t)
end
test("native UI first read is explicitly unaccepted",function()
 local f=setup()
 assert(poll(f,1.1)=="OBSERVED")
 local r=Timeline.summary(f.s)
 assert(r.status=="NEITHER")
 assert(not r.ourAcceptIndicatorEverVisible)
 assert(not r.theirAcceptIndicatorEverVisible)
end)
test("partner manually accepts; no local Accept or any completion",function()
 local f=setup()
 poll(f,1.1);f.theirAccept.Visible=true
 assert(poll(f,1.2)=="OBSERVED")
 local r=Timeline.summary(f.s)
 assert(r.status=="THEIRS_ONLY" and r.theirAcceptIndicatorEverVisible)
 assert(not r.ourAcceptIndicatorEverVisible)
 assert(not r.authorizesAccept and not r.mayReportProfit)
end)
test("both native accepted icons and later window close remain unknown",function()
 local f=setup()
 poll(f,1.1)
 f.ownAccept.Visible=true;f.theirAccept.Visible=true
 assert(poll(f,1.2)=="HOLD")
 assert(poll(f,1.4)=="OBSERVED")
 assert(Timeline.summary(f.s).bothAcceptedStableObserved==true)
 f.screen.Enabled=false
 assert(poll(f,1.5)=="CLOSED_UNKNOWN")
 local r=Timeline.summary(f.s)
 assert(r.closureStatus=="closed_unknown"
  and r.serverCompletionProven==false
  and r.mayRecordCompletedTrade==false)
end)
test("offer swap after manual acceptance taints timeline",function()
 local f=setup()
 poll(f,1.1)
 f.theirAccept.Visible=true;poll(f,1.2)
 local container=f.their:FindFirstChild("Container")
 container.Children={}
 slot(f.their,1,"Nightblade","Nightblade")
 local item=container:FindFirstChild("NewItem1")
 item:FindFirstChild("Container"):FindFirstChild("Amount").Text="x1"
 assert(poll(f,1.3)=="HOLD")
 assert(Timeline.summary(f.s).offerMutationAfterAccept)
end)
test("root reuse after closing does not restart old timeline",function()
 local f=setup()
 poll(f,1.1)
 f.screen.Enabled=false;poll(f,1.2)
 f.screen.Enabled=true
 assert(poll(f,1.3)=="HOLD")
 assert(f.s.phase=="CLOSED_UNKNOWN")
end)
test("empty local side tracks theirs Accept as icon only, not valid exchange",function()
 local f=setup()
 f.our:FindFirstChild("Container").Children={}
 f.theirAccept.Visible=true
 assert(poll(f,1.1)=="HOLD")
 local r=Timeline.summary(f.s)
 assert(r.theirAcceptIndicatorEverVisible)
 assert(r.offerMutationAfterAccept)
 assert(not r.anyBothAccepted)
 assert(r.status=="UNRESOLVED")
 assert(not r.serverCompletionProven)
end)
test("client job change closes observer but doesn't verify completion",function()
 local f=setup()
 poll(f,1.1)
 f.game.JobId="other-job"
 assert(poll(f,1.2)=="CLOSED_UNKNOWN")
 assert(not Timeline.summary(f.s).serverCompletionProven)
end)
print("PASS",tests,"Stage28 actual Stage9 native acceptance and closure mock integration")
