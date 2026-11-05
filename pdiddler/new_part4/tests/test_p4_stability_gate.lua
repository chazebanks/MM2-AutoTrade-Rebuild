-- Stage 14 pure preflight validation; offline, no Roblox API or executor.
local dir=arg[1] or './'
package.path=dir..'/?.lua;'..package.path
local G=require('p4_stability_gate')
local n=0
local function check(name,fn)
    local ok,why=pcall(fn)
    if not ok then error('FAILED '..name..': '..tostring(why)) end
    n=n+1
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function snap()
    return {tradeOpen=true,contextOK=true,marketFresh=true,session='sess',
        ourAccepted=false,theirAccepted=false,ourSig='ours:iceblaster:x2',
        theirSig='theirs:watergun',ourSlots=1,theirSlots=1,theirResolved=true,
        ownItems={{slot=1,id='Iceblaster',qty=2}}}
end
local function ready(g,o)
    eq(G.observe(g,o,0),false)
    eq(G.observe(g,o,.08),false)
    eq(G.observe(g,o,.16),false)
    eq(G.observe(g,o,.24),true)
end
check('default gate requires independent samples over time',function()
    ready(G.new('sess'),snap())
end)
check('repeated timestamp never increases sample count',function()
    local g,o=G.new('sess'),snap()
    eq(G.observe(g,o,0),false)
    eq(G.observe(g,o,0),false)
    eq(g.samples,1)
    eq(G.observe(g,o,.11),false)
    eq(G.observe(g,o,.22),true)
end)
check('same-time changed offer resets accumulation',function()
    local g,o=G.new('sess'),snap()
    eq(G.observe(g,o,0),false)
    o.theirSig='other:new'
    eq(G.observe(g,o,0),false)
    eq(g.samples,0)
    eq(G.observe(g,o,.08),false)
    eq(G.observe(g,o,.16),false)
    eq(G.observe(g,o,.32),true)
end)
check('opponent edit resets gate, no stale quote authorization',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0);G.observe(g,o,.08)
    o.theirSig='their:sugar'
    eq(G.observe(g,o,.16),false);eq(g.samples,1)
    eq(G.observe(g,o,.24),false)
    eq(G.observe(g,o,.40),true)
end)
check('local quantity change resets gate',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0);G.observe(g,o,.08)
    o.ourSig='ours:iceblaster:blank';o.ownItems[1].qty=1
    eq(G.observe(g,o,.16),false);eq(g.samples,1)
end)
check('scanner identity changes under identical GUI text reset gate',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0);G.observe(g,o,.08)
    o.ownItems[1].id='AnotherItem'
    eq(G.observe(g,o,.16),false);eq(g.samples,1)
end)
check('acceptance becomes true: reset and no approval',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0);G.observe(g,o,.08)
    o.theirAccepted=true
    eq(G.observe(g,o,.16),false);eq(g.samples,0)
end)
check('missing acceptance reset',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0);o.ourAccepted=nil
    eq(G.observe(g,o,.08),false);eq(g.samples,0)
end)
check('missing/duplicated item identity never authorizes',function()
    local g,o=G.new('sess'),snap()
    o.ownItems[1].id=''
    eq(G.observe(g,o,0),false);eq(g.samples,0)
    o.ownItems={{slot=1,id='Iceblaster',qty=1},{slot=1,id='Iceblaster',qty=1}}
    o.ourSlots=2
    eq(G.observe(g,o,.08),false);eq(g.samples,0)
end)
check('stale market and context do not pass',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0)
    o.marketFresh=false
    eq(G.observe(g,o,.08),false);eq(g.samples,0)
    o.marketFresh=true;o.contextOK=false
    eq(G.observe(g,o,.16),false);eq(g.samples,0)
end)
check('gap above maximum restarts proof',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0);G.observe(g,o,.08)
    eq(G.observe(g,o,.50),false)
    eq(g.samples,1)
end)
check('wrong session invalidates gate',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,0);o.session='other'
    eq(G.observe(g,o,.08),false);eq(g.samples,0)
end)
check('backwards time invalidates gate',function()
    local g,o=G.new('sess'),snap()
    G.observe(g,o,.2)
    eq(G.observe(g,o,.1),false)
    eq(g.samples,0)
end)
check('invalid configuration is refused',function()
    for _,opts in ipairs({
        {minSamples=2},{minSeconds=.01},{maxGapSeconds=.01},
        {minSamples=0},{minSeconds=5}
    }) do
        eq(pcall(G.new,'sess',opts),false)
    end
end)
print('PASS',n,'Stage14 pure stability gate tests')
