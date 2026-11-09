-- Stage70: RESEARCH-ONLY, source-vs-game-weapon identity boundary.
-- The Supreme publisher can accurately value a checker record, but that
-- does NOT independently prove which MM2 raw Weapons.Owned key denotes it.
-- No trade/Accept/Discord/export/market training authority from this module.
local M={}

-- TRUST ROOT: code-reviewed mappings ONLY. Deliberately EMPTY because
-- Stages54-58 established 164 fuzzy/19 alias/7 internal matches but ZERO
-- independently authenticated raw-key -> numeric Supreme checker ID links.
-- NEVER populate from a caller's checkerId, "verified" boolean, or alias.
-- Each future entry requires an independently reviewed versioned evidence
-- record, source dates and a separate regression proving its exact identity.
local REVIEWED_RAW_TO_CHECKER={
 -- EMPTY: not a placeholder for guesses or fuzzy self-promotion.
}

local REQUIRED_SOURCE_URL={
 ancient="https://supremevalues.com/mm2/ancients",
 godly="https://supremevalues.com/mm2/godlies",
 chroma="https://supremevalues.com/mm2/chromas"
}
local function finite(x)
 return type(x)=="number" and x==x
   and x~=math.huge and x~=-math.huge
end
local function positiveInteger(x)
 return finite(x) and x==math.floor(x) and x>0 and x<=1000000
end
local function norm(x)
 if type(x)~="string" then return "" end
 return x:gsub("’","'"):lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
end
local function sourceFresh(profile)
 if type(profile)~="table" or profile.liveReady~=true
   or type(profile.get)~="function"
   or type(profile.isFresh)~="function"
   or type(profile.sources)~="table" then return false end
 local at=os.time() -- caller cannot rewind source freshness with injected clock
 if not finite(at) or at~=math.floor(at) then return false end
 local obs=profile.observedAtEpoch
 local pub=profile.publishedAtEpoch
 local exp=profile.expiresAtEpoch
 if not finite(obs) or not finite(pub) or not finite(exp)
    or obs~=math.floor(obs) or pub~=math.floor(pub) or exp~=math.floor(exp)
    or pub>obs or obs>at or at>=exp
    or at-pub>72*3600
    or exp>obs+24*3600 or exp>pub+72*3600 then return false end
 for page,url in pairs(REQUIRED_SOURCE_URL) do
  local src=profile.sources[page]
  if type(src)~="table" or src.url~=url
    or type(src.sha256)~="string" or #src.sha256~=64
    or not src.sha256:match("^[0-9a-f]+$")
    or type(src.publishedAt)~="string"
    or type(src.observedAt)~="string" then
   return false
  end
 end
 local ok,fresh=pcall(profile.isFresh,at)
 return ok and fresh==true
end

local function result(status,reason)
 return {
  schema="gingerscope-stage70-raw-checker-proof-gate-v1",
  status=status,reason=reason,
  readOnly=true,tradeOutcome="UNKNOWN",
  sourceFresh=false,
  reviewedMappingCount=0,
  itemRowsObserved=0,
  priceRowsVerified=0,
  unverifiedItemRows=0,
  rawCheckerCrosswalkProven=false,
  items={},
  verifiedSubtotal=nil,
  completeValue=nil,
  numericTradingAuthority=false,
  authorizesAccept=false,
  authorizesTrade=false,
  mayReportProfit=false,
  mayRecordCompletedTrade=false,
  mayRecordRejectedTrade=false,
  mayUseForStrategyLearning=false,
  maySendDiscordWebhook=false
 }
end

function M.evaluate(inv,profile)
 local out=result("UNVERIFIED_SOURCE_OR_IDENTITY","NOT_EVALUATED")
 if type(inv)~="table" or type(inv.items)~="table" then
  out.reason="INVENTORY_UNAVAILABLE"
  return out
 end

 -- The checker roster is immutable within this module and cannot be supplied
 -- or filled by caller-controlled items, GUI flags or source page metadata.
 local reviewed=0
 local checkerTargetSeen={}
 for key,proof in pairs(REVIEWED_RAW_TO_CHECKER) do
  reviewed=reviewed+1
  if type(key)~="string" or key=="" or type(proof)~="table"
    or proof.rawKey~=key or type(proof.checkerId)~="string"
    or not proof.checkerId:match("^%d+$")
    or not REQUIRED_SOURCE_URL[proof.page]
    or type(proof.name)~="string" or proof.name==""
    or (proof.type~="Knife" and proof.type~="Gun")
    or type(proof.reviewedEvidenceId)~="string"
    or not proof.reviewedEvidenceId:match("^INDEPENDENT%-REVIEW%-%d+$")
    or type(proof.provenanceVersion)~="string"
    or proof.provenanceVersion=="" then
   out.reason="INVALID_STATIC_REVIEWED_CROSSWALK"
   return out
  end
  local checkerTarget=proof.page..":"..proof.checkerId
  if checkerTargetSeen[checkerTarget] then
   out.reason="DUPLICATE_REVIEWED_CHECKER_TARGET"
   return out
  end
  checkerTargetSeen[checkerTarget]=true
 end
 out.reviewedMappingCount=reviewed
 out.sourceFresh=sourceFresh(profile)

 local seen={}
 local rows=0
 for k,it in pairs(inv.items) do
  if type(k)~="number" or k~=math.floor(k) or k<1 or k>10000
    or type(it)~="table" then
   out.reason="INVALID_INVENTORY_ROW_SHAPE"
   return out
  end
  rows=rows+1
  if rows>10000 then
   out.reason="TOO_MANY_INVENTORY_ROWS"
   return out
  end
 end
 for i=1,rows do
  if type(inv.items[i])~="table" then
   out.reason="SPARSE_INVENTORY_ROWS"
   return out
  end
 end
 out.itemRowsObserved=rows
 local rawSeen={}
 local subtotal=0
 for _,it in ipairs(inv.items) do
  local raw=it.id
  if type(raw)~="string" or raw=="" or rawSeen[raw]
    or it.cat~="Weapons" or not positiveInteger(it.qty)
    or type(it.page)~="string"
    or (it.type~="Knife" and it.type~="Gun") then
   out.reason="INVALID_OR_DUPLICATE_RAW_ITEM"
   out.items={}
   out.priceRowsVerified=0
   out.verifiedSubtotal=nil
   return out
  end
  rawSeen[raw]=true
  local proof=REVIEWED_RAW_TO_CHECKER[raw]
  local valid=out.sourceFresh
    and proof and proof.page==it.page
    and proof.type==it.type
    and norm(proof.name)==norm(it.name)
    and it.checkerId==proof.checkerId
  if valid then
   local ok,r=pcall(profile.get,proof.page,proof.checkerId)
   if ok and type(r)=="table"
     and r.verified==true
     and r.page==proof.page and r.id==proof.checkerId
     and norm(r.name)==norm(proof.name)
     and finite(r.supremeValue) and r.supremeValue>0
     and finite(r.demand) and r.demand>=0 and r.demand<=11
     and type(r.stability)=="string" and r.stability~="" then
    local amount=r.supremeValue*it.qty
    if finite(amount) then
     out.items[#out.items+1]={
      -- No player's raw key, weapon name, or inventory fingerprint exported.
      page=proof.page,qty=it.qty,unitValue=r.supremeValue,
      evidenceId=proof.reviewedEvidenceId,
      evidenceVersion=proof.provenanceVersion,
     }
     out.priceRowsVerified=out.priceRowsVerified+1
     subtotal=subtotal+amount
     if not finite(subtotal) then
      out.items={}
      out.priceRowsVerified=0
      out.verifiedSubtotal=nil
      out.unverifiedItemRows=rows
      out.status="UNVERIFIED_SOURCE_OR_IDENTITY"
      out.reason="AGGREGATE_VALUE_OVERFLOW"
      return out
     end
    else valid=false end
   else valid=false end
  else
   valid=false
  end
  if not valid then
   out.unverifiedItemRows=out.unverifiedItemRows+1
  end
 end

 if out.priceRowsVerified>0 and finite(subtotal) then
  out.verifiedSubtotal=subtotal
 end
 -- Mixed/incomplete inventory NEVER receives a complete total. The snapshot
 -- publisher's "verified" row flag is not crosswalk identity proof.
 if out.sourceFresh and out.unverifiedItemRows==0
   and out.priceRowsVerified==rows and rows>0
   and finite(subtotal) -- finite unit prices can sum to infinity
   and inv.unmapped==0 and inv.unpriced==0 and inv.badQty==0 then
  out.completeValue=subtotal
  out.status="SOURCE_CURRENT_AND_REVIEWED_CROSSWALK_ONLY"
  out.reason="REVIEW_ONLY_NEVER_TRADING_AUTHORITY"
 else
  out.status=out.sourceFresh and "SOURCE_CURRENT_IDENTITY_UNVERIFIED"
                              or "SOURCE_EXPIRED_OR_UNTRUSTED"
  out.reason=out.sourceFresh and "RAW_TO_CHECKER_ID_NOT_REVIEWED"
                              or "SUPREME_SOURCE_NOT_FRESH"
 end
 -- Production trading must still rely on a *separate* code-reviewed
 -- safety/settlement controller even after a future crosswalk is reviewed.
 return out
end
return M
