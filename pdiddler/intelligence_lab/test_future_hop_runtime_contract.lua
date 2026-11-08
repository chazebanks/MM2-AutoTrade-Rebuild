-- Cross-PR offline safety contract for future runtime PR107 -> server shortlist PR108.
-- NO game/Roblox APIs; these are synthetic state transitions, NEVER teleport.
local supervisor=assert(dofile(arg[1]))
local time=1000
local s=assert(supervisor.new(time))
local function step(kind,fields,delay)
 time=time+(delay or 0)
 local e={kind=kind,epoch=s.epoch}
 for k,v in pairs(fields or {}) do e[k]=v end
 local after,err=supervisor.step(s,e,time)
 assert(after,tostring(err))
 s=after
 assert(s.authorizesTrade==false and s.authorizesAccept==false)
 assert(s.serverCompletionProven==false and s.mayReportProfit==false)
 return s
end
local function show(tag,trade,loading)
 local eligible=(s.phase=="HOP_ELIGIBLE" and s.canHopAsSuggestion==true)
 print(table.concat({tag,s.phase,tostring(eligible),tostring(s.inCombat),
       tostring(trade),tostring(loading),tostring(s.epoch)},"|"))
end
step("WORLD_READY",{jobId="here"})
step("UI_SNAPSHOT",{jobId="here",tradeUiReady=true,fingerprint="visible"})
step("UI_SNAPSHOT",{jobId="here",tradeUiReady=true,fingerprint="visible"},1500)
step("SCAN_FINISHED",{verified=true})
step("COMBAT_STATE",{inCombat=false})
step("HOP_REVIEW",{jobId="here"})
step("HOP_TIMER_FINISHED",{},30000)
show("HOP_READY",false,false)
step("COMBAT_STATE",{inCombat=true})
show("COMBAT_INTERRUPTED",false,false)
step("COMBAT_STATE",{inCombat=false})
show("COOLDOWN_NOT_FINISHED",false,false)
step("HOP_TIMER_FINISHED",{},30000)
show("COOLDOWN_FINISHED",false,false)
local oldEpoch=s.epoch
step("WORLD_LOADING")
show("WORLD_RESET",false,true)
local again,err=supervisor.step(s,{kind="HOP_TIMER_FINISHED",epoch=oldEpoch},time+1)
assert(again and again.phase=="WAIT_WORLD" and again.canHopAsSuggestion==false)
s=again
show("STALE_HOP_IGNORED",false,true)
step("WORLD_READY",{jobId="here"},1)
step("UI_SNAPSHOT",{jobId="here",tradeUiReady=true,fingerprint="visible2"})
step("UI_SNAPSHOT",{jobId="here",tradeUiReady=true,fingerprint="visible2"},1500)
step("SCAN_FINISHED",{verified=true})
step("COMBAT_STATE",{inCombat=false})
step("TARGET_REVIEW",{partnerKey="P1",jobId="here"})
step("REQUEST_OBSERVED",{partnerKey="P1",jobId="here"})
step("TRADE_OPEN",{tradeId="T1",partnerKey="P1",jobId="here",exactPartnerVerified=true})
step("HOP_REVIEW",{jobId="here"})
show("TRADE_ACTIVE",true,false)
step("TRADE_CLOSED",{tradeId="T1"})
show("TRADE_CLOSED_UNKNOWN",false,false)
step("CONTINUE_ROTATION")
show("ROTATION_READY_NOT_HOP_ELIGIBLE",false,false)
print("GIN_FUTURE_HOP_SUPERVISOR_CASES_PASS")
