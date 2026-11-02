-- Part 4.5 Discord trade-report regression
-- Proves canonical checkerId lookup, tracked gain, liquidity presentation,
-- ineligible handling, and post-inventory totals.

local profile=require("../pdiddler_market_profile_2026-11-02_v1_VALIDATED")
local market=require("../pdiddler4_market_logic_v1_TEST")
local Report=require("../pdiddler4_5_trade_report_v1")

local candidate={
    tradeId="fixture-trade-1",
    partnerName="TradePartner",
    gave={
        {
            page="godly",
            id="Iceblaster",       -- real/raw MM2 owned key can be a name
            checkerId="481",       -- canonical market identity
            name="Iceblaster",
            qty=1,
            rawValue=35,
            ineligible=false,
        },
        {
            page="ineligible",
            id="RareKnife",
            checkerId=nil,
            name="Rare Knife",
            qty=1,
            rawValue=0,
            ineligible=true,
        },
    },
    received={
        {
            page="ancient",
            id="Emberscythe",
            checkerId="1027",
            name="Emberscythe",
            qty=1,
            rawValue=300,
            ineligible=false,
        },
    },
    preInventory={
        total=1000,
        rawOwned=20,
        unmapped=0,
        unpriced=0,
        badQty=0,
        fingerprint="before",
        items={
            {page="godly",id="Iceblaster",checkerId="481",name="Iceblaster",qty=1,value=35},
            {page="ancient",id="Emberscythe",checkerId="1027",name="Emberscythe",qty=1,value=300},
        },
    },
}

local report=Report.build(candidate,nil,profile,market)

assert(report.partnerName=="TradePartner")
assert(report.tradeId=="fixture-trade-1")

assert(report.gave.mm2Total==35,"ineligible item must not be silently counted as zero-value market item")
assert(report.received.mm2Total==300)
assert(report.gainMM2==265)
assert(report.inventoryAfter.expectedMM2==1265)

local ice=report.gave.items[1]
assert(ice.name=="Iceblaster")
assert(ice.marketId=="481","report must use canonical checkerId, not raw owned key")
assert(ice.mm2Unit==35 and ice.supremeUnit==33)
assert(ice.demand==1)
assert(type(ice.liquidityScore)=="number")
assert(type(ice.liquidityLabel)=="string" and ice.liquidityLabel~="")
assert(ice.stability=="Stable")

local rare=report.gave.items[2]
assert(rare.tracked==false)
assert(rare.mm2Unit==nil)
assert(rare.demand==nil)
assert(rare.liquidityScore==nil)

local ember=report.received.items[1]
assert(ember.marketId=="1027")
assert(ember.mm2Unit==300 and ember.supremeUnit==375)
assert(ember.demand==5)
assert(ember.stability=="Fluctuating")

local post={
    total=1265,
    rawOwned=20,
    unmapped=0,
    unpriced=0,
    badQty=0,
    fingerprint="after",
    items={
        {page="ancient",id="Emberscythe",checkerId="1027",name="Emberscythe",qty=2,value=300},
        {page="godly",id="Iceblaster",checkerId="481",name="Iceblaster",qty=0,value=35},
    },
}

report=Report.build(candidate,post,profile,market)
assert(report.inventoryAfter.verified==true)
assert(report.inventoryAfter.mm2Total==1265)
assert(report.inventoryAfter.expectedMM2==1265)
assert(report.inventoryAfter.deltaMismatch==false)

local payload=Report.discordPayload(report)
assert(type(payload)=="table" and type(payload.embeds)=="table" and payload.embeds[1])
local embed=payload.embeds[1]
assert(embed.title=="MM2 Trade Completed")
assert(type(embed.fields)=="table")
assert(#embed.fields>=4)

local names={}
for _,field in ipairs(embed.fields) do names[field.name]=true end
assert(names["You Traded"])
assert(names["You Received"])
assert(names["Value Gained"])
assert(names["Inventory After"])

local encodedText=""
for _,field in ipairs(embed.fields) do
    encodedText=encodedText..tostring(field.name)..tostring(field.value)
end
assert(encodedText:find("Demand",1,true))
assert(encodedText:find("Liquidity",1,true))
assert(encodedText:find("Iceblaster",1,true))
assert(encodedText:find("Emberscythe",1,true))

print("PASS Part 4.5 Discord trade report")
