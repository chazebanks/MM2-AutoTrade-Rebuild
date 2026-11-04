-- Account-scoped, readback-verified outbox storage. All filesystem and JSON APIs
-- are injected. These are the only paths this module ever reads or writes.
local J={}
local PATHS={'pdiddler_webhook_journal_v1_a.json','pdiddler_webhook_journal_v1_b.json'}
local MAX_BYTES=4*1024*1024
local MAX_REVISION=9007199254740991
local STATES={queued=true,sending=true,sent=true,['delivery-uncertain']=true,rejected=true}
local ROW_KEYS={state=true,attempts=true,nextAttempt=true,report=true,receipt=true}
local ENVELOPE_KEYS={schema=true,accountId=true,revision=true,ledger=true}
local RECEIPT_KEYS={acknowledged=true,messageId=true}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function integer(n) return finite(n) and n>=0 and n==math.floor(n) end
local function accountId(s) return type(s)=='string' and #s<=20 and s:match('^[1-9]%d*$')~=nil end
local function keysOnly(t,allowed)
    if type(t)~='table' or getmetatable(t)~=nil then return false end
    for k in pairs(t) do if not allowed[k] then return false end end
    return true
end
local function sensitive(k)
    local key=k:lower():gsub('[^%w]','')
    for _,word in ipairs({'url','token','secret','password','credential','authorization','cookie','apikey'}) do
        if key:find(word,1,true) then return true end
    end
    return false
end
-- Copy only finite JSON data; never retain a caller's mutable snapshot or a
-- decoded metatable. Report metadata may vary, but credentials cannot be stored.
local function jsonCopy(value,seen,budget,depth)
    budget.n=budget.n+1
    if budget.n>50000 or depth>32 then return nil,false end
    local kind=type(value)
    if kind=='boolean' then return value,true end
    if kind=='number' then return value,finite(value) end
    if kind=='string' then return value,#value<=65536 and not value:find('://',1,true) end
    if kind~='table' or getmetatable(value)~=nil or seen[value] then return nil,false end
    seen[value]=true
    local out,count,maxIndex,hasStrings={},0,0,false
    for k,v in pairs(value) do
        if type(k)=='string' then
            if #k>256 or sensitive(k) then seen[value]=nil;return nil,false end
            hasStrings=true
        elseif integer(k) and k>=1 and k<=50000 then
            if k>maxIndex then maxIndex=k end
        else seen[value]=nil;return nil,false end
        local copy,ok=jsonCopy(v,seen,budget,depth+1)
        if not ok then seen[value]=nil;return nil,false end
        out[k]=copy;count=count+1
    end
    seen[value]=nil
    if maxIndex>0 and (hasStrings or count~=maxIndex) then return nil,false end
    return out,true
end
local function ledgerCopy(snapshot)
    if type(snapshot)~='table' or getmetatable(snapshot)~=nil then return nil end
    local copied,ok=jsonCopy(snapshot,{}, {n=0},0)
    if not ok then return nil end
    for id,row in pairs(copied) do
        if type(id)~='string' or id=='' or not keysOnly(row,ROW_KEYS) or not STATES[row.state]
            or not integer(row.attempts) or row.attempts>3 or not finite(row.nextAttempt) or row.nextAttempt<0
            or type(row.report)~='table' or row.report.id~=id or row.report.verified~=true then return nil end
        if row.receipt~=nil and (not keysOnly(row.receipt,RECEIPT_KEYS) or row.receipt.acknowledged~=true
            or (row.receipt.messageId~=nil and not accountId(row.receipt.messageId))) then return nil end
    end
    return copied
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function envelopeCopy(value,owner,slot)
    if not keysOnly(value,ENVELOPE_KEYS) or value.schema~=1 or value.accountId~=owner
        or not integer(value.revision) or value.revision<1 or value.revision>MAX_REVISION
        or (slot and (value.revision-1)%2~=slot-1) then return nil end
    local ledger=ledgerCopy(value.ledger)
    if not ledger then return nil end
    return {schema=1,accountId=owner,revision=value.revision,ledger=ledger}
end
function J.open(options)
    if type(options)~='table' or not accountId(options.accountId) then return nil,'journal-invalid-account' end
    for _,key in ipairs({'read','write','exists','encode','decode'}) do
        if type(options[key])~='function' then return nil,'journal-storage-unavailable' end
    end
    local owner=options.accountId
    local function readSlot(slot)
        local ok,present=pcall(options.exists,PATHS[slot])
        if not ok or type(present)~='boolean' then return nil,'journal-storage-unavailable' end
        if not present then return false end
        local readOK,raw=pcall(options.read,PATHS[slot])
        if not readOK or type(raw)~='string' or #raw==0 or #raw>MAX_BYTES then return nil,'journal-read-unverified' end
        local decodeOK,value=pcall(options.decode,raw)
        local env=decodeOK and envelopeCopy(value,owner,slot) or nil
        if not env then return nil,'journal-invalid-existing-data' end
        return env,nil,raw
    end
    local a,aError=readSlot(1)
    if a==nil then return nil,aError end
    local b,bError=readSlot(2)
    if b==nil then return nil,bError end
    if a and b and math.abs(a.revision-b.revision)~=1 then return nil,'journal-inconsistent-revisions' end
    local current=(a and b) and (a.revision>b.revision and a or b) or a or b
    if current and not (a and b) and current.revision~=1 then return nil,'journal-incomplete-existing-data' end
    local knownSlots={a,b}
    local journal={ledger=current and ledgerCopy(current.ledger) or {},revision=current and current.revision or 0,state='ready'}
    local function block(reason) journal.state='blocked';return nil,reason end
    function journal.persist(snapshot)
        if journal.state~='ready' then return nil,'journal-blocked' end
        local ledger=ledgerCopy(snapshot)
        if not ledger then return nil,'journal-invalid-snapshot' end
        if journal.revision>=MAX_REVISION then return block('journal-revision-exhausted') end
        -- Detect another writer, a deleted slot, or corruption before replacing
        -- anything. In-memory acknowledgement cannot repair uncertain storage.
        for index=1,2 do
            local observed=readSlot(index)
            if observed==nil or not equal(observed,knownSlots[index]) then return block('journal-storage-changed') end
        end
        local revision=journal.revision+1
        local slot=(revision-1)%2+1
        local expected={schema=1,accountId=owner,revision=revision,ledger=ledger}
        local encodeOK,raw=pcall(options.encode,expected)
        if not encodeOK or type(raw)~='string' or #raw==0 or #raw>MAX_BYTES then return nil,'journal-encoding-unavailable' end
        -- A thrown/false write can have partially changed the file. Permanently
        -- block this instance; a later call must not turn uncertainty into retry.
        local writeOK,result=pcall(options.write,PATHS[slot],raw)
        if not writeOK or result==false then return block('journal-write-unverified') end
        local restored,_,readback=readSlot(slot)
        if not restored or readback~=raw or not equal(restored,expected) then return block('journal-write-unverified') end
        knownSlots[slot]=expected
        journal.revision=revision
        return true
    end
    -- Sending snapshots are intentionally restored unchanged. The outbox owns
    -- conversion to delivery-uncertain and must persist it before resuming work.
    return journal
end
return J
