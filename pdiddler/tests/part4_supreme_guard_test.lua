-- Execute production helpers with only Roblox objects and policy injected.
local file=assert(io.open(arg[1] or "pdiddler/pdiddler4_balancer_SUPREME_v1_TEST.lua")); local source=file:read("*a"); file:close()
local P=assert(loadfile("pdiddler/pdiddler4_supreme_policy_v1.lua"))()
local function extract(a,b)
    local start=assert(source:find("local function "..a.."(",1,true))
    local finish=assert(source:find("local function "..b.."(",start+1,true))
    return source:sub(start,finish-1)
end
local function node(name,parent,props)
    local n={Name=name,Parent=parent,Visible=true,Enabled=true,children={}}
    for k,v in pairs(props or {}) do n[k]=v end
    function n:IsA(c) return c=="GuiObject" or c=="TextLabel" end
    function n:FindFirstChild(k) return self.children[k] end
    function n:FindFirstChildOfClass(k) return self.children[k] end
    if parent then parent.children[name]=n end; return n
end
local pg=node("PlayerGui"); local lp=node("Local"); lp.children.PlayerGui=pg
local roster={}; local players={GetPlayers=function() return roster end}
local scope=setmetatable({Players=players,LP=lp,PG=pg,MARKET_LOGIC=P},{__index=_G})
local code=extract("norm","slotName")..extract("slotQty","readSide")..extract("fullShownName","theirAcceptedShown")..extract("resolveEntry","evaluateSide")
-- fullShownName region includes the immutable fallback table, which is inert.
local api=assert(load(code.."\nreturn {root=tradeRoot,partner=findPartner,qty=slotQty,resolve=resolveEntry}","production helpers","t",scope))()
local passed,failed=0,0
local function test(name,fn) local ok,err=pcall(fn); if ok then passed=passed+1; print("PASS "..name) else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end end
local function trade(gui,shown,visible)
    local g=node(gui,pg); local c=node("Container",g); local t=node("Trade",c,{Visible=visible~=false})
    local side=node("TheirOffer",t); node("Username",side,{Text=shown}); return t
end
test("hidden phone cannot mask visible tablet",function()
    trade("TradeGUI_Phone","Actual",false); local desktop=trade("TradeGUI","Actual",true); assert(api.root()==desktop)
end)
test("exact username wins over another player's display name",function()
    local impostor={Name="Wrong_User",DisplayName="Actual"}; local real={Name="Actual",DisplayName="Other"}; roster={impostor,real}
    assert(api.partner(trade("TradeGUI","@Actual"))==real)
end)
test("underscores remain meaningful in partner identity",function()
    local real={Name="Actual_User",DisplayName="ActualUser"}; roster={real}; assert(api.partner(trade("TradeGUI","ActualUser"))==nil)
end)
local inv={items={{page="godly",id="raw_A",checkerId="7",name="A",qty=2,value=100}},unmapped=0,unpriced=0,badQty=0}
test("explicit contradictory item id cannot fall back to name",function() assert(api.resolve({shown="A",internalId="raw_B",qty=1},inv)==nil) end)
test("unknown visible item remains unresolved",function() assert(api.resolve({shown="Unknown",qty=1},inv)==nil) end)
test("invalid live quantity cannot silently become one",function() assert(api.resolve({shown="A",qty=0},inv)==nil) end)
test("live quantity cannot exceed verified inventory",function() assert(api.resolve({shown="A",qty=3},inv)==nil) end)
test("correct raw id and name retain separate checker id",function() local r=assert(api.resolve({shown="A",internalId="raw_A",qty=1},inv)); assert(r.id=="raw_A" and r.checkerId=="7") end)
test("valid id with contradictory name remains unresolved",function() assert(api.resolve({shown="B",internalId="raw_A",qty=1},inv)==nil) end)
test("ambiguous same-name items remain unresolved",function() local x={items={inv.items[1],{page="ancient",id="other",name="A",qty=1,value=10}}}; assert(api.resolve({shown="A",qty=1},x)==nil) end)
test("slot malformed count is unresolved",function() local s=node("Slot"); local c=node("Container",s); node("Amount",c,{Text="x??"}); assert(api.qty(s)==nil) end)
print("RESULT "..passed.." passed, "..failed.." failed")
assert(failed==0)
