-- Research-only deterministic experiments. Pass an exact PR14 checkout as arg1.
-- texlua research-notes/tools/compare_current_trader_v11.lua /path/to/PR14
-- Uses the preserved Nov 3 profile AS OF its retrieval, not current executable prices.
local root=assert(arg[1],'PR14 checkout root required')
local P=dofile(root..'/pdiddler/pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua')
local E=dofile(root..'/pdiddler/pdiddler4_early_counter_policy_v2_BOUNDED_VALUE.lua')
local recorded=dofile(root..'/pdiddler/pdiddler_supreme_snapshot_2026_11_03_ISSUE4.lua')
local S={};for k,v in pairs(recorded) do S[k]=v end
S.isFresh=function() return recorded.isFresh(recorded.observedAtEpoch+1) end
local function item(name,qty)
 for _,r in pairs(S.profiles) do
  if r.name==name then
   -- Native type does not affect these economic comparisons. Knife is a legal fixture type.
   return {page=r.page,id=r.id,checkerId=r.id,name=r.name,value=r.supremeValue,
    qty=qty or 1,cat='Weapons',type='Knife'}
  end
 end
 error('missing profile item '..name)
end
local function inventory(items) return {items=items,unmapped=0,unpriced=0,badQty=0} end
local function bundle(items,side) return P.bundleAssessment(items,side or 'ours',S) end
local function plans(items,theirs) return P.buildPlans(inventory(items),bundle(theirs,'theirs'),S,P) end
local function eval(items)
 local m=bundle(items);local counts={}
 for _,x in ipairs(items) do counts[x.page..':'..x.id]=(counts[x.page..':'..x.id] or 0)+x.qty end
 return {rawTotal=m.rawTotal,market=m,counts=counts,unresolved={}}
end
local function names(plan)
 local a={};for _,x in ipairs(plan.picks) do a[#a+1]=x.name..' x'..x.qty end
 return table.concat(a,' + ')
end
local function printcase(label,...) print('\n'..label,... ) end
-- 1. Strict 60% quote creates a discontinuity, with no permitted path to the other safe quote.
do
 local own={item('Icecream'),item('Green Luger')};local their={item('Flowerwood')}
 local candidates=plans(own,their)
 local quote,reason=P.selectInitialOffer(candidates,235)
 local late,lateReason=P.selectLateConcession(candidates,quote.rawTotal,1,235)
 assert(quote.rawTotal==23 and not late)
 local without=plans({own[1]},their)
 local fallback,fallbackReason=P.selectInitialOffer(without,235)
 assert(fallback.rawTotal==145 and fallback.rawProfit==90)
 printcase('QUOTE GAP: own Icecream145 + Green Luger23; receive Flowerwood235',quote.rawTotal,names(quote),reason,lateReason)
 print('Remove only Green Luger23:',fallback.rawTotal,names(fallback),fallbackReason)
end
-- 2. Distinct exact offers with equal economic facts replenish the early allowance.
do
 local own={item('Boneblade'),item('Jinglegun'),item('Plasmabeam'),item('Laser'),item('Green Luger'),item('Chroma Laser'),item('Ornament')}
 local variants={
  {item('Chroma Swirly Gun'),item('Darkbringer'),item('Iceblaster')},
  {item('Chroma Swirly Gun'),item('Candleflame'),item('Iceblaster')},
  {item('Chroma Swirly Gun'),item('Elderwood Revolver'),item('Iceblaster')},
 }
 local current=eval({own[1]});local state={};local expected={38,54,65}
 printcase('EQUAL-ECONOMICS EDITS: receive101, demand1, Stable every time; start give7')
 for i,theirItems in ipairs(variants) do
  local t=eval(theirItems);local ps=plans(own,theirItems)
  local signature='35+'..theirItems[2].id..'33+Iceblaster33'
  local action,plan,metadata=E.choose(state,signature,current,t,ps,{accepted=false,localAccepted=false})
  assert(action=='counter' and plan.rawTotal==expected[i])
  print(i,names(plan),'give',plan.rawTotal,'profit',plan.rawProfit,'per-generation budget',metadata.budget)
  current=eval(plan.picks)
 end
 print('Total concession from unchanged101 economics:',current.rawTotal-7,'(not one 40-cap trade allowance)')
end
-- 3. Numeric eligibility ignores incoming downside/status and portfolio shape.
do
 local ours=bundle({item('Beachy')});local theirs=bundle({item('Embersickle')},'theirs')
 local decision=P.tradeDecision(ours,theirs)
 assert(decision.ok and decision.rawProfit==15 and theirs.riskPoints==1)
 printcase('PUBLISHED-RANGE SCENARIO: Beachy75 -> Embersickle90',decision.ok,decision.rawProfit,'received risk',theirs.riskPoints)
 print('Research Nov3 published lower85 makes scenario gain10. This is not an executable bid.')
 local downgraded=P.tradeDecision(bundle({item('Icepiercer')}),bundle({item('Ornament',3)},'theirs'))
 assert(downgraded.ok and downgraded.rawProfit==35 and downgraded.qualityGain==-2)
 print('Icepiercer160/D3 -> 3 Ornament195/D1:',downgraded.ok,downgraded.rawProfit,downgraded.qualityGain)
 print('If original inventory also has Chroma Darkbringer65/D1, >=D3 held value changes160 ->0.')
end
-- 4. DP drops equal given-stat alternatives before post-trade concentration can be compared.
do
 local own={item('Darkbringer'),item('Iceblaster',3)};local their={item('Ornament')}
 local candidates=plans(own,their)
 assert(#candidates==1 and #candidates[1].picks==1 and candidates[1].picks[1].name=='Darkbringer')
 local selected=P.selectInitialOffer(candidates,65)
 local hhiSelected=(99*99+65*65)/(164*164)
 local hhiAlternative=(33*33+66*66+65*65)/(164*164)
 printcase('EQUAL-STATS DP PRUNING: Darkbringer33 + Iceblaster33 x3 -> receive Ornament65',#candidates,names(selected))
 print('Post-inventory HHI selected / give one Iceblaster instead:',hhiSelected,hhiAlternative)
 print('Both give33, D1, Stable, 1 copy and yield+32; alternate is absent from candidate list.')
end
-- 5. A small positive trade is intentionally impossible under the absolute+15 constraint.
do
 local candidates=plans({item('Orange Seer')},{item('Boneblade')})
 assert(#candidates==0)
 printcase('ABSOLUTE FLOOR: Orange Seer2 -> Boneblade7 +5',#candidates,'safe plans under mandated+15')
end
-- 6. Synthetic consistency check: unweighted unstable-copy ratio can invert value exposure.
do
 local high={ok=true,key='90%-unstable',rawTotal=100,rawProfit=100,units=3,givenExitScore=3,givenRisk=1/3}
 local low={ok=true,key='10%-unstable',rawTotal=100,rawProfit=100,units=2,givenExitScore=3,givenRisk=1/2}
 -- high means unstable90+stable5+stable5; low means unstable10+stable90.
 -- These are supplied planner summaries, not assertions that such market items are offered.
 local selected=P.selectLateConcession({high,low},90,1,200)
 assert(selected==high)
 printcase('SYNTHETIC RISK METRIC: same give100/profit100/demand3',selected.key,'selected before 10%-unstable two-copy candidate')
end
print('\nAll six deterministic strategy experiments passed. No acceptance probabilities or completed returns are assumed.')
