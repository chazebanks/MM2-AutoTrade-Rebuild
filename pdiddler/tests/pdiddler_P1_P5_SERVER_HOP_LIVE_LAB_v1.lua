-- PDIDDLER P1 + P5 SERVER HOP LIVE LAB v1
-- Standalone transport validation only.
-- This LAB intentionally does not inspect inventories or claim true trade exhaustion.
-- Good lobby: wait 45 seconds, then exercise the Part 5 hopper transport.
-- Bot lobby: Part 1 remains authority and Part 5 immediately re-hops.

print("[PDIDDLER LAB] P1 + P5 SERVER HOP LIVE LAB")

local ENV=(getgenv and getgenv()) or _G
ENV.PDIDDLER_P1P5_LAB_SESSION=(tonumber(ENV.PDIDDLER_P1P5_LAB_SESSION) or 0)+1
local LAB_SESSION=ENV.PDIDDLER_P1P5_LAB_SESSION

local function labAlive()
    return ENV.PDIDDLER_P1P5_LAB_SESSION==LAB_SESSION
end

local function loadModule(url,label)
    local ok,src=pcall(function()
        return game:HttpGet(url,true)
    end)
    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER LAB] "..tostring(label).." HTTP failed: "..tostring(src))
    end

    local fn,err=loadstring(src)
    if not fn then
        error("[PDIDDLER LAB] "..tostring(label).." compile failed: "..tostring(err))
    end

    local runOk,result=pcall(fn)
    if not runOk then
        error("[PDIDDLER LAB] "..tostring(label).." init failed: "..tostring(result))
    end
    return result
end

local HOPPER_COMMIT="fa288984552e95fc13be01ec9c9b58bf7c9fb914"
local HOPPER_BASE=
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
    ..HOPPER_COMMIT
    .."/pdiddler/"

local policy=loadModule(
    HOPPER_BASE.."pdiddler5_server_hopper_policy_v1.lua",
    "Part 5 policy"
)
local part5=loadModule(
    HOPPER_BASE.."pdiddler5_server_hopper_v1.lua",
    "Part 5 runtime"
)

local hopper=part5.bootstrap(policy)

local p1=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
    "Part 1 known-good bot detector"
)

local ok1,res1=pcall(p1.run)
if not ok1 then
    warn("[PDIDDLER LAB] PART 1 ERROR | "..tostring(res1))
    return false
end

if res1~=true then
    print("[PDIDDLER LAB] PART 1 BOT REJECTED | immediate Part 5 re-hop")
    local started,why=hopper:handleBotRejected("part1-bot-rejected")
    if not started and why~="already-hopping" and why~="another-hopper-active" then
        warn("[PDIDDLER LAB] BOT RE-HOP NOT STARTED | "..tostring(why))
    end
    return true
end

print("[PDIDDLER LAB] PART 1 APPROVED | standalone hopper test armed")
print("[PDIDDLER LAB] LAB COUNTDOWN | 45 seconds | test-only trigger")

local startedAt=os.clock()
while labAlive() do
    local elapsed=os.clock()-startedAt
    if elapsed>=45 then
        break
    end
    task.wait(0.25)
end

if not labAlive() then
    return false
end

print("[PDIDDLER LAB] LAB COUNTDOWN COMPLETE | invoking Part 5 transport")
local started,why=hopper:hopNow("p1-p5-lab-45s")
if not started and why~="already-hopping" and why~="another-hopper-active" then
    warn("[PDIDDLER LAB] HOP NOT STARTED | "..tostring(why))
end

return true
