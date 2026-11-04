-- Pure completed-report outbox. Persistence and normalized transport are injected.
-- persist(snapshot) must return true only after a durable write. send(report)
-- returns {status, receipt={acknowledged=true,messageId?}, retryAfter?}.
local O={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function integer(n) return finite(n) and n>=0 and n==math.floor(n) end
local function text(s) return type(s)=="string" and s~="" end
local function cents(n)
    if not finite(n) or n<0 then return nil end
    local value=math.floor(n*100+.5);return math.abs(value-n*100)<.000001 and value or nil
end
local function clone(value,seen,depth)
    local kind=type(value)
    if kind=="nil" or kind=="string" or kind=="boolean" then return value end
    if kind=="number" then if not finite(value) then error("nonfinite-data",0) end;return value end
    if kind~="table" or (depth or 0)>24 then error("nonserializable-data",0) end
    seen=seen or {};if seen[value] then error("cyclic-data",0) end;seen[value]=true
    local out={};for k,v in pairs(value) do
        if type(k)~="string" and not integer(k) then error("invalid-data-key",0) end
        out[k]=clone(v,seen,(depth or 0)+1)
    end
    seen[value]=nil;return out
end
local function copy(value) local ok,out=pcall(clone,value);if ok then return out end end
local function itemTotal(items)
    if type(items)~="table" or #items==0 or #items>4 then return nil end
    local total,seen=0,{}
    for _,it in ipairs(items) do
        if type(it)~="table" or not text(it.id) or seen[it.id] or not text(it.name)
            or not integer(it.qty) or it.qty<1 or not finite(it.demand) or it.demand<0 or it.demand>11 then return nil end
        local value=cents(it.value);if not value or value<=0 then return nil end
        total=total+value*it.qty;seen[it.id]=true
    end
    return total
end
function O.validReport(report)
    if type(report)~="table" or report.kind~="completed-trade" or report.provenance~="exact-raw-delta-v2"
        or report.verified~=true or report.rawInventoryVerified~=true or report.tradeOpen==true
        or not text(report.id) or not text(report.job) or not text(report.version) then return false end
    local given,received=itemTotal(report.give),itemTotal(report.receive)
    local gc,rc,profit=cents(report.givenTotal),cents(report.receivedTotal),cents(report.profit)
    local inventory=cents(report.pricedInventoryTotal)
    if not given or not received or given~=gc or received~=rc or not profit or received-given~=profit or profit<1500
        or not inventory or not integer(report.unpricedTypes) or not integer(report.unpricedCopies)
        or report.unpricedTypes>report.unpricedCopies or (report.unpricedTypes==0)~=(report.unpricedCopies==0) then return false end
    if report.unpricedCopies==0 then if cents(report.inventoryTotal)~=inventory then return false end
    elseif report.inventoryTotal~=nil then return false end
    return copy(report)~=nil
end
function O.payload(report)
    assert(O.validReport(report),"completed reconciliation report required")
    local function items(list)
        local lines={};for _,it in ipairs(list) do
            lines[#lines+1]=tostring(it.name).." x"..it.qty.." | value "..it.value.." | demand "..it.demand.." | liquidity "..tostring(it.liquidity or "unavailable")
        end;return table.concat(lines,"\n")
    end
    local coverage=report.inventoryTotal~=nil and ("Whole inventory value "..report.inventoryTotal)
        or ("Whole inventory value unavailable | unpriced types "..report.unpricedTypes.." | unpriced copies "..report.unpricedCopies)
    return {allowed_mentions={parse={}},embeds={{title="Verified MM2 trade "..report.id,
        description="Supreme "..report.version.." | partner "..tostring(report.partner).." | time "..tostring(report.time or "unavailable"),
        fields={{name="Given",value=items(report.give)},{name="Received",value=items(report.receive)},
            {name="Totals",value="Given "..report.givenTotal.." | received "..report.receivedTotal.." | profit +"..report.profit},
            {name="Priced inventory subtotal",value=tostring(report.pricedInventoryTotal)},
            {name="Inventory coverage",value=coverage}}}}}
end
function O.new(ledger,enabled,options)
    options=type(options)=="table" and options or {}
    local persist=options.persist
    local o={ledger=type(ledger)=="table" and ledger or {},state=enabled and "ready" or "disabled"}
    if enabled and type(persist)~="function" then o.state="persistence-unavailable" end
    local function ready() return enabled and o.state=="ready" end
    local function durable(candidate)
        local snapshot=copy(candidate);if not snapshot then return false,"nonserializable-ledger" end
        local ok,result=pcall(persist,snapshot)
        if not ok or result~=true then o.lastError="persistence-failed";return false,"persistence-failed" end
        return true
    end
    if ready() then
        local candidate=copy(o.ledger)
        if not candidate then o.state="invalid-ledger"
        else
            local recovered=false
            for _,row in pairs(candidate) do if type(row)=="table" and row.state=="sending" then row.state="delivery-uncertain";recovered=true end end
            if recovered then
                local saved=durable(candidate)
                for id,row in pairs(candidate) do o.ledger[id]=row end
                if not saved then o.state="persistence-error" end
            end
        end
    end
    local function enqueue(report)
        if not ready() then return false,o.state end
        if not O.validReport(report) then return false,"invalid-completed-report" end
        if o.ledger[report.id] then return false,"duplicate-report" end
        local candidate=copy(o.ledger);if not candidate then return false,"invalid-ledger" end
        candidate[report.id]={state="queued",attempts=0,report=copy(report),nextAttempt=0}
        local saved,why=durable(candidate);if not saved then return false,why end
        o.ledger[report.id]=candidate[report.id];return true
    end
    local function deliver(id,now,send)
        if not ready() then return false,o.state end
        local row=o.ledger[id]
        if not finite(now) or now<0 or type(send)~="function" or type(row)~="table" or row.state~="queued"
            or not finite(row.nextAttempt) or now<row.nextAttempt or not integer(row.attempts) or row.attempts>=3
            or not O.validReport(row.report) then return false,"delivery-ineligible" end
        local candidate=copy(o.ledger);if not candidate then return false,"invalid-ledger" end
        local sending=candidate[id];sending.state="sending";sending.attempts=sending.attempts+1
        local saved,why=durable(candidate);if not saved then return false,why end
        o.ledger[id]=sending
        local ok,response=pcall(send,copy(sending.report))
        -- Production supplies an absolute wall clock. Retry-After starts when
        -- the response arrives, after persistence and HTTP may have yielded.
        local responseNow=now
        local clockValid=true
        if type(options.now)=="function" then
            local clockOK,value=pcall(options.now)
            if not clockOK or not finite(value) or value<now then clockValid=false
            else responseNow=value end
        end
        local status=ok and type(response)=="table" and response.status or nil
        if not integer(status) or status<100 or status>599 then status=nil end
        local final=copy(sending)
        local receipt=type(response)=="table" and response.receipt
        local acknowledged=status and status>=200 and status<300 and type(receipt)=="table" and receipt.acknowledged==true
            and (receipt.messageId==nil or text(receipt.messageId))
        if acknowledged then
            final.state="sent";final.receipt={acknowledged=true,messageId=receipt.messageId}
        elseif status==429 then
            local delay=response.retryAfter
            if not finite(delay) or delay<0 or not clockValid or not finite(responseNow+delay) then final.state="delivery-uncertain"
            elseif final.attempts>=3 then final.state="rejected"
            else final.state="queued";final.nextAttempt=responseNow+math.max(.5,delay) end
        elseif status and status>=400 and status<500 then final.state="rejected"
        else final.state="delivery-uncertain" end
        candidate=copy(o.ledger);candidate[id]=final
        local committed=durable(candidate)
        if not committed then
            -- Durable disk remains 'sending'; both this owner and any reload
            -- must hold uncertainty after a transport attempt.
            sending.state="delivery-uncertain";o.ledger[id]=sending
            return false,"post-send-persistence-failed"
        end
        o.ledger[id]=final
        return final.state=="sent",final.state
    end
    -- Persistence and transport may yield or call back into the owner. Hold a
    -- local operation lease before either boundary to prevent duplicate sends
    -- and full-ledger snapshots overwriting another concurrent transition.
    local busy=false
    local function guarded(fn,...)
        if busy then return false,"outbox-busy" end
        busy=true
        local ok,result,why=pcall(fn,...)
        busy=false
        if not ok then return false,"outbox-operation-failed" end
        return result,why
    end
    function o.enqueue(...) return guarded(enqueue,...) end
    function o.deliver(...) return guarded(deliver,...) end
    return o
end
return O
