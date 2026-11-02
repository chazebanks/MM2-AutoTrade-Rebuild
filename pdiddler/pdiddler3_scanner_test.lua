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

    -- Inventory remote pacing / live refresh.
    RemoteMinInterval = 0.18,
    RemoteTimeout = 4.5,
    PeriodicRescanSeconds = 45,
    PeriodicRescanGap = 0.35,
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
indexItems(Sync.Weapons or Sync.Item)

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

local function checkerPage(meta)
 if not meta then return nil end
 if meta.chroma then return "chroma" end
 local r=norm(meta.rarity)
 if r=="ancient" or r=="godly" then return r end
 return nil
end

local function allowedPage(page)
 return page=="ancient" or page=="godly" or page=="chroma"
end

local LiveValues={
 ready=false,
 attempted=false,
 lastAttemptAt=0,
 lastLoadedAt=0,
 RetrySeconds=30,
 RefreshSeconds=600,
 source="unavailable",
 count=0,
 byPage={godly={},chroma={},ancient={}},
 collisions={godly={},chroma={},ancient={}}
}

local function httpGetText(url)
 local ok,res=pcall(function() return game:HttpGet(url) end)
 if ok and type(res)=="string" and #res>100 then return res end

 local reqFn=nil
 if type(request)=="function" then reqFn=request
 elseif type(http_request)=="function" then reqFn=http_request
 elseif type(syn)=="table" and type(syn.request)=="function" then reqFn=syn.request end

 if reqFn then
  local ok2,res2=pcall(function()
   return reqFn({Url=url,Method="GET"})
  end)
  if ok2 and type(res2)=="table" and type(res2.Body)=="string" and #res2.Body>100 then
   return res2.Body
  end
 end
end

local function htmlPlain(html)
 html=tostring(html or "")
 html=html:gsub("<script.->.-</script>"," ")
 html=html:gsub("<style.->.-</style>"," ")
 html=html:gsub("<br%s*/?>","\n")
 html=html:gsub("</p>","\n"):gsub("</div>","\n"):gsub("</td>","\n")
 html=html:gsub("</tr>","\n"):gsub("</li>","\n")
 html=html:gsub("<[^>]->"," ")
 html=html:gsub("&nbsp;"," "):gsub("&#160;"," ")
 html=html:gsub("&amp;","&"):gsub("&apos;","'"):gsub("&#39;","'")
 html=html:gsub("&quot;",'"')
 return html
end

local function cleanValueName(x)
 x=tostring(x or "")
 x=x:gsub("^%s*Image%s*[%|%-]?%s*","")
 x=x:gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
 return x
end

local function ignoreValueLine(line)
 local q=line:lower()
 return line==""
  or q=="home"
  or q=="godly values"
  or q=="ancient values"
  or q=="all values below are based in seers."
  or q=="seer"
  or q=="chroma"
  or q:match("^tier%s")
  or q=="special tier"
  or q:match("^demand:")
  or q:match("^rarity:")
  or q:match("^stability:")
  or q:match("^status:")
  or q:match("^origin:")
  or q:match("^obtained:")
  or q:match("^%(")
  or q:find("privacy policy",1,true)
  or q:find("t.o.s",1,true)
end

local function parseValuePage(html,basePage)
 local plain=htmlPlain(html)
 local page=basePage
 local lastName=nil
 local added=0

 for raw in plain:gmatch("[^\r\n]+") do
  local line=cleanValueName(raw)

  if line=="CHROMA" then
   page="chroma"
   lastName=nil
  elseif page=="chroma" and line:match("^TIER%s") then
   page="godly"
   lastName=nil
  else
   local num=line:match("^Value:%s*([%d,]+%.?%d*)")
   if num and lastName and LiveValues.byPage[page] then
    local v=tonumber((num:gsub(",","")))
    if v then
     local key=norm(lastName)
     local bucket=LiveValues.byPage[page][key]
     if not bucket then
      bucket={}
      LiveValues.byPage[page][key]=bucket
     end
     bucket[#bucket+1]={name=lastName,value=v}
     if #bucket>1 then
      LiveValues.collisions[page][key]=true
     end
     added += 1
    end
    lastName=nil
   elseif not ignoreValueLine(line)
    and not line:find(":",1,true)
    and #line<=80
   then
    lastName=line
   end
  end
 end

 return added
end

local function resetLiveValueMaps()
 LiveValues.byPage={godly={},chroma={},ancient={}}
 LiveValues.collisions={godly={},chroma={},ancient={}}
 LiveValues.count=0
end

local function buildLiveValues()
 local now=os.clock()

 if LiveValues.ready and (now-LiveValues.lastLoadedAt)<LiveValues.RefreshSeconds then
  return true
 end

 if LiveValues.attempted
  and not LiveValues.ready
  and (now-LiveValues.lastAttemptAt)<LiveValues.RetrySeconds
 then
  return false
 end

 LiveValues.attempted=true
 LiveValues.lastAttemptAt=now
 resetLiveValueMaps()

 local godlyHtml=httpGetText("https://www.mm2values.com/mobile.php?p=godly")
 local ancientHtml=httpGetText("https://www.mm2values.com/mobile.php?p=ancient")

 local n=0
 if godlyHtml then n += parseValuePage(godlyHtml,"godly") end
 if ancientHtml then n += parseValuePage(ancientHtml,"ancient") end

 local godlyN,chromaN,ancientN=0,0,0
 local collisions=0
 for _,bucket in pairs(LiveValues.byPage.godly) do godlyN+=#bucket end
 for _,bucket in pairs(LiveValues.byPage.chroma) do chromaN+=#bucket end
 for _,bucket in pairs(LiveValues.byPage.ancient) do ancientN+=#bucket end
 for _,pageMap in pairs(LiveValues.collisions) do
  for _ in pairs(pageMap) do collisions+=1 end
 end

 local sentinels =
  LiveValues.byPage.godly[norm("Elderwood Revolver")]
  and LiveValues.byPage.godly[norm("Death Shard")]
  and LiveValues.byPage.chroma[norm("Chroma DeathShard")]
  and LiveValues.byPage.ancient[norm("Gingerscope")]
  and LiveValues.byPage.ancient[norm("Icebreaker")]

 if godlyN>=60 and chromaN>=15 and ancientN>=10 and sentinels then
  LiveValues.ready=true
  LiveValues.lastLoadedAt=now
  LiveValues.source="mm2values-live"
  LiveValues.count=n
  print("[PDIDDLER3] LIVE MM2VALUES READY","godly",godlyN,"chroma",chromaN,"ancient",ancientN,"nameCollisions",collisions)
  return true
 end

 LiveValues.ready=false
 LiveValues.source="unavailable"
 warn("[PDIDDLER3] LIVE MM2VALUES INCOMPLETE","godly",godlyN,"chroma",chromaN,"ancient",ancientN,"- prices disabled rather than guessing")
 return false
end

local function liveValueKey(meta)
 local q=norm(identityName(meta))
 q=q:gsub("^vamps","vampires")
 q=q:gsub("travellers","travelers")
 return q
end

local function liveMarket(meta)
 if not buildLiveValues() then return nil,"live-unavailable" end
 local page=checkerPage(meta)
 if not allowedPage(page) then return nil,"tier-excluded" end

 local q=liveValueKey(meta)
 local bucket=LiveValues.byPage[page] and LiveValues.byPage[page][q]
 if not bucket or #bucket==0 then
  return nil,"live-name-miss"
 end

 if #bucket==1 then
  local rec=bucket[1]
  return {
   v=rec.value,
   id=q,
   page=page,
   img="LIVE:"..tostring(rec.name),
   source="live-exact-name",
   identity=metaIdentity(meta)
  },nil
 end

 -- Duplicate normalized names must NEVER be resolved by load order.
 -- If every duplicate has the same value, the numeric result is safe.
 local first=tonumber(bucket[1].value)
 local same=true
 for i=2,#bucket do
  if tonumber(bucket[i].value)~=first then
   same=false
   break
  end
 end

 if same and first then
  return {
   v=first,
   id=q,
   page=page,
   img="LIVE:DUPLICATE-SAME-VALUE:"..identityName(meta),
   source="live-collision-same-value",
   identity=metaIdentity(meta)
  },nil
 end

 return nil,"live-name-collision"
end
local function checkerMarket(meta)
 local page=checkerPage(meta)
 if not allowedPage(page) then return nil,"tier-excluded" end

 local live,why=liveMarket(meta)
 if live then return live,nil end

 -- Never use stale/fuzzy pricing. A qualifying item may remain UNPRICED,
 -- but it must never receive a believable value from a guess.
 return nil,why or "exact-live-value-unresolved"
end


local function auditEligibleIdentityCollisions()
 local groups={}
 for _,m in pairs(Meta) do
  local page=checkerPage(m)
  if allowedPage(page) then
   local k=table.concat({page,norm(identityName(m))},"|")
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

local function targetInventory(p,force)
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
    local lastInv=nil

    for attempt = 1, retries do
        if not p or not p.Parent then
            return "left", nil
        end

        local inv = targetInventory(p, attempt > 1)

        if inv
            and (inv.unmapped or 0)==0
            and (inv.badQty or 0)==0
        then
            local fp=tostring(inv.fingerprint or "")

            if lastFingerprint~=nil and fp==lastFingerprint then
                -- Classification happens only after TWO identical,
                -- complete snapshots of this exact target.
                if #inv.items>0 then
                    return "whitelist", inv
                end
                return "blacklist", inv
            end

            lastFingerprint=fp
            lastInv=inv
        else
            -- Any incomplete/unreadable response breaks stability proof.
            lastFingerprint=nil
            lastInv=inv
        end

        if attempt < retries then
            guiSetStatus(
                string.format(
                    "%s inventory verification — stable read %d/%d",
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
        local snapshot={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP then snapshot[#snapshot+1]=p end
        end

        table.sort(snapshot,function(a,b)
            return a.UserId<b.UserId
        end)

        for _,p in ipairs(snapshot) do
            if p.Parent then
                scanPlayerLive(p,"refresh")
                task.wait(C.PeriodicRescanGap)
            end
        end
    end
end)

print(
    "[PDIDDLER3] PERIODIC RESCAN ACTIVE",
    C.PeriodicRescanSeconds,
    "seconds"
)

print(
    "[MM2 Scanner T4.3] LIVE VALUE / INVENTORY AUDIT ACTIVE"
)

