local modulePath = assert(os.getenv("STAGE106_MODULE"))
local stage9NativePath = assert(os.getenv("STAGE106_STAGE9_NATIVE"))
local stage9ContractPath = assert(os.getenv("STAGE106_STAGE9_CONTRACT"))
local stage83Path = assert(os.getenv("STAGE106_STAGE83_REGISTRY"))
local matcherPath = assert(os.getenv("STAGE106_STAGE101_MATCHER"))
local overlayPath = assert(os.getenv("STAGE106_STAGE100_OVERLAY"))
local nativePrint = print

local function fail(message)
    error("STAGE106 FAIL " .. message, 2)
end

local function eq(actual, expected, message)
    if actual ~= expected then
        fail(
            (message or "value mismatch")
                .. " got="
                .. tostring(actual)
                .. " expected="
                .. tostring(expected)
        )
    end
end

local function source(path)
    local file = assert(io.open(path, "rb"))
    local result = file:read("*a")
    file:close()
    return result
end

local function mockSourceLoader()
    local files = {
        ["p4_native_observer.lua"] = stage9NativePath,
        ["p4_observer_contract.lua"] = stage9ContractPath,
        ["stage83_public_slug_registry.lua"] = stage83Path,
        ["stage101_multiweapon_raw_key_match.lua"] = matcherPath,
        ["stage100_screen_prompt_overlay.lua"] = overlayPath,
    }
    return files
end

local function newSignal(state)
    local signal = { connections = {} }
    function signal:Connect(callback)
        local connection = { Connected = true }
        function connection:Disconnect()
            if self.Connected then
                self.Connected = false
                state.disconnected = state.disconnected + 1
            end
        end
        connection.callback = callback
        self.connections[#self.connections + 1] = connection
        state.connected = state.connected + 1
        return connection
    end
    function signal:Fire(...)
        state.fired = state.fired + 1
        for _, connection in ipairs(self.connections) do
            if connection.Connected then
                state.delivered = state.delivered + 1
                connection.callback(...)
            end
        end
    end
    return signal
end

local function childrenOf(node)
    local children = rawget(node, "_children")
    if not children then
        children = {}
        rawset(node, "_children", children)
    end
    return children
end

local NodeMethods = {}
local Node = {}
Node.__index = function(self, key)
    if key == "Parent" then
        return rawget(self, "_parent")
    end
    if key == "AbsolutePosition" then
        return rawget(self, "_absolutePosition") or { X = 0, Y = 0 }
    end
    if key == "AbsoluteSize" then
        return rawget(self, "_absoluteSize") or { X = 0, Y = 0 }
    end
    return NodeMethods[key] or rawget(self, key)
end
Node.__newindex = function(self, key, value)
    if key == "Parent" then
        local old = rawget(self, "_parent")
        if old then
            local children = childrenOf(old)
            for i = #children, 1, -1 do
                if children[i] == self then
                    table.remove(children, i)
                end
            end
        end
        rawset(self, "_parent", value)
        if value then
            childrenOf(value)[#childrenOf(value) + 1] = self
        end
        return
    end
    rawset(self, key, value)
end

local function newNode(className)
    local node = setmetatable({
        ClassName = className,
        Name = className,
        Visible = true,
        Enabled = true,
        Text = "",
        _children = {},
    }, Node)
    return node
end

function NodeMethods:IsA(className)
    return self.ClassName == className
        or (
            className == "GuiObject"
            and (
                self.ClassName == "Frame"
                or self.ClassName == "TextLabel"
                or self.ClassName == "TextButton"
            )
        )
end

function NodeMethods:FindFirstChild(name, recursive)
    for _, child in ipairs(childrenOf(self)) do
        if child.Name == name then
            return child
        end
    end
    if recursive then
        for _, child in ipairs(childrenOf(self)) do
            local found = child:FindFirstChild(name, true)
            if found then
                return found
            end
        end
    end
    return nil
end

function NodeMethods:FindFirstChildOfClass(className)
    for _, child in ipairs(childrenOf(self)) do
        if child.ClassName == className then
            return child
        end
    end
    return nil
end

function NodeMethods:GetDescendants()
    local result = {}
    local function walk(parent)
        for _, child in ipairs(childrenOf(parent)) do
            result[#result + 1] = child
            walk(child)
        end
    end
    walk(self)
    return result
end

function NodeMethods:GetAttribute(name)
    return self.Attributes and self.Attributes[name]
end

function NodeMethods:Destroy()
    self.Parent = nil
    self.Destroyed = true
end

local function object(className, name, parent)
    local item = newNode(className)
    item.Name = name
    item.Parent = parent
    return item
end

local function textNode(name, text, parent)
    local item = object("TextLabel", name, parent)
    item.Text = text
    return item
end

local function addSlot(side, index, label, quantity, chroma)
    local slots = side:FindFirstChild("Container")
    local slot = object("Frame", "NewItem" .. tostring(index), slots)
    local title = object("Frame", "ItemName", slot)
    textNode("Label", label, title)
    local quantityBox = object("Frame", "Container", slot)
    textNode("Amount", quantity, quantityBox)
    local tags = object("Frame", "Tags", slot)
    if chroma then
        object("Frame", "Chroma", tags)
    end
    return slot
end

local function removeSlots(side)
    local slots = side:FindFirstChild("Container")
    for index = 1, 4 do
        local slot = slots:FindFirstChild("NewItem" .. tostring(index))
        if slot then
            slot:Destroy()
        end
    end
end

local function itemMetadata(registry, key)
    local value = assert(registry.entries[key])
    return {
        ItemName = value[1],
        ItemType = value[2],
        Rarity = value[3],
        Chroma = value[4],
    }
end

local function newWorld(options)
    options = options or {}
    local state = {
        connected = 0,
        disconnected = 0,
        delivered = 0,
        fired = 0,
        now = 0,
        phase = "",
        output = {},
        tradeOpen = false,
        altAdded = false,
        mainAdded = false,
        scenario = options,
        overlayPositions = {},
        registry = assert(loadfile(stage83Path))(),
    }

    local players = newNode("Players")
    local localPlayer = newNode("Player")
    local partner = newNode("Player")
    local playerGui = newNode("PlayerGui")
    localPlayer.Name = "main_account"
    localPlayer.UserId = 1001
    localPlayer.Parent = players
    players.LocalPlayer = localPlayer
    partner.Name = "venossgaming90190"
    partner.UserId = 1002
    partner.Parent = players
    playerGui.Parent = localPlayer

    local function buildTrade()
        local screen = object("ScreenGui", "TradeGUI", playerGui)
        local container = object("Frame", "Container", screen)
        local root = object("Frame", "Trade", container)
        root._absolutePosition = options.tradePosition or { X = 450, Y = 150 }
        root._absoluteSize = options.tradeSize or { X = 360, Y = 360 }
        local ours = object("Frame", "YourOffer", root)
        object("Frame", "Accepted", ours).Visible = false
        object("Frame", "Container", ours)
        local theirs = object("Frame", "TheirOffer", root)
        object("Frame", "Accepted", theirs).Visible = false
        object("Frame", "Container", theirs)
        textNode("Username", "(venossgaming90190)", theirs)
        state.screen = screen
        state.root = root
        state.ours = ours
        state.theirs = theirs
        state.tradeOpen = true
    end

    local remotes = newNode("Folder")
    remotes.Name = "Trade"
    local remote = newNode("RemoteEvent")
    remote.Name = "UpdateTrade"
    remote.OnClientEvent = newSignal(state)
    remote.Parent = remotes
    state.remote = remote

    local replicated = newNode("ReplicatedStorage")
    replicated.Name = "ReplicatedStorage"
    remotes.Parent = replicated
    local database = object("Folder", "Database", replicated)
    local syncModule = object("ModuleScript", "Sync", database)
    local catalogue = {}
    for _, key in ipairs({ "Scythe", "Laser", "Immortal", "ImmortalChroma", "Gingerscope" }) do
        catalogue[key] = itemMetadata(state.registry, key)
    end
    state.catalogue = catalogue
    state.syncModule = syncModule

    local workspace = newNode("Workspace")
    workspace.CurrentCamera = {
        ViewportSize = options.viewport or { X = 1024, Y = 768 },
    }
    if options.noCamera then
        workspace.CurrentCamera = nil
    end
    state.workspace = workspace
    local services = {
        Players = players,
        ReplicatedStorage = replicated,
        Workspace = workspace,
        HttpService = {
            JSONEncode = function(_, value)
                local function encode(input)
                    if type(input) == "boolean" or type(input) == "number" then
                        return tostring(input)
                    end
                    if type(input) == "string" then
                        return '"' .. input:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
                    end
                    if type(input) ~= "table" then
                        return "null"
                    end
                    local out = {}
                    for key, entry in pairs(input) do
                        out[#out + 1] = encode(tostring(key)) .. ":" .. encode(entry)
                    end
                    return "{" .. table.concat(out, ",") .. "}"
                end
                return encode(value)
            end,
        },
    }
    function players:GetPlayers()
        return { localPlayer, partner }
    end
    function players:GetPlayerByUserId(userId)
        if localPlayer.UserId == userId then
            return localPlayer
        end
        if partner.UserId == userId then
            return partner
        end
        return nil
    end
    function replicated:FindFirstChild(name)
        return NodeMethods.FindFirstChild(self, name)
    end
    function syncModule:IsA(className)
        return className == "ModuleScript"
    end

    local env = {
        PDIDDLER_STAGE106_TARGET_USERNAME = "venossgaming90190",
        PDIDDLER_STAGE106_READONLY_ARMED = true,
    }
    local sourceFiles = mockSourceLoader()
    local clock = { now = 0 }
    local function firePacket()
        local altKey = options.altKey or "Scythe"
        local mainKey = options.mainKey or "Laser"
        local altQuantity = options.altQuantity or 1
        local mainQuantity = options.mainQuantity or 1
        local altName = state.registry.entries[altKey][1]
        local mainName = state.registry.entries[mainKey][1]
        local altChroma = state.registry.entries[altKey][4]
        local mainChroma = state.registry.entries[mainKey][4]
        local altText = altQuantity == 1 and "" or "x" .. altQuantity
        local mainText = mainQuantity == 1 and "" or "x" .. mainQuantity
        if not state.altAdded then
            addSlot(state.theirs, 1, altName, altText, altChroma)
        end
        addSlot(state.ours, 1, mainName, mainText, mainChroma)
        state.mainAdded = true
        local localRow = {
            Player = localPlayer,
            Accepted = options.accepted == "main",
            Offer = {
                {
                    options.eventMainKey or mainKey,
                    options.eventMainQuantity or mainQuantity,
                    "Weapons",
                },
            },
        }
        local partnerRow = {
            Player = partner,
            Accepted = options.accepted == "alt",
            Offer = { { altKey, altQuantity, "Weapons" } },
        }
        if options.fullPacket == false then
            localRow.Offer = nil
        end
        local packet = {
            LastOffer = 12,
            Locked = options.locked == true,
            Player1 = options.swapped and partnerRow or localRow,
            Player2 = options.swapped and localRow or partnerRow,
        }
        if options.duplicateCallback then
            remote.OnClientEvent:Fire(packet)
        end
        if options.noCallback or options.delayedCallback then
            state.delayedPacket = packet
            return
        end
        remote.OnClientEvent:Fire(packet)
    end

    _G.getgenv = function()
        return env
    end
    _G.game = {
        PlaceId = 142823291,
        JobId = "current-job",
        GetService = function(_, name)
            return assert(services[name], "unknown service " .. name)
        end,
        HttpGet = function(_, url)
            for marker, path in pairs(sourceFiles) do
                if url:find(marker, 1, true) then
                    return source(path)
                end
            end
            fail("unexpected pinned source URL")
        end,
    }
    _G.Instance = {
        new = function(className)
            local item = newNode(className)
            if className == "TextButton" then
                item.Activated = newSignal({
                    connected = 0,
                    disconnected = 0,
                    fired = 0,
                    delivered = 0,
                })
            end
            if className == "Frame" then
                item.Active = false
            end
            return item
        end,
    }
    _G.Enum = {
        ZIndexBehavior = { Sibling = "Sibling" },
        Font = { GothamBold = "GothamBold", GothamSemibold = "GothamSemibold", Gotham = "Gotham" },
        TextXAlignment = { Left = "Left" },
        TextYAlignment = { Center = "Center", Top = "Top" },
    }
    _G.UDim = {
        new = function(scale, offset)
            return { Scale = scale, Offset = offset }
        end,
    }
    _G.UDim2 = {
        fromOffset = function(x, y)
            return { X = x, Y = y }
        end,
    }
    _G.Color3 = {
        fromRGB = function(r, g, b)
            return { R = r, G = g, B = b }
        end,
    }
    local originalRequire = _G.require
    _G.require = function(module)
        if module == syncModule then
            return { Weapons = catalogue }
        end
        return originalRequire(module)
    end
    _G.os = {
        clock = function()
            return clock.now
        end,
    }
    _G.task = {
        spawn = function(callback)
            callback()
        end,
        wait = function(duration)
            clock.now = clock.now + (duration or 0)
            state.now = clock.now
            if state.mutateNextCapture then
                local label = state.ours
                    :FindFirstChild("Container")
                    :FindFirstChild("NewItem1")
                    :FindFirstChild("ItemName")
                    :FindFirstChild("Label")
                label.Text = "Changed Weapon"
                state.mutateNextCapture = nil
            end
            if state.phase == "OPEN" and not state.tradeOpen then
                buildTrade()
            elseif state.phase == "ALT" and not state.altAdded then
                state.altAdded = true
                local altKey = options.altKey or "Scythe"
                local altQuantity = options.altQuantity or 1
                local altItem = state.registry.entries[altKey]
                addSlot(
                    state.theirs,
                    1,
                    altItem[1],
                    altQuantity == 1 and "" or "x" .. altQuantity,
                    altItem[4]
                )
                remote.OnClientEvent:Fire({
                    LastOffer = 11,
                    Locked = false,
                    Player1 = { Player = localPlayer, Accepted = false, Offer = {} },
                    Player2 = {
                        Player = partner,
                        Accepted = false,
                        Offer = { { altKey, altQuantity, "Weapons" } },
                    },
                })
            elseif state.phase == "MAIN" and not state.mainAdded then
                if options.targetChanges then
                    partner.Parent = nil
                end
                if options.jobChanges then
                    game.JobId = "changed-job"
                end
                if options.rootChanges then
                    state.screen:Destroy()
                    state.tradeOpen = false
                    buildTrade()
                end
                if options.resizeAfterReady then
                    workspace.CurrentCamera.ViewportSize = { X = 1280, Y = 720 }
                    state.root._absolutePosition = options.moveTradeRight and { X = 900, Y = 170 }
                        or { X = 35, Y = 170 }
                elseif options.portraitAfterReady then
                    workspace.CurrentCamera.ViewportSize = { X = 768, Y = 1024 }
                    state.root._absolutePosition = { X = 350, Y = 320 }
                end
                if options.mutateAfterMain then
                    state.mutateNextCapture = true
                end
                firePacket()
            elseif state.phase == "MAIN" and state.mainAdded and state.delayedPacket then
                remote.OnClientEvent:Fire(state.delayedPacket)
                state.delayedPacket = nil
            end
        end,
    }
    _G.print = function(...)
        local message = table.concat({ ... }, " ")
        state.output[#state.output + 1] = message
        if message:find("WAIT_FOR_MANUAL_TRADE_WINDOW", 1, true) then
            state.phase = "OPEN"
        elseif message:find("READY_ALT_ADD_ONE", 1, true) then
            state.phase = "ALT"
        elseif message:find("READY_MAIN_ADD_ONE", 1, true) then
            state.phase = "MAIN"
        end
    end
    _G.warn = _G.print
    _G.setclipboard = function(value)
        state.clipboard = value
    end

    if options.targetMissing then
        partner.Parent = nil
    end
    if options.openImmediately then
        buildTrade()
        state.phase = "ALT"
    end
    local ok, result = pcall(function()
        return assert(loadfile(modulePath))()
    end)
    if not ok then
        fail("wrapper raised unexpectedly: " .. tostring(result))
    end
    state.instance = result
    state.env = env
    local guide = playerGui:FindFirstChild("PDIDDLER_Stage106_ReadOnly_Instructions")
    local frame = guide and guide:FindFirstChild("Instructions")
    state.guide = guide
    state.frame = frame
    if frame and frame.Visible then
        local position, size = frame.Position, frame.Size
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        assert(position and size and viewport, "visible guide has no geometry")
        assert(
            position.X >= 14
                and position.Y >= 72
                and position.X + size.X <= viewport.X - 14
                and position.Y + size.Y <= viewport.Y - 34,
            "guide violates viewport or safe-area margins"
        )
        if state.root and state.tradeOpen then
            local rootPosition, rootSize = state.root.AbsolutePosition, state.root.AbsoluteSize
            assert(
                position.X + size.X <= rootPosition.X - 12
                    or position.X >= rootPosition.X + rootSize.X + 12
                    or position.Y + size.Y <= rootPosition.Y - 12
                    or position.Y >= rootPosition.Y + rootSize.Y + 12,
                "guide overlaps the actual trade bounds or 12px clearance"
            )
        end
        state.geometryChecked = true
    end
    return state
end

local function expectStopped(options, reason, disconnected)
    local state = newWorld(options)
    local report = assert(state.instance.report)
    eq(report.status, "INCONCLUSIVE", report.reason)
    if reason then
        eq(report.reason, reason, "reason")
    end
    eq(state.connected > 0, disconnected, "listener attached")
    if state.connected > 0 then
        eq(state.disconnected, state.connected, "listener disconnected")
    end
    eq(report.authorizesTrade, false)
    eq(report.authorizesAccept, false)
    eq(report.eventSessionAssociationProven, false)
    eq(report.callbackCausalityProven, false)
    eq(report.rawItemIdConfirmed, false)
    eq(report.currentPricesVerified, false)
    eq(report.priceForTradeVerified, false)
    eq(report.serverTradeRevisionProven, false)
    eq(report.serverCompletionProven, false)
    eq(report.mayReportProfit, false)
    eq(report.maySendDiscordWebhook, false)
    eq(report.tradeOutcome, "UNKNOWN")
    return state
end

local function test(name, callback)
    local ok, err = pcall(callback)
    if not ok then
        fail(name .. ": " .. tostring(err))
    end
    print("PASS Stage106 " .. name)
end

local function matcherFourSlots()
    local matcher = assert(loadfile(matcherPath))()
    local contract = assert(loadfile(stage9ContractPath))()
    local registry = assert(loadfile(stage83Path))()
    local scope = {
        jobId = "four-slot-job",
        session = "four-slot-session",
        root = {},
        localPlayer = {},
        partnerPlayer = {},
    }
    local ourKeys = { "Laser", "Darkbringer", "Shark", "Immortal" }
    local theirKeys = { "Scythe", "ImmortalChroma", "Lightbringer", "Celestial" }
    local quantities = { 1, 2, 5, 3 }
    local catalogue = {}
    local function rows(keys)
        local result = {}
        for index, key in ipairs(keys) do
            local public = registry.entries[key]
            catalogue[key] = itemMetadata(registry, key)
            result[index] = {
                slot = index,
                label = public[1],
                amountText = quantities[index] == 1 and "" or "x" .. quantities[index],
                chroma = public[4],
            }
        end
        return result
    end
    local guiOur, guiTheir = rows(ourKeys), rows(theirKeys)
    local function side(slots)
        return { complete = true, accepted = false, slots = slots }
    end
    local function snapshot(at, ours, theirs)
        return {
            at = at,
            jobId = scope.jobId,
            session = scope.session,
            root = scope.root,
            localPlayer = scope.localPlayer,
            partnerPlayer = scope.partnerPlayer,
            raw = {
                tradeOpen = true,
                contextOK = true,
                session = scope.session,
                our = side(ours),
                their = side(theirs),
            },
        }
    end
    local function offers(keys)
        local result = {}
        for index, key in ipairs(keys) do
            result[index] = { key, quantities[index], "Weapons" }
        end
        return result
    end
    local input = {
        scope = scope,
        eventCount = 1,
        before = snapshot(100, {}, guiTheir),
        receipt = {
            at = 100.2,
            jobId = scope.jobId,
            session = scope.session,
            root = scope.root,
            localPlayer = scope.localPlayer,
            partnerPlayer = scope.partnerPlayer,
            packed = {
                n = 1,
                [1] = {
                    LastOffer = 12,
                    Locked = false,
                    Player1 = {
                        Player = scope.partnerPlayer,
                        Accepted = false,
                        Offer = offers(theirKeys),
                    },
                    Player2 = {
                        Player = scope.localPlayer,
                        Accepted = false,
                        Offer = offers(ourKeys),
                    },
                },
            },
        },
        after1 = snapshot(100.3, guiOur, guiTheir),
        after2 = snapshot(100.5, guiOur, guiTheir),
    }
    return matcher, input, catalogue, registry, contract
end

test("positive one packet maps two sides, swapped players, x5 Chroma", function()
    local state = newWorld({
        openImmediately = true,
        swapped = true,
        altKey = "ImmortalChroma",
        altQuantity = 5,
    })
    local report = state.instance.report
    eq(report.status, "CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED", report.reason)
    eq(report.bothSidesReconciled, true)
    eq(report.inputClientEventCount, 1)
    eq(report.ourMatchedSlotCount, 1)
    eq(report.theirMatchedSlotCount, 1)
    eq(report.eventSessionAssociationProven, false)
    eq(report.callbackCausalityProven, false)
    eq(report.rawItemIdConfirmed, false)
    eq(report.currentPricesVerified, false)
    eq(report.serverCompletionProven, false)
    eq(report.authorizesTrade, false)
    eq(report.authorizesAccept, false)
    eq(report.mayReportProfit, false)
    eq(report.maySendDiscordWebhook, false)
    eq(report.tradeOutcome, "UNKNOWN")
    eq(state.connected, 1)
    eq(state.disconnected, 1)
    eq(state.fired, 2, "expected pre-listener ALT and single MAIN packets")
    eq(state.geometryChecked, true, "visible instruction geometry was not checked")
    eq(report.onScreenGuideShown, true)
    eq(report.onScreenGuideFinalShown, true)
    eq(report.onScreenGuideNonOverlappingTrade, true)
    eq(report.onScreenGuidePlacementFailures, 0)
    eq(state.delivered, 1, "pre-listener ALT callback was incorrectly captured")
    eq(state.env.GINGERSCOPE_STAGE106_READONLY_WITNESS, state.instance)
    eq(state.frame.Active, false, "instruction panel must not intercept taps")
    local dismiss = state.frame:FindFirstChild("Dismiss")
    assert(dismiss and dismiss.Active, "final dismiss control missing")
    dismiss.Activated:Fire()
    eq(state.instance.report.authorizesAccept, false)
    local prompts = table.concat(state.output, "\n")
    assert(prompts:find("WAIT_FOR_MANUAL_TRADE_WINDOW", 1, true))
    assert(prompts:find("READY_ALT_ADD_ONE", 1, true))
    assert(prompts:find("READY_MAIN_ADD_ONE", 1, true))
    for _, message in ipairs(state.output) do
        for _, secret in ipairs({ "Scythe", "Laser", "ImmortalChroma", "venossgaming90190" }) do
            if message:find(secret, 1, true) then
                fail("private event data leaked to console")
            end
        end
    end
end)

test(
    "pinned matcher supports four physical slots per side independently of stack counts",
    function()
        local matcher, input, catalogue, registry, contract = matcherFourSlots()
        local report, private = matcher.inspect(input, catalogue, registry, contract)
        eq(report.status, "CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED")
        eq(report.ourMatchedSlotCount, 4)
        eq(report.theirMatchedSlotCount, 4)
        eq(private.ours[3].quantity, 5)
        eq(private.theirs[2].quantity, 2)
        eq(report.authorizesTrade, false)
        eq(report.authorizesAccept, false)
        eq(report.eventSessionAssociationProven, false)
        eq(report.callbackCausalityProven, false)
        eq(report.rawItemIdConfirmed, false)
        eq(report.currentPricesVerified, false)
        eq(report.serverCompletionProven, false)
        eq(report.mayReportProfit, false)
        eq(report.maySendDiscordWebhook, false)
        eq(report.tradeOutcome, "UNKNOWN")
        input.after1.at = 104
        input.after2.at = 104.2
        report, private = matcher.inspect(input, catalogue, registry, contract)
        eq(report.status, "INCONCLUSIVE", "stale event report")
        eq(report.reason, "CLIENT_EVENT_GUI_TIMING_NOT_BOUNDED")
        eq(private, nil)
    end
)

test("duplicate callback fails closed and disconnects", function()
    expectStopped(
        { openImmediately = true, duplicateCallback = true },
        "MULTIPLE_OR_UNBOUND_UPDATE_TRADE_CALLBACKS",
        true
    )
end)

test("late callback after the visible change fails closed", function()
    expectStopped({
        openImmediately = true,
        delayedCallback = true,
    }, "GUI_OFFER_CHANGED_BEFORE_PARTNER_CALLBACK", true)
end)

test("changing GUI after the first stable sample fails closed", function()
    expectStopped({
        openImmediately = true,
        mutateAfterMain = true,
    }, "GUI_AFTER_SNAPSHOT_NOT_STABLE", true)
end)

test("unsafe full-screen trade bounds stop before listener attachment", function()
    expectStopped({
        openImmediately = true,
        tradeSize = { X = 1024, Y = 768 },
        tradePosition = { X = 0, Y = 0 },
    }, "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE", false)
end)

test("viewport resize and trade movement preserve exclusion clearance", function()
    for _, options in ipairs({
        { openImmediately = true, resizeAfterReady = true },
        { openImmediately = true, resizeAfterReady = true, moveTradeRight = true },
        { openImmediately = true, portraitAfterReady = true },
    }) do
        local state = newWorld(options)
        eq(
            state.instance.report.status,
            "CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED"
        )
        eq(state.instance.report.onScreenGuideNonOverlappingTrade, true)
        eq(state.instance.report.onScreenGuidePlacementFailures, 0)
        eq(state.geometryChecked, true)
    end
end)

test("missing camera and original zero-sized trade bounds stop before listener", function()
    expectStopped({ noCamera = true }, "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE", false)
    expectStopped({
        openImmediately = true,
        tradeSize = { X = 0, Y = 0 },
    }, "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE", false)
end)

test("zero callback after visible MAIN change fails closed", function()
    expectStopped(
        { openImmediately = true, noCallback = true },
        "GUI_OFFER_CHANGED_BEFORE_PARTNER_CALLBACK",
        true
    )
end)

test("truncated full packet fails closed", function()
    expectStopped({ openImmediately = true, fullPacket = false }, nil, true)
end)

test("mismatched raw key, quantity or Chroma fails closed", function()
    expectStopped({
        openImmediately = true,
        eventMainKey = "ImmortalChroma",
    }, "OUR_NO_CLIENT_EVENT_RAW_KEY_MATCH_FOR_GUI_SLOT", true)
    expectStopped({
        openImmediately = true,
        eventMainQuantity = 2,
    }, "OUR_NO_CLIENT_EVENT_RAW_KEY_MATCH_FOR_GUI_SLOT", true)
    expectStopped({
        openImmediately = true,
        mainKey = "ImmortalChroma",
        eventMainKey = "Immortal",
    }, "OUR_NO_CLIENT_EVENT_RAW_KEY_MATCH_FOR_GUI_SLOT", true)
end)

test("locked or accepted packet fails closed", function()
    expectStopped({ openImmediately = true, locked = true }, nil, true)
    expectStopped({ openImmediately = true, accepted = "alt" }, nil, true)
end)

test("changed target, JobId or GUI root fails closed", function()
    expectStopped(
        { openImmediately = true, targetChanges = true },
        "SESSION_OR_TARGET_CHANGED",
        true
    )
    expectStopped({ openImmediately = true, jobChanges = true }, "SESSION_OR_TARGET_CHANGED", true)
    expectStopped({ openImmediately = true, rootChanges = true }, "TRADE_GUI_ROOT_CHANGED", true)
end)

test("exact target absence never attaches listener", function()
    expectStopped({ targetMissing = true }, "TARGET_NOT_UNIQUE_IN_SERVER", false)
end)

test("protected outbound Gingerscope blocks candidate", function()
    expectStopped({
        openImmediately = true,
        mainKey = "Gingerscope",
    }, "PROTECTED_OUTBOUND_ITEM_BLOCKED", true)
end)

test("unsafe initial prompt placement aborts before listener", function()
    expectStopped({
        viewport = { X = 280, Y = 240 },
    }, "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE", false)
end)

test("one-shot cannot be retried in same JobId", function()
    local state = newWorld({ openImmediately = true })
    local prior = state.instance
    local second = assert(loadfile(modulePath))()
    eq(second, prior)
    eq(state.connected, 1)
end)

nativePrint("STAGE106_READONLY_WITNESS_PASS")
