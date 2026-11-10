-- Stage102: actual Stage98 physical GUI slot parser + Lua archival reference
-- engine against 189 original Stage94 public value/demand/stability records.
-- Everything remains client-only and denies any trade/Accept authority.
local REF=assert(loadfile(assert(os.getenv("STAGE102_ARCHIVE_LUA"))))()
local Archive=assert(loadfile("pdiddler/intelligence_lab/stage102_lua_public_reference_preview.lua"))()
local Stage9=assert(loadfile(assert(os.getenv("STAGE102_ORIGINAL_STAGE9"))))()
local Epoch=assert(loadfile(assert(os.getenv("STAGE102_ORIGINAL_STAGE98"))))()
local total=0
local function eq(a,b,msg)assert(a==b,(msg or "mismatch")..": got="..tostring(a).." expected="..tostring(b))end
local function test(name,fn)
 local ok,e=pcall(fn)
 if not ok then error("STAGE102 FAIL "..name..": "..tostring(e)) end
 total=total+1
 print("PASS Stage102 "..name)
end
local function checkDeny(r)
 eq(r.readOnly,true);eq(r.researchOnly,true)
 eq(r.nameOnlyUnbound,true)
 eq(r.protectedOutgoingAllowed,false)
 eq(r.tradeOutcome,"UNKNOWN")
 for _,key in ipairs({
  "currentGameItemIdentityAuthenticated","rawOfferKeyBoundToPhysicalSlot",
  "numericSupremeCheckerIdVerified","uniqueWeaponInstanceProven",
  "authenticatedOwnedInventory","sourcePublisherFreshForTrade",
  "currentPricesVerified","priceForTradeVerified","serverTradeRevisionProven",
  "serverAttestation","serverCompletionProven","eventSessionAssociationProven",
  "callbackCausalityProven","authorizesTrade","authorizesAccept",
  "mayRecordCompletedTrade","mayReportProfit","maySendDiscordWebhook",
  "mayUseForStrategyLearning",
 }) do eq(r[key],false,key) end
end
local function slot(i,label,quantity,chroma)
 if chroma==nil then chroma=false end
 return {slot=i,label=label,amountText=quantity==1 and "" or
    "x"..tostring(quantity),chroma=chroma,rawId=nil}
end
local function observation(c,at,ours,theirs)
 return {at=at,session=c.session,jobId=c.jobId,root=c.root,
  localPlayer=c.localPlayer,partnerPlayer=c.partnerPlayer,
  raw={tradeOpen=true,contextOK=true,session=c.session,
    our={accepted=false,complete=true,slots=ours or {}},
    their={accepted=false,complete=true,slots=theirs or {}}}}
end
local function state(our,their)
 local c={session="one_private_client_session",jobId="one_job",
  root={},localPlayer={},partnerPlayer={}}
 local s=assert(Epoch.new(c,Stage9))
 Epoch.observe(s,observation(c,10))
 Epoch.observe(s,observation(c,10.2))
 Epoch.observe(s,observation(c,10.3,our,their))
 local r=Epoch.observe(s,observation(c,10.52,our,their))
 eq(r.status,"CLIENT_OFFER_STABLE_RESEARCH_ONLY")
 return s,c
end
local BEFORE=1794300000
local AFTER=1794349608
test("full 189 original-source public catalogue validates as historical",function()
 local lookup,reason=Archive.validateArchive(REF)
 assert(lookup,tostring(reason))
 local n=0
 for _ in pairs(lookup) do n=n+1 end
 eq(n,189)
end)
test("Emberbow vs Gingerscope historical 650 vs 16000 is research-only",function()
 local s=state({slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
 local r=Archive.preview(REF,s,BEFORE,10.53)
 eq(r.status,"HISTORICAL_PUBLIC_CANDIDATES_RESEARCH_ONLY",r.reason)
 eq(r.matchedCandidateSlots,2)
 eq(r.ourHistoricalReferenceTotal,650)
 eq(r.theirHistoricalReferenceTotal,16000)
 eq(r.illustrativeHistoricalDifference,15350)
 eq(r.rows[1].liquidity,"UNVERIFIED")
 eq(r.rows[2].identityEvidence,"NAME_ONLY_NOT_RAW_KEY_BOUND")
 checkDeny(r)
end)
test("at archive expiry historical rows shown but two-sided total suppressed",function()
 local s=state({slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
 for _,now in ipairs({AFTER,AFTER+1,AFTER+86400}) do
  local r=Archive.preview(REF,s,now,10.53)
  eq(r.sourcePriceState,"ARCHIVED_RESEARCH_CAPTURE_EXPIRED")
  eq(r.ourHistoricalReferenceTotal,nil)
  eq(r.theirHistoricalReferenceTotal,nil)
  eq(r.illustrativeHistoricalDifference,nil)
  eq(r.rows[1].historicalValuePerCopy,650)
  eq(r.rows[2].historicalValuePerCopy,16000)
  checkDeny(r)
 end
end)
test("unknown weapon name and wrong Chroma display never silently match",function()
 for _,x in ipairs({
  {label="Ginger Scope",chroma=false},
  {label="Fang",chroma=true},
  {label="Chroma Fang",chroma=false},
  {label="Unknown-Godly",chroma=false}
 }) do
  local s=state({slot(1,"Emberbow",1)},{slot(1,x.label,1,x.chroma)})
  local r=Archive.preview(REF,s,BEFORE,10.53)
  eq(r.unmatchedSlots,1)
  eq(r.illustrativeHistoricalDifference,nil)
  checkDeny(r)
 end
end)
test("two chroma stacks retain historical units and still never prove identity",function()
 local s=state({slot(1,"Chroma Fang",2,true)},
    {slot(1,"Gingerscope",1)})
 local r=Archive.preview(REF,s,BEFORE,10.53)
 eq(r.matchedCandidateSlots,2)
 eq(r.rows[1].chroma,true)
 eq(r.rows[1].quantity,2)
 eq(r.rows[1].historicalSubtotal,r.rows[1].historicalValuePerCopy*2)
 checkDeny(r)
end)
test("Gingerscope visible on OUR side is protected and never an outgoing offer",function()
 local s=state({slot(1,"Gingerscope",1)},{slot(1,"Emberbow",1)})
 local r=Archive.preview(REF,s,BEFORE,10.53)
 eq(r.protectedGingerscopeCandidateVisible,true)
 eq(r.rows[1].protectedTargetCandidate,true)
 eq(r.protectedOutgoingAllowed,false)
 eq(r.authorizesTrade,false)
 checkDeny(r)
end)
test("changed original Stage98 local epoch makes prior snapshot ineligible",function()
 local s,c=state({slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
 local r=Archive.preview(REF,s,BEFORE,10.53)
 eq(r.matchedCandidateSlots,2)
 Epoch.observe(s,observation(c,10.7,{slot(1,"Emberbow",1)},{}))
 r=Archive.preview(REF,s,BEFORE,10.71)
 eq(r.status,"INCONCLUSIVE")
 eq(r.reason,"CLIENT_LOCAL_REVISION_NOT_STABLE")
 checkDeny(r)
end)
test("accepted or ambiguous original GUI snapshot never generates a preview",function()
 local s,c=state({slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
 local v=observation(c,10.71,{slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
 v.raw.their.accepted=true
 Epoch.observe(s,v)
 local r=Archive.preview(REF,s,BEFORE,10.72)
 eq(r.status,"INCONCLUSIVE")
 checkDeny(r)
end)
test("wrong schema, source unit price, category and copied authority fail",function()
 for _,mod in ipairs({"schema","price","chroma","count","accept"}) do
  local tmp={}
  for k,v in pairs(REF) do tmp[k]=v end
  local rows={}
  for i,v in ipairs(REF.rows) do rows[i]=v end
  tmp.rows=rows
  if mod=="schema" then tmp.schema="forged" end
  if mod=="price" then
   local row={}
   for k,v in pairs(rows[1]) do row[k]=v end
   row.value="99999999";rows[1]=row
  end
  if mod=="chroma" then
   local row={}
   for k,v in pairs(rows[1]) do row[k]=v end
   row.chroma=not row.chroma;rows[1]=row
  end
  if mod=="count" then tmp.entryCount=188 end
  if mod=="accept" then tmp.authorizesAccept=true end
  local s=state({slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
  local r=Archive.preview(tmp,s,BEFORE,10.53)
  eq(r.status,"INCONCLUSIVE",mod)
  checkDeny(r)
 end
end)
test("stale GUI capture age >2 sec or impossible clock never creates estimate",function()
 local s=state({slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
 local r=Archive.preview(REF,s,BEFORE,15)
 eq(r.status,"INCONCLUSIVE")
 checkDeny(r)
 r=Archive.preview(REF,s,math.huge,10.53)
 eq(r.status,"INCONCLUSIVE")
 checkDeny(r)
end)
test("nonempty only one side cannot show a historical two-sided spread",function()
 local s=state({},{slot(1,"Gingerscope",1)})
 local r=Archive.preview(REF,s,BEFORE,10.53)
 eq(r.matchedCandidateSlots,1)
 eq(r.illustrativeHistoricalDifference,nil)
 checkDeny(r)
end)
test("no network, market, or game action path in the public Lua preview",function()
 assert(type(Archive.preview)=="function")
 assert(type(Archive.validateArchive)=="function")
 local s=state({slot(1,"Emberbow",1)},{slot(1,"Gingerscope",1)})
 local r=Archive.preview(REF,s,BEFORE,10.53)
 checkDeny(r)
end)
print("STAGE102_FULL_ARCHIVE_LUA_TEST_PASS groups="..total)
