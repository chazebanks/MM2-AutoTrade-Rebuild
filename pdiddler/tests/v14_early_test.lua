local E=dofile((arg and arg[1]) or 'pdiddler/pdiddler4_early_counter_policy_v4_MEASURED_APPEAL.lua')
local function plan(id,v,d)
 return {ok=true,key=id,units=1,rawTotal=v,rawProfit=101-v,givenExitScore=d,givenRisk=0,
 picks={{page='godly',id=id,qty=1,value=v,demand=d,stability='Stable',cat='Weapons',type='Knife'}}}
end
local current={rawTotal=7,counts={['godly:A']=1},unresolved={},market={confidence=true,rawTotal=7,exitScore=1,riskPoints=0}}
local theirs={rawTotal=101,unresolved={},market={confidence=true,rawTotal=101,exitScore=1,riskPoints=0}}
local action,candidate=E.choose({},'T',current,theirs,{plan('B',20,1),plan('C',38,1)},
 {earlyRemaining=31.6,accepted=false,localAccepted=false})
assert(action=='keep' and candidate==nil,'tied appeal spent early budget without a market improvement')
print('PASS tied appeal preserves early budget for deliberate late negotiation')
local action2,candidate2=E.choose({},'T',current,theirs,{plan('B',20,3),plan('C',38,3)},
 {earlyRemaining=31.6,accepted=false,localAccepted=false})
assert(action2=='counter' and candidate2.rawTotal==20)
print('PASS comparable genuine demand improvement chooses lower cost')
local action3=E.choose({},'T',current,theirs,{plan('B',20,3)},
 {earlyRemaining=31.6,accepted=true,localAccepted=false})
assert(action3=='hold');print('PASS opponent Accepted still freezes voluntary early changes')
