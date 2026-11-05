-- Stage 17 synthetic bilateral-review regression suite (never native actions).
local dir=arg[1] or './'
package.path=dir..'/?.lua;'..package.path
local D=require('p4_dual_perspective')
local n=0
local function test(name,fn)
    local ok,why=pcall(fn)
    if not ok then error('FAILED '..name..': '..tostring(why)) end
    n=n+1
end
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b)) end
local function contains(rows,name)
    for _,v in ipairs(rows) do if v==name then return true end end
    return false
end
local function copy(t)
    if type(t)~='table' then return t end
    local o={}
    for k,v in pairs(t) do o[k]=copy(v) end
    return o
end
local A='godly:11:checker-id'
local B='chroma:12:checker-id'
local C='ancient:13:checker-id'
local D1='godly:14:checker-id'
local E='godly:15:checker-id'
local function item(value,demand,stability,flip)
    return {valueCents=value,lowCents=value,highCents=value,
        demand=demand,stability=stability,flippability=flip,
        verified=true,tradable=true}
end
local function fixture()
    local ctx={now=1000,market={sourceId='synthetic-no-deployment',
        verified=true,observedAt=900,validUntil=2000,items={
            [A]=item(10000,2,'stable','flippable'),
            [B]=item(12000,5,'stable','highly_flippable'),
            [C]=item(15000,1,'unsafe','rarely_flippable'),
            [D1]=item(9000,8,'stable','highly_flippable'),
            [E]=item(8000,8,'stable','highly_flippable'),
        }},ownInventory={[A]=4,[B]=2,[C]=1,[D1]=1,[E]=1},
        opponentInventory={[A]=2,[B]=2,[C]=1,[D1]=1}}
    return ctx,{give={{id=A,qty=1}},receive={{id=B,qty=1}}}
end
local function noAuthority(r)
    eq(r.quoteSafe,false);eq(r.authorizesTrade,false)
    eq(r.authorizesAccept,false);eq(r.nativeReady,false)
    eq(r.reviewOnly,true)
    eq(r.preferencesVerified,false)
    eq(r.acceptanceProbability,nil)
end
test('large own gain with no seller upside is explicitly unproven',function()
    local c,p=fixture()
    local r=D.assess(c,p)
    eq(r.case,'UNPROVEN_SELLER_CASE')
    eq(r.ourGainCents,2000)
    eq(r.sellerSurplusCents,-2000)
    eq(r.sellerCoverageBasisPoints,8333)
    eq(r.ourReview.demandRelation,'better')
    eq(r.sellerDemandRelation,'worse')
    eq(r.sellerFlippabilityRelation,'worse')
    assert(contains(r.warnings,'seller-gives-more-listed-value-than-receives'))
    noAuthority(r)
end)
test('seller quality tradeoff is distinct from listed-value gain',function()
    local c,p=fixture()
    p.give={{id=D1,qty=1}}
    local r=D.assess(c,p)
    eq(r.case,'QUALITY_TRADEOFF')
    eq(r.sellerCoverageBasisPoints,7500)
    eq(r.sellerDemandRelation,'better')
    eq(r.sellerFlippabilityRelation,'unchanged')
    eq(r.sellerSurplusCents,-3000)
    noAuthority(r)
end)
test('seller monetary gain exposes our loss without approving it',function()
    local c,p=fixture()
    p.give={{id=B,qty=1}}
    p.receive={{id=A,qty=1}}
    local r=D.assess(c,p)
    eq(r.case,'VALUE_CASE')
    eq(r.ourReview.lane,'REVIEW_LOSS')
    eq(r.sellerSurplusCents,2000)
    eq(r.sellerCoverageBasisPoints,12000)
    assert(contains(r.warnings,'our-listed-value-loss-requires-independent-justification'))
    noAuthority(r)
end)
test('seller listed gain can still have damaging demand and stability',function()
    local c,p=fixture()
    p.give={{id=C,qty=1}}
    local r=D.assess(c,p)
    eq(r.case,'VALUE_CASE')
    eq(r.sellerSurplusCents,3000)
    eq(r.sellerQualityDownside,true)
    assert(contains(r.warnings,'seller-quality-mixed-or-worse'))
    noAuthority(r)
end)
test('seller receives more copies and slots warnings independently',function()
    local c,p=fixture()
    p.give={{id=A,qty=1},{id=E,qty=1}}
    local r=D.assess(c,p)
    eq(r.case,'VALUE_CASE')
    eq(r.sellerReceivedCopies,2)
    eq(r.sellerReceivedSlots,2)
    assert(contains(r.warnings,'seller-receives-more-individual-copies'))
    assert(contains(r.warnings,'seller-receives-more-visible-item-types'))
    noAuthority(r)
end)
test('stacked copies count as copies not physical slots',function()
    local c,p=fixture()
    p.give={{id=A,qty=2}}
    local r=D.assess(c,p)
    eq(r.sellerReceivedCopies,2)
    eq(r.sellerReceivedSlots,1)
    assert(contains(r.warnings,'seller-receives-more-individual-copies'))
    assert(not contains(r.warnings,'seller-receives-more-visible-item-types'))
    noAuthority(r)
end)
test('missing price ranges are not silently assumed conservative',function()
    local c,p=fixture()
    c.market.items[B].lowCents=nil;c.market.items[B].highCents=nil
    local r=D.assess(c,p)
    eq(r.sellerConservativeGainCents,nil)
    assert(contains(r.warnings,'seller-conservative-price-range-unverified'))
    noAuthority(r)
end)
test('unknown flippability remains unknown',function()
    local c,p=fixture()
    c.market.items[A].flippability=nil
    local r=D.assess(c,p)
    eq(r.sellerFlippabilityRelation,'unknown')
    assert(contains(r.warnings,'seller-resale-proxy-unknown'))
    noAuthority(r)
end)
test('expired source blocks even a superficially favorable trade',function()
    local c,p=fixture()
    c.now=c.market.validUntil
    local r=D.assess(c,p)
    eq(r.case,'BLOCKED')
    noAuthority(r)
end)
test('unverified opponent ownership blocks',function()
    local c,p=fixture()
    c.opponentInventory[B]=nil
    local r=D.assess(c,p)
    eq(r.case,'BLOCKED')
    noAuthority(r)
end)
test('tier/name collision cannot pass by display name',function()
    local c,p=fixture()
    p.give[1].id='Laser'
    local r=D.assess(c,p)
    eq(r.case,'BLOCKED')
    noAuthority(r)
end)
test('oversized stack blocks through Stage16 invariant',function()
    local c,p=fixture()
    p.give={{id=A,qty=4},{id=E,qty=1}}
    local r=D.assess(c,p)
    eq(r.case,'BLOCKED')
    noAuthority(r)
end)
test('seller evaluation does not mutate inputs',function()
    local c,p=fixture()
    local cc=copy(c);local pp=copy(p)
    D.assess(c,p);D.assess(c,p)
    local function check(a,b)
        for k,v in pairs(a) do
            if type(v)=='table' then check(v,b[k]) else eq(v,b[k]) end
        end
    end
    check(c,cc);check(p,pp)
end)
test('multi candidate lanes preserve input identity, not acceptance rank',function()
    local c,p=fixture()
    local quality=copy(p);quality.give={{id=D1,qty=1}}
    local sellerValue=copy(p);sellerValue.give={{id=B,qty=1}};sellerValue.receive={{id=A,qty=1}}
    local invalid=copy(p);invalid.receive={{id='Laser',qty=1}}
    local rows,why=D.reviewCandidates(c,{p,quality,sellerValue,invalid})
    eq(why,nil);eq(rows.count,4)
    eq(#rows.valueCases,1);eq(rows.valueCases[1].index,3)
    eq(#rows.qualityTradeoffs,1);eq(rows.qualityTradeoffs[1].index,2)
    eq(#rows.unproven,1);eq(rows.unproven[1].index,1)
    eq(#rows.blocked,1);eq(rows.blocked[1].index,4)
    eq(rows.authorizesAccept,false);eq(rows.quoteSafe,false)
end)
test('empty candidate review remains empty and inert',function()
    local c=fixture()
    local rows=D.reviewCandidates(c,{})
    eq(rows.count,0);eq(#rows.valueCases,0)
    eq(rows.authorizesTrade,false)
end)
test('candidate cap refuses silent omission',function()
    local c,p=fixture()
    local rows,why=D.reviewCandidates(c,{p,copy(p)},1)
    eq(rows,nil);eq(why,'candidate-input-or-budget-invalid')
end)
test('sparse and extraneous keyed candidates fail closed',function()
    local c,p=fixture()
    local a,why=D.reviewCandidates(c,{[1]=p,[3]=copy(p)})
    eq(a,nil);eq(why,'candidate-input-or-budget-invalid')
    local b,why2=D.reviewCandidates(c,{p,extra=copy(p)})
    eq(b,nil);eq(why2,'candidate-input-or-budget-invalid')
end)
test('no native action APIs in research module',function()
    local f=assert(io.open(dir..'/p4_dual_perspective.lua','r'))
    local src=f:read('*a');f:close()
    for _,s in ipairs({'FireServer','InvokeServer','HttpGet','VirtualInputManager',
        'mouse1click','queue_on_teleport','setclipboard'}) do
        assert(not src:find(s,1,true),'forbidden native effect in research: '..s)
    end
    assert(D.accept==nil and D.place==nil and D.click==nil)
end)
print('PASS',n,'Stage17 bilateral counterparty review tests')
