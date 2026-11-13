-- Stage116 geometry derived from the already reviewed Stage100 screen placement
-- contract (original Stage100 artifact Git blob e0eac8e039655999bd7bbac1f12da179db7c22ed).
-- This module is PURE; it has no Roblox GUI instance or trade side effects.
local M = {}
local function number(x)
    return type(x) == "number" and x == x
        and x ~= math.huge and x ~= -math.huge
end
local function overlaps(a,b,gap)
    gap = gap or 0
    return a.x < b.x+b.w+gap and a.x+a.w > b.x-gap
        and a.y < b.y+b.h+gap and a.y+a.h > b.y-gap
end
function M.choose(viewport, trade, requestedSize)
    if type(viewport) ~= "table" or not number(viewport.x)
        or not number(viewport.y) then
        return nil, "VIEWPORT_UNAVAILABLE"
    end
    local W,H = viewport.x,viewport.y
    if W < 300 or H < 260 then return nil, "SCREEN_TOO_SMALL" end
    local margin,top,bottom = 14,72,34
    local size = requestedSize or {}
    if type(size) ~= "table" then return nil,"INVALID_PANEL_SIZE" end
    local rw,rh = size.w or 304,size.h or 144
    if not number(rw) or not number(rh) or rw < 240
        or rw > 512 or rh < 80 or rh > 220 then
        return nil, "INVALID_PANEL_SIZE"
    end
    local width,height = math.min(rw,W-2*margin),rh
    if width < 240 or top+height+bottom > H then
        return nil,"NO_SAFE_PANEL_SIZE"
    end
    if trade ~= nil then
        if type(trade) ~= "table" or not number(trade.x)
            or not number(trade.y) or not number(trade.w)
            or not number(trade.h) or trade.w <= 0 or trade.h <= 0 then
            return nil,"TRADE_BOUNDS_UNAVAILABLE"
        end
    end
    local positions = {
        {margin,top}, {W-margin-width,top},
        {margin,H-bottom-height}, {W-margin-width,H-bottom-height},
        {margin,(H-height)/2}, {W-margin-width,(H-height)/2},
        {(W-width)/2,top}, {(W-width)/2,H-bottom-height},
    }
    for _,pt in ipairs(positions) do
        local p={x=pt[1],y=pt[2],w=width,h=height}
        if p.x>=margin and p.y>=top
            and p.x+width<=W-margin and p.y+height<=H-bottom
            and (trade==nil or not overlaps(p,trade,12)) then
            return p,"NONOVERLAPPING_PANEL_PLACEMENT"
        end
    end
    return nil,"NO_SAFE_SPACE_OUTSIDE_TRADE"
end
return M
