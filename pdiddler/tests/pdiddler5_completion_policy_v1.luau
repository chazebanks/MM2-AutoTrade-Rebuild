-- Part 5 completion policy v1
-- Pure Luau. No Roblox services. Shadow-only: decides whether the first
-- native Accept click would be allowed, but performs no action.

local Policy=require("../pdiddler5_completion_policy_v1")

local function readySnapshot()
    return {
        tradeOpen=true,
        sessionCurrent=true,
        partnerCurrent=true,
        p4Verified=true,
        ourNonEmpty=true,
        theirNonEmpty=true,
        ourResolved=true,
        theirResolved=true,
        recoveryIdle=true,
        txIdle=true,
        offerStable=true,
        decisionOk=true,
        signaturesCurrent=true,
        opponentAccepted=true,
        cooldownReady=true,
        acceptButtonVisible=true,
        confirmVisible=false,
        localAccepted=false,
    }
end

local s=readySnapshot()
local ok,reason=Policy.evaluate(s)
assert(ok==true and reason=="ready-first-click","fully safe snapshot must be ready")

local cases={
    {"tradeOpen","trade-closed"},
    {"sessionCurrent","stale-session"},
    {"partnerCurrent","partner-mismatch"},
    {"p4Verified","p4-not-verified"},
    {"ourNonEmpty","our-offer-empty"},
    {"theirNonEmpty","their-offer-empty"},
    {"ourResolved","our-offer-unresolved"},
    {"theirResolved","their-offer-unresolved"},
    {"recoveryIdle","recovery-active"},
    {"txIdle","transaction-active"},
    {"offerStable","offer-unstable"},
    {"decisionOk","decision-unsafe"},
    {"signaturesCurrent","offer-changed"},
    {"opponentAccepted","opponent-not-accepted"},
    {"cooldownReady","native-cooldown-active"},
    {"acceptButtonVisible","accept-button-not-visible"},
}

for _,case in ipairs(cases) do
    local field,expected=case[1],case[2]
    local x=readySnapshot()
    x[field]=false
    local pass,why=Policy.evaluate(x)
    assert(pass==false and why==expected,
        field.." should block with "..expected..", got "..tostring(why))
end

do
    local x=readySnapshot()
    x.confirmVisible=true
    local pass,why=Policy.evaluate(x)
    assert(pass==false and why=="accept-sequence-already-started",
        "visible Confirm must block shadow readiness")
end

do
    local x=readySnapshot()
    x.localAccepted=true
    local pass,why=Policy.evaluate(x)
    assert(pass==false and why=="local-already-accepted",
        "local Accepted state must block duplicate completion")
end

print("PASS Part 5 shadow completion policy")
