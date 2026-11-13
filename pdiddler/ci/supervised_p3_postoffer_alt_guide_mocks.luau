-- Actual Lune/Luau property-style tests for exact passive ALT guidance.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local mod=luau.load(fs.readFile(
 "pdiddler/supervised/supervised_p3_postoffer_alt_guide.lua"),
 {injectGlobals=true})()
local count=0
local function eq(a,b,why)
 count+=1;assert(a==b,tostring(why)..": "..tostring(a).." != "..tostring(b))
end
local function fixture()
 local state=mod.new()
 local root={}
 local t=0
 local function update(own,their,options)
  options=options or {}
  t+=(options.advance or 0.2)
  return state.observe({
   now=options.time or t,
   status=options.status or "P4_TWO_SIDED_CLIENT_SNAPSHOT",
   clientBound=options.bound~=false,
   root=options.root or root,
   oneShotComplete=options.done~=false,
   ownSlots=own,theirSlots=their,
  })
 end
 return state,update,root
end
do
 local gate,u=fixture()
 eq(gate.current().phase,"WAIT_AUTO_OFFER","must wait for actual original auto offer")
 eq(u(0,0,{done=false}).phase,"WAIT_AUTO_OFFER","no early ALT stage")
 eq(u(1,0).phase,"WAIT_ALT_ADD","only after known own one item + ALT zero")
 eq(u(1,0).phase,"WAIT_ALT_ADD","ALT untouched cannot skip")
 eq(u(1,1).phase,"WAIT_ALT_ADD","first add snapshot not yet confirmed")
 eq(u(1,1).phase,"WAIT_ALT_REMOVE","second ALT 1-slot sample advances to REMOVE")
 eq(gate.current().altAddClientObserved,true,"add client witnessed")
 eq(u(1,1).phase,"WAIT_ALT_REMOVE","ALT must remove before final stage")
 eq(u(1,0).phase,"WAIT_ALT_REMOVE","first remove sample not enough")
 eq(u(1,0).phase,"READY_MANUAL_DECLINE","after second remove sample: MAIN decline")
 eq(gate.current().altRemoveClientObserved,true,"remove client witnessed")
 eq(gate.current().completedClientSequence,true,"client-only sequence complete")
 eq(gate.current().serverCompletionProven,false,"not server settlement")
 eq(gate.current().authorizesAccept,false,"no automatic final accept")
 eq(gate.current().mayUseForStrategyLearning,false,"no learning")
end
do
 local gate,u=fixture()
 u(1,0);u(1,1);eq(u(1,0).phase,"WAIT_ALT_ADD","flicker reset prevents premature ADD")
 eq(u(1,1).phase,"WAIT_ALT_ADD","one new sample not enough")
 eq(u(1,1).phase,"WAIT_ALT_REMOVE","two consecutive visible ALT add")
 eq(gate.current().altRemoveClientObserved,false,"remove not yet performed")
end
do
 local gate,u,root=fixture()
 u(1,0)
 eq(u(1,0,{root={}}).reason,"P4_CLIENT_ROOT_REPLACED","bound root change fails closed")
 eq(gate.current().phase,"BLOCKED","cannot revive old root")
 eq(u(1,1,{root=root}).phase,"BLOCKED","old root not revived")
end
do
 local gate,u=fixture()
 u(1,0)
 eq(u(0,0).reason,"MAIN_OFFER_CHANGED_DURING_ALT_TEST","own offer removed")
 eq(gate.current().altAddClientObserved,false,"no fake add after loss")
end
do
 local gate,u=fixture()
 u(1,0)
 eq(u(1,2).reason,"ALT_OFFER_MULTISLOT_UNEXPECTED","extra ALT item unsafe")
 eq(gate.current().phase,"BLOCKED","quarantine multislots")
end
do
 local gate,u=fixture()
 u(1,0)
 eq(u(1,0,{status="P3_ROTATING"}).reason,"P4_WINDOW_CLOSED_BEFORE_ALT_SEQUENCE","closed client before add")
 eq(gate.current().phase,"BLOCKED","cannot later claim remove")
end
do
 local gate,u=fixture()
 eq(u(1,1).reason,"INITIAL_AUTO_OFFER_OR_ALT_BASELINE_UNSAFE","ALT was already offering")
 eq(gate.current().phase,"BLOCKED","must capture empty baseline")
end
do
 local gate,u=fixture()
 eq(u(1,0,{bound=false}).reason,"UNBOUND_OR_MISSING_CLIENT_ROOT","no unbound transition")
 eq(gate.current().phase,"BLOCKED","no self certified client bound")
end
do
 local gate,u=fixture()
 eq(u(2,0).reason,"INITIAL_AUTO_OFFER_OR_ALT_BASELINE_UNSAFE","two own slots not acceptable")
end
do
 local gate,u=fixture()
 eq(u(1,0,{done=false}).phase,"WAIT_AUTO_OFFER","can't advance before prior one item")
end
do
 local gate,u=fixture()
 u(1,0)
 eq(u(1,0,{advance=61}).reason,"ALT_TEST_STEP_TIMEOUT","bounded manual step")
end
do
 local gate,u=fixture()
 u(1,0);u(1,1)
 eq(gate.stop().phase,"BLOCKED","operator stop without add/remove incomplete")
 eq(gate.current().completedClientSequence,false,"cannot count stop as pass")
end
do
 local gate,u=fixture()
 u(1,0);u(1,1);u(1,1);u(1,0);u(1,0)
 eq(gate.stop().phase,"READY_MANUAL_DECLINE","terminal client witness retained after stop")
 eq(gate.current().tradeOutcome,"UNKNOWN","terminal client PASS not settled")
end
do
 local gate,u=fixture()
 eq(gate.current().altAddClientObserved,false,"no guessed ALT input")
 eq(gate.current().altRemoveClientObserved,false,"no guessed ALT removal")
 eq(gate.current().authorizesTrade,false,"no trade action")
end
print("P3_ALT_GUIDE_PASS",count)
