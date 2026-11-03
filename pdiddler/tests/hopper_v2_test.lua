local F=dofile("pdiddler/tests/integration_fixture.lua")
local path=arg[1] or "pdiddler/pdiddler5_server_hopper_v2.lua"
local passed,failed=0,0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) local ok,err=pcall(fn); if ok then passed=passed+1; print("PASS "..name) else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end end
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={Connected=true}; function c:Disconnect() self.Connected=false end
        self.listeners[#self.listeners+1]={fn=fn,c=c}; return c
    end
    function s:fire(...) for _,v in ipairs(self.listeners) do if v.c.Connected then v.fn(...) end end end
    return s
end
local function setup(o)
    o=o or {}; local f=F.new(); f.calls={}; f.httpCalls=0; f.saved={}
    local ts={TeleportInitFailed=signal()}; f.lp.OnTeleport=signal()
    f.scope.Enum={TeleportState={Failed="Failed",Started="Started",WaitingForServer="Waiting",InProgress="Progress"}}
    function ts:GetTeleportSetting() return o.persisted end
    function ts:SetTeleportSetting(k,v) f.saved[k]=v end
    function ts:TeleportToPlaceInstance(place,id,player)
        eq(place,142823291); eq(player,f.lp); f.calls[#f.calls+1]=id
        if o.callDelay then f.task.wait(o.callDelay) end
        if o.staleFailure then
            if id=="s11" then f.task.delay(1,function() self.TeleportInitFailed:fire(f.lp,"Failure","full",142823291,{ServerInstanceId=id}) end)
            else
                f.lp.OnTeleport:fire("Started")
                f.task.delay(1,function() self.TeleportInitFailed:fire(f.lp,"Failure","old failure",142823291,nil) end)
            end
        end
        if o.callError then error("teleport-denied") end
        if o.progress then f.lp.OnTeleport:fire("Started") end
        if o.lateFailure then f.task.delay(3,function() self.TeleportInitFailed:fire(f.lp,"Failure","denied",142823291,{ServerInstanceId=id}) end) end
        if o.success then f.task.delay(1,function() f.game.JobId="new-job" end) end
    end
    f.services={TeleportService=ts,HttpService={JSONDecode=function(_,body)
        if body=="bad-json" then error("bad-json") end
        if body=="persisted" then return {version=1,visited={"s11"}} end
        return {data={{id="s10",playing=10,maxPlayers=12},{id="s11",playing=11,maxPlayers=12},{id="s11b",playing=11,maxPlayers=12}},nextPageCursor=nil}
    end,JSONEncode=function() return "encoded-state" end,UrlEncode=function(_,s) return s end}}
    function f.game:HttpGet(url)
        assert(url:match("games.roblox.com/v1/games/142823291/servers/Public"))
        f.httpCalls=f.httpCalls+1
        if o.httpDelay then f.task.wait(o.httpDelay) end
        if o.httpError then error("http-denied") end
        return o.badJson and "bad-json" or "servers"
    end
    -- Execute actual policy and transport; only network/services/scheduler are doubles.
    local policy=dofile("pdiddler/tests/fixtures/p5_policy_v1.lua")
    local file=assert(io.open(path)); local code=file:read("*a"); file:close()
    -- Original P5 uses Luau += and continue: targeted translation for baseline repro.
    code=code:gsub("n11%+=1","n11=n11+1"):gsub("n10%+=1","n10=n10+1"):gsub("S.attemptSerial%+=1","S.attemptSerial=S.attemptSerial+1")
    code=code:gsub("continue","goto nextRefresh"):gsub("\n        end\n\n        S.hopping=false","\n            ::nextRefresh::\n        end\n\n        S.hopping=false")
    f.module=assert(load(code,"@"..path,"t",f.scope))()
    f.hopper=f.module.bootstrap(policy,o.guard and function() return o.guard(f) end)
    f.ts=ts; f.policy=policy
    return f
end
test("11/12 before 10/12; synchronous failures serialize",function()
    local f=setup({callError=true}); assert(f.hopper:hopNow("test")); f:advance(40)
    eq(f.calls[1],"s11"); eq(f.calls[2],"s11b"); eq(f.calls[3],"s10"); eq(#f.calls,3)
end)
test("HTTP permission failure terminates within budget",function()
    local f=setup({httpError=true}); f.hopper:hopNow("test"); f:advance(40)
    eq(#f.calls,0); eq(f.hopper.state.terminal,true); assert(f.httpCalls<=2)
end)
test("hung HTTP cannot later initiate teleport",function()
    local f=setup({httpDelay=100}); f.hopper:hopNow("test"); f:advance(40)
    eq(f.hopper.state.terminal,true); f:advance(150); eq(#f.calls,0)
end)
test("malformed server JSON stops bounded discovery",function()
    local f=setup({badJson=true}); f.hopper:hopNow("test"); f:advance(40); eq(f.hopper.state.terminal,true); eq(#f.calls,0)
end)
test("Started without completion enters terminal hold",function()
    local f=setup({progress=true}); f.hopper:hopNow("test"); f:advance(60)
    eq(#f.calls,1); eq(f.hopper.state.terminal,true); eq(f.hopper.state.hopping,true)
    local ok=f.hopper:hopNow("again"); eq(ok,false)
end)
test("silent teleport response never causes competing attempt",function()
    local f=setup(); f.hopper:hopNow("test"); f:advance(60); eq(#f.calls,1); eq(f.hopper.state.terminal,true)
end)
test("yielding teleport call enters hold without retry",function()
    local f=setup({callDelay=100,progress=true}); f.hopper:hopNow("test"); f:advance(60); eq(#f.calls,1); eq(f.hopper.state.terminal,true)
    f:advance(150); eq(#f.calls,1)
end)
test("explicit late failure releases attempt and tries next",function()
    local f=setup({progress=true,lateFailure=true}); f.hopper:hopNow("test"); f:advance(40)
    eq(f.calls[1],"s11"); eq(f.calls[2],"s11b"); eq(f.calls[3],"s10"); eq(#f.calls,3)
end)
test("actual job change ends hop monitor",function()
    local f=setup({progress=true,success=true}); f.hopper:hopNow("test"); f:advance(5); eq(#f.calls,1); eq(f.hopper.state.hopping,false)
end)
test("duplicate bootstrap retains controller",function()
    local f=setup(); eq(f.module.bootstrap(f.policy),f.hopper)
    assert(f.hopper:hopNow("test")); eq(f.hopper:hopNow("duplicate"),false); f:advance(3); eq(#f.calls,1)
end)
test("visited teleport settings exclude previous targets",function()
    local f=setup({persisted="persisted",callError=true}); f.hopper:hopNow("test"); f:advance(40)
    eq(f.calls[1],"s11b"); eq(f.calls[2],"s10"); eq(#f.calls,2); assert(next(f.saved))
end)
test("stop refuses to abandon an in-flight teleport",function()
    local f=setup({progress=true}); f.hopper:hopNow("test"); f:advance(1); eq(f.hopper:stop(),false)
end)
test("late unattributed failure cannot supersede progressing next attempt",function()
    local f=setup({staleFailure=true}); f.hopper:hopNow("test"); f:advance(60)
    eq(#f.calls,2); eq(f.calls[2],"s11b"); eq(f.hopper.state.terminal,true); eq(f.hopper.state.hopping,true)
end)
test("safety change during server discovery prevents delayed teleport",function()
    local f=setup({httpDelay=2,guard=function(x) return x.now<1,"new-request-or-trader" end})
    f.hopper:hopNow("test"); f:advance(20); eq(#f.calls,0); eq(f.hopper.state.terminal,true)
end)
print(string.format("%d passed, %d failed",passed,failed)); os.exit(failed==0 and 0 or 1)
