-- Bounded cache for repeated MM2 market bundle assessments.
-- Pure Luau: no Roblox services, remotes, GUI, scheduler, or network calls.

local M={}

local function positiveInt(v,default)
    v=math.floor(tonumber(v) or default)
    if v<1 then return default end
    return v
end

local function canonicalItemsKey(items,side)
    local parts={tostring(side=="ours" and "ours" or "theirs")}

    if type(items)=="table" then
        local itemParts={}
        for _,item in ipairs(items) do
            if type(item)=="table" then
                itemParts[#itemParts+1]=table.concat({
                    tostring(item.page or ""),
                    tostring(item.id or ""),
                    tostring(tonumber(item.value) or 0),
                    tostring(math.max(1,tonumber(item.qty) or 1)),
                },":")
            end
        end
        table.sort(itemParts)
        for _,part in ipairs(itemParts) do
            parts[#parts+1]=part
        end
    end

    return table.concat(parts,"|")
end

local function newStore(profile,logic,maxEntries)
    assert(type(logic)=="table","market logic required")
    assert(type(logic.bundleAssessment)=="function","market logic bundleAssessment required")

    maxEntries=positiveInt(maxEntries,64)

    local cache={}
    local order={}
    local count=0

    local function remember(key,value)
        if cache[key]~=nil then
            cache[key]=value
            return
        end

        if count>=maxEntries then
            local oldest=table.remove(order,1)
            if oldest~=nil and cache[oldest]~=nil then
                cache[oldest]=nil
                count-=1
            end
        end

        cache[key]=value
        order[#order+1]=key
        count+=1
    end

    local function get(items,side,keyOverride)
        local key=keyOverride or canonicalItemsKey(items,side)
        local hit=cache[key]

        if hit~=nil then
            return hit,"cache"
        end

        local result=logic.bundleAssessment(
            items,
            side=="ours" and "ours" or "theirs",
            profile
        )

        if type(result)=="table" then
            remember(key,result)
        end

        return result,"computed"
    end

    local function clear()
        table.clear(cache)
        table.clear(order)
        count=0
    end

    return {
        get=get,
        clear=clear,
    }
end

function M.new(profile,logic,maxEntries)
    local store=newStore(profile,logic,maxEntries)

    local api={}

    function api.ensure(eval,side)
        assert(type(eval)=="table","evaluation table required")

        local items={}
        for _,r in ipairs(eval.resolved or {}) do
            if type(r)=="table" and r.ineligible~=true then
                items[#items+1]={
                    page=tostring(r.page or ""),
                    id=tostring(r.id or ""),
                    name=tostring(r.name or r.id or ""),
                    value=tonumber(r.rawValue) or 0,
                    qty=math.max(1,tonumber(r.qty) or 1),
                }
            end
        end

        local normalizedSide=side=="ours" and "ours" or "theirs"
        local key=normalizedSide.."|sig|"..tostring(eval.signature or "")
        local market,source=store.get(items,normalizedSide,key)

        eval.market=market
        if type(market)=="table" then
            eval.protectedTotal=tonumber(market.protectedTotal)
                or tonumber(eval.rawTotal)
                or 0
        else
            eval.protectedTotal=tonumber(eval.rawTotal) or 0
        end

        return market,source
    end

    function api.clear()
        store.clear()
    end

    return api
end

function M.wrap(profile,logic,maxEntries)
    local store=newStore(profile,logic,maxEntries)
    local wrapped={}

    function wrapped.bundleAssessment(items,side,profileLookup)
        -- The cache is valid only for the frozen profile it was created with.
        -- If another profile is explicitly supplied, preserve original behavior.
        if profileLookup~=nil and profileLookup~=profile then
            return logic.bundleAssessment(items,side,profileLookup)
        end

        local result=store.get(
            items,
            side=="ours" and "ours" or "theirs"
        )

        return result
    end

    function wrapped.clearBundleCache()
        store.clear()
    end

    return setmetatable(wrapped,{__index=logic})
end

return M
