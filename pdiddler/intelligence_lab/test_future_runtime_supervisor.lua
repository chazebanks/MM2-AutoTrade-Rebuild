local M=assert(dofile(arg[1]))
local time=1000000
local s=assert(M.new(time))
local function step(kind,fields,advance)
 time=time+(advance or 0)
 local e={kind=kind,epoch=s.epoch}
 for k,v in pairs(fields or {})do e[k]=v end
 local n,err=M.step(s,e,time)
 assert(type(n)=="table",tostring(err))
 assert(n.authorizesTrade==false and n.authorizesAccept==false)
 assert(n.mayRecordCompletedTrade==false and n.mayReportProfit==false)
 assert(n.serverCompletionProven==false and n.tradeOutcome=="UNKNOWN")
 s=n
 return n
end
local function eq(x,y,label) assert(x==y,(label or "").." want="..tostring(y).." actual="..tostring(x)) end
eq(s.phase,"WAIT_WORLD","new")
step("SCAN_FINISHED",{verified=true})
eq(s.phase,"WAIT_WORLD","scan before world")
step("WORLD_READY",{jobId="JOB-A"})
eq(s.phase,"WAIT_UI_STABLE")
step("UI_SNAPSHOT",{jobId="JOB-A",tradeUiReady=false,fingerprint="FP1"})
eq(s.reason,"UI_NOT_STABLE")
step("UI_SNAPSHOT",{jobId="JOB-A",tradeUiReady=true,fingerprint="FP1"})
eq(s.reason,"UI_STABILITY_TIMER_STARTED")
step("UI_SNAPSHOT",{jobId="JOB-A",tradeUiReady=true,fingerprint="FP1"},1499)
eq(s.phase,"WAIT_UI_STABLE","not yet 1500ms")
step("UI_SNAPSHOT",{jobId="JOB-A",tradeUiReady=true,fingerprint="FP1"},1)
eq(s.phase,"SCANNING","stable gate")
step("SCAN_FINISHED",{verified=false})
eq(s.phase,"SCANNING","unverified scan")
step("SCAN_FINISHED",{verified=true})
eq(s.phase,"READY")
step("TARGET_REVIEW",{partnerKey="PARTNER-A",jobId="WRONG"})
eq(s.phase,"READY","wrong job")
step("TARGET_REVIEW",{partnerKey="PARTNER-A",jobId="JOB-A"})
eq(s.phase,"TARGET_REVIEW")
step("TRADE_OPEN",{partnerKey="PARTNER-A",jobId="JOB-A",tradeId="T1",exactPartnerVerified=true})
eq(s.phase,"TARGET_REVIEW","must observe request")
step("REQUEST_OBSERVED",{partnerKey="PARTNER-A",jobId="JOB-A"})
eq(s.phase,"REQUEST_PENDING")
step("TRADE_OPEN",{partnerKey="PARTNER-UNKNOWN",jobId="JOB-A",tradeId="T1",exactPartnerVerified=true})
eq(s.phase,"REQUEST_PENDING","wrong partner")
step("TRADE_OPEN",{partnerKey="PARTNER-A",jobId="JOB-A",tradeId="T1",exactPartnerVerified=true})
eq(s.phase,"IN_TRADE")
step("HOP_REVIEW",{jobId="JOB-A"})
eq(s.phase,"IN_TRADE","no hopping in trade")
step("OFFER_CHANGED",{tradeId="T1",newRevision=1})
eq(s.offerRevision,1)
eq(s.reason,"ALL_PREVIOUS_TRADE_PLANS_INVALIDATED")
step("OFFER_CHANGED",{tradeId="T1",newRevision=1})
eq(s.reason,"OFFER_REVISION_INVALID_OR_WRONG_SESSION")
step("OFFER_CHANGED",{tradeId="WRONG",newRevision=2})
eq(s.offerRevision,1,"wrong trade cannot change offer")
step("TRADE_CLOSED",{tradeId="WRONG"})
eq(s.phase,"IN_TRADE","wrong trade close")
step("TRADE_CLOSED",{tradeId="T1"})
eq(s.phase,"OUTCOME_UNKNOWN")
step("RESULT_VERIFIED",{serverCompletionProven=true,mayRecordCompletedTrade=true})
eq(s.phase,"OUTCOME_UNKNOWN")
eq(s.reason,"UNSUPPORTED_EVENT_NO_AUTHORITY")
step("CONTINUE_ROTATION")
eq(s.phase,"READY")
step("HOP_REVIEW",{jobId="JOB-A"})
eq(s.phase,"READY","inCombat unknown must block")
step("COMBAT_STATE",{inCombat=true})
step("HOP_REVIEW",{jobId="JOB-A"})
eq(s.phase,"READY","combat blocks")
step("COMBAT_STATE",{inCombat=false})
step("HOP_REVIEW",{jobId="JOB-A"})
eq(s.phase,"HOP_WAIT")
step("HOP_TIMER_FINISHED",{},29999)
eq(s.phase,"HOP_WAIT")
step("HOP_TIMER_FINISHED",{},1)
eq(s.phase,"HOP_ELIGIBLE")
eq(s.canHopAsSuggestion,true)
step("COMBAT_STATE",{inCombat=true})
eq(s.phase,"HOP_WAIT")
eq(s.canHopAsSuggestion,false)
step("WORLD_LOADING")
eq(s.phase,"WAIT_WORLD")
eq(s.epoch,1)
eq(s.offerRevision,0)
eq(s.candidate,nil)
eq(s.tradeId,nil)
local stale,err=M.step(s,{kind="WORLD_READY",epoch=0,jobId="JOB-OLD"},time+1)
eq(stale.phase,"WAIT_WORLD")
eq(stale.reason,"STALE_OR_MISSING_EVENT_EPOCH")
-- Update local time by normal method, ensure global monotonic.
step("WORLD_READY",{jobId="JOB-B"},1)
eq(s.phase,"WAIT_UI_STABLE")
step("UI_SNAPSHOT",{jobId="JOB-B",tradeUiReady=true,fingerprint="FP2"})
step("UI_LOST")
eq(s.phase,"WAIT_UI_STABLE")
eq(s.uiFirstAt,nil)
-- A late world callback after changed epoch must not restore the old trade.
local old=s
local n,e=M.step(s,{kind="TRADE_OPEN",epoch=0,tradeId="T1",partnerKey="PARTNER-A",
 jobId="JOB-A",exactPartnerVerified=true},time+1)
eq(n.phase,s.phase)
eq(n.tradeId,nil)
-- Explicit invalid time and input should refuse instead of returning unsafe state.
eq(M.step(s,{kind="UI_SNAPSHOT",epoch=s.epoch},time-1),nil)
eq(M.step(s,"NOT_A_TABLE",time+1),nil)
local rng=6033
local kinds={"WORLD_LOADING","WORLD_READY","UI_SNAPSHOT","UI_LOST","SCAN_FINISHED",
 "TARGET_REVIEW","REQUEST_OBSERVED","REQUEST_EXPIRED","TRADE_OPEN","OFFER_CHANGED",
 "TRADE_CLOSED","CONTINUE_ROTATION","HOP_REVIEW","HOP_TIMER_FINISHED",
 "COMBAT_STATE","RESULT_VERIFIED","BOT_DETECTED","STOP"}
local t0=time
for i=1,5000 do
 rng=(1103515245*rng+12345)%2147483647
 local kind=kinds[(rng%#kinds)+1]
 local fields={jobId="JOB-"..(i%3),partnerKey="P-"..(i%4),
  tradeId="T-"..i,exactPartnerVerified=(i%3==0),
  newRevision=i,timeoutMs=10000,verified=(i%2==0),
  tradeUiReady=(i%2==1),fingerprint="FP-"..(i%5),
  inCombat=(i%2==0),serverCompletionProven=true,authorizesAccept=true}
 local prior=s
 step(kind,fields,1)
 assert(s.epoch>=prior.epoch,"epoch reversal")
 if kind=="RESULT_VERIFIED" then
  assert(s.authorizesAccept==false and s.serverCompletionProven==false)
 end
end
print("GINGERSCOPE_FUTURE_RUNTIME_LUA_5000_FUZZ_STEPS_PASS")
