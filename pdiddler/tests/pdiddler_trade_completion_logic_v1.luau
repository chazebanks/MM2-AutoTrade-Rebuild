-- Completed-trade completion logic contract v1
-- Pure Luau. Raw owned-key deltas only.

local Completion=require("../pdiddler_trade_completion_logic_v1")

local snap={
    gave={
        {id="Iceblaster",qty=2},
        {id="ChromaLaser",qty=1},
    },
    received={
        {id="VampireAxe",qty=1},
        {id="Iceblaster",qty=1},
    },
}

local d,useful=Completion.expectedDelta(snap)
assert(useful==true)
assert(d.Iceblaster==-1)
assert(d.ChromaLaser==-1)
assert(d.VampireAxe==1)

local before={
    Iceblaster=3,
    ChromaLaser=1,
    VampireAxe=0,
    Unrelated=4,
}
local after={
    Iceblaster=2,
    ChromaLaser=0,
    VampireAxe=1,
    Unrelated=99,
}

local ok,why=Completion.deltaMatches(before,after,d)
assert(ok==true and why=="matched")

after.Iceblaster=3
ok,why=Completion.deltaMatches(before,after,d)
assert(ok==false and why=="delta-mismatch:Iceblaster")

local zero,usefulZero=Completion.expectedDelta({
    gave={{id="Same",qty=1}},
    received={{id="Same",qty=1}},
})
assert(usefulZero==false)
ok,why=Completion.deltaMatches({Same=1},{Same=1},zero)
assert(ok==false and why=="no-useful-delta")

local bad,usefulBad=Completion.expectedDelta({
    gave={{name="MissingRawId",qty=1}},
    received={{id="Good",qty=1}},
})
assert(usefulBad==false)
assert(bad==nil)

assert(Completion.fresh({capturedAt=10},10.5,0.75)==true)
assert(Completion.fresh({capturedAt=10},10.8,0.75)==false)
assert(Completion.fresh(nil,10,1)==false)

print("PASS completed-trade completion logic contract")
