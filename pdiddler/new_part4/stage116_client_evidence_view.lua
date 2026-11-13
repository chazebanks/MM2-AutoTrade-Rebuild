-- Stage116: display-safe, PURE read-only client evidence summaries.
-- Stage106 candidate GUI matching and Stage115 sanitized offline replay are
-- DIFFERENT unlinked records. Neither grants MM2 trade settlement authority.
-- This module never reads Roblox state, raw keys, names or private account IDs.
local M = {}

local STAGE106_SCHEMA = "gingerscope-stage106-two-sided-update-trade-readonly-v1"
local STAGE115_SCHEMA = "gingerscope-offline-event-replay-v1"
local PASS106 = "CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED"
local TIERS = {
    NO_TERMINAL_CLIENT_EVIDENCE = "No terminal client readback evidence",
    CLIENT_WINDOW_CLOSED_ONLY = "Client trade window closed; result unknown",
    CLIENT_POSTCLOSE_NO_CHANGE = "Separate client readback shows no change",
    CLIENT_POSTCLOSE_CHANGE_UNATTRIBUTED = "Separate client readback changed (unattributed)",
    CLIENT_POSTCLOSE_READBACKS_CONFLICT = "Separate client readbacks conflict",
}
local DENIED106 = {
    "eventSessionAssociationProven", "callbackCausalityProven",
    "rawItemIdConfirmed", "uniqueWeaponInstanceProven",
    "serverAttestation", "serverCompletionProven",
    "currentPricesVerified", "priceForTradeVerified",
    "authorizesTrade", "authorizesAccept",
    "mayRecordCompletedTrade", "mayReportProfit",
    "maySendDiscordWebhook", "mayUseForStrategyLearning",
}
local DENIED115 = {
    "serverCompletionProven", "serverAttestation",
    "serverTransactionIdAuthenticated", "eventSessionAssociationProven",
    "causalTradeAttributionProven", "exactWeaponIdentityConfirmed",
    "mayRecordCompletedTrade", "mayRecordRejectedTrade",
    "mayReportProfit", "mayUseForStrategyLearning",
    "authorizesTrade", "authorizesAccept",
    "discordWebhookSent", "operatorCorroborationProven",
}

local function plainTable(t)
    return type(t) == "table" and getmetatable(t) == nil
end
local function allDenied(t, fields)
    for _, key in ipairs(fields) do
        if t[key] ~= false then
            return false
        end
    end
    return true
end
local function integer(x, bound)
    return type(x) == "number" and x == x and x >= 0 and x <= bound
        and x % 1 == 0
end

local function offerText(report)
    if report == nil then
        return "No Stage106 candidate report available"
    end
    if not plainTable(report) or report.schema ~= STAGE106_SCHEMA
        or report.readOnly ~= true or report.clientOnly ~= true
        or report.tradeOutcome ~= "UNKNOWN"
        or not allDenied(report, DENIED106)
    then
        return "Stage106 client evidence rejected"
    end
    if report.status == "INCONCLUSIVE" then
        return "Stage106 candidate comparison inconclusive (client only)"
    end
    if report.status ~= PASS106 or report.bothSidesReconciled ~= true
        or report.clientPerSlotRawKeyCandidateUnique ~= true
        or report.guiTwoStableSamples ~= true
        or not integer(report.ourMatchedSlotCount, 4)
        or not integer(report.theirMatchedSlotCount, 4)
        or report.ourMatchedSlotCount == 0 or report.theirMatchedSlotCount == 0
    then
        return "Stage106 client evidence rejected"
    end
    return "Client offer-key candidates matched GUI (not authenticated)"
end

local function readbackText(report)
    if report == nil then
        return "No Stage115 sanitized replay report available"
    end
    if not plainTable(report)
        or report.schema ~= STAGE115_SCHEMA
        or report.status ~= "CLIENT_REPLAY_ONLY"
        or report.readOnly ~= true
        or report.simulationOnly ~= true
        or report.clientEventsAreUntrusted ~= true
        or report.tradeOutcome ~= "UNKNOWN"
        or not allDenied(report, DENIED115)
        or type(report.clientEvidenceTier) ~= "string"
        or TIERS[report.clientEvidenceTier] == nil
    then
        return "Stage115 replay evidence rejected"
    end
    local total = report.postCloseDeltaObservations
    local changed = report.postCloseChangedReadbacks
    local unchanged = report.postCloseUnchangedReadbacks
    local repeats = report.postCloseReadbackRepeats
    local distinct = report.postCloseDistinctReadbackPatterns
    for _, n in ipairs({total, changed, unchanged, repeats, distinct}) do
        if not integer(n, 256) then
            return "Stage115 replay evidence rejected"
        end
    end
    if changed + unchanged ~= total or repeats > total
        or distinct > total or (total > 0 and distinct == 0)
        or (total == 0 and (repeats ~= 0 or distinct ~= 0))
    then
        return "Stage115 replay evidence rejected"
    end
    local tier = report.clientEvidenceTier
    if tier == "CLIENT_POSTCLOSE_READBACKS_CONFLICT" then
        if distinct < 2 then return "Stage115 replay evidence rejected" end
    elseif tier == "CLIENT_POSTCLOSE_CHANGE_UNATTRIBUTED" then
        if changed == 0 or distinct ~= 1 or unchanged ~= 0 then
            return "Stage115 replay evidence rejected"
        end
    elseif tier == "CLIENT_POSTCLOSE_NO_CHANGE" then
        if unchanged == 0 or changed ~= 0 or distinct ~= 1 then
            return "Stage115 replay evidence rejected"
        end
    elseif total ~= 0 then
        return "Stage115 replay evidence rejected"
    end
    return TIERS[tier]
end

function M.build(stage106, stage115)
    -- Entire response is fixed text + fixed false authority. Never reflect
    -- untrusted account/weapon names, raw IDs, status text or arbitrary keys.
    local offer = offerText(stage106)
    local readback = readbackText(stage115)
    return {
        schema = "gingerscope-stage116-unlinked-client-evidence-view-v1",
        status = "CLIENT_EVIDENCE_DISPLAY_ONLY",
        readOnly = true,
        offerText = offer,
        readbackText = readback,
        linkText = "These records are NOT linked to one confirmed trade",
        outcomeText = "OUTCOME UNKNOWN",
        tradeOutcome = "UNKNOWN",
        relationProven = false,
        serverCompletionProven = false,
        serverAttestation = false,
        serverTransactionIdAuthenticated = false,
        eventSessionAssociationProven = false,
        operatorCorroborationProven = false,
        authorizesTrade = false,
        authorizesAccept = false,
        mayRecordCompletedTrade = false,
        mayReportProfit = false,
        maySendDiscordWebhook = false,
        mayUseForStrategyLearning = false,
    }
end
return M
