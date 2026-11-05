-- Multi-component offline integration replay. No MM2 instance or real input.
local dir=arg[1] or './'
local stage9=arg[2] or dir
local stage8=arg[3] or dir
package.path=dir..'/?.lua;'..stage9..'/?.lua;'..stage8..'/?.lua;'..package.path
local Safe=require('p4_safety_core')
local Observe=require('p4_observer_contract')
local Exec=require('p4_removal_executor')
local Native=require('p4_native_removal')
local n=0
local function check(name,fn)
    local ok,why=pcall(fn)
    if not ok then error(name..': '..tostring(why)) end
    n=n+1
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function slot(i,id,label,amount,chroma)
    return {slot=i,rawId=id,label=label,amountText=amount,chroma=chroma==true}
end
local inv={unmapped=0,unpriced=0,badQty=0,items={
    {id='Mortal',name='Mortal',qty=1,checkerId='1031',page='godly',cat='Weapons',type='Knife'},
    {id='Immortal',name='Immortal',qty=2,checkerId='1032',page='godly',cat='Weapons',type='Gun'},
    {id='EmbersickleChroma',name='Chroma Embersickle',qty=1,checkerId='1029',page='chroma',cat='Weapons',type='Knife'},
}}
local opponentInv={unmapped=0,unpriced=0,badQty=0,items={
    {id='WatergunChroma',name='Chroma Watergun',qty=1,checkerId='810',page='chroma',cat='Weapons',type='Gun'},
    {id='Sugar',name='Sugar',qty=1,checkerId='22',page='godly',cat='Weapons',type='Gun'},
}}
local Node={};Node.__index=Node
function Node:new(name)
    return setmetatable({Name=name,Parent=nil,Visible=true,Enabled=true,kids={}},self)
end
function Node:add(name)
    local x=Node:new(name);x.Parent=self;self.kids[name]=x;return x
end
function Node:IsA(kind) return kind=='GuiObject' end
function Node:FindFirstChild(name) return self.kids[name] end
local function setup()
    local root=Node:new('Trade')
    local items=root:add('YourOffer'):add('Container')
    local raw={session='sess',tradeOpen=true,contextOK=true,
        our={complete=true,accepted=false,slots={
            slot(1,'Mortal','Mortal','x1'),
            slot(2,'Immortal','Immortal','×2'),
            slot(3,'EmbersickleChroma','Embersickle','1',true),
        }},their={complete=true,accepted=false,slots={slot(1,'WatergunChroma','Watergun','x1',true)}}}
    for k=1,3 do items:add('NewItem'..k):add('Container'):add('ActionButton') end
    local function read()
        return Observe.normalize(raw,{marketFresh=true,ownInventory=inv,opponentInventory=opponentInv})
    end
    local clicks=0
    local native=Native.new({session='sess',observer={capture=function()return read()end},
        handle={config={session='sess',root=root}},clickOnce=function(button,intent)
            clicks=clicks+1
            if items:FindFirstChild('NewItem'..intent.slot):FindFirstChild('Container'):FindFirstChild('ActionButton')~=button then
                return false
            end
            for index,r in ipairs(raw.our.slots) do
                if r.slot==intent.slot then table.remove(raw.our.slots,index);break end
            end
            items.kids['NewItem'..intent.slot]=nil
            return true
        end})
    return {raw=raw,items=items,read=read,native=native,clicks=function()return clicks end}
end
check('Watergun removal -> 3-slot protected clear -> stable wait, no decline',function()
    local f=setup();local safety=Safe.new('sess');local executor=Exec.new('sess')
    local o,d=f.read();eq(d.authorizesTrade,false);eq(o.quoteSafe,false)
    local decision=Safe.step(safety,o,0);eq(decision,'REMOVE_ONE')
    local at=0
    for remaining=3,1,-1 do
        local snapshot=f.read()
        local action,intent=Exec.prepare(executor,'REMOVE_ONE',snapshot,at)
        eq(action,'DISPATCH');eq(intent.slot,remaining)
        eq(Exec.dispatched(executor,intent,Native.execute(f.native,intent),at+.01),'WAIT')
        local obs=f.read()
        eq(Exec.observe(executor,obs,at+.04),'VERIFIED')
        local nextAction=Safe.step(safety,obs,at+.05)
        eq(nextAction,remaining>1 and 'REMOVE_ONE' or 'HOLD')
        at=at+.14
    end
    eq(f.clicks(),3);eq(safety.mode,'WAIT_REPLAN')
    -- The opponent may take time to replace the Watergun; no repeat/decline.
    f.raw.their.slots={}
    eq(Safe.step(safety,f.read(),at+.2),'HOLD')
    f.raw.their.slots={slot(1,'Sugar','Sugar','1')}
    eq(Safe.step(safety,f.read(),at+.3),'HOLD')
    eq(Safe.step(safety,f.read(),at+1.1),'REQUEST_PLAN')
    eq(f.clicks(),3)
end)
check('stack x2 is one physical remove event despite two copies',function()
    local f=setup();local safety=Safe.new('sess');local executor=Exec.new('sess')
    f.raw.our.slots={slot(2,'Immortal','Immortal','×2')}
    f.items.kids.NewItem1=nil;f.items.kids.NewItem3=nil
    local before=f.read();eq(before.ourSlots,1);eq(before.ownItems[1].qty,2)
    eq(Safe.step(safety,before,0),'REMOVE_ONE')
    local action,intent=Exec.prepare(executor,'REMOVE_ONE',before,.1)
    eq(action,'DISPATCH');eq(intent.slot,2);eq(intent.qty,2)
    eq(Exec.dispatched(executor,intent,Native.execute(f.native,intent),.11),'WAIT')
    local after=f.read()
    eq(Exec.observe(executor,after,.2),'VERIFIED')
    eq(Safe.step(safety,after,.2),'HOLD')
    eq(f.clicks(),1)
end)
check('manual acceptance before a pending removal is not clicked',function()
    local f=setup();local executor=Exec.new('sess')
    local before=f.read();local _,intent=Exec.prepare(executor,'REMOVE_ONE',before,0)
    f.raw.our.accepted=true
    local receipt=Native.execute(f.native,intent)
    eq(receipt.status,'BLOCKED');eq(f.clicks(),0)
    eq(Exec.dispatched(executor,intent,receipt,.01),'ESCALATE')
end)
check('closed trade cannot receive stale remove',function()
    local f=setup();local executor=Exec.new('sess')
    local _,intent=Exec.prepare(executor,'REMOVE_ONE',f.read(),0)
    f.raw.tradeOpen=false
    eq(Native.execute(f.native,intent).status,'BLOCKED')
    eq(f.clicks(),0)
end)
print('PASS',n,'Stage 8/9/10 offline integration tests')
