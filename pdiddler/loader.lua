-- pdiddler / Part 1 / Modular loader
-- Execute this file in an environment supporting game:HttpGet and loadstring.
-- Each module is compiled separately to avoid oversized local scopes.
local BASE = "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/main/"
local state = {name = "pdiddler", version = "0.1.0", modules = {}, errors = {}}

local function fetchModule(path)
    assert(type(game.HttpGet) == "function", "HttpGet unavailable")
    assert(type(loadstring) == "function", "loadstring unavailable")
    local source = game:HttpGet(BASE .. path)
    assert(type(source) == "string" and #source > 0, "empty module: " .. path)
    local chunk, compileError = loadstring(source, "=" .. path)
    assert(chunk, compileError)
    local ok, module = pcall(chunk)
    assert(ok, module)
    assert(type(module) == "table", "module must return a table: " .. path)
    return module
end

local function boot()
    local ok, result = pcall(function()
        local module = fetchModule("pdiddler/core/health.lua")
        return module.run(state)
    end)
    if ok and result and result.ok then
        state.modules.health = result
        print("[pdiddler] Part 1 PASS | modular loader ready")
    else
        local err = tostring(result)
        state.errors[#state.errors + 1] = err
        warn("[pdiddler] Part 1 FAIL | " .. err)
    end
    return state
end

return boot()
