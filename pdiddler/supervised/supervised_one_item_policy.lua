-- Supervised MM2 single-item outgoing pilot: PURE orchestration.
-- Manually selected exact partner and one raw weapon key. No pricing/planner,
-- scanner, request, auto Accept, completed trade, Discord, or server settlement.
-- This is a local offer attempt ONLY. A separate default-deny TradeIO gate
-- handles the actual OfferItem physical remote.
local M={}
local function result(status,reason,count)
    return {
        schema="gingerscope-supervised-one-item-pilot-v1",
        status=status,reason=reason,offerCount=count or 0,
        tradeOutcome="UNKNOWN",
        readOnly=false, -- one explicitly user-armed OfferItem can be dispatched
        authorizesTrade=false,authorizesAccept=false,
        serverCompletionProven=false,serverTransactionIdAuthenticated=false,
        mayRecordCompletedTrade=false,mayReportProfit=false,
        maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
    }
end
local function safeName(s,maxLen)
    return type(s)=="string" and #s>=1 and #s<=maxLen
       and not s:find("[%c]") and not s:find("^%s") and not s:find("%s$")
end
local function protected(key)
    return type(key)=="string" and
        key:lower():gsub("[^%w]",""):find("gingerscope",1,true)~=nil
end
local function exactMatch(a,b)
    return type(a)=="string" and type(b)=="string" and
        a:lower()==b:lower()
end
local function liveStatus(io,actors,localPlayer,target,trade)
    if type(trade)~="table" and type(trade)~="userdata" then
        return false,"VISIBLE_TRADE_UNAVAILABLE"
    end
    if io.trade()~=trade then
        return false,"VISIBLE_TRADE_CHANGED"
    end
    if not target or target==localPlayer or target.Parent~=actors then
        return false,"EXACT_TARGET_NOT_PRESENT"
    end
    if not exactMatch(io.partnerName(trade),target.Name) then
        return false,"VISIBLE_PARTNER_NOT_EXACT_TARGET"
    end
    local own=trade:FindFirstChild("YourOffer")
    local their=trade:FindFirstChild("TheirOffer")
    if not own or not their or not own:FindFirstChild("Container")
        or not their:FindFirstChild("Container") then
        return false,"OFFER_UI_INCOMPLETE"
    end
    local accepted=own:FindFirstChild("Accepted")
    if not accepted or type(accepted.Visible)~="boolean" then
        return false,"OWN_ACCEPT_STATE_UNKNOWN"
    end
    -- Original MM2 TradeModule toggles TheirOffer.Accepted.Visible. If
    -- that client indicator is missing/unreadable, a fallback scan returning
    -- false is not proof that the other party has NOT accepted.
    local theirAccepted=their:FindFirstChild("Accepted")
    if not theirAccepted or type(theirAccepted.Visible)~="boolean" then
        return false,"THEIR_ACCEPT_STATE_UNKNOWN"
    end
    if accepted.Visible~=false or theirAccepted.Visible~=false
        or io.acceptedTheir(trade)~=false then
        return false,"ACCEPT_ALREADY_SET"
    end
    local state=io.readSide(trade,"YourOffer")
    if type(state)~="table" or type(state.slots)~="number"
        or state.slots<0 or state.slots>4 then
        return false,"OWN_OFFER_STATE_UNKNOWN"
    end
    if state.slots~=0 then
        return false,"OWN_OFFER_ALREADY_NONEMPTY"
    end
    return true,"PRECONDITIONS_OBSERVED_CLIENT_ONLY"
end

function M.run(io,gate,players,localPlayer,config)
    if type(gate)=="table" then
        -- Prevent any carry-over from another invocation of the same gate.
        gate.checkOutbound=nil
    end
    if type(config)~="table" then
        return result("BLOCKED","PILOT_CONFIG_MISSING")
    end
    if config._consumed==true then
        return result("BLOCKED","ONE_SHOT_ALREADY_USED")
    end
    if config.armed~=true then
        return result("BLOCKED","EXPLICIT_MANUAL_ARM_MISSING")
    end
    if config.manualOfferOnly~=true then
        return result("BLOCKED","MANUAL_OFFER_ONLY_ACK_MISSING")
    end
    local key=config.weaponKey
    if protected(key) then
        return result("BLOCKED","PROTECTED_GINGERSCOPE_OUTGOING")
    end
    if not safeName(key,90) then
        return result("BLOCKED","WEAPON_KEY_INVALID")
    end
    if not safeName(config.targetName,32) then
        return result("BLOCKED","TARGET_NAME_INVALID")
    end
    if type(io)~="table" or type(gate)~="table"
        or type(io.trade)~="function" or type(io.offerItem)~="function"
        or type(io.partnerName)~="function"
        or type(io.readSide)~="function" or type(io.acceptedTheir)~="function" then
        return result("BLOCKED","LIVE_IO_UNAVAILABLE")
    end
    if type(players)~="table" and type(players)~="userdata" then
        return result("BLOCKED","LIVE_PLAYERS_UNAVAILABLE")
    end
    local target=players:FindFirstChild(config.targetName)
    if not target then
        return result("BLOCKED","EXACT_TARGET_NOT_FOUND")
    end
    local t=io.trade()
    if not t then
        return result("BLOCKED","VISIBLE_TRADE_UNAVAILABLE")
    end
    local ok,why=liveStatus(io,players,localPlayer,target,t)
    if not ok then return result("BLOCKED",why) end

    -- One physical offer attempt per deliberate user arm. The callback's
    -- returned true is never a source-price or server settlement receipt.
    config._consumed=true
    config.armed=false
    local item={id=key,rawKey=key,name=key}
    local pending=true
    gate.checkOutbound=function(candidate,observed)
        if pending~=true or candidate~=item or observed~=t
            or protected(candidate.id) or candidate.id~=key then
            return false
        end
        local currentOk=liveStatus(io,players,localPlayer,target,t)
        return currentOk==true
    end
    local called,sent,sendReason=pcall(io.offerItem,item)
    pending=false
    gate.checkOutbound=nil
    if not called or sent~=true then
        return result("BLOCKED","OFFER_DISPATCH_DENIED")
    end
    return result("OFFER_REMOTE_FIRED_CLIENT_ONLY",
                  "NO_ITEM_OWNERSHIP_OR_SETTLEMENT_ATTESTATION",1)
end
return M
