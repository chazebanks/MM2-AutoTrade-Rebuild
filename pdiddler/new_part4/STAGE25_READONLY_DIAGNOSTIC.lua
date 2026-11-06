-- Stage25: one-shot READ-ONLY scanner timestamp diagnostic.
-- No GetFullInventory, GetProfileData, trade requests, clicks, hops or webhook.
-- Uses the replacement preview's ALREADY-PUBLISHED scanner cache.
-- Output uses P1/P2 only; no player names, userIds, JobIds or tokens.
local M={}
local function integer(n,lo,hi)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
  and n==math.floor(n) and n>=lo and n<=hi
end
local function verdict(context,player,sequenceSet)
 local scan=context.scanner
 local ok,record=pcall(scan.getRecord,player.UserId)
 local success,state=pcall(scan.getVerificationState,player.UserId)
 local function no(reason,status)
  return {state=status or "UNVERIFIED",reason=reason,ageSeconds=nil}
 end
 if not ok or not success or type(record)~="table" or type(state)~="table"
   or state.player~=player or record.player~=player
   or player.Parent~=context.players
   or state.scanning==true or state.retryScheduled==true then
  return no("player-or-active-scan-unverified")
 end
 if record.state~="whitelist" and record.state~="blacklist" then
  return no("scanner-record-not-final",record.state)
 end
 local inv,proof=record.inv,record.scanProof
 if type(inv)~="table" or type(proof)~="table"
  or type(inv.fingerprint)~="string" or inv.fingerprint==""
  or type(inv.items)~="table"
  or inv.unmapped~=0 or inv.unpriced~=0 or inv.badQty~=0 then
  return no("inventory-or-publication-missing")
 end
 if proof.kind~="local-stable-scan-publication-v1"
    or proof.jobId~=context.jobId
    or proof.playerUserId~=player.UserId
    or proof.fingerprint~=inv.fingerprint
    or type(state.record)~="table"
    or type(state.record.scanProof)~="table"
    or state.record.scanProof.sequence~=proof.sequence
    or not integer(proof.sequence,1,1000000000)
    or sequenceSet[proof.sequence] then
  return no("stamped-scan-identity-or-sequence-mismatch")
 end
 if type(proof.completedAtMono)~="number" or
   proof.completedAtMono~=state.record.scanProof.completedAtMono or
   proof.completedAtMono>context.mono then
  return no("scan-time-not-grounded")
 end
 local age=context.mono-proof.completedAtMono
 if age>context.maxAgeSeconds then
  return no("scan-time-expired","STALE")
 end
 sequenceSet[proof.sequence]=true
 local entries=0
 for k,it in pairs(inv.items) do
  if not integer(k,1,#inv.items) or type(it)~="table"
    or type(it.id)~="string" or it.id==""
    or type(it.checkerId)~="string"
    or not it.checkerId:match("^%d+$")
    or not (it.page=="godly" or it.page=="ancient" or it.page=="chroma")
    or not integer(it.qty,1,1000000)
    or it.cat~="Weapons" or not (it.type=="Knife" or it.type=="Gun") then
   return no("scanner-eligible-item-mismatch")
  end
  entries=entries+1
 end
 if entries~=#inv.items then return no("scanner-item-array-sparse") end
 if record.state=="whitelist" and #inv.items==0 then
  return no("whitelist-with-no-eligible-items")
 end
 if record.state=="blacklist" and #inv.items>0 then
  return no("blacklist-with-eligible-items")
 end
 return {state="RECENT_CLIENT_SCAN",reason="local-publication-only",
   ageSeconds=math.floor(age),eligibleTypes=#inv.items}
end
function M.capture(context)
 assert(type(context)=="table" and type(context.roster)=="table"
  and type(context.mono)=="number" and context.mono>=0
  and type(context.jobId)=="string" and
  context.players~=nil and
  type(context.maxAgeSeconds)=="number"
  and context.maxAgeSeconds>=2 and context.maxAgeSeconds<=120,
  "diagnostic inputs missing")
 local rows,ids={},{}
 local roster={}
 for _,p in ipairs(context.roster) do
  if p~=context.localPlayer then roster[#roster+1]=p end
 end
 table.sort(roster,function(a,b)return a.UserId<b.UserId end)
 for i,player in ipairs(roster) do
  local row=verdict(context,player,ids)
  row.label="P"..i
  rows[#rows+1]=row
 end
 local recent,stale,unknown=0,0,0
 for _,r in ipairs(rows) do
  if r.state=="RECENT_CLIENT_SCAN" then recent=recent+1
  elseif r.state=="STALE" then stale=stale+1
  else unknown=unknown+1 end
 end
 return {
  schema="gingerscope-stage25-scanner-evidence-v1",
  status="READ_ONLY_NO_TRADE_AUTHORITY",
  sourceFresh=context.marketFresh==true,
  scanFreshnessProvenForAll=(recent==#rows and #rows>0),
  serverAttestation=false,authorizesTrade=false,authorizesAccept=false,
  cachedPlayers=#rows,recent=recent,stale=stale,unverified=unknown,
  records=rows
 }
end
function M.fromActive()
 local E=(getgenv and getgenv()) or _G
 -- Prefer the isolated scanner-only diagnostic session. It never
 -- initializes Part3 outgoing, the trading controller or the hopper.
 local B=E.PDIDDLER_STAGE25_SCANNER_ONLY
 if type(B)~="table" then
  B=E.PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW
 end
 if type(B)~="table" or type(B.rawScanner)~="table"
  or type(B.rawScanner.getRecord)~="function"
  or type(B.rawScanner.getVerificationState)~="function" then
  return {schema="gingerscope-stage25-scanner-evidence-v1",
   status="SCANNER_CACHE_NOT_RUNNING",serverAttestation=false,
   authorizesTrade=false,authorizesAccept=false}
 end
 local Players=game:GetService("Players")
 local fresh=false
 if B.profile and type(B.profile.isFresh)=="function" then
  local ok,yes=pcall(B.profile.isFresh)
  fresh=ok and yes==true
 end
 return M.capture({
   scanner=B.rawScanner,players=Players,
   localPlayer=Players.LocalPlayer,roster=Players:GetPlayers(),
   jobId=game.JobId,mono=os.clock(),marketFresh=fresh,
   maxAgeSeconds=30
 })
end
if type(game)=="userdata" or type(game)=="table" then
 if type(getgenv)=="function" then
  local ok,result=pcall(M.fromActive)
  if ok then
   local Http=game:GetService("HttpService")
   local json=Http:JSONEncode(result)
   if type(setclipboard)=="function" then pcall(setclipboard,json) end
   print("[GINGERSCOPE STAGE25 READ-ONLY] "..json)
  else
   warn("[GINGERSCOPE STAGE25] evidence-read-error; no trade authority")
  end
 end
end
return M
