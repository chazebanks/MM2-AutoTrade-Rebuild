-- pdiddler part 1: independent module smoke test
local M = {}
function M.run(context)
    assert(type(context) == "table", "missing context")
    return {ok = true, module = "health", version = "0.1.0"}
end
return M
