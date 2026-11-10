-- Weapon-key reconciliation research (Stage101).
-- FULL two-sided client UpdateTrade raw key/qty/Weapons snapshot versus
-- original Stage9 physical GUI slots + current local Sync.Weapons metadata.
-- Candidate raw keys NEVER establish a server transaction, unique instance,
-- current market price or permission to trade/Accept.
-- Four offered slots per side, not four total copies: stacks use Stage9's
-- positive integer quantity bound (<= 1,000,000), without trading authority.
local M={}
local function finite(v)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function integer(v,lo,hi)
 return finite(v) and v==math.floor(v) and v>=lo and v<=hi
end
local function safeString(v,maxLen)
 return type(v)=="string" and #v>0 and #v<=maxLen and
   not v:find("[%c]") and #v:gsub("%s","")>0
end
local function normalize(v)
 if not safeString(v,128) then return nil end
 return v:gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," "):lower()
end
local function dense(v,maxLen)
 if type(v)~="table" or getmetatable(v)~=nil then return nil end
 local n=#v
 if n>maxLen then return nil end
 local count=0
 for k in pairs(v) do
  if not integer(k,1,n) then return nil end
  count=count+1
 end
 if n~=count then return nil end
 return n
end
local function exactFields(v,allowed,wanted)
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 local seen=0
 for k in pairs(v) do
  if not allowed[k] then return false end
  seen=seen+1
 end
 if seen~=wanted then return false end
 for k in pairs(allowed) do if rawget(v,k)==nil then return false end end
 return true
end
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local PLAYER={Player=true,Accepted=true,Offer=true}
local TRIPLE={[1]=true,[2]=true,[3]=true}
local PACK={n=true,[1]=true}
local function report(reason)
 return {
  schema="gingerscope-stage101-multislot-weapon-key-client-only-v1",
  status="INCONCLUSIVE",reason=reason or "INPUT_NOT_VERIFIED",
  readOnly=true,clientOnly=true,marketValueAuthority=false,
  inputClientEventCount=0,bothSidesReconciled=false,
  clientPerSlotRawKeyCandidateUnique=false,
  clientEventGuiQuantityMatched=false,
  clientEventGuiVariantMatched=false,
  currentClientMetadataMatchedHistoricalPublicRef=false,
  guiNameOnlySlotCount=0,guiRawTextSlotCount=0,
  ourMatchedSlotCount=0,theirMatchedSlotCount=0,
  sessionClientReferencesConsistent=false,
  guiTwoStableSamples=false,observedVisibleGuiTransition=false,
  eventSessionAssociationProven=false,callbackCausalityProven=false,
  serverTradeRevisionProven=false,rawItemIdConfirmed=false,
  uniqueWeaponInstanceProven=false,ownerSideSlotBound=false,
  authenticatedOwnedInventory=false,
  numericSupremeCheckerIdVerified=false,
  currentPricesVerified=false,priceForTradeVerified=false,
  sourcePublisherFresh=false,serverAttestation=false,
  serverCompletionProven=false,authorizesTrade=false,
  authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN"
 }
end
local function scopeOK(scope)
 return type(scope)=="table" and
    safeString(scope.jobId,180) and safeString(scope.session,180)
    and scope.root~=nil and scope.localPlayer~=nil and
    scope.partnerPlayer~=nil and
    not rawequal(scope.localPlayer,scope.partnerPlayer)
end
local function guiSide(side,parser)
 if type(side)~="table" or side.complete~=true or
    side.accepted~=false then return nil,"GUI_SIDE_OR_ACCEPT_UNVERIFIED" end
 local n=dense(side.slots,4)
 if not n then return nil,"GUI_SLOTS_NOT_DENSE_OR_TOO_MANY" end
 local out,used={}, {}
 for i=1,n do
  local slot=side.slots[i]
  if type(slot)~="table" or getmetatable(slot)~=nil or
     not integer(slot.slot,1,4) or used[slot.slot] or
     type(slot.chroma)~="boolean" or
     not normalize(slot.label) then
    return nil,"GUI_SLOT_INDEX_NAME_OR_VARIANT_INVALID"
  end
  used[slot.slot]=true
  local qty=parser(slot.amountText)
  if not integer(qty,1,1000000) then
   return nil,"GUI_SLOT_STACK_QUANTITY_UNVERIFIED"
  end
  if slot.rawId~=nil and slot.rawId~="" and
     not safeString(slot.rawId,128) then
   return nil,"GUI_SLOT_RAW_TEXT_INVALID"
  end
  out[#out+1]={index=slot.slot,quantity=qty,
     visibleName=normalize(slot.label),
     chroma=slot.chroma,rawText=slot.rawId or ""}
 end
 table.sort(out,function(a,b)return a.index<b.index end)
 return out
end
local function guiSnapshot(view,scope,parser)
 if type(view)~="table" or not finite(view.at) or view.at<0 or
    view.jobId~=scope.jobId or view.session~=scope.session or
    not rawequal(view.root,scope.root) or
    not rawequal(view.localPlayer,scope.localPlayer) or
    not rawequal(view.partnerPlayer,scope.partnerPlayer) then
  return nil,"GUI_CLIENT_SESSION_OR_PLAYER_CHANGED"
 end
 local raw=view.raw
 if type(raw)~="table" or raw.tradeOpen~=true or
    raw.contextOK~=true or raw.session~=scope.session then
  return nil,"GUI_EXACT_TRADE_CONTEXT_MISSING"
 end
 local ours,reason=guiSide(raw.our,parser)
 if not ours then return nil,reason end
 local theirs,why=guiSide(raw.their,parser)
 if not theirs then return nil,why end
 return {ours=ours,theirs=theirs}
end
local function sameGuiRows(a,b)
 if #a~=#b then return false end
 for i=1,#a do
  for _,k in ipairs({"index","quantity","visibleName","chroma","rawText"}) do
   if a[i][k]~=b[i][k] then return false end
  end
 end
 return true
end
local function catalogEntry(key,catalogue,registry)
 if not safeString(key,128) or
    type(catalogue)~="table" or type(registry)~="table" or
    registry.schema~="gingerscope-stage83-public-slug-registry-v1" or
    registry.authorizesTrade~=false or
    registry.authorizesAccept~=false or
    registry.currentPricesVerified~=false or
    type(registry.entries)~="table" then
  return nil
 end
 local fromPublic=rawget(registry.entries,key)
 local fromGame=rawget(catalogue,key)
 if type(fromPublic)~="table" or
    type(fromGame)~="table" or
    not safeString(fromPublic[1],128) or
    fromGame.ItemName~=fromPublic[1] or
    fromGame.ItemType~=fromPublic[2] or
    fromGame.Rarity~=fromPublic[3] or
    fromPublic[2]~="Knife" and fromPublic[2]~="Gun" or
    (fromPublic[3]~="Godly" and fromPublic[3]~="Ancient") or
    type(fromPublic[4])~="boolean" or
    (fromGame.Chroma==true)~=fromPublic[4] or
    (fromGame.Chroma~=nil and type(fromGame.Chroma)~="boolean") then
  return nil
 end
 local n=normalize(fromPublic[1])
 if not n then return nil end
 return {
  rawKey=key,normalizedName=n,chroma=fromPublic[4],
  itemType=fromPublic[2],rarity=fromPublic[3]
 }
end
local function eventSide(offer,catalogue,registry)
 local n=dense(offer,4)
 if not n then return nil,"EVENT_OFFER_NOT_DENSE_OR_TOO_MANY" end
 local out={}
 for i=1,n do
  local triple=offer[i]
  if not exactFields(triple,TRIPLE,3) or
     type(triple[1])~="string" or triple[3]~="Weapons" or
     not integer(triple[2],1,1000000) then
   return nil,"EVENT_WEAPON_TUPLE_INVALID"
  end
  local item=catalogEntry(triple[1],catalogue,registry)
  if not item then
   return nil,"EVENT_KEY_NOT_IN_SAME_CLIENT_PUBLIC_VARIANT_CATALOGUE"
  end
  out[#out+1]={key=triple[1],quantity=triple[2],
    visibleName=item.normalizedName,chroma=item.chroma,
    rarity=item.rarity,itemType=item.itemType}
 end
 return out
end
local function eventSnapshot(receipt,scope,catalogue,registry)
 if type(receipt)~="table" or
    receipt.jobId~=scope.jobId or receipt.session~=scope.session or
    not rawequal(receipt.root,scope.root) or
    not rawequal(receipt.localPlayer,scope.localPlayer) or
    not rawequal(receipt.partnerPlayer,scope.partnerPlayer) or
    not finite(receipt.at) or receipt.at<0 or
    not exactFields(receipt.packed,PACK,2) or
    receipt.packed.n~=1 then
  return nil,"CLIENT_EVENT_RECEIPT_SCOPE_OR_PACK_INVALID"
 end
 local p=receipt.packed[1]
 if not exactFields(p,ROOT,4) or
    not finite(p.LastOffer) or p.Locked~=false or
    not exactFields(p.Player1,PLAYER,3) or
    not exactFields(p.Player2,PLAYER,3) then
  return nil,"CLIENT_EVENT_ROOT_OR_ORIENTATION_INVALID"
 end
 local first=rawequal(p.Player1.Player,scope.localPlayer)
    and rawequal(p.Player2.Player,scope.partnerPlayer)
 local second=rawequal(p.Player2.Player,scope.localPlayer)
    and rawequal(p.Player1.Player,scope.partnerPlayer)
 if first==second or p.Player1.Accepted~=false or
    p.Player2.Accepted~=false then
  return nil,"CLIENT_EVENT_PLAYER_OR_ACCEPT_AMBIGUOUS"
 end
 local rawOurs=(first and p.Player1 or p.Player2).Offer
 local rawTheirs=(first and p.Player2 or p.Player1).Offer
 local ours,reason=eventSide(rawOurs,catalogue,registry)
 if not ours then return nil,reason end
 local theirs,why=eventSide(rawTheirs,catalogue,registry)
 if not theirs then return nil,why end
 if #ours+#theirs==0 then return nil,"CLIENT_EVENT_BOTH_SIDES_EMPTY" end
 return {ours=ours,theirs=theirs}
end
local function displayedName(slot)
 local n=slot.visibleName
 if slot.chroma and n:sub(1,7)~="chroma " then
  return "chroma "..n
 end
 return n
end
local function eventName(row)
 return row.chroma and ("chroma "..row.visibleName) or
   row.visibleName
end
-- Bipartite matching <=4 slots. Multiple permutations of IDENTICAL keys
-- are acceptable; distinct raw keys with the same visible name/variant
-- are AMBIGUOUS unless exactly one raw key can occupy each slot.
local function matchSide(gui,event)
 if #gui~=#event then return nil,"GUI_AND_EVENT_SLOT_COUNTS_DIFFER" end
 if #gui==0 then return {},nil,0,0 end
 local candidates={}
 local noId,withId=0,0
 for i,slot in ipairs(gui) do
  local matches={}
  for j,row in ipairs(event) do
   if slot.quantity==row.quantity and
      slot.chroma==row.chroma and
      displayedName(slot)==eventName(row) and
      (slot.rawText=="" or slot.rawText==row.key) then
    matches[#matches+1]=j
   end
  end
  if #matches==0 then
   return nil,"NO_CLIENT_EVENT_RAW_KEY_MATCH_FOR_GUI_SLOT"
  end
  candidates[i]=matches
  if slot.rawText=="" then noId=noId+1 else withId=withId+1 end
 end
 local seenKeys,solutions={},0
 local taken,assigned={},{ }
 local function visit(i)
  if i>#gui then
   solutions=solutions+1
   for x,j in ipairs(assigned) do
    local key=event[j].key
    seenKeys[x]=seenKeys[x] or {}
    seenKeys[x][key]=true
   end
   return
  end
  for _,j in ipairs(candidates[i]) do
   if not taken[j] then
    taken[j]=true;assigned[i]=j
    visit(i+1)
    assigned[i]=nil;taken[j]=nil
   end
  end
 end
 visit(1)
 if solutions==0 then
  return nil,"NO_COMPLETE_GUI_TO_EVENT_MATCH"
 end
 local binding={}
 for i,slot in ipairs(gui) do
  local keys,count=nil,0
  for key in pairs(seenKeys[i] or {}) do keys=key;count=count+1 end
  if count~=1 then
   return nil,"MULTIPLE_DISTINCT_CLIENT_RAW_KEYS_MATCH_GUI_SLOT"
  end
  binding[#binding+1]={
    index=slot.index,key=keys,quantity=slot.quantity,
    rawGuiTextPresent=slot.rawText~="",
    clientOnly=true
  }
 end
 return binding,nil,noId,withId
end
function M.inspect(input,catalogue,registry,stage9)
 local o=report()
 if type(input)~="table" or not scopeOK(input.scope) or
    not stage9 or type(stage9.parseQuantity)~="function" then
  o.reason="SCOPE_OR_ORIGINAL_QUANTITY_PARSER_UNAVAILABLE";return o
 end
 local scope=input.scope
 if input.eventCount~=1 then
  o.reason="CLIENT_EVENT_COUNT_NOT_EXACTLY_ONE";return o
 end
 o.inputClientEventCount=1
 local before,why=guiSnapshot(input.before,scope,stage9.parseQuantity)
 if not before then o.reason=why;return o end
 local after1,reason1=guiSnapshot(input.after1,scope,stage9.parseQuantity)
 if not after1 then o.reason=reason1;return o end
 local after2,reason2=guiSnapshot(input.after2,scope,stage9.parseQuantity)
 if not after2 then o.reason=reason2;return o end
 local receipt=input.receipt
 if type(receipt)~="table" or not finite(receipt.at) or
    not (input.before.at<receipt.at and
    receipt.at<=input.after1.at and input.after1.at<input.after2.at
    and receipt.at-input.before.at<=3 and
    input.after1.at-receipt.at<=3 and
    input.after2.at-input.after1.at>=.15 and
    input.after2.at-input.after1.at<=1) then
  o.reason="CLIENT_EVENT_GUI_TIMING_NOT_BOUNDED";return o
 end
 if not sameGuiRows(after1.ours,after2.ours) or
    not sameGuiRows(after1.theirs,after2.theirs) then
  o.reason="GUI_AFTER_SNAPSHOT_NOT_STABLE";return o
 end
 o.guiTwoStableSamples=true
 if sameGuiRows(before.ours,after1.ours) and
    sameGuiRows(before.theirs,after1.theirs) then
  o.reason="NO_NEW_VISIBLE_GUI_MUTATION";return o
 end
 o.observedVisibleGuiTransition=true
 local event,whyEvent=eventSnapshot(receipt,scope,catalogue,registry)
 if not event then o.reason=whyEvent;return o end
 o.sessionClientReferencesConsistent=true
 o.currentClientMetadataMatchedHistoricalPublicRef=true
 local ours,oursWhy,oursName,oursRaw=matchSide(after2.ours,event.ours)
 if not ours then o.reason="OUR_"..oursWhy;return o end
 local theirs,theirsWhy,theirsName,theirsRaw=matchSide(after2.theirs,event.theirs)
 if not theirs then o.reason="THEIR_"..theirsWhy;return o end
 o.guiNameOnlySlotCount=oursName+theirsName
 o.guiRawTextSlotCount=oursRaw+theirsRaw
 o.ourMatchedSlotCount=#ours
 o.theirMatchedSlotCount=#theirs
 o.clientEventGuiQuantityMatched=true
 o.clientEventGuiVariantMatched=true
 o.bothSidesReconciled=true
 o.clientPerSlotRawKeyCandidateUnique=true
 o.status="CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED"
 o.reason="CLIENT_RAW_KEY_CANDIDATES_ONLY_NO_SIGNED_TRADE_SESSION"
 -- The second result contains PRIVATE candidate raw keys. It MUST NOT be
 -- logged or fed to live offer execution or profit/Discord. It deliberately
 -- has no any permission booleans set true.
 return o,{
  clientOnly=true,validForAutomatedTrade=false,
  validForAutomatedAccept=false,eventCausalAttribution=false,
  serverTradeRevisionProven=false,rawKeyServerAuthenticated=false,
  marketValueAuthority=false,tradeOutcome="UNKNOWN",
  ours=ours,theirs=theirs
 }
end
return M
