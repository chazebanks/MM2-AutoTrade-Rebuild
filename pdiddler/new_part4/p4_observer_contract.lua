-- New Part 4 / Stage 9: pure read-only normalized trade observations.
-- No Roblox objects, remote calls, item mutations, accepting, or price lookups.
-- This module does NOT authorize offers; quoteSafe stays false until an
-- independently verified market/strategy adapter is built and tested.
local M = {}

local function isInt(x, min, max)
    return type(x) == "number" and x == x and x ~= math.huge
        and x ~= -math.huge and x == math.floor(x)
        and x >= min and x <= max
end

local function canon(s)
    if type(s) ~= "string" then return "" end
    return s:gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," "):lower()
end

local function startsChroma(s)
    return canon(s):sub(1,7) == "chroma "
end

local function fullName(label, chroma)
    local n = canon(label)
    if chroma and not startsChroma(label) then n = "chroma "..n end
    return n
end

local function validQuantity(text)
    if type(text) ~= "string" then return nil end
    local s=text:gsub("^%s+",""):gsub("%s+$","")
    s=s:gsub("^[xX]%s*","")
    if s:sub(1, #"×")=="×" then
        s=s:sub(#"×"+1):gsub("^%s+", "")
    end
    if not s:match("^%d+$") then return nil end
    if #s > 7 then return nil end
    local qty = tonumber(s)
    if not isInt(qty,1,1000000) then return nil end
    return qty
end
M.parseQuantity = validQuantity

local function sigField(v)
    v = tostring(v == nil and "?" or v)
    return tostring(#v)..":"..v
end

local function signature(side,tag)
    if type(side)~="table" or side.complete~=true
        or type(side.slots)~="table" or #side.slots>4 then return nil end
    local parts={tag}
    local seen={}
    for _,slot in ipairs(side.slots) do
        if type(slot)~="table" or not isInt(slot.slot,1,4) or seen[slot.slot] then
            return nil
        end
        seen[slot.slot]=true
        parts[#parts+1]=sigField(slot.slot)
        parts[#parts+1]=sigField(slot.rawId)
        parts[#parts+1]=sigField(slot.label)
        parts[#parts+1]=sigField(slot.chroma)
        parts[#parts+1]=sigField(slot.amountText)
    end
    return table.concat(parts,"|")
end

-- Deterministic order, independent of the order that FindFirstChild returned.
local function normalizedSignature(side,tag)
    if type(side)~="table" or side.complete~=true or type(side.slots)~="table" or #side.slots>4 then
        return nil
    end
    local rows={}
    for _,x in ipairs(side.slots) do rows[#rows+1]=x end
    table.sort(rows,function(a,b)
        return type(a)=="table" and type(b)=="table"
            and type(a.slot)=="number" and type(b.slot)=="number" and a.slot<b.slot
    end)
    return signature({complete=true,slots=rows},tag)
end

local function indexInventory(inv)
    if type(inv)~="table" or type(inv.items)~="table" then return nil,"scanner-record-missing" end
    if inv.unmapped~=0 or inv.badQty~=0 or inv.unpriced~=0 then
        return nil,"scanner-record-incomplete"
    end
    local byId,byName={},{}
    for _,it in ipairs(inv.items) do
        if type(it)~="table" or type(it.id)~="string" or it.id==""
            or type(it.name)~="string" or canon(it.name)==""
            or type(it.checkerId)~="string" or not it.checkerId:match("^%d+$")
            or not (it.page=="godly" or it.page=="chroma" or it.page=="ancient")
            or not (it.type=="Knife" or it.type=="Gun")
            or not isInt(it.qty,1,1000000)
            or it.cat~="Weapons" then
            return nil,"scanner-item-invalid"
        end
        if byId[it.id] then return nil,"duplicate-scanner-id" end
        byId[it.id]=it
        local nm=canon(it.name)
        if byName[nm] ~= nil then
            byName[nm]=false -- ambiguity is forbidden for name-only lookup
        else
            byName[nm]=it
        end
    end
    return {byId=byId,byName=byName},nil
end

local function resolve(slot,index)
    if type(slot)~="table" or not index then return nil,"slot-or-scanner-missing" end
    local qty=validQuantity(slot.amountText)
    if not qty then return nil,"quantity-unverified" end
    if type(slot.label)~="string" or canon(slot.label)=="" then return nil,"name-unavailable" end
    if slot.chroma~=true and slot.chroma~=false then return nil,"chroma-state-unverified" end
    local matchingName=fullName(slot.label,slot.chroma)
    local it
    if type(slot.rawId)=="string" and slot.rawId~="" then
        it=index.byId[slot.rawId]
        if not it then return nil,"raw-id-not-in-scanner" end
        if canon(it.name)~=matchingName then return nil,"raw-id-name-disagreement" end
    else
        it=index.byName[matchingName]
        if type(it)~="table" then return nil,"unproven-or-ambiguous-display-identity" end
    end
    if qty>it.qty then return nil,"quantity-exceeds-scanner" end
    return {slot=slot.slot,id=it.id,qty=qty,page=it.page,checkerId=it.checkerId,
        name=it.name,origin=slot.rawId and slot.rawId~="" and "raw-id" or "unique-scanner-name"},nil
end

local function decodeSide(side,tag,inv)
    local errors={}
    local physical=normalizedSignature(side,tag)
    if not physical then return {},false,nil,{"side-layout-or-slots-invalid"} end
    local index,err=indexInventory(inv)
    if not index then errors[#errors+1]=err end
    local out={}
    local seen,counts={},{}
    local valid=true
    for _,slot in ipairs(side.slots) do
        if type(slot)~="table" or not isInt(slot.slot,1,4) or seen[slot.slot] then
            valid=false;errors[#errors+1]="slot-index-invalid"
        else
            seen[slot.slot]=true
            local item,why=resolve(slot,index)
            if not item then
                valid=false;errors[#errors+1]=why
            else
                counts[item.id]=(counts[item.id] or 0)+item.qty
                if counts[item.id]>index.byId[item.id].qty then
                    valid=false;errors[#errors+1]="aggregate-quantity-exceeds-scanner"
                else
                    out[#out+1]=item
                end
            end
        end
    end
    if #errors>0 then valid=false end
    table.sort(out,function(a,b)return a.slot<b.slot end)
    return out,valid,physical,errors
end

-- INPUT rawCapture: game-context-checked *raw* current offer slots and accept indicators.
-- trust: current scanner ownership records and explicit market freshness boolean.
-- Quote safety is deliberately NOT established by an inventory display alone.
function M.normalize(rawCapture,trust)
    trust=trust or {}
    local raw=type(rawCapture)=="table" and rawCapture or {}
    local session=type(raw.session)=="string" and raw.session or "invalid-session"
    local o={tradeOpen=raw.tradeOpen==true,session=session,
        contextOK=false,marketFresh=trust.marketFresh==true,
        ourSig="unverified-ours",theirSig="unverified-theirs",
        ourSlots=0,theirSlots=0,ownItems={},theirResolved=false,
        quoteSafe=false,ourAccepted=raw.our and raw.our.accepted,
        theirAccepted=raw.their and raw.their.accepted}
    local report={authorizesTrade=false,authorizesAccept=false,provesCompletion=false,
        marketValueAuthority=false,ourItems={},theirItems={},errors={},
        quoteSafeReason="no-independent-current-price-and-policy-proof"}
    if not o.tradeOpen then
        o.contextOK=false
        report.errors[#report.errors+1]="trade-closed"
        return o,report
    end
    if raw.contextOK~=true then report.errors[#report.errors+1]="trade-session-or-partner-unverified" end
    if raw.our and type(raw.our.slots)=="table" then o.ourSlots=#raw.our.slots end
    if raw.their and type(raw.their.slots)=="table" then o.theirSlots=#raw.their.slots end
    local own,ownOK,ourSig,ownErrors=decodeSide(raw.our,"YourOffer",trust.ownInventory)
    local theirs,theirOK,theirSig,theirErrors=decodeSide(raw.their,"TheirOffer",trust.opponentInventory)
    o.ourSig=ourSig or o.ourSig
    o.theirSig=theirSig or o.theirSig
    report.ourItems=own
    report.theirItems=theirs
    for _,x in ipairs(ownErrors) do report.errors[#report.errors+1]="our:"..x end
    for _,x in ipairs(theirErrors) do report.errors[#report.errors+1]="their:"..x end
    if not o.marketFresh then report.errors[#report.errors+1]="market-unfresh-or-unverified" end
    if raw.our==nil or type(raw.our.accepted)~="boolean" then report.errors[#report.errors+1]="our-accept-unverified" end
    if raw.their==nil or type(raw.their.accepted)~="boolean" then report.errors[#report.errors+1]="their-accept-unverified" end
    o.contextOK=raw.contextOK==true and ourSig~=nil and theirSig~=nil and ownOK
        and type(o.ourAccepted)=="boolean" and type(o.theirAccepted)=="boolean"
    o.theirResolved=theirOK
    if ownOK then
        for _,it in ipairs(own) do
            o.ownItems[#o.ownItems+1]={slot=it.slot,id=it.id,qty=it.qty}
        end
    end
    return o,report
end

return M