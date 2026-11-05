-- Stage 16 pure research evaluator regression tests. All fixtures are synthetic.
local dir=arg[1] or './'
package.path=dir..'/?.lua;'..package.path
local R=require('p4_risk_review')
local n=0
local function test(name,fn)
    local ok,why=pcall(fn)
    if not ok then error('FAILED '..name..': '..tostring(why)) end
    n=n+1
end
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b)) end
local function copy(t)
    if type(t)~='table' then return t end
    local o={}
    for k,v in pairs(t) do o[k]=copy(v) end
    return o
end
local A='godly:11:checker-id'
local B='chroma:12:checker-id'
local C='godly:13:checker-id'
local D='ancient:14:checker-id'
local E='godly:15:checker-id'
local function item(value,demand,stability,flip,low,high)
    return {valueCents=value,demand=demand,stability=stability,
        flippability=flip,lowCents=low,highCents=high,
        verified=true,tradable=true}
end
local function fixture()
    local c={now=1000,market={sourceId='synthetic-snapshot-do-not-deploy',
        verified=true,observedAt=900,validUntil=2000,items={
        [A]=item(10000,2,'stable','flippable',10000,10000),
        [B]=item(12000,5,'doing_well','highly_flippable',11500,13000),
        [C]=item(20000,1,'underpaid','rarely_flippable',10000,22000),
        [D]=item(9000,6,'stable','highly_flippable',9000,9000),
        [E]=item(12000,5,'stable',nil,12000,12000),
    }},ownInventory={[A]=4,[B]=1,[C]=2},opponentInventory={[A]=2,[B]=2,[C]=2,[D]=1,[E]=2}}
    local p={give={{id=A,qty=1}},receive={{id=B,qty=1}}}
    return c,p
end
local function assess() local c,p=fixture();return R.assess(c,p),c,p end
local function noAuthority(r)
    eq(r.quoteSafe,false)
    eq(r.authorizesTrade,false)
    eq(r.authorizesAccept,false)
    eq(r.nativeReady,false)
    eq(r.reviewOnly,true)
end
local function blockedChange(change,reason)
    local c,p=fixture()
    change(c,p)
    local r=R.assess(c,p)
    eq(r.lane,'BLOCKED')
    if reason then eq(r.reason,reason) end
    noAuthority(r)
end
test('favorable conservative positive growth, better demand and flip',function()
    local r=assess()
    eq(r.lane,'REVIEW_FAVORABLE')
    eq(r.baseGainCents,2000)
    eq(r.conservativeGainCents,1500)
    eq(r.demandRelation,'better')
    eq(r.flippabilityRelation,'better')
    eq(r.stabilityExposureRelation,'unchanged')
    noAuthority(r)
end)
test('large nominal profit can still be caution due to poor demand',function()
    local c,p=fixture()
    p.receive={{id=C,qty=1}}
    local r=R.assess(c,p)
    eq(r.baseGainCents,10000)
    eq(r.demandRelation,'worse')
    eq(r.flippabilityRelation,'worse')
    eq(r.lane,'REVIEW_CAUTION')
    noAuthority(r)
end)
test('base positive but worst case negative is review caution',function()
    local c,p=fixture()
    c.market.items[B].lowCents=8000
    local r=R.assess(c,p)
    eq(r.baseGainCents,2000)
    eq(r.conservativeGainCents,-2000)
    eq(r.lane,'REVIEW_CAUTION')
end)
test('loss for better demand remains review-only',function()
    local c,p=fixture()
    p.receive={{id=D,qty=1}}
    local r=R.assess(c,p)
    eq(r.baseGainCents,-1000)
    eq(r.demandRelation,'better')
    eq(r.lane,'REVIEW_LOSS')
    noAuthority(r)
end)
test('unknown ranges explicitly prevent favorable verdict',function()
    local c,p=fixture()
    c.market.items[B].lowCents=nil
    c.market.items[B].highCents=nil
    local r=R.assess(c,p)
    eq(r.conservativeGainCents,nil)
    eq(r.lane,'REVIEW_CAUTION')
    eq(r.riskWarnings[3],'price-range-not-fully-verified')
end)
test('unknown flippability is not inferred from demand',function()
    local c,p=fixture();p.receive={{id=E,qty=1}}
    local r=R.assess(c,p)
    eq(r.demandRelation,'better')
    eq(r.flippabilityRelation,'unknown')
    eq(r.lane,'REVIEW_CAUTION')
end)
test('nominally equal prices are not automatically favorable',function()
    local c,p=fixture()
    c.market.items[B].valueCents=10000
    c.market.items[B].lowCents=9000
    local r=R.assess(c,p)
    eq(r.baseGainCents,0)
    eq(r.lane,'REVIEW_CAUTION')
end)
test('more than one stack copy remains a conservative warning',function()
    local c,p=fixture()
    p.give={{id=A,qty=2}}
    p.receive={{id=B,qty=2}}
    local r=R.assess(c,p)
    eq(r.baseGainCents,4000)
    eq(r.conservativeGainCents,3000)
    eq(r.lane,'REVIEW_FAVORABLE')
    local warnings=table.concat(r.riskWarnings,'|')
    assert(warnings:find('stack-trading-may-deviate',1,true))
end)
test('low demand unchanged outcome does not become acceptance probability',function()
    local c,p=fixture()
    c.market.items[A].demand=1
    c.market.items[B].demand=1
    local r=R.assess(c,p)
    eq(r.demandRelation,'unchanged')
    noAuthority(r)
end)
test('side effect free input untouched',function()
    local c,p=fixture()
    local a=copy(c);local b=copy(p)
    R.assess(c,p);R.assess(c,p)
    local function same(x,y)
        for k,v in pairs(x) do
            if type(v)=='table' then same(v,y[k]) else eq(v,y[k]) end
        end
    end
    same(c,a);same(p,b)
end)
test('expired source rejected',function()
    blockedChange(function(c)c.now=c.market.validUntil end,'source-missing-unverified-or-expired')
end)
test('source not yet observed rejected',function()
    blockedChange(function(c)c.now=899 end,'source-missing-unverified-or-expired')
end)
test('unverified source rejected',function()
    blockedChange(function(c)c.market.verified=false end,'source-missing-unverified-or-expired')
end)
test('source without identity rejected',function()
    blockedChange(function(c)c.market.sourceId='' end,'source-missing-unverified-or-expired')
end)
test('invalid time rejected',function()
    blockedChange(function(c)c.now=math.huge end,'source-missing-unverified-or-expired')
end)
test('unverified source item rejected',function()
    blockedChange(function(c)c.market.items[B].verified=false end,'receive-item-price-demand-or-stability-unverified')
end)
test('untradable source item rejected',function()
    blockedChange(function(c)c.market.items[B].tradable=false end,'receive-item-price-demand-or-stability-unverified')
end)
test('zero price rejected',function()
    blockedChange(function(c)c.market.items[B].valueCents=0 end,'receive-item-price-demand-or-stability-unverified')
end)
test('NaN price rejected',function()
    blockedChange(function(c)c.market.items[B].valueCents=0/0 end,'receive-item-price-demand-or-stability-unverified')
end)
test('noninteger price rejected',function()
    blockedChange(function(c)c.market.items[B].valueCents=1.3 end,'receive-item-price-demand-or-stability-unverified')
end)
test('unknown demand rejected',function()
    blockedChange(function(c)c.market.items[B].demand=nil end,'receive-item-price-demand-or-stability-unverified')
end)
test('bad demand outside ordinal accepted range rejected',function()
    blockedChange(function(c)c.market.items[B].demand=12 end,'receive-item-price-demand-or-stability-unverified')
end)
test('unknown stability rejected rather than assigned',function()
    blockedChange(function(c)c.market.items[B].stability='unknown' end,'receive-item-price-demand-or-stability-unverified')
end)
test('bad ranges rejected',function()
    blockedChange(function(c)c.market.items[B].lowCents=15000 end,'receive-price-range-invalid')
end)
test('partial ranges rejected',function()
    blockedChange(function(c)c.market.items[B].highCents=nil end,'receive-price-range-invalid')
end)
test('invalid flippability rejected',function()
    blockedChange(function(c)c.market.items[B].flippability='probably' end,'receive-flippability-invalid')
end)
test('unknown checker identity rejected',function()
    blockedChange(function(c,p)p.receive[1].id='godly:999:checker-id' end,'receive-item-price-demand-or-stability-unverified')
end)
test('display name not a source variant identity',function()
    blockedChange(function(c,p)p.give[1].id='Laser' end,'give-identity-quantity-or-duplicate-invalid')
end)
test('wrong tier excluded',function()
    blockedChange(function(c,p)p.give[1].id='vintage:10:checker-id' end,'give-identity-quantity-or-duplicate-invalid')
end)
test('own quantity unproven fails',function()
    blockedChange(function(c,p)p.give[1].qty=5 end,'give-identity-quantity-or-duplicate-invalid')
end)
test('opponent copy not owned',function()
    blockedChange(function(c,p)p.receive[1].qty=3 end,'receive-ownership-unproven')
end)
test('conservative 4-copy ceiling despite stack UI',function()
    blockedChange(function(c,p)
        p.give={{id=A,qty=4},{id=B,qty=1}}
    end,'give-conservative-four-copy-limit')
end)
test('duplicate item in same side rejected',function()
    blockedChange(function(c,p)p.give={{id=A,qty=1},{id=A,qty=1}} end,
        'give-identity-quantity-or-duplicate-invalid')
end)
test('same item on both sides rejected',function()
    blockedChange(function(c,p)p.receive={{id=A,qty=1}} end,
        'same-weapon-on-both-sides')
end)
test('empty bundle rejected',function()
    blockedChange(function(c,p)p.give={} end,'give-bundle-or-inventory-missing')
end)
test('sparse offer table cannot hide an unseen item',function()
    blockedChange(function(c,p)
        p.give={[1]={id=A,qty=1},[3]={id=B,qty=1}}
    end,'give-bundle-or-inventory-missing')
end)
test('non-numeric array key is rejected',function()
    blockedChange(function(c,p)
        p.give={{id=A,qty=1},noise={id=B,qty=1}}
    end,'give-bundle-or-inventory-missing')
end)
test('candidate list containing extra keyed entry rejected',function()
    local c,p=fixture()
    local values={[1]=p,extra=copy(p)}
    local out,why=R.reviewCandidates(c,values)
    eq(out,nil);eq(why,'candidate-budget-or-input-invalid')
end)
test('more than four physical rows rejected',function()
    blockedChange(function(c,p)p.give={{id=A,qty=1},{id=B,qty=1},
        {id=C,qty=1},{id=D,qty=1},{id=E,qty=1}}
    end,'give-bundle-or-inventory-missing')
end)
test('hard unsafe or underpaid received is not favorable',function()
    local c,p=fixture()
    c.market.items[B].stability='unsafe'
    local r=R.assess(c,p)
    eq(r.lane,'REVIEW_CAUTION')
end)
test('higher risky share means caution',function()
    local c,p=fixture()
    c.market.items[B].stability='fluctuating'
    local r=R.assess(c,p)
    eq(r.stabilityExposureRelation,'worse')
    eq(r.lane,'REVIEW_CAUTION')
end)
test('same-time market version cannot mint missing source',function()
    blockedChange(function(c)c.market.validUntil=c.market.observedAt end,
        'source-missing-unverified-or-expired')
end)
test('candidate review sorted by independent lanes, no execution',function()
    local c,p=fixture()
    local profit=copy(p)
    local risk=copy(p);risk.receive={{id=C,qty=1}}
    local loss=copy(p);loss.receive={{id=D,qty=1}}
    local invalid=copy(p);invalid.give={{id='Laser',qty=1}}
    local list,why=R.reviewCandidates(c,{loss,invalid,risk,profit})
    eq(why,nil)
    eq(#list.candidates,4)
    eq(list.candidates[1].index,4)
    eq(list.candidates[2].index,3)
    eq(list.candidates[3].index,1)
    eq(list.candidates[4].index,2)
    eq(list.authorizesTrade,false)
end)
test('candidate ordering deterministic on tie',function()
    local c,p=fixture()
    local x=R.reviewCandidates(c,{copy(p),copy(p),copy(p)})
    eq(x.candidates[1].index,1)
    eq(x.candidates[2].index,2)
    eq(x.candidates[3].index,3)
end)
test('candidate budget refuses silent truncation',function()
    local c,p=fixture()
    local rows={p,copy(p)}
    local r,why=R.reviewCandidates(c,rows,1)
    eq(r,nil);eq(why,'candidate-budget-or-input-invalid')
end)
test('review of no candidates returns empty result without approval',function()
    local c=fixture()
    local out=R.reviewCandidates(c,{})
    eq(#out.candidates,0)
    eq(out.quoteSafe,false)
end)
test('no Roblox or executor effects in pure module',function()
    local f=assert(io.open(dir..'/p4_risk_review.lua','r'))
    local code=f:read('*a');f:close()
    for _,bad in ipairs({'FireServer','InvokeServer','clickOnce','mouse1click',
        'VirtualInputManager','HttpGet','queue_on_teleport','setclipboard'}) do
        assert(not code:find(bad,1,true),'unsafe API in Stage16 module: '..bad)
    end
    assert(R.place==nil and R.accept==nil and R.click==nil)
end)
print('PASS',n,'Stage16 conservative risk candidate tests')
