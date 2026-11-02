-- pdiddler Part 5 completion policy v1
-- Pure Luau. Shadow-only.
-- Decides whether the FIRST native Accept click would be allowed.
-- Performs no Roblox actions.

local P={}

local function requireTrue(s,field,reason)
    if s[field]~=true then
        return false,reason
    end
    return nil,nil
end

function P.evaluate(snapshot)
    local s=type(snapshot)=="table" and snapshot or {}

    local checks={
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

    for _,check in ipairs(checks) do
        local blocked,why=requireTrue(s,check[1],check[2])
        if blocked~=nil then
            return blocked,why
        end
    end

    if s.confirmVisible==true then
        return false,"accept-sequence-already-started"
    end

    if s.localAccepted==true then
        return false,"local-already-accepted"
    end

    return true,"ready-first-click"
end

return P
