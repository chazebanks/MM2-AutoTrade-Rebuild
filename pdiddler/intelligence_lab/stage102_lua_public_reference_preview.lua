-- Stage102 original-publication archive -> Stage98 local physical GUI offers.
-- PURE / READ-ONLY. No Roblox globals, remotes, screen input, pricing refresh,
-- account inventory, raw weapon identity, profit or final Accept authority.
-- The 189-row public archive is NOT a current market feed.
local M={}
M.schema="gingerscope-stage102-lua-public-name-candidate-preview-v1"
local SOURCE="gingerscope-stage102-pinned-public-name-value-archive-v1"
local ORIGINAL="6eafa73001f59f41d07e6fee6959be38dabd8b2d43e690ede30852f9b0ee532a"
local PUBLISHED=1794250713
local EXPIRES=1794349608
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function int(v,lo,hi)
 return finite(v) and v==math.floor(v) and v>=lo and v<=hi
end
local function safeName(s)
 if type(s)~="string" or #s<1 or #s>150 or s:find("[%c]") then return nil end
 local v=s:gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," "):lower()
 return v~="" and v or nil
end
local DENY={
 clientOnly=true,readOnly=true,researchOnly=true,nameOnlyUnbound=true,
 currentGameItemIdentityAuthenticated=false,rawOfferKeyBoundToPhysicalSlot=false,
 numericSupremeCheckerIdVerified=false,uniqueWeaponInstanceProven=false,
 authenticatedOwnedInventory=false,sourcePublisherFreshForTrade=false,
 currentPricesVerified=false,priceForTradeVerified=false,
 serverTradeRevisionProven=false,serverAttestation=false,
 serverCompletionProven=false,eventSessionAssociationProven=false,
 callbackCausalityProven=false,authorizesTrade=false,
 authorizesAccept=false,mayRecordCompletedTrade=false,mayReportProfit=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
 tradeOutcome="UNKNOWN"
}
local function result(status,reason)
 local r={
  schema=M.schema,status=status,reason=reason,
  sourcePriceState="UNAVAILABLE",matchedCandidateSlots=0,
  unmatchedSlots=0,ambiguousSlots=0,
  localOfferEpoch=nil,rows={},ourHistoricalReferenceTotal=nil,
  theirHistoricalReferenceTotal=nil,illustrativeHistoricalDifference=nil,
  protectedGingerscopeCandidateVisible=false,protectedOutgoingAllowed=false,
  historicalSourcePublishedAt="2026-11-09T18:58:33Z",
  historicalSourceExpiresAt="2026-11-10T22:26:48Z"
 }
 for k,v in pairs(DENY) do r[k]=v end
 return r
end
local function dense(t,limit)
 if type(t)~="table" or getmetatable(t)~=nil or #t>limit then return false end
 local seen=0
 for k in pairs(t) do
  if not int(k,1,#t) then return false end
  seen=seen+1
 end
 return seen==#t
end
function M.validateArchive(archive)
 if type(archive)~="table" or getmetatable(archive)~=nil or
    archive.schema~=SOURCE or archive.origin~="ORIGINAL_STAGE94_PUBLIC_RESEARCH_ONLY"
    or archive.originalJoinedRowsSha256~=ORIGINAL or
    archive.publishedAt~="2026-11-09T18:58:33Z" or
    archive.expiresAt~="2026-11-10T22:26:48Z" or
    archive.entryCount~=189 or archive.currentPricesVerified~=false or
    archive.priceForTradeVerified~=false or
    archive.rawOfferKeyBoundToPhysicalSlot~=false or
    archive.numericSupremeCheckerIdVerified~=false or
    archive.authorizesTrade~=false or archive.authorizesAccept~=false or
    archive.mayReportProfit~=false or archive.serverCompletionProven~=false
    or not dense(archive.rows,189) or #archive.rows~=189 then
  return nil,"ARCHIVED_SOURCE_SCHEMA_OR_AUTHORITY_INVALID"
 end
 if type(archive.categoryCounts)~="table" or
    archive.categoryCounts.ancient~=15 or
    archive.categoryCounts.godly~=128 or
    archive.categoryCounts.chroma~=46 then
  return nil,"ARCHIVED_CATEGORY_COUNTS_INVALID"
 end
 local counters={ancient=0,godly=0,chroma=0}
 local lookup={}
 for _,row in ipairs(archive.rows) do
  if type(row)~="table" or getmetatable(row)~=nil or
     not safeName(row.label) or
     (row.category~="ancient" and row.category~="godly" and
      row.category~="chroma") or
     type(row.chroma)~="boolean" or
     (row.chroma~=(row.category=="chroma")) or
     (safeName(row.label):sub(1,7)=="chroma ")~=row.chroma or
     not int(row.value,1,999999999) or not int(row.demand,0,11) or
     type(row.stability)~="string" or #row.stability<1 or
     #row.stability>60 then
    return nil,"ARCHIVED_PUBLIC_ROW_INVALID"
  end
  counters[row.category]=counters[row.category]+1
  local key=(row.chroma and "1" or "0")..":"..safeName(row.label)
  if lookup[key]~=nil then return nil,"ARCHIVED_DUPLICATE_PUBLIC_NAME" end
  lookup[key]=row
 end
 for k,count in pairs(archive.categoryCounts) do
  if counters[k]~=count then return nil,"ARCHIVED_CATEGORY_COVERAGE_MISMATCH" end
 end
 return lookup,"PINNED_PUBLIC_ARCHIVE_SHAPE_VALID"
end
local function physical(side)
 if not dense(side,4) then return nil,"CLIENT_OFFER_SIDE_MALFORMED" end
 local out,seen,total={},{},0
 for _,v in ipairs(side) do
  if type(v)~="table" or not int(v[1],1,4) or seen[v[1]]
    or not safeName(v[2]) or type(v[3])~="boolean"
    or not int(v[4],1,4) or type(v[5])~="string"
    or #v[5]>128 or v[5]:find("[%c]") then
   return nil,"CLIENT_PHYSICAL_SLOT_UNVERIFIED"
  end
  seen[v[1]]=true
  total=total+v[4]
  if total>4 then return nil,"FOUR_COPY_LIMIT_EXCEEDED" end
  out[#out+1]={slot=v[1],label=safeName(v[2]),
    chroma=v[3],quantity=v[4]}
 end
 return out
end
function M.preview(archive,state,nowUnix,nowClock)
 local out=result("INCONCLUSIVE","CLIENT_OR_SOURCE_INCOMPLETE")
 if not int(nowUnix,1600000000,2100000000) or
   not finite(nowClock) then
  out.reason="EVALUATION_CLOCK_UNTRUSTED";return out
 end
 local catalogue,why=M.validateArchive(archive)
 if not catalogue then out.reason=why;return out end
 if type(state)~="table" or state.dead or state.first or
    state.pending or type(state.scope)~="table" or
    not int(state.epoch,1,1000000) or
    not int(state.stable,2,1000000) or
    not finite(state.changedAt) or not finite(state.lastAt) or
    nowClock<state.lastAt or nowClock-state.lastAt>2 or
    state.lastAt-state.changedAt<.15 then
  out.reason="CLIENT_LOCAL_REVISION_NOT_STABLE";return out
 end
 local ours,a=physical(state.our)
 if not ours then out.reason=a;return out end
 local theirs,b=physical(state.their)
 if not theirs then out.reason=b;return out end
 local sourceState=nowUnix>=EXPIRES and
    "ARCHIVED_RESEARCH_CAPTURE_EXPIRED" or
    "HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW"
 if nowUnix<PUBLISHED then
  out.reason="ARCHIVE_NOT_YET_PUBLISHED";return out
 end
 local counts={ours=0,theirs=0}
 local full={ours=true,theirs=true}
 local matched,unmatched=0,0
 for _,sideName in ipairs({"ours","theirs"}) do
  local rows=sideName=="ours" and ours or theirs
  for _,v in ipairs(rows) do
   local match=catalogue[(v.chroma and "1" or "0")..":"..v.label]
   local candidate={
    side=sideName,slot=v.slot,visibleLabel=v.label,
    chroma=v.chroma,quantity=v.quantity,
    identityEvidence="NAME_ONLY_NOT_RAW_KEY_BOUND",
    historicalValuePerCopy=nil,historicalSubtotal=nil,
    historicalDemand=nil,historicalStability=nil,
    liquidity="UNVERIFIED",priceForTradeVerified=false,
    protectedTargetCandidate=(sideName=="ours" and v.label=="gingerscope")
   }
   if candidate.protectedTargetCandidate then
    out.protectedGingerscopeCandidateVisible=true
   end
   if match then
    matched=matched+1
    counts[sideName]=counts[sideName]+match.value*v.quantity
    candidate.matchStatus="UNIQUE_PUBLIC_NAME_VARIANT_CANDIDATE"
    candidate.publicReferenceLabel=match.label
    candidate.historicalValuePerCopy=match.value
    candidate.historicalSubtotal=match.value*v.quantity
    candidate.historicalDemand=match.demand
    candidate.historicalStability=match.stability
   else
    unmatched=unmatched+1
    full[sideName]=false
    candidate.matchStatus="NO_EXACT_PUBLIC_NAME_VARIANT_MATCH"
   end
   out.rows[#out.rows+1]=candidate
  end
 end
 out.status=unmatched==0 and
   "HISTORICAL_PUBLIC_CANDIDATES_RESEARCH_ONLY" or
   "PUBLIC_NAME_MATCH_INCOMPLETE_RESEARCH_ONLY"
 out.reason="CLIENT_GUI_NAMES_NOT_VERIFIED_RAW_WEAPON_KEYS"
 out.sourcePriceState=sourceState
 out.localOfferEpoch=state.epoch
 out.matchedCandidateSlots=matched
 out.unmatchedSlots=unmatched
 if unmatched==0 and #ours>0 and #theirs>0 and
   full.ours and full.theirs and
   sourceState=="HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW" then
  out.ourHistoricalReferenceTotal=counts.ours
  out.theirHistoricalReferenceTotal=counts.theirs
  out.illustrativeHistoricalDifference=counts.theirs-counts.ours
 end
 -- Never produce a real "safe offer" bit. A visually matched Gingerscope
 -- on our side is protected; ambiguous physical identity is NOT a waiver.
 return out
end
return M
