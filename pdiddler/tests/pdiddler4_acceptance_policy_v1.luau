print("MM2 ADAPTIVE ACCEPTANCE POLICY TEST")

local logic=require("../pdiddler4_market_logic_v2_ACCEPTANCE")
local policy=require("../pdiddler4_acceptance_policy_v1")

local pass=0
local function case(name,fn)
    fn()
    pass+=1
    print("PASS "..name)
end
local function eq(a,b,msg)
    assert(a==b,(msg or "eq").." expected="..tostring(b).." got="..tostring(a))
end
local function ok(v,msg) assert(v,msg or "assertion failed") end

local function prof(mm2,sup,demand,stability,verified)
    return {
        mm2Value=mm2,
        supremeValue=sup,
        supremeLabel=tostring(sup),
        demand=demand,
        stability=stability,
        profiled=true,
        verified=verified~=false,
    }
end

local profiles={
    ["godly:huge"]=prof(500,500,8,"Doing Well"),
    ["godly:strong100"]=prof(100,100,8,"Doing Well"),
    ["godly:stable100"]=prof(100,100,5,"Stable"),
    ["godly:stable120"]=prof(120,120,5,"Stable"),
    ["godly:stable80"]=prof(80,80,5,"Stable"),
    ["godly:stable40"]=prof(40,40,5,"Stable"),
    ["godly:stable20"]=prof(20,20,5,"Stable"),
    ["godly:weak95"]=prof(95,95,1,"Underpaid For"),
    ["godly:weak60"]=prof(60,60,1,"Underpaid For"),
    ["godly:fluct90"]=prof(90,90,5,"Fluctuating"),
    ["godly:disputed100"]=prof(100,150,8,"Doing Well"),
    ["godly:low30"]=prof(30,30,3,"Stable"),
    ["godly:481"]=prof(35,35,8,"Doing Well"),
}
local profile={liveReady=true}
function profile.get(page,id)
    return profiles[tostring(page)..":"..tostring(id)]
end

local function item(id,value,qty,page)
    return {
        page=page or "godly",
        id=tostring(id),
        name=tostring(id),
        value=value,
        qty=qty or 1,
    }
end

local partner={
    items={
        item("stable120",120),
        item("stable80",80),
        item("stable40",40),
        item("stable20",20),
    }
}

case("opener skips unreachable highest and selects attractive reachable",function()
    local own={items={
        item("huge",500),
        item("weak95",95),
        item("strong100",100),
    }}
    local picked,meta=policy.selectOpener(own,partner,profile,logic)
    ok(picked,"expected reachable opener")
    eq(picked.id,"strong100","must not use unreachable highest or weak opener")
    eq(meta.partnerTop4Raw,260,"partner top4")
end)

case("opener resolves checkerId while preserving raw owned key",function()
    local own={items={{
        page="godly",
        id="Iceblaster",
        checkerId="481",
        name="Iceblaster",
        value=35,
        qty=1,
    }}}
    local picked,meta=policy.selectOpener(own,partner,profile,logic)
    ok(picked,"checker-backed raw item should be eligible opener")
    eq(picked.id,"Iceblaster","executor-facing raw owned key must be preserved")
    eq(picked.checkerId,"481","market identity must remain checker-backed")
    eq(meta.reason,"selected","checker-backed opener selected")
end)

case("opener returns nil when nothing is realistically reachable",function()
    local own={items={item("huge",500)}}
    local tinyPartner={items={item("stable40",40),item("stable20",20)}}
    local picked,meta=policy.selectOpener(own,tinyPartner,profile,logic)
    eq(picked,nil,"no forced absurd opener")
    eq(meta.reason,"no-realistic-candidate","reason")
end)

case("opener rejects underpaid and materially disputed candidates",function()
    local own={items={
        item("weak95",95),
        item("disputed100",100),
        item("stable80",80),
    }}
    local picked=policy.selectOpener(own,partner,profile,logic)
    ok(picked,"expected clean fallback")
    eq(picked.id,"stable80","clean stable opener wins")
end)

case("market logic exposes receive-side underpaid health",function()
    local b=logic.bundleAssessment({
        item("weak60",60,2),
        item("stable80",80),
    },"theirs",profile)
    eq(b.underpaidCopies,2,"underpaid copies")
    eq(b.underpaidValue,120,"underpaid value")
    ok(b.underpaidValueShare>0.5,"underpaid share")
end)

local function plan(id,rawProfit,givenExit,kind,units,disputed,unprofiled,mode)
    return {
        id=id,
        ok=true,
        mode=mode or "profit",
        rawProfit=rawProfit,
        protectedProfit=rawProfit,
        requiredProfit=15,
        rawTotal=300-rawProfit,
        protectedTotal=300-rawProfit,
        givenExitScore=givenExit,
        kind=kind or "NORMAL",
        units=units or 1,
        disputedCopies=disputed or 0,
        unprofiledCopies=unprofiled or 0,
        picks={{page="godly",id=id}},
    }
end

local healthyTheir=logic.bundleAssessment({item("stable120",120),item("stable80",80),item("stable40",40),item("stable20",20)},"theirs",profile)

case("same profit stage prefers healthier bundle for counterparty",function()
    local ranked=policy.rankSafePlans({
        plan("weakGiven",20,-3,"NORMAL",1),
        plan("strongGiven",21,3,"NORMAL",1),
    },healthyTheir,2)
    eq(ranked[1].id,"strongGiven","appeal beats dumping weak inventory")
end)

case("counterparty upgrade shape wins comparable tie",function()
    local ranked=policy.rankSafePlans({
        plan("theirDowngrade",20,1,"UPGRADE",3),
        plan("theirUpgrade",20,1,"DOWNGRADE",1),
    },healthyTheir,2)
    eq(ranked[1].id,"theirUpgrade","counterparty upgrade preferred")
end)

case("disputed or unprofiled plans cannot receive tier A",function()
    local tier1=policy.appeal(plan("disputed",20,4,"DOWNGRADE",1,1,0),healthyTheir)
    local tier2=policy.appeal(plan("unprofiled",20,4,"DOWNGRADE",1,0,1),healthyTheir)
    ok(tier1~="A","disputed capped")
    ok(tier2~="A","unprofiled capped")
end)

case("underpaid receive bundle cannot earn positive quality credit",function()
    local weakTheir=logic.bundleAssessment({
        item("weak60",60,3),
        item("stable120",120),
    },"theirs",profile)
    local tier,meta=policy.appeal(plan("looksStrong",30,4,"DOWNGRADE",1),weakTheir)
    ok(meta.qualityDelta<=0,"underpaid receive exposure removes positive quality credit")
    ok(tier~="A","underpaid-heavy receive bundle cannot be A")
end)

case("reject plans are excluded even if attractive",function()
    local rejected=plan("reject",50,5,"DOWNGRADE",1,0,0,"reject")
    rejected.ok=false
    local ranked=policy.rankSafePlans({
        rejected,
        plan("safe",15,0,"NORMAL",1),
    },healthyTheir,2)
    eq(#ranked,1,"only safe plan remains")
    eq(ranked[1].id,"safe","safe wins")
end)

case("sweeten time progression is bounded",function()
    eq(policy.sweetenStep(0),0,"0s")
    eq(policy.sweetenStep(4.99),0,"before first step")
    eq(policy.sweetenStep(5),1,"first step")
    eq(policy.sweetenStep(9.99),1,"before second step")
    eq(policy.sweetenStep(10),2,"second step")
    eq(policy.sweetenStep(999),2,"bounded at 2")
end)

case("profit bands step from reserve to floor",function()
    local p0=plan("floor",15,0,"NORMAL",1)
    local p1=plan("middle",21,0,"NORMAL",1)
    local p2=plan("reserve",27,0,"NORMAL",1)
    local plans={p0,p1,p2}
    eq(policy.rankSafePlans(plans,healthyTheir,0)[1].id,"reserve","stage0")
    eq(policy.rankSafePlans(plans,healthyTheir,1)[1].id,"middle","stage1")
    eq(policy.rankSafePlans(plans,healthyTheir,2)[1].id,"floor","stage2")
end)

case("missing target band chooses nearest lower before higher",function()
    local plans={
        plan("floor",15,0,"NORMAL",1),
        plan("reserve",27,0,"NORMAL",1),
    }
    eq(policy.rankSafePlans(plans,healthyTheir,1)[1].id,"floor","nearest lower band")
end)

case("appeal tier D can be surfaced for selective hold",function()
    local ugly=plan("ugly",15,-4,"UPGRADE",4)
    local ranked,meta=policy.rankSafePlans({ugly},healthyTheir,2)
    eq(ranked[1].id,"ugly","safe plan remains inspectable")
    eq(meta.bestTier,"D","caller can choose not to present D plan")
end)

case("ranking is deterministic",function()
    local plans={
        plan("beta",15,0,"NORMAL",1),
        plan("alpha",15,0,"NORMAL",1),
    }
    local a=policy.rankSafePlans(plans,healthyTheir,2)
    local b=policy.rankSafePlans(plans,healthyTheir,2)
    eq(a[1].id,b[1].id,"repeat result")
    eq(a[1].id,"alpha","canonical tie break")
end)

assert(pass==15,"expected 15 cases, got "..tostring(pass))
print("PASS adaptive acceptance policy 15/15")
