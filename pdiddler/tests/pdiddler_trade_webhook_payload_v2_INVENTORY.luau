-- Completed-trade webhook payload contract v2
-- Pure Luau. No Roblox services, no HTTP.

local Payload=require("../pdiddler_trade_webhook_payload_v2_INVENTORY")

local snap={
    id="p4w:7:12345:999999",
    traderName="ExampleTrader",
    gave={{
        name="Plasmabeam",qty=1,page="godly",id="Plasmabeam",
        mm2Value=20,supremeValue=18,demand=1,stability="Stable",
        liquidity=-2,rawTotal=20,protectedTotal=20,
    }},
    received={{
        name="Darkbringer",qty=1,page="godly",id="Darkbringer",
        mm2Value=35,supremeValue=33,demand=1,stability="Stable",
        liquidity=-2,rawTotal=35,protectedTotal=35,
    }},
    giveRaw=20,
    receiveRaw=35,
    giveProtected=20,
    receiveProtected=35,
    rawGain=15,
    protectedGain=15,
    trackedInventoryTotal=4876,
    trackedInventoryVerification="verified-stable-delta-verified",
    trackedInventoryUnmapped=0,
    trackedInventoryUnpriced=0,
    trackedInventoryBadQty=0,
}

local payload=Payload.build(snap,"server-complete")
assert(type(payload)=="table")
assert(type(payload.embeds)=="table" and type(payload.embeds[1])=="table")

local e=payload.embeds[1]
local fields={}
for _,f in ipairs(e.fields or {}) do
    fields[f.name]=f.value
end

assert(fields["We traded"]:find("Plasmabeam x1",1,true))
assert(fields["They traded"]:find("Darkbringer x1",1,true))
assert(fields["Gain"]:find("Raw +15",1,true))
assert(fields["Tracked inventory after"]:find("4876",1,true))
assert(fields["Tracked inventory after"]:find("verified-stable-delta-verified",1,true))
assert(fields["Trade ID"]:find("p4w:7:12345:999999",1,true))
assert(e.footer.text:find("server-complete",1,true))

local unavailable=Payload.build({
    id="trade-unavailable",
    traderName="ExampleTrader",
    gave={},
    received={},
    trackedInventoryVerification="unavailable:timeout",
},"server-complete")

local f2={}
for _,f in ipairs(unavailable.embeds[1].fields or {}) do
    f2[f.name]=f.value
end
assert(f2["Tracked inventory after"]:find("Unavailable",1,true))
assert(f2["Tracked inventory after"]:find("unavailable:timeout",1,true))

print("PASS completed-trade webhook payload v2 inventory contract")
