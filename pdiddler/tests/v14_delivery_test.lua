-- Offline durability and Discord delivery boundaries: no network or executor APIs.
local J=dofile('pdiddler/pdiddler_runtime_journal_v1.lua')
local T=dofile('pdiddler/pdiddler_discord_transport_v1.lua')
local O=dofile('pdiddler/pdiddler_webhook_outbox_v3.lua')
local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function clone(t) if type(t)~='table' then return t end;local c={};for k,v in pairs(t) do c[k]=clone(v) end;return c end
-- Injected codec models JSON round trips, including a fresh decoded object each read.
-- Serialization order is deliberately independent of pairs iteration order.
local function codec()
    local encoded={}
    local function value(v)
        if type(v)~='table' then return type(v)..':'..tostring(v) end
        local keys={};for k in pairs(v) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        local parts={};for _,k in ipairs(keys) do parts[#parts+1]=value(k)..'='..value(v[k]) end
        return '{'..table.concat(parts,'|')..'}'
    end
    local function encode(v) local s=value(v);encoded[s]=clone(v);return s end
    local function decode(s) assert(encoded[s],'invalid fixture JSON');return clone(encoded[s]) end
    return encode,decode
end
local function diskFixture()
    local files,writes={},{}
    local encode,decode=codec()
    local cfg={accountId='123',encode=encode,decode=decode,
        exists=function(path) return files[path]~=nil end,
        read=function(path) assert(files[path]~=nil);return files[path] end,
        write=function(path,data) writes[#writes+1]=path;files[path]=data end}
    return cfg,files,writes
end
local function report()
    return {id='tx1',job='job',partner=2,version='prices',verified=true,kind='completed-trade',provenance='exact-raw-delta-v2',
        rawInventoryVerified=true,give={{id='A',name='A',qty=1,value=100,demand=3}},
        receive={{id='B',name='B',qty=1,value=115,demand=3}},givenTotal=100,receivedTotal=115,profit=15,
        pricedInventoryTotal=215,inventoryTotal=215,wholeInventoryVerified=true,unpricedTypes=0,unpricedCopies=0,time=10}
end
local function row(state) return {state=state or 'queued',attempts=0,nextAttempt=0,report=report()} end
local function transport(response,overrides)
    local encode,decode=codec();local calls={};local bounds={}
    if type(response)=='table' and type(response.Body)=='table' then response=clone(response);response.Body=encode(response.Body) end
    local opts={webhookUrl='https://discord.com/api/webhooks/123/secret_TOKEN',encode=encode,decode=decode,
        http=function(req) calls[#calls+1]=req;return response end,
        bounded=function(label,seconds,fn) bounds[#bounds+1]={label=label,seconds=seconds};return pcall(fn) end}
    for k,v in pairs(overrides or {}) do opts[k]=v end
    local send,why=T.new(opts);return send,calls,bounds,why,opts
end

test('journal uses exactly two fixed slots and restores highest verified revision',function()
    local cfg,files,writes=diskFixture();local j=assert(J.open(cfg));eq(next(j.ledger),nil)
    assert(j.persist({tx1=row()}));assert(j.persist({tx1=row('sending')}));assert(j.persist({tx1=row('sent')}))
    eq(#writes,3);eq(writes[1],'pdiddler_webhook_journal_v1_a.json');eq(writes[2],'pdiddler_webhook_journal_v1_b.json');eq(writes[3],writes[1])
    local restored=assert(J.open(cfg));eq(restored.ledger.tx1.state,'sent');eq(restored.revision,3)
end)
test('sending state is durable before HTTP and crash recovery never resends',function()
    local cfg=diskFixture();local j=assert(J.open(cfg));local o=O.new(j.ledger,true,{persist=j.persist});assert(o.enqueue(report()))
    local requests=0;local durableSending,recoveredUncertain=false,false
    o.deliver('tx1',0,function()
        requests=requests+1
        local afterCrash=assert(J.open(cfg));eq(afterCrash.ledger.tx1.state,'sending');durableSending=true
        local restored=O.new(afterCrash.ledger,true,{persist=afterCrash.persist});eq(restored.ledger.tx1.state,'delivery-uncertain')
        assert(not restored.enqueue(report()));assert(not restored.deliver('tx1',100,function() requests=requests+1 end));recoveredUncertain=true
        error('simulated lost acknowledgement')
    end)
    eq(requests,1);assert(durableSending,'sending snapshot was not durable before HTTP');assert(recoveredUncertain,'crash restore was not deduplicated');eq(o.ledger.tx1.state,'delivery-uncertain')
end)
test('write failure and wrong readback block later writes and sends',function()
    for _,mode in ipairs({'throws','false','wrong-readback','corrupt-readback'}) do
        local cfg,files,writes=diskFixture();local j=assert(J.open(cfg));assert(j.persist({tx1=row()}))
        local original=cfg.write;local attempts=0
        cfg.write=function(path,data)
            attempts=attempts+1
            if mode=='throws' then original(path,data);error('uncertain storage write') end
            if mode=='false' then return false end
            if mode=='wrong-readback' then files[path]=cfg.encode({schema=1,accountId='123',revision=2,ledger={}});return end
            files[path]='partial JSON'
        end
        assert(not j.persist({tx1=row('sending')}));assert(not j.persist({tx1=row('sending')}));eq(attempts,1)
        eq(#writes,mode=='throws' and 2 or 1)
    end
end)
test('corruption in either existing slot fails closed despite healthy other slot',function()
    local cfg,files,writes=diskFixture();local j=assert(J.open(cfg));j.persist({tx1=row()});j.persist({tx1=row('sending')})
    files[writes[1]]='broken';local restored,why=J.open(cfg);eq(restored,nil);assert(type(why)=='string')
end)
test('account mismatch schema mismatch and conflicting revisions reject restore',function()
    for _,mode in ipairs({'account','schema','conflict'}) do
        local cfg,files,writes=diskFixture();local j=assert(J.open(cfg));j.persist({tx1=row()});j.persist({tx1=row('sending')})
        local env=cfg.decode(files[writes[2]])
        if mode=='account' then env.accountId='456' elseif mode=='schema' then env.schema=2
        else env.revision=1 end
        files[writes[2]]=cfg.encode(env);assert(not J.open(cfg))
    end
end)
test('journal rejects invalid rows cyclic values and credentials without writes',function()
    local cfg,_,writes=diskFixture();local j=assert(J.open(cfg))
    assert(not j.persist({tx1={state='unknown',attempts=0,nextAttempt=0,report=report()}}))
    local r=row();r.report.webhookUrl='https://discord.com/api/webhooks/123/secret_TOKEN';assert(not j.persist({tx1=r}))
    r=row();r.report.other='https://discord.com/api/webhooks/123/secret_TOKEN';assert(not j.persist({tx1=r}))
    r=row();r.report.loop=r;assert(not j.persist({tx1=r}));eq(#writes,0)
end)
test('external corruption deletion and concurrent changes cannot be overwritten',function()
    for _,mode in ipairs({'corrupt','delete','concurrent'}) do
        local cfg,files,writes=diskFixture();local j=assert(J.open(cfg));assert(j.persist({tx1=row()}))
        if mode=='corrupt' then files[writes[1]]='broken'
        elseif mode=='delete' then files[writes[1]]=nil
        else local other=assert(J.open(cfg));assert(other.persist({tx1=row('sending')})) end
        local count=#writes;assert(not j.persist({tx1=row('sending')}));eq(#writes,count);eq(j.state,'blocked')
    end
end)
test('storage exceptions and invalid dependencies return sanitized failures',function()
    local cfg,files,writes=diskFixture();local j=assert(J.open(cfg));assert(j.persist({tx1=row()}))
    cfg.read=function() error('secret_TOKEN https://discord.com/api/webhooks/123/secret_TOKEN') end
    local restored,why=J.open(cfg);eq(restored,nil);assert(type(why)=='string');assert(not why:find('secret_TOKEN',1,true))
    cfg,files,writes=diskFixture();j=assert(J.open(cfg))
    cfg.write=function() error('secret_TOKEN') end
    local ok;ok,why=j.persist({tx1=row()});assert(not ok);assert(not why:find('secret_TOKEN',1,true));eq(j.state,'blocked')
    cfg.exists=false;eq(J.open(cfg),nil)
end)
test('Discord wait response requires returned decimal message ID',function()
    local send,calls,bounds=transport({StatusCode=200,Body={id='123456789012345678'}})
    local res=send({content='offline'});eq(res.status,200);eq(res.receipt.acknowledged,true);eq(res.receipt.messageId,'123456789012345678')
    eq(#calls,1);eq(calls[1].Url,'https://discord.com/api/webhooks/123/secret_TOKEN?wait=true');eq(calls[1].Method,'POST')
    eq(calls[1].Headers['Content-Type'],'application/json');eq(#bounds,1);eq(bounds[1].seconds,10)
end)
test('204 status-only malformed and nonmessage success stay ambiguous',function()
    for _,response in ipairs({{StatusCode=204},{status=200},{StatusCode=200,Body='bad'},
        {StatusCode=200,Body={}},{StatusCode=200,Body={id=123}},{StatusCode=200,Body={id='abc'}}}) do
        local send,calls=transport(response);local res=send({});eq(res.receipt,nil);eq(#calls,1)
    end
end)
test('Discord 429 honors complete body and header delays without retrying',function()
    local send,calls=transport({StatusCode=429,Body={retry_after=120},Headers={['Retry-After']='90'}})
    local res=send({});eq(res.status,429);eq(res.retryAfter,120);eq(res.receipt,nil);eq(#calls,1)
    send,calls=transport({StatusCode=429,Headers={['retry-after']='240'}});eq(send({}).retryAfter,240);eq(#calls,1)
    send=transport({StatusCode=429,Body={retry_after=-1}});eq(send({}).retryAfter,nil)
end)
test('timeouts HTTP failures malformed HTTP and server errors are single attempt',function()
    for _,response in ipairs({true,{StatusCode=500},{StatusCode=502,Body='bad'}}) do
        local send,calls=transport(response);eq(send({}).receipt,nil);eq(#calls,1)
    end
    local send,calls=transport({}, {bounded=function() return false,'timeout secret_TOKEN' end});eq(send({}).receipt,nil);eq(#calls,0)
    send,calls=transport({}, {http=function() error('request https://discord.com/api/webhooks/123/secret_TOKEN') end})
    local ok,res=pcall(send,{});assert(ok);eq(res.receipt,nil)
end)
test('transport calls HTTP once even if bounding callback is invoked twice',function()
    local send,calls=transport({StatusCode=200,Body={id='123456789012345678'}}, {
        bounded=function(_,_,fn) local ok,res=pcall(fn);fn();return ok,res end})
    eq(send({}).receipt.acknowledged,true);eq(#calls,1)
end)
test('noncanonical URLs and missing boundaries fail without exposing credentials',function()
    for _,url in ipairs({'http://discord.com/api/webhooks/123/secret_TOKEN','https://example.com/api/webhooks/123/secret_TOKEN',
        'https://discord.com.evil/api/webhooks/123/secret_TOKEN','https://discord.com@evil/api/webhooks/123/secret_TOKEN',
        'https://discord.com/api/webhooks/123/secret_TOKEN?wait=false','https://discord.com/api/webhooks/123/secret_TOKEN#fragment',
        'https://discord.com/api/webhooks/123/secret_TOKEN/extra'}) do
        local send,calls,_,why=transport({}, {webhookUrl=url});eq(send,nil);eq(#calls,0)
        assert(not tostring(why):find('secret_TOKEN',1,true));assert(not tostring(why):find(url,1,true))
    end
    local send,_,_,why=transport({}, {bounded=false});eq(send,nil);assert(type(why)=='string')
end)
test('transport acknowledgement and full rate limit flow through durable outbox',function()
    local cfg=diskFixture();local j=assert(J.open(cfg));local o=O.new(j.ledger,true,{persist=j.persist});assert(o.enqueue(report()))
    local send,calls=transport({StatusCode=429,Body={retry_after=120}})
    assert(not o.deliver('tx1',0,function(r) return send(O.payload(r)) end));eq(o.ledger.tx1.nextAttempt,120)
    assert(not o.deliver('tx1',119,send));eq(#calls,1)
    local accepted,acceptedCalls=transport({StatusCode=200,Body={id='123456789012345678'}})
    assert(o.deliver('tx1',120,function(r) return accepted(O.payload(r)) end));eq(#acceptedCalls,1)
    local restored=assert(J.open(cfg));eq(restored.ledger.tx1.state,'sent')
end)
test('HTTP and encoder failures never return secret-bearing errors',function()
    local send=transport({}, {encode=function() error('secret_TOKEN') end});local ok,res=pcall(send,{});assert(ok);eq(res.receipt,nil)
    for k,v in pairs(res) do assert(not tostring(k):find('secret_TOKEN',1,true));assert(not tostring(v):find('secret_TOKEN',1,true)) end
end)
print('RESULT '..passed..' passed; '..failed..' failed')
if failed>0 then error('delivery boundary failures: '..failed) end
