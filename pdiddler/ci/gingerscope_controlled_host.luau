-- A controlled host for the real read-only P1 through P4 components.
-- Service, clock, inventory, request outcome and GUI dependencies are in memory.
-- Only normalized invented stock and observations cross into the Python suite.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local system2 = "pdiddler/system2/"
local supervised = "pdiddler/supervised/"
local catalogBytes = fs.readFile(system2 .. "supreme_only_189_research_catalog_2026_11_25_publication_nov23.json")
local catalogHash = "3f0996b9ac20f3c4689519e1faf65e83796bce8b2d6afe6ad4d2e705ffca525e"
local replayAt, replayEpoch = "2026-11-25T07:52:05Z", 1795593125
assert(serde.hash("sha256", catalogBytes) == catalogHash, "controlled Supreme archive changed")
local catalog = serde.decode("json", catalogBytes)

local readiness = {}
local function stage(name)
    table.insert(readiness, name)
end

local guiClasses = {Frame = true, TextLabel = true, TextButton = true, ImageLabel = true}
local function node(class, name, parent)
    local object = {
        ClassName = class, Name = name, Parent = parent, Visible = true, Enabled = true,
        Text = "", Attributes = {}, children = {},
    }
    if parent then parent.children[name] = object end
    function object:IsA(kind)
        return kind == class or (kind == "GuiObject" and guiClasses[class] == true)
    end
    function object:FindFirstChild(key, recursive)
        if self.children[key] then return self.children[key] end
        if recursive then
            for _, child in pairs(self.children) do
                local found = child:FindFirstChild(key, true)
                if found then return found end
            end
        end
    end
    function object:GetDescendants()
        local descendants = {}
        local function collect(root)
            for _, child in pairs(root.children) do
                table.insert(descendants, child)
                collect(child)
            end
        end
        collect(self)
        return descendants
    end
    function object:GetAttribute(key)
        return self.Attributes[key]
    end
    return object
end

local gui = node("PlayerGui", "ControlledGui")
local players = {}
local main = {Name = "FixtureMainOnly", UserId = 1, Parent = players}
local partner = {Name = "FixturePartnerOnly", UserId = 2, Parent = players}
function main:FindFirstChildOfClass(kind)
    if kind == "PlayerGui" then return gui end
end
function players:GetPlayerByUserId(id)
    if id == partner.UserId and partner.Parent == self then return partner end
end
function players:FindFirstChild(name)
    if name == partner.Name and partner.Parent == self then return partner end
end
players.LocalPlayer = main

local services = {
    Players = players, CoreGui = node("Folder", "ControlledCoreGui"),
    ReplicatedStorage = node("Folder", "NoRemotes"),
    HttpService = {JSONDecode = function(_, bytes) return serde.decode("json", bytes) end},
    GuiService = {}, VirtualInputManager = {},
}
local game = {PlaceId = 142823291, JobId = "CONTROLLED_FIXTURE_JOB"}
function game:GetService(name)
    return assert(services[name], "controlled host requested an unsupported service")
end
local monotonic = 0
local function advance(seconds)
    monotonic += seconds
    assert(monotonic < 38, "controlled startup exceeded the synthetic clock bound")
end
local environment = {
    game = game, os = {clock = function() return monotonic end},
    task = {wait = advance}, print = function() end, warn = function() end,
    assert = assert, error = error, ipairs = ipairs, pairs = pairs, next = next,
    bit32 = bit32, math = math, pcall = pcall, select = select, string = string, table = table,
    tonumber = tonumber, tostring = tostring, type = type,
}
local function module(path)
    return luau.load(fs.readFile(path), {environment = environment, injectGlobals = false})()
end

local health = module("pdiddler/core/health.lua").run({modules = {}, errors = {}})
assert(health.ok and health.module == "health", "controlled P1 health failed")
stage("HEALTH_READY")
assert(module("pdiddler/pdiddler2.lua").run() == true, "controlled Part 2 readiness failed")
stage("PART2_READY")

local screen = node("ScreenGui", "TradeGUI", gui)
screen.Enabled = false
local root = node("Frame", "Trade", node("Frame", "Container", screen))
local function side(name)
    local box = node("Frame", name, root)
    node("Frame", "Accepted", box).Visible = false
    return box, node("Frame", "Container", box)
end
local _, ourSlots = side("YourOffer")
local theirSide, theirSlots = side("TheirOffer")
node("TextLabel", "Username", theirSide).Text = "(" .. partner.Name .. ")"
local function slot(sideSlots)
    local frame = node("Frame", "NewItem1", sideSlots)
    local label = node("TextLabel", "Label", node("Frame", "ItemName", frame))
    node("TextLabel", "Amount", node("Frame", "Container", frame)).Text = ""
    return frame, label
end
local ourSlot, ourLabel = slot(ourSlots)
local theirSlot, theirLabel = slot(theirSlots)

local ownFixture = {Fang = 2, Harvester = 1, FangChroma = 1, Gingerscope = 1}
local partnerFixture = {Gemstone = 1, Plasmabeam = 1, Iceblaster = 1}
local altFixture = {OrangeSeer = 1}
local rows, sync = {}, {Weapons = {}}
for _, row in ipairs(catalog.rows) do
    rows[row.rawGameKeyCandidate] = row
end
for _, key in ipairs({"Fang", "Harvester", "FangChroma", "Gingerscope", "Gemstone", "Plasmabeam"}) do
    local row = assert(rows[key], "controlled item left the reviewed Supreme archive")
    sync.Weapons[key] = {
        ItemName = row.officialName,
        ItemType = row.category == "ancient" and "Gun" or "Knife",
        Rarity = row.category == "ancient" and "Ancient" or "Godly",
        Chroma = row.category == "chroma",
    }
end
local function updateSlot(frame, label, key)
    frame.Attributes.ItemId = key
    label.Text = rows[key].officialName
end
updateSlot(ourSlot, ourLabel, "Fang")
updateSlot(theirSlot, theirLabel, "Gemstone")

local function inventory()
    local seen, items, total = {}, {}, 0
    for rawId, quantity in pairs(ownFixture) do
        local row = rows[rawId]
        total += quantity
        table.insert(seen, rawId .. "x" .. tostring(quantity))
        table.insert(items, {
            cat = "Weapons", id = rawId, qty = quantity, page = row.category,
            type = sync.Weapons[rawId].ItemType, name = row.officialName,
        })
    end
    table.sort(seen)
    return {seen = seen, items = items, fingerprint = table.concat(seen, "|"),
            rawOwned = total, unmapped = 0, badQty = 0}
end
local scanner = {
    isWhitelisted = function(id) return id == partner.UserId end,
    getRecord = function(id)
        if id == partner.UserId then return {state = "whitelist", player = partner} end
    end,
    getWhitelist = function() return {partner} end,
    hasPendingWork = function() return false end,
    getOwnInventory = inventory,
    resolveOfferEntry = function() error("controlled host only calls protected observation methods") end,
}
local paused, armed, stopped = false, false, false
local outgoing = {
    session = 1, state = {processed = {}},
    isPaused = function() return paused end,
    isArmed = function() return armed end,
    resume = function()
        if screen.Enabled then return false, "CONTROLLED_GUI_OPEN" end
        paused = false
        return true
    end,
    stop = function() stopped = true; armed = false end,
}
local outgoingFactory = {run = function(observedScanner, options)
    assert(observedScanner == scanner and options.requiresExplicitStart and not options.readyCheck(),
           "observation must attach before the controlled outbound double can be armed")
    outgoing.arm = function()
        assert(options.readyCheck(), "controlled P3 gate not ready")
        armed = true
        return true
    end
    return outgoing
end}
local function ready() return not stopped end
local context = {
    getJobId = function() return game.JobId end,
    getP3Session = function() return outgoing.session end,
    onScreenSafe = ready, watchdogReady = ready, noOtherTransactionOwner = ready, readyCheck = ready,
}
local io = module(supervised .. "pdiddler4_tradeio_supervised_v2.lua").new(scanner, {})
local supervisor = assert(module(supervised .. "supervised_p3_startup_supervisor.lua").new(
    scanner, outgoingFactory, module(supervised .. "supervised_real_p3_rotation_handoff.lua"),
    module(supervised .. "supervised_p3_p4_handoff.lua"), io, players, main, context
))
assert(supervisor.status().status == "P3_SUPERVISOR_PREPARED_NOT_ARMED")
assert(supervisor.arm({}) == false, "mock P3 must preserve explicit start gating")
stage("P3_OBSERVER_READY")
-- This is permission only for the in-memory outgoing factory above.
assert(supervisor.arm({
    explicitUserAuthorization = true, allowRealP3RequestRotation = true, finalAcceptMustRemainManual = true,
}))
assert(supervisor.poll().status == "P3_ROTATING")
screen.Enabled, paused = true, true
outgoing.state.processed[partner.UserId] = "trade-open"
assert(supervisor.poll().status == "P4_TWO_SIDED_CLIENT_SNAPSHOT", "controlled P3-to-P4 handoff failed")
stage("P4_BOUND")
local lexicalScope = {
    jobId = game.JobId, session = "p3stage119:1", root = root, localPlayer = main, partnerPlayer = partner,
}
local lease = assert(module(system2 .. "native_c9_original_p3_protected_host_adapter.lua").new({
    supervisor = supervisor, game = game, players = players, io = io,
    readOriginalHostBoundScope = function() return lexicalScope end,
    getJobId = context.getJobId, getP3Session = context.getP3Session, isOriginalHostRunning = ready,
}))
local captureModule = module(system2 .. "native_market_offer_client_capture.lua")
local capture = assert(captureModule.new({
    game = game, players = players, scope = lease.scope, isBoundSession = lease.isBoundSession,
}))
local strategy = assert(module(system2 .. "native_supreme_only_protected_c3p4_adapter_nov25.lua").new({
    hostHandle = lease, game = game, players = players, sync = sync, scannerApi = scanner,
    consentedToReadOnlyInventoryRpc = true, captureAdapter = captureModule,
    supremeCore = module(system2 .. "native_supreme_only_bilateral_research_nov25.lua"),
    sourceBytes = catalogBytes, sha256 = module(system2 .. "native_sha256_rfc6234_readonly.lua").hex,
    utcNow = function() return replayEpoch end,
    monoNow = function() advance(0.001); return monotonic end,
}))

local sessionId = "controlled-host-trade"
local events, evidence = {}, {}
local function event(kind, revision)
    local sequence = #events + 1
    local value = {
        sequence = sequence, revision = revision, kind = kind,
        event_id = "controlled-host-" .. tostring(sequence), session_id = sessionId,
    }
    table.insert(events, value)
    return value
end
local function publisherKey(rawId)
    local row = assert(rows[rawId], "controlled identity must match the reviewed Supreme archive")
    return row.category .. ":" .. row.officialItemId
end
local function positionMap(positions)
    local result = {}
    for rawId, quantity in pairs(positions) do
        result[publisherKey(rawId)] = quantity
    end
    return result
end
local function observedTerms(slots)
    local raw, canonical = {}, {}
    for _, item in ipairs(slots) do
        local id = assert(item.rawId, "controlled slot was not identified by the P4 capture")
        local quantity = item.amountText == "" and 1 or tonumber(item.amountText:match("^[xX](%d+)$"))
        assert(quantity == 1, "this controlled lifecycle only uses singleton slots")
        table.insert(raw, {id = id, quantity = quantity})
        canonical[publisherKey(id)] = quantity
    end
    return raw, canonical
end
local function observe(kind, revision)
    local frame = capture.capture()
    assert(frame.doubleReadStable and frame.clientOnly, "controlled P4 frame not stable")
    local rawGive, give = observedTerms(frame.ourSlots)
    local rawReceive, receive = observedTerms(frame.theirSlots)
    local preview = strategy:preview({{
        kind = "HYPOTHETICAL_RESEARCH_ONLY", valueSource = "SUPREME_ONLY",
        give = rawGive, receive = rawReceive,
    }})
    assert(preview.status == "SUPREME_ONLY_PROTECTED_C3_P4_SHADOW_OBSERVED", "controlled Supreme preview blocked")
    for _, flag in ipairs({
        "authorizesTrade", "authorizesOffer", "authorizesAccept", "mayReportProfit",
        "maySendDiscordWebhook", "mayUseForStrategyLearning", "realPlayerAcceptanceOrSettlementProven",
    }) do
        assert(preview[flag] == false, "controlled preview must deny live and settlement authority")
    end
    local change = event(kind, revision)
    change.give, change.receive = give, receive
    local values = preview.hypotheticalAlternatives[1]
    table.insert(evidence, {
        revision = revision, physical_give_slots = #frame.ourSlots, physical_receive_slots = #frame.theirSlots,
        outgoing_listed = values.outgoingSupremeListedValue, incoming_listed = values.incomingSupremeListedValue,
        listed_delta = values.supremeListedGain,
    })
end

event("PARTNER_REQUEST_ACCEPTED", 0)
observe("OFFER_OBSERVED", 1)
updateSlot(theirSlot, theirLabel, "Plasmabeam")
observe("PARTNER_OFFER_REVISION", 2)
assert(supervisor.resumeAfterClose() == false, "controlled P3 resumed while P4 was visible")
screen.Enabled = false
assert(supervisor.resumeAfterClose() and not paused, "controlled P3 did not resume after local closure")
stage("P3_RESUMED")
assert(not lease.isBoundSession() and capture.capture().status == "BLOCKED", "controlled lease survived local closure")
stage("LEASE_REVOKED")
assert(supervisor.stop() and stopped and not armed, "controlled host stop failed")
stage("STOPPED")

-- The protected adapter verifies this scanner's own census before and after its
-- GUI reads. The other two stocks are explicit scenario inputs.
local own = {}
for _, item in ipairs(inventory().items) do
    own[item.id] = item.qty
end
print(serde.encode("json", {
    schema = "gingerscope-controlled-host-v1", evidence_class = "SYNTHETIC_LUNE_OBSERVATION",
    catalog_sha256 = catalogHash, replay_at = replayAt, live_authority = false, readiness = readiness,
    session = {
        sessionId = sessionId, accounts = {main = positionMap(own), alt = positionMap(altFixture)},
        counterpartyStock = positionMap(partnerFixture), events = events,
    },
    offer_evidence = evidence,
}))
