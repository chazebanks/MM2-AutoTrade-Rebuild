-- S2 protected original P3/P4 -> Supreme-only C3/C4 RESEARCH adapter.
-- Uses the ORIGINAL bound lease, ORIGINAL ScannerAPI read and ORIGINAL P4
-- double-read GUI capture. Does not call the old two-publisher C3/C4 logic.
-- NO remotes, requests, offers, Accept, Decline, chat, hops, or telemetry.
-- Runtime publisher authentication and server item identity are NOT proven.
local M={}
local SCHEMA="gingerscope-system2-original-p3p4-supreme-only-adapter-v1"
local SOURCE="SUPREME_ONLY"
local CATALOG_SHA256="fd657db48c00c996705093dadc384c1a0ddd4630398826108b5585ca76c2eca4"
local SOURCE_GIT_BLOB="958038a6b22c43e8d0359cb15e6704bc84253430"
local PLACE=142823291
local MAX_SCAN_SECONDS=10
local MAX_OWN_AGE=30
local function finite(x)
 return type(x)=="number" and x==x and
  x~=math.huge and x~=-math.huge
end
local function nat(x)
 return finite(x) and x==math.floor(x) and x>=1 and x<=100000
end
local function userId(n)
 return finite(n) and n==math.floor(n) and n>0 and n<10^16
end
local function rawKey(x)
 return type(x)=="string" and #x>=1 and #x<=90 and
  x:match("^[A-Za-z0-9_]+$")~=nil
end
local function normalized(name)
 if type(name)~="string" or #name<1 or #name>160 then return nil end
 local s=name:lower():gsub("^%s*chroma%s+",""):gsub("[^%w]","")
 return #s>0 and s or nil
end
local function fail(reason)
 return {schema=SCHEMA,status="BLOCKED",reason=reason,
  valueSource=SOURCE,readOnly=true,clientOnly=true,researchOnly=true,
  gameItemInstancesAuthenticated=false,serverTradeSettlementProven=false,
  actualDeviceVerified=false,publisherBytesAuthenticatedOnClient=false,
  partnerWillingnessVerified=false,empiricalLiquidity="UNKNOWN",
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayUseForStrategyLearning=false,mayReportProfit=false,
  maySendDiscordWebhook=false}
end
local function sameCounts(a,b)
 if type(a)~="table" or type(b)~="table" then return false end
 for k,v in pairs(a) do if b[k]~=v then return false end end
 for k,v in pairs(b) do if a[k]~=v then return false end end
 return true
end
local function sameSlots(a,b)
 if type(a)~="table" or type(b)~="table" or #a~=#b then return false end
 for i,v in ipairs(a) do
  local y=b[i]
  if not y or v.slot~=y.slot or v.rawId~=y.rawId or
    v.rawIdObserved~=y.rawIdObserved or v.label~=y.label or
    v.amountText~=y.amountText or v.chromaTag~=y.chromaTag then
   return false
  end
 end
 return true
end
local function sameFrame(a,b)
 return type(a)=="table" and type(b)=="table" and
  a.jobId==b.jobId and a.tradeLeaseId==b.tradeLeaseId and
  a.partnerUserId==b.partnerUserId and
  a.ourAccepted==b.ourAccepted and
  a.theirAccepted==b.theirAccepted and
  a.clientRawCaptureSignature==b.clientRawCaptureSignature and
  sameSlots(a.ourSlots,b.ourSlots) and
  sameSlots(a.theirSlots,b.theirSlots)
end
local function findMeta(sync,id)
 local a=type(sync.Weapons)=="table" and sync.Weapons[id] or nil
 local b=type(sync.Item)=="table" and sync.Item[id] or nil
 if (a~=nil and type(a)~="table") or (b~=nil and type(b)~="table") then
  return nil,"GAME_METADATA_MALFORMED" end
 if not a and not b then return nil,"RAW_GAME_KEY_ABSENT" end
 if a and b then
  for _,field in ipairs({"ItemName","Name","ItemType","Rarity","Chroma",
    "Tradable","CanTrade","Untradable","NonTradable","EvoIndex","EvoBaseID"}) do
   if a[field]~=b[field] then
    return nil,"GAME_METADATA_WEAPONS_ITEM_CONFLICT" end
  end
 end
 return a or b,nil
end
local function eligible(meta)
 return type(meta)=="table" and
   (meta.ItemType=="Knife" or meta.ItemType=="Gun") and
   (meta.Rarity=="Ancient" or meta.Rarity=="Godly") and
   meta.Tradable~=false and meta.CanTrade~=false and
   meta.NonTradable~=true and meta.Untradable~=true and
   meta.EvoIndex==nil and meta.EvoBaseID==nil
end
local function boundMeta(sync,id,byKey)
 local m,why=findMeta(sync,id)
 if not m then return nil,why end
 if not eligible(m) then return nil,"GAME_ITEM_NOT_ELIGIBLE" end
 local row=byKey[id]
 if not row then return nil,"SUPREME_ONLY_RAW_GAME_KEY_NOT_IN_189" end
 local chroma=m.Chroma==true
 if ((row.category=="chroma")~=chroma) or
    (row.category=="ancient" and m.Rarity~="Ancient") or
    (row.category=="godly" and m.Rarity~="Godly") or
    not normalized(m.ItemName or m.Name) or
    normalized(m.ItemName or m.Name)~=normalized(row.officialName) then
  return nil,"GAME_METADATA_SUPREME_NAME_RARITY_OR_CHROMA_MISMATCH" end
 return m,nil
end
local function numAmount(s)
 if type(s)~="string" or #s>20 then return nil end
 if s=="" then return 1 end
 local t=s:gsub("^%s+",""):gsub("%s+$","")
 t=t:gsub("^[xX]","")
 if #t<1 or #t>7 or not t:match("^%d+$") then return nil end
 local number=tonumber(t)
 return nat(number) and number or nil
end
local function parsedSlots(list,byKey,sync,ours,own)
 if type(list)~="table" or #list>4 then
  return nil,"GUI_EXCEEDS_FOUR_PHYSICAL_SLOTS" end
 local result,used={},{}
 for _,s in ipairs(list) do
  if type(s)~="table" or not nat(s.slot) or s.slot>4 or
    not rawKey(s.rawId) or s.rawIdObserved~=true or
    used[s.slot] or used[s.rawId] or
    type(s.chromaTag)~="boolean" or
    type(s.label)~="string" then
   return nil,"GUI_RAW_ATTRIBUTE_ID_MISSING_AMBIGUOUS_OR_DUPLICATED" end
  used[s.slot]=true;used[s.rawId]=true
  local n=numAmount(s.amountText)
  if not n then return nil,"GUI_QUANTITY_NOT_PROVEN" end
  local meta,why=boundMeta(sync,s.rawId,byKey)
  if not meta then return nil,why end
  local row=byKey[s.rawId]
  local chroma=meta.Chroma==true
  if normalized(s.label)~=normalized(row.officialName) or
    ((s.chromaTag or s.label:lower():match("^%s*chroma%s+")~=nil)~=chroma) then
   return nil,"GUI_VISIBLE_LABEL_OR_CHROMA_CONFLICT" end
  if ours and (s.rawId=="Gingerscope" or n>(own[s.rawId] or 0)) then
   return nil,"GUI_OWNED_COUNT_OR_TARGET_OUTBOUND_INVALID" end
  result[#result+1]={id=s.rawId,quantity=n,slot=s.slot}
 end
 table.sort(result,function(a,b)return a.slot<b.slot end)
 return result,nil
end
local function owns(scanner,byKey,sync)
 if type(scanner)~="table" or type(scanner.items)~="table" or
   type(scanner.seen)~="table" or type(scanner.fingerprint)~="string" or
   scanner.unmapped~=0 or scanner.badQty~=0 or
   not finite(scanner.rawOwned) or scanner.rawOwned<0 then
  return nil,"ORIGINAL_OWN_SCANNER_CENSUS_INVALID" end
 local raw,serial,sourceTotal={}, {},0
 for _,s in ipairs(scanner.seen) do
  if type(s)~="string" then return nil,"RAW_OWN_FINGERPRINT_MALFORMED" end
  local id,qty=s:match("^(.-)x(%d+)$")
  local n=tonumber(qty)
  if not rawKey(id) or not nat(n) or raw[id] then
   return nil,"RAW_OWN_FINGERPRINT_DUPLICATE_OR_INVALID" end
  raw[id]=n;serial[#serial+1]=s;sourceTotal+=n
 end
 table.sort(serial)
 if table.concat(serial,"|")~=scanner.fingerprint or
    sourceTotal~=scanner.rawOwned then
  return nil,"RAW_OWN_FINGERPRINT_TOTAL_MISMATCH" end
 local owned={}
 for _,it in ipairs(scanner.items) do
  if type(it)~="table" or it.cat~="Weapons" or
    not rawKey(it.id) or not nat(it.qty) or
    owned[it.id]~=nil or raw[it.id]~=it.qty then
   return nil,"ORIGINAL_ELIGIBLE_SCANNER_ROW_INVALID" end
  local meta,why=boundMeta(sync,it.id,byKey)
  if not meta then return nil,why end
  if it.page~=byKey[it.id].category or
    it.type~=meta.ItemType or
    normalized(it.name)~=normalized(byKey[it.id].officialName) then
   return nil,"ORIGINAL_SCANNER_RAW_WEAPON_VARIANT_MISMATCH" end
  owned[it.id]=it.qty
 end
 for id,n in pairs(raw) do
  local meta,why=findMeta(sync,id)
  if not meta then return nil,why end
  if eligible(meta) then
   if not byKey[id] or owned[id]~=n then
    return nil,"ORIGINAL_SCANNER_ELIGIBLE_WEAPON_OMITTED" end
   local m,issue=boundMeta(sync,id,byKey)
   if not m then return nil,issue end
  elseif owned[id]~=nil then
   return nil,"ORIGINAL_SCANNER_NONTRADABLE_INCLUDED" end
 end
 if next(owned)==nil then return nil,"SUPREME_ONLY_NO_OWNED_ELIGIBLE_WEAPONS" end
 return owned,nil
end
local function saneScope(s)
 return type(s)=="table" and type(s.jobId)=="string" and
   #s.jobId>=8 and type(s.leaseId)=="string" and
   #s.leaseId>=8 and userId(s.localUserId) and
   userId(s.partnerUserId) and
   s.localUserId~=s.partnerUserId and s.root~=nil
end
function M.new(c)
 if type(c)~="table" or
   c.consentedToReadOnlyInventoryRpc~=true or
   type(c.hostHandle)~="table" or
   type(c.hostHandle.isBoundSession)~="function" or
   type(c.hostHandle.status)~="function" or
   c.hostHandle.readOnly~=true or
   c.hostHandle.clientOnly~=true or
   c.hostHandle.authorizesTrade~=false or
   c.hostHandle.authorizesOffer~=false or
   c.hostHandle.authorizesAccept~=false or
   not saneScope(c.hostHandle.scope) or
   c.game==nil or c.players==nil or
   type(c.sync)~="table" or
   type(c.scannerApi)~="table" or
   type(c.scannerApi.getOwnInventory)~="function" or
   type(c.captureAdapter)~="table" or
   type(c.captureAdapter.new)~="function" or
   type(c.supremeCore)~="table" or
   type(c.supremeCore.sourceStatus)~="function" or
   type(c.supremeCore.review)~="function" or
   type(c.sourceBytes)~="string" or
   type(c.sha256)~="function" or
   type(c.utcNow)~="function" or
   type(c.monoNow)~="function" then
  return nil,"SUPREME_ONLY_PROTECTED_INPUT_OR_INVENTORY_CONSENT_MISSING" end
 -- Validate the exact UTF-8 publisher catalog source bytes, not an
 -- untrusted claimed Git blob SHA or caller-provided decoded price table.
 -- The hash callback must come from an independently reviewed host module.
 if #c.sourceBytes<1000 or #c.sourceBytes>150000 then
  return nil,"SUPREME_ONLY_SOURCE_BYTE_LENGTH_INVALID" end
 local hashed,digest=pcall(c.sha256,c.sourceBytes)
 if not hashed or type(digest)~="string" then
  return nil,"SUPREME_ONLY_SOURCE_SHA256_VERIFICATION_FAILED" end
 local activeSourceGitBlob,activeCapture
 if digest==CATALOG_SHA256 then
  activeSourceGitBlob=SOURCE_GIT_BLOB;activeCapture=1794951678
 elseif digest=="3f0996b9ac20f3c4689519e1faf65e83796bce8b2d6afe6ad4d2e705ffca525e" then
  activeSourceGitBlob="b6f5c1eec48d59b422f53baa4d83a54ce6837b72";activeCapture=1795586999
 else
  return nil,"SUPREME_ONLY_SOURCE_SHA256_VERIFICATION_FAILED" end
 local httpOK,http=pcall(function()return c.game:GetService("HttpService")end)
 if not httpOK or not http or type(http.JSONDecode)~="function" then
  return nil,"SUPREME_ONLY_VERIFIED_SOURCE_JSONDECODER_UNAVAILABLE" end
 local decoded,catalog=pcall(function()return http:JSONDecode(c.sourceBytes)end)
 if not decoded or type(catalog)~="table" then
  return nil,"SUPREME_ONLY_VERIFIED_SOURCE_JSON_INVALID" end
 local scope=c.hostHandle.scope
 local function live()
  if c.game.PlaceId~=PLACE or tostring(c.game.JobId)~=scope.jobId then
   return false,"ORIGINAL_MM2_PLACE_OR_JOB_CHANGED" end
  local ok,service=pcall(function()return c.game:GetService("Players")end)
  if not ok or service~=c.players then
   return false,"ORIGINAL_PLAYERS_SERVICE_NOT_BOUND" end
  local localPlayer=c.players.LocalPlayer
  if not localPlayer or localPlayer.UserId~=scope.localUserId or
    localPlayer.Parent~=c.players then
   return false,"ORIGINAL_LOCAL_ACCOUNT_CHANGED" end
  local pg=localPlayer:FindFirstChildOfClass("PlayerGui")
  if pg==nil then return false,"ORIGINAL_PLAYER_GUI_MISSING" end
  local yes,partner=pcall(c.players.GetPlayerByUserId,c.players,scope.partnerUserId)
  if not yes or not partner or partner.Parent~=c.players or
    partner.UserId~=scope.partnerUserId or partner==localPlayer then
   return false,"ORIGINAL_PARTNER_CHANGED_OR_DEPARTED" end
  local good,isCurrent=pcall(c.hostHandle.isBoundSession)
  local okStatus,status=pcall(c.hostHandle.status)
  if not good or isCurrent~=true or not okStatus or type(status)~="table" or
    status.schema~="gingerscope-c9-original-p3-host-lease-v1" or
    status.status~="ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND" or
    status.readOnly~=true or status.clientOnly~=true or
    status.authorizesTrade~=false or
    status.authorizesOffer~=false or status.authorizesAccept~=false or
    status.serverCompletionProven~=false then
   return false,"ORIGINAL_CLIENT_READ_ONLY_LEASE_NOT_CURRENT" end
  return true,nil
 end
 local function now()
  local ok,t=pcall(c.utcNow)
  if not ok or not finite(t) then return nil,"CURRENT_UTC_CLOCK_INVALID" end
  local proof,source=pcall(c.supremeCore.sourceStatus,catalog,activeSourceGitBlob,t)
  if not proof or type(source)~="table" or
    source.status~="SUPREME_ONLY_RESEARCH_SOURCE_CHECKED" or
    source.valueSource~="SUPREME_ONLY" or
    source.authorizesTrade~=false or source.authorizesOffer~=false or
    source.authorizesAccept~=false then
   return nil,"SUPREME_ONLY_SOURCE_EXPIRED_OR_UNVERIFIED" end
  return t,nil
 end
 local catalogRows={}
 for _,row in ipairs(catalog.rows or {}) do
  if type(row)~="table" or
    not rawKey(row.rawGameKeyCandidate) or
    catalogRows[row.rawGameKeyCandidate] then
   return nil,"SUPREME_ONLY_CATALOG_RAW_KEYS_INVALID" end
  -- Absolutely no fallback source/extra price column, including a hidden
  -- second market price field smuggled in via host-provided JSON.
  for k in pairs(row) do
   if k~="rawGameKeyCandidate" and k~="category" and
      k~="officialName" and k~="officialItemId" and
      k~="supremeListed" and k~="supremeDemand" and
      k~="supremeStability" and k~="outgoingGingerscopeProtected" then
    return nil,"SUPREME_ONLY_EXTRA_CATALOG_FIELD_FORBIDDEN" end
  end
  catalogRows[row.rawGameKeyCandidate]=row
 end
 local firstSource,sourceWhy=now()
 if not firstSource then return nil,sourceWhy end
 local obj={}
 local adapter,why=c.captureAdapter.new({
  game=c.game,players=c.players,scope=scope,
  isBoundSession=function()
   local active=live()
   return active==true
  end})
 if not adapter or type(adapter.capture)~="function" then
  return nil,"ORIGINAL_P4_CAPTURE_ADAPTER_UNAVAILABLE" end
 local function scan()
  local ready,boundWhy=live()
  if not ready then return nil,boundWhy end
  local fresh,sourceWhy=now()
  if not fresh then return nil,sourceWhy end
  local okStart,start=pcall(c.monoNow)
  local ok,inventory=pcall(c.scannerApi.getOwnInventory)
  local okFinish,finish=pcall(c.monoNow)
  if not okStart or not okFinish or not finite(start) or
    not finite(finish) or start<0 or finish<start or
    finish-start>MAX_SCAN_SECONDS then
   return nil,"ORIGINAL_SCANNER_READ_DURATION_UNVERIFIED" end
  if not ok or type(inventory)~="table" then
   return nil,"ORIGINAL_SCANNER_READ_FAILED" end
  local owned,err=owns(inventory,catalogRows,c.sync)
  if not owned then return nil,err end
  local still,currentWhy=live()
  if not still then return nil,currentWhy end
  local stillFresh,sourceEndWhy=now()
  if not stillFresh then return nil,sourceEndWhy end
  return {counts=owned,at=finish},nil
 end
 local function frame()
  local ready,boundWhy=live()
  if not ready then return nil,boundWhy end
  local ok,got=pcall(adapter.capture)
  if not ok or type(got)~="table" then return nil,"ORIGINAL_P4_READ_FAILED" end
  if got.status=="BLOCKED" then return nil,"ORIGINAL_P4_CAPTURE_BLOCKED" end
  if got.doubleReadStable~=true or got.clientOnly~=true or
     got.contextOK~=true or got.tradeOpen~=true or got.rootBound~=true or
     got.jobId~=scope.jobId or got.tradeLeaseId~=scope.leaseId or
     got.partnerUserId~=scope.partnerUserId or
     type(got.clientRawCaptureSignature)~="string" or
     type(got.ourAccepted)~="boolean" or
     type(got.theirAccepted)~="boolean" then
   return nil,"ORIGINAL_P4_CLIENT_SESSION_OR_GUI_UNVERIFIED" end
  local yes,issue=live()
  if not yes then return nil,issue end
  return got,nil
 end
 function obj:preview(options)
  if type(options)~="table" or #options<1 or #options>12 then
   return fail("SUPREME_ONLY_RESEARCH_OPTIONS_REQUIRED") end
  local before,reason=scan()
  if not before then return fail(reason) end
  local seen,why=frame()
  if not seen then return fail(why) end
  local ours,ownWhy=parsedSlots(seen.ourSlots,catalogRows,c.sync,true,before.counts)
  local their,theirWhy=parsedSlots(seen.theirSlots,catalogRows,c.sync,false,before.counts)
  if not ours or not their then return fail(ownWhy or theirWhy) end
  -- No hypothetical alternatives disguised as the current trade.
  -- Both parties must match the exact authenticated physical GUI stacks.
  local function sameOffer(requested,physical)
   if type(requested)~="table" or #requested~=#physical then return false end
   local needed,seen={},{}
   for _,x in ipairs(physical) do
    if needed[x.id] then return false end
    needed[x.id]=x.quantity
   end
   for _,x in ipairs(requested) do
    if type(x)~="table" or not rawKey(x.id) or
       not nat(x.quantity) or seen[x.id] or
       needed[x.id]~=x.quantity then return false end
    for key in pairs(x) do
     if key~="id" and key~="quantity" then return false end
    end
    seen[x.id]=true
   end
   return true
  end
  for _,option in ipairs(options) do
   if type(option)~="table" or
      option.kind~="HYPOTHETICAL_RESEARCH_ONLY" or
      option.valueSource~=SOURCE then
    return fail("SUPREME_ONLY_OPTION_SOURCE_OR_SHAPE_INVALID") end
   for key in pairs(option) do
    if key~="kind" and key~="valueSource" and
       key~="give" and key~="receive" then
     return fail("SUPREME_ONLY_OPTION_EXTRA_PRICE_FIELDS_FORBIDDEN") end
   end
   if not sameOffer(option.receive,their) then
    return fail("OPPONENT_ITEM_NOT_EXACTLY_PRESENT_IN_BOUND_GUI") end
   if not sameOffer(option.give,ours) then
    return fail("OWN_ITEM_NOT_EXACTLY_PRESENT_IN_BOUND_GUI") end
  end
  local quoteClock,quoteWhy=now()
  if not quoteClock then return fail(quoteWhy) end
  local success,preview=pcall(c.supremeCore.review,catalog,activeSourceGitBlob,
      quoteClock,before.counts,options)
  if not success or type(preview)~="table" or
    preview.schema~="gingerscope-system2-native-supreme-only-bilateral-research-v1" or
    preview.status~="SUPREME_ONLY_NATIVE_RESEARCH_NOT_EXECUTABLE" or
    preview.valueSource~=SOURCE or
    preview.authorizesTrade~=false or preview.authorizesOffer~=false or
    preview.authorizesAccept~=false or
    preview.mayReportProfit~=false or
    preview.mayUseForStrategyLearning~=false or
    type(preview.hypotheticalAlternatives)~="table" or
    #preview.hypotheticalAlternatives~=#options then
   return fail("SUPREME_ONLY_EVALUATOR_UNAUTHORIZED_OR_BLOCKED") end
  local second,changed=frame()
  if not second then return fail(changed) end
  if not sameFrame(seen,second) then
   return fail("ORIGINAL_P4_OFFER_ACCEPTANCE_OR_STACK_CHANGED") end
  local after,inventoryWhy=scan()
  if not after then return fail(inventoryWhy) end
  if not sameCounts(before.counts,after.counts) then
   return fail("ORIGINAL_C3_OWN_CENSUS_CHANGED_DURING_STRATEGY") end
  local last,lastWhy=frame()
  if not last then return fail(lastWhy) end
  if not sameFrame(second,last) then
   return fail("ORIGINAL_P4_CHANGED_AFTER_C3_REFRESH") end
  local fresh,sourceWhy=now()
  if not fresh then return fail(sourceWhy) end
  local bound,scopeWhy=live()
  if not bound then return fail(scopeWhy) end
  -- Never return original account/partner/JobId/lease or private inventory.
  local result={}
  for i,r in ipairs(preview.hypotheticalAlternatives) do
   result[#result+1]={
    index=i,status=r.status,
    outgoingSupremeListedValue=r.outgoingSupremeListedValue,
    incomingSupremeListedValue=r.incomingSupremeListedValue,
    supremeListedGain=r.supremeListedGain,
    demandIncoming=r.demandIncoming,
    demandOutgoing=r.demandOutgoing,
    reviewedAsClientOnly=true,tradeActionable=false}
  end
  return {schema=SCHEMA,
   status="SUPREME_ONLY_PROTECTED_C3_P4_SHADOW_OBSERVED",
   valueSource=SOURCE,sourceAgeSeconds=math.floor(fresh-activeCapture),
   hypotheticalAlternatives=result,
   originalOfferSidesPhysicallyObserved=true,
   clientOfferChangedDuringResearch=false,
   originalGameInstanceIdentityServerProven=false,
   publisherBytesAuthenticatedOnClient=false,
   realPlayerAcceptanceOrSettlementProven=false,
   readOnly=true,clientOnly=true,researchOnly=true,
   authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
   maySendDiscordWebhook=false,mayReportProfit=false,
   mayUseForStrategyLearning=false}
 end
 return obj,nil
end
return M
