-- pdiddler completed-trade Discord payload v2 | tracked inventory + Trade ID
-- Pure Luau: no Roblox services, no network calls.

local M={}

local function num(v)
    local n=tonumber(v)
    if not n or n~=n or n==math.huge or n==-math.huge then return nil end
    return n
end

local function fmtValue(v)
    local n=num(v)
    if not n then return "N/A" end
    if math.floor(n)==n then return tostring(math.floor(n)) end
    return string.format("%.2f",n)
end

local function fmtSigned(v)
    local n=num(v)
    if not n then return "N/A" end
    if math.floor(n)==n then
        return string.format("%+d",math.floor(n))
    end
    return string.format("%+.2f",n)
end

local function fmtLiquidity(v)
    local n=num(v)
    if not n then return "N/A" end
    return string.format("%+.2f",n)
end

local function compact(s,maxLen)
    s=tostring(s or "")
    maxLen=tonumber(maxLen) or 1000
    if #s<=maxLen then return s end
    if maxLen<=3 then return s:sub(1,maxLen) end
    return s:sub(1,maxLen-3).."..."
end

local function itemLine(it)
    it=type(it)=="table" and it or {}
    local qty=math.max(1,math.floor(num(it.qty) or 1))
    local name=tostring(it.name or it.id or "Unknown item")
    local mm2=fmtValue(it.mm2Value)
    local supreme

    if num(it.supremeValue) then
        supreme=fmtValue(it.supremeValue)
    elseif type(it.supremeLabel)=="string" and it.supremeLabel~="" then
        supreme=tostring(it.supremeLabel)
    else
        supreme="N/A"
    end

    local demand=num(it.demand)
    local demandText=demand and (fmtValue(demand).."/10") or "N/A"
    local stability=
        type(it.stability)=="string" and it.stability~=""
        and tostring(it.stability)
        or "N/A"

    return string.format(
        "• %s x%d — MM2 %s | Supreme %s | Demand %s | Liquidity %s | %s",
        name,
        qty,
        mm2,
        supreme,
        demandText,
        fmtLiquidity(it.liquidity),
        stability
    )
end

local function itemLines(items)
    if type(items)~="table" or #items==0 then return "None" end
    local out={}
    for _,it in ipairs(items) do
        out[#out+1]=itemLine(it)
    end
    return compact(table.concat(out,"\n"),1000)
end

function M.build(snapshot,source)
    local s=type(snapshot)=="table" and snapshot or {}
    local trader=tostring(s.traderName or s.partnerName or "Unknown")

    local giveRaw=num(s.giveRaw) or 0
    local receiveRaw=num(s.receiveRaw) or 0
    local giveProtected=num(s.giveProtected) or giveRaw
    local receiveProtected=num(s.receiveProtected) or receiveRaw
    local rawGain=num(s.rawGain)
    local protectedGain=num(s.protectedGain)

    if not rawGain then rawGain=receiveRaw-giveRaw end
    if not protectedGain then protectedGain=receiveProtected-giveProtected end

    local description="Completed trade with **"..compact(trader,180).."**"

    local tradeId=tostring(s.id or "")
    local trackedTotal=num(s.trackedInventoryTotal)
    local trackedStatus=tostring(s.trackedInventoryVerification or "unavailable")
    local trackedValue=trackedTotal and fmtValue(trackedTotal) or "Unavailable"

    local trackedDetails={}
    local unmapped=math.max(0,math.floor(num(s.trackedInventoryUnmapped) or 0))
    local unpriced=math.max(0,math.floor(num(s.trackedInventoryUnpriced) or 0))
    local badQty=math.max(0,math.floor(num(s.trackedInventoryBadQty) or 0))

    trackedDetails[#trackedDetails+1]="Status: "..trackedStatus
    if unmapped>0 then trackedDetails[#trackedDetails+1]="unmapped "..tostring(unmapped) end
    if unpriced>0 then trackedDetails[#trackedDetails+1]="unpriced "..tostring(unpriced) end
    if badQty>0 then trackedDetails[#trackedDetails+1]="badQty "..tostring(badQty) end

    local fields={
        {
            name="We traded",
            value=itemLines(s.gave),
            inline=false,
        },
        {
            name="They traded",
            value=itemLines(s.received),
            inline=false,
        },
        {
            name="Trade value",
            value=string.format(
                "We: %s  •  Them: %s\nProtected — We: %s  •  Them: %s",
                fmtValue(giveRaw),
                fmtValue(receiveRaw),
                fmtValue(giveProtected),
                fmtValue(receiveProtected)
            ),
            inline=false,
        },
        {
            name="Gain",
            value=string.format(
                "Raw %s  •  Protected %s",
                fmtSigned(rawGain),
                fmtSigned(protectedGain)
            ),
            inline=false,
        },
        {
            name="Tracked inventory after",
            value=trackedValue.."\n"..table.concat(trackedDetails," • "),
            inline=false,
        },
        {
            name="Trade ID",
            value=tradeId~="" and ("\`"..compact(tradeId,220).."\`") or "Unavailable",
            inline=false,
        },
    }

    return {
        username="MM2 Auto Trade",
        allowed_mentions={parse={}},
        embeds={{
            title="✅ MM2 Trade Completed",
            description=description,
            color=5763719,
            fields=fields,
            footer={text="Completion: "..tostring(source or "verified")},
        }},
    }
end

return M
