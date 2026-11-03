-- Idempotent outbox contract. Transport/JSON/credentials are injected, never logged.
-- Production remains disabled until native completion and persistence are proved.
local O={}
local function clone(t) if type(t)~="table" then return t end; local r={}; for k,v in pairs(t) do r[k]=clone(v) end; return r end
function O.payload(report)
    assert(report.verified==true,"verified reconciliation required")
    local function items(list)
        local lines={}; for _,it in ipairs(list) do
            lines[#lines+1]=tostring(it.name).." x"..it.qty.." | value "..it.value.." | demand "..it.demand.." | liquidity "..tostring(it.liquidity or "unavailable")
        end
        return table.concat(lines,"\n")
    end
    return {allowed_mentions={parse={}},embeds={{title="Verified MM2 trade "..report.id,
        description="Supreme "..tostring(report.version).." | partner "..tostring(report.partner).." | time "..tostring(report.time or "unavailable"),
        fields={{name="Given",value=items(report.give)},{name="Received",value=items(report.receive)},
            {name="Totals",value="Given "..report.givenTotal.." | received "..report.receivedTotal.." | profit +"..report.profit},
            {name="Verified inventory value",value=tostring(report.inventoryTotal)}}}}}
end
function O.new(ledger,enabled)
    local o={ledger=ledger,state=enabled and "ready" or "disabled"}
    for _,row in pairs(ledger) do if row.state=="sending" then row.state="delivery-uncertain" end end
    function o.enqueue(report)
        if not enabled or type(report)~="table" or report.verified~=true or type(report.id)~="string" or report.id=="" or ledger[report.id] then return false end
        ledger[report.id]={state="queued",attempts=0,report=clone(report),nextAttempt=0}; return true
    end
    function o.deliver(id,now,send)
        local row=ledger[id]
        if not enabled or not row or row.state~="queued" or now<row.nextAttempt then return false end
        -- Must be persisted before the transport call by a future native adapter.
        row.state="sending"; row.attempts=row.attempts+1
        local ok,response=pcall(send,clone(row.report))
        local code=ok and type(response)=="table" and tonumber(response.status) or nil
        if code and code>=200 and code<300 then row.state="sent"; return true end
        if code==429 then
            if row.attempts>=3 then row.state="rejected"
            else row.state="queued"; row.nextAttempt=now+math.max(.5,math.min(30,tonumber(response.retryAfter) or row.attempts)) end
        elseif code and code>=400 and code<500 then row.state="rejected"
        else row.state="delivery-uncertain" end
        return false
    end
    return o
end
return O
