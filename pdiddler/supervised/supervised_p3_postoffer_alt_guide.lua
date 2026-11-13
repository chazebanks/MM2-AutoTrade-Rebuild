-- Strictly CLIENT-only guide for a post-auto-offer ALT add/remove test.
-- It does NOT send trade requests, offer items, accept, decline, or learn.
-- A valid P3/P4 client snapshot and the single original auto placement must
-- both be seen BEFORE "ALT ADD" is shown. Never skip an observed step.
local M={}
local function result(phase,reason,add,remove)
 return {
  phase=phase,reason=reason,
  altAddClientObserved=add,altRemoveClientObserved=remove,
  completedClientSequence=phase=="READY_MANUAL_DECLINE",
  serverCompletionProven=false,authorizesAccept=false,
  authorizesTrade=false,mayUseForStrategyLearning=false,
  mayReportProfit=false,tradeOutcome="UNKNOWN",
 }
end
function M.new()
 local phase="WAIT_AUTO_OFFER"
 local root=nil
 local stableCount=0
 local lastValue=nil
 local startedAt=nil
 local add=false
 local remove=false
 local controller={}
 local function block(why)
  phase="BLOCKED"
  return result(phase,why,add,remove)
 end
 function controller.current()
  return result(phase,"CLIENT_ONLY_NO_SERVER_SETTLEMENT",add,remove)
 end
 function controller.observe(data)
  if phase=="BLOCKED" or phase=="READY_MANUAL_DECLINE" then
   return controller.current()
  end
  if type(data)~="table" or type(data.now)~="number" or
     data.now~=data.now or data.now<0 then return block("CLIENT_CLOCK_OR_DATA_INVALID") end
  if data.status~="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
   if root~=nil then return block("P4_WINDOW_CLOSED_BEFORE_ALT_SEQUENCE") end
   return controller.current()
  end
  if data.clientBound~=true or (type(data.root)~="table" and type(data.root)~="userdata") then
   return block("UNBOUND_OR_MISSING_CLIENT_ROOT")
  end
  local own,their=data.ownSlots,data.theirSlots
  if type(own)~="number" or own~=math.floor(own) or own<0 or own>4 or
     type(their)~="number" or their~=math.floor(their) or their<0 or their>4 then
   return block("UNTRUSTED_PHYSICAL_SLOT_COUNT")
  end
  if phase=="WAIT_AUTO_OFFER" then
   if not data.oneShotComplete then return controller.current() end
   if own~=1 or their~=0 then
    return block("INITIAL_AUTO_OFFER_OR_ALT_BASELINE_UNSAFE")
   end
   root=data.root
   startedAt=data.now
   phase="WAIT_ALT_ADD"
   stableCount=0
   lastValue=nil
   return result(phase,"MAIN_OFFER_ONE_ALT_MUST_ADD",add,remove)
  end
  if root~=data.root then return block("P4_CLIENT_ROOT_REPLACED") end
  if own~=1 then return block("MAIN_OFFER_CHANGED_DURING_ALT_TEST") end
  if data.now<startedAt then return block("CLIENT_CLOCK_ROLLBACK") end
  if data.now-startedAt>60 then return block("ALT_TEST_STEP_TIMEOUT") end
  if their>1 then return block("ALT_OFFER_MULTISLOT_UNEXPECTED") end
  local expected=phase=="WAIT_ALT_ADD" and 1 or 0
  if their~=expected then
   -- A stable baseline before ALT ADD is not a completed ADD.
   stableCount=0
   lastValue=nil
   return controller.current()
  end
  if lastValue~=their then
   lastValue=their
   stableCount=1
   return controller.current()
  end
  stableCount+=1
  if stableCount<2 then return controller.current() end
  startedAt=data.now
  lastValue=nil
  stableCount=0
  if phase=="WAIT_ALT_ADD" then
   add=true
   phase="WAIT_ALT_REMOVE"
   return result(phase,"ALT_ADD_CLIENT_COUNT_OBSERVED_NOW_REMOVE",add,remove)
  end
  if phase=="WAIT_ALT_REMOVE" and add then
   remove=true
   phase="READY_MANUAL_DECLINE"
   return result(phase,"ALT_REMOVE_CLIENT_COUNT_OBSERVED_MANUAL_DECLINE",add,remove)
  end
  return block("INVALID_STATE_TRANSITION")
 end
 function controller.stop()
  if phase~="READY_MANUAL_DECLINE" then phase="BLOCKED" end
  return controller.current()
 end
 return controller
end
return M
