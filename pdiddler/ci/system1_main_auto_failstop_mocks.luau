-- System1 MAIN auto: four real outcomes represented by fake GUI only.
-- No Roblox HTTP/remotes; strict fail-stop, error copy and no Accept policy.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local src=fs.readFile("pdiddler/system1/system1_main_auto_failstop_controller.lua")
local M=luau.load(src,{injectGlobals=true})()
local tests=0
local function eq(a,b,name)
 tests+=1
 assert(a==b,tostring(name)..": "..tostring(a).." != "..tostring(b))
end
local function item(slot,name,q)
 return {physicalSlot=slot,displayCandidate=name,quantity=q or 1,
  chromaCandidate=false,rawItemIdAuthenticated=false}
end
local function snap(ours,theirs)
 return {status="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT",
  ours=ours,theirs=theirs,physicalOwnSlots=#ours,
  physicalTheirSlots=#theirs,partnerExactClientBound=true,
  part3Paused=true,part4TradeVisible=true,requestOriginBound=false,
  authorizesOffer=false,authorizesAccept=false,
  rawItemIdsAuthenticated=false,pricesAuthenticated=false,
  offerRevisionAuthenticated=false,serverCompletionProven=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  tradeOutcome="UNKNOWN"}
end
local function fixture(changes)
 changes=changes or {}
 local state={
  root=nil,epoch=0,ours={},theirs={},running=true,
  copy={},stopCalls=0,endCalls=0,requests={},offers={},remove=0,
  decline=0,clock=0,failOffer=changes.failOffer,
 }
 local api={
  startEpoch=function(round,nonce)
   if changes.rejectEpoch==round then return false,"denied" end
   state.root=nil;state.ours={};state.theirs={}
   state.epoch+=1
   state.requests[#state.requests+1]={round=round,nonce=nonce}
   return true,"epoch-"..tostring(state.epoch)
  end,
  inspect=function(round,epoch)
   if changes.inspectThrows then error("UNTRUSTED_INSPECT_THROW") end
   local status=state.root and snap(state.ours,state.theirs) or nil
   if changes.overrideSnap then status=changes.overrideSnap end
   return {sessionFresh=not changes.staleEpoch,
    exactPartner=not changes.wrongPartner,
    noOtherController=not changes.otherController,
    p3Status=changes.p3Status or "P3_ROTATING",
    root=state.root,snapshot=status}
  end,
  offerApproved=function(round,count,epoch,choiceIndex)
   state.offers[#state.offers+1]={round=round,count=count,choiceIndex=choiceIndex}
   if state.failOffer then return {status="STOPPED",offerAttempts=1} end
   state.ours={}
   for i=1,count do
    state.ours[i]=item(i,"MAIN_"..tostring(choiceIndex+i-1))
   end
   return {status="CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
    offerAttempts=count,clientVisibleAddedSlots=count,
    authorizesAccept=false,serverCompletionProven=false,
    tradeOutcome="UNKNOWN"}
  end,
  removeOwnOne=function(round,root,epoch,allowTheirItem)
   state.remove+=1
   if #state.theirs~=0 and (not allowTheirItem or round~=5) then
    return false
   end
   if changes.failRemoval then return false end
   table.remove(state.ours,#state.ours)
   return true
  end,
  decline=function(round,root,epoch)
   state.decline+=1
   if changes.failDecline then return false end
   state.root=nil
   return true
  end,
  endEpoch=function(round,epoch)
   state.endCalls+=1
   return not changes.failEndEpoch
  end,
  stopAll=function()state.stopCalls+=1;state.running=false end,
  copyReport=function(out)
   state.copy[#state.copy+1]=out
   return true
  end,
 }
 local cfg={explicitFourRoundConsent=true,finalAcceptDisabled=true,
  exactConsentingAlt=true,approvedTwoDistinctOwnedItems=true,
   includeAdaptiveRound=changes.adaptive==true,
   explicitAdaptiveRevisionConsent=changes.adaptive==true,
  requestTimeout=30,altStepTimeout=90,actionTimeout=8}
 local ctrl=M.new(api,cfg)
 local function tick(dt)
  state.clock+=dt or 0.2
  return ctrl.tick(state.clock)
 end
 local function ticks(num)
  local r
  for _=1,num do r=tick() end
  return r
 end
 local function drive()
  local max=250
  for _=1,max do
   local phase=ctrl.status().phase
   if phase=="DONE" or phase=="STOPPED" then break end
   if phase=="WAIT_OPEN" then
    state.root={round=ctrl.status().round}
   elseif phase=="ALT_ADD" then
    local n=ctrl.status().round==4 and 2 or 1
    state.theirs={}
    for i=1,n do state.theirs[i]=item(i,"ALT_"..tostring(i)) end
   elseif phase=="ALT_REVISE" then
     state.theirs={item(1,"ALT_REPLACEMENT")}
    elseif phase=="ALT_CLEAR_FOR_REOFFER" then
     state.theirs={}
    elseif phase=="ALT_READD" then
     state.theirs={item(1,"ALT_NEW_RESPONSE")}
    elseif phase=="ALT_REMOVE_ONE" then
    state.theirs={item(2,"ALT_2")}
   elseif phase=="ALT_REMOVE_ALL" then
    state.theirs={}
   end
   tick()
  end
  return ctrl.status()
 end
 return {state=state,ctrl=ctrl,tick=tick,ticks=ticks,drive=drive,
    cfg=cfg,api=api}
end
do
 local f=fixture()
 local r=f.drive()
 eq(r.status,"CLIENT_TEST_SEQUENCE_COMPLETE","four-round auto MAIN passes")
 eq(r.phase,"DONE","final state")
 eq(r.completedRounds,4,"four windows closed")
 eq(#r.rounds,4,"each window receipt")
 eq(#f.state.requests,4,"four DISTINCT attempted request epochs")
 eq(f.state.requests[1].round,1,"round1 request")
 eq(f.state.requests[2].round,2,"round2 request")
 eq(f.state.requests[3].round,3,"round3 request")
 eq(f.state.requests[4].round,4,"round4 request")
 eq(f.state.requests[1].nonce,1,"P3 epoch nonce1")
 eq(f.state.requests[4].nonce,4,"P3 epoch nonce4")
 eq(r.actions.offersAttempted,3,"MAIN only planned 1+2 eligible items")
 eq(r.actions.offersClientVisible,3,"all 3 GUI-approved item placements")
 eq(#f.state.offers,2,"one offer batch in trade3 and one in trade4")
 eq(f.state.offers[1].count,1,"one item in trade3")
 eq(f.state.offers[2].count,2,"two items in trade4")
 eq(r.actions.removalsAttempted,3,"MAIN removed 1 then 2 items")
 eq(f.state.remove,3,"three one-at-a-time actual remove adapter calls")
 eq(r.actions.declinesAttempted,4,"MAIN automatically declines four")
 eq(f.state.decline,4,"four decline adapter calls")
 eq(r.actions.clientClosedWindows,4,"four observed window closes")
 eq(f.state.endCalls,4,"old P3 session ended each round")
 eq(f.state.stopCalls,1,"final stopAll once")
 eq(#f.state.copy,1,"full final auto report copied automatically")
 eq(f.state.copy[1].phase,"DONE","complete report in clipboard")
 eq(r.authorizesAccept,false,"final Accept impossible")
 eq(r.serverCompletionProven,false,"client close not settlement")
 eq(r.tradeOutcome,"UNKNOWN","no fabricated trade completion")
 eq(r.mayUseForStrategyLearning,false,"not a learned successful trade")
 eq(r.automaticMain,true,"automatic MAIN, ALT guided")
 eq(f.ctrl.tick(f.state.clock+1).phase,"DONE","no second run after completion")
end
-- Every step can fail terminally; receipt includes round + phase + error.
for _,which in ipairs({
 "REJECT_EPOCH","INSPECT_THROW","WRONG_PARTNER","STALE_EPOCH",
 "SECOND_REQUEST","OFFER_DENIED","REMOVE_CLICK_FAILED",
 "AUTO_DECLINE_FAILED","OLD_EPOCH_CANNOT_CLOSE","UNKNOWN_SNAPSHOT",
 "OTHER_CONTROLLER"
}) do
 local ch={}
 if which=="REJECT_EPOCH" then ch.rejectEpoch=1
 elseif which=="INSPECT_THROW" then ch.inspectThrows=true
 elseif which=="WRONG_PARTNER" then ch.wrongPartner=true
 elseif which=="STALE_EPOCH" then ch.staleEpoch=true
 elseif which=="SECOND_REQUEST" then ch.rejectEpoch=2
 elseif which=="OFFER_DENIED" then ch.failOffer=true
 elseif which=="REMOVE_CLICK_FAILED" then ch.failRemoval=true
 elseif which=="AUTO_DECLINE_FAILED" then ch.failDecline=true
 elseif which=="OLD_EPOCH_CANNOT_CLOSE" then ch.failEndEpoch=true
 elseif which=="UNKNOWN_SNAPSHOT" then ch.overrideSnap={status="REJECTED"}
 else ch.otherController=true end
 local f=fixture(ch)
 local r=f.drive()
 eq(r.phase,"STOPPED","terminal stop "..which)
 eq(r.status,"STOPPED","stopped status "..which)
 eq(#f.state.copy,1,"error auto-copied "..which)
 eq(f.state.stopCalls,1,"P3 stopped once "..which)
 eq(f.state.copy[1].reason,r.reason,"exact error recorded "..which)
 eq(f.state.copy[1].round,r.round,"failure round recorded "..which)
 eq(r.authorizesAccept,false,"no Accept even on "..which)
 eq(f.ctrl.tick(f.state.clock+1).status,"STOPPED",
    "never silently resume after "..which)
end
do
 local f=fixture()
 f.tick() -- start epoch
 f.ticks(1)
 local r=f.tick(31)
 eq(r.phase,"STOPPED","timeout before ALT accepted")
 eq(r.reason,"TIMEOUT_WAIT_OPEN","exact action to debug")
 eq(#f.state.copy,1,"timeouts copied")
 eq(r.actions.declinesAttempted,0,"no blind decline without bound root")
 eq(r.actions.offersAttempted,0,"no unsolicited items")
end
do
 local f=fixture()
 f.tick()
 f.state.root={}
 f.tick();f.tick();f.tick() -- enter MAIN_DECLINING for round1
 local r=f.tick(0.2)
 eq(r.phase,"WAIT_CLOSE","MAIN clicked decline on empty")
 eq(r.actions.declinesAttempted,1,"one decline")
 eq(#f.state.copy,0,"no premature failure copy")
end
do
 local f=fixture()
 f.tick()
 f.state.root={}
 f.tick()
 f.state.ours={item(1,"Gingerscope")}
 local r=f.tick()
 eq(r.phase,"STOPPED","protected Gingerscope outbound stops")
 eq(r.reason,"PROTECTED_CLIENT_SNAPSHOT_INVALID","client guard reject")
 eq(#f.state.copy,1,"protected error copied")
end
do
 local f=fixture()
 f.tick()
 f.state.root={}
 f.tick()
 f.state.theirs={item(1,"ALT_UNEXPECTED")}
 local r=f.tick()
 eq(r.phase,"STOPPED","unexpected first offer stops")
 eq(r.reason,"TRADE_NOT_EMPTY_ON_OPEN","not a pass")
end
do
 local f=fixture()
 f.tick()
 f.state.root={}
 f.tick()
 local r=f.ctrl.stop()
 eq(r.phase,"STOPPED","STOP button terminal")
 eq(r.reason,"OPERATOR_STOPPED","manual stop labeled separately")
 eq(#f.state.copy,1,"STOP auto copy")
 eq(f.ctrl.tick(f.state.clock+1).phase,"STOPPED","operator stop terminal")
end
-- Explicit preauthorization required, no default-on runner.
do
 local f=fixture()
 local cfg=f.cfg
 cfg.explicitFourRoundConsent=false
 local c,r=M.new(f.api,cfg)
 eq(c,nil,"no engine without operator-wide consent")
 eq(r.status,"BLOCKED","default closed")
end
-- Adaptive optional fifth test: replace ALT offer while MAIN holds first
-- preapproved item; MAIN withdraws with exact unchanged ALT offer, waits
-- empty, then reoffers a different preapproved item and completes.
do
 local f=fixture({adaptive=true})
 local r=f.drive()
 if r.status~="CLIENT_TEST_SEQUENCE_COMPLETE" then
  print("SYSTEM1_ADAPTIVE_DEBUG",r.phase,r.reason,r.round,r.lastAction,
   r.actions.altRevisionsObserved,r.actions.adaptiveReoffersAttempted,
   r.actions.offersAttempted,r.actions.removalsAttempted)
 end
 eq(r.status,"CLIENT_TEST_SEQUENCE_COMPLETE","adaptive five-round success")
 eq(r.phase,"DONE","adaptive terminal")
 eq(r.maxRounds,5,"five rounds explicitly approved")
 eq(r.adaptiveRoundAuthorized,true,"adaptive consent recorded")
 eq(r.completedRounds,5,"five distinct client trade windows")
 eq(r.reason,"ALL_FIVE_CLIENT_ROUNDS_VERIFIED","fifth-round receipt")
 eq(r.actions.requestsStarted,5,"five fresh epochs")
 eq(r.actions.offersAttempted,5,"3 base + 2 dynamic offers")
 eq(r.actions.offersClientVisible,5,"5 visible MAIN offer slots total")
 eq(r.actions.removalsAttempted,5,"3 base + 2 dynamic removals")
 eq(r.actions.declinesAttempted,5,"five auto declines")
 eq(r.actions.clientClosedWindows,5,"five closed client windows")
 eq(r.actions.altRevisionsObserved,1,"one stable ALT replacement")
 eq(r.actions.adaptiveReoffersAttempted,1,"one different MAIN reoffer")
 eq(#f.state.offers,4,"four outgoing batches")
 eq(f.state.offers[3].choiceIndex,1,"adaptive first preapproved weapon")
 eq(f.state.offers[4].choiceIndex,2,"adaptive SECOND preapproved weapon")
 eq(f.state.endCalls,5,"all P3 epochs closed")
 eq(#f.state.copy,1,"copy after all five")
 eq(f.state.copy[1].authorizesAccept,false,"no final accept permission")
 eq(f.state.copy[1].tradeOutcome,"UNKNOWN","no server settlement")
end
do
 local f=fixture()
 f.cfg.includeAdaptiveRound=true
 f.cfg.explicitAdaptiveRevisionConsent=false
 local c,r=M.new(f.api,f.cfg)
 eq(c,nil,"four-round consent does not authorize fifth round")
 eq(r.status,"BLOCKED","no implicit extended authority")
end

print("SYSTEM1_MAIN_AUTO_FAILSTOP_PURE_PASS",tests)
