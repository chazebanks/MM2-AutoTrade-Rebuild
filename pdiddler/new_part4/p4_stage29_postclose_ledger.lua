-- Stage29: pure READ-ONLY own-inventory change ledger after GUI closure.
-- Local Roblox inventory remote responses are CLIENT evidence only.
-- An observed delta NEVER proves a completed trade, causal attribution,
-- authenticated server outcome, profit, or permission to Accept.
local M={}
local function integer(n,lo,hi)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
   and n==math.floor(n) and n>=lo and n<=hi
end
local function finite(n) return type(n)=="number" and n==n and n>=0 and n<math.huge end
local function validScope(s,scope)
 return type(scope)=="table" and scope.session==s.session and
   scope.jobId==s.jobId and scope.accountId==s.accountId and
   scope.partnerId==s.partnerId and scope.jobId~="" and
   scope.accountId~=nil and scope.partnerId~=nil
end
local function normalize(inv)
 if type(inv)~="table" or type(inv.items)~="table" or
    type(inv.fingerprint)~="string" or inv.fingerprint=="" or
    not integer(inv.rawOwned,1,1000000) or inv.unmapped~=0 or
    inv.badQty~=0 or type(inv.unpriced)~="number" then
    return nil,"incomplete-owned-weapon-scan"
 end
 local items,count,eligible={},0,0
 for k,r in pairs(inv.items) do
  if not integer(k,1,#inv.items) or type(r)~="table" or
     not (r.page=="ancient" or r.page=="godly" or r.page=="chroma")
     or type(r.checkerId)~="string" or not r.checkerId:match("^%d+$")
     or #r.checkerId>8 or type(r.id)~="string" or r.id=="" or
     r.cat~="Weapons" or not (r.type=="Gun" or r.type=="Knife")
     or not integer(r.qty,1,1000000) then
    return nil,"invalid-canonical-own-item"
  end
  local id=r.page..":"..r.checkerId..":checker-id"
  if items[id] then return nil,"duplicate-checker-identity" end
  count=count+1;eligible=eligible+r.qty;items[id]=r.qty
 end
 if count~=#inv.items or eligible>inv.rawOwned then
  return nil,"inventory-incomplete-or-sparse"
 end
 return {items=items,fp=inv.fingerprint,count=count,
   eligibleCount=eligible,rawOwned=inv.rawOwned},nil
end
local function changed(first,second)
 local n,gained,lost=0,0,0
 for k,q in pairs(first) do
  local diff=(second[k] or 0)-q
  if diff~=0 then
   n=n+1
   if diff>0 then gained=gained+diff else lost=lost-diff end
  end
 end
 for k,q in pairs(second) do if not first[k] then n=n+1;gained=gained+q end end
 return n,gained,lost
end
local function stop(s,why)
 s.status="INCOMPLETE";s.reason=why;s.terminal=true
 return "INCOMPLETE",why
end
function M.new(scope,now,opts)
 assert(type(scope)=="table" and type(scope.session)=="string" and scope.session~=""
   and scope.jobId and scope.accountId and scope.partnerId and finite(now),
   "Stage29 scoped session and time required")
 opts=opts or {}
 local age=opts.maxBeforeToClose or 30
 local gap=opts.minPostGap or .75
 local horizon=opts.maxPostAge or 30
 assert(finite(age) and age>=1 and age<=60
   and finite(gap) and gap>=.25 and gap<=10
   and finite(horizon) and horizon>=3 and horizon<=60,
   "Stage29 readback timing bounds invalid")
 return {session=scope.session,jobId=scope.jobId,
   accountId=scope.accountId,partnerId=scope.partnerId,
   createdAt=now,maxBeforeToClose=age,minPostGap=gap,maxPostAge=horizon,
   status="AWAIT_BEFORE",reason="not-yet-observed",terminal=false,
   pre=nil,post1=nil,post2=nil,closedAt=nil,
   beforeAt=nil,after1At=nil,after2At=nil,
   scans=0,readbackStatus="not-started"}
end
function M.before(s,inv,t,scope)
 if s.status~="AWAIT_BEFORE" or s.terminal then return "HOLD","not-awaiting-before" end
 if not validScope(s,scope) then return stop(s,"scope-changed-before") end
 if not finite(t) or t<s.createdAt then return stop(s,"before-clock-invalid") end
 local pre,why=normalize(inv)
 if not pre then return stop(s,"before-"..why) end
 s.pre=pre;s.beforeAt=t;s.scans=1
 s.status="AWAIT_CLOSE";s.reason="before-read-observed"
 return "OBSERVED","before-read-observed"
end
function M.close(s,kind,t,scope)
 if s.terminal or s.status~="AWAIT_CLOSE" then return "HOLD","close-not-ready" end
 if not validScope(s,scope) then return stop(s,"scope-changed-at-close") end
 if kind~="CLOSED_UNKNOWN" then
  return stop(s,"close-not-verified-same-trade")
 end
 if not finite(t) or t<s.beforeAt or
    t-s.beforeAt>s.maxBeforeToClose then
  return stop(s,"before-to-close-age-invalid")
 end
 s.closedAt=t;s.status="AWAIT_AFTER1"
 s.reason="trade-window-closed-outcome-unknown"
 return "OBSERVED","closed-client-window-only"
end
function M.after(s,inv,t,scope,sequence)
 if s.terminal or
   (s.status~="AWAIT_AFTER1" and s.status~="AWAIT_AFTER2") then
    return "HOLD","post-read-not-ready"
 end
 if not validScope(s,scope) then return stop(s,"scope-changed-after-close") end
 if not integer(sequence,2,3) or sequence~=s.scans+1 then
    return stop(s,"readback-sequence-invalid")
 end
 if not finite(t) or not s.closedAt or t<=s.closedAt
   or t-s.closedAt>s.maxPostAge then
   return stop(s,"post-close-readback-age-invalid")
 end
 local read,why=normalize(inv)
 if not read then return stop(s,"post-"..why) end
 if s.status=="AWAIT_AFTER1" then
   s.post1=read;s.after1At=t;s.scans=2
   s.status="AWAIT_AFTER2";s.reason="one-post-read-insufficient"
   return "OBSERVED","first-post-read-only"
 end
 if t<=s.after1At or t-s.after1At<s.minPostGap then
   return stop(s,"independent-post-read-gap-unverified")
 end
 s.post2=read;s.after2At=t;s.scans=3
 s.terminal=true
 if s.post1.fp~=s.post2.fp or
    s.post1.rawOwned~=s.post2.rawOwned then
    s.status="POST_READS_DISAGREE";s.reason="post-read-fingerprints-disagree"
    return s.status,s.reason
 end
 local postChange=changed(s.post1.items,s.post2.items)
 if postChange~=0 then
   s.status="POST_READS_DISAGREE";s.reason="post-read-eligible-quantities-disagree"
   return s.status,s.reason
 end
 local types,gained,lost=changed(s.pre.items,s.post2.items)
 s.changedTypes=types;s.gainedCount=gained;s.lostCount=lost
 s.rawChanged=s.pre.fp~=s.post2.fp
 s.status=types>0 and "ELIGIBLE_DELTA_UNATTRIBUTED"
    or (s.rawChanged and "RAW_WEAPON_CHANGE_UNATTRIBUTED"
     or "NO_ELIGIBLE_DELTA_OBSERVED")
 s.reason=types>0 and "eligible-counts-differ-but-cause-unknown"
    or (s.rawChanged and "other-weapons-or-raw-inventory-changed"
    or "client-readbacks-identical-not-decline-proof")
 return s.status,s.reason
end
function M.summary(s)
 return {schema="gingerscope-stage29-post-close-own-inventory-v1",
   status=s.status,reason=s.reason,
   readbackCalls=s.scans,
   beforeObserved=s.pre~=nil,
   windowClosureObserved=s.closedAt~=nil,
   postReadbacksObserved=(s.post1 and 1 or 0)+(s.post2 and 1 or 0),
   changedEligibleTypes=s.changedTypes,
   gainedEligibleCopies=s.gainedCount,lostEligibleCopies=s.lostCount,
   rawWeaponInventoryChanged=s.rawChanged,
   readbacksAreClientClaims=true,
   tradeOutcome="UNKNOWN",
   clientWindowClosureDoesNotProveDecline=true,
   clientWindowClosureDoesNotProveCompletion=true,
   serverAttestation=false,serverCompletionProven=false,
   authorizesTrade=false,authorizesAccept=false,
   mayRecordCompletedTrade=false,mayReportProfit=false,
   reviewOnly=true}
end
return M
