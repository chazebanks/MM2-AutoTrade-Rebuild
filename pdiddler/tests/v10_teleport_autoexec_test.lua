-- V10 teleport auto-reentry: pure executor compatibility fixture.
-- Runs on Lua 5.4; no actual Roblox/Delta or network access.
local filename="pdiddler/pdiddler_V10_TELEPORT_AUTOBOOT_v1.lua"
local file=assert(io.open(filename,"r"))
local script=file:read("*a");file:close()
local tests=0
local function test(name,fn)
    local ok,why=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(why),0) end
    tests=tests+1;print("PASS "..name)
end
local REPO="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local fakeCommit=string.rep("a",40)
local AUTOURL=REPO..fakeCommit.."/pdiddler/pdiddler_V10_TELEPORT_AUTOBOOT_v1.lua"
local SOURCE_SHA="58c9aede108b60278b9baa9dd7da73f7a4d95ac5"
local function mock(opts)
    opts=opts or {}
    local o={env={},queue={},fetches={},warnings={},prints={},job=opts.job or "job-1"}
    o.env.PDIDDLER_V10_AUTOBOOT_URL=opts.url or AUTOURL
    local g={}
    g.PlaceId=opts.placeId or 142823291
    g.JobId=o.job
    function g:IsLoaded() return true end
    function g:HttpGet(url)
        o.fetches[#o.fetches+1]=url
        if url==AUTOURL then return script end
        if not url:find(SOURCE_SHA,1,true) then error("unpinned source: "..url) end
        return "return true" -- offline stub for the preexisting pinned V10 modules
    end
    local env={game=g,task={wait=function() end},getgenv=function() return o.env end,
        warn=function(...) o.warnings[#o.warnings+1]=table.concat({...}," ") end,
        print=function(...) o.prints[#o.prints+1]=table.concat({...}," ") end}
    setmetatable(env,{__index=_G})
    env.loadstring=function(chunk) return load(chunk,"executor","t",env) end
    if opts.queueMode=="direct" then
        env.queue_on_teleport=function(code) o.queue[#o.queue+1]=code end
    elseif opts.queueMode=="syn" then
        env.syn={queue_on_teleport=function(code) o.queue[#o.queue+1]=code end}
    elseif opts.queueMode=="reject" then
        env.queueonteleport=function() return false,"rejected" end
    end
    o.sandbox=env
    function o:run(code)
        local fn,err=load(code or script,"bootstrap-test","t",self.sandbox)
        assert(fn,err)
        return fn()
    end
    return o
end
test("direct queue adds only one hook and starts pinned V10",function()
    local m=mock({queueMode="direct"})
    local state=m:run()
    assert(state.queueStatus=="queued" and state.loaderStatus=="launched")
    assert(#m.queue==1 and #m.fetches==2)
    for _,url in ipairs(m.fetches) do
        assert(url:find(SOURCE_SHA,1,true))
    end
    assert(m.queue[1]:find(AUTOURL,1,true),"immutable bootstrap URL not requeued")
end)
test("two launch sources in one JobId cannot double-load or double-queue",function()
    local m=mock({queueMode="direct"})
    local a=m:run();local b=m:run()
    assert(a==b and #m.queue==1 and #m.fetches==2)
end)
test("queued code starts another job and queues for a third",function()
    local first=mock({queueMode="direct"})
    first:run()
    local nextJob=mock({queueMode="direct",job="job-2"})
    nextJob.env.PDIDDLER_V10_AUTOBOOT_URL=nil
    nextJob:run(first.queue[1])
    assert(nextJob.env.PDIDDLER_V10_AUTOBOOT_URL==AUTOURL)
    assert(#nextJob.fetches==3)
    assert(#nextJob.queue==1)
    assert(nextJob.env.PDIDDLER_V10_TELEPORT_AUTOBOOT_v1.jobId=="job-2")
    nextJob:run(first.queue[1])
    assert(#nextJob.queue==1 and #nextJob.fetches==3)
end)
test("syn.queue_on_teleport fallback supported without touching global queue",function()
    local m=mock({queueMode="syn"})
    local state=m:run()
    assert(state.queueStatus=="queued" and #m.queue==1)
end)
test("queue unavailable doesn't prevent initial launch",function()
    local m=mock()
    local state=m:run()
    assert(state.queueStatus=="unsupported" and state.loaderStatus=="launched")
    assert(#m.fetches==2 and #m.warnings==1)
end)
test("rejected queue reports failure but still starts initial V10",function()
    local m=mock({queueMode="reject"})
    local state=m:run()
    assert(state.queueStatus=="failed" and state.loaderStatus=="launched")
    assert(#m.fetches==2)
end)
test("other Roblox places do not run the trader or create queue",function()
    local m=mock({queueMode="direct",placeId=1234567})
    assert(m:run()==nil and #m.queue==0 and #m.fetches==0)
end)
test("no fixed commit URL refuses to queue or run",function()
    local m=mock({queueMode="direct",url=REPO.."main/pdiddler/pdiddler_V10_TELEPORT_AUTOBOOT_v1.lua"})
    local state=m:run()
    assert(state.loaderStatus=="starting" and #m.fetches==0 and #m.queue==0)
end)
print("RESULT "..tests.." V10 teleport auto-reentry mock tests passed")
