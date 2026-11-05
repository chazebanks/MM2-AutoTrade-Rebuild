-- Stage 11 integrated test: real pure 8/9/10 modules + mocked native MM2 GUI.
local dir=arg[1] or './'
package.path=dir..'/?.lua;'..package.path
local Controller=require('p4_coordinator')
local Safety=require('p4_safety_core')
local Contract=require('p4_observer_contract')
local Observer=require('p4_native_observer')
local Exec=require('p4_removal_executor')
local Native=require('p4_native_removal')
local n=0
local function eq(a,b,label)
    assert(a==b,(label or 'equality')..' expected '..tostring(b)..', got '..tostring(a))
end
local function test(name,fn)
    local good,reason=pcall(fn)
    if not good then error('TEST '..name..': '..tostring(reason)) end
    n=n+1
end
local Node={}; Node.__index=Node
function Node:new(class,name,props)
    local x=setmetatable({ClassName=class,Name=name,Parent=nil,Children={},attrs={},Visible=true,Enabled=true},self)
    for k,v in pairs(props or {}) do x[k]=v end
    return x
end
function Node:add(child)
    child.Parent=self;self.Children[#self.Children+1]=child;return child
end
function Node:find(name)
    for _,x in ipairs(self.Children) do if x.Name==name then return x end end
end
function Node:remove(name)
    for i,x in ipairs(self.Children) do if x.Name==name then table.remove(self.Children,i);x.Parent=nil;return x end end
end
function Node:IsA(kind)
    return self.ClassName==kind or (kind=='GuiObject' and (
        self.ClassName=='Frame' or self.ClassName=='TextLabel'
        or self.ClassName=='ImageLabel' or self.ClassName=='TextButton'))
end
function Node:FindFirstChild(name,recursive)
    local x=self:find(name);if x then return x end
    if recursive then for _,v in ipairs(self.Children) do local found=v:FindFirstChild(name,true);if found then return found end end end
end
function Node:FindFirstChildOfClass(kind)
    for _,x in ipairs(self.Children) do if x:IsA(kind) then return x end end
end
function Node:GetAttribute(k)return self.attrs[k] end
local function node(kind,name,props) return Node:new(kind,name,props) end
local function inv(items)
    return {unmapped=0,unpriced=0,badQty=0,items=items}
end
local ourInv=inv({
    {id='Mortal',name='Mortal',qty=1,checkerId='1031',page='godly',cat='Weapons',type='Knife'},
    {id='Immortal',name='Immortal',qty=2,checkerId='1032',page='godly',cat='Weapons',type='Gun'},
    {id='EmbersickleChroma',name='Chroma Embersickle',qty=1,checkerId='1029',page='chroma',cat='Weapons',type='Knife'},
})
local theirInv=inv({
    {id='WatergunChroma',name='Chroma Watergun',qty=1,checkerId='810',page='chroma',cat='Weapons',type='Gun'},
    {id='Sugar',name='Sugar',qty=1,checkerId='22',page='godly',cat='Weapons',type='Gun'},
})
local function createSlot(container,num,id,label,amount,chroma)
    local s=container:add(node('Frame','NewItem'..num));s.attrs.ItemId=id
    s:add(node('Frame','ItemName')):add(node('TextLabel','Label',{Text=label}))
    s:add(node('Frame','Container')):add(node('TextLabel','Amount',{Text=amount}))
    s:FindFirstChild('Container'):add(node('TextButton','ActionButton'))
    if chroma then s:add(node('Frame','Tags')):add(node('ImageLabel','Chroma')) end
    return s
end
local function fixture(opts)
    opts=opts or {}
    local f={time=0,clicks={},receipts={},marketFresh=true,clickResult=true}
    f.players=node('Players','Players')
    f.self=f.players:add(node('Player','Self',{UserId=123}))
    f.partner=f.players:add(node('Player','Opponent',{UserId=999}))
    f.players.LocalPlayer=f.self
    function f.players:GetPlayerByUserId(id) if id==999 then return self:find('Opponent') end end
    f.pg=f.self:add(node('PlayerGui','PlayerGui'))
    f.screen=f.pg:add(node('ScreenGui','TradeGUI'))
    f.root=f.screen:add(node('Frame','Container')):add(node('Frame','Trade'))
    f.ours=f.root:add(node('Frame','YourOffer'))
    f.theirs=f.root:add(node('Frame','TheirOffer'))
    f.ours:add(node('Frame','Accepted',{Visible=false}))
    f.theirs:add(node('Frame','Accepted',{Visible=false}))
    f.ownSlots=f.ours:add(node('Frame','Container'))
    f.theirSlots=f.theirs:add(node('Frame','Container'))
    f.theirs:add(node('TextLabel','Username',{Text='(Opponent)'}))
    createSlot(f.ownSlots,1,'Mortal','Mortal','x1',false)
    createSlot(f.ownSlots,2,'Immortal','Immortal','×2',false)
    createSlot(f.ownSlots,3,'EmbersickleChroma','Embersickle','1',true)
    createSlot(f.theirSlots,1,'WatergunChroma','Watergun','x1',true)
    f.game={JobId='job-1',PlaceId=142823291}
    f.session='job-1:123:999:1'
    f.handle=Observer.new({contract=Contract,game=f.game,players=f.players,root=f.root,
        session=f.session,jobId='job-1',partnerUserId=999,localUserId=123,
        ownInventory=ourInv,opponentInventory=theirInv,
        marketFresh=function()return f.marketFresh end})
    local function clickOnce(button,intent)
        f.clicks[#f.clicks+1]={slot=intent.slot,id=intent.id,qty=intent.qty}
        if f.onClick then f.onClick(f,button,intent) end
        if not f.clickResult then return false end
        if not f.delayRemoval then f.ownSlots:remove('NewItem'..intent.slot) end
        return true
    end
    f.nativeHandle=Native.new({observer=Observer,handle=f.handle,session=f.session,
        clickOnce=clickOnce})
    f.coord=Controller.new({session=f.session,clock=function()return f.time end,
        observer=Observer,obsHandle=f.handle,safety=Safety,executor=Exec,
        native=Native,nativeHandle=f.nativeHandle,
        safetyOptions=opts.safetyOptions,executorOptions=opts.executorOptions})
    function f:tick(t) self.time=t;return Controller.tick(self.coord) end
    function f:status() return Controller.status(self.coord) end
    return f
end

test('one slot at a time: watergun removed, new sugar offered, three verifications',function()
    local f=fixture()
    local a=f:tick(0);eq(a,'HOLD');eq(#f.clicks,1)
    eq(f:status().waitingProof,true)
    local after=f:tick(.1);eq(after,'HOLD');eq(#f.clicks,1)
    eq(f:status().mode,'AWAIT_REMOVAL')
    f.theirSlots:remove('NewItem1')
    createSlot(f.theirSlots,1,'Sugar','Sugar','x1',false)
    eq(f:tick(.2),'HOLD');eq(#f.clicks,2)
    eq(f.clicks[2].qty,2)
    eq(f:tick(.3),'HOLD');eq(#f.clicks,2)
    eq(f:tick(.4),'HOLD');eq(#f.clicks,3)
    eq(f:tick(.5),'HOLD');eq(#f.clicks,3)
    eq(f:status().mode,'WAIT_REPLAN')
    eq(f:tick(1.4),'HOLD')
    eq(f:status().mode,'PLAN_REQUESTED')
    eq(f:tick(1.7),'HOLD')
    eq(f:status().waitingProof,false)
    eq(#f.clicks,3)
    eq(f:status().terminal,nil)
end)

test('no duplicate click while a removal is awaiting proof',function()
    local f=fixture();f.delayRemoval=true
    eq(f:tick(0),'HOLD');eq(#f.clicks,1)
    eq(f:tick(.4),'HOLD');eq(f:tick(.8),'HOLD');eq(#f.clicks,1)
    eq(f:tick(1.1),'DECLINE');eq(#f.clicks,1)
    eq(f:tick(1.2),'HOLD');eq(#f.clicks,1)
end)

test('partial stack change is verified and requests another removal later',function()
    local f=fixture();f.delayRemoval=true
    f.ownSlots:remove('NewItem1');f.ownSlots:remove('NewItem3')
    f.ownSlots:find('NewItem2'):find('Container'):find('Amount').Text='x2'
    eq(f:tick(0),'HOLD');eq(#f.clicks,1);eq(f.clicks[1].qty,2)
    -- Live Delta trace: two copies show x2, one copy has an empty Amount label.
    f.ownSlots:find('NewItem2'):find('Container'):find('Amount').Text=''
    eq(f:tick(.2),'HOLD');eq(#f.clicks,1)
    eq(f:tick(.3),'HOLD');eq(#f.clicks,2);eq(f.clicks[2].qty,1)
    f.ownSlots:remove('NewItem2')
    eq(f:tick(.4),'HOLD');eq(f:status().mode,'WAIT_REPLAN')
end)

test('opponent edits do not cancel in-flight removal',function()
    local f=fixture();f.delayRemoval=true
    eq(f:tick(0),'HOLD');eq(#f.clicks,1)
    f.theirSlots:remove('NewItem1')
    createSlot(f.theirSlots,1,'Sugar','Sugar','1',false)
    eq(f:tick(.1),'HOLD');eq(f:status().waitingProof,true)
    f.ownSlots:remove('NewItem3')
    eq(f:tick(.2),'HOLD');eq(f:status().mode,'AWAIT_REMOVAL')
    eq(f:tick(.3),'HOLD');eq(#f.clicks,2)
end)

test('opponent acceptance before click blocks native dispatch',function()
    local f=fixture()
    f.onClick=function()end
    -- Read accepts false to reserve intent, but acceptance appears during the
    -- native observer's fresh capture (second capture of the tick).
    local original=Observer.capture
    local calls=0
    local injected={capture=function(handle)
        calls=calls+1
        if calls==2 then f.theirs:find('Accepted').Visible=true end
        return original(handle)
    end}
    f.coord.observer=injected
    f.nativeHandle.config.observer=injected
    eq(f:tick(0),'DECLINE')
    eq(#f.clicks,0)
    eq(f:status().terminal,'DECLINE_REQUIRED')
end)

test('trade closes before native click: stop without stale decline',function()
    local f=fixture();local original=Observer.capture;local count=0
    local changed={capture=function(h)
        count=count+1
        if count==2 then f.screen.Enabled=false end
        return original(h)
    end}
    f.coord.observer=changed;f.nativeHandle.config.observer=changed
    eq(f:tick(0),'STOP')
    eq(#f.clicks,0)
end)

test('trade closes after remove dispatch: no stale click or decline',function()
    local f=fixture();eq(f:tick(0),'HOLD')
    f.screen.Enabled=false
    eq(f:tick(.2),'STOP');eq(f:tick(.4),'STOP')
    eq(#f.clicks,1)
end)

test('UI read missing local accept indicator: decline intent, no click',function()
    local f=fixture();f.ours:remove('Accepted')
    eq(f:tick(0),'DECLINE');eq(#f.clicks,0)
end)

test('market not fresh: no clicking, decline intent',function()
    local f=fixture();f.marketFresh=false
    eq(f:tick(0),'DECLINE');eq(#f.clicks,0)
end)

test('user manually accepted before first tick: no removal',function()
    local f=fixture();f.ours:find('Accepted').Visible=true
    eq(f:tick(0),'DECLINE');eq(#f.clicks,0)
end)

test('wrong job id stops without actions',function()
    local f=fixture();f.game.JobId='job-2'
    eq(f:tick(0),'STOP');eq(#f.clicks,0)
end)

test('root swapped stops without actions',function()
    local f=fixture();f.screen:find('Container'):remove('Trade')
    f.screen:find('Container'):add(node('Frame','Trade'))
    eq(f:tick(0),'STOP');eq(#f.clicks,0)
end)

test('native click attempted but uncertain: no repeat and escalates',function()
    local f=fixture();f.clickResult=false
    eq(f:tick(0),'DECLINE')
    eq(#f.clicks,1)
    eq(f:tick(.1),'HOLD')
    eq(#f.clicks,1)
end)

test('slow click callback exceeds dispatch window: decline, no repeat',function()
    local f=fixture()
    f.onClick=function(self) self.time=1.0 end
    eq(f:tick(0),'DECLINE')
    eq(#f.clicks,1)
end)

test('clock backward is blocked',function()
    local f=fixture();eq(f:tick(1),'HOLD')
    eq(f:tick(.9),'DECLINE')
    eq(#f.clicks,1)
end)

test('no reentrant click if callback polls recursively',function()
    local f=fixture();local nested
    f.onClick=function(self) nested=self.coord and Controller.tick(self.coord) end
    eq(f:tick(0),'HOLD')
    eq(nested,'HOLD')
    eq(#f.clicks,1)
end)

test('read-only report never authorizes new plan or acceptance',function()
    local f=fixture()
    f.ownSlots:remove('NewItem1');f.ownSlots:remove('NewItem2');f.ownSlots:remove('NewItem3')
    local observation,report=Observer.capture(f.handle)
    eq(report.authorizesTrade,false);eq(report.authorizesAccept,false)
    eq(observation.quoteSafe,false)
    eq(f:tick(0),'HOLD');eq(#f.clicks,0)
    eq(f:tick(.7),'HOLD')
    eq(f:status().mode,'PLAN_REQUESTED');eq(#f.clicks,0)
end)


test('opponent accepts between verified removals: queued next click is blocked',function()
    local f=fixture()
    eq(f:tick(0),'HOLD');eq(#f.clicks,1)
    eq(f:tick(.1),'HOLD');eq(f:status().mode,'AWAIT_REMOVAL')
    f.theirs:find('Accepted').Visible=true
    eq(f:tick(.2),'DECLINE');eq(#f.clicks,1)
end)

test('quote closes between verified removals: stop, no second click',function()
    local f=fixture()
    eq(f:tick(0),'HOLD');eq(f:tick(.1),'HOLD');eq(#f.clicks,1)
    f.screen.Enabled=false
    eq(f:tick(.2),'STOP');eq(#f.clicks,1)
end)

test('market becomes stale with removal pending: cancel new work',function()
    local f=fixture();f.delayRemoval=true
    eq(f:tick(0),'HOLD');eq(#f.clicks,1)
    f.marketFresh=false
    eq(f:tick(.1),'DECLINE');eq(#f.clicks,1)
end)

test('opponent switches three times while a removal awaits proof',function()
    local f=fixture();f.delayRemoval=true
    eq(f:tick(0),'HOLD');eq(#f.clicks,1)
    for j=1,3 do
        f.theirSlots:remove('NewItem1')
        if j%2==0 then
            createSlot(f.theirSlots,1,'Sugar','Sugar','x1',false)
        else
            createSlot(f.theirSlots,1,'WatergunChroma','Watergun','1',true)
        end
        eq(f:tick(j*.1),'HOLD');eq(#f.clicks,1)
    end
    f.ownSlots:remove('NewItem3')
    eq(f:tick(.4),'HOLD');eq(#f.clicks,1)
    eq(f:tick(.5),'HOLD');eq(#f.clicks,2)
end)

test('partner renamed inside same root: cannot click',function()
    local f=fixture();f.theirs:find('Username').Text='(SomeoneElse)'
    eq(f:tick(0),'DECLINE');eq(#f.clicks,0)
end)

test('native quote changes between coordinator read and click: blocked',function()
    local f=fixture();local capture=Observer.capture;local calls=0
    local altered={capture=function(h)
        calls=calls+1
        if calls==2 then
            f.ownSlots:find('NewItem3'):find('ItemName'):find('Label').Text='Not Chroma Embersickle'
        end
        return capture(h)
    end}
    f.coord.observer=altered;f.nativeHandle.config.observer=altered
    eq(f:tick(0),'DECLINE');eq(#f.clicks,0)
end)

print('PASS',n,'Stage 11 integrated observer/safety/removal tests')
