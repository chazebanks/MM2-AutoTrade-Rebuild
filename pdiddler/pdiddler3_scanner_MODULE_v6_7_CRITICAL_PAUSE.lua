-- pdiddler3 SCANNER-ONLY TEST (safe first-stage validation)
-- Extracted T4.4 live eligibility scanner from proven prior build.
-- No outgoing requests, no incoming acceptance, no final trade acceptance.
-- This is not the complete Part 3 implementation.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ENV=(getgenv and getgenv()) or _G

local LP = Players.LocalPlayer
if not LP then
    warn("[MM2 Scanner T4] LocalPlayer missing")
    return
end

local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

local function activeTradeGui()
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local g=PG:FindFirstChild(name)
        local c=g and g:FindFirstChild("Container")
        local t=c and c:FindFirstChild("Trade")

        if t then
            local enabled=true
            if g:IsA("ScreenGui") then
                local ok,v=pcall(function() return g.Enabled end)
                if ok then enabled=v end
            end
            if enabled then
                return true
            end
        end
    end

    return false
end

local function criticalTradeActivity()
    if tostring(ENV.PDIDDLER_STATUS_OWNER or "")=="P4" then
        return true,"part4"
    end

    if ENV.PDIDDLER_OUTGOING_BUSY_SESSION~=nil then
        return true,"outgoing"
    end

    if activeTradeGui() then
        return true,"trade-gui"
    end

    return false,nil
end

local function waitForScannerWindow(p)
    while p and p.Parent do
        local busy=criticalTradeActivity()
        if not busy then
            return true
        end
        task.wait(0.25)
    end

    return false
end

local C = {
    TargetScanRetries = 3,
    TargetScanRetryDelay = 0.55,

    -- New-player profiles can take several seconds to become readable.
    JoinScanRetries = 12,
    JoinScanRetryDelay = 1.25,

    -- If a player is still unreadable after the join window, keep retrying
    -- in the background instead of leaving them permanently UNKNOWN.
    UnknownRetryDelay = 2.5,
    UnknownRetryMax = 12,

    -- Inventory remote pacing / live refresh.
    RemoteMinInterval = 0.18,
    RemoteTimeout = 4.5,
    PeriodicRescanSeconds = 45,
    PeriodicRescanGap = 0.55,
}

local function log(...)
    print("[MM2 Scanner T4]", ...)
end

local function norm(x)
    return tostring(x or ""):gsub("’","'"):lower():gsub("[^%w]","")
end

log("START")

-- ============================================================================
-- T4.1 ON-SCREEN TEST GUI
-- ============================================================================

local GUI = {
    screen = nil,
    frame = nil,
    titleBar = nil,
    status = nil,
    summary = nil,
    list = nil,
    layout = nil,
    minimize = nil,
    rows = {},
    rowRenderCache = {},
    statusRenderCache = nil,
    summaryRenderCache = nil,
    minimized = false,
    fullSize = UDim2.fromOffset(470, 520),
    miniSize = UDim2.fromOffset(470, 105),
}

local function guiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then
            return h
        end
    end

    return LP:WaitForChild("PlayerGui")
end

local function destroyOldGui()
    local roots = {
        LP:FindFirstChildOfClass("PlayerGui"),
        CoreGui,
    }

    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then
            roots[#roots + 1] = h
        end
    end

    for _, root in ipairs(roots) do
        if root then
            local old = root:FindFirstChild("MM2EligibilityScannerT41")
            if old then
                pcall(function()
                    old:Destroy()
                end)
            end
        end
    end
end

local function makeText(parent, name, text, size, pos, fontSize)
    local x = Instance.new("TextLabel")
    x.Name = name
    x.Parent = parent
    x.BackgroundTransparency = 1
    x.BorderSizePixel = 0
    x.Size = size
    x.Position = pos or UDim2.new()
    x.Font = Enum.Font.Gotham
    x.TextSize = fontSize or 16
    x.TextColor3 = Color3.fromRGB(238, 241, 245)
    x.TextXAlignment = Enum.TextXAlignment.Left
    x.TextYAlignment = Enum.TextYAlignment.Center
    x.TextWrapped = true
    x.Text = text or ""
    return x
end

local function createGui()
    destroyOldGui()

    local screen = Instance.new("ScreenGui")
    screen.Name = "MM2EligibilityScannerT41"
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        screen.IgnoreGuiInset = true
    end)
    screen.Parent = guiParent()

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Parent = screen
    frame.Size = GUI.fullSize
    frame.Position = UDim2.new(0, 14, 0.14, 0)
    frame.BackgroundColor3 = Color3.fromRGB(55, 22, 88)
    frame.BackgroundTransparency = 0.04
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ClipsDescendants = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Color = Color3.fromRGB(185, 120, 255)
    stroke.Parent = frame

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = frame
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.fromOffset(0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(32, 12, 52)
    titleBar.BackgroundTransparency = 0.08
    titleBar.BorderSizePixel = 0
    titleBar.Active = true

    local title = makeText(
        titleBar,
        "Title",
        "MM2 T4.4 Live Eligibility Scanner",
        UDim2.new(1, -74, 1, 0),
        UDim2.fromOffset(14, 0),
        18
    )
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(235, 214, 255)

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.Parent = titleBar
    minimize.Size = UDim2.fromOffset(42, 30)
    minimize.Position = UDim2.new(1, -52, 0, 5)
    minimize.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    minimize.BackgroundTransparency = 0.08
    minimize.BorderSizePixel = 0
    minimize.Font = Enum.Font.GothamBold
    minimize.TextSize = 18
    minimize.TextColor3 = Color3.fromRGB(238, 241, 245)
    minimize.Text = "—"

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 8)
    minCorner.Parent = minimize

    local minStroke = Instance.new("UIStroke")
    minStroke.Thickness = 1
    minStroke.Transparency = 0.15
    minStroke.Color = Color3.fromRGB(175, 105, 245)
    minStroke.Parent = minimize

    local status = makeText(
        frame,
        "Status",
        "Starting scanner...",
        UDim2.new(1, -28, 0, 42),
        UDim2.fromOffset(14, 42),
        14
    )
    status.TextColor3 = Color3.fromRGB(219, 190, 255)

    local summary = makeText(
        frame,
        "Summary",
        "Whitelist 0  |  Blacklist 0  |  Unknown 0",
        UDim2.new(1, -28, 0, 28),
        UDim2.fromOffset(14, 84),
        14
    )
    summary.Font = Enum.Font.GothamSemibold
    summary.TextColor3 = Color3.fromRGB(255, 255, 255)

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Parent = frame
    divider.BorderSizePixel = 0
    divider.BackgroundColor3 = Color3.fromRGB(184, 115, 255)
    divider.BackgroundTransparency = 0.25
    divider.Size = UDim2.new(1, -28, 0, 1)
    divider.Position = UDim2.fromOffset(14, 116)

    local list = Instance.new("ScrollingFrame")
    list.Name = "PlayerList"
    list.Parent = frame
    list.Position = UDim2.fromOffset(12, 126)
    list.Size = UDim2.new(1, -24, 1, -138)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.ScrollBarImageColor3 = Color3.fromRGB(190, 125, 255)
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    pcall(function()
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    end)

    local padding = Instance.new("UIPadding")
    padding.Parent = list
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.PaddingRight = UDim.new(0, 2)
    padding.PaddingTop = UDim.new(0, 2)

    local layout = Instance.new("UIListLayout")
    layout.Parent = list
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(
            0,
            layout.AbsoluteContentSize.Y + 12
        )
    end)

    -- Dragging: touch or mouse from the title bar.
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function updateDrag(input)
        if not dragging or not dragStart or not startPos then
            return
        end

        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput then
            updateDrag(input)
        end
    end)

    local function applyMinimized()
        if GUI.minimized then
            frame.Size = GUI.miniSize
            list.Visible = false
            divider.Visible = false
            summary.Position = UDim2.fromOffset(14, 72)
            status.Size = UDim2.new(1, -28, 0, 30)
            status.Position = UDim2.fromOffset(14, 40)
            minimize.Text = "+"
        else
            frame.Size = GUI.fullSize
            list.Visible = true
            divider.Visible = true
            summary.Position = UDim2.fromOffset(14, 84)
            status.Size = UDim2.new(1, -28, 0, 42)
            status.Position = UDim2.fromOffset(14, 42)
            minimize.Text = "—"
        end
    end

    minimize.MouseButton1Click:Connect(function()
        GUI.minimized = not GUI.minimized
        applyMinimized()
    end)

    GUI.screen = screen
    GUI.frame = frame
    GUI.titleBar = titleBar
    GUI.status = status
    GUI.summary = summary
    GUI.list = list
    GUI.layout = layout
    GUI.minimize = minimize

    applyMinimized()
end

local function guiSetStatus(text,owner)
    local lock=ENV.PDIDDLER_STATUS_OWNER

    -- When Part 4 owns the active trade, scanner background refreshes and
    -- Part 3 must not overwrite the balancer/timer status.
    if lock and tostring(lock)~="" then
        if tostring(owner or "")~=tostring(lock) then
            return false
        end
    end

    if not GUI.status then
        return false
    end

    local nextText=tostring(text or "")

    -- TextWrapped + AutomaticSize causes layout work on iPad. Do not assign
    -- the same status string repeatedly.
    if GUI.statusRenderCache==nextText
        and GUI.status.Text==nextText
    then
        return true
    end

    GUI.statusRenderCache=nextText
    GUI.status.Text=nextText
    return true
end

local function guiSetSummary(white, black, unknown)
    if not GUI.summary then return end

    local nextText=string.format(
        "Whitelist %d  |  Blacklist %d  |  Unknown %d",
        tonumber(white) or 0,
        tonumber(black) or 0,
        tonumber(unknown) or 0
    )

    if GUI.summaryRenderCache==nextText
        and GUI.summary.Text==nextText
    then
        return
    end

    GUI.summaryRenderCache=nextText
    GUI.summary.Text=nextText
end

local function rowColor(state)
    return Color3.fromRGB(12, 12, 16)
end

local function rowAccentColor(state)
    if state == "whitelist" then
        return Color3.fromRGB(55, 220, 125)
    elseif state == "blacklist" then
        return Color3.fromRGB(235, 70, 80)
    elseif state == "unknown" then
        return Color3.fromRGB(245, 195, 65)
    elseif state == "sending" then
        return Color3.fromRGB(85, 155, 255)
    elseif state == "requesting" then
        return Color3.fromRGB(65, 135, 255)
    elseif state == "notready" or state == "unavailable" then
        return Color3.fromRGB(255, 175, 55)
    elseif state == "ignored" then
        return Color3.fromRGB(245, 140, 45)
    elseif state == "declined" then
        return Color3.fromRGB(245, 75, 85)
    elseif state == "accepted" then
        return Color3.fromRGB(50, 235, 120)
    elseif state == "left" then
        return Color3.fromRGB(150, 150, 165)
    elseif state == "sendfailed" then
        return Color3.fromRGB(255, 65, 80)
    elseif state == "processed" then
        return Color3.fromRGB(165, 110, 235)
    end

    return Color3.fromRGB(175, 105, 245)
end

local function rowTitle(state)
    if state == "whitelist" then
        return "WHITELIST"
    elseif state == "blacklist" then
        return "BLACKLIST"
    elseif state == "unknown" then
        return "UNKNOWN"
    elseif state == "sending" then
        return "SENDING"
    elseif state == "requesting" then
        return "REQUESTING"
    elseif state == "notready" then
        return "NOT READY"
    elseif state == "unavailable" then
        return "UNAVAILABLE"
    elseif state == "ignored" then
        return "IGNORED"
    elseif state == "declined" then
        return "DECLINED"
    elseif state == "accepted" then
        return "ACCEPTED"
    elseif state == "left" then
        return "LEFT"
    elseif state == "sendfailed" then
        return "SEND FAILED"
    elseif state == "processed" then
        return "PROCESSED"
    end

    return "SCANNING"
end

local function guiSetPlayer(player, state, detail, order)
    if not GUI.list or not player then
        return
    end

    local key = tostring(player.UserId)
    local label = GUI.rows[key]

    if not label then
        label = Instance.new("TextLabel")
        label.Name = "P_" .. key
        label.Parent = GUI.list
        label.Size = UDim2.new(1, -6, 0, 58)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.BackgroundColor3 = rowColor(state)
        label.BackgroundTransparency = 0.08
        label.BorderSizePixel = 0
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(245, 247, 250)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.RichText = false
        label.LayoutOrder = order or 0

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = label

        local padding = Instance.new("UIPadding")
        padding.Parent = label
        padding.PaddingTop = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)

        local statusStroke = Instance.new("UIStroke")
        statusStroke.Name = "StatusStroke"
        statusStroke.Thickness = 2
        statusStroke.Transparency = 0.08
        statusStroke.Color = rowAccentColor(state)
        statusStroke.Parent = label

        GUI.rows[key] = label
    end

    local username = tostring(player.Name or "?")
    local display = tostring(player.DisplayName or username)
    local nameText = username

    if display ~= username then
        nameText = display .. "  @" .. username
    end

    local nextText=string.format(
        "[%s]  %s\n%s",
        rowTitle(state),
        nameText,
        tostring(detail or "")
    )
    local nextOrder=order or label.LayoutOrder
    local nextBg=rowColor(state)
    local nextAccent=rowAccentColor(state)

    local cacheKey=table.concat({
        tostring(state or ""),
        tostring(nextOrder),
        nextText,
    },"\31")

    -- The RequestUI maintenance loop and periodic scanner can ask for the
    -- exact same row repeatedly. Avoid Text/AutomaticSize/layout invalidation
    -- unless something actually changed.
    if GUI.rowRenderCache[key]~=cacheKey then
        label.BackgroundColor3 = nextBg
        label.LayoutOrder = nextOrder

        local statusStroke = label:FindFirstChild("StatusStroke")
        if statusStroke and statusStroke:IsA("UIStroke") then
            statusStroke.Color = nextAccent
        end

        label.Text = nextText
        GUI.rowRenderCache[key]=cacheKey
    end
end

createGui()

-- ============================================================================
-- STRICT VALUE / IDENTITY LAYER
-- ============================================================================

local function req(mod)
 if not mod then return end
 local ok,x=pcall(require,mod)
 if ok then return x end
 if setthreadidentity then
  local old
  if getthreadidentity then pcall(function() old=getthreadidentity() end) end
  pcall(setthreadidentity,2)
  ok,x=pcall(require,mod)
  pcall(setthreadidentity,old or 8)
  if ok then return x end
 end
end

local DB=RS:FindFirstChild("Database")
local Sync=req(DB and DB:FindFirstChild("Sync")) or {}
local Meta={}

local function assetKey(x)
 local raw=tostring(x or "")
 if raw=="" then return "" end
 return raw:match("(%d%d%d%d%d+)") or norm(raw)
end

local function indexItems(src)
 if type(src)~="table" then return end
 for id,d in pairs(src) do
  if type(d)=="table" then
   Meta["Weapons|"..tostring(id)]={
    id=tostring(id),
    cat="Weapons",
    data=d,
    name=d.ItemName or d.Name or tostring(id),
    chroma=d.Chroma==true,
    type=d.ItemType or "",
    rarity=d.Rarity or ""
   }
  end
 end
end
indexItems(Sync.Weapons)
if Sync.Item~=Sync.Weapons then
 indexItems(Sync.Item)
end

local function identityName(meta)
 if not meta then return "" end
 local name=tostring(meta.name or meta.id or "")
 if meta.chroma then
  return name:lower():match("^chroma%s") and name or ("Chroma "..name)
 end
 return name
end

local function metaIdentity(meta)
 if not meta then return "" end
 local d=meta.data or {}
 local page=meta.chroma and "chroma" or norm(meta.rarity)
 return table.concat({
  tostring(meta.id or ""),
  tostring(page or ""),
  norm(meta.type),
  meta.chroma and "chroma" or "normal",
  norm(d.Year or d.EventYear or ""),
  norm(d.Event or d.Season or ""),
  tostring(d.ItemID or ""),
  assetKey(d.Image or d.Icon or d.Texture or "")
 },"|")
end

local VALUE_SNAPSHOT_UPDATED="2026-10-31 12:31:12 EST"
local Checker={rows={},byId={},ready=false}
Checker.raw=[==[
ancient|1|250000000|NiksScythe.png
ancient|771|15250|Gingerscope.png
ancient|743|7700|TravellersAxe.png
ancient|860|1950|Celestial.png
ancient|829|1375|vampsaxe.png
ancient|1026|325|Emberbow.png
ancient|1027|300|Emberscythe.png
ancient|526|250|harvester.png
ancient|661|165|Icepiercer.png
ancient|480|70|Icebreaker.png
ancient|3|45|BatwingUpdated.png
ancient|2|40|ewscythe.png
ancient|529|40|SwirlAxe.png
ancient|471|32|HallowscytheUp.png
ancient|404|20|LogchopperUp.png
ancient|4|15|IcewingknifeUp.png
chroma|739|140000|ChromaTravGun.png
chroma|772|47000|Chroma_Evergun.png
chroma|773|33000|Chroma_Evergreen.png
chroma|855|29000|CBauble.png
chroma|857|26000|ChromaConstellation.png
chroma|831|25000|chromavampsgun.png
chroma|927|23000|ChromaAlienbeam.png
chroma|1036|10000|Chroma_Emberscythe.png
chroma|928|12500|ChromaRaygun.png
chroma|899|8250|ChromaSunsetGun.png
chroma|962|7650|Chroma_Snowcannon.png
chroma|1030|4450|Chroma_Emberbow.png
chroma|900|5500|ChromaSunsetKnife.png
chroma|957|5500|ChromaBlizzard.png
chroma|958|4250|Chroma_Snowstorm.png
chroma|990|3400|CHeartwand.png
chroma|960|2400|Chroma_Snow_Dagger.png
chroma|810|2350|Chroma_Watergun.png
chroma|1006|1875|C_Icecream.png
chroma|1033|1800|coming.png
chroma|1034|1800|coming.png
chroma|985|1800|Chroma_Ornament.png
chroma|992|1800|Ctreat.png
chroma|991|1750|Csweet.png
chroma|1007|1325|CSands.png
chroma|1008|1275|CBeachy.png
chroma|1029|1100|Chroma_Embersickle.png
chroma|447|60|Chroma_Darkbringer.png
chroma|446|55|Chroma_Lightbringer.png
chroma|6|48|chromaluger.png
chroma|8|40|chromalaser.png
chroma|525|40|chromacandle.png
chroma|13|35|chromads.png
chroma|527|35|chromaswirlygun.png
chroma|616|35|ChromaElderwoodBlade.png
chroma|7|33|chromashark.png
chroma|9|33|chromaslasher.png
chroma|10|33|chromafang.png
chroma|439|33|chromagem.png
chroma|11|30|chromaheat.png
chroma|659|30|ChromaCookiecane.png
chroma|14|25|chromatides.png
chroma|15|25|chromaseer.png
chroma|17|25|Chroma_Gingerblade.png
chroma|12|22|chromasaw.png
chroma|16|20|Chroma_Boneblade.png
godly|740|5150|TravGun.png
godly|770|3425|Evergun.png
godly|769|2700|Evergreen.png
godly|856|2475|2024Constellation.png
godly|830|1875|vampsgun.png
godly|762|1850|Turkey.png
godly|926|1850|Alienbeam.png
godly|925|1825|Raygun.png
godly|741|1550|Darkshot.png
godly|742|1525|Darksword.png
godly|696|1160|BlossomGun.png
godly|697|1150|Sakura.png
godly|901|775|SunsetGun.png
godly|961|680|Snowcannon.png
godly|854|675|Bauble.png
godly|902|650|SunsetKnife.png
godly|833|625|soul.png
godly|832|615|spirit.png
godly|924|440|Xenoshot.png
godly|923|435|Xenoknife.png
godly|715|410|rainbowgun.png
godly|891|405|Flora_Gun.png
godly|714|400|Rainbowblade.png
godly|890|395|Bloom_Knife.png
godly|989|350|Heartwand.png
godly|955|250|Blizzard.png
godly|956|250|Snowstorm.png
godly|728|240|Ocean_gun.png
godly|795|235|Flowerwood_Gun.png
godly|727|235|Waves_knife.png
godly|794|230|Flowerwood_Knife.png
godly|959|170|Snow_Dagger.png
godly|988|155|Treat.png
godly|1005|155|Icecream_knife.png
godly|811|150|WaterGun.png
godly|987|150|Sweet.png
godly|1031|140|Mortal.png
godly|1032|140|Immortal.png
godly|859|140|2024Borealis.png
godly|858|135|2024Australis.png
godly|618|120|Bat_Zombie.png
godly|23|90|Updated_Candy.png
godly|1028|80|Embersickle.png
godly|813|80|Pearlsh.png
godly|1003|80|BeachyGodly2026.png
godly|1004|80|SandsGodly2026.png
godly|812|75|Pearl.png
godly|512|65|HeartBladeUp.png
godly|984|60|ornagodly.png
godly|20|38|Red_Luger.png
godly|620|37|Phantom_Shop.png
godly|621|37|Spectre.png
godly|524|35|candleflame.png
godly|18|35|ewrev.png
godly|448|35|DarkbringerUpdated.png
godly|481|35|IceblasterUP.png
godly|22|33|Sugar_v2.png
godly|617|33|Makeshift.png
godly|445|33|LightbringerUpdated.png
godly|619|32|ElderwoodBlade.png
godly|21|25|Green_Luger.png
godly|30|23|AmeriUP.png
godly|46|23|LaserUpdated.png
godly|472|22|hallowgunup.png
godly|532|20|IceBeamUP.png
godly|48|20|SharkUP.png
godly|572|20|Plasmabeam.png
godly|63|20|NightBladeUp.png
godly|528|18|SwirlGunUP.png
godly|531|18|IceFlakeUP.png
godly|32|18|BattleAxe2UP.png
godly|34|18|PixelUp.png
godly|36|18|Ginger_LugerUP.png
godly|31|17|OldGloryUp.png
godly|35|17|BlasterUP.png
godly|39|17|LugerUpdated.png
godly|573|17|Plasmablade.png
godly|37|15|VirtualUP.png
godly|43|15|SlasherUP.png
godly|405|15|MintyUp.png
godly|408|15|LugerCaneUP.png
godly|473|15|VampiresedgeUP.png
godly|482|15|JinglegunUP.png
godly|660|14|Cookiecane.png
godly|662|14|Gingermint.png
godly|522|13|NebulaUp.png
godly|530|13|SwirlyBladeUP.png
godly|49|13|DeathshardUp.png
godly|57|13|Battleaxe1UP.png
godly|60|13|GingerbladeUP.png
godly|379|13|eternalcane.png
godly|440|13|GemstoneUP.png
godly|24|12|ChillUpdated4.png
godly|28|12|ClockworkUp.png
godly|33|12|SpiderUP.png
godly|40|12|HeatUP.png
godly|42|12|TidesUP.png
godly|47|12|FangUp.png
godly|26|10|EternalUpdated.png
godly|41|10|XmasUP.png
godly|58|10|FrostsaberUP.png
godly|441|10|eternal3.png
godly|444|10|Mm2bioblade.png
godly|467|10|Eternal4UP.png
godly|25|9|Handsaw_Png.png
godly|29|9|HallowEdgeUp.png
godly|59|9|IceShardUP.png
godly|19|8|Eternal_2UP.png
godly|27|8|BonebladeUP.png
godly|44|8|PumpkingUP.png
godly|45|8|SawUP.png
godly|62|8|ghostblade.png
godly|38|7|FlamesUp.png
godly|50|7|WinterEdgeUP.png
godly|51|7|IceDragonUp.png
godly|64|7|HallowsbladeUP.png
godly|407|7|FrostbiteUP.png
godly|521|5|EggbladeUP.png
godly|61|5|SnowflakeUP.png
godly|468|5|PrismaticUp.png
godly|479|4|peppermint.png
godly|483|4|CookiebladeUP.png
godly|52|3|redseer.png
godly|53|3|blueseer.png
godly|54|3|purpleseer.png
godly|889|3|Seer.png
godly|55|2|orangeseer.png
godly|56|2|yellowseer.png
]==]

local function checkerPage(meta)
 if not meta then return nil end
 if meta.chroma then return "chroma" end
 local r=norm(meta.rarity)
 if r=="ancient" or r=="godly" then return r end
 return nil
end

local function allowedPage(page) return page=="ancient" or page=="godly" or page=="chroma" end

local function qualifyingMeta(meta)
 if not meta then return false end
 if not allowedPage(checkerPage(meta)) then return false end

 local t=norm(meta.type)
 if t~="knife" and t~="gun" then return false end

 local d=meta.data or {}

 -- Evolution stages are catalog/progression entries, not normal tradable
 -- weapons. Examples: Reaver_Ancient, IceHammer_Ancient,
 -- Gingerscythe_Ancient, Synthwave_Ancient.
 if d.EvoBaseID~=nil or d.EvoIndex~=nil then
  return false
 end

 -- MM2 contains placeholder/test Godly entries named "???" such as
 -- Emptybringer. They must never create a whitelist target.
 if norm(meta.name)==""
  or tostring(meta.name)=="???"
 then
  return false
 end

 -- Honor explicit non-trade metadata when MM2 supplies it. Missing flags are
 -- not treated as non-tradable, so ordinary catalog items remain eligible.
 if d.Tradable==false
  or d.CanTrade==false
  or d.Untradable==true
  or d.NonTradable==true
 then
  return false
 end

 return true
end

local function checkerBuild()
 if Checker.ready then return true end
 local count=0
 for line in tostring(Checker.raw):gmatch("[^\r\n]+") do
  local page,id,val,img=line:match("^([^|]+)|([^|]+)|([^|]+)|(.+)$")
  val=tonumber(val)
  if page and id and val and img then
   Checker.rows[page]=Checker.rows[page] or {}
   Checker.byId[page]=Checker.byId[page] or {}
   local rec={page=page,id=tostring(id),v=val,img=tostring(img)}
   Checker.rows[page][#Checker.rows[page]+1]=rec
   Checker.byId[page][rec.id]=rec
   count=count+1
  end
 end
 Checker.ready=count>0
 log("VALUE SNAPSHOT READY",count,"rows | source update",VALUE_SNAPSHOT_UPDATED)
 return Checker.ready
end

local function checkerCanon(x,page,itemType,level)
 local raw=tostring(x or ""):gsub("%.[^%.]+$","")
 local q=norm(raw)
 q=q:gsub("travellers","traveler"):gsub("travelers","traveler"):gsub("strarry","starry"):gsub("knfie","knife"):gsub("spearmingun","spearmintgun"):gsub("brozen","bronze"):gsub("pumpin","pumpkin")
 if q:sub(1,8)=="travsaxe" then q="traveleraxe"..q:sub(9)
 elseif q:sub(1,7)=="travgun" then q="travelergun"..q:sub(8)
 elseif q:sub(1,8)=="vampsaxe" then q="vampiresaxe"..q:sub(9)
 elseif q:sub(1,8)=="vampsgun" then q="vampiresgun"..q:sub(9)
 elseif q:sub(1,7)=="vampaxe" then q="vampiresaxe"..q:sub(8)
 elseif q:sub(1,6)=="gscope" then q="gingerscope"..q:sub(7)
 elseif q:sub(1,8)=="ewscythe" then q="elderwoodscythe"..q:sub(9) end
 if (tonumber(level) or 0)>=1 then
  q=q:gsub("20%d%d",""):gsub("updated",""):gsub("update",""):gsub("godly","")
  if #q>4 and q:sub(-2)=="up" then q=q:sub(1,-3) end
  if #q>4 and q:sub(-2)=="v2" then q=q:sub(1,-3) end
  if page=="chroma" then
   if q:sub(1,6)=="chroma" then q=q:sub(7) elseif q:sub(1,1)=="c" and #q>4 then q=q:sub(2) end
  end
 end
 if (tonumber(level) or 0)>=2 then
  local t=norm(itemType)
  if t~="" and #q>#t+2 and q:sub(-#t)==t then q=q:sub(1,#q-#t) end
  if t=="knife" and #q>4 and q:sub(-1)=="k" then q=q:sub(1,-2)
  elseif t=="gun" and #q>4 and q:sub(-1)=="g" then q=q:sub(1,-2) end
 end
 return q
end

local CheckerInternalKey={
 godly={
  BattleAxe="57",
  Bioblade="444",
  Chill="24",
  Handsaw="25",
  Phantom2022="620",
  Rainbow_K="714",
 },
 chroma={
  CandleflameChroma="525",
 },
 ancient={}
}

local function checkerInternalAlias(page,meta)
 if not meta then return nil end
 local bucket=CheckerInternalKey[page]
 return bucket and bucket[tostring(meta.id)] or nil
end

local function checkerAlias(page,name,typ)
 local q,t=norm(name),norm(typ)
 if page=="chroma" and (q=="chromadeathshard" or q=="deathshard") then return "13" end
 if page=="chroma" and (q=="chromatravelersgun" or q=="chromatravellersgun" or q=="travelersgun" or q=="travellersgun") then return "739" end
 if page=="chroma" and (q=="chromavampiresgun" or q=="vampiresgun") then return "831" end
 if page=="godly" and q=="pearlshine" then return "813" end
 if page=="godly" and q=="bat" then return "618" end
 if page=="godly" and q=="ornament" then return "984" end
 if page=="godly" and q=="amerilaser" then return "30" end
 if page=="godly" and (q=="swirlygun" or q=="swirlgun") then return "528" end
 if page=="godly" and (q=="hallowsedge" or q=="hallowedge") then return "29" end
 if page=="godly" and (q=="elderwoodrevolver" or q=="ewrevolver") then return "18" end
 if page=="ancient" and (q=="swirlyaxe" or q=="swirlaxe") then return "529" end
 if page=="godly" and (q=="wintersedge" or q=="winteredge") then return "50" end
 if page=="godly" and q=="sunrise" and (t=="" or t=="gun") then return "901" end
 if page=="godly" and q=="sunset" and (t=="" or t=="knife") then return "902" end
 if page=="chroma" and (q=="chromasunrise" or q=="sunrise") and (t=="" or t=="gun") then return "899" end
 if page=="chroma" and (q=="chromasunset" or q=="sunset") and (t=="" or t=="knife") then return "900" end
 if page=="chroma" and (q=="chromagemstone" or q=="gemstone") then return "439" end
 if page=="chroma" and (q=="chromamortal" or q=="mortal") then return "1033" end
 if page=="chroma" and (q=="chromaimmortal" or q=="immortal") then return "1034" end
end

local checkerCache={}
local function checkerResolve(name,opts)
 if not checkerBuild() then return nil,"snapshot unavailable" end
 opts=type(opts)=="table" and opts or {}
 local shown=tostring(name or "")
 local pageHint=tostring(opts.page or "")
 local typ=tostring(opts.type or "")
 local iid=tostring(opts.id or "")
 local chroma=opts.chroma==true
 local meta=opts.meta
 if shown=="" and meta then shown=identityName(meta) end
 if pageHint=="" and meta then pageHint=checkerPage(meta) or "" end
 if typ=="" and meta then typ=tostring(meta.type or "") end
 if iid=="" and meta then iid=tostring(meta.id or "") end
 if meta and meta.chroma then chroma=true end
 if pageHint~="" and not allowedPage(pageHint) then return nil,"tier excluded" end
 local ck=table.concat({norm(shown),pageHint,norm(typ),norm(iid),chroma and "1" or "0"},"|")
 if checkerCache[ck] then return checkerCache[ck],"cache" end
 if pageHint~="" then
  local internalId=checkerInternalAlias(pageHint,meta)
  local internalRec=internalId
   and Checker.byId[pageHint]
   and Checker.byId[pageHint][internalId]

  if internalRec then
   checkerCache[ck]=internalRec
   return internalRec,"internal-key"
  end

  local aid=checkerAlias(pageHint,shown,typ)
  local rec=aid and Checker.byId[pageHint] and Checker.byId[pageHint][aid]
  if rec then
   checkerCache[ck]=rec
   return rec,"alias"
  end
 end
 local pages={}
 if pageHint~="" then
  pages[1]=pageHint
 else
  return nil,"missing-tier"
 end
 local best,bestScore,tied,tiedSame=nil,-100000,false,true
 local md=meta and meta.data or {}
 local itemYear=tostring(md.Year or md.EventYear or ""):match("(20%d%d)")
 if not itemYear then itemYear=iid:match("(20%d%d)") end
 for _,page in ipairs(pages) do
  local n0,n1,n2=checkerCanon(shown,page,typ,0),checkerCanon(shown,page,typ,1),checkerCanon(shown,page,typ,2)
  local mn=meta and identityName(meta) or ""
  local m0,m1,m2=checkerCanon(mn,page,typ,0),checkerCanon(mn,page,typ,1),checkerCanon(mn,page,typ,2)
  local i0,i1,i2=checkerCanon(iid,page,typ,0),checkerCanon(iid,page,typ,1),checkerCanon(iid,page,typ,2)
  for _,rec in ipairs(Checker.rows[page] or {}) do
   local c0,c1,c2=checkerCanon(rec.img,page,typ,0),checkerCanon(rec.img,page,typ,1),checkerCanon(rec.img,page,typ,2)
   local score=-100000
   if n0~="" and c0==n0 then score=340 elseif n1~="" and c1==n1 then score=285 elseif n2~="" and c2==n2 then score=240 end
   if m0~="" and c0==m0 then score=math.max(score,360) elseif m1~="" and c1==m1 then score=math.max(score,300) elseif m2~="" and c2==m2 then score=math.max(score,255) end
   if i0~="" and c0==i0 then score=math.max(score,430) elseif i1~="" and c1==i1 then score=math.max(score,350) elseif i2~="" and c2==i2 then score=math.max(score,290) end
   if page==pageHint then score=score+45 end
   local rawImg,t=norm(rec.img),norm(typ)
   if t=="gun" then if rawImg:find("knife",1,true) then score=score-180 elseif rawImg:find("gun",1,true) then score=score+20 end
   elseif t=="knife" then if rawImg:find("gun",1,true) then score=score-180 elseif rawImg:find("knife",1,true) then score=score+20 end end
   local checkerYear=tostring(rec.img):match("(20%d%d)")
   if itemYear and checkerYear then if itemYear==checkerYear then score=score+65 else score=score-120 end end
   if score>bestScore then best,bestScore,tied,tiedSame=rec,score,false,true
   elseif score==bestScore and best and rec.id~=best.id then tied=true; if math.abs((rec.v or 0)-(best.v or 0))>.000001 then tiedSame=false end end
  end
 end
 if best and bestScore>=200 and not tied then
  checkerCache[ck]=best
  return best,"match:"..bestScore
 end
 if tied then return nil,"ambiguous" end
 return nil,"unresolved"
end

local function checkerMarket(meta)
 local page=checkerPage(meta)
 if not allowedPage(page) then return nil end
 local rec,why=checkerResolve(identityName(meta),{page=page,type=meta.type,id=meta.id,chroma=meta.chroma,meta=meta})
 if not rec then return nil,why end
 return {v=rec.v,id=rec.id,page=rec.page,img=rec.img,source="verified-snapshot-2026-11-01"},nil
end

checkerBuild()

local function auditEligibleIdentityCollisions()
 local groups={}
 for _,m in pairs(Meta) do
  local page=checkerPage(m)
  if qualifyingMeta(m) then
   local k=table.concat({page,norm(identityName(m)),norm(m.type)},"|")
   groups[k]=groups[k] or {}
   groups[k][#groups[k]+1]=m
  end
 end

 local collisions=0
 for k,list in pairs(groups) do
  if #list>1 then
   collisions+=1
   local ids={}
   for _,m in ipairs(list) do
    ids[#ids+1]=metaIdentity(m)
   end
   warn("[PDIDDLER3] ELIGIBLE NAME COLLISION",k,"count",#list,table.concat(ids," || "))
  end
 end
 print("[PDIDDLER3] ELIGIBLE IDENTITY AUDIT COMPLETE","collisions",collisions)
end

auditEligibleIdentityCollisions()

local function auditCatalogExclusions()
 local rarityWeapons=0
 local tradeEligible=0
 local excluded=0

 for _,m in pairs(Meta) do
  local page=checkerPage(m)
  local t=norm(m.type)

  if allowedPage(page) and (t=="knife" or t=="gun") then
   rarityWeapons+=1

   if qualifyingMeta(m) then
    tradeEligible+=1
   else
    excluded+=1
   end
  end
 end

 print(
  "[PDIDDLER3] CATALOG FILTER",
  "rarityWeapons",rarityWeapons,
  "tradeEligible",tradeEligible,
  "excludedNonTrade",excluded
 )
end

auditCatalogExclusions()

local function auditValueCoverage()
 local total=0
 local resolved=0
 local unresolved={}

 for _,m in pairs(Meta) do
  if qualifyingMeta(m) then
   total+=1
   local rec,why=checkerMarket(m)
   if rec and tonumber(rec.v) then
    resolved+=1
   else
    unresolved[#unresolved+1]={
     name=identityName(m),
     id=tostring(m.id),
     page=tostring(checkerPage(m)),
     typ=tostring(m.type),
     identity=metaIdentity(m),
     why=tostring(why or "unresolved")
    }
   end
  end
 end

 table.sort(unresolved,function(a,b)
  if a.page~=b.page then return a.page<b.page end
  return a.name<b.name
 end)

 print(
  "[PDIDDLER3] TRADE VALUE COVERAGE",
  "resolved",resolved,
  "total",total,
  "unresolved",#unresolved
 )

 local show=math.min(#unresolved,12)
 for i=1,show do
  local x=unresolved[i]
  warn(
   "[PDIDDLER3] UNPRICED CATALOG ITEM",
   x.page,
   x.name,
   "id="..x.id,
   "type="..x.typ,
   x.why,
   x.identity
  )
 end
 if #unresolved>show then
  warn("[PDIDDLER3] UNPRICED CATALOG ITEMS OMITTED",#unresolved-show)
 end
end

auditValueCoverage()

local function inventoryFromProfile(prof)
 if type(prof)~="table" then return nil end

 local weapons=prof.Weapons
 local owned=type(weapons)=="table" and weapons.Owned
 if type(owned)~="table" then return nil end

 local out={
  items={},
  total=0,
  rawOwned=0,
  unmapped=0,
  unpriced=0,
  badQty=0,
  seen={}
 }

 for rawId,count in pairs(owned) do
  local id=tostring(rawId)
  local qty=nil

  if type(count)=="number" then
   if count>=0 and count==math.floor(count) then
    qty=count
   end
  elseif type(count)=="string" then
   local n=tonumber(count)
   if n and n>=0 and n==math.floor(n) then
    qty=n
   end
  end

  if qty==nil then
   out.badQty+=1
   out.seen[#out.seen+1]=id.."x?"
  elseif qty>0 then
   out.rawOwned+=qty
   out.seen[#out.seen+1]=id.."x"..tostring(qty)

   local meta=Meta["Weapons|"..id]

   if not meta then
    -- We cannot safely classify the complete inventory if MM2 itself has an
    -- owned weapon key that our live Sync catalog did not expose.
    out.unmapped+=qty
   else
    local page=checkerPage(meta)

    if qualifyingMeta(meta) then
     local market,why=checkerMarket(meta)

     out.items[#out.items+1]={
      id=id,
      cat="Weapons",
      name=identityName(meta),
      qty=qty,
      value=market and market.v or nil,
      type=tostring(meta.type or ""),
      page=page,
      checkerId=market and market.id or "UNPRICED",
      identity=metaIdentity(meta),
      year=tostring((meta.data or {}).Year or ""),
      event=tostring((meta.data or {}).Event or ""),
      valueSource=market and market.source or tostring(why or "UNPRICED")
     }

     if market and tonumber(market.v) then
      out.total+=tonumber(market.v)*qty
     else
      out.unpriced+=qty
     end
    end
   end
  end
 end

 table.sort(out.seen)
 out.fingerprint=table.concat(out.seen,"|")

 table.sort(out.items,function(a,b)
  local av=tonumber(a.value)
  local bv=tonumber(b.value)

  if av~=nil and bv~=nil and av~=bv then
   return av>bv
  elseif av~=nil and bv==nil then
   return true
  elseif av==nil and bv~=nil then
   return false
  end

  if tostring(a.page)~=tostring(b.page) then
   return tostring(a.page)<tostring(b.page)
  end

  return tostring(a.id)<tostring(b.id)
 end)

 return out
end

local function unwrapProfile(x,depth)
 depth=depth or 0
 if type(x)~="table" or depth>4 then return nil end
 if type(x.Weapons)=="table" and type(x.Weapons.Owned)=="table" then return x end
 for _,n in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
  local p=unwrapProfile(x[n],depth+1); if p then return p end
 end
end

local function getFullInventoryRemote()
 local remotes=RS:FindFirstChild("Remotes")
 local extras=remotes and remotes:FindFirstChild("Extras")
 local rf=extras and extras:FindFirstChild("GetFullInventory")
 if rf and rf:IsA("RemoteFunction") then return rf end
 return nil
end

local InventoryRemoteGate={
 busy=false,
 inflight=false,
 lastCallAt=0,
 timeoutCount=0,
}

local function targetInventory(p)
 if not p or p==LP or not p.Parent then return nil end

 local rf=getFullInventoryRemote()
 if not rf then
  warn("[PDIDDLER3] GetFullInventory remote missing")
  return nil
 end

 while InventoryRemoteGate.busy do
  if not p.Parent then return nil end
  task.wait(0.03)
 end

 InventoryRemoteGate.busy=true

 -- If an earlier timed-out InvokeServer is still alive, do not create another.
 if InventoryRemoteGate.inflight then
  InventoryRemoteGate.busy=false
  return nil
 end

 local elapsed=os.clock()-InventoryRemoteGate.lastCallAt
 if elapsed<C.RemoteMinInterval then
  task.wait(C.RemoteMinInterval-elapsed)
 end

 local done=false
 local ok=false
 local raw=nil

 InventoryRemoteGate.inflight=true

 task.spawn(function()
  ok,raw=pcall(function()
   return rf:InvokeServer(p.Name)
  end)
  done=true
  InventoryRemoteGate.inflight=false
 end)

 local deadline=os.clock()+C.RemoteTimeout
 while not done and os.clock()<deadline do
  if not p.Parent then break end
  task.wait(0.03)
 end

 InventoryRemoteGate.lastCallAt=os.clock()
 InventoryRemoteGate.busy=false

 if not done then
  InventoryRemoteGate.timeoutCount += 1
  warn(
   "[PDIDDLER3] INVENTORY RPC TIMEOUT",
   p.Name,
   "count",
   InventoryRemoteGate.timeoutCount
  )
  return nil
 end

 if not ok or type(raw)~="table" then
  return nil
 end

 local prof=unwrapProfile(raw)
 if not prof
  or type(prof.Weapons)~="table"
  or type(prof.Weapons.Owned)~="table"
 then
  return nil
 end

 return inventoryFromProfile(prof)
end

-- ============================================================================
-- T4.3 SERVER SCAN + ROBUST LIVE JOIN/LEAVE TRACKING
-- ============================================================================

local function fmtValue(v)
    v = tonumber(v) or 0
    if math.floor(v) == v then
        return tostring(math.floor(v))
    end
    return string.format("%.2f", v)
end

local function itemLine(it)
    return string.format(
        "%s | %s | x%d | each=%s | subtotal=%s | checker=%s",
        tostring(it.page or "?"):upper(),
        tostring(it.name or it.id or "?"),
        tonumber(it.qty) or 1,
        fmtValue(it.value),
        fmtValue((tonumber(it.value) or 0) * (tonumber(it.qty) or 1)),
        tostring(it.checkerId or "?")
    )
end

local function eligibleCopies(inv)
    local n = 0
    for _, it in ipairs((inv and inv.items) or {}) do
        n += math.max(1, tonumber(it.qty) or 1)
    end
    return n
end

local function eligibleSummary(inv)
    local parts = {}

    for _, it in ipairs((inv and inv.items) or {}) do
        local qty = math.max(1, tonumber(it.qty) or 1)
        local subtotal = (tonumber(it.value) or 0) * qty

        parts[#parts + 1] = string.format(
            "%s%s (%s)",
            tostring(it.name or it.id or "?"),
            qty > 1 and (" x" .. tostring(qty)) or "",
            it.value and fmtValue(subtotal) or "UNPRICED"
        )
    end

    if #parts == 0 then
        return "No eligible Ancient/Godly/Chroma Godly"
    end

    return table.concat(parts, ", ")
end

local Live = {
    byUserId = {},
    order = {},
    nextOrder = 0,
    scanning = {},
    retrying = {},
    retryCount = {},
    white = 0,
    black = 0,
    unknown = 0,
}

local function trackedCount()
    local n = 0
    for _ in pairs(Live.byUserId) do
        n += 1
    end
    return n
end

local function recount()
    local white, black, unknown = 0, 0, 0

    for _, rec in pairs(Live.byUserId) do
        if rec.state == "whitelist" then
            white += 1
        elseif rec.state == "blacklist" then
            black += 1
        elseif rec.state == "unknown" then
            unknown += 1
        end
    end

    Live.white = white
    Live.black = black
    Live.unknown = unknown
    guiSetSummary(white, black, unknown)
end

local function getOrder(p)
    local uid = tostring(p.UserId)

    if not Live.order[uid] then
        Live.nextOrder += 1
        Live.order[uid] = Live.nextOrder
    end

    return Live.order[uid]
end

local function scanOne(p, reason)
    local isJoinLike =
        reason == "join"
        or reason == "retry"

    local retries =
        isJoinLike
        and C.JoinScanRetries
        or C.TargetScanRetries

    local retryDelay =
        isJoinLike
        and C.JoinScanRetryDelay
        or C.TargetScanRetryDelay

    local lastFingerprint=nil
    local stableCount=0
    local lastInv=nil

    for attempt = 1, retries do
        if not p or not p.Parent then
            return "left", nil
        end

        local inv = targetInventory(p)

        if inv
            and (inv.unmapped or 0)==0
            and (inv.badQty or 0)==0
        then
            local fp=tostring(inv.fingerprint or "")

            if lastFingerprint~=nil and fp==lastFingerprint then
                stableCount+=1
            else
                lastFingerprint=fp
                stableCount=1
            end

            lastInv=inv

            -- A completely empty Weapons.Owned response is more likely to be
            -- a loading/transient profile. Require an extra confirming read.
            local requiredStable=(tonumber(inv.rawOwned) or 0)==0 and 3 or 2

            if stableCount>=requiredStable then
                if #inv.items>0 then
                    return "whitelist", inv
                end
                return "blacklist", inv
            end
        else
            -- An unreadable/incomplete response breaks the stability proof.
            lastFingerprint=nil
            stableCount=0
            lastInv=inv
        end

        if attempt < retries then
            guiSetStatus(
                string.format(
                    "%s inventory verification — stable %d/%d",
                    p.Name,
                    stableCount,
                    ((lastInv and (tonumber(lastInv.rawOwned) or 0)==0) and 3 or 2)
                )
            )
            task.wait(retryDelay)
        end
    end

    if not p or not p.Parent then
        return "left", nil
    end

    return "unknown", lastInv
end

local function removePlayerState(p)
    if not p then
        return
    end

    local uid = tostring(p.UserId)

    Live.scanning[uid] = nil
    Live.retrying[uid] = nil
    Live.retryCount[uid] = nil
    Live.byUserId[uid] = nil

    local row = GUI.rows[uid]
    if row then
        pcall(function()
            row:Destroy()
        end)
        GUI.rows[uid] = nil
    end

    recount()

    guiSetStatus(
        string.format(
            "%s left — removed from live scanner",
            p.Name
        )
    )

    print(
        "[MM2 Scanner T4.3] PLAYER LEFT",
        p.Name,
        "| removed from live state"
    )
end

local scanPlayerLive
local scheduleUnknownRetry

local function applyPlayerResult(p, state, inv)
    if not p or not p.Parent then
        return
    end

    local uid = tostring(p.UserId)
    local order = getOrder(p)

    Live.byUserId[uid] = {
        player = p,
        state = state,
        inv = inv,
    }

    if state == "whitelist" then
        Live.retrying[uid] = nil
        Live.retryCount[uid] = nil

        guiSetPlayer(
            p,
            "whitelist",
            string.format(
                "Eligible: %d  |  Total value: %s\nItems: %s",
                eligibleCopies(inv),
                fmtValue(inv.total)..((inv.unpriced or 0)>0 and (" + "..inv.unpriced.." UNPRICED") or ""),
                eligibleSummary(inv)
            ),
            order
        )

        print(
            "[MM2 Scanner T4.3] WHITELIST",
            p.Name,
            "| eligible copies", eligibleCopies(inv),
            "| eligible total value", fmtValue(inv.total)
        )

    elseif state == "blacklist" then
        Live.retrying[uid] = nil
        Live.retryCount[uid] = nil

        guiSetPlayer(
            p,
            "blacklist",
            "No eligible Ancient / Godly / Chroma Godly",
            order
        )

        print(
            "[MM2 Scanner T4.3] BLACKLIST",
            p.Name,
            "| no eligible Ancient/Godly/Chroma Godly"
        )

    else
        guiSetPlayer(
            p,
            "unknown",
            (inv and ((inv.unmapped or 0) > 0 or (inv.badQty or 0) > 0))
                and ("Inventory incomplete — unmapped="..tostring(inv.unmapped or 0).." badQty="..tostring(inv.badQty or 0).."; retrying")
                or "Inventory not ready yet — automatic retry active",
            order
        )

        print(
            "[MM2 Scanner T4.3] TEMP UNKNOWN",
            p.Name,
            "| scheduling background retry"
        )
    end

    recount()
end

scheduleUnknownRetry = function(p)
    if not p or not p.Parent then
        return
    end

    local uid = tostring(p.UserId)

    if Live.retrying[uid] then
        return
    end

    local count = tonumber(Live.retryCount[uid]) or 0

    if count >= C.UnknownRetryMax then
        guiSetPlayer(
            p,
            "unknown",
            "Inventory could not be fully verified after extended retries",
            getOrder(p)
        )

        warn(
            "[MM2 Scanner T4.3] UNKNOWN FINAL",
            p.Name,
            "| extended retry limit reached"
        )
        return
    end

    Live.retrying[uid] = true
    Live.retryCount[uid] = count + 1

    task.spawn(function()
        task.wait(C.UnknownRetryDelay)

        Live.retrying[uid] = nil

        if not p.Parent then
            return
        end

        scanPlayerLive(p, "retry")
    end)
end

scanPlayerLive = function(p, reason)
    if not p or p == LP or not p.Parent then
        return
    end

    -- Initial startup happens before Part 3/4 are armed. Every later inventory
    -- read is noncritical and should yield while an outgoing request or active
    -- item trade is being handled.
    if reason~="initial" then
        if not waitForScannerWindow(p) then
            return
        end
    end

    local uid = tostring(p.UserId)

    if Live.scanning[uid] then
        return
    end

    Live.scanning[uid] = true

    local order = getOrder(p)

    guiSetPlayer(
        p,
        "scanning",
        reason == "join"
            and "New player joined — waiting for MM2 inventory..."
            or reason == "retry"
                and "Retrying inventory read..."
                or "Reading inventory...",
        order
    )

    guiSetStatus(
        string.format(
            "%s: %s",
            reason == "join"
                and "New join"
                or reason == "retry"
                    and "Retrying"
                    or "Scanning",
            p.Name
        )
    )

    print(
        "[MM2 Scanner T4.3] SCAN",
        reason or "initial",
        p.Name
    )

    local state, inv = scanOne(p, reason)

    Live.scanning[uid] = nil

    if state == "left" or not p.Parent then
        removePlayerState(p)
        return
    end

    applyPlayerResult(p, state, inv)

    if state == "unknown" then
        scheduleUnknownRetry(p)
    else
        guiSetStatus(
            string.format(
                "LIVE — %d tracked | W:%d B:%d U:%d",
                trackedCount(),
                Live.white,
                Live.black,
                Live.unknown
            )
        )
    end
end

-- Attach live listeners BEFORE the initial snapshot so nobody joining/leaving
-- during the initial scan can be missed.
Players.PlayerAdded:Connect(function(p)
    if p == LP then
        return
    end

    print(
        "[MM2 Scanner T4.3] PLAYER JOINED",
        p.Name
    )

    guiSetPlayer(
        p,
        "scanning",
        "Joined server — waiting for inventory data...",
        getOrder(p)
    )

    guiSetStatus(
        "New player joined: "
        .. p.Name
        .. " — preparing inventory scan"
    )

    task.spawn(function()
        -- Small settle delay, followed by the longer progressive read window.
        task.wait(1.5)

        if p.Parent then
            scanPlayerLive(p, "join")
        end
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    if p == LP then
        return
    end

    removePlayerState(p)
end)

-- Initial server scan.
local initial = {}

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        initial[#initial + 1] = p
    end
end

table.sort(initial, function(a, b)
    return a.Name:lower() < b.Name:lower()
end)

print(
    "[MM2 Scanner T4.3] INITIAL FULL SERVER SCAN START | players",
    #initial
)

guiSetStatus(
    "Initial scan — "
    .. tostring(#initial)
    .. " players"
)

for i, p in ipairs(initial) do
    if p.Parent then
        guiSetStatus(
            string.format(
                "Initial scan %d/%d: %s",
                i,
                #initial,
                p.Name
            )
        )

        scanPlayerLive(p, "initial")
    end

    task.wait(0.08)
end

-- Reconcile once after the initial scan in case a player joined during setup.
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        local uid = tostring(p.UserId)

        if not Live.byUserId[uid]
            and not Live.scanning[uid]
        then
            task.spawn(function()
                scanPlayerLive(p, "join")
            end)
        end
    end
end

guiSetStatus(
    string.format(
        "LIVE — tracking joins/leaves | W:%d B:%d U:%d",
        Live.white,
        Live.black,
        Live.unknown
    )
)

print(
    "[MM2 Scanner T4.3] INITIAL SCAN COMPLETE",
    "| whitelist", Live.white,
    "| blacklist", Live.black,
    "| unknown", Live.unknown
)

print(
    "[MM2 Scanner T4.3] LIVE MODE ACTIVE - joins auto-scan with progressive retries; leavers auto-remove"
)

task.spawn(function()
    while task.wait(C.PeriodicRescanSeconds) do
        while criticalTradeActivity() do
            task.wait(0.35)
        end

        local snapshot={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP then snapshot[#snapshot+1]=p end
        end

        table.sort(snapshot,function(a,b)
            return a.UserId<b.UserId
        end)

        for _,p in ipairs(snapshot) do
            while criticalTradeActivity() do
                if not p.Parent then break end
                task.wait(0.25)
            end

            if p.Parent then
                scanPlayerLive(p,"refresh")
                task.wait(C.PeriodicRescanGap)
            end
        end
    end
end)

print(
    "[PDIDDLER3] PERIODIC RESCAN ACTIVE (PAUSES DURING REQUESTS/TRADES)",
    C.PeriodicRescanSeconds,
    "seconds"
)

print(
    "[MM2 Scanner T4.3] LIVE VALUE / INVENTORY AUDIT ACTIVE"
)



-- ============================================================================
-- SCANNER API BRIDGE FOR LATER PART-3 MODULES
-- The successful scanner above is unchanged.
-- ============================================================================
local ScannerAPI={}
local RequestUI={}

local function scannerApiBaseText(player)
    local rec=player and Live.byUserId[tostring(player.UserId)]
    if not rec or not rec.inv then return "Eligible trader" end

    return string.format(
        "Eligible: %d | Total value: %s%s\nItems: %s",
        eligibleCopies(rec.inv),
        fmtValue(rec.inv.total),
        ((rec.inv.unpriced or 0)>0) and (" + "..tostring(rec.inv.unpriced).." UNPRICED") or "",
        eligibleSummary(rec.inv)
    )
end

local function scannerApiRenderOverride(player,entry)
    if not player or not player.Parent or not entry then return end

    local base=scannerApiBaseText(player)
    if entry.extra and entry.extra~="" then
        base=tostring(entry.extra).."\n"..base
    end

    guiSetPlayer(
        player,
        entry.state,
        base,
        Live.order[tostring(player.UserId)] or 0
    )
end

function ScannerAPI.getRecord(userId)
    return Live.byUserId[tostring(userId)]
end

function ScannerAPI.isWhitelisted(userId)
    local rec=Live.byUserId[tostring(userId)]
    return rec~=nil and rec.state=="whitelist"
end

function ScannerAPI.getWhitelist()
    local out={}

    for _,rec in pairs(Live.byUserId) do
        local p=rec.player
        if rec.state=="whitelist"
            and p
            and p.Parent==Players
        then
            out[#out+1]=p
        end
    end

    table.sort(out,function(a,b)
        local ao=Live.order[tostring(a.UserId)] or math.huge
        local bo=Live.order[tostring(b.UserId)] or math.huge

        if ao~=bo then return ao<bo end
        return a.Name:lower()<b.Name:lower()
    end)

    return out
end

function ScannerAPI.hasPendingWork()
    for _,rec in pairs(Live.byUserId) do
        if rec.state=="unknown" then return true end
    end

    for _,v in pairs(Live.scanning) do
        if v then return true end
    end

    for _,v in pairs(Live.retrying) do
        if v then return true end
    end

    return false
end

function ScannerAPI.claimStatusOwner(owner)
    owner=tostring(owner or "")
    if owner=="" then return false end
    ENV.PDIDDLER_STATUS_OWNER=owner
    return true
end

function ScannerAPI.releaseStatusOwner(owner)
    owner=tostring(owner or "")
    if tostring(ENV.PDIDDLER_STATUS_OWNER or "")==owner then
        ENV.PDIDDLER_STATUS_OWNER=nil
        return true
    end
    return false
end

function ScannerAPI.getStatusOwner()
    return ENV.PDIDDLER_STATUS_OWNER
end

function ScannerAPI.setStatus(text,owner)
    return guiSetStatus(tostring(text or ""),owner)
end

function ScannerAPI.setRequestState(player,state,extra)
    if not player then return end

    local uid=tostring(player.UserId)
    RequestUI[uid]={
        state=tostring(state or "processed"),
        extra=tostring(extra or "")
    }

    scannerApiRenderOverride(player,RequestUI[uid])
end

function ScannerAPI.clearRequestState(player)
    if not player then return end
    RequestUI[tostring(player.UserId)]=nil
end

local OwnInventoryGate={
    busy=false,
    inflight=false,
    lastCallAt=0,
    timeoutCount=0,
}

function ScannerAPI.getOwnInventory()
    local remotes=RS:FindFirstChild("Remotes")
    local invFolder=remotes and remotes:FindFirstChild("Inventory")
    local rf=invFolder and invFolder:FindFirstChild("GetProfileData")

    if not rf or not rf:IsA("RemoteFunction") then
        return nil,"GetProfileData-missing"
    end

    if OwnInventoryGate.busy or OwnInventoryGate.inflight then
        return nil,"own-inventory-busy"
    end

    OwnInventoryGate.busy=true

    local elapsed=os.clock()-OwnInventoryGate.lastCallAt
    if elapsed<C.RemoteMinInterval then
        task.wait(C.RemoteMinInterval-elapsed)
    end

    local done=false
    local ok=false
    local raw=nil

    OwnInventoryGate.inflight=true

    task.spawn(function()
        ok,raw=pcall(function()
            return rf:InvokeServer()
        end)
        done=true
        OwnInventoryGate.inflight=false
    end)

    local deadline=os.clock()+C.RemoteTimeout
    while not done and os.clock()<deadline do
        task.wait(0.03)
    end

    OwnInventoryGate.lastCallAt=os.clock()
    OwnInventoryGate.busy=false

    if not done then
        OwnInventoryGate.timeoutCount+=1
        return nil,"own-inventory-timeout"
    end

    if not ok or type(raw)~="table" then
        return nil,"own-inventory-rpc-failed"
    end

    local prof=unwrapProfile(raw)
    if not prof then
        return nil,"own-profile-invalid"
    end

    local parsed=inventoryFromProfile(prof)
    if not parsed then
        return nil,"own-inventory-parse-failed"
    end

    return parsed,nil
end

function ScannerAPI.restoreWhitelist(player,prefix)
    if not player then return end

    local uid=tostring(player.UserId)
    RequestUI[uid]=nil

    local rec=Live.byUserId[uid]
    if not rec or rec.state~="whitelist" then return end

    guiSetPlayer(
        player,
        "whitelist",
        ((prefix and prefix~="") and (tostring(prefix).."\n") or "")
        ..scannerApiBaseText(player),
        Live.order[uid] or 0
    )
end

-- Scanner refreshes can redraw a whitelist row. Reapply request state so
-- the request executor remains the authoritative owner of request UI.
task.spawn(function()
    while task.wait(1.00) do
        for uid,entry in pairs(RequestUI) do
            local rec=Live.byUserId[uid]
            local p=rec and rec.player

            if p and p.Parent==Players then
                scannerApiRenderOverride(p,entry)
            elseif not rec then
                RequestUI[uid]=nil
            end
        end
    end
end)

return ScannerAPI
