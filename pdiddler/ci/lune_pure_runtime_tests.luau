-- Lune v0.11.1: isolated offline execution of REAL checked-in pure modules.
-- No game, remotes, input simulation, executor, trading or event claims.
local health = require("../core/health")
assert(type(health) == "table" and type(health.run) == "function")

local ready = health.run({ modules = {}, errors = {} })
assert(ready.ok == true)
assert(ready.module == "health" and ready.version == "0.1.0")
local bad, reason = pcall(health.run, nil)
assert(bad == false and type(reason) == "string")
assert(string.find(reason, "missing context", 1, true) ~= nil)
local badNumber = pcall(health.run, 1)
assert(badNumber == false)

local market = require("../../values/mm2values")
assert(type(market) == "table" and type(market.get) == "function")
assert(market.complete == false and market.liveReady == false)
assert(market.authorizesTrade == false and market.authorizesAccept == false)
assert(market.mayReportProfit == false)
assert(market.publisherUpdatedAtUtc == nil)
local gingerscope = market.get("Gingerscope")
assert(type(gingerscope) == "table")
assert(gingerscope.category == "Ancient")
assert(type(gingerscope.value) == "number" and gingerscope.value > 0)
assert(market.get("__NO_SUCH_WEAPON__") == nil)

print("[PASS] Lune executed real health and research-only MM2Values modules")
print("[NOTE] historical market values remain unverified and unusable for trading")
