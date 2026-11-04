local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print("PASS "..name) else failed=failed+1;print("FAIL "..name..": "..tostring(why)) end
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function stable(f)
    assert(f:capture("before"));f.counts={KnifeA=1,KnifeB=1};assert(f:capture("after"));assert(f:capture("after"))
end
local function event(probe,kind)
    for i=#probe.events,1,-1 do local e=probe.events[i];if e.kind==kind then return e end end
    return nil
end

test("report remains visible after polling exhausted v1 global output cap",function()
    local f=probeFixture():start()
    for i=1,125 do f.partner.Text="Partner"..i;f:advance(f.now+.2) end
    local before=#f.printed;f.probe.report();assert(#f.printed>before,"terminal report hidden by polling budget")
end)
test("native scalar identifiers and allowlisted structured fields survive sanitization",function()
    local f=probeFixture():start()
    f.acceptRemote.OnClientEvent:Fire(true,"fixture-native-id",23,{TransactionId="fixture-transaction",Status="pending",Success=false,Payload={TradeId=81},Inventory={SecretId=900}},f.root)
    local e=event(f.probe,"server-event");assert(e,"structured event absent")
    eq(e.context.partner,"FixturePartner");eq(e.payload[1].value,true);eq(e.payload[2].value,"fixture-native-id");eq(e.payload[3].value,23)
    eq(e.payload[4].fields.TransactionId.value,"fixture-transaction");eq(e.payload[4].fields.Success.value,false)
    eq(e.payload[4].fields.Payload.fields.TradeId.value,81);eq(e.payload[4].fields.Inventory,nil)
    eq(e.payload[5].kind,"Instance");eq(e.payload[5].value,nil)
end)
test("same root hidden and reopened between polls creates a new observed lifetime",function()
    local f=probeFixture():start();local generation=f.probe.rootGeneration;f:reopen()
    assert(f.probe.rootGeneration>generation,"same instance reopen escaped lifetime tracking")
end)
test("before read crossing close reopen is discarded instead of relabeled at response",function()
    local f=probeFixture():start();f.readDelay=1;assert(f.probe.capture("before"));f:advance(0);f:reopen();f:advance(1.1)
    eq(f.probe.snapshots.before,nil)
end)
test("partner change while read pending discards snapshot",function()
    local f=probeFixture():start();f.readDelay=.5;assert(f.probe.capture("before"));f:advance(0);f.partner:Set("Text","OtherPartner");f:advance(.6)
    eq(f.probe.snapshots.before,nil)
end)
test("new lifetime cannot supply after reads for older pending transaction",function()
    local f=probeFixture():start();assert(f:capture("before"));f:reopen();f:advance(.2)
    local ok=f:capture("after");assert(not ok,"after capture crossed transaction epoch")
end)
test("same pending transaction permits after reads after observed closure but reports unconfirmed",function()
    local f=probeFixture():start();assert(f:capture("before"));f.root:Set("Visible",false);f:advance(.2)
    f.counts={KnifeA=1,KnifeB=1};assert(f:capture("after"));assert(f:capture("after"))
    local ok,r=f.probe.report();assert(ok);eq(r.status,"UNCONFIRMED");eq(r.nativeTransactionId,nil)
    eq(r.changedTypes,2);eq(r.delta[1].id,"KnifeA");eq(r.delta[1].delta,-1);eq(r.delta[2].delta,1)
end)
test("after raw counts must match exactly even when old serialized keys collide",function()
    local f=probeFixture():start();assert(f:capture("before"));f.counts={["a:1|b"]=2};assert(f:capture("after"))
    f.counts={a=1,b=2};assert(f:capture("after"));assert(not f.probe.report(),"delimiter collision accepted distinct maps")
end)
test("mismatched snapshot transaction context rejects reporting",function()
    local f=probeFixture():start();stable(f)
    local snap=f.probe.snapshots.after2;snap.rootGeneration=(snap.rootGeneration or 0)+1
    assert(not f.probe.report(),"cross epoch report accepted")
end)
test("one outstanding inventory read persists through timeout and discards late result",function()
    local f=probeFixture():start();f.readDelay=6;assert(f.probe.capture("before"));f:advance(4.1)
    eq(f.reads,1);assert(not f.probe.capture("before"));eq(f.probe.snapshots.before,nil)
    f:advance(6.1);eq(f.probe.snapshots.before,nil);eq(f.probe.captureBusy,false)
    f.readDelay=0;assert(f:capture("before"));eq(f.reads,2)
end)
test("stopped probe cannot release an outstanding invocation to a replacement",function()
    local f=probeFixture():start();f.readDelay=6;assert(f.probe.capture("before"));f:advance(0);f.probe.stop();f.probe=NEW_PROBE(f);f:advance(0)
    assert(not f.probe.capture("before"),"replacement overlapped stopped outstanding InvokeServer")
    eq(f.reads,1);f:advance(6.1);f.readDelay=0;assert(f:capture("before"));eq(f.reads,2)
end)
test("request time player and JobId changes fence result",function()
    for _,change in ipairs({function(f) f.game.JobId="other-job" end,function(f) f.players.LocalPlayer={UserId=99} end}) do
        local f=probeFixture():start();f.readDelay=.5;assert(f.probe.capture("before"));f:advance(0);change(f);f:advance(.6)
        eq(f.probe.snapshots.before,nil)
    end
end)
test("invalid counts and remote failure emit terminal evidence without snapshot",function()
    for _,counts in ipairs({{A=-1},{A=.5},{A=math.huge},{[3]=1},{A=0/0}}) do
        local f=probeFixture():start();f.counts=counts;assert(f:capture("before"));eq(f.probe.snapshots.before,nil)
        assert(event(f.probe,"capture-error"))
    end
    local f=probeFixture():start();f.readError=true;assert(f:capture("before"));eq(f.probe.snapshots.before,nil);assert(event(f.probe,"capture-error"))
end)
test("event storage stays bounded and unrelated polling cannot evict terminal evidence",function()
    local f=probeFixture():start();f.probe.report()
    for i=1,250 do f.partner.Text="Partner"..i;f:advance(f.now+.2) end
    assert(#f.probe.events<=160);assert(type(f.probe.terminalEvents)=="table");assert(#f.probe.terminalEvents>=1)
    local found=false;for _,e in ipairs(f.probe.terminalEvents) do if e.kind=="report" then found=true end end;assert(found)
    local e=event(f.probe,"ui-change");assert(e);eq(e.context.rootGeneration,f.probe.rootGeneration)
end)
test("inspection and stop remain observational and stop disconnects callbacks",function()
    local f=probeFixture():start();local reads=f.reads;f.probe.inspectButtons();eq(f.reads,reads)
    local count=#f.probe.events;f.probe.stop();f.button.Activated:Fire();f.acceptRemote.OnClientEvent:Fire(true,"late");f:advance(.4)
    eq(#f.probe.events,count+1);eq(f.probe.active,false);assert(not f.probe.capture("before"))
end)
test("ancestor Enabled close reopen and root ancestry reuse advance lifetime synchronously",function()
    local f=probeFixture():start();local n=f.probe.rootGeneration
    f.gui:Set("Enabled",false);f.gui:Set("Enabled",true);eq(f.probe.rootGeneration,n+1)
    local parent=f.root.Parent;f.root:SetParent(nil);f.root:SetParent(parent);eq(f.probe.rootGeneration,n+2)
end)
test("manual button observation connections remain bounded during UI churn",function()
    local f=probeFixture():start();local total=0
    for i=1,180 do f.node("Accept"..i,"TextButton",f.root) end
    for _,node in ipairs(f.root:GetDescendants()) do
        for _,entry in ipairs(node.Activated.listeners) do if entry.c.Connected then total=total+1 end end
    end
    assert(total<=80,"unbounded manual button observer connections: "..total)
end)
test("timeout boundary accepts earlier response and rejects response at four seconds",function()
    for _,row in ipairs({{delay=3.99,accepted=true},{delay=4,accepted=false}}) do
        local f=probeFixture():start();f.readDelay=row.delay;assert(f.probe.capture("before"));f:advance(4.1)
        eq(f.probe.snapshots.before~=nil,row.accepted)
    end
end)
test("after without before and wrong native remote class invoke nothing",function()
    local f=probeFixture():start();assert(not f:capture("after"));eq(f.reads,0)
    f.remote.ClassName="RemoteEvent";assert(not f:capture("before"));eq(f.reads,0)
end)
test("two most recent after reads may settle without accepting unequal raw maps",function()
    local f=probeFixture():start();assert(f:capture("before"));f.counts={KnifeA=1};assert(f:capture("after"))
    f.counts={KnifeA=1,KnifeB=1};assert(f:capture("after"));assert(not f.probe.report())
    assert(f:capture("after"));local ok,r=f.probe.report();assert(ok);eq(r.status,"UNCONFIRMED")
end)
test("structured cyclic payload has depth and string bounds without inventory expansion",function()
    local f=probeFixture():start();local data={TradeId=123,Message=string.rep("x",400)};data.Payload=data
    data.Inventory={secret="must not appear"};f.acceptRemote.OnClientEvent:Fire(data)
    local e=assert(event(f.probe,"server-event"));local value=e.payload[1]
    eq(#value.fields.Message.value,160);assert(value.fields.Message.truncated);eq(value.fields.Inventory,nil)
    assert(value.fields.Payload.fields.Payload.fields.Payload.truncated)
end)
print("RESULT "..passed.." passed; "..failed.." failed")
assert(failed==0,"probe regression failures: "..failed)
