-- pdiddler completed-trade completion logic v1
-- Pure Luau. Raw Weapons.Owned keys only.

local M={}

local function qty(v)
    local n=tonumber(v)
    if not n or n~=n or n<1 then return nil end
    n=math.floor(n)
    if n<1 then return nil end
    return n
end

function M.expectedDelta(snapshot)
    if type(snapshot)~="table" then return nil,false end

    local delta={}
    local sawAny=false

    local function add(items,sign)
        if type(items)~="table" then return true end

        for _,it in ipairs(items) do
            if type(it)~="table" then return false end

            local id=tostring(it.id or "")
            local q=qty(it.qty)
            if id=="" or not q then
                return false
            end

            sawAny=true
            delta[id]=(delta[id] or 0)+(sign*q)
        end

        return true
    end

    if not add(snapshot.gave,-1) then return nil,false end
    if not add(snapshot.received,1) then return nil,false end
    if not sawAny then return delta,false end

    local useful=false
    for _,v in pairs(delta) do
        if v~=0 then
            useful=true
            break
        end
    end

    return delta,useful
end

function M.deltaMatches(before,after,delta)
    if type(before)~="table" or type(after)~="table" or type(delta)~="table" then
        return false,"invalid-inventory"
    end

    local useful=false

    for id,want in pairs(delta) do
        want=tonumber(want) or 0

        if want~=0 then
            useful=true
            local b=tonumber(before[id]) or 0
            local a=tonumber(after[id]) or 0
            local got=a-b

            if got~=want then
                return false,"delta-mismatch:"..tostring(id)
            end
        end
    end

    if not useful then
        return false,"no-useful-delta"
    end

    return true,"matched"
end

function M.fresh(snapshot,now,maxAge)
    if type(snapshot)~="table" then return false end

    local captured=tonumber(snapshot.capturedAt)
    now=tonumber(now)
    maxAge=tonumber(maxAge) or 0

    if not captured or not now or maxAge<0 then return false end

    local age=now-captured
    return age>=0 and age<=maxAge
end

return M
