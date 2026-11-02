-- Completed-trade telemetry snapshot contract v1
-- Pure Luau. Ensures webhook data reuses Part 4 resolved identities + market logic.

local Telemetry=require("../pdiddler_trade_telemetry_v1")
local Market=require("../pdiddler4_market_logic_v1_TEST")

local profiles={
    ["godly:481"]={
        page="godly",id="481",name="Iceblaster",
        mm2Value=35,supremeValue=33,demand=1,stability="Stable",
        profiled=true,verified=true,
    },
    ["ancient:VampireAxe"]={
        page="ancient",id="VampireAxe",name="Vampire's Axe",
        mm2Value=1375,supremeValue=1425,demand=6,stability="Stable",
        profiled=true,verified=true,
    },
}

local profile={
    get=function(page,id)
        return profiles[tostring(page)..":"..tostring(id)]
    end,
}

local ourEval={
    slots=1,rawTotal=70,protectedTotal=70,signature="our-sig",
    unresolved={},
    resolved={{
        id="481",page="godly",name="Iceblaster",
        rawValue=35,qty=2,rawSubtotal=70,ineligible=false,
    }},
}

local theirEval={
    slots=2,rawTotal=1375,protectedTotal=1375,signature="their-sig",
    unresolved={},
    resolved={
        {
            id="VampireAxe",page="ancient",name="Vampire's Axe",
            rawValue=1375,qty=1,rawSubtotal=1375,ineligible=false,
        },
        {
            id="RareFiller",page="ineligible",name="Rare Filler",
            rawValue=0,qty=1,rawSubtotal=0,ineligible=true,
        },
    },
}

local decision={
    ok=true,
    rawProfit=1305,
    protectedProfit=1305,
    requiredProfit=15,
    kind="NORMAL",
    mode="profit",
}

local snap=Telemetry.build({
    tradeId="p4:99:abc",
    traderName="ExampleTrader",
    traderUserId=99,
    ourEval=ourEval,
    theirEval=theirEval,
    decision=decision,
    marketProfile=profile,
    marketLogic=Market,
})

assert(snap.id=="p4:99:abc")
assert(snap.traderName=="ExampleTrader")
assert(snap.traderUserId==99)
assert(snap.ourSignature=="our-sig")
assert(snap.theirSignature=="their-sig")
assert(snap.giveRaw==70 and snap.receiveRaw==1375)
assert(snap.rawGain==1305)
assert(snap.protectedGain==1305)
assert(snap.requiredProfit==15)
assert(snap.kind=="NORMAL" and snap.mode=="profit")

assert(#snap.gave==1)
assert(snap.gave[1].name=="Iceblaster")
assert(snap.gave[1].qty==2)
assert(snap.gave[1].mm2Value==35)
assert(snap.gave[1].supremeValue==33)
assert(snap.gave[1].demand==1)
assert(snap.gave[1].stability=="Stable")
assert(snap.gave[1].liquidity==-2)
assert(snap.gave[1].confidence==true)

assert(#snap.received==2)
assert(snap.received[1].name=="Vampire's Axe")
assert(snap.received[1].demand==6)
assert(snap.received[1].liquidity==1)

local filler=snap.received[2]
assert(filler.ineligible==true)
assert(filler.mm2Value==0)
assert(filler.supremeValue==nil)
assert(filler.demand==nil)
assert(filler.liquidity==nil)
assert(filler.confidence==false)

print("PASS completed-trade telemetry snapshot contract")
