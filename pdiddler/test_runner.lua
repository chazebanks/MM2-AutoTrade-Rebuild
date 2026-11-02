-- pdiddler test harness v1: test parts independently
-- Run this file via Delta after the part's source is available on GitHub.
-- Does not alter the tested module or automatically run other parts.
local BASE = "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/main/pdiddler/"
local PART = "pdiddler1.lua"
local function run()
    local okFetch, source = pcall(function() return game:HttpGet(BASE .. PART) end)
    if not okFetch or type(source) ~= "string" or #source == 0 then
        warn("[pdiddler TEST] FAIL download: " .. tostring(source))
        return
    end
    local compiled, err = loadstring(source, "=" .. PART)
    if not compiled then
        warn("[pdiddler TEST] FAIL compile: " .. tostring(err))
        return
    end
    local okLoad, module = pcall(compiled)
    if not okLoad or type(module) ~= "table" or type(module.run) ~= "function" then
        warn("[pdiddler TEST] FAIL module: " .. tostring(module))
        return
    end
    local okRun, result = pcall(module.run)
    if not okRun then
        warn("[pdiddler TEST] FAIL runtime: " .. tostring(result))
    elseif type(result) ~= "boolean" then
        warn("[pdiddler TEST] FAIL unexpected return: " .. tostring(result))
    else
        print("[pdiddler TEST] PASS execution | bot gate: " .. (result and "APPROVED" or "REJECTED"))
        print("[pdiddler TEST] Note: server classification accuracy requires manual verification.")
    end
end
run()
