-- pdiddler2: proven T1 tablet picker and T2 optional friend Play
-- Extracted from previous MM2 T8.2.5 startup stack.
-- Standalone module; run() executes Tablet then Friend Play.
local M = {}
function M.run()
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

print("[MM2 Startup T1+T2] START")

local function visible(o)
    if not o then return false end

    local ok, result = pcall(function()
        local c = o
        while c do
            if c:IsA("ScreenGui") and not c.Enabled then
                return false
            end
            if c:IsA("GuiObject") and not c.Visible then
                return false
            end
            c = c.Parent
        end
        return true
    end)

    return ok and result
end

local function textOf(o, fallbackName)
    if not o then return "" end

    local s = ""
    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
        pcall(function()
            s = tostring(o.Text or "")
        end)
    end

    if fallbackName and s == "" then
        s = tostring(o.Name or "")
    end

    return s:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function center(o)
    local ok, p, z = pcall(function()
        return o.AbsolutePosition, o.AbsoluteSize
    end)

    if not ok or not p or not z or z.X <= 1 or z.Y <= 1 then
        return nil
    end

    return p.X + z.X / 2, p.Y + z.Y / 2
end

local function roots()
    local out = {}

    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        out[#out + 1] = pg
    end

    out[#out + 1] = CoreGui

    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then
            out[#out + 1] = h
        end
    end

    return out
end

local function pressButton(button)
    if not button or not visible(button) then
        return false
    end

    local attempted = false

    if firesignal then
        attempted = pcall(function()
            firesignal(button.Activated)
        end) or attempted

        pcall(function()
            firesignal(button.MouseButton1Click)
        end)
    end

    pcall(function()
        button:Activate()
        attempted = true
    end)

    local ok = pcall(function()
        local p = button.AbsolutePosition
        local z = button.AbsoluteSize
        local x = p.X + z.X / 2
        local y = p.Y + z.Y / 2

        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    return attempted or ok
end

-- ============================================================
-- T1: PROVEN TABLET PICKER
-- ============================================================

local function isPhone(t)
    return t == "phone"
        or t == "mobile"
        or t == "mobile phone"
end

local function isTablet(t)
    return t == "tablet"
        or t == "ipad"
        or t == "tablet / ipad"
        or t == "tablet/ipad"
end

local function descendantOf(o, scope)
    local c = o
    while c do
        if c == scope then return true end
        c = c.Parent
    end
    return false
end

local function nearestTabletButton(tabletNode, phoneNode, scope)
    -- Same direct-ancestor preference used by the successful T1 test.
    local c = tabletNode
    for _ = 1, 6 do
        if not c then break end
        if c:IsA("TextButton") or c:IsA("ImageButton") then
            return c
        end
        if c == scope then break end
        c = c.Parent
    end

    -- Same physical-nearest fallback used by the successful T1 test.
    local tx, ty = center(tabletNode)
    local px, py = center(phoneNode)
    if not tx or not px then return nil end

    local best, bestDist
    local ok, list = pcall(function()
        return scope:GetDescendants()
    end)
    if not ok then return nil end

    for _, d in ipairs(list) do
        if visible(d) and (d:IsA("TextButton") or d:IsA("ImageButton")) then
            local bx, by = center(d)
            if bx then
                local dt = (bx - tx)^2 + (by - ty)^2
                local dp = (bx - px)^2 + (by - py)^2

                if dt <= dp and (not bestDist or dt < bestDist) then
                    best = d
                    bestDist = dt
                end
            end
        end
    end

    return best
end

local function findTabletPicker()
    for _, root in ipairs(roots()) do
        local ok, list = pcall(function()
            return root:GetDescendants()
        end)

        if ok then
            local tablets = {}
            local phones = {}

            for _, d in ipairs(list) do
                if visible(d) then
                    local t = textOf(d, true)
                    if isTablet(t) then
                        tablets[#tablets + 1] = d
                    end
                    if isPhone(t) then
                        phones[#phones + 1] = d
                    end
                end
            end

            for _, tabletNode in ipairs(tablets) do
                local scope = tabletNode.Parent

                for _ = 1, 7 do
                    if not scope then break end

                    local phoneNode
                    for _, pnode in ipairs(phones) do
                        if descendantOf(pnode, scope) then
                            phoneNode = pnode
                            break
                        end
                    end

                    if phoneNode then
                        local button = nearestTabletButton(tabletNode, phoneNode, scope)
                        if button then
                            return {
                                button = button,
                                scope = scope,
                            }
                        end
                    end

                    if scope:IsA("ScreenGui") then break end
                    scope = scope.Parent
                end
            end
        end
    end

    return nil
end

local function runTabletStage()
    print("[MM2 Startup T1+T2] T1 waiting for Phone/Tablet picker...")

    local deadline = os.clock() + 25
    local attempts = 0
    local sawPicker = false

    while os.clock() < deadline do
        local picker = findTabletPicker()

        if picker then
            sawPicker = true
            attempts = attempts + 1

            local x, y = center(picker.button)
            print(
                "[MM2 Startup T1+T2] T1 picker found | attempt",
                attempts,
                "| button",
                picker.button:GetFullName(),
                "| center",
                tostring(math.floor(x or -1)),
                tostring(math.floor(y or -1))
            )

            local sent = pressButton(picker.button)
            print("[MM2 Startup T1+T2] T1 Tablet click sent:", sent)

            task.wait(0.6)

            if not findTabletPicker() then
                print("[MM2 Startup T1+T2] T1 SUCCESS - Tablet picker dismissed")
                return true
            end

            warn("[MM2 Startup T1+T2] T1 picker still visible after click")

            if attempts >= 4 then
                warn("[MM2 Startup T1+T2] T1 FAILED - picker remained after 4 attempts")
                return false
            end

            task.wait(0.5)
        else
            task.wait(0.15)
        end
    end

    if not sawPicker then
        warn("[MM2 Startup T1+T2] T1 SKIP - device picker did not appear; continuing")
        return true
    end

    warn("[MM2 Startup T1+T2] T1 FAILED - device picker did not dismiss")
    return false
end

-- ============================================================
-- T2: PROVEN OPTIONAL FRIEND-PLAY BYPASS
-- ============================================================

local function ancestorButton(o, maxDepth)
    local c = o
    for _ = 1, maxDepth or 7 do
        if not c then break end
        if c:IsA("TextButton") or c:IsA("ImageButton") then
            return c
        end
        c = c.Parent
    end
    return nil
end

local function scopeLooksLikeFriendPrompt(scope)
    if not scope then return false end

    local ok, list = pcall(function()
        return scope:GetDescendants()
    end)
    if not ok then return false end

    local hasHeading = false
    local hasJoin = false
    local hasPlay = false

    for _, d in ipairs(list) do
        if visible(d) then
            local t = textOf(d, false)

            if t == "joining a friend?"
                or t:find("joining a friend", 1, true)
            then
                hasHeading = true
            end

            if t == "join" then
                hasJoin = true
            end

            if t == "play" or t == "play anyway" then
                hasPlay = true
            end
        end
    end

    return hasHeading and hasJoin and hasPlay
end

local function findFriendPlayButton()
    for _, root in ipairs(roots()) do
        local ok, list = pcall(function()
            return root:GetDescendants()
        end)

        if ok then
            for _, d in ipairs(list) do
                if visible(d) then
                    local t = textOf(d, false)

                    if t == "play" or t == "play anyway" then
                        local button = ancestorButton(d, 7)

                        if button and visible(button) then
                            local scope = button.Parent

                            for _ = 1, 8 do
                                if not scope then break end

                                if (scope:IsA("Frame")
                                    or scope:IsA("CanvasGroup")
                                    or scope:IsA("ScrollingFrame"))
                                    and scopeLooksLikeFriendPrompt(scope)
                                then
                                    return {
                                        button = button,
                                        scope = scope,
                                    }
                                end

                                if scope:IsA("ScreenGui") then break end
                                scope = scope.Parent
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function pressFriendPlay(button)
    if not button or not visible(button) then
        return false
    end

    -- Absolute safety rule from T2: never click the small Join button.
    if textOf(button, false) == "join" then
        warn("[MM2 Startup T1+T2] T2 SAFETY BLOCK - candidate was Join")
        return false
    end

    return pressButton(button)
end

local function runFriendStage()
    print("[MM2 Startup T1+T2] T2 checking briefly for optional 'Joining a friend?' prompt...")

    local deadline = os.clock() + 3
    local attempts = 0
    local sawPrompt = false

    while os.clock() < deadline do
        local found = findFriendPlayButton()

        if found then
            sawPrompt = true
            attempts = attempts + 1

            local x, y = center(found.button)
            print(
                "[MM2 Startup T1+T2] T2 friend prompt found | attempt",
                attempts,
                "| PLAY button",
                found.button:GetFullName(),
                "| center",
                tostring(math.floor(x or -1)),
                tostring(math.floor(y or -1))
            )

            local sent = pressFriendPlay(found.button)
            print("[MM2 Startup T1+T2] T2 Play click sent:", sent)

            task.wait(0.7)

            if not findFriendPlayButton() then
                print("[MM2 Startup T1+T2] T2 SUCCESS - friend prompt dismissed with Play")
                return true
            end

            warn("[MM2 Startup T1+T2] T2 prompt still visible after Play click")

            if attempts >= 4 then
                warn("[MM2 Startup T1+T2] T2 FAILED - friend prompt remained after 4 attempts")
                return false
            end

            task.wait(0.5)
        else
            task.wait(0.12)
        end
    end

    if not sawPrompt then
        print("[MM2 Startup T1+T2] T2 SKIP - no friend prompt within 3s (normal); continuing")
        return true
    end

    warn("[MM2 Startup T1+T2] T2 FAILED - friend prompt did not dismiss")
    return false
end
local tabletOK = runTabletStage()
if not tabletOK then return false end
return runFriendStage()
end
return M
