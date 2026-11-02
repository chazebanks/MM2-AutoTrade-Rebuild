-- Completed-trade webhook payload contract v1
-- Pure Luau. No Roblox services, no HTTP.

local Payload=require("../pdiddler_trade_webhook_payload_v1")

local snap={
    id="trade-42",
    traderName="ExampleTrader",
    gave={
        {
            name="Iceblaster",qty=2,page="godly",id="Iceblaster",
            mm2Value=35,supremeValue=33,demand=1,stability="Stable",
            liquidity=-2,confidence=true,rawTotal=70,protectedTotal=70,
        },
    },
    received={
        {
            name="Vampire's Axe",qty=1,page="ancient",id="VampireAxe",
            mm2Value=1375,supremeValue=1425,demand=6,stability="Stable",
            liquidity=1,confidence=true,rawTotal=1375,protectedTotal=1375,
        },
        {
            name="Rare Filler",qty=1,page="ineligible",id="RareFiller",
            mm2Value=0,supremeValue=nil,demand=nil,stability=nil,
            liquidity=nil,confidence=false,rawTotal=0,protectedTotal=0,
        },
    },
    giveRaw=70,
    receiveRaw=1375,
    giveProtected=70,
    receiveProtected=1375,
    rawGain=1305,
    protectedGain=1305,
}

local payload=Payload.build(snap,"server-complete")
assert(type(payload)=="table")
assert(payload.username=="MM2 Auto Trade")
assert(type(payload.embeds)=="table" and type(payload.embeds[1])=="table")

local e=payload.embeds[1]
assert(e.title=="✅ MM2 Trade Completed")
assert(e.description:find("ExampleTrader",1,true))

local fields={}
for _,f in ipairs(e.fields or {}) do fields[f.name]=f.value end

assert(fields["We traded"]:find("Iceblaster x2",1,true))
assert(fields["We traded"]:find("MM2 35",1,true))
assert(fields["We traded"]:find("Supreme 33",1,true))
assert(fields["We traded"]:find("Demand 1/10",1,true))
assert(fields["We traded"]:find("Liquidity -2.00",1,true))

assert(fields["They traded"]:find("Vampire's Axe x1",1,true))
assert(fields["They traded"]:find("Demand 6/10",1,true))
assert(fields["They traded"]:find("Liquidity +1.00",1,true))
assert(fields["They traded"]:find("Rare Filler x1",1,true))
assert(fields["They traded"]:find("Demand N/A",1,true))
assert(fields["They traded"]:find("Liquidity N/A",1,true))

assert(fields["Trade value"]:find("We: 70",1,true))
assert(fields["Trade value"]:find("Them: 1375",1,true))
assert(fields["Gain"]:find("+1305",1,true))
assert(fields["Gain"]:find("Protected +1305",1,true))

assert(e.footer.text:find("server-complete",1,true))
assert(payload.allowed_mentions and payload.allowed_mentions.parse)
assert(#payload.allowed_mentions.parse==0)

print("PASS completed-trade webhook payload contract")
