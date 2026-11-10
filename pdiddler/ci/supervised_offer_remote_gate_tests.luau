-- Executes the ACTUAL supervised fork of pdiddler4_tradeio_v1 in Lune.
-- Current original v1 trade I/O is NOT modified or run against a live game.
-- No real Roblox services, network, Discord, price or item transactions.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local function assertEquals(a,b,name)
    assert(a==b,tostring(name)..": "..tostring(a).." != "..tostring(b))
end
local fired={}
local fakeTrade={Name="Trade",Visible=true}
function fakeTrade:IsA(name) return name=="GuiObject" end
local screen={Enabled=true}
function screen:IsA(name) return name=="ScreenGui" end
function screen:FindFirstChild(name)
    if name=="Container" then return self.Container end
end
screen.Container={Visible=true,Parent=screen}
function screen.Container:IsA(name) return name=="GuiObject" end
function screen.Container:FindFirstChild(name)
    if name=="Trade" then return fakeTrade end
end
local gui={}
fakeTrade.Parent=screen.Container
screen.Parent=gui
function gui:IsA(name) return name=="PlayerGui" end
function gui:FindFirstChild(name)
    if name=="TradeGUI" then return screen end
end
local remote={}
function remote:IsA(kind) return kind=="RemoteEvent" end
function remote:FireServer(raw,category)
    table.insert(fired,{raw=raw,category=category})
end
local tf={}
function tf:FindFirstChild(name)
    if name=="OfferItem" then return remote end
end
local root={}
function root:FindFirstChild(name)
    if name=="Trade" then return tf end
end
local localPlayer={}
function localPlayer:FindFirstChildOfClass(name)
    if name=="PlayerGui" then return gui end
end
local services={
    Players={LocalPlayer=localPlayer},
    ReplicatedStorage=root,
    VirtualInputManager={},
    GuiService={},
}
local game={
    GetService=function(_,name) return services[name] end,
}
local env={game=game}
local module=luau.load(source,{environment=env,injectGlobals=true})()
assert(type(module)=="table" and type(module.new)=="function")
local scanner={resolveOfferEntry=function() return nil end}
local checks=0
local function check(value,expected,label)
    checks+=1
    assertEquals(value,expected,label)
end
local function offered(io,item)
    local before=#fired
    local ok,reason=io.offerItem(item)
    check(#fired,before,"blocked remote stays silent")
    check(ok,false,"unapproved offer")
    check(type(reason),"string","blocked explanation")
    return reason
end
local default=module.new(scanner)
check(offered(default,{id="Scythe",name="Batwing"}),"SUPERVISED_OFFER_GATE_MISSING","default locked")
local permit={checkOutbound=function(item,openedTrade)
    return openedTrade==fakeTrade and item.id=="Scythe"
end}
local io=module.new(scanner,permit)
for _,item in ipairs({
    {id="Gingerscope",name="Fake"},
    {id="Scythe",rawKey="Gingerscope",name="Batwing"},
    {id="Scythe",name="Ginger Scope"},
    {id="Scythe",name="Gingerscope"},
    {id="Chroma Gingerscope",name="Chroma Gingerscope"},
    {id="Scythe",identity="Gingerscope",name="Batwing"},
}) do
    check(offered(io,item),"PROTECTED_GINGERSCOPE_OUTGOING","protected by raw/name")
end
for _,item in ipairs({
    {},{id=0,name="Batwing"},{id={},name="Batwing"},
    {id="",name="Batwing"},{id="Scythe",name="GingerScope"},
    {id="Scythe",name="Batwing",rawKey=123},
}) do
    local reason=offered(io,item)
    check(type(reason),"string","malformed explanation")
end
local bad={
    {checkOutbound=function() return "true" end},
    {checkOutbound=function() return 1 end},
    {checkOutbound=function() error("fake approval") end},
    {checkOutbound=true},
    {},
}
for _,v in ipairs(bad) do
    local obj=module.new(scanner,v)
    offered(obj,{id="Scythe",name="Batwing"})
end
-- Even a true gate must evaluate against the currently observed TRADE root.
local attempts=0
local rootChecked=module.new(scanner,{checkOutbound=function(item,t)
    attempts+=1
    return t==fakeTrade
end})
screen.Enabled=false
check(offered(rootChecked,{id="Scythe",name="Batwing"}),"TRADE_NOT_VISIBLE","no hidden trade mutation")
check(attempts,0,"policy not called for hidden GUI")
screen.Enabled=true
local before=#fired
local ok,reason=rootChecked.offerItem({id="Scythe",name="Batwing"})
check(ok,true,"one fresh approved offer")
check(reason,"fired","remote response")
check(#fired,before+1,"exactly one remote")
check(fired[#fired].raw,"Scythe","correct raw key")
check(fired[#fired].category,"Weapons","correct weapon category")
check(attempts,1,"one gate approval")
-- An approval returned after the window closes must not send a stale offer.
local delayed=module.new(scanner,{checkOutbound=function()
    screen.Enabled=false
    return true
end})
local result=offered(delayed,{id="Scythe",name="Batwing"})
check(result,"TRADE_CHANGED_DURING_AUTHORIZATION","session changed")
screen.Enabled=true
for _,changedField in ipairs({"id","name","rawKey"}) do
    local hostile=module.new(scanner,{checkOutbound=function(item)
        item[changedField]="Gingerscope"
        return true
    end})
    local reason=offered(hostile,{id="Scythe",name="Batwing"})
    check(reason,"OFFER_ITEM_CHANGED_DURING_AUTHORIZATION","callback mutation blocked")
end
-- The attempted authorization cannot substitute another (even nonprotected)
-- game raw key before the same physical offer is fired.
local swap=module.new(scanner,{checkOutbound=function(item)
    item.id="Emberbow"
    return true
end})
check(offered(swap,{id="Scythe",name="Batwing"}),
      "OFFER_ITEM_CHANGED_DURING_AUTHORIZATION","item identity cannot switch")

print("[PASS] original supervised tradeio fork remote mutation boundary:",checks)
print("[PASS] protected Gingerscope never outbound; default gate locked; no final Accept")
