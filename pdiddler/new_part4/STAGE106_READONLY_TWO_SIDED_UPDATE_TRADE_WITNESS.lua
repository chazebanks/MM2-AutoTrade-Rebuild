-- Stage106: one read-only two-sided UpdateTrade / original Stage9 slot witness.
-- Local client candidates only; never proves event causality or settlement.
local E = (type(getgenv) == "function" and getgenv()) or _G
local KEY = "GINGERSCOPE_STAGE106_READONLY_WITNESS"
local targetName = E.PDIDDLER_STAGE106_TARGET_USERNAME
if
    E.PDIDDLER_STAGE106_READONLY_ARMED ~= true
    or type(targetName) ~= "string"
    or #targetName < 3
    or #targetName > 20
    or not targetName:match("^[A-Za-z0-9_]+$")
then
    warn("[STAGE106] explicitly arm READONLY and set the exact consenting ALT username")
    return nil
end
if game.PlaceId ~= 142823291 then
    warn("[STAGE106] original MM2 place only")
    return nil
end
if E[KEY] ~= nil then
    warn("[STAGE106] one-shot already used in this JobId; do not retry")
    return E[KEY]
end
for _, name in ipairs({
    "GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW",
    "GINGERSCOPE_STAGE89_SINGLE_REQUEST_DIAGNOSTIC",
    "GINGERSCOPE_STAGE90_CARD_LAYOUT_AUDIT",
    "GINGERSCOPE_STAGE91_SINGLE_REQUEST_DIAGNOSTIC",
    "GINGERSCOPE_STAGE92_SINGLE_REQUEST_DIAGNOSTIC",
    "GINGERSCOPE_STAGE93_SINGLE_REQUEST_DIAGNOSTIC",
    "GINGERSCOPE_STAGE97_PARTNER_EVENT_READONLY",
    "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
    "PDIDDLER_OUTGOING_CONTROLLER",
    "PDIDDLER_OUTGOING_SESSION",
    "PDIDDLER_OUTGOING_BUSY_SESSION",
    "PDIDDLER_PART4_SESSION",
    "PDIDDLER_PART4_CONTROLLER",
    "PDIDDLER_HOPPING_SESSION",
    "PDIDDLER_PART5_CONTROLLER",
    "PDIDDLER_STATUS_OWNER",
}) do
    if E[name] ~= nil then
        warn("[STAGE106] another pdiddler owner is present; use a fresh server")
        return nil
    end
end

local report = {
    schema = "gingerscope-stage106-two-sided-update-trade-readonly-v1",
    status = "STARTING",
    reason = "INITIALIZING",
    readOnly = true,
    clientOnly = true,
    targetClientBound = false,
    exactPartnerGuiObserved = false,
    stage9ObserverBound = false,
    stage9Frames = 0,
    eventReceiptCount = 0,
    bothSidesReconciled = false,
    ourMatchedSlotCount = 0,
    theirMatchedSlotCount = 0,
    guiNameOnlySlotCount = 0,
    guiRawTextSlotCount = 0,
    guiTwoStableSamples = false,
    observedVisibleGuiTransition = false,
    onScreenGuideShown = false,
    onScreenGuideFinalShown = false,
    onScreenGuideNonOverlappingTrade = false,
    onScreenGuidePlacementFailures = 0,
    onScreenGuideUpdates = 0,
    actualRequests = 0,
    actualOffers = 0,
    actualAccepts = 0,
    actualDeclines = 0,
    actualTeleports = 0,
    eventSessionAssociationProven = false,
    callbackCausalityProven = false,
    rawItemIdConfirmed = false,
    uniqueWeaponInstanceProven = false,
    currentPricesVerified = false,
    priceForTradeVerified = false,
    marketValueAuthority = false,
    sourcePublisherFresh = false,
    serverAttestation = false,
    serverTradeRevisionProven = false,
    serverCompletionProven = false,
    authenticatedOwnedInventory = false,
    numericSupremeCheckerIdVerified = false,
    authorizesTrade = false,
    authorizesAccept = false,
    mayRecordCompletedTrade = false,
    mayReportProfit = false,
    maySendDiscordWebhook = false,
    mayUseForStrategyLearning = false,
    tradeOutcome = "UNKNOWN",
    elapsedSeconds = 0,
}

local started = os.clock()
local state = { running = true, report = report }
E[KEY] = state
local Players = game:GetService("Players")
local LocalPlayer = Players and Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
local jobId = tostring(game.JobId)
local target = nil
local tradeRoot = nil
local connection = nil
local receiptCount = 0
local receipt = nil
local callbackBad = false
local callbackReason = nil
local currentPrompt = nil
local panel = nil
local sourceCache = {}

local function safeJson()
    local ok, json = pcall(function()
        return game:GetService("HttpService"):JSONEncode(report)
    end)
    if ok and type(json) == "string" and #json < 4000 then
        local line = "[GINGERSCOPE STAGE106 TWO-SIDED UPDATE TRADE] " .. json
        print(line)
        if type(setclipboard) == "function" then
            pcall(setclipboard, line)
        end
    else
        warn("[STAGE106] sanitized aggregate report unavailable")
    end
end

local function currentTradeRoots()
    local roots = {}
    if not PlayerGui then
        return roots
    end
    for _, guiName in ipairs({ "TradeGUI_Phone", "TradeGUI" }) do
        local gui = PlayerGui:FindFirstChild(guiName)
        local container = gui and gui:FindFirstChild("Container")
        local root = container and container:FindFirstChild("Trade")
        if root and gui.Enabled ~= false and root.Visible ~= false then
            roots[#roots + 1] = root
        end
    end
    return roots
end

local function exactRoot()
    if #currentTradeRoots() == 0 then
        return nil, "NO_OPEN_TRADE_ROOT"
    end
    local roots = currentTradeRoots()
    if #roots ~= 1 then
        return nil, "MULTIPLE_VISIBLE_TRADE_GUI_ROOTS"
    end
    local root = roots[1]
    local side = root:FindFirstChild("TheirOffer")
    local header = side and side:FindFirstChild("Username")
    if
        not header
        or not (header:IsA("TextLabel") or header:IsA("TextButton"))
        or type(header.Text) ~= "string"
    then
        return nil, "TRADE_PARTNER_HEADER_UNAVAILABLE"
    end
    local shown = header.Text:match("^%s*%((.-)%)%s*$") or header.Text
    shown = shown:gsub("^@", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if shown:lower() ~= target.Name:lower() then
        return nil, "TRADE_GUI_WRONG_PARTNER"
    end
    return root, "EXACT_CURRENT_CLIENT_PARTNER"
end

local function live()
    return state.running
        and E[KEY] == state
        and tostring(game.JobId) == jobId
        and LocalPlayer ~= nil
        and LocalPlayer.Parent == Players
        and PlayerGui ~= nil
        and PlayerGui.Parent == LocalPlayer
        and LocalPlayer:FindFirstChildOfClass("PlayerGui") == PlayerGui
        and target ~= nil
        and target.Parent == Players
        and Players:GetPlayerByUserId(target.UserId) == target
end

local function rectangle(node)
    local ok, position, size = pcall(function()
        return node.AbsolutePosition, node.AbsoluteSize
    end)
    if not ok or not position or not size then
        return nil
    end
    local x, y, w, h = position.X, position.Y, size.X, size.Y
    if
        type(x) ~= "number"
        or type(y) ~= "number"
        or type(w) ~= "number"
        or type(h) ~= "number"
        or x ~= x
        or y ~= y
        or w ~= w
        or h ~= h
        or w <= 0
        or h <= 0
    then
        return nil
    end
    return { x = x, y = y, w = w, h = h }
end

local function intersects(a, b, gap)
    return a.x < b.x + b.w + gap
        and a.x + a.w > b.x - gap
        and a.y < b.y + b.h + gap
        and a.y + a.h > b.y - gap
end

local function createPanel(layout, playerGui, workspaceService)
    local ok, ui = pcall(function()
        local screen = Instance.new("ScreenGui")
        screen.Name = "PDIDDLER_Stage106_ReadOnly_Instructions"
        screen.ResetOnSpawn = false
        screen.IgnoreGuiInset = true
        screen.DisplayOrder = 150
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screen.Parent = playerGui

        local frame = Instance.new("Frame")
        frame.Name = "Instructions"
        frame.BackgroundColor3 = Color3.fromRGB(28, 23, 40)
        frame.BackgroundTransparency = 0.04
        frame.BorderSizePixel = 0
        frame.Active = false
        frame.Visible = false
        frame.ZIndex = 10
        frame.Parent = screen
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(177, 128, 239)
        stroke.Thickness = 2
        stroke.Parent = frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame
        local title = Instance.new("TextLabel")
        title.Name = "Step"
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(218, 187, 255)
        title.TextSize = 13
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextYAlignment = Enum.TextYAlignment.Center
        title.Active = false
        title.ZIndex = 11
        title.Parent = frame
        local body = Instance.new("TextLabel")
        body.Name = "Instruction"
        body.BackgroundTransparency = 1
        body.TextColor3 = Color3.fromRGB(255, 255, 255)
        body.TextWrapped = true
        body.TextSize = 16
        body.Font = Enum.Font.GothamSemibold
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Active = false
        body.ZIndex = 11
        body.Parent = frame
        local hint = Instance.new("TextLabel")
        hint.Name = "Warning"
        hint.BackgroundTransparency = 1
        hint.TextColor3 = Color3.fromRGB(235, 214, 255)
        hint.TextSize = 12
        hint.TextWrapped = true
        hint.Font = Enum.Font.Gotham
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.TextYAlignment = Enum.TextYAlignment.Center
        hint.Active = false
        hint.ZIndex = 11
        hint.Parent = frame
        return { screen = screen, frame = frame, title = title, body = body, hint = hint }
    end)
    if not ok or type(ui) ~= "table" then
        return nil, "ONSCREEN_GUIDE_PANEL_CREATION_FAILED"
    end
    local self = { ui = ui, layout = layout, workspace = workspaceService, final = false }
    function self:hide()
        pcall(function()
            self.ui.frame.Visible = false
        end)
    end
    function self:show(step, body, hint, root, isFinal)
        local camera = self.workspace.CurrentCamera
        if not camera then
            self:hide()
            return false, "VIEWPORT_UNAVAILABLE"
        end
        local viewport
        local good, value = pcall(function()
            return camera.ViewportSize
        end)
        if good and value then
            viewport = { x = value.X, y = value.Y }
        end
        local trade = nil
        if root then
            trade = rectangle(root)
            if not trade then
                self:hide()
                return false, "TRADE_BOUNDS_UNAVAILABLE"
            end
        end
        local place, why = self.layout.choose(viewport, trade, { w = 304, h = 96 })
        if not place then
            self:hide()
            return false, why
        end
        local candidate = { x = place.x, y = place.y, w = place.w, h = place.h }
        if trade and intersects(candidate, trade, 12) then
            self:hide()
            return false, "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE"
        end
        local placed = pcall(function()
            self.ui.frame.Position = UDim2.fromOffset(place.x, place.y)
            self.ui.frame.Size = UDim2.fromOffset(place.w, place.h)
            self.ui.title.Position = UDim2.fromOffset(10, 6)
            self.ui.title.Size = UDim2.fromOffset(place.w - 20, 20)
            self.ui.body.Position = UDim2.fromOffset(10, 27)
            self.ui.body.Size = UDim2.fromOffset(place.w - 20, 42)
            self.ui.hint.Position = UDim2.fromOffset(10, 72)
            self.ui.hint.Size = UDim2.fromOffset(place.w - 20, 18)
            self.ui.title.Text = step
            self.ui.body.Text = body
            self.ui.hint.Text = hint
            self.ui.frame.Visible = true
        end)
        if not placed then
            self:hide()
            return false, "ONSCREEN_GUIDE_LAYOUT_FAILED"
        end
        report.onScreenGuideShown = true
        report.onScreenGuideUpdates = math.min(report.onScreenGuideUpdates + 1, 2000)
        if trade then
            report.onScreenGuideNonOverlappingTrade = true
        end
        if isFinal and not self.final then
            local buttonOk, button = pcall(function()
                local dismiss = Instance.new("TextButton")
                dismiss.Name = "Dismiss"
                dismiss.Text = "X"
                dismiss.TextSize = 13
                dismiss.Font = Enum.Font.GothamBold
                dismiss.TextColor3 = Color3.fromRGB(255, 255, 255)
                dismiss.BackgroundColor3 = Color3.fromRGB(90, 60, 120)
                dismiss.AutoButtonColor = false
                dismiss.Active = true
                dismiss.Selectable = true
                dismiss.ZIndex = 12
                dismiss.Size = UDim2.fromOffset(22, 20)
                dismiss.Position = UDim2.fromOffset(place.w - 26, 5)
                dismiss.Parent = self.ui.frame
                return dismiss
            end)
            if not buttonOk then
                self:hide()
                return false, "ONSCREEN_GUIDE_DISMISS_LAYOUT_FAILED"
            end
            button.Activated:Connect(function()
                pcall(function()
                    self.ui.screen:Destroy()
                end)
            end)
            self.final = true
        end
        return true, "NONOVERLAPPING_PANEL_PLACEMENT"
    end
    return true, self
end

local SOURCES = {
    stage9Contract = {
        "1971b93d324f0275e6a9affb472ac3e804439ed8",
        "pdiddler/new_part4/p4_observer_contract.lua",
    },
    stage9Native = {
        "1971b93d324f0275e6a9affb472ac3e804439ed8",
        "pdiddler/new_part4/p4_native_observer.lua",
    },
    stage83 = {
        "25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae",
        "pdiddler/intelligence_lab/stage83_public_slug_registry.lua",
    },
    stage101 = {
        "29889595b5e80c788ade75fbb97880b736fc8cb2",
        "pdiddler/intelligence_lab/stage101_multiweapon_raw_key_match.lua",
    },
    stage100Overlay = {
        "59d869b7d4d8fbcee3f2709e266b47ffb4a05d78",
        "pdiddler/new_part4/stage100_screen_prompt_overlay.lua",
    },
}
local REPOSITORY = "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"

local function loadPinned(name)
    if sourceCache[name] then
        return sourceCache[name]
    end
    local pin = SOURCES[name]
    if not pin then
        return nil
    end
    local ok, module = pcall(function()
        local text = game:HttpGet(REPOSITORY .. pin[1] .. "/" .. pin[2])
        assert(type(text) == "string" and #text > 50 and #text < 300000)
        local compile = loadstring or load
        assert(type(compile) == "function")
        return assert(compile(text))()
    end)
    if not ok or type(module) ~= "table" then
        return nil
    end
    sourceCache[name] = module
    return module
end

local function finish(status, reason)
    if not state.running then
        return state
    end
    state.running = false
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        connection = nil
    end
    local finalReason = reason or "INCONCLUSIVE"
    if panel then
        local visibleRoot = nil
        local roots = currentTradeRoots()
        if #roots == 1 then
            visibleRoot = roots[1]
        end
        local displayed, shown = pcall(
            panel.show,
            panel,
            status == "PASS" and "PASS • CLIENT CANDIDATES ONLY" or "STOP • NO TRADE AUTHORITY",
            "Stage106 read-only observation finished.",
            "Never press final Accept. Copy the sanitized aggregate report.",
            visibleRoot,
            true
        )
        if displayed and shown then
            report.onScreenGuideFinalShown = true
        else
            report.onScreenGuidePlacementFailures =
                math.min(report.onScreenGuidePlacementFailures + 1, 99)
            status = "INCONCLUSIVE"
            finalReason = "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE"
        end
    end
    report.status = status == "PASS"
            and "CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED"
        or "INCONCLUSIVE"
    report.reason = finalReason
    report.elapsedSeconds = math.floor(math.max(0, os.clock() - started))
    report.eventReceiptCount = math.min(receiptCount, 99)
    report.eventSessionAssociationProven = false
    report.callbackCausalityProven = false
    report.rawItemIdConfirmed = false
    report.currentPricesVerified = false
    report.priceForTradeVerified = false
    report.marketValueAuthority = false
    report.sourcePublisherFresh = false
    report.serverAttestation = false
    report.serverTradeRevisionProven = false
    report.serverCompletionProven = false
    report.authenticatedOwnedInventory = false
    report.numericSupremeCheckerIdVerified = false
    report.authorizesTrade = false
    report.authorizesAccept = false
    report.mayReportProfit = false
    report.maySendDiscordWebhook = false
    report.tradeOutcome = "UNKNOWN"
    safeJson()
    return state
end

local function stop(reason)
    return finish("INCONCLUSIVE", reason)
end

local function eligibleVisibleSlot(slot, catalogue, registry)
    if type(slot) ~= "table" or type(slot.label) ~= "string" or type(slot.chroma) ~= "boolean" then
        return false
    end
    local label = slot.label:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "):lower()
    if slot.chroma and label:sub(1, 7) ~= "chroma " then
        label = "chroma " .. label
    end
    for key, entry in pairs(registry.entries) do
        local metadata = rawget(catalogue, key)
        if
            type(entry) == "table"
            and type(metadata) == "table"
            and type(entry[1]) == "string"
            and type(entry[2]) == "string"
            and (entry[3] == "Godly" or entry[3] == "Ancient")
            and type(entry[4]) == "boolean"
            and metadata.ItemName == entry[1]
            and metadata.ItemType == entry[2]
            and metadata.Rarity == entry[3]
            and (metadata.Chroma == true) == entry[4]
        then
            local name = entry[1]:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "):lower()
            if entry[4] and name:sub(1, 7) ~= "chroma " then
                name = "chroma " .. name
            end
            if name == label then
                return true
            end
        end
    end
    return false
end

local function run()
    if not LocalPlayer or not PlayerGui or PlayerGui.Parent ~= LocalPlayer then
        return finish("INCONCLUSIVE", "MAIN_CLIENT_GUI_UNAVAILABLE")
    end
    local matches = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if
            player ~= LocalPlayer
            and type(player.Name) == "string"
            and player.Name:lower() == targetName:lower()
            and player.Parent == Players
        then
            matches[#matches + 1] = player
        end
    end
    if #matches ~= 1 then
        return finish("INCONCLUSIVE", "TARGET_NOT_UNIQUE_IN_SERVER")
    end
    target = matches[1]
    report.targetClientBound = true

    local contract = loadPinned("stage9Contract")
    local native = loadPinned("stage9Native")
    local registry = loadPinned("stage83")
    local matcher = loadPinned("stage101")
    local layout = loadPinned("stage100Overlay")
    if
        not contract
        or not native
        or not registry
        or not matcher
        or not layout
        or type(contract.normalize) ~= "function"
        or type(native.new) ~= "function"
        or type(native.capture) ~= "function"
        or type(matcher.inspect) ~= "function"
        or type(layout.choose) ~= "function"
        or type(registry.entries) ~= "table"
        or registry.schema ~= "gingerscope-stage83-public-slug-registry-v1"
        or registry.authorizesTrade ~= false
        or registry.authorizesAccept ~= false
        or registry.currentPricesVerified ~= false
    then
        return finish("INCONCLUSIVE", "READONLY_PINNED_SOURCES_UNAVAILABLE")
    end
    local catalogue
    local catalogueOk = pcall(function()
        local replicated = game:GetService("ReplicatedStorage")
        local database = replicated:FindFirstChild("Database")
        local syncModule = database and database:FindFirstChild("Sync")
        assert(syncModule and syncModule:IsA("ModuleScript"))
        local sync = require(syncModule)
        assert(type(sync) == "table" and type(sync.Weapons) == "table")
        catalogue = sync.Weapons
    end)
    if not catalogue or not catalogueOk or getmetatable(catalogue) ~= nil then
        return finish("INCONCLUSIVE", "CURRENT_CLIENT_WEAPON_METADATA_UNAVAILABLE")
    end
    local workspaceService = game:GetService("Workspace")
    local made, promptPanel = createPanel(layout, PlayerGui, workspaceService)
    if not made then
        return finish("INCONCLUSIVE", "ONSCREEN_GUIDE_PANEL_CREATION_FAILED")
    end
    panel = promptPanel

    local function present(step, body, hint, root)
        currentPrompt = { step = step, body = body, hint = hint }
        local visibleRoots = currentTradeRoots()
        local placementRoot = root
        if not placementRoot and #visibleRoots == 1 then
            placementRoot = visibleRoots[1]
        elseif #visibleRoots > 1 then
            panel:hide()
            report.onScreenGuidePlacementFailures =
                math.min(report.onScreenGuidePlacementFailures + 1, 99)
            return false, "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE"
        end
        local ok, reason = panel:show(step, body, hint, placementRoot, false)
        if not ok then
            report.onScreenGuidePlacementFailures =
                math.min(report.onScreenGuidePlacementFailures + 1, 99)
            return false, reason
        end
        return true
    end

    local function stillLive(expectedRoot)
        if not live() then
            return false, "SESSION_OR_TARGET_CHANGED"
        end
        local root, reason = exactRoot()
        if expectedRoot then
            if root ~= expectedRoot then
                return false, reason == "NO_OPEN_TRADE_ROOT" and "TRADE_GUI_ROOT_CHANGED" or reason
            end
        elseif root then
            return true, root
        elseif reason ~= "NO_OPEN_TRADE_ROOT" then
            return false, reason
        end
        return true, nil
    end

    local function guidedWait(duration, expectedRoot)
        local untilAt = os.clock() + duration
        while os.clock() < untilAt do
            local ok, rootOrReason = stillLive(expectedRoot)
            if not ok then
                return false, rootOrReason
            end
            local visibleRoot = expectedRoot or rootOrReason
            if currentPrompt then
                local shown, reason =
                    present(currentPrompt.step, currentPrompt.body, currentPrompt.hint, visibleRoot)
                if not shown then
                    return false, "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE"
                end
            end
            task.wait(math.min(0.05, math.max(0, untilAt - os.clock())))
        end
        return true
    end

    local function showStep(step, body, hint, root)
        local previousStep = currentPrompt and currentPrompt.step
        local shown, reason = present(step, body, hint, root)
        if not shown then
            return false, reason
        end
        if previousStep ~= step then
            print("[STAGE106] " .. step .. ": " .. body .. " " .. hint)
        end
        currentPrompt = { step = step, body = body, hint = hint }
        return true
    end

    local function makeObserver(root)
        local session = "stage106:" .. tostring(started)
        local capturedRaw = nil
        local proxy = {
            normalize = function(raw, trust)
                capturedRaw = raw
                return contract.normalize(raw, trust)
            end,
        }
        local ok, handle = pcall(native.new, {
            game = game,
            players = Players,
            root = root,
            session = session,
            jobId = jobId,
            partnerUserId = target.UserId,
            localUserId = LocalPlayer.UserId,
            contract = proxy,
            ownInventory = nil,
            opponentInventory = nil,
            marketFresh = function()
                return false
            end,
        })
        if not ok or type(handle) ~= "table" then
            return nil, nil
        end
        local function capture()
            local liveNow, why = stillLive(root)
            if not liveNow then
                return nil, nil, nil, why
            end
            capturedRaw = nil
            local captured, observation, diagnostic = pcall(native.capture, handle)
            local raw = capturedRaw
            if
                not captured
                or type(observation) ~= "table"
                or type(diagnostic) ~= "table"
                or type(raw) ~= "table"
                or observation.tradeOpen ~= true
                or observation.session ~= session
                or observation.quoteSafe ~= false
                or type(observation.ourSig) ~= "string"
                or type(observation.theirSig) ~= "string"
                or observation.ourSig:sub(1, 10) == "unverified"
                or observation.theirSig:sub(1, 10) == "unverified"
                or observation.ourSig == "capture-error"
                or observation.theirSig == "capture-error"
                or type(observation.ourSlots) ~= "number"
                or type(observation.theirSlots) ~= "number"
                or observation.ourSlots < 0
                or observation.ourSlots > 4
                or observation.theirSlots < 0
                or observation.theirSlots > 4
                or raw.tradeOpen ~= true
                or raw.contextOK ~= true
                or raw.session ~= session
                or type(raw.our) ~= "table"
                or type(raw.their) ~= "table"
                or raw.our.complete ~= true
                or raw.their.complete ~= true
                or raw.our.accepted ~= false
                or raw.their.accepted ~= false
                or type(raw.our.slots) ~= "table"
                or type(raw.their.slots) ~= "table"
                or diagnostic.authorizesTrade ~= false
                or diagnostic.authorizesAccept ~= false
            then
                return nil, nil, nil, "ORIGINAL_STAGE9_CAPTURE_UNVERIFIED"
            end
            report.stage9Frames = math.min(report.stage9Frames + 1, 9999)
            return observation, raw, os.clock()
        end
        return { session = session, handle = handle, capture = capture }, session
    end

    local function record(observer, scope)
        local observation, raw, at, reason = observer.capture()
        if not observation then
            return nil, nil, reason
        end
        return {
            raw = raw,
            at = at,
            session = scope.session,
            jobId = jobId,
            root = tradeRoot,
            localPlayer = LocalPlayer,
            partnerPlayer = target,
        },
            observation
    end

    local function isEmpty(observation, raw)
        return observation.ourSlots == 0
            and observation.theirSlots == 0
            and #raw.our.slots == 0
            and #raw.their.slots == 0
            and raw.our.accepted == false
            and raw.their.accepted == false
    end

    local function captureCurrentRemote()
        local replicated = game:GetService("ReplicatedStorage")
        local folder = replicated:FindFirstChild("Trade")
        if not folder then
            return nil
        end
        local ok, desc = pcall(function()
            return folder:GetDescendants()
        end)
        if not ok or type(desc) ~= "table" or #desc > 12000 then
            return nil
        end
        local found, count = nil, 0
        for _, item in ipairs(desc) do
            if item.Name == "UpdateTrade" and item:IsA("RemoteEvent") then
                found = item
                count = count + 1
            end
        end
        return count == 1 and found or nil
    end

    local guideFirst = {
        step = "1 / 3  •  MAIN OPENS TRADE",
        body = "MAIN manually opens an EMPTY trade with the consenting ALT.",
        hint = "NEVER PRESS FINAL ACCEPT.",
    }
    local shown, why = showStep(guideFirst.step, guideFirst.body, guideFirst.hint, nil)
    if not shown then
        return stop("ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE")
    end
    print("[STAGE106] WAIT_FOR_MANUAL_TRADE_WINDOW")
    local deadline = os.clock() + 30
    while live() and os.clock() < deadline do
        local root, rootReason = exactRoot()
        if root then
            tradeRoot = root
            break
        end
        if rootReason ~= "NO_OPEN_TRADE_ROOT" then
            return stop(rootReason)
        end
        local waited, waitReason = guidedWait(0.1, nil)
        if not waited then
            return stop(waitReason)
        end
    end
    if not live() then
        return stop("SESSION_OR_TARGET_CHANGED")
    end
    if not tradeRoot then
        return stop("MANUAL_TRADE_WINDOW_NOT_OBSERVED_WITHIN_30S")
    end
    report.exactPartnerGuiObserved = true

    local observer, session = makeObserver(tradeRoot)
    if not observer then
        return stop("ORIGINAL_STAGE9_OBSERVER_NOT_AVAILABLE")
    end
    local scope = {
        session = session,
        jobId = jobId,
        root = tradeRoot,
        localPlayer = LocalPlayer,
        partnerPlayer = target,
    }
    local first, firstObservation, firstReason = record(observer, scope)
    if not first then
        return stop(firstReason)
    end
    if not isEmpty(firstObservation, first.raw) then
        return stop("TRADE_OFFERS_NOT_BOTH_EMPTY_AT_STEP_ONE")
    end
    local waited, waitReason = guidedWait(0.18, tradeRoot)
    if not waited then
        return stop(waitReason)
    end
    local emptyBaseline, emptyObservation, emptyReason = record(observer, scope)
    if not emptyBaseline then
        return stop(emptyReason)
    end
    if
        not isEmpty(emptyObservation, emptyBaseline.raw)
        or firstObservation.ourSig ~= emptyObservation.ourSig
        or firstObservation.theirSig ~= emptyObservation.theirSig
    then
        return stop("EMPTY_TRADE_BASELINE_NOT_STABLE")
    end
    report.stage9ObserverBound = true

    local guideAlt = {
        step = "2 / 3  •  ALT ADDS ONE",
        body = "ALT manually adds ONE expendable eligible Ancient/Godly/Chroma weapon.",
        hint = "Keep MAIN empty. NEVER PRESS FINAL ACCEPT.",
    }
    shown, why = showStep(guideAlt.step, guideAlt.body, guideAlt.hint, tradeRoot)
    if not shown then
        return stop("ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE")
    end
    print("[STAGE106] READY_ALT_ADD_ONE")
    local altDeadline = os.clock() + 45
    local altStable = nil
    while live() and os.clock() < altDeadline do
        local observed, raw, at, captureReason = observer.capture()
        if not observed then
            return stop(captureReason)
        end
        if observed.ourSlots ~= 0 or #raw.our.slots ~= 0 then
            return stop("MAIN_OFFER_CHANGED_BEFORE_LISTENER")
        end
        if observed.theirSlots > 1 or #raw.their.slots > 1 then
            return stop("ALT_DID_NOT_ADD_EXACTLY_ONE_SLOT")
        end
        if observed.theirSlots == 1 then
            if
                #raw.their.slots ~= 1
                or not eligibleVisibleSlot(raw.their.slots[1], catalogue, registry)
            then
                return stop("ALT_VISIBLE_SLOT_NOT_IN_ELIGIBLE_PUBLIC_CATALOGUE")
            end
            local beforeSignature = observed.theirSig
            waited, waitReason = guidedWait(0.18, tradeRoot)
            if not waited then
                return stop(waitReason)
            end
            local stableObservation, stableRaw, stableAt, stableReason = observer.capture()
            if not stableObservation then
                return stop(stableReason)
            end
            if
                stableObservation.ourSlots ~= 0
                or stableObservation.theirSlots ~= 1
                or stableObservation.ourSig ~= observed.ourSig
                or stableObservation.theirSig ~= beforeSignature
                or #stableRaw.our.slots ~= 0
                or #stableRaw.their.slots ~= 1
                or not eligibleVisibleSlot(stableRaw.their.slots[1], catalogue, registry)
            then
                return stop("ALT_ONLY_GUI_NOT_STABLE")
            end
            altStable = {
                raw = stableRaw,
                at = stableAt,
                session = session,
                jobId = jobId,
                root = tradeRoot,
                localPlayer = LocalPlayer,
                partnerPlayer = target,
                ourSig = stableObservation.ourSig,
                theirSig = stableObservation.theirSig,
            }
            break
        end
        local shownNow, showReason = present(guideAlt.step, guideAlt.body, guideAlt.hint, tradeRoot)
        if not shownNow then
            return stop("ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE")
        end
        task.wait(0.1)
    end
    if not live() then
        return stop("SESSION_OR_TARGET_CHANGED")
    end
    if not altStable then
        return stop("ALT_ONE_SLOT_NOT_OBSERVED_WITHIN_45S")
    end

    local remote = captureCurrentRemote()
    if not remote then
        return stop("UNIQUE_UPDATE_TRADE_REMOTE_UNAVAILABLE")
    end
    local connectOk, newConnection = pcall(function()
        return remote.OnClientEvent:Connect(function(...)
            local pack = table.pack(...)
            local callbackOk = pcall(function()
                if not state.running then
                    return
                end
                receiptCount = receiptCount + 1
                if receiptCount ~= 1 then
                    callbackBad = true
                    callbackReason = "MULTIPLE_OR_UNBOUND_UPDATE_TRADE_CALLBACKS"
                    receipt = nil
                    return
                end
                local current, reason = exactRoot()
                if not live() or current ~= tradeRoot then
                    callbackBad = true
                    if not live() then
                        callbackReason = "SESSION_OR_TARGET_CHANGED"
                    elseif current ~= tradeRoot then
                        callbackReason = "TRADE_GUI_ROOT_CHANGED"
                    else
                        callbackReason = reason
                    end
                    return
                end
                receipt = {
                    packed = pack,
                    at = os.clock(),
                    session = session,
                    jobId = jobId,
                    root = tradeRoot,
                    localPlayer = LocalPlayer,
                    partnerPlayer = target,
                }
            end)
            if not callbackOk then
                callbackBad = true
                callbackReason = "CLIENT_EVENT_RECEIPT_INVALID"
                receipt = nil
            end
        end)
    end)
    if not connectOk or not newConnection or type(newConnection.Disconnect) ~= "function" then
        return stop("READONLY_UPDATE_TRADE_LISTENER_FAILED")
    end
    connection = newConnection

    local before, beforeObservation, beforeReason = record(observer, scope)
    if not before then
        return stop(beforeReason)
    end
    if
        beforeObservation.ourSlots ~= 0
        or beforeObservation.theirSlots ~= 1
        or beforeObservation.ourSig ~= altStable.ourSig
        or beforeObservation.theirSig ~= altStable.theirSig
    then
        return stop("ALT_ONLY_BEFORE_SNAPSHOT_CHANGED")
    end
    if receiptCount ~= 0 or callbackBad then
        return stop(callbackReason or "CALLBACK_OBSERVED_BEFORE_READY_MAIN_ADD_ONE")
    end
    if
        before.raw.our.accepted ~= false
        or before.raw.their.accepted ~= false
        or #before.raw.our.slots ~= 0
        or #before.raw.their.slots ~= 1
    then
        return stop("ALT_ONLY_BEFORE_SNAPSHOT_CHANGED")
    end

    local mainGuide = {
        step = "3 / 3  •  READY_MAIN_ADD_ONE",
        body = "MAIN manually adds ONE eligible expendable Ancient/Godly/Chroma weapon; leave ALT unchanged.",
        hint = "Protected items are blocked. NEVER PRESS FINAL ACCEPT.",
    }
    shown, why = showStep(mainGuide.step, mainGuide.body, mainGuide.hint, tradeRoot)
    if not shown then
        return stop("ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE")
    end
    print("[STAGE106] READY_MAIN_ADD_ONE")

    local mainDeadline = os.clock() + 35
    while live() and os.clock() < mainDeadline do
        if callbackBad or receiptCount > 1 then
            return stop(callbackReason or "MULTIPLE_OR_UNBOUND_UPDATE_TRADE_CALLBACKS")
        end
        local observed, raw, at, captureReason = observer.capture()
        if not observed then
            return stop(captureReason)
        end
        if observed.theirSig ~= beforeObservation.theirSig or #raw.their.slots ~= 1 then
            return stop("ALT_GUI_CHANGED_AFTER_BEFORE")
        end
        if observed.ourSlots > 1 or #raw.our.slots > 1 then
            return stop("MAIN_DID_NOT_ADD_EXACTLY_ONE_SLOT")
        end
        if observed.ourSlots == 1 then
            if receiptCount == 0 then
                return stop("GUI_OFFER_CHANGED_BEFORE_PARTNER_CALLBACK")
            end
            if not receipt or receiptCount ~= 1 then
                return stop(callbackReason or "MULTIPLE_OR_UNBOUND_UPDATE_TRADE_CALLBACKS")
            end
            local after1 = {
                raw = raw,
                at = at,
                session = session,
                jobId = jobId,
                root = tradeRoot,
                localPlayer = LocalPlayer,
                partnerPlayer = target,
            }
            waited, waitReason = guidedWait(0.18, tradeRoot)
            if not waited then
                return stop(waitReason)
            end
            if callbackBad or receiptCount ~= 1 then
                return stop(callbackReason or "MULTIPLE_OR_UNBOUND_UPDATE_TRADE_CALLBACKS")
            end
            local after2, afterObservation, afterReason = record(observer, scope)
            if not after2 then
                return stop(afterReason)
            end
            if
                afterObservation.ourSlots ~= 1
                or afterObservation.theirSlots ~= 1
                or afterObservation.theirSig ~= beforeObservation.theirSig
            then
                return stop("GUI_AFTER_SNAPSHOT_NOT_STABLE")
            end
            local result, private = matcher.inspect({
                scope = scope,
                before = before,
                receipt = receipt,
                after1 = after1,
                after2 = after2,
                eventCount = receiptCount,
            }, catalogue, registry, contract)
            receipt = nil
            if type(result) ~= "table" then
                return stop("STAGE101_RESEARCH_COMPARATOR_FAILED")
            end
            for _, field in ipairs({
                "inputClientEventCount",
                "bothSidesReconciled",
                "clientPerSlotRawKeyCandidateUnique",
                "clientEventGuiQuantityMatched",
                "clientEventGuiVariantMatched",
                "currentClientMetadataMatchedHistoricalPublicRef",
                "sessionClientReferencesConsistent",
                "ourMatchedSlotCount",
                "theirMatchedSlotCount",
                "guiNameOnlySlotCount",
                "guiRawTextSlotCount",
                "guiTwoStableSamples",
                "observedVisibleGuiTransition",
            }) do
                report[field] = result[field]
            end
            if
                result.authorizesTrade ~= false
                or result.authorizesAccept ~= false
                or result.eventSessionAssociationProven ~= false
                or result.callbackCausalityProven ~= false
                or result.rawItemIdConfirmed ~= false
                or result.currentPricesVerified ~= false
                or result.serverCompletionProven ~= false
            then
                return stop("UNEXPECTED_AUTHORITY_ESCALATION_BLOCKED")
            end
            if
                result.status ~= "CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED"
                or type(private) ~= "table"
                or private.clientOnly ~= true
                or private.validForAutomatedTrade ~= false
                or private.validForAutomatedAccept ~= false
                or private.rawKeyServerAuthenticated ~= false
            then
                return stop(result.reason or "STAGE101_CANDIDATE_MATCH_INCONCLUSIVE")
            end
            for _, row in ipairs(private.ours or {}) do
                if row.key == "Gingerscope" then
                    private = nil
                    return stop("PROTECTED_OUTBOUND_ITEM_BLOCKED")
                end
            end
            private = nil
            return finish("PASS", "CLIENT_RAW_KEY_CANDIDATES_ONLY_NO_SIGNED_TRADE_SESSION")
        end
        local refreshed, refreshReason =
            present(mainGuide.step, mainGuide.body, mainGuide.hint, tradeRoot)
        if not refreshed then
            return stop("ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE")
        end
        task.wait(0.1)
    end
    if not live() then
        return stop("SESSION_OR_TARGET_CHANGED")
    end
    return stop(
        receiptCount == 1 and "NO_MATCHING_TWO_SIDED_GUI_SNAPSHOT"
            or "NO_UPDATE_TRADE_CALLBACK_OBSERVED"
    )
end

task.spawn(function()
    local ok = pcall(run)
    if not ok then
        stop("READONLY_RUNTIME_OR_GUI_FAILURE")
    end
end)
return state
