-- V8 native UI Accept cooldown tests: Lua 5.4 mock tree, no Roblox remotes.
local G=dofile("pdiddler/pdiddler4_accept_ui_gate_v1.lua")
local P=dofile("pdiddler/pdiddler4_supreme_policy_v5_NATIVE_READY.lua")
local count=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(err),0) end
    count=count+1; print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function node(kind,name,txt,parent)
    local n={kind=kind,Name=name,Text=txt or "",Visible=true,Enabled=true,children={},Parent=parent}
    function n:IsA(c)
        return self.kind==c or (c=="GuiButton" and (self.kind=="TextButton" or self.kind=="ImageButton"))
    end
    function n:FindFirstChild(s)
        for _,c in ipairs(self.children) do if c.Name==s then return c end end
    end
    function n:GetDescendants()
        local out={}
        local function visit(x)
            for _,c in ipairs(x.children) do out[#out+1]=c; visit(c) end
        end
        visit(self); return out
    end
    if parent then parent.children[#parent.children+1]=n end
    return n
end
local function scene()
    local root=node("Frame","Trade")
    local actions=node("Frame","Actions","",root)
    local accept=node("Frame","Accept","",actions)
    local button=node("TextButton","ActionButton","ACCEPT",accept)
    local overlay=node("TextLabel","Cooldown","Please wait (6) before accepting.",actions)
    return root,actions,accept,button,overlay
end
local function shown(n)
    local x=n
    while x do if x.Visible==false or x.Enabled==false then return false end; x=x.Parent end
    return true
end
test("visible native countdown takes precedence over green accept label",function()
    local root=scene()
    eq(G.read(root,shown),"cooldown")
end)
test("verified green ACCEPT only after countdown disappears",function()
    local root,_,_,_,overlay=scene()
    overlay.Visible=false
    eq(G.read(root,shown),"ready")
end)
test("a hidden ACCEPT or missing action fails closed",function()
    local root,actions,_,button,overlay=scene()
    overlay.Visible=false; button.Visible=false
    eq(G.read(root,shown),"unknown")
    actions.Visible=false
    eq(G.read(root,shown),"unknown")
end)
test("other player Accepted marker does not count as button ready",function()
    local root,_,_,button,overlay=scene()
    button.Text=""; overlay.Visible=false
    node("TextLabel","Accepted","ACCEPT",node("Frame","TheirOffer","",root))
    eq(G.read(root,shown),"unknown")
end)
test("the entire native 6-to-1 countdown blocks sweetening",function()
    local root,_,_,_,overlay=scene()
    for n=6,1,-1 do
        overlay.Text="Please wait ("..n..") before accepting."
        eq(G.read(root,shown),"cooldown")
    end
end)
test("green Accept must stay present for 2.5s",function()
    local s={}
    eq(G.step(s,"ours/theirs",6,"ready",false),false)
    eq(G.step(s,"ours/theirs",8.49,"ready",false),false)
    eq(G.step(s,"ours/theirs",8.50,"ready",false),true)
end)
test("offer replacement resets ready buffer",function()
    local s={}
    G.step(s,"ourA/theirA",6,"ready",false)
    eq(G.step(s,"ourB/theirA",8,"ready",false),false)
    eq(G.step(s,"ourB/theirA",10.49,"ready",false),false)
    eq(G.step(s,"ourB/theirA",10.5,"ready",false),true)
end)
test("brief reappearing countdown resets ready timer",function()
    local s={}
    G.step(s,"same",6,"ready",false)
    eq(G.step(s,"same",8,"cooldown",false),false)
    eq(G.step(s,"same",8.5,"ready",false),false)
    eq(G.step(s,"same",11,"ready",false),true)
end)
test("Accepted state freezes eligibility until ready re-proven",function()
    local s={}
    G.step(s,"same",6,"ready",false)
    eq(G.step(s,"same",9,"ready",true),false)
    eq(G.step(s,"same",9.1,"ready",false),false)
    eq(G.step(s,"same",11.6,"ready",false),true)
end)
local function plan(x)
    return {ok=true,rawTotal=x,rawProfit=100-x,units=1,givenExitScore=4,key=tostring(x),picks={}}
end
test("policy cannot sweeten before confirmed native gate",function()
    local s={}
    local plans={plan(70),plan(75),plan(80)}
    eq(P.negotiate(s,"their",70,plans,0,false,false),"accept-not-ready")
    eq(P.negotiate(s,"their",70,plans,9,false,false),"accept-not-ready")
    eq(s.steps,0)
    local action,nextPlan=P.negotiate(s,"their",70,plans,9.1,false,true)
    eq(action,"improve");assert(nextPlan.rawProfit>=15)
end)
test("policy cannot decline while button readiness is unknown",function()
    local s={}
    local plans={plan(70)}
    P.negotiate(s,"their",70,plans,0,false,false)
    eq(P.negotiate(s,"their",70,plans,59,false,false),"accept-not-ready")
    eq(s.steps,0)
    -- Overall 60s deadline is owned separately by P.observe.
    local timer={}
    eq(P.observe(timer,0,1,false),"active")
    eq(P.observe(timer,60,1,false),"overall-timeout")
end)
test("after last sweeten, final decline requires native readiness again",function()
    local s={signature="s",total=80,since=1,steps=2}
    eq(P.negotiate(s,"s",80,{},30,false,false),"accept-not-ready")
    eq(P.negotiate(s,"s",80,{},32,false,true),"final-wait")
    eq(P.negotiate(s,"s",80,{},36.9,false,true),"final-wait")
    eq(P.negotiate(s,"s",80,{},37,false,true),"decline")
end)
print("RESULT "..count.." V8 visible-accept-gate tests passed")
