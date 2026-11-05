-- Stage 10 injected-click native actuator mock. No Roblox click actually sent.
local root=arg[1] or './'
package.path=root..'/?.lua;'..package.path
local Native=require('p4_native_removal')
local Core=require('p4_removal_executor')
local count=0
local function check(name,fn)
    local ok,err=pcall(fn)
    if not ok then error('FAILED '..name..': '..tostring(err)) end
    count=count+1
end
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b)) end
local Node={};Node.__index=Node
function Node:new(name,kind)
    return setmetatable({Name=name,kind=kind or 'Frame',Visible=true,Enabled=true,Parent=nil,kids={}},self)
end
function Node:IsA(kind)
    return kind==self.kind or kind=='GuiObject' and self.kind~='ScreenGui'
end
function Node:FindFirstChild(name) return self.kids[name] end
function Node:add(name,kind)
    local n=Node:new(name,kind);n.Parent=self;self.kids[name]=n;return n
end
local function fixture()
    local rootTrade=Node:new('Trade')
    local own=rootTrade:add('YourOffer')
    local container=own:add('Container')
    local a=container:add('NewItem1');a:add('Container'):add('ActionButton','TextButton')
    local b=container:add('NewItem2');b:add('Container'):add('ActionButton','TextButton')
    local state={tradeOpen=true,session='sess',contextOK=true,
        ourAccepted=false,theirAccepted=false,ourSig='base',
        ownItems={{slot=1,id='Mortal',qty=1},{slot=2,id='Immortal',qty=2}},ourSlots=2}
    local read={capture=function(_handle) return state,{authorizesTrade=false} end}
    local handle={config={session='sess',root=rootTrade}}
    local calls=0
    local native=Native.new({observer=read,handle=handle,session='sess',clickOnce=function(button,intent)
        calls=calls+1;return button==b:FindFirstChild('Container'):FindFirstChild('ActionButton')
    end})
    local core=Core.new('sess')
    local action,intent=Core.prepare(core,'REMOVE_ONE',state,0)
    eq(action,'DISPATCH')
    return {root=rootTrade,own=own,container=container,state=state,observer=read,handle=handle,
        native=native,core=core,intent=intent,getCalls=function()return calls end}
end
check('native sends only one requested physical removal',function()
    local f=fixture()
    local receipt=Native.execute(f.native,f.intent)
    eq(receipt.status,'SENT_ONCE');eq(f.getCalls(),1)
    eq(Core.dispatched(f.core,f.intent,receipt,.01),'WAIT')
end)
check('replaying same token cannot click twice',function()
    local f=fixture();eq(Native.execute(f.native,f.intent).status,'SENT_ONCE')
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),1)
end)
check('changed opponent items do not block safe local withdrawal',function()
    local f=fixture();f.state.theirSig='opponent-replaced'
    eq(Native.execute(f.native,f.intent).status,'SENT_ONCE');eq(f.getCalls(),1)
end)
check('changed own signature blocks the removal',function()
    local f=fixture();f.state.ourSig='different'
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('accepted local side blocks',function()
    local f=fixture();f.state.ourAccepted=true
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('accepted other side blocks',function()
    local f=fixture();f.state.theirAccepted=true
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('stale session and closed window block',function()
    local f=fixture();f.state.tradeOpen=false
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
    local g=fixture();g.state.session='other'
    eq(Native.execute(g.native,g.intent).status,'BLOCKED');eq(g.getCalls(),0)
end)
check('incorrect item or quantity in slot blocks',function()
    local f=fixture();f.state.ownItems[2].qty=1
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('missing remove button blocks',function()
    local f=fixture();f.container:FindFirstChild('NewItem2'):FindFirstChild('Container').kids={}
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('hidden remove button blocks',function()
    local f=fixture();f.container:FindFirstChild('NewItem2'):FindFirstChild('Container'):FindFirstChild('ActionButton').Visible=false
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('click callback returning false is uncertain, not proof',function()
    local f=fixture();f.native.config.clickOnce=function() return false end
    local receipt=Native.execute(f.native,f.intent)
    eq(receipt.status,'ATTEMPT_UNCERTAIN');eq(receipt.attempted,true)
    eq(Core.dispatched(f.core,f.intent,receipt,.01),'ESCALATE')
end)
check('throwing click callback is not retried',function()
    local f=fixture();local hits=0
    f.native.config.clickOnce=function() hits=hits+1;error('native input error') end
    eq(Native.execute(f.native,f.intent).status,'ATTEMPT_UNCERTAIN')
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(hits,1)
end)
check('close handle disallows later clicks',function()
    local f=fixture();Native.close(f.native)
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('invalid intent cannot click',function()
    local f=fixture();f.intent.kind='ACCEPT'
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('observer exception fails closed',function()
    local f=fixture();f.native.config.observer.capture=function()error('UI destroyed')end
    eq(Native.execute(f.native,f.intent).status,'BLOCKED');eq(f.getCalls(),0)
end)
check('fully verified physical reduction requires a separate new snapshot',function()
    local f=fixture();local receipt=Native.execute(f.native,f.intent)
    eq(Core.dispatched(f.core,f.intent,receipt,.01),'WAIT')
    eq(Core.observe(f.core,f.state,.2),'HOLD')
    f.state.ownItems={{slot=1,id='Mortal',qty=1}}
    f.state.ourSlots=1;f.state.ourSig='after-remove'
    eq(Core.observe(f.core,f.state,.3),'VERIFIED')
    eq(f.core.mode,'IDLE')
end)
print('PASS',count,'Stage 10 native injected-click tests')
