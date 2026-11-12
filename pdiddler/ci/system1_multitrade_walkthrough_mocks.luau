local fs=require("@lune/fs")
local luau=require("@lune/luau")
local src=fs.readFile("pdiddler/system1/system1_multitrade_client_walkthrough.lua")
local walk=luau.load(src,{injectGlobals=true})()
local tests=0
local function eq(a,b,tag)
 tests+=1;assert(a==b,tostring(tag)..": "..tostring(a).." != "..tostring(b))
end
local function item(index,label,qty,chroma)
 return {physicalSlot=index,displayCandidate=label,
  quantity=qty or 1,chromaCandidate=chroma or false,
  rawItemIdAuthenticated=false}
end
local function snap(own,other)
 own=own or {};other=other or {}
 return {status="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT",
  ours=own,theirs=other,physicalOwnSlots=#own,physicalTheirSlots=#other,
  partnerExactClientBound=true,part3Paused=true,part4TradeVisible=true,
  requestOriginBound=false,rawItemIdsAuthenticated=false,
  pricesAuthenticated=false,offerRevisionAuthenticated=false,
  authorizesOffer=false,authorizesAccept=false,
  serverCompletionProven=false,mayReportProfit=false,
  maySendDiscordWebhook=false,tradeOutcome="UNKNOWN"}
end
local function fixture()
 local w=walk.new({maxRounds=4,maxWaitSeconds=90})
 local clock=0
 local function tick(root,own,their,override)
  clock+=0.2
  local ev={now=clock,root=root,sameJob=true,
    exactPartner=true,competingController=false}
  if root then ev.snapshot=snap(own,their) end
  if override then for k,v in pairs(override)do ev[k]=v end end
  return w.tick(ev)
 end
 local function twice(root,own,their)
  tick(root,own,their)
  return tick(root,own,their)
 end
 return w,tick,twice
end
do
 local w,tick,twice=fixture()
 local start=w.status()
 eq(start.phase,"WAIT_OPEN","initial wait for ALT request")
 eq(start.round,1,"round 1 begins")
 eq(start.authorizesOffer,false,"no scripted offer rights")
 eq(start.authorizesAccept,false,"never automatic final Accept")
 eq(start.manualConsentOnly,true,"manual client proof only")
 eq(start.p3RequestOriginAuthenticated,false,"no fake P3 origin")
 eq(start.tradeOutcome,"UNKNOWN","no settlement assertion")
 eq(start.canNext,false,"no premature next")

 local a={}
 eq(twice(a,{},{}).phase,"R1_CLOSE","round1 empty trade ready to decline")
 eq(tick(nil).phase,"REVIEW","round1 manually closed")
 eq(w.status().passedRounds,1,"round1 passed")
 eq(w.status().completedRounds,1,"round1 is recorded")
 eq(w.status().rounds[1].clientWindowClosed,true,"actual client close recorded")
 eq(w.next(),true,"round2 explicitly NEXT")
 eq(w.status().round,2,"round2 starts")
 eq(w.status().phase,"WAIT_OPEN","must open a NEW trade")
 local b={}
 eq(twice(b,{},{}).phase,"R2_ALT_ADD","round2 alt instructions")
 eq(twice(b,{}, {item(1,"ALT_1")}).phase,"R2_ALT_REMOVE","round2 alt ADD stable")
 eq(twice(b,{},{}).phase,"R2_CLOSE","round2 alt REMOVE stable")
 eq(tick(nil).phase,"REVIEW","round2 manually closed")
 eq(w.status().passedRounds,2,"round2 passed")
 eq(w.next(),true,"advance round3")
 local c={}
 eq(twice(c,{},{}).phase,"R3_MAIN_ADD","round3 main offer instruction")
 eq(twice(c,{item(1,"MAIN_ONE")},{}).phase,"R3_ALT_ADD","one main visible")
 eq(twice(c,{item(1,"MAIN_ONE")},{item(1,"ALT_ONE")}).phase,
   "R3_ALT_REMOVE","two-sided GUI observed")
 eq(twice(c,{item(1,"MAIN_ONE")},{}).phase,
   "R3_MAIN_REMOVE","ALT ABA returns to empty")
 eq(twice(c,{},{}).phase,"R3_CLOSE","MAIN cleared")
 eq(tick(nil).phase,"REVIEW","round3 closed")
 eq(w.status().passedRounds,3,"3 rounds passed")
 eq(w.next(),true,"advance round4")
 local d={}
 eq(twice(d,{},{}).phase,"R4_MAIN_TWO","4-slot exercise begins")
 local m={item(1,"MAIN_A"),item(2,"MAIN_B")}
 local t={item(1,"ALT_A"),item(2,"ALT_B")}
 eq(twice(d,m,{}).phase,"R4_ALT_TWO","two distinct own physical slots")
 eq(twice(d,m,t).phase,"R4_ALT_ONE","two distinct ALT physical slots")
 eq(twice(d,m,{item(2,"ALT_B")}).phase,"R4_ALT_EMPTY","ALT removed first item")
 eq(twice(d,m,{}).phase,"R4_MAIN_EMPTY","ALT removed both")
 eq(twice(d,{},{}).phase,"R4_CLOSE","MAIN removed both")
 eq(tick(nil).phase,"REVIEW","round4 closed")
 eq(w.status().passedRounds,4,"all 4 passes")
 eq(w.status().observedStepTransitions,11,"eleven witnessed item/offer phase transitions")
 eq(w.next(),true,"explicit finish after reviewed fourth")
 eq(w.status().phase,"DONE","full multi-trade test complete")
 eq(w.status().finished,true,"marked completed")
 eq(w.status().completedRounds,4,"four actual client trade windows")
 eq(w.status().openedTradeWindows,4,"four distinct trade opens")
 eq(w.status().authorizesTrade,false,"neither end-to-end nor settled trade authority")
 eq(w.status().mayUseForStrategyLearning,false,"never feed fake learning records")
 eq(w.next(),false,"no duplicate finished review")
end
-- Early close records an INCOMPLETE round rather than pretending success;
-- the user may choose NEXT only after the old trade window really closed.
do
 local w,tick,twice=fixture()
 local first={}
 eq(twice(first,{},{}).phase,"R1_CLOSE","first round set")
 tick(nil);w.next()
 local b={}
 eq(twice(b,{},{}).phase,"R2_ALT_ADD","second started")
 eq(tick(nil).phase,"REVIEW","premature close ends round as failed")
 eq(w.status().failedRounds,1,"close early is not a pass")
 eq(w.status().rounds[2].result,"INCOMPLETE","honest round label")
 eq(w.next(),true,"other rounds can proceed after evidence reviewed")
 eq(w.status().round,3,"resume with distinct new round")
end
-- Unexpected ALT mutation while MAIN is supposed to offer is a failed
-- round that requires manual close before proceeding.
do
 local w,tick,twice=fixture()
 local a={};twice(a,{},{});tick(nil);w.next()
 local b={};twice(b,{},{});twice(b,{}, {item(1,"ALT_X")})
 twice(b,{},{});tick(nil);w.next()
 local c={};twice(c,{},{})
 local r=tick(c,{}, {item(1,"ALT_FORBIDDEN")})
 eq(r.phase,"WAIT_CLOSE_AFTER_FAIL","wrong side mutation quarantines round")
 eq(r.reason,"UNREQUESTED_OTHER_SIDE_MUTATION","precise static reason")
 eq(r.canNext,false,"cannot move until old GUI closes")
 tick(nil)
 eq(w.status().failedRounds,1,"only failure counted once")
 eq(w.status().rounds[3].result,"INCOMPLETE","not a passed trade")
end
for _,problem in ipairs({
 {key="sameJob",bad=false},
 {key="exactPartner",bad=false},
 {key="competingController",bad=true},
}) do
 local w,tick=fixture()
 local o={};local r=tick(o,{}, {},{[problem.key]=problem.bad})
 eq(r.phase,"BLOCKED","global block on "..problem.key)
 eq(r.stopped,true,"terminal block")
 eq(w.next(),false,"cannot next after unsafe "..problem.key)
end
do
 local w,tick=fixture()
 local a={};tick(a,{}, {})
 local b={}
 eq(tick(b,{},{}).reason,"TRADE_ROOT_CHANGED_DURING_ROUND","wrong root blocks")
end
for _,mutation in ipairs({"ACCEPTED","GUN","BAD_QUANTITY","BAD_SLOTS","NO_PRICE_FLAGS","BAD_CHROMA"}) do
 local w,tick=fixture()
 local a={}
 local s=snap({}, {})
 if mutation=="ACCEPTED" then s.authorizesAccept=true
 elseif mutation=="GUN" then
  s.ours={item(1,"Gingerscope")};s.physicalOwnSlots=1
 elseif mutation=="BAD_QUANTITY" then
  s.theirs={item(1,"ALT_WEAPON",0)};s.physicalTheirSlots=1
 elseif mutation=="BAD_SLOTS" then s.physicalOwnSlots=3
 elseif mutation=="NO_PRICE_FLAGS" then s.pricesAuthenticated=true
 else
  s.ours={item(1,"MAIN",1,"yes")};s.physicalOwnSlots=1
 end
 local r=tick(a,{}, {},{snapshot=s})
 eq(r.phase,"BLOCKED","reject untrusted snapshot "..mutation)
 eq(r.reason,"PROTECTED_CLIENT_SNAPSHOT_REJECTED","no ungrounded promotion "..mutation)
end
do
 local w,tick,twice=fixture()
 local a={};twice(a,{},{})
 eq(w.status().phase,"R1_CLOSE","baseline")
 local r=tick(a,{}, {},{now=-1})
 eq(r.phase,"BLOCKED","nonmonotonic clock blocks")
end
do
 local w,tick,twice=fixture()
 local a={};twice(a,{},{})
 eq(w.stop().stopped,true,"STOP is terminal")
 eq(w.status().reason,"OPERATOR_STOPPED","clear sanitized stop")
 eq(tick(nil).stopped,true,"no fake completed round after STOP")
end
print("SYSTEM1_MULTITRADE_PURE_PASS",tests)
