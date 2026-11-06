-- Stage34: PURE, READ-ONLY exact eligible offer vs own-inventory delta comparator.
-- Reuses Stage9 normalized native offer rows and Stage29 ledger instance.
-- Never calls Roblox, prices items, makes trade decisions, or proves settlement.
-- Item identities are held transiently and NEVER appear in summary output.
local M={}
local function integer(v,lo,hi)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
    and v==math.floor(v) and v>=lo and v<=hi
end
local function finite(v) return type(v)=="number" and v==v and v>=0 and v<math.huge end
local function sameScope(s,scope)
 return type(scope)=="table" and scope.session==s.session and
  scope.jobId==s.jobId and scope.accountId==s.accountId and
  scope.partnerId==s.partnerId and s.jobId~="" and
  s.accountId~=nil and s.partnerId~=nil
end
local function identical(a,b)
 for k,q in pairs(a) do if b[k]~=q then return false end end
 for k,q in pairs(b) do if a[k]~=q then return false end end
 return true
end
local function offerMap(rows,slots)
 if not integer(slots,0,4) or type(rows)~="table" or #rows~=slots then
  return nil,"offer-slot-count-unverified"
 end
 local map,seen={},{}
 local copies=0
 for _,r in ipairs(rows) do
  if type(r)~="table" or not integer(r.slot,1,4)
      or seen[r.slot] or type(r.id)~="string" or r.id==""
      or not (r.page=="ancient" or r.page=="godly" or r.page=="chroma")
      or type(r.checkerId)~="string" or
       not r.checkerId:match("^%d+$") or #r.checkerId>8
      or not integer(r.qty,1,4) then
    return nil,"offer-identity-or-quantity-unverified"
  end
  seen[r.slot]=true
  copies=copies+r.qty
  if copies>4 then return nil,"over-four-physical-copies-unverified" end
  local key=r.page..":"..r.checkerId..":checker-id"
  map[key]=(map[key] or 0)+r.qty
 end
 return map,nil,copies
end
local function offerSample(o,diag)
 if type(o)~="table" or o.tradeOpen~=true or o.contextOK~=true
    or o.theirResolved~=true or type(diag)~="table"
    or type(o.ourSig)~="string" or o.ourSig=="" or
       o.ourSig:match("^unverified") or o.ourSig=="capture-error"
    or type(o.theirSig)~="string" or o.theirSig=="" or
       o.theirSig:match("^unverified") or o.theirSig=="capture-error"
    or type(o.ourAccepted)~="boolean" or
       type(o.theirAccepted)~="boolean" then
  return nil,"native-context-or-accept-unverified"
 end
 local ours,why,oursCount=offerMap(diag.ourItems,o.ourSlots)
 if not ours then return nil,"own-"..why end
 local theirs,why2,theirsCount=offerMap(diag.theirItems,o.theirSlots)
 if not theirs then return nil,"partner-"..why2 end
 if oursCount+theirsCount==0 then
  return nil,"both-offers-empty"
 end
 return {signature=o.ourSig.."\0"..o.theirSig,
  ours=ours,theirs=theirs,ourCopies=oursCount,theirCopies=theirsCount,
  oursAccepted=o.ourAccepted,theirsAccepted=o.theirAccepted},nil
end
local function makeResult(s,status,reason,details)
 details=details or {}
 return {schema="gingerscope-stage34-client-offer-delta-reconciliation-v1",
  status=status,reason=reason,
  stableOfferFrames=s.stableFrames,
  stableOfferObserved=s.stable==true,
  offerMutationAfterAccept=s.tainted==true,
  offerWindowClosed=s.closedAt~=nil,
  ourAcceptIndicatorObserved=s.ourAcceptSeen==true,
  theirAcceptIndicatorObserved=s.theirAcceptSeen==true,
  expectedIncomingEligibleCopies=details.expectedIn,
  expectedOutgoingEligibleCopies=details.expectedOut,
  observedIncomingEligibleCopies=details.observedIn,
  observedOutgoingEligibleCopies=details.observedOut,
  eligibleIdentityTypesCompared=details.compared,
  mismatchIdentityTypes=details.mismatched,
  rawWeaponDeltaMatchesExpected=details.rawMatches,
  readbacksAreClientClaims=true,
  offerCaptureIsClientClaim=true,
  claimButtonIsNotCreditPrerequisite=true,
  tradeOutcome="UNKNOWN",causalAttributionProven=false,
  serverAttestation=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,readOnly=true}
end
function M.new(scope,t,config)
 assert(type(scope)=="table" and type(scope.session)=="string" and
  scope.session~="" and type(scope.jobId)=="string" and scope.jobId~="" and
  scope.accountId~=nil and scope.partnerId~=nil and finite(t),
  "Stage34 bound scope and monotonic clock required")
 config=config or {}
 local minGap=config.minStableGap or .15
 local maxCloseLag=config.maxCloseLag or .45
 assert(finite(minGap) and minGap>=.1 and minGap<=1 and
  finite(maxCloseLag) and maxCloseLag>=.2 and maxCloseLag<=1,
  "Stage34 stability bounds invalid")
 return {session=scope.session,jobId=scope.jobId,
  accountId=scope.accountId,partnerId=scope.partnerId,
  startedAt=t,lastAt=nil,lastSig=nil,snapshot=nil,stableFrames=0,
  stable=false,firstSigAt=nil,tainted=false,seenAnyAccept=false,
  ourAcceptSeen=false,theirAcceptSeen=false,
  closedAt=nil,terminal=false,invalidReason=nil,
  minGap=minGap,maxCloseLag=maxCloseLag}
end
local function invalidate(s,why)
 s.terminal=true;s.invalidReason=why;s.stable=false
 return "INCOMPLETE",why
end
function M.observe(s,o,diag,t,scope)
 if s.terminal or s.closedAt then return "HOLD","already-terminal" end
 if not sameScope(s,scope) then return invalidate(s,"trade-scope-changed") end
 if not finite(t) or t<s.startedAt or (s.lastAt and t<=s.lastAt) then
  return invalidate(s,"nonmonotonic-client-observation")
 end
 s.lastAt=t
 local sample,reason=offerSample(o,diag)
 if not sample then
  if s.seenAnyAccept then return invalidate(s,"accepted-with-"..reason) end
  s.lastSig=nil;s.stableFrames=0;s.stable=false;s.snapshot=nil
  return "HOLD",reason
 end
 if s.lastSig and s.lastSig~=sample.signature and s.seenAnyAccept then
  s.tainted=true
  return invalidate(s,"offer-mutated-after-client-accept")
 end
 if s.lastSig==sample.signature then
  -- String signatures do not substitute for independently consistent
  -- canonical scanner resolutions of every actual physical offer slot.
  if not s.snapshot or
    not identical(s.snapshot.ours,sample.ours) or
    not identical(s.snapshot.theirs,sample.theirs) then
    return invalidate(s,"signature-and-resolved-identity-disagree")
  end
  s.stableFrames=s.stableFrames+1
 else
  s.lastSig=sample.signature
  s.stableFrames=1;s.firstSigAt=t
  s.stable=false
 end
 s.snapshot=sample
 if sample.oursAccepted or sample.theirsAccepted then s.seenAnyAccept=true end
 if sample.oursAccepted then s.ourAcceptSeen=true end
 if sample.theirsAccepted then s.theirAcceptSeen=true end
 s.stable=s.stableFrames>=2 and t-s.firstSigAt>=s.minGap
 return s.stable and "STABLE" or "OBSERVING","client-offer-only"
end
function M.close(s,t,scope)
 if s.terminal or s.closedAt then return "HOLD","already-terminal" end
 if not sameScope(s,scope) then return invalidate(s,"scope-changed-at-close") end
 if not finite(t) or not s.lastAt or t<s.lastAt then
  return invalidate(s,"close-clock-invalid")
 end
 s.closedAt=t
 if not s.stable or t-s.lastAt>s.maxCloseLag then
  return invalidate(s,"stable-final-offer-not-observed-near-close")
 end
 s.terminal=true
 return "CLOSED_UNKNOWN","native-gui-close-only"
end
function M.evaluate(s,l,scope)
 if type(s)~="table" or type(l)~="table" then
  return makeResult(s or {},"INCOMPLETE","missing-stage34-or-ledger-instance")
 end
 if s.invalidReason or not s.terminal or not s.closedAt or
    not s.stable or not s.snapshot or s.tainted then
  return makeResult(s,"INCOMPLETE",s.invalidReason or "final-offer-unverified")
 end
 if not sameScope(s,scope) or l.session~=s.session or
    l.jobId~=s.jobId or l.accountId~=s.accountId or
    l.partnerId~=s.partnerId then
  return makeResult(s,"INCOMPLETE","ledger-or-evaluator-scope-mismatch")
 end
 if not l.terminal or l.scans~=3 or
    (l.status~="ELIGIBLE_DELTA_UNATTRIBUTED" and
      l.status~="NO_ELIGIBLE_DELTA_OBSERVED" and
      l.status~="RAW_WEAPON_CHANGE_UNATTRIBUTED") or
    not finite(l.closedAt) or math.abs(l.closedAt-s.closedAt)>.25 or
    type(l.pre)~="table" or type(l.post1)~="table" or
    type(l.post2)~="table" or
    not identical(l.post1.items or {},l.post2.items or {}) or
    l.post1.fp~=l.post2.fp or l.post1.rawOwned~=l.post2.rawOwned or
    not finite(l.after1At) or not finite(l.after2At) or
    l.after1At<=s.closedAt or l.after2At<=l.after1At then
  return makeResult(s,"INCOMPLETE","ledger-readback-unstable-or-unverified")
 end
 local snap=s.snapshot
 -- Same eligible checker item on BOTH sides masks gross in/out quantities
 -- in a net-owned inventory delta. There is no safe exact gross proof.
 for k in pairs(snap.ours) do
  if snap.theirs[k] then
   return makeResult(s,"AMBIGUOUS_OVERLAPPING_OFFER_TYPES",
      "same-item-in-both-offers-net-delta-ambiguous")
  end
 end
 local expected,expectedIn,expectedOut={},
  snap.theirCopies,snap.ourCopies
 for k,q in pairs(snap.theirs) do expected[k]=q end
 for k,q in pairs(snap.ours) do expected[k]=-q end
 local actual,observedIn,observedOut={},0,0
 for k,q in pairs(l.pre.items or {}) do
  if not integer(q,1,1000000) then
   return makeResult(s,"INCOMPLETE","before-eligible-count-invalid")
  end
  actual[k]=-q
 end
 for k,q in pairs(l.post2.items or {}) do
  if not integer(q,1,1000000) then
   return makeResult(s,"INCOMPLETE","after-eligible-count-invalid")
  end
  actual[k]=(actual[k] or 0)+q
 end
 local mismatched,compared=0,0
 local seen={}
 for k,q in pairs(expected) do
  seen[k]=true;compared=compared+1
  if (actual[k] or 0)~=q then mismatched=mismatched+1 end
 end
 for k,q in pairs(actual) do
  if q>0 then observedIn=observedIn+q
  elseif q<0 then observedOut=observedOut-q end
  if q~=0 and not seen[k] then
   compared=compared+1;mismatched=mismatched+1
  end
 end
 local rawDelta=l.post2.rawOwned-l.pre.rawOwned
 local rawMatches=rawDelta==expectedIn-expectedOut
 local details={expectedIn=expectedIn,expectedOut=expectedOut,
    observedIn=observedIn,observedOut=observedOut,compared=compared,
    mismatched=mismatched,rawMatches=rawMatches}
 if mismatched~=0 or not rawMatches or
   (expectedIn+expectedOut>0 and l.pre.fp==l.post2.fp) then
  return makeResult(s,"OFFER_AND_OWN_DELTA_MISMATCH_CLIENT_ONLY",
   "owned-eligible-change-does-not-match-stable-offers",details)
 end
 return makeResult(s,"OFFER_AND_OWN_DELTA_AGREE_CLIENT_ONLY",
   "exact-eligible-identities-and-quantities-agree-not-settlement",details)
end
return M
