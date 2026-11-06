-- Synthetic payloads only: no real Trade.Update schema is assumed here.
local dir = arg[1] or "pdiddler/new_part4"
local chunk = loadfile(dir .. "/p4_trade_update_shape.lua")
assert(type(chunk) == "function", "shape inspector module must exist")
local M = chunk()
assert(type(M) == "table" and type(M.inspect) == "function")
local passed = 0
local function test(name, fn)
    local ok, why = pcall(fn)
    assert(ok, "FAILED " .. name .. ": " .. tostring(why))
    passed = passed + 1
end
local proofFields = {
    "payloadSchemaKnown", "rawKeyPresentConfirmed", "ownerSideSlotBound",
    "eventSessionAssociationProven", "rawItemIdConfirmed", "exactWeaponIdentityConfirmed",
    "serverAttestation", "serverCompletionProven", "causalAttributionProven",
    "authorizesTrade", "authorizesAccept", "mayRecordCompletedTrade", "mayReportProfit",
}
local types = {"NIL", "BOOLEAN", "NUMBER", "STRING", "TABLE", "USERDATA", "FUNCTION", "THREAD", "OTHER"}
local layouts = {"EMPTY", "DENSE_ARRAY", "STRING_MAP", "NUMBER_MAP", "MIXED", "OTHER"}
local reasons = {
    SHAPE_ONLY_UNBOUND=true, INVALID_PACKED_ARGUMENTS=true, METATABLE=true,
    CYCLE=true, DEPTH_LIMIT=true, TABLE_LIMIT=true, ENTRY_LIMIT=true,
    STRING_LIMIT=true, NONFINITE_NUMBER=true, UNSUPPORTED_KEY_TYPE=true, OPAQUE_VALUE=true,
    ALIAS_DEPTH_UNVERIFIED=true,
}
local function keysExactly(t, names)
    local expected = {}
    for _, name in ipairs(names) do expected[name] = true end
    local count = 0
    for key in pairs(t) do
        assert(expected[key], "unexpected output field")
        count = count + 1
    end
    assert(count == #names, "missing output field")
end
local function boundedInteger(n, limit)
    assert(type(n) == "number" and n >= 0 and n <= limit and n % 1 == 0)
end
local function shapeOnly(r)
    local fields = {"schema", "status", "reason", "argumentCount", "argumentTypes", "totalTables",
        "totalEntries", "repeatedTables", "maxDepthObserved", "levels", "shapeComplete", "readOnly",
        "tradeOutcome", "eventOrderingKnown"}
    for _, name in ipairs(proofFields) do fields[#fields+1] = name end
    keysExactly(r, fields)
    assert(r.schema == "gingerscope-trade-update-payload-shape-v1")
    assert(r.status == "INCOMPLETE" or r.status == "PAYLOAD_SHAPE_OBSERVED_UNBOUND")
    assert(reasons[r.reason] and type(r.shapeComplete) == "boolean")
    assert(r.shapeComplete == (r.status == "PAYLOAD_SHAPE_OBSERVED_UNBOUND"))
    assert(r.readOnly == true and r.tradeOutcome == "UNKNOWN" and r.eventOrderingKnown == false)
    for _, name in ipairs(proofFields) do assert(r[name] == false, name) end
    boundedInteger(r.argumentCount, 8)
    assert(#r.argumentTypes == r.argumentCount)
    local allowedTypes = {}
    for _, name in ipairs(types) do allowedTypes[name] = true end
    for i = 1, r.argumentCount do assert(allowedTypes[r.argumentTypes[i]]) end
    for key in pairs(r.argumentTypes) do
        assert(type(key) == "number" and key >= 1 and key <= r.argumentCount and key % 1 == 0)
    end
    boundedInteger(r.totalTables, 32)
    boundedInteger(r.totalEntries, 128)
    boundedInteger(r.repeatedTables, 136)
    boundedInteger(r.maxDepthObserved, 4)
    assert(#r.levels == 4)
    local tableSum, entrySum = 0, 0
    for _, level in ipairs(r.levels) do
        keysExactly(level, {"tables", "entries", "keyTypes", "valueTypes", "layouts"})
        keysExactly(level.keyTypes, {"STRING", "NUMBER", "BOOLEAN", "OTHER"})
        keysExactly(level.valueTypes, types)
        keysExactly(level.layouts, layouts)
        boundedInteger(level.tables, 32)
        boundedInteger(level.entries, 128)
        local keySum, valueSum, layoutSum = 0, 0, 0
        for _, n in pairs(level.keyTypes) do boundedInteger(n, 128); keySum = keySum+n end
        for _, n in pairs(level.valueTypes) do boundedInteger(n, 128); valueSum = valueSum+n end
        for _, n in pairs(level.layouts) do boundedInteger(n, 32); layoutSum = layoutSum+n end
        assert(keySum == level.entries and valueSum == level.entries)
        assert(layoutSum == level.tables)
        tableSum, entrySum = tableSum+level.tables, entrySum+level.entries
    end
    assert(tableSum == r.totalTables and entrySum == r.totalEntries)
    return r
end
local function inspect(...)
    return shapeOnly(M.inspect(table.pack(...)))
end
local function incomplete(reason, ...)
    local r = inspect(...)
    assert(r.status == "INCOMPLETE" and r.reason == reason)
    return r
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

test("no arguments gives a complete empty shape", function()
    local r = inspect()
    assert(r.shapeComplete and r.reason == "SHAPE_ONLY_UNBOUND")
    assert(r.argumentCount == 0 and r.totalTables == 0 and r.totalEntries == 0 and r.maxDepthObserved == 0)
end)
test("packed nil holes retain positions including trailing nil", function()
    local r = inspect(nil, true, 99, "synthetic private alpha", nil)
    assert(r.argumentCount == 5 and same(r.argumentTypes, {"NIL", "BOOLEAN", "NUMBER", "STRING", "NIL"}))
    assert(r.shapeComplete and r.totalEntries == 0)
end)
test("eight arguments including false and zero are valid", function()
    assert(inspect(false, 0, "", nil, {}, {}, true, nil).argumentCount == 8)
end)
test("empty table and dense nested arrays count structure", function()
    local r = inspect({{}, {false, 0, "value"}})
    assert(r.totalTables == 3 and r.totalEntries == 5 and r.maxDepthObserved == 2)
    assert(r.levels[1].layouts.DENSE_ARRAY == 1 and r.levels[1].valueTypes.TABLE == 2)
    assert(r.levels[2].layouts.EMPTY == 1 and r.levels[2].layouts.DENSE_ARRAY == 1)
    assert(r.levels[2].valueTypes.BOOLEAN == 1 and r.levels[2].valueTypes.NUMBER == 1)
end)
test("unknown string keys are only string map counts", function()
    local r = inspect({private_unknown_weapon="secret-id", private_unknown_owner=7})
    assert(r.shapeComplete and r.levels[1].layouts.STRING_MAP == 1)
    assert(r.levels[1].keyTypes.STRING == 2 and r.levels[1].valueTypes.STRING == 1)
end)
test("sparse keys one two four six never become dense arrays", function()
    local r = inspect({[1]="a", [2]="b", [4]="c", [6]="d"})
    assert(r.shapeComplete and r.levels[1].layouts.NUMBER_MAP == 1)
    assert(r.levels[1].layouts.DENSE_ARRAY == 0 and r.totalEntries == 4)
end)
test("zero negative fractional and distant integer keys remain number maps", function()
    for _, key in ipairs({0, -1, 1.5, 1000000000}) do
        assert(inspect({[key]=true}).levels[1].layouts.NUMBER_MAP == 1)
    end
end)
test("mixed and boolean key layouts expose types only", function()
    assert(inspect({[1]=false, unknown="value"}).levels[1].layouts.MIXED == 1)
    local r = inspect({[true]="a", [false]="b"})
    assert(r.shapeComplete and r.levels[1].layouts.OTHER == 1 and r.levels[1].keyTypes.BOOLEAN == 2)
end)
test("synthetic duplicate names chroma and quantities cannot change equal shapes into identity", function()
    local a = inspect({{Name="Gingerscope", Chroma=false, Quantity=1}, {Name="Gingerscope", Chroma=true, Quantity=99}})
    local b = inspect({{Other="private-id-a", Marker=true, Count=-7}, {Other="private-id-b", Marker=false, Count=0}})
    assert(same(a, b) and a.shapeComplete)
end)
test("shared table aliases count once and record repeat edges", function()
    local child = {"synthetic-value"}
    local r = inspect({child, child, child})
    assert(r.shapeComplete and r.totalTables == 2 and r.totalEntries == 4 and r.repeatedTables == 2)
    r = inspect(child, child)
    assert(r.shapeComplete and r.totalTables == 1 and r.totalEntries == 1 and r.repeatedTables == 1)
end)
test("aliases at different depths cannot hide descendants beyond the depth bound", function()
    local child = {leaf={}}
    local outer = {next={next={next=child}}}
    incomplete("ALIAS_DEPTH_UNVERIFIED", child, outer)
    incomplete("ALIAS_DEPTH_UNVERIFIED", outer, child)
end)
test("different depth aliases conservatively refuse even when descendants would fit", function()
    local child = {}
    incomplete("ALIAS_DEPTH_UNVERIFIED", child, {child})
    incomplete("ALIAS_DEPTH_UNVERIFIED", {child}, child)
end)
test("self cycles fail closed with bounded type statistics", function()
    local cyclic = {}; cyclic.secret=cyclic
    local r = incomplete("CYCLE", cyclic)
    assert(r.totalTables == 1 and r.totalEntries == 1 and r.levels[1].valueTypes.TABLE == 1)
end)
test("indirect cycles fail closed", function()
    local a, b = {}, {}; a[1]=b; b[1]=a
    incomplete("CYCLE", a)
end)
test("payload metatable traps are rejected without invocation", function()
    local called = 0
    local function trap() called=called+1; error("metamethod must not run") end
    local payload = setmetatable({hidden="secret"}, {__index=trap, __pairs=trap, __len=trap, __tostring=trap})
    incomplete("METATABLE", payload)
    assert(called == 0)
    incomplete("METATABLE", setmetatable({}, {__metatable=false}))
end)
test("packed argument metatables and index traps are rejected", function()
    local called = false
    local r = shapeOnly(M.inspect(setmetatable({n=1}, {__index=function() called=true; return "private" end})))
    assert(r.status == "INCOMPLETE" and r.reason == "METATABLE" and not called)
end)
test("function thread and userdata values expose only fixed type enums", function()
    local fn, thread = function() end, coroutine.create(function() end)
    assert(incomplete("OPAQUE_VALUE", fn).argumentTypes[1] == "FUNCTION")
    assert(incomplete("OPAQUE_VALUE", thread).argumentTypes[1] == "THREAD")
    local handle = assert(io.tmpfile())
    assert(incomplete("OPAQUE_VALUE", handle).argumentTypes[1] == "USERDATA")
    local r = incomplete("OPAQUE_VALUE", {fn, thread, handle})
    assert(r.levels[1].valueTypes.FUNCTION == 1 and r.levels[1].valueTypes.THREAD == 1 and r.levels[1].valueTypes.USERDATA == 1)
    handle:close()
end)
test("unsupported keys count OTHER without traversing key objects", function()
    for _, key in ipairs({{}, function() end, coroutine.create(function() end)}) do
        local r = incomplete("UNSUPPORTED_KEY_TYPE", {[key]="private-value"})
        assert(r.totalTables == 1 and r.totalEntries == 1 and r.levels[1].keyTypes.OTHER == 1)
        assert(r.levels[1].layouts.OTHER == 1)
    end
end)
test("nonfinite numeric values and keys are invalid", function()
    for _, value in ipairs({math.huge, -math.huge, 0/0}) do
        incomplete("NONFINITE_NUMBER", value)
        assert(incomplete("NONFINITE_NUMBER", {value}).levels[1].valueTypes.NUMBER == 1)
    end
    incomplete("NONFINITE_NUMBER", {[math.huge]=true})
end)
test("string byte bounds accept exactly 4096 and reject longer arguments keys and values", function()
    local exact, over = string.rep("x", 4096), string.rep("z", 4097)
    assert(inspect(exact, {[exact]=exact}).shapeComplete)
    incomplete("STRING_LIMIT", over)
    incomplete("STRING_LIMIT", {[over]=true})
    incomplete("STRING_LIMIT", {over})
end)
test("four table levels are complete while a fifth is bounded", function()
    assert(inspect({{{{}}}}).shapeComplete)
    local r = incomplete("DEPTH_LIMIT", {{{{{}}}}})
    assert(r.maxDepthObserved == 4 and r.totalTables == 4 and r.totalEntries == 4)
end)
test("32 distinct tables fit while the 33rd is bounded", function()
    local exact = {}; for i=1,31 do exact[i]={} end
    assert(inspect(exact).shapeComplete and inspect(exact).totalTables == 32)
    exact[32]={}
    local r = incomplete("TABLE_LIMIT", exact)
    assert(r.totalTables == 32)
end)
test("128 entries fit while the 129th is bounded", function()
    local exact = {}; for i=1,128 do exact[i]=i end
    assert(inspect(exact).shapeComplete and inspect(exact).totalEntries == 128)
    exact[129]=129
    local r = incomplete("ENTRY_LIMIT", exact)
    assert(r.totalEntries == 128 and r.levels[1].layouts.OTHER == 1)
end)
test("entry budget applies across multiple payload tables", function()
    local a, b = {}, {}; for i=1,65 do a[i]=i; b[i]=i end
    assert(incomplete("ENTRY_LIMIT", a, b).totalEntries == 128)
end)
test("malformed packed arguments cannot become complete", function()
    local invalid = {true, 17, "private", {}, {n=-1}, {n=9}, {n=1.5}, {n=math.huge}, {n=0/0},
        {n="1"}, {n=0, [1]="extra"}, {n=1, [0]="extra"}, {n=1, [2]="extra"},
        {n=1, arbitraryPrivateField="extra"}, {n=1, [false]="extra"}}
    local r = shapeOnly(M.inspect(nil)); assert(r.reason == "INVALID_PACKED_ARGUMENTS")
    for _, value in ipairs(invalid) do
        r = shapeOnly(M.inspect(value))
        assert(r.status == "INCOMPLETE" and r.reason == "INVALID_PACKED_ARGUMENTS")
    end
end)
test("oversized malformed argument pack stops without exporting extra fields", function()
    local args = {n=8}; for i=1,1000 do args[i]="private value" end
    assert(shapeOnly(M.inspect(args)).reason == "INVALID_PACKED_ARGUMENTS")
end)
test("stale proof fields remain ordinary unknown payload fields", function()
    local stale = {schema="another-schema", status="VERIFIED", readOnly=false, tradeOutcome="COMPLETED", eventOrderingKnown=true}
    for _, name in ipairs(proofFields) do stale[name]=true end
    local r = inspect(stale)
    assert(r.shapeComplete and r.levels[1].layouts.STRING_MAP == 1)
end)
test("output recursively contains no private tokens references keys values or variable strings", function()
    local source = {private_marker_alpha="private-token-938495", private_marker_uri="rbxassetid://92837492",
        private_marker_owner=8182873, private_marker_nested={{private_marker_id="private-id-4827"}}}
    local r = inspect(source)
    local function scan(node)
        assert(node ~= source and node ~= source.private_marker_nested)
        for key, value in pairs(node) do
            if type(key) == "string" then assert(not key:find("private_marker", 1, true)) end
            if type(value) == "string" then
                assert(not value:find("private", 1, true) and not value:find("rbxassetid", 1, true))
            elseif type(value) == "table" then scan(value) end
        end
    end
    scan(r)
    assert(source.private_marker_alpha == "private-token-938495")
end)
test("fresh reports do not share mutable statistics or authority flags", function()
    local a = inspect({1}); a.payloadSchemaKnown=true; a.levels[1].keyTypes.NUMBER=99
    local b = inspect({1})
    assert(b.payloadSchemaKnown == false and b.levels[1].keyTypes.NUMBER == 1)
end)

print("PASS", passed, "synthetic Trade.Update payload shape tests")
