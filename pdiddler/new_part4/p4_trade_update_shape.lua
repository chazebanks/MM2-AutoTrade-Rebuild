-- Read-only aggregate census of an unknown payload schema. No item resolver.
-- The argument pack itself is excluded from table/entry/depth aggregates.
local M = {}
local rawNext, rawGet, meta, luaType = next, rawget, getmetatable, type
local typeNames = {
    ["nil"]="NIL", boolean="BOOLEAN", number="NUMBER", string="STRING",
    table="TABLE", userdata="USERDATA", ["function"]="FUNCTION", thread="THREAD",
}
local reasonRank = {
    SHAPE_ONLY_UNBOUND=0, OPAQUE_VALUE=1, UNSUPPORTED_KEY_TYPE=2,
    NONFINITE_NUMBER=3, STRING_LIMIT=4, ENTRY_LIMIT=5, TABLE_LIMIT=6,
    DEPTH_LIMIT=7, ALIAS_DEPTH_UNVERIFIED=8, METATABLE=9, CYCLE=10, INVALID_PACKED_ARGUMENTS=11,
}
local function typeName(value)
    return typeNames[luaType(value)] or "OTHER"
end
local function finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end
local function level()
    return {
        tables=0, entries=0,
        keyTypes={STRING=0, NUMBER=0, BOOLEAN=0, OTHER=0},
        valueTypes={NIL=0, BOOLEAN=0, NUMBER=0, STRING=0, TABLE=0,
            USERDATA=0, FUNCTION=0, THREAD=0, OTHER=0},
        layouts={EMPTY=0, DENSE_ARRAY=0, STRING_MAP=0, NUMBER_MAP=0, MIXED=0, OTHER=0},
    }
end
local function report()
    return {
        schema="gingerscope-trade-update-payload-shape-v1",
        status="PAYLOAD_SHAPE_OBSERVED_UNBOUND", reason="SHAPE_ONLY_UNBOUND", shapeComplete=true,
        argumentCount=0, argumentTypes={}, totalTables=0, totalEntries=0,
        repeatedTables=0, maxDepthObserved=0, levels={level(), level(), level(), level()},
        payloadSchemaKnown=false, rawKeyPresentConfirmed=false, ownerSideSlotBound=false,
        eventSessionAssociationProven=false, rawItemIdConfirmed=false,
        exactWeaponIdentityConfirmed=false, serverAttestation=false,
        serverCompletionProven=false, causalAttributionProven=false,
        authorizesTrade=false, authorizesAccept=false, mayRecordCompletedTrade=false,
        mayReportProfit=false, readOnly=true, tradeOutcome="UNKNOWN", eventOrderingKnown=false,
    }
end

function M.inspect(args)
    local result = report()
    local function fail(reason)
        result.shapeComplete = false
        result.status = "INCOMPLETE"
        -- A fixed priority makes competing failure kinds independent of key order.
        if reasonRank[reason] > reasonRank[result.reason] then result.reason = reason end
    end
    if luaType(args) ~= "table" then
        fail("INVALID_PACKED_ARGUMENTS")
        return result
    end
    if meta(args) ~= nil then
        fail("METATABLE")
        return result
    end
    local n = rawGet(args, "n")
    if luaType(n) ~= "number" or not finite(n) or n < 0 or n > 8 or n % 1 ~= 0 then
        fail("INVALID_PACKED_ARGUMENTS")
        return result
    end
    result.argumentCount = n
    for i=1,n do result.argumentTypes[i] = typeName(rawGet(args, i)) end
    local packKey = nil
    while true do
        packKey = rawNext(args, packKey)
        if packKey == nil then break end
        if packKey ~= "n" and (luaType(packKey) ~= "number" or not finite(packKey)
            or packKey < 1 or packKey > n or packKey % 1 ~= 0) then
            fail("INVALID_PACKED_ARGUMENTS")
            return result
        end
    end

    local seen, active = {}, {}
    local visitTable
    local function visitValue(value, depth)
        local kind = typeName(value)
        if kind == "TABLE" then
            visitTable(value, depth)
        elseif kind == "STRING" then
            if #value > 4096 then fail("STRING_LIMIT") end
        elseif kind == "NUMBER" then
            if not finite(value) then fail("NONFINITE_NUMBER") end
        elseif kind == "USERDATA" or kind == "FUNCTION" or kind == "THREAD" or kind == "OTHER" then
            fail("OPAQUE_VALUE")
        end
    end
    visitTable = function(value, depth)
        if seen[value] then
            result.repeatedTables = result.repeatedTables + 1
            if active[value] then fail("CYCLE") end
            -- Descendants are traversed once. A second path at another depth
            -- cannot inherit the first path's depth validation, even if empty.
            if seen[value] ~= depth then fail("ALIAS_DEPTH_UNVERIFIED") end
            if depth > 4 then fail("DEPTH_LIMIT") end
            return
        end
        if depth > 4 then fail("DEPTH_LIMIT"); return end
        if result.totalTables >= 32 then fail("TABLE_LIMIT"); return end
        seen[value], active[value] = depth, true
        result.totalTables = result.totalTables + 1
        if depth > result.maxDepthObserved then result.maxDepthObserved = depth end
        local stats = result.levels[depth]
        stats.tables = stats.tables + 1
        if meta(value) ~= nil then
            fail("METATABLE")
            stats.layouts.OTHER = stats.layouts.OTHER + 1
            active[value] = nil
            return
        end

        local key, count, stringKeys, numberKeys, booleanKeys = nil, 0, 0, 0, 0
        local dense, maxIndex, unsupported, truncated = true, 0, false, false
        while true do
            local entryValue
            key, entryValue = rawNext(value, key)
            if key == nil then break end
            if result.totalEntries >= 128 then
                fail("ENTRY_LIMIT")
                truncated = true
                break
            end
            result.totalEntries = result.totalEntries + 1
            stats.entries = stats.entries + 1
            count = count + 1
            local keyKind = typeName(key)
            if keyKind == "STRING" then
                stringKeys = stringKeys + 1
                stats.keyTypes.STRING = stats.keyTypes.STRING + 1
                if #key > 4096 then fail("STRING_LIMIT") end
            elseif keyKind == "NUMBER" then
                numberKeys = numberKeys + 1
                stats.keyTypes.NUMBER = stats.keyTypes.NUMBER + 1
                if not finite(key) then
                    fail("NONFINITE_NUMBER")
                    dense = false
                elseif key < 1 or key % 1 ~= 0 then
                    dense = false
                elseif key > maxIndex then
                    maxIndex = key
                end
            elseif keyKind == "BOOLEAN" then
                booleanKeys = booleanKeys + 1
                stats.keyTypes.BOOLEAN = stats.keyTypes.BOOLEAN + 1
            else
                stats.keyTypes.OTHER = stats.keyTypes.OTHER + 1
                unsupported = true
                fail("UNSUPPORTED_KEY_TYPE")
            end
            local valueKind = typeName(entryValue)
            stats.valueTypes[valueKind] = stats.valueTypes[valueKind] + 1
            visitValue(entryValue, depth + 1)
        end
        local layout
        if truncated or unsupported then layout = "OTHER"
        elseif count == 0 then layout = "EMPTY"
        elseif numberKeys == count then
            if dense and maxIndex == count then layout = "DENSE_ARRAY" else layout = "NUMBER_MAP" end
        elseif stringKeys == count then layout = "STRING_MAP"
        elseif booleanKeys == count then layout = "OTHER"
        else layout = "MIXED" end
        stats.layouts[layout] = stats.layouts[layout] + 1
        active[value] = nil
    end
    for i=1,n do visitValue(rawGet(args, i), 1) end
    return result
end

return M
