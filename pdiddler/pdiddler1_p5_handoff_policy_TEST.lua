-- Pdiddler P1/P5 policy regression tests (no teleport/trades).
-- Run standalone in Delta or another Luau runtime supporting loadstring + HttpGet.
local policy=loadstring(game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/feature/p1-bot-gate-safety-v1/pdiddler/pdiddler1_p5_handoff_policy_v1.lua",true))()
local count=0
local function test(name,mutate,wantState,wantReason)
    local ids={}
    for i=1,11 do ids[i]=tostring(i) end
    local function appearance()
        return {supporting=true,total=11,loaded=11,ids=table.clone(ids)}
    end
    local o={jobId="job-a",complete=true,stable=true,groupPattern=true,observedAt=100,
        total=11,moving=9,confirmed=7,partial=0,unknown=2,
        initialIds=table.clone(ids),appearance={appearance(),appearance()}}
    local ctx={jobId="job-a",now=101,currentIds=table.clone(ids),
        observerCurrent=true,criticalBusy=false,tradeVisible=false,
        outgoingOwned=false,scannerPending=false,hopping=false}
    if mutate then mutate(o,ctx) end
    local state,reason=policy.assess(o,ctx)
    assert(state==wantState and (not wantReason or reason==wantReason),
        name.." expected "..wantState.."/"..tostring(wantReason)..
        " got "..tostring(state).."/"..tostring(reason))
    count+=1
    print("[P1 TEST] OK "..name)
end
test("known-bot-pattern",nil,"REVIEW")
test("no-animation-cluster",function(o) o.confirmed=0 o.partial=0 o.unknown=2 end,"ALLOW")
test("busy-trade",function(_,c) c.criticalBusy=true end,"HOLD","trade-or-request-busy")
test("visible-trade",function(_,c) c.tradeVisible=true end,"HOLD","trade-or-request-busy")
test("outgoing-owned",function(_,c) c.outgoingOwned=true end,"HOLD","trade-or-request-busy")
test("scanner-pending",function(_,c) c.scannerPending=true end,"HOLD","system-busy")
test("already-hopping",function(_,c) c.hopping=true end,"HOLD","system-busy")
test("stale-observer",function(_,c) c.observerCurrent=false end,"HOLD","stale-observer")
test("stale-evidence",function(_,c) c.now=125 end,"HOLD","stale-evidence")
test("different-server",function(_,c) c.jobId="job-b" end,"HOLD","different-job")
test("churn-latched",function(o) o.stable=false end,"HOLD","population-churn")
test("last-minute-join",function(_,c) c.currentIds[12]="12" end,"HOLD","population-changed")
test("replaced-player",function(_,c) c.currentIds[11]="20" end,"HOLD","membership-changed")
test("between-avatar-scans",function(o) o.appearance[2].ids[11]="20" end,"HOLD","appearance-membership-changed")
test("appearance-negative",function(o) o.appearance[1].supporting=false end,"HOLD","appearance-not-corroborated")
test("appearance-not-loaded",function(o) o.appearance[1].loaded=2 end,"HOLD","appearance-not-corroborated")
test("insufficient-moving",function(o) o.moving=5 o.confirmed=3 o.partial=2 o.unknown=6 end,"HOLD","insufficient-coverage")
test("false-counts",function(o) o.confirmed=15 end,"HOLD","inconsistent-counts")
test("observer-disagrees",function(o) o.groupPattern=false end,"HOLD","observer-policy-mismatch")
print("[P1 TEST] PASS "..count.." checks; pure policy only")
