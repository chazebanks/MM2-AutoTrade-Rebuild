-- Stage 9 read-only native observer in a fake Roblox tree (not actual Roblox).
local dir=arg[1] or './'
package.path=dir..'/?.lua;'..package.path
local Native=require('p4_native_observer')
local Contract=require('p4_observer_contract')
local tests=0
local function check(name,fn)
    local ok,err=pcall(fn)
    if not ok then error('FAILED '..name..': '..tostring(err)) end
    tests=tests+1
end
local function equal(a,b)
    assert(a==b,tostring(a)..' ~= '..tostring(b))
end
local Node={}
Node.__index=Node
function Node:new(kind,name,props)
    local n=setmetatable({ClassName=kind,Name=name,Children={},attrs={},Parent=nil,Visible=true,Enabled=true},self)
    for k,v in pairs(props or {}) do n[k]=v end
    return n
end
function Node:Add(child)
    child.Parent=self
    self.Children[#self.Children+1]=child
    return child
end
function Node:IsA(kind)
    if self.ClassName==kind then return true end
    if kind=='GuiObject' then
        return self.ClassName=='Frame' or self.ClassName=='TextLabel'
            or self.ClassName=='TextButton' or self.ClassName=='ImageLabel'
    end
    return false
end
function Node:FindFirstChild(name,recursive)
    for _,v in ipairs(self.Children) do if v.Name==name then return v end end
    if recursive then
        for _,v in ipairs(self.Children) do
            local hit=v:FindFirstChild(name,true)
            if hit then return hit end
        end
    end
    return nil
end
function Node:FindFirstChildOfClass(kind)
    for _,v in ipairs(self.Children) do if v:IsA(kind) then return v end end
end
function Node:GetAttribute(name) return self.attrs[name] end
local function node(kind,name,props) return Node:new(kind,name,props) end
local function label(name,txt,visible)
    return node('TextLabel',name,{Text=txt,Visible=visible~=false})
end
local function addSlot(side,n,id,shown,amount,chroma)
    local container=side:FindFirstChild('Container')
    local slot=container:Add(node('Frame','NewItem'..n))
    if id then slot.attrs.ItemId=id end
    slot:Add(node('Frame','ItemName')):Add(label('Label',shown))
    slot:Add(node('Frame','Container')):Add(label('Amount',amount))
    if chroma then slot:Add(node('Frame','Tags')):Add(node('ImageLabel','Chroma')) end
    return slot
end
local function inventory(items)
    return {unmapped=0,unpriced=0,badQty=0,items=items}
end
local ownInventory=inventory({
    {id='Immortal',name='Immortal',qty=2,checkerId='1032',page='godly',cat='Weapons',type='Gun'},
    {id='Mortal',name='Mortal',qty=1,checkerId='1031',page='godly',cat='Weapons',type='Knife'},
})
local theirInventory=inventory({
    {id='WatergunChroma',name='Chroma Watergun',qty=1,checkerId='810',page='chroma',cat='Weapons',type='Gun'},
    {id='Sugar',name='Sugar',qty=1,checkerId='22',page='godly',cat='Weapons',type='Gun'},
})
local function setup(phone)
    local players=node('Players','Players')
    local localPlayer=node('Player','Self',{UserId=1234})
    local partner=node('Player','Opponent',{UserId=5678})
    players:Add(localPlayer);players:Add(partner)
    players.LocalPlayer=localPlayer
    function players:GetPlayerByUserId(id)
        if tonumber(id)==5678 then return partner end
    end
    local gui=localPlayer:Add(node('PlayerGui','PlayerGui'))
    local screen=gui:Add(node('ScreenGui',phone and 'TradeGUI_Phone' or 'TradeGUI'))
    local root=screen:Add(node('Frame','Container')):Add(node('Frame','Trade'))
    local ours=root:Add(node('Frame','YourOffer'))
    local theirs=root:Add(node('Frame','TheirOffer'))
    ours:Add(node('Frame','Accepted',{Visible=false}))
    theirs:Add(node('Frame','Accepted',{Visible=false}))
    ours:Add(node('Frame','Container'))
    theirs:Add(node('Frame','Container'))
    theirs:Add(label('Username','(Opponent)'))
    addSlot(ours,1,'Immortal','Immortal','x2',false)
    addSlot(theirs,1,'WatergunChroma','Watergun','1',true)
    local game={PlaceId=142823291,JobId='job-1'}
    local config={contract=Contract,game=game,players=players,root=root,session='job-1:1234:5678:1',
        jobId='job-1',localUserId=1234,partnerUserId=5678,
        ownInventory=ownInventory,opponentInventory=theirInventory,
        marketFresh=function() return true end}
    return {config=config,game=game,players=players,localPlayer=localPlayer,
        partner=partner,root=root,screen=screen,gui=gui,ours=ours,theirs=theirs}
end
check('native reads one stacked slot and exact opponent chroma',function()
    local t=setup();local obs,report=Native.capture(Native.new(t.config))
    equal(obs.tradeOpen,true);equal(obs.contextOK,true)
    equal(obs.ourSlots,1);equal(obs.ownItems[1].qty,2)
    equal(obs.theirResolved,true);equal(report.theirItems[1].id,'WatergunChroma')
    equal(obs.ourAccepted,false);equal(obs.theirAccepted,false)
    equal(obs.quoteSafe,false)
end)
check('native works on phone trade GUI path',function()
    local t=setup(true)
    local o=Native.capture(Native.new(t.config))
    equal(o.contextOK,true)
end)
check('detects opponent removing one weapon while local unchanged',function()
    local t=setup();local h=Native.new(t.config)
    local a=Native.capture(h)
    local container=t.theirs:FindFirstChild('Container')
    container.Children={} -- mocked removal
    local b=Native.capture(h)
    assert(a.theirSig~=b.theirSig)
    equal(a.ourSig,b.ourSig)
    equal(b.theirSlots,0)
end)
check('detects display change while count remains one',function()
    local t=setup();local h=Native.new(t.config)
    local a=Native.capture(h)
    local c=t.theirs:FindFirstChild('Container')
    c.Children={}
    addSlot(t.theirs,1,'Sugar','Sugar','x1',false)
    local b=Native.capture(h)
    assert(a.theirSig~=b.theirSig)
end)
check('blank native Amount label resolves one only with valid weapon identity',function()
    local t=setup()
    local item=t.ours:FindFirstChild('Container'):FindFirstChild('NewItem1')
    item.attrs={} -- real Delta showed NO_ID; use unique scanner name
    item:FindFirstChild('Container'):FindFirstChild('Amount').Text=''
    local o,d=Native.capture(Native.new(t.config))
    equal(o.contextOK,true)
    equal(o.ownItems[1].qty,1)
    equal(d.ourItems[1].origin,'unique-scanner-name')
    equal(o.quoteSafe,false)
end)
check('missing amount label never assumes qty one',function()
    local t=setup()
    local item=t.ours:FindFirstChild('Container'):FindFirstChild('NewItem1')
    item:FindFirstChild('Container').Children={}
    local o,report=Native.capture(Native.new(t.config))
    equal(o.contextOK,false);equal(#o.ownItems,0)
    assert(table.concat(report.errors,'|'):find('quantity-unverified',1,true))
end)
check('raw ID unavailable uses uniquely matched scanner metadata',function()
    local t=setup();local item=t.ours:FindFirstChild('Container'):FindFirstChild('NewItem1')
    item.attrs={}
    local o,d=Native.capture(Native.new(t.config))
    equal(o.contextOK,true);equal(d.ourItems[1].origin,'unique-scanner-name')
end)
check('missing native accepted indicator is UNKNOWN rather than false',function()
    local t=setup();t.ours.Children[1]=t.ours.Children[2];table.remove(t.ours.Children,2)
    local o,d=Native.capture(Native.new(t.config))
    equal(o.ourAccepted,nil);equal(o.contextOK,false)
    assert(table.concat(d.errors,'|'):find('our-accept-unverified',1,true))
end)
check('manual acceptance is observed without implying trade completion',function()
    local t=setup()
    t.ours:FindFirstChild('Accepted').Visible=true
    local o,d=Native.capture(Native.new(t.config))
    equal(o.ourAccepted,true);equal(d.provesCompletion,false)
end)
check('partner identity change blocks context even if original root remains',function()
    local t=setup()
    t.theirs:FindFirstChild('Username').Text='OtherPlayer'
    local o=Native.capture(Native.new(t.config))
    equal(o.contextOK,false)
end)
check('root replacement closes session and does not adopt replacement',function()
    local t=setup();local h=Native.new(t.config)
    local container=t.screen:FindFirstChild('Container')
    local newer=node('Frame','Trade')
    container.Children={newer};newer.Parent=container
    local o=Native.capture(h)
    equal(o.tradeOpen,false)
    equal(h.closed,true)
end)
check('trade closed once cannot reopen within same observer handle',function()
    local t=setup();local h=Native.new(t.config)
    t.screen.Enabled=false
    equal(Native.capture(h).tradeOpen,false)
    t.screen.Enabled=true
    equal(Native.capture(h).tradeOpen,false)
end)
check('different job cannot inherit old trade',function()
    local t=setup();local h=Native.new(t.config)
    t.game.JobId='job-2'
    local o=Native.capture(h)
    equal(o.tradeOpen,false)
end)
check('wrong MM2 place cannot produce live observations',function()
    local t=setup();local h=Native.new(t.config)
    t.game.PlaceId=1
    equal(Native.capture(h).tradeOpen,false)
end)
check('local user id changed closes session',function()
    local t=setup();local h=Native.new(t.config)
    t.localPlayer.UserId=778
    equal(Native.capture(h).tradeOpen,false)
end)
check('stale market callback leaves quote unapproved',function()
    local t=setup();t.config.marketFresh=function()return false end
    local o=Native.capture(Native.new(t.config))
    equal(o.marketFresh,false);equal(o.quoteSafe,false)
end)
check('market callback throwing does not mark fresh',function()
    local t=setup();t.config.marketFresh=function()error('offline')end
    local o=Native.capture(Native.new(t.config))
    equal(o.marketFresh,false);equal(o.quoteSafe,false)
end)
check('unknown UI exception returns invalid context without Roblox actions',function()
    local t=setup();t.root.GetAttribute=function()error('unexpected')end
    local o=Native.capture(Native.new(t.config))
    equal(o.contextOK,true) -- root attrs are not queried; only slot attrs are
    local item=t.ours:FindFirstChild('Container'):FindFirstChild('NewItem1')
    item.GetAttribute=function()error('failure')end
    o=Native.capture(Native.new(t.config))
    equal(o.contextOK,false)
    equal(o.quoteSafe,false)
end)
check('read-only source never invokes trade remote or simulated input',function()
    local f=assert(io.open(dir..'/p4_native_observer.lua','r'))
    local src=f:read('*a');f:close()
    for _,bad in ipairs({'FireServer','InvokeServer','SendMouseButtonEvent','queue_on_teleport','AcceptTrade','DeclineTrade'}) do
        assert(not src:find(bad,1,true),bad..' found in native observer source')
    end
end)
print('PASS',tests,'Stage 9 native mock tests')