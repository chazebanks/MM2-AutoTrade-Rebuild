-- System2 C6: passive, local-only speaker-bound MM2 trade-chat evidence.
-- Requires actual TextChatMessage.TextSource.UserId in runtime adapter.
-- Never sends chat, offers, trade requests, final Accept or Discord.
-- Never converts a phrase into personality, verified willingness, probability,
-- completed trade or a learning label. Message text is never returned or stored.
local M={}
local SCHEMA="gingerscope-system2-partner-intent-readonly-v1"
local CONTEXT="gingerscope-system2-local-bilateral-context-v1"
local MARKET="gingerscope-system2-exact-market-gamekey-crosswalk-v1"
local WINDOW=12
local TTL=120
local MAX_EVENTS=48
local function denied(reason)
 return {schema=SCHEMA,status="BLOCKED",reason=reason,clientOnly=true,
   readOnly=true,personalReplyProven=false,verifiedPartnerPreference=false,
   verifiedTradeAcceptance=false,tradeOutcome="UNKNOWN",
   mayUseForStrategyLearning=false,maySendDiscordWebhook=false,
   authorizesChat=false,authorizesTrade=false,authorizesOffer=false,
   authorizesAccept=false,estimatedAcceptProbability=nil}
end
local function finite(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function validId(v)
 return finite(v) and v==math.floor(v) and v>0 and v<10^16
end
local function clean(t)
 if type(t)~="string" or #t<1 or #t>240 then return nil end
 local s=t:lower():gsub("[^%w]+"," "):gsub("%s+"," ")
 return " "..s:gsub("^%s+",""):gsub("%s+$","").." "
end
local function phrase(p)
 if type(p)~="string" or #p<1 or #p>120 then return nil end
 local s=clean(p)
 return s and s:sub(2,-2) or nil
end
local function validSource(m)
 if type(m)~="table" or m.schema~=MARKET or
    m.status~="EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK" or
    m.mayUseForLiveOffer~=false or m.authorizesTrade~=false or
    m.authorizesAccept~=false or type(m.items)~="table" or #m.items~=189 or
    type(m.crosswalkRowsSha256)~="string" or #m.crosswalkRowsSha256~=64
    then return nil,"MARKET_OR_ITEM_ROSTER_NOT_SEALED" end
 local aliases,rows={},{}
 local function add(alias,key)
  local p=phrase(alias)
  if p and #p>=3 then
   if aliases[p]~=nil and aliases[p]~=key then
    aliases[p]=false
   elseif aliases[p]==nil then aliases[p]=key end
  end
 end
 for _,r in ipairs(m.items) do
  if type(r)~="table" or type(r.rawGameKeyCandidate)~="string" or
     rows[r.rawGameKeyCandidate] or type(r.expectedGameName)~="string"
     or type(r.marketName)~="string" or type(r.gameChroma)~="boolean" then
   return nil,"MARKET_NAME_ROSTER_INVALID" end
  local id=r.rawGameKeyCandidate
  rows[id]=r
  add(r.marketName,id)
  if r.gameChroma then
   local expected=phrase(r.expectedGameName)
   if expected then
    if expected:sub(1,6)~="chroma" then expected="chroma "..expected end
    add(expected,id)
   end
  else add(r.expectedGameName,id) end
 end
 if not rows.Gingerscope or
    rows.Gingerscope.outgoingGingerscopeProtected~=true then
  return nil,"PROTECTED_TARGET_NOT_PRESERVED" end
 return aliases,rows
end
local function getMentions(s,aliases)
 local found={}
 for alias,id in pairs(aliases) do
  local pos=1
  while true do
   local i,j=s:find(" "..alias.." ",pos,true)
   if not i then break end
   found[#found+1]={id=id,alias=alias,start=i,ending=j}
   pos=j
  end
 end
 table.sort(found,function(a,b)
  if a.start~=b.start then return a.start<b.start end
  return #a.alias>#b.alias
 end)
 local out={}
 for _,candidate in ipairs(found) do
  local overlaps=false
  for _,previous in ipairs(out) do
   if candidate.start<=previous.ending and
      candidate.ending>=previous.start then
    overlaps=true
    if candidate.start==previous.start and
       #candidate.alias==#previous.alias and candidate.id~=previous.id then
     return nil,"AMBIGUOUS_SAME_NAME_IN_MARKET_ROSTER" end
    break
   end
  end
  if not overlaps then
   if candidate.id==false then return nil,"AMBIGUOUS_MARKET_NAME" end
   out[#out+1]=candidate
  end
 end
 return out,nil
end
local function classify(s,mentions)
 local tokens={
  {" nlf ","AVOIDS"}, {" not looking for ","AVOIDS"},
  {" don t want ","AVOIDS"}, {" dont want ","AVOIDS"},
  {" do not want ","AVOIDS"}, {" no interest in ","AVOIDS"},
  {" but not ","AVOIDS"}, {" dont need ","AVOIDS"},
  {" don t need ","AVOIDS"}, {" no need for ","AVOIDS"},
  {" lf ","WANTS"}, {" looking for ","WANTS"}, {" searching for ","WANTS"},
  {" i want ","WANTS"}, {" i need ","WANTS"}, {" i like ","WANTS"},
 }
 local markers={}
 for _,v in ipairs(tokens) do
  local pos=1
  while true do
   local i,j=s:find(v[1],pos,true)
   if not i then break end
   markers[#markers+1]={start=i,ending=j,kind=v[2]}
   pos=j
  end
 end
 table.sort(markers,function(a,b)
  if a.ending~=b.ending then return a.ending<b.ending end
  return a.start<b.start
 end)
 local items={}
 for _,v in ipairs(mentions) do
  local kind="MENTION_ONLY"
  local marker=nil
  for _,t in ipairs(markers) do
   if t.ending<=v.start then marker=t end
  end
  if marker and v.start-marker.ending<=90 then
   kind=marker.kind
   local segment=" "..s:sub(marker.ending+1,v.start-1).." "
   if segment:find(" but not ",1,true) then
    kind="AVOIDS"
   elseif segment:find(" not ",1,true) or segment:find(" maybe ",1,true)
       or segment:find(" might ",1,true) or
       segment:find(" unsure ",1,true) then
    kind="MENTION_ONLY"
   end
  end
  items[#items+1]={key=v.id,intent=kind}
 end
 local function has(x)return s:find(x,1,true)~=nil end
 local intent="UNKNOWN"
 if has(" nty ") or has(" no thanks ") or has(" not interested ") or
    has(" i pass ") or has(" hard pass ") then intent="CHAT_REFUSAL_NOT_TRADE_DECLINE"
 elseif has(" what do you want ") or has(" what do u want ") or
        has(" what are you looking for ") or has(" what u want ") or
        has(" what for ") or has(" what you want ") or
        has(" wut u want ") then intent="ASKS_WHAT_WE_WANT"
 elseif has(" can you add ") or has(" can u add ") or
        has(" add more ") or has(" more adds ") or
        has(" you add ") or has(" u add ") or has(" need adds ") then
  intent="REQUESTS_ADDS"
 elseif has(" overpay ") or has(" op only ") or has(" need op ") then
  intent="REQUESTS_OVERPAY_UNQUANTIFIED"
 elseif has(" looking to downgrade ") or has(" want downgrade ") or
        has(" downgrading ") then intent="PREFERS_DOWNGRADE"
 elseif has(" want upgrade ") or has(" upgrading ") or
        has(" looking to upgrade ") then intent="PREFERS_UPGRADE"
 end
 if #items>0 and intent=="UNKNOWN" then
  for _,it in ipairs(items) do
   if it.intent=="WANTS" or it.intent=="AVOIDS" then
    intent="ITEM_SPECIFIC_PREFERENCE_STATED";break end
  end
 end
 local constraints={
  noDuplicates=has(" no dupes ") or has(" no duplicates ") or
    has(" dont want duplicates "),
  noSeers=has(" no seers ") or has(" nlf seers "),
  noPets=has(" no pets ") or has(" nlf pets "),
  compactInventory=has(" keep it small ") or
    has(" fewer items ") or has(" small inventory "),
 }
 if intent=="UNKNOWN" then
  for _,yes in pairs(constraints) do
   if yes then intent="INVENTORY_PREFERENCE_STATED";break end
  end
 end
 return intent,items,constraints
end
-- C3 refreshOwn() resets its local offer revision. An x1 -> x2
-- mutation during chat parsing may therefore be observed at the same
-- revision after an own-census refresh. Compare original C3 contents.
local function sameOwn(a,b)
 if type(a)~="table" or type(b)~="table" then return false end
 for k,n in pairs(a) do
  if type(k)~="string" or type(n)~="number" or b[k]~=n then return false end
 end
 for k,n in pairs(b) do
  if type(k)~="string" or type(n)~="number" or a[k]~=n then return false end
 end
 return true
end
local function sameOfferSide(a,b)
 if type(a)~="table" or type(b)~="table" or
  type(a.items)~="table" or type(b.items)~="table" or
  #a.items~=#b.items or a.physicalSlots~=b.physicalSlots or
  a.mm2Listed~=b.mm2Listed or
  a.supremeListed~=b.supremeListed or
  a.clientNameOnlyCandidates~=b.clientNameOnlyCandidates or
  a.allRawAttributesObserved~=b.allRawAttributesObserved then return false end
 for i,item in ipairs(a.items) do
  local other=b.items[i]
  if type(item)~="table" or type(other)~="table" or
   item.slot~=other.slot or item.id~=other.id or
   item.quantity~=other.quantity or
   item.clientIdentityEvidence~=other.clientIdentityEvidence then
   return false
  end
 end
 return true
end
local function sameOffer(a,b)
 return type(a)=="table" and type(b)=="table" and
  a.status==b.status and a.clientRevision==b.clientRevision and
  a.ourAccepted==b.ourAccepted and a.theirAccepted==b.theirAccepted and
  a.mm2ListedDelta==b.mm2ListedDelta and
  a.supremeListedDelta==b.supremeListedDelta and
  a.nameOnlyCatalogCandidateCount==b.nameOnlyCatalogCandidateCount and
  a.exactRawAttributesBothSidesObserved==b.exactRawAttributesBothSidesObserved and
  sameOfferSide(a.our,b.our) and sameOfferSide(a.their,b.their)
end
local function acceptScope(bound,scope,ctx)
 if type(bound)~="table" or type(scope)~="table" or
   type(ctx)~="table" or ctx.schema~=CONTEXT or
   ctx.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
   ctx.readOnly~=true or ctx.clientOnly~=true or
   ctx.authorizesOffer~=false or ctx.authorizesAccept~=false or
   type(ctx.offer)~="table" or ctx.offer.readOnly~=true or
   not finite(ctx.clientOfferRevision) or
   ctx.clientOfferRevision<1 or
   ctx.clientOfferRevision~=math.floor(ctx.clientOfferRevision) or
   ctx.clientOfferRevision~=ctx.offer.clientRevision or
   -- The C3 original scanner/P4 GUI is bound to its own constructor scope.
   -- A stale readScope callback must never bless a NEW active C3 lease.
   type(ctx.sessionScope)~="table" or
   ctx.sessionScope.jobId~=bound.jobId or
   ctx.sessionScope.leaseId~=bound.leaseId or
   ctx.sessionScope.partnerUserId~=bound.partnerUserId or
   type(scope.jobId)~="string" or scope.jobId~=bound.jobId or
   scope.leaseId~=bound.leaseId or
   scope.localUserId~=bound.localUserId or
   scope.partnerUserId~=bound.partnerUserId or
   scope.mainUsername~=bound.mainUsername or
   scope.tradeOpen~=true or scope.leaseActive~=true or
   not validId(scope.partnerUserId) or not validId(scope.localUserId) or
   not finite(ctx.offer.ownedCensusAgeSeconds) or
   ctx.offer.ownedCensusAgeSeconds<0 or
   ctx.offer.ownedCensusAgeSeconds>30 or
   not finite(ctx.offer.sourceAgeSeconds) or
   ctx.offer.sourceAgeSeconds<0 or
   ctx.offer.sourceAgeSeconds>21600 then
  return false
 end
 return true
end
local function address(text,scope,now,revision,channel)
 local mentions={}
 for name in text:lower():gmatch("@([%w_]+)") do
  mentions[#mentions+1]=name
 end
 local main=scope.mainUsername:lower()
 local display=type(scope.mainDisplayName)=="string" and
   scope.mainDisplayName:lower():gsub("[^%w_]","") or ""
 local directed=false
 for _,name in ipairs(mentions) do
  if name==main or
     (display~="" and scope.mainDisplayNameUnique==true and name==display) then
   directed=true
  else return "AMBIGUOUS_OTHER_ACCOUNT_MENTION",false end
 end
 if directed then return "EXPLICIT_UNIQUE_MENTION",true end
 if channel=="WHISPER_BETWEEN_BOUND_USERS" then
  return "DIRECT_BOUND_WHISPER",true
 end
 local witnessed=scope.lastOurOfferChanged==true and
   scope.lastOurOfferRevision==revision and
   finite(scope.lastOurOfferAt) and
   now>=scope.lastOurOfferAt and now-scope.lastOurOfferAt<=WINDOW
 if witnessed then
  return "TENTATIVE_IN_CURRENT_TRADE_AFTER_OWN_OFFER",false
 end
 return "PUBLIC_UNADDRESSED",false
end
local function channelType(name,scope)
 if name=="RBXGeneral" then return "PUBLIC_GENERAL" end
 if type(name)~="string" then return nil end
 local a,b=name:match("^RBXWhisper:(%d+)_(%d+)$")
 if not a or not b then return nil end
 a=tonumber(a);b=tonumber(b)
 if (a==scope.localUserId and b==scope.partnerUserId) or
    (b==scope.localUserId and a==scope.partnerUserId) then
  return "WHISPER_BETWEEN_BOUND_USERS"
 end
 return nil
end
function M.new(config)
 if type(config)~="table" or type(config.bound)~="table" or
    type(config.readContext)~="function" or
    type(config.readScope)~="function" or type(config.now)~="function" then
  return nil,"PASSIVE_SESSION_READER_DEPENDENCIES_MISSING" end
 local bound=config.bound
 if not validId(bound.localUserId) or not validId(bound.partnerUserId) or
   bound.localUserId==bound.partnerUserId or
   type(bound.jobId)~="string" or #bound.jobId<8 or
   type(bound.leaseId)~="string" or #bound.leaseId<8 or
   type(bound.mainUsername)~="string" or
   not bound.mainUsername:match("^[%w_]+$") then
  return nil,"ORIGINAL_TRADE_PARTICIPANT_BINDING_INVALID" end
 local aliases,rows=validSource(config.crosswalk)
 if not aliases then return nil,rows end
 local seen,seenList,events={}, {},{}
 local current=nil
 local lastRevision=nil
 local observer={}
 local function purge()
  current=nil;lastRevision=nil
  seen={};seenList={};events={}
 end
 local function read()
  local ok,ctx=pcall(config.readContext)
  local good,scope=pcall(config.readScope)
  local tgood,now=pcall(config.now)
  if not ok or not good or not tgood or not finite(now) or
     not acceptScope(bound,scope,ctx) then
   purge()
   return nil,nil,nil,"ORIGINAL_P3_P4_CLIENT_SCOPE_NOT_CURRENT"
  end
  if lastRevision~=nil and ctx.clientOfferRevision<lastRevision then
   purge()
   return nil,nil,nil,"CLIENT_OFFER_REVISION_ROLLBACK"
  end
  if ctx.crosswalkRowsSha256~=config.crosswalk.crosswalkRowsSha256 or
     ctx.sourceRetrievedUtc~=config.crosswalk.sourceRetrievedUtc then
   purge()
   return nil,nil,nil,"SOURCE_REVISION_CHANGED"
  end
  return ctx,scope,now,nil
 end
 local function reset(id,revision)
  if current~=id then
   current=id;lastRevision=revision
   seen={};seenList={};events={}
  elseif lastRevision==nil or revision>lastRevision then
   lastRevision=revision -- allow LF/NLF TTL within same bound session
  end
 end
 local function envelope(status,why,extra)
  local out=denied(why);out.status=status
  out.observedPassiveSignal=status=="PASSIVE_ITEM_PREFERENCE" or
    status=="PASSIVE_CONVERSATION_SIGNAL"
  if extra then for k,v in pairs(extra) do out[k]=v end end
  return out
 end
 function observer.ingest(p)
  local ctx,scope,now,err=read()
  if not ctx then return denied(err) end
  reset(scope.jobId..":"..scope.leaseId..":"..tostring(scope.partnerUserId),ctx.clientOfferRevision)
  if type(p)~="table" or type(p.messageId)~="string" or
      #p.messageId<1 or #p.messageId>120 or
      not validId(p.speakerUserId) or
      not finite(p.observedAt) or p.observedAt>now+2 or
      now-p.observedAt>3 or type(p.text)~="string" or
      #p.text>240 or #p.text<1 then
   return denied("INCOMING_MESSAGE_OR_TIMESTAMP_INVALID")
  end
  if p.speakerUserId~=scope.partnerUserId then
   return envelope("IGNORED_OTHER_SPEAKER","NOT_CURRENT_BOUND_TRADING_PARTNER")
  end
  local channel=channelType(p.channelName,scope)
  if not channel then return denied("UNATTRIBUTABLE_OR_NONPERMITTED_CHAT_CHANNEL") end
  if seen[p.messageId] then
   return envelope("IGNORED_DUPLICATE_MESSAGE","MESSAGE_ID_ALREADY_SEEN")
  end
  local text=clean(p.text)
  if not text then return denied("FILTERED_MESSAGE_EMPTY_OR_INVALID") end
  local mode,personal=address(p.text,scope,now,ctx.clientOfferRevision,channel)
  if mode=="AMBIGUOUS_OTHER_ACCOUNT_MENTION" then
   return envelope("AMBIGUOUS_RECIPIENT","MESSAGE_MENTIONS_ANOTHER_USER")
  end
  local mention,reason=getMentions(text,aliases)
  if not mention then
   return envelope("AMBIGUOUS_ITEM","MARKET_ITEM_ALIAS_COLLISION")
  end
  local intent,items,constraints=classify(text,mention)
  if mode=="TENTATIVE_IN_CURRENT_TRADE_AFTER_OWN_OFFER" and
      intent=="UNKNOWN" then mode="PUBLIC_UNADDRESSED" end
  local okR,ctxAfter=pcall(config.readContext)
  local okS,scopeAfter=pcall(config.readScope)
  local okN,timeAfter=pcall(config.now)
  if not okR or not okS or not okN or
     not acceptScope(bound,scopeAfter,ctxAfter) or
     ctxAfter.clientOfferRevision~=ctx.clientOfferRevision or
     ctxAfter.crosswalkRowsSha256~=ctx.crosswalkRowsSha256 or
     ctxAfter.sourceRetrievedUtc~=ctx.sourceRetrievedUtc or
     not sameOwn(ctx.ownCounts,ctxAfter.ownCounts) or
     not sameOffer(ctx.offer,ctxAfter.offer) or
     scopeAfter.jobId~=scope.jobId or
     scopeAfter.leaseId~=scope.leaseId or
     not finite(timeAfter) or timeAfter<now or timeAfter-now>2 then
   return denied("PARTNER_OFFER_LEASE_OR_SOURCE_CHANGED_MID_MESSAGE")
  end
  seen[p.messageId]=true
  seenList[#seenList+1]=p.messageId
  if #seenList>MAX_EVENTS then
   local gone=table.remove(seenList,1);seen[gone]=nil
  end
  local hasPreference=false
  for _,item in ipairs(items) do
   if item.intent=="WANTS" or item.intent=="AVOIDS" then
    hasPreference=true
   end
  end
  local known=intent~="UNKNOWN" or hasPreference
  local signal={time=timeAfter,revision=ctx.clientOfferRevision,
    addressing=mode,personalReplyProven=personal,
    intent=intent,items=items,constraints=constraints,
    itemNamesMatched=#items,
    chatUserIdDerivedFromTextSource=true,
    chatResponseAcceptedByCounterparty=false,
    outcomeVerified=false}
  if known then
   events[#events+1]=signal
   if #events>MAX_EVENTS then table.remove(events,1) end
  end
  local state=hasPreference and "PASSIVE_ITEM_PREFERENCE" or
    known and "PASSIVE_CONVERSATION_SIGNAL" or "PASSIVE_NO_DECODABLE_INTENT"
  return envelope(state,"CLIENT_CHAT_ONLY_NO_TRADE_COMMITMENT",{
   addressType=mode,personalReplyProven=personal,
   signalType=intent,itemPreferences=items,
   constraints=constraints,
   clientOfferRevision=ctx.clientOfferRevision,
   explicitPersonalReply=personal and mode~="TENTATIVE_IN_CURRENT_TRADE_AFTER_OWN_OFFER",
   realPartnerBehaviorObservedViaClient=true,
   itemPreferenceIsAcceptedOffer=false,
  })
 end
 function observer.snapshot()
  local ctx,scope,now,err=read()
  if not ctx then return denied(err) end
  reset(scope.jobId..":"..scope.leaseId..":"..tostring(scope.partnerUserId),ctx.clientOfferRevision)
  local prefs,counts,latest={}, {}, {}
  local constraints={noDuplicates=false,noSeers=false,noPets=false,
     compactInventory=false}
  local total,public,contextual,direct=0,0,0,0
  for _,e in ipairs(events) do
   if now>=e.time and now-e.time<=TTL and
       e.revision<=ctx.clientOfferRevision then
    if e.revision==ctx.clientOfferRevision then
     total+=1
     if e.personalReplyProven then direct+=1
     elseif e.addressing=="TENTATIVE_IN_CURRENT_TRADE_AFTER_OWN_OFFER" then
      contextual+=1 else public+=1 end
     counts[e.intent]=(counts[e.intent] or 0)+1
    end
    -- LF/NLF and simple constraints persist briefly within the SAME lease.
    -- Previous revision chat "NTY" does NOT become a new trade decline.
    for _,p in ipairs(e.items) do
     if p.intent=="WANTS" or p.intent=="AVOIDS" then
      local record=latest[p.key]
      if not record or e.time>=record.at then
       latest[p.key]={intent=p.intent,at=e.time,addressing=e.addressing,
        explicitlyAddressed=e.personalReplyProven,revision=e.revision}
      end
     end
    end
    for k,v in pairs(e.constraints) do
     if v then constraints[k]=true end
    end
   end
  end
  for id,v in pairs(latest) do
   prefs[#prefs+1]={rawGameKeyCandidate=id,intent=v.intent,
     addressing=v.addressing,explicitlyAddressed=v.explicitlyAddressed,
     statedAtClientOfferRevision=v.revision,
     carriedAcrossOfferChange=v.revision~=ctx.clientOfferRevision}
  end
  table.sort(prefs,function(a,b)return a.rawGameKeyCandidate<b.rawGameKeyCandidate end)
  return envelope("CLIENT_ONLY_PASSIVE_PARTNER_PREFERENCE_RESEARCH",
     "STATED_PREFERENCE_NOT_A_COMPLETED_TRADE",{
     sourceRowsSha256=ctx.crosswalkRowsSha256,clientOfferRevision=ctx.clientOfferRevision,
     activeSignals=total,explicitDirectedSignals=direct,
     contextualTentativeSignals=contextual,unaddressedPublicSignals=public,
     itemPreferences=prefs,statementTypes=counts,constraints=constraints,
     noRawChatRetained=true,noRawChatExported=true,
     currentCounterpartyIdentityKnownClientOnly=true,
     completedTradeProven=false,empiricalAcceptanceProbability=nil})
 end
 function observer.compareResearchOptions(alternatives)
  local snapshot=observer.snapshot()
  if snapshot.status~="CLIENT_ONLY_PASSIVE_PARTNER_PREFERENCE_RESEARCH" then
   return denied("CURRENT_PARTNER_EVIDENCE_SNAPSHOT_REQUIRED") end
  if type(alternatives)~="table" or #alternatives<1 or #alternatives>12 then
   return denied("ONE_TO_TWELVE_RESEARCH_OPTIONS_REQUIRED") end
  local preference={}
  for _,v in ipairs(snapshot.itemPreferences) do
   preference[v.rawGameKeyCandidate]=v.intent
  end
  local options={}
  for index,o in ipairs(alternatives) do
   if type(o)~="table" or type(o.give)~="table" or
     type(o.receive)~="table" or #o.give<1 or #o.receive<1 or
     #o.give>4 or #o.receive>4 then
    return denied("OPTION_NOT_FOUR_PHYSICAL_SLOTS")
   end
   local likes,avoids,unknown=0,0,0
   local duplicate=false
   local unique={}
   for _,item in ipairs(o.give) do
    if type(item)~="table" or not rows[item.id] or
       not finite(item.quantity) or
       item.quantity~=math.floor(item.quantity) or
       item.quantity<1 or item.quantity>1000000 then
     return denied("OPTION_ITEM_NOT_CURRENT_RAW_KEY")
    end
    if unique[item.id] then return denied("DUPLICATE_RAW_KEY_IN_OFFER") end
    unique[item.id]=true
    if preference[item.id]=="WANTS" then likes+=1
    elseif preference[item.id]=="AVOIDS" then avoids+=1
    else unknown+=1 end
    if snapshot.constraints.noSeers and item.id:lower():find("seer",1,true) then
      avoids+=1 end
    if snapshot.constraints.noDuplicates and item.quantity>1 then
      duplicate=true end
   end
   local receiveSeen={}
   for _,other in ipairs(o.receive) do
    if type(other)~="table" or not rows[other.id] or
       not finite(other.quantity) or
       other.quantity~=math.floor(other.quantity) or
       other.quantity<1 or other.quantity>1000000 or
       receiveSeen[other.id] then
     return denied("RECEIVE_SIDE_ITEM_OR_QUANTITY_INVALID")
    end
    receiveSeen[other.id]=true
   end
   local count=#o.give
   options[#options+1]={index=index,statedWantedMatches=likes,
     statedAvoidedMatches=avoids,unknownItemPreferences=unknown,
     violatesNoDuplicates=duplicate,
     compactInventoryCaution=snapshot.constraints.compactInventory and count>1,
     itemCompatibility=(avoids>0 or duplicate) and "CONFLICTS_STATED_PREFERENCE" or
       likes>0 and "MATCHES_STATED_ITEM_INTEREST" or "UNVERIFIED",
     actualWillingnessToTrade=false,estimatedAcceptProbability=nil,
     optionFeasibilityMustBeValidatedSeparatelyByComponent4=true,
     canProposeLiveOffer=false}
  end
  return envelope("CLIENT_ONLY_PREFERENCE_COMPATIBILITY_RESEARCH",
    "NO_OBSERVED_PARTNER_CONSENT_TO_ANY_OPTION",{
     clientOfferRevision=snapshot.clientOfferRevision,options=options,
     sourceRowsSha256=snapshot.sourceRowsSha256,
     confidenceIsNotAcceptanceProbability=true})
 end
 return observer,nil
end
return M
