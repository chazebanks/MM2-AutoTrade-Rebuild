-- pdiddler3 SCANNER-ONLY TEST (safe first-stage validation)
-- Extracted T4.4 live eligibility scanner from proven prior build.
-- No outgoing requests, no incoming acceptance, no final trade acceptance.
-- This is not the complete Part 3 implementation.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
if not LP then
    warn("[MM2 Scanner T4] LocalPlayer missing")
    return
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
}

local State = {
    targetReader = nil,
    targetMode = nil,
    targetReaderCheckedAt = 0,
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
    frame.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ClipsDescendants = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Color = Color3.fromRGB(120, 126, 138)
    stroke.Parent = frame

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = frame
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.fromOffset(0, 0)
    titleBar.BackgroundTransparency = 1
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

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.Parent = titleBar
    minimize.Size = UDim2.fromOffset(42, 30)
    minimize.Position = UDim2.new(1, -52, 0, 5)
    minimize.BackgroundColor3 = Color3.fromRGB(45, 49, 58)
    minimize.BackgroundTransparency = 0.08
    minimize.BorderSizePixel = 0
    minimize.Font = Enum.Font.GothamBold
    minimize.TextSize = 18
    minimize.TextColor3 = Color3.fromRGB(238, 241, 245)
    minimize.Text = "—"

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 8)
    minCorner.Parent = minimize

    local status = makeText(
        frame,
        "Status",
        "Starting scanner...",
        UDim2.new(1, -28, 0, 42),
        UDim2.fromOffset(14, 42),
        14
    )
    status.TextColor3 = Color3.fromRGB(188, 199, 216)

    local summary = makeText(
        frame,
        "Summary",
        "Whitelist 0  |  Blacklist 0  |  Unknown 0",
        UDim2.new(1, -28, 0, 28),
        UDim2.fromOffset(14, 84),
        14
    )
    summary.Font = Enum.Font.GothamSemibold

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Parent = frame
    divider.BorderSizePixel = 0
    divider.BackgroundColor3 = Color3.fromRGB(76, 82, 94)
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

local function guiSetStatus(text)
    if GUI.status then
        GUI.status.Text = tostring(text or "")
    end
end

local function guiSetSummary(white, black, unknown)
    if GUI.summary then
        GUI.summary.Text = string.format(
            "Whitelist %d  |  Blacklist %d  |  Unknown %d",
            tonumber(white) or 0,
            tonumber(black) or 0,
            tonumber(unknown) or 0
        )
    end
end

local function rowColor(state)
    if state == "whitelist" then
        return Color3.fromRGB(25, 88, 55)
    elseif state == "blacklist" then
        return Color3.fromRGB(75, 35, 38)
    elseif state == "unknown" then
        return Color3.fromRGB(86, 71, 31)
    elseif state == "sending" then
        return Color3.fromRGB(48, 63, 92)
    elseif state == "requesting" then
        return Color3.fromRGB(40, 72, 120)
    elseif state == "ignored" then
        return Color3.fromRGB(92, 66, 31)
    elseif state == "declined" then
        return Color3.fromRGB(96, 45, 45)
    elseif state == "accepted" then
        return Color3.fromRGB(28, 108, 66)
    elseif state == "left" then
        return Color3.fromRGB(64, 64, 68)
    elseif state == "sendfailed" then
        return Color3.fromRGB(112, 52, 52)
    elseif state == "processed" then
        return Color3.fromRGB(48, 58, 72)
    end

    return Color3.fromRGB(38, 49, 67)
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

        GUI.rows[key] = label
    end

    label.BackgroundColor3 = rowColor(state)
    label.LayoutOrder = order or label.LayoutOrder

    local username = tostring(player.Name or "?")
    local display = tostring(player.DisplayName or username)
    local nameText = username

    if display ~= username then
        nameText = display .. "  @" .. username
    end

    label.Text = string.format(
        "[%s]  %s\n%s",
        rowTitle(state),
        nameText,
        tostring(detail or "")
    )
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
local Mods=RS:FindFirstChild("Modules")
local Sync=req(DB and DB:FindFirstChild("Sync")) or {}
local ProfileData=req(Mods and Mods:FindFirstChild("ProfileData")) or {}
local Meta={}
local NameCandidates={}
local AssetCandidates={}

local function candidateAdd(map,q,m)
 if not q or q=="" or not m then return end
 map[q]=map[q] or {}
 for _,x in ipairs(map[q]) do if x==m then return end end
 map[q][#map[q]+1]=m
end

local function assetKey(x)
 local raw=tostring(x or "")
 if raw=="" then return "" end
 return raw:match("(%d%d%d%d%d+)") or norm(raw)
end

local function indexCatalogAssets(d,m)
 for k,v in pairs(d or {}) do
  local nk=norm(k)
  if (type(v)=="string" or type(v)=="number")
   and (nk:find("image",1,true) or nk:find("icon",1,true) or nk:find("texture",1,true) or nk:find("thumbnail",1,true))
  then
   local a=assetKey(v)
   if a~="" then candidateAdd(AssetCandidates,a,m) end
  end
 end
end

local function addNameMeta(q,m) candidateAdd(NameCandidates,q,m) end

local function indexItems(src)
 if type(src)~="table" then return end
 for id,d in pairs(src) do
  if type(d)=="table" and (d.ItemType=="Knife" or d.ItemType=="Gun") then
   local m={id=tostring(id),cat="Weapons",data=d,name=d.ItemName or d.Name or tostring(id),chroma=d.Chroma==true,type=d.ItemType or "",rarity=d.Rarity or ""}
   Meta["Weapons|"..tostring(id)]=m
   indexCatalogAssets(d,m)
   local display=m.chroma and (m.name:lower():match("^chroma%s") and m.name or ("Chroma "..m.name)) or m.name
   addNameMeta(norm(display),m)
  end
 end
end
indexItems(Sync.Weapons or Sync.Item)

local function tradable(d)
 return type(d)=="table" and d.Tradable~=false and d.CanTrade~=false and d.Untradable~=true and d.NonTradable~=true and d.Locked~=true
end

local VariantPrefixes={{"gold","Gold"},{"silver","Silver"},{"bronze","Bronze"},{"blue","Blue"},{"red","Red"},{"purple","Purple"},{"green","Green"},{"yellow","Yellow"},{"orange","Orange"},{"pink","Pink"}}
local function identityName(meta)
 if not meta then return "" end
 local name=tostring(meta.name or meta.id or "")
 local d=meta.data or {}
 if meta.chroma then return name:lower():match("^chroma%s") and name or ("Chroma "..name) end
 local nameq=norm(name)
 if norm(meta.rarity)=="unique" then
  for _,field in ipairs({"Variant","VariantName","Color","Colour","LeaderboardColor","LeaderboardColour","Edition","Version"}) do
   local rq=norm(d[field])
   if rq~="" then
    for _,pair in ipairs(VariantPrefixes) do
     if (rq==pair[1] or rq:find(pair[1],1,true)) and not nameq:find(pair[1],1,true) then return pair[2].." "..name end
    end
   end
  end
 end
 return name
end

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
godly|741|1600|Darkshot.png
godly|742|1575|Darksword.png
godly|696|1160|BlossomGun.png
godly|697|1150|Sakura.png
godly|901|775|SunsetGun.png
godly|961|680|Snowcannon.png
godly|854|675|Bauble.png
godly|902|650|SunsetKnife.png
godly|833|640|soul.png
godly|832|630|spirit.png
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
 log("VALUE SNAPSHOT READY",count,"rows (loaded once)")
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

local function checkerAlias(page,name,typ)
 local q,t=norm(name),norm(typ)
 if page=="godly" and q=="sunrise" and (t=="" or t=="gun") then return "901" end
 if page=="godly" and q=="sunset" and (t=="" or t=="knife") then return "902" end
 if page=="chroma" and (q=="chromasunrise" or q=="sunrise") and (t=="" or t=="gun") then return "899" end
 if page=="chroma" and (q=="chromasunset" or q=="sunset") and (t=="" or t=="knife") then return "900" end
 if page=="chroma" and (q=="chromagemstone" or q=="gemstone") then return "439" end
 if page=="chroma" and (q=="chromamortal" or q=="mortal") then return "1033" end
 if page=="chroma" and (q=="chromaimmortal" or q=="immortal") then return "1034" end
end

local function isSunset(page,id,name)
 local q=norm(name)
 return tostring(id or "")=="902" or tostring(id or "")=="900" or q=="sunset" or q=="chromasunset"
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
  local aid=checkerAlias(pageHint,shown,typ)
  local rec=aid and Checker.byId[pageHint] and Checker.byId[pageHint][aid]
  if rec then
   if isSunset(rec.page,rec.id,shown) then return nil,"sunset ignored" end
   checkerCache[ck]=rec; return rec,"alias"
  end
 end
 local pages={}
 if pageHint~="" then pages[#pages+1]=pageHint end
 for _,p in ipairs({"ancient","chroma","godly"}) do
  local seen=false; for _,x in ipairs(pages) do if x==p then seen=true break end end
  if not seen and ((chroma and p=="chroma") or (not chroma and p~="chroma")) then pages[#pages+1]=p end
 end
 local best,bestScore,tied,tiedSame=nil,-100000,false,true
 local itemYear=iid:match("(20%d%d)")
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
   if score<240 and n2~="" and c2~="" and math.min(#n2,#c2)>=5 and (n2:find(c2,1,true) or c2:find(n2,1,true)) then score=205 end
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
 if best and bestScore>=200 and (not tied or tiedSame) then
  if isSunset(best.page,best.id,shown) then return nil,"sunset ignored" end
  checkerCache[ck]=best
  return best,tied and "value-equivalent" or ("match:"..bestScore)
 end
 if tied then return nil,"ambiguous" end
 return nil,"unresolved"
end

local function checkerMarket(meta)
 local page=checkerPage(meta)
 if not allowedPage(page) then return nil end
 local rec,why=checkerResolve(identityName(meta),{page=page,type=meta.type,id=meta.id,chroma=meta.chroma,meta=meta})
 if not rec then return nil,why end
 return {v=rec.v,id=rec.id,page=rec.page,img=rec.img},nil
end

checkerBuild()

local function ownProfile(forceRemote)
 local rem=RS:FindFirstChild("Remotes")
 local inv=rem and rem:FindFirstChild("Inventory")
 local rf=inv and inv:FindFirstChild("GetProfileData")
 if forceRemote and rf and rf:IsA("RemoteFunction") then
  local ok,x=pcall(function() return rf:InvokeServer() end)
  if ok and type(x)=="table" then return x end
 end
 if type(ProfileData)=="table" and ProfileData.Weapons then return ProfileData end
 if rf and rf:IsA("RemoteFunction") then
  local ok,x=pcall(function() return rf:InvokeServer() end)
  if ok and type(x)=="table" then return x end
 end
end

local function inventoryFromProfile(prof)
 if type(prof)~="table" then return nil end
 local owned=prof.Weapons and prof.Weapons.Owned
 if type(owned)~="table" then return nil end

 local out={items={},total=0,rawOwned=0,unmapped=0,unpriced=0}

 for id,count in pairs(owned) do
  local qty=type(count)=="number" and math.max(0,math.floor(count)) or 1
  if qty>0 then
   out.rawOwned += qty
   local m=Meta["Weapons|"..tostring(id)]

   -- If the live MM2 catalog cannot identify an owned weapon ID, the scan is
   -- incomplete. Never turn an incomplete scan into a blacklist.
   if not m then
    out.unmapped += qty
   elseif tradable(m.data) and allowedPage(checkerPage(m)) then
    local e=checkerMarket(m)
    out.items[#out.items+1]={
     id=m.id,cat="Weapons",name=identityName(m),qty=qty,
     value=e and e.v or nil,type=m.type,page=checkerPage(m),
     checkerId=e and e.id or "UNPRICED"
    }
    if e then
     out.total += e.v*qty
    else
     out.unpriced += qty
    end
   end
  end
 end

 table.sort(out.items,function(a,b)
  local av=tonumber(a.value) or -math.huge
  local bv=tonumber(b.value) or -math.huge
  if av~=bv then return av>bv end
  return tostring(a.id)<tostring(b.id)
 end)

 return out
end

local function scanOwn() return inventoryFromProfile(ownProfile(true) or ownProfile(false)) end

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

local function targetInventory(p,force)
 if not p or p==LP or not p.Parent then return nil end

 -- Match MM2's own ViewProfileModule exactly:
 -- Remotes.Extras.GetFullInventory:InvokeServer(usernameString)
 local rf=getFullInventoryRemote()
 if not rf then
  warn("[PDIDDLER3] GetFullInventory remote missing")
  return nil
 end

 local ok,raw=pcall(function()
  return rf:InvokeServer(p.Name)
 end)
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

    local inv

    for attempt = 1, retries do
        if not p or not p.Parent then
            return "left", nil
        end

        inv = targetInventory(p, attempt > 1)

        if inv then
            -- A verified full inventory can be blacklisted only when every
            -- owned weapon ID was understood by the live MM2 catalog.
            if (inv.unmapped or 0) > 0 then
                return "unknown", inv
            end
            return (#inv.items > 0) and "whitelist" or "blacklist", inv
        end

        if attempt < retries then
            guiSetStatus(
                string.format(
                    "%s inventory not ready — retry %d/%d",
                    p.Name,
                    attempt,
                    retries
                )
            )

            task.wait(retryDelay)
        end
    end

    if not p or not p.Parent then
        return "left", nil
    end

    return "unknown", nil
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
    Live.order[uid] = nil

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
            (inv and (inv.unmapped or 0) > 0)
                and ("Inventory incomplete — "..tostring(inv.unmapped).." unmapped weapon copies; retrying")
                or "Inventory not ready yet — automatic retry active",
            order
        )

        warn(
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
            "Inventory stayed unreadable after extended retries",
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

print(
    "[MM2 Scanner T4.3] CHECK: 'VALUE SNAPSHOT READY' should have appeared exactly ONCE"
)

