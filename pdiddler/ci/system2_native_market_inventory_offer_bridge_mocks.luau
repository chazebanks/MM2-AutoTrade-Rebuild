-- Real Lune executes production pure market bridge, exact GUI adapter, and glue.
-- Market prices are actual current source-crosswalk JSON produced by this CI job.
-- Roblox service objects and scanner snapshots are *mocked*: NOT original-game PASS.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local base="pdiddler/system2/"
local market=serde.decode("json",fs.readFile(base.."research_market_crosswalk_current.json"))
local sourceEpoch=tonumber(fs.readFile(base.."research_market_epoch.txt"))
local core=luau.load(fs.readFile(base.."native_market_inventory_offer_core.lua"))()
local resolver=luau.load(fs.readFile(base.."native_offer_item_identity_resolver.lua"))()
local capture=luau.load(fs.readFile(base.."native_market_offer_client_capture.lua"))()
local glue=luau.load(fs.readFile(base.."native_market_inventory_offer_bridge.lua"))()
local count=0
local function eq(x,y,label)
 count+=1
 assert(x==y,label..": expected "..tostring(y)..", got "..tostring(x))
end
local function ok(x,label)count+=1;assert(x,label)end
local rows={}
for _,row in ipairs(market.items) do rows[row.rawGameKeyCandidate]=row end
eq(#market.items,189,"actual market count")
eq(rows.Gingerscope.mm2Listed,16000,"real live Gingerscope MM2")
eq(rows.FlowerwoodKnife.marketSlug,"flowerwood-knife","site alias")
eq(rows.FlowerwoodKnife.supremeListed,nil,"missing published Supreme stays nil")
eq(rows.EmberbowChroma.gameRarity,"Ancient","chroma ancient")
eq(rows.ChromaDarkbringer.gameRarity,"Godly","chroma godly")

local sync={Weapons={}}
for _,row in ipairs(market.items) do
 sync.Weapons[row.rawGameKeyCandidate]={
  ItemName=row.expectedGameName,ItemType=row.gameItemType,
  Rarity=row.gameRarity,Chroma=row.gameChroma,
 }
end
local scannerReads=0
local profileItems={"EmberbowChroma","FlowerwoodKnife","Gingerscope"}
local quantities={EmberbowChroma=6,FlowerwoodKnife=1,Gingerscope=1}
local function scannerSnapshot()
 local result={items={},seen={},rawOwned=8,unmapped=0,badQty=0,
   unpriced=8,total=999999999,fingerprint=""}
 for _,id in ipairs(profileItems) do
  local r=rows[id]
  table.insert(result.items,{
   id=id,cat="Weapons",name=(r.gameChroma and "Chroma " or "")..r.expectedGameName,
   qty=quantities[id],page=r.marketCategory,type=r.gameItemType,
   value=777777777,checkerId="UNPRICED",valueSource="2026-10-31",
   identity="irrelevant-stale-checker",year="",event=""
  })
  table.insert(result.seen,id.."x"..tostring(quantities[id]))
 end
 table.sort(result.seen)
 result.fingerprint=table.concat(result.seen,"|")
 return result
end
local reader={getOwnInventory=function()
 scannerReads+=1
 return scannerSnapshot(),nil
end}
local function node(kind,name)
 local o={ClassName=kind,Name=name,children={},Visible=true,Enabled=true,
  Text="",Attributes={}}
 function o:IsA(k)
  if self.ClassName==k then return true end
  if k=="GuiObject" then
   return self.ClassName=="Frame" or self.ClassName=="TextLabel" or
    self.ClassName=="TextButton" or self.ClassName=="ImageLabel"
  end
  return false
 end
 function o:FindFirstChild(n,recursive)
  local x=self.children[n]
  if x then return x end
  if recursive then
   for _,c in pairs(self.children) do
    local y=c:FindFirstChild(n,true)
    if y then return y end
   end
  end
  return nil
 end
 function o:FindFirstChildOfClass(k)
  if k=="PlayerGui" and self.children.PlayerGui then return self.children.PlayerGui end
  for _,v in pairs(self.children) do if v:IsA(k) then return v end end
 end
 function o:GetAttribute(name) return self.Attributes[name] end
 function o:put(v) v.Parent=self;self.children[v.Name]=v;return v end
 return o
end
local players={}
local pg=node("PlayerGui","PlayerGui")
local localPlayer={UserId=121111112}
function localPlayer:FindFirstChildOfClass(n)
 if n=="PlayerGui" then return pg end
end
players.LocalPlayer=localPlayer
local opponent={UserId=565555552,Name="PartnerUser",Parent=players}
function players:GetPlayerByUserId(id)
 return id==opponent.UserId and opponent or nil
end
local screen=pg:put(node("ScreenGui","TradeGUI"))
local root=screen:put(node("Frame","Container")):put(node("Frame","Trade"))
local function makeSide(name)
 local side=root:put(node("Frame",name))
 side:put(node("Frame","Accepted")).Visible=false
 local container=side:put(node("Frame","Container"))
 return side,container
end
local our,ourList=makeSide("YourOffer")
local their,theirList=makeSide("TheirOffer")
their:put(node("TextLabel","Username")).Text="(PartnerUser)"
local function appendSlot(parent,num,id,label,amount,chroma)
 local slot=parent:put(node("Frame","NewItem"..tostring(num)))
 slot.Attributes.ItemId=id
 slot:put(node("Frame","ItemName")):put(node("TextLabel","Label")).Text=label
 slot:put(node("Frame","Container")):put(node("TextLabel","Amount")).Text=amount
 if chroma then slot:put(node("Frame","Tags")):put(node("Frame","Chroma")) end
 return slot
end
local ours=appendSlot(ourList,1,"EmberbowChroma","Chroma Emberbow","x6",true)
local theirs=appendSlot(theirList,1,"Iceblaster","Iceblaster","",false)
local job="MAIN_ORIGINAL_JOB_001"
local lease="REAL_P3_LEASE_001"
local game={PlaceId=142823291,JobId=job}
local scope={jobId=job,leaseId=lease,localUserId=localPlayer.UserId,
 partnerUserId=opponent.UserId,root=root}
local active=true
local monotonic=1.0
local utc=sourceEpoch+20
local function now()return monotonic end
local function tick()return utc end
local adapter,why=capture.new({game=game,players=players,scope=scope,
 isBoundSession=function()return active end})
ok(adapter~=nil,"actual P4 style GUI capture adapter built")
local firstFrame=adapter.capture()
eq(firstFrame.doubleReadStable,true,"real-geometry two-read stable")
eq(firstFrame.ourSlots[1].rawId,"EmberbowChroma","exact attribute raw id")
eq(firstFrame.theirSlots[1].amountText,"","single stack empty amount preserved")
local bridge,reason=glue.new({core=core,captureAdapter=capture,scope=scope,
 game=game,players=players,sync=sync,scannerApi=reader,nameResolver=resolver,crosswalk=market,
 isBoundSession=function()return active end,
 utcNow=tick,monoNow=now,sourceRetrievedEpoch=sourceEpoch})
ok(bridge~=nil,"scanner and P4 GUI bridge actually wired")
local calls=0
local pinned,whyPinned=glue.newWithPinnedSource({
 core=core,captureAdapter=capture,scope=scope,game=game,players=players,
 sync=sync,scannerApi=reader,nameResolver=resolver,isBoundSession=function()return active end,
 utcNow=tick,monoNow=now,
 sourceHttpGet=function(url)
  calls+=1
  ok(url:find("fd823dd0f0036c02ba4632a4f0a879bd429cb4fc",1,true)~=nil,
     "source uses immutable verified Git commit")
  return fs.readFile(base.."research_market_crosswalk_current.json")
 end,
 jsonDecode=function(bytes)return serde.decode("json",bytes)end,
 isoToEpoch=function(s)
  eq(s,market.sourceRetrievedUtc,"pinned source time actually parsed")
  return sourceEpoch
 end,
})
ok(pinned~=nil,"native can load real immutable source over HTTP")
eq(calls,1,"pinned source downloaded once")
eq(pinned.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
   "actual native bridge can use downloaded price crosswalk")
local stale=bridge.observeOffer()
eq(stale.reason,"OWN_CENSUS_EXPIRED_REFRESH_REQUIRED","must inventory first")
local own=bridge.refreshOwn()
eq(own.status,"READONLY_OWN_MARKET_BOUND","real mapped market + stale scanner input")
eq(own.matchedEligibleKeys,3,"three raw ids")
eq(own.matchedEligibleCopies,8,"six-copy Chroma stack one item")
eq(own.mm2ListedSubtotal,6*rows.EmberbowChroma.mm2Listed+
 rows.FlowerwoodKnife.mm2Listed+rows.Gingerscope.mm2Listed,"source value own")
eq(own.supremeListedSubtotal,nil,"single-source Flowerwood missing Supreme")
eq(own.scannerLegacyPriceIgnored,true,"no October 31 price")
eq(scannerReads,2,"two independent read-only mock bridge instances each called scanner once")
local observe=bridge.observeOffer()
eq(observe.status,"CLIENT_OFFER_OBSERVATION_READONLY","observed real shape")
eq(observe.clientRevision,1,"initial client revision")
eq(observe.our.physicalSlots,1,"one physical slot with six copies")
eq(observe.our.items[1].quantity,6,"six actual copies in single slot")
eq(observe.their.items[1].id,"Iceblaster","opponent raw ID")
eq(observe.mm2ListedDelta,rows.Iceblaster.mm2Listed-
 6*rows.EmberbowChroma.mm2Listed,"current site bilateral delta")
eq(observe.serverOfferRevisionProven,false,"not server proof")
eq(observe.authorizesAccept,false,"never accepts")
-- Original scanner + actual P4 GUI-shape observations now feed the new
-- bilateral research engine, not merely fabricated standalone strategy input.
local nativeBilateral=luau.load(fs.readFile(base.."native_bilateral_attractiveness_shadow.lua"))()
local nativeBilateralBridge=luau.load(fs.readFile(base.."native_bilateral_attractiveness_bridge.lua"))()
local research=bridge.researchContext()
eq(research.status,"LOCAL_READONLY_MARKET_OFFER_CONTEXT",
  "original scanner and GUI produce local bilateral research input")
eq(research.ownCounts.EmberbowChroma,6,"private six-copy ownership local only")
eq(research.crosswalkRowsSha256,market.crosswalkRowsSha256,
  "bilateral source must match real crosswalk")
eq(research.offer.their.items[1].id,"Iceblaster",
  "actual GUI-shape their offer attached to research")
local researchAdapter,researchErr=nativeBilateralBridge.new({
 marketBridge=bridge,bilateralCore=nativeBilateral,crosswalk=market})
ok(researchAdapter~=nil,"native quality engine connected to original scanner and P4 observer")
local bilateral=researchAdapter:compare({
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="EmberbowChroma",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}},
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="FlowerwoodKnife",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}},
})
eq(bilateral.status,"ABSTAIN_PARTNER_INTENT_UNVERIFIED",
 "loss or incomplete quote refuses to propose any live trade")
eq(bilateral.alternatives[1].status,"RISK_FILTERED",
 "market-backed original GUI alt cannot pass unapproved value loss")
eq(bilateral.alternatives[2].reason,"DUAL_PUBLISHER_PRICE_NOT_AVAILABLE",
 "genuine Flowerwood Supreme missing quote preserved")
eq(bilateral.authorizesTrade,false,"full component3->component4 bridge is research-only")
-- C8 restart: source-backed ORIGINAL C3 scanner+P4 GUI -> C4 race test.
-- A refreshed census resets C3's client revision. If owned quantities change
-- during comparison, revision 1 can recur and MUST NOT validate stale ranking.
local raceScanner={getOwnInventory=function()
 local snapshot=scannerSnapshot()
 snapshot.rawOwned=quantities.EmberbowChroma+
    quantities.FlowerwoodKnife+quantities.Gingerscope
 return snapshot,nil
end}
local raceBridge,raceErr=glue.new({
 core=core,captureAdapter=capture,scope=scope,game=game,players=players,
 sync=sync,scannerApi=raceScanner,nameResolver=resolver,crosswalk=market,
 isBoundSession=function()return active end,
 utcNow=tick,monoNow=now,sourceRetrievedEpoch=sourceEpoch})
ok(raceBridge~=nil,"C8 real C3 separate census bridge created")
eq(raceBridge.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
 "C8 starting real scanner census valid")
local raceBefore=raceBridge.researchContext()
eq(raceBefore.clientOfferRevision,1,"C8 original GUI first offer revision")
eq(raceBefore.ownCounts.EmberbowChroma,6,"C8 original scanner reads six")
local raceCore={compare=function(first,source,options)
 quantities.EmberbowChroma=7
 eq(raceBridge.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
  "C8 original scanner refreshes to seven inside strategy compare")
 return nativeBilateral.compare(first,source,options)
end}
local raceAdapter,raceAdapterErr=nativeBilateralBridge.new({
 marketBridge=raceBridge,bilateralCore=raceCore,crosswalk=market})
ok(raceAdapter~=nil,"C8 original C3 to C4 real scorer bridge created")
local raceReport=raceAdapter:compare({
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="EmberbowChroma",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}},
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="FlowerwoodKnife",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}}
})
eq(raceReport.status,"BLOCKED",
 "C8 census change amid comparison must not reuse old recommendation")
eq(raceReport.reason,"OWN_INVENTORY_CHANGED_DURING_STRATEGY_COMPARISON",
 "C8 same revision and market hash cannot disguise inventory mutation")
local raceAfter=raceBridge.researchContext()
eq(raceAfter.clientOfferRevision,1,
 "C8 original C3 refresh resets same GUI to the same revision 1")
eq(raceAfter.ownCounts.EmberbowChroma,7,
 "C8 originally scanned owned quantity genuinely changed")
quantities.EmberbowChroma=6

-- WHOLE-SYSTEM DEBUG: opponent changes a GUI stack while the scanner
-- refreshes the SAME owned quantities. C3's local offer revision resets to 1,
-- so source+revision+ownCount equality alone MUST NOT reuse the old offer.
local opponentOfferBridge,opponentOfferErr=glue.new({
 core=core,captureAdapter=capture,scope=scope,game=game,players=players,
 sync=sync,scannerApi=raceScanner,nameResolver=resolver,crosswalk=market,
 isBoundSession=function()return active end,
 utcNow=tick,monoNow=now,sourceRetrievedEpoch=sourceEpoch})
ok(opponentOfferBridge~=nil,"Debug original GUI+scanner opponent-offer race bridge")
eq(opponentOfferBridge.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
 "Debug baseline own census accepted")
local originalOffer=opponentOfferBridge.researchContext()
eq(originalOffer.clientOfferRevision,1,"Debug initial client offer revision")
eq(originalOffer.offer.their.items[1].quantity,1,"Debug original opponent copy count")
local opponentAmount=theirs:FindFirstChild("Container"):FindFirstChild("Amount")
local opponentRaceCore={compare=function(first,source,options)
 opponentAmount.Text="x2"
 eq(opponentOfferBridge.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
  "Debug real C3 refresh same own holdings while partner changes GUI")
 return nativeBilateral.compare(first,source,options)
end}
local opponentRaceAdapter,opponentRaceErr=nativeBilateralBridge.new({
 marketBridge=opponentOfferBridge,bilateralCore=opponentRaceCore,crosswalk=market})
ok(opponentRaceAdapter~=nil,"Debug C4 genuine scorer connected to changing partner offer")
local opponentRaceResult=opponentRaceAdapter:compare({
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="EmberbowChroma",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}},
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="FlowerwoodKnife",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}}
})
eq(opponentRaceResult.status,"BLOCKED",
 "Debug partner quantity changed despite same local revision and own inventory")
eq(opponentRaceResult.reason,"OFFER_CONTENT_CHANGED_DURING_STRATEGY_COMPARISON",
 "Debug C4 must fail closed instead of returning old bilateral assessment")
local newOffer=opponentOfferBridge.researchContext()
eq(newOffer.clientOfferRevision,1,
 "Debug C3 revision 1 reused after own-census refresh")
eq(newOffer.ownCounts.EmberbowChroma,6,
 "Debug own census same, offer mutation independent")
eq(newOffer.offer.their.items[1].quantity,2,
 "Debug real original opponent GUI quantity changed x1->x2")
opponentAmount.Text=""

-- C8 scoped P3/P4 lease-handoff adversary: two *actual* C3 scanner and
-- original P4 GUI readers can produce the same source, copied inventory,
-- offer contents and local revision 1 while protected lease A becomes B.
-- This host facade rebinds to the currently active C3 capture instance.
-- No live Roblox, requests, offers, chat, or Accept are performed.
local currentProtectedLease=lease
local function buildForProtectedLease(boundLease)
 local boundScope={jobId=job,leaseId=boundLease,
  localUserId=localPlayer.UserId,partnerUserId=opponent.UserId,root=root}
 local target,err=glue.new({
  core=core,captureAdapter=capture,scope=boundScope,game=game,
  players=players,sync=sync,scannerApi=raceScanner,
  nameResolver=resolver,crosswalk=market,
  isBoundSession=function()return active and currentProtectedLease==boundLease end,
  utcNow=tick,monoNow=now,sourceRetrievedEpoch=sourceEpoch})
 ok(target~=nil,"C8 actual protected lease bridge constructed")
 eq(target.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
  "C8 scanner reads genuine source-bound census for active lease")
 return target
end
local activeResearchBridge=buildForProtectedLease(currentProtectedLease)
local beforeLeaseContext=activeResearchBridge.researchContext()
eq(beforeLeaseContext.status,"LOCAL_READONLY_MARKET_OFFER_CONTEXT",
 "C8 old protected lease has actual C3 source and GUI")
eq(beforeLeaseContext.clientOfferRevision,1,
 "C8 first protected lease starts at local revision one")
local leaseFacade={researchContext=function()
 return activeResearchBridge.researchContext()
end}
local swappedLeaseDuringCompare=false
local leaseSwappingCore={compare=function(first,source,alternatives)
 currentProtectedLease="REAL_P3_LEASE_002"
 activeResearchBridge=buildForProtectedLease(currentProtectedLease)
 swappedLeaseDuringCompare=true
 return nativeBilateral.compare(first,source,alternatives)
end}
local leaseBoundResearch,leaseBoundError=nativeBilateralBridge.new({
 marketBridge=leaseFacade,bilateralCore=leaseSwappingCore,crosswalk=market})
ok(leaseBoundResearch~=nil,"C8 genuine C3->C4 protected lease facade")
local leaseResult=leaseBoundResearch:compare({
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="EmberbowChroma",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}},
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="FlowerwoodKnife",quantity=1}},
  receive={{id="Iceblaster",quantity=1}}}
})
ok(swappedLeaseDuringCompare,
 "C8 protected lease switch genuinely occurred inside the scorer")
local afterLeaseContext=activeResearchBridge.researchContext()
eq(afterLeaseContext.status,"LOCAL_READONLY_MARKET_OFFER_CONTEXT",
 "C8 new protected lease independently sampled original GUI")
eq(afterLeaseContext.clientOfferRevision,beforeLeaseContext.clientOfferRevision,
 "C8 local offer revision is identical even after different protected lease")
eq(afterLeaseContext.ownCounts.EmberbowChroma,beforeLeaseContext.ownCounts.EmberbowChroma,
 "C8 own raw copies identical across active protected lease change")
eq(afterLeaseContext.offer.their.items[1].quantity,
 beforeLeaseContext.offer.their.items[1].quantity,
 "C8 exact partner GUI unchanged across lease change")
eq(leaseResult.status,"BLOCKED",
 "C8 distinct P3/P4 protected lease MUST invalidate original-source C4 result")
eq(leaseResult.reason,"P3_P4_SESSION_BINDING_CHANGED_DURING_STRATEGY_COMPARISON",
 "C8 different protected trade lease cannot share one C4 strategy assessment")

-- C8 next distinct integration: actual C3 P3/P4 lease -> C6 passive
-- TextChatMessage.UserId observer. Two source-bound C3 readers across
-- DIFFERENT protected leases still have identical inventory/offer/revision.
-- C6's independent readScope may briefly remain stale; C6 must bind the
-- original C3 constructor sessionScope, not just accept old GUI revision.
local c6=luau.load(fs.readFile(base.."native_partner_intent_observer.lua"))()
local chatBound={jobId=job,leaseId=lease,localUserId=localPlayer.UserId,
 partnerUserId=opponent.UserId,mainUsername="MainTestUser_Alpha"}
local function oldChatScope()
 return {jobId=job,leaseId=lease,localUserId=localPlayer.UserId,
  partnerUserId=opponent.UserId,mainUsername="MainTestUser_Alpha",
  tradeOpen=true,leaseActive=true}
end
currentProtectedLease=lease
local c6First=buildForProtectedLease(lease)
local firstSessionObserved=false
local c6ResearchChanged=nil
local c6Observer,c6Error=c6.new({
 bound=chatBound,crosswalk=market,now=now,
 readScope=oldChatScope,
 readContext=function()
  if not firstSessionObserved then
   local first=c6First.researchContext()
   firstSessionObserved=true
   currentProtectedLease="REAL_P3_LEASE_002"
   c6ResearchChanged=buildForProtectedLease(currentProtectedLease)
   return first
  end
  return c6ResearchChanged.researchContext()
 end})
ok(c6Observer~=nil,"C8 genuine C3/P4 and C6 passive chat reader created")
local rejectedChat=c6Observer.ingest({
 speakerUserId=opponent.UserId,
 text="@MainTestUser_Alpha LF Harvester",
 messageId="C8_CHAT_AFTER_PROTECTED_LEASE_ABA",
 observedAt=monotonic,channelName="RBXGeneral"})
eq(firstSessionObserved,true,"C8 switch executed between real C3 context reads")
eq(rejectedChat.status,"BLOCKED",
 "C8 old bound TextChat speaker cannot contaminate next protected lease")
eq(rejectedChat.reason,"PARTNER_OFFER_LEASE_OR_SOURCE_CHANGED_MID_MESSAGE",
 "C8 C6 must compare its C3 constructor-bound session, not stale scope facade")
eq(c6Observer.snapshot().status,"BLOCKED",
 "C8 post-rebind snapshot cannot carry a prior lease wishlist")
currentProtectedLease=lease

-- C8 second independent C6 counterexample: a P3/C3 own-census
-- refresh resets the offer revision even though the partner's stack mutates.
-- Chat processing spans TWO original C3/P4 GUI readings: do not attribute a
-- message to a trade whose terms changed, despite identical lease+revision.
local c6RevisedBridge=buildForProtectedLease(lease)
local c6ReadNumber=0
local c6OfferChanged=nil
local c6NoContentDrift,c6NoContentWhy=c6.new({
 bound=chatBound,crosswalk=market,now=now,readScope=oldChatScope,
 readContext=function()
  c6ReadNumber+=1
  if c6ReadNumber==1 then
   local before=c6RevisedBridge.researchContext()
   local theirAmount=theirs:FindFirstChild("Container"):FindFirstChild("Amount")
   theirAmount.Text="x2"
   eq(c6RevisedBridge.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
    "C8 original C3 inventory refresh resets local GUI revision")
   return before
  end
  return c6RevisedBridge.researchContext()
 end})
ok(c6NoContentDrift~=nil,"C8 passive C6 constructed from actual C3/P4 GUI")
local c6ChangedOffer=c6NoContentDrift.ingest({
 speakerUserId=opponent.UserId,text="@MainTestUser_Alpha LF Harvester",
 messageId="C8_CHAT_DURING_CHANGED_OFFER_ABA",
 channelName="RBXGeneral",observedAt=monotonic})
eq(c6ChangedOffer.status,"BLOCKED",
 "C8 C6 must invalidate chat attribution when partner changes offered copies")
eq(c6ChangedOffer.reason,"PARTNER_OFFER_LEASE_OR_SOURCE_CHANGED_MID_MESSAGE",
 "C8 same local lease/revision must not mask changed GUI offer contents")
theirs:FindFirstChild("Container"):FindFirstChild("Amount").Text=""

-- C8 final cross-language OFFLINE chain: genuinely execute C3 scanner/P4
-- GUI -> C6 passive speaker attribution -> C7 original V2 native staging.
-- P3 request/accept and P4 closure receipts below are synthetic test state,
-- NOT observed game requests, settlements or Discord transport.
currentProtectedLease=lease
local c8Bridge=buildForProtectedLease(lease)
local c8C6,c8C6Error=c6.new({
 bound=chatBound,crosswalk=market,now=now,readScope=oldChatScope,
 readContext=function()return c8Bridge.researchContext()end})
ok(c8C6~=nil,"C8 original C3/P4 to genuine C6 passive chat connected")
local c8Other=c8C6.ingest({
 speakerUserId=localPlayer.UserId,text="@MainTestUser_Alpha LF Harvester",
 messageId="C8_ORIGINAL_OTHER_SPEAKER",channelName="RBXGeneral",
 observedAt=monotonic})
eq(c8Other.status,"IGNORED_OTHER_SPEAKER",
 "C8 original C6 speaker rejection cannot classify different sender")
local c8Tentative=c8C6.ingest({
 speakerUserId=opponent.UserId,text="LF Harvester",
 messageId="C8_ORIGINAL_UNADDRESSED_CHAT",channelName="RBXGeneral",
 observedAt=monotonic})
eq(c8Tentative.status,"PASSIVE_ITEM_PREFERENCE",
 "C8 actual C6 notices item preference even if not addressed to main")
eq(c8Tentative.personalReplyProven,false,
 "C8 original unaddressed partner chat is not verified direct response")
local c8Directed=c8C6.ingest({
 speakerUserId=opponent.UserId,text="@MainTestUser_Alpha LF Harvester",
 messageId="C8_ORIGINAL_DIRECT_CHAT",channelName="RBXGeneral",
 observedAt=monotonic})
eq(c8Directed.status,"PASSIVE_ITEM_PREFERENCE",
 "C8 genuine C6 accepts exact bound speaker and username mention")
eq(c8Directed.personalReplyProven,true,
 "C8 only genuine original C6 directly addressed user is eligible for V2 direct")
eq(c8Directed.clientOfferRevision,1,
 "C8 genuine C3 local GUI revision is attached to C6 observation")
local c8V2=luau.load(fs.readFile(base.."native_v2_client_response_envelope.lua"))()
local function c8TestDigest(msg)
 -- Intentionally non-cryptographic Lune test stub. NOT a real SHA256.
 local h=2166136261
 for i=1,#msg do
  h=bit32.bxor(h,string.byte(msg,i))
  h=(h*16777619)%4294967296
 end
 local t=string.format("%08x",h)
 return t..t..t..t..t..t..t..t
end
local c8Bound={jobId=job,leaseId=lease,
 localUserId=localPlayer.UserId,partnerUserId=opponent.UserId,
 scope="PUBLIC_CLIENT_OBSERVATION"}
local c8Envelope,c8EnvelopeError=c8V2.new({
 salt=string.rep("g",48),nonce="C8_OFFLINE_SYNTHETIC_NONCE_V2",
 bound=c8Bound,cryptoSha256=c8TestDigest,
 readP3P4Lease=function()
  return {jobId=job,leaseId=lease,localUserId=localPlayer.UserId,
   partnerUserId=opponent.UserId,
   active=active and currentProtectedLease==lease,clientOnly=true}
 end})
ok(c8Envelope~=nil,"C8 original C7 native V2 sequencer bound to C3/P4 scope")
local function c8Receipt(kind,rev,witness)
 return {kind=kind,revision=rev,clientOnly=true,
  observedByReviewedP3P4=true,clientWitnessKind=witness}
end
local ca=c8Envelope.stage("MAIN_REQUEST_PENDING",
 c8Receipt("MAIN_REQUEST_PENDING",0,"P3_REQUEST_SUBMITTED"))
eq(ca.status,"CLIENT_V2_ENVELOPE_STAGED_NOT_SENT",
 "C8 synthetic request baseline is never a network transmission")
local cb=c8Envelope.stage("PARTNER_REQUEST_ACCEPTED",
 c8Receipt("PARTNER_REQUEST_ACCEPTED",0,"P3_PARTNER_REQUEST_ACCEPTED"))
eq(cb.payload.kind,"PARTNER_REQUEST_ACCEPTED",
 "C8 synthetic request acceptance only a client phase")
local cc=c8Envelope.stage("PARTNER_OFFER_REVISION",
 c8Receipt("PARTNER_OFFER_REVISION",c8Directed.clientOfferRevision,
  "P4_OFFER_REVISION_OBSERVED"))
eq(cc.payload.revision,1,"C8 C3 actual GUI revision reaches V2 client revision")
local tentativeV2=c8Receipt("CHAT_DIRECT_CLIENT_ATTRIBUTED",1,
 "C6_PARTNER_CHAT_CLASSIFIED")
tentativeV2.chatEvidenceClientOnly=true
tentativeV2.provenDirectedPartnerMessage=c8Tentative.personalReplyProven
eq(c8Envelope.stage("CHAT_DIRECT_CLIENT_ATTRIBUTED",tentativeV2).reason,
 "V2_TENTATIVE_CHAT_NOT_DIRECT",
 "C8 C6 tentative chat cannot be promoted to V2 directed message")
local directV2=c8Receipt("CHAT_DIRECT_CLIENT_ATTRIBUTED",1,
 "C6_PARTNER_CHAT_CLASSIFIED")
directV2.chatEvidenceClientOnly=true
directV2.provenDirectedPartnerMessage=c8Directed.personalReplyProven
local cd=c8Envelope.stage("CHAT_DIRECT_CLIENT_ATTRIBUTED",directV2)
eq(cd.payload.kind,"CHAT_DIRECT_CLIENT_ATTRIBUTED",
 "C8 actual C6 verified speaker+address feeds C7 native body only")
local ce=c8Envelope.stage("CLIENT_WINDOW_CLOSED_UNKNOWN",
 c8Receipt("CLIENT_WINDOW_CLOSED_UNKNOWN",1,
  "P4_TRADE_WINDOW_OUTCOME_OBSERVED"))
eq(ce.payload.kind,"CLIENT_WINDOW_CLOSED_UNKNOWN",
 "C8 synthetic terminal window closure stays UNKNOWN, never settlement")
eq(c8Envelope.summary().clientSessionPhase,"TERMINAL",
 "C8 native C7 V2 episode terminated locally without trading authority")
eq(c8Envelope.summary().mayUseForStrategyLearning,false,
 "C8 C7 no client-only feedback can train a live partner model")
local c8Fixture={fixtureOnly=true,transportNeverSent=true,
 syntheticP3Request=true,syntheticP4Closure=true,
 actualOriginalC3C6C7CodeExecuted=true,
 records={ca.payload,cb.payload,cc.payload,cd.payload,ce.payload}}
local c8Encoded=serde.encode("json",c8Fixture)
for _,secret in ipairs({job,lease,tostring(localPlayer.UserId),
 tostring(opponent.UserId),"MainTestUser_Alpha"}) do
 eq(c8Encoded:find(secret,1,true),nil,
  "C8 native V2 receiver fixture must not leak private raw bindings")
end
fs.writeFile("pdiddler/ci/.generated_system2_c8_original_c6_v2.json",c8Encoded)

local repeatFrame=bridge.observeOffer()
eq(repeatFrame.clientRevision,1,"unchanged stable client revision")
ours:FindFirstChild("Container"):FindFirstChild("Amount").Text="x5"
local changed=bridge.observeOffer()
eq(changed.status,"CLIENT_OFFER_CHANGED_PREVIEW_INVALIDATED","offer changed")
eq(changed.clientRevision,2,"revision advanced")
eq(changed.priorPreviewInvalidated,true,"old preview invalidated")
ours:FindFirstChild("Container"):FindFirstChild("Amount").Text="x7"
eq(bridge.observeOffer().reason,"OUR_OUTGOING_TARGET_OR_QUANTITY_INVALID",
   "outgoing qty greater than profile")
ours:FindFirstChild("Container"):FindFirstChild("Amount").Text="x6"
ours.Attributes.ItemId="Gingerscope"
ours:FindFirstChild("Tags").children.Chroma.Visible=false
ours:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Gingerscope"
eq(bridge.observeOffer().reason,"OUR_OUTGOING_TARGET_OR_QUANTITY_INVALID",
   "Gingerscope never outbound")
ours.Attributes.ItemId="EmberbowChroma"
ours:FindFirstChild("Tags").children.Chroma.Visible=true
ours:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Chroma Emberbow"
ours:FindFirstChild("Tags").children.Chroma.Visible=false
ours:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Emberbow"
eq(bridge.observeOffer().reason,"OUR_OFFER_RAW_KEY_LABEL_OR_CHROMA_CONFLICT",
   "wrong chroma label AND tag fails closed")
ours:FindFirstChild("Tags").children.Chroma.Visible=true
ours:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Chroma Emberbow"
ours.Attributes.ItemId=nil
local nameOnly=bridge.observeOffer()
eq(nameOnly.status,"CLIENT_OFFER_CHANGED_PREVIEW_INVALIDATED",
   "original GUI has no raw item attr but exact name produces research candidate")
eq(nameOnly.nameOnlyCatalogCandidateCount,1,
   "name-only item explicitly remains unverified")
eq(nameOnly.exactRawAttributesBothSidesObserved,false,
   "name candidate cannot become exact raw attribute evidence")
eq(nameOnly.authorizesOffer,false,"research-only label never authorizes offers")
eq(nameOnly.our.items[1].clientIdentityEvidence,
   "UNVERIFIED_NAME_ONLY_GAME_CATALOG_CANDIDATE",
   "candidate identity uncertainty preserved")
ours.Attributes.ItemId="EmberbowChroma"
theirs.Attributes.ItemId=nil
theirs:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Laser"
eq(bridge.observeOffer().reason,
   "THEIR_NAME_CANDIDATE_KNOWN_CROSS_TIER_NAME_COLLISION_NEEDS_RAW_ID",
   "old native Stage9 Laser collision remains blocked")
theirs.Attributes.ItemId="Iceblaster"
theirs:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Iceblaster"
appendSlot(ourList,5,"Iceblaster","Iceblaster","",false)
eq(bridge.observeOffer().reason,"GUI_CAPTURE_PHYSICAL_SLOT_LAYOUT_EXCEEDS_FOUR",
   "native GUI capture refuses fifth physical slot")
ourList.children.NewItem5=nil
opponent.Name="SomeoneElse"
eq(bridge.observeOffer().reason,"GUI_CAPTURE_GUI_PARTNER_DIFFERENT_FROM_BOUND_ACCOUNT",
   "changed partner GUI association rejects")
opponent.Name="PartnerUser"
active=false
eq(bridge.observeOffer().reason,"GUI_CAPTURE_REVIEWED_P3_P4_LEASE_NOT_ACTIVE",
   "stolen or invalidated lease")
active=true
monotonic=40
eq(bridge.observeOffer().reason,"OWN_CENSUS_EXPIRED_REFRESH_REQUIRED",
   "own profile max age 30 seconds")
monotonic=1.4
utc=sourceEpoch+21601
eq(bridge.refreshOwn().reason,"SOURCE_CROSSWALK_EXPIRED_OR_UNVERIFIED",
   "source 6hr expires and stops")
utc=sourceEpoch+20
local counterfeit=serde.decode("json",fs.readFile(base.."research_market_crosswalk_current.json"))
counterfeit.authorizesTrade=true
local nope,err=core.new({scannerApi=reader,sync=sync,crosswalk=counterfeit,
 captureOffer=adapter.capture,utcNow=tick,monoNow=now,
 sourceRetrievedEpoch=sourceEpoch,jobId=job,leaseId=lease,
 partnerUserId=opponent.UserId})
eq(nope,nil,"forged trade authorization rejected")
eq(err,"SOURCE_CROSSWALK_CONTRACT_INVALID","source authority denial")
-- C8 end-to-end ORIGINAL-SOURCE *read-only* research, no user actions:
-- genuine C3 scanner+P4 GUI, C4 bilateral scorer, C5 bounded multi-step
-- search, C6 partner-speaker chat, C7 private native V2 summary, all wired
-- to a single protected synthetic P3/P4 job/lease. This is not MM2 live.
currentProtectedLease=lease
active=true
monotonic=1.4
utc=sourceEpoch+20
ours.Attributes.ItemId="Frostsaber"
ours:FindFirstChild("ItemName"):FindFirstChild("Label").Text=rows.Frostsaber.expectedGameName
ours:FindFirstChild("Container"):FindFirstChild("Amount").Text=""
ours:FindFirstChild("Tags").children.Chroma.Visible=false
theirs.Attributes.ItemId="SnowDagger"
theirs:FindFirstChild("ItemName"):FindFirstChild("Label").Text=rows.SnowDagger.expectedGameName
theirs:FindFirstChild("Container"):FindFirstChild("Amount").Text=""
appendSlot(theirList,2,"Icepiercer",rows.Icepiercer.expectedGameName,"",false)
local goalOwned={"Frostsaber","Iceblaster","Harvester","OrangeSeer"}
local growthScanner={getOwnInventory=function()
 local result={items={},seen={},rawOwned=#goalOwned,unmapped=0,badQty=0,
  fingerprint="",total=99999999,unpriced=#goalOwned}
 for _,id in ipairs(goalOwned) do
  local v=rows[id]
  result.items[#result.items+1]={id=id,cat="Weapons",
   name=v.expectedGameName,qty=1,page=v.marketCategory,type=v.gameItemType}
  result.seen[#result.seen+1]=id.."x1"
 end
 table.sort(result.seen)
 result.fingerprint=table.concat(result.seen,"|")
 return result,nil
end}
local growthC3,whyGrowthC3=glue.new({
 core=core,captureAdapter=capture,scope=scope,game=game,players=players,
 sync=sync,scannerApi=growthScanner,nameResolver=resolver,crosswalk=market,
 isBoundSession=function()return active and currentProtectedLease==lease end,
 utcNow=tick,monoNow=now,sourceRetrievedEpoch=sourceEpoch})
ok(growthC3~=nil,"C8 real scanner/P4 GUI research bridge for target acquisition")
eq(growthC3.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
 "C8 original scanner observes four owned weapons with NO Gingerscope")
local c8Start=growthC3.researchContext()
eq(c8Start.ownCounts.Gingerscope,nil,
 "C8 original source client census does not already own protected target")
eq(c8Start.offer.their.items[1].id,"SnowDagger",
 "C8 genuine P4 GUI gives first independently identifiable candidate")
eq(c8Start.offer.their.items[2].id,"Icepiercer",
 "C8 genuine P4 GUI gives second independent candidate")
local c8C4Gate,c8C4Why=nativeBilateralBridge.new({
 marketBridge=growthC3,bilateralCore=nativeBilateral,crosswalk=market})
ok(c8C4Gate~=nil,"C8 actual C3 to C4 strategy scorer")
local c8C5Core=luau.load(fs.readFile(base.."native_multistep_growth_shadow.lua"))()
local c8C5Glue=luau.load(fs.readFile(base.."native_multistep_growth_bridge.lua"))()
local c8C5Gate,c8C5Why=c8C5Glue.new({
 marketBridge=growthC3,growthCore=c8C5Core,
 bilateralCore=nativeBilateral,crosswalk=market})
ok(c8C5Gate~=nil,"C8 genuine C3 to C4 oracle to C5 growth planner")
local c8PartnerChat,c8PartnerErr=c6.new({
 bound=chatBound,crosswalk=market,
 readContext=function()return growthC3.researchContext()end,
 readScope=oldChatScope,now=now})
ok(c8PartnerChat~=nil,"C8 C6 partner attribution reads same original C3")
local c8ChatSignal=c8PartnerChat.ingest({
 speakerUserId=opponent.UserId,text="@MainTestUser_Alpha LF Harvester",
 messageId="C8_COMPLETE_ORIGINAL_CHAIN_C6_DIRECT",
 channelName="RBXGeneral",observedAt=monotonic})
eq(c8ChatSignal.personalReplyProven,true,
 "C8 speaker-bound C6 signal from actual original C3/P4 chain")
local c8GateSource=luau.load(fs.readFile(base.."native_c8_original_source_replay.lua"))()
local c8Gate,c8GateWhy=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=c8Envelope})
ok(c8Gate~=nil,"C8 final original C3 through C7 gate constructed")
local c8Options={
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="Frostsaber",quantity=1}},
  receive={{id="SnowDagger",quantity=1}}},
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="Iceblaster",quantity=1}},
  receive={{id="Icepiercer",quantity=1}}}
}
local c8SellerStages={
 {kind="EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_STOCK",
  stock={{id="Waves_K",quantity=1},{id="FlowerwoodGun",quantity=1},
   {id="Ocean_G",quantity=1},{id="Blizzard",quantity=1}},
  availabilityVerified=false,willingnessVerified=false},
 {kind="EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_STOCK",
  stock={{id="Snowcannon",quantity=1},{id="SunsetKnife",quantity=1},
   {id="Bauble",quantity=1},{id="SunsetGun",quantity=1}},
  availabilityVerified=false,willingnessVerified=false},
}
local c8Full=c8Gate:replay(c8Options,c8SellerStages)
eq(c8Full.status,"OFFLINE_C8_ORIGINAL_CHAIN_RESEARCH_ONLY",
 "C8 original C3/P4→C4→C5→C6→C7 replay, blocked reason "..tostring(c8Full.reason))
eq(c8Full.c4Status,"ABSTAIN_PARTNER_INTENT_UNVERIFIED",
 "C8 actual bilateral research abstains without verified partner consent")
eq(c8Full.c5Status,"RESEARCH_GROWTH_ROUTE_DISCOVERY_ONLY",
 "C8 actual C5 generates multiple real-source hypothetical growth paths")
ok(c8Full.c5HypotheticalRouteCount>=2,
 "C8 multi-step planner genuinely compares different growth paths")
eq(c8Full.c6Status,"CLIENT_ONLY_PASSIVE_PARTNER_PREFERENCE_RESEARCH",
 "C8 real C6 passive chat research integrated")
eq(c8Full.v2EventsStagedLocally,5,"C8 original V2 client-only staged episode")
eq(c8Full.authorizesOffer,false,"C8 full replay cannot place offer")
eq(c8Full.authorizesAccept,false,"C8 full replay cannot press final Accept")
eq(c8Full.mayUseForStrategyLearning,false,"C8 unknown client feedback cannot train")
eq(c8Full.actualTradeOutcome,"UNKNOWN","C8 no fabricated settled trade")
eq(c8Full.hasAuthenticatedGameSettlement,false,
 "C8 client-only C3/P4 source is not game-server evidence")
local c8Rendered=serde.encode("json",c8Full)
for _,private in ipairs({job,lease,tostring(localPlayer.UserId),
 tostring(opponent.UserId),"MainTestUser_Alpha","Frostsaber","SnowDagger"}) do
 eq(c8Rendered:find(private,1,true),nil,
  "C8 combined summary never exports private trade or item identities")
end
-- C8 adversarial end-to-end protected lease swap after C7 summary, before
-- final C3 read; even C4/C5 internal reads can each have been stable.
local c8LostLease={summary=function()
 currentProtectedLease="P3_PROTECTED_NEW_LEASE_99"
 return c8Envelope.summary()
end,matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope}
local c8ChangedGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,c6=c8PartnerChat,c7=c8LostLease})
local c8Changed=c8ChangedGate:replay(c8Options,c8SellerStages)
eq(c8Changed.status,"BLOCKED",
 "C8 lease turnover even after planning invalidates whole chain")
eq(c8Changed.reason,"C8_ORIGINAL_SOURCE_SCOPE_OR_OFFER_CHANGED_DURING_REPLAY",
 "C8 source reader proves old protected lease was revoked")
currentProtectedLease=lease
-- C8 changed source publication while C7 is staging also fails closed.
local c8OldMarket={summary=function()
 utc=sourceEpoch+21601
 return c8Envelope.summary()
end,matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope}
local c8TimeGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,c6=c8PartnerChat,c7=c8OldMarket})
local c8SourceDrift=c8TimeGate:replay(c8Options,c8SellerStages)
eq(c8SourceDrift.status,"BLOCKED",
 "C8 stale source during chain fails even if initial publisher was fresh")
utc=sourceEpoch+20
-- Reject a misleading C7 stream from a different lease independently.
local badC7Bound={jobId=job,leaseId="MISMATCHED_PROTECTED_LEASE",
 localUserId=localPlayer.UserId,partnerUserId=opponent.UserId,
 scope="PUBLIC_CLIENT_OBSERVATION"}
local differentC7=c8V2.new({bound=badC7Bound,
 salt=string.rep("h",48),nonce="C8_DIFFERENT_CLIENT_EPISODE_02",
 cryptoSha256=c8TestDigest,
 readP3P4Lease=function()
  return {jobId=job,leaseId=lease,
   localUserId=localPlayer.UserId,partnerUserId=opponent.UserId,
   active=active,clientOnly=true}
 end})
ok(differentC7~=nil,"C8 malformed-binding V2 test instance can be constructed")
local c8BadV2Gate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=differentC7})
local c8OtherSession=c8BadV2Gate:replay(c8Options,c8SellerStages)
eq(c8OtherSession.status,"BLOCKED",
 "C8 V2 client feedback must belong to exact C3 job/lease/partner")
eq(c8OtherSession.reason,"C8_NATIVE_C7_WRONG_OR_INACTIVE_PROTECTED_LEASE",
 "C8 different lease privacy-preserving boolean session binding enforced")

-- A failed protected lease/source event must not corrupt the in-memory
-- baseline when original client scope is actually restored.
eq(c8Gate:replay(c8Options,c8SellerStages).status,
 "OFFLINE_C8_ORIGINAL_CHAIN_RESEARCH_ONLY",
 "C8 recovery after revoked lease and stale publisher (same known valid scope)")
-- C8 private V2 local revision must match C3 current offer revision even if
-- all session IDs match; no stale success/acceptance label crosses revisions.
local c8WrongRevision={matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope,
 summary=function()
  local original=c8Envelope.summary()
  local copy={}
  for k,v in pairs(original) do copy[k]=v end
  copy.currentClientRevision=999
  return copy
 end}
local c8RevGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=c8WrongRevision})
eq(c8RevGate:replay(c8Options,c8SellerStages).reason,
 "C8_NATIVE_C7_OFFER_REVISION_NOT_CURRENT",
 "C8 stale C7 local revision is not valid current GUI evidence")
-- Reject forged C7 final Accept even with otherwise correct scope.
local c8FalseAuth={matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope,
 summary=function()
  local original=c8Envelope.summary()
  local copy={}
  for k,v in pairs(original) do copy[k]=v end
  copy.authorizesAccept=true
  return copy
 end}
local c8ForgedGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=c8FalseAuth})
eq(c8ForgedGate:replay(c8Options,c8SellerStages).reason,
 "C8_ORIGINAL_C7_UNVERIFIED_TRANSPORT_OR_AUTHORITY",
 "C8 forged final Accept permission cannot pass the integrated replay")
-- P3 job/server hop after C7 summary, before final original GUI read.
local c8Hop={matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope,
 summary=function()
  game.JobId="DIFFERENT_ORIGINAL_MM2_SERVER"
  return c8Envelope.summary()
 end}
local c8HopGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=c8Hop})
eq(c8HopGate:replay(c8Options,c8SellerStages).reason,
 "C8_ORIGINAL_SOURCE_SCOPE_OR_OFFER_CHANGED_DURING_REPLAY",
 "C8 actual original P4 GUI packet denies server hop mid-replay")
game.JobId=job
-- Same-userID player Name no longer matches P4 GUI username: no auto
-- acceptance or carryover of prior speaker preferences.
local c8OtherPartner={matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope,
 summary=function()
  opponent.Name="DIFFERENT_BOUND_TRADING_PARTNER"
  return c8Envelope.summary()
 end}
local c8OtherPartnerGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=c8OtherPartner})
eq(c8OtherPartnerGate:replay(c8Options,c8SellerStages).reason,
 "C8_ORIGINAL_SOURCE_SCOPE_OR_OFFER_CHANGED_DURING_REPLAY",
 "C8 changed real GUI account name invalidates original partner association")
opponent.Name="PartnerUser"
-- C3 profile refreshed with a new actual owned key but SAME qty and
-- SAME client offer revision. C8 must compare true raw inventory contents.
local c8ReplaceCensus={matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope,
 summary=function()
  goalOwned[3]="Slasher"
  eq(growthC3.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
   "C8 original C3 independent four-weapon scanner refresh")
  return c8Envelope.summary()
 end}
local c8ReplaceGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=c8ReplaceCensus})
eq(c8ReplaceGate:replay(c8Options,c8SellerStages).reason,
 "C8_ORIGINAL_SOURCE_SCOPE_OR_OFFER_CHANGED_DURING_REPLAY",
 "C8 changed owned weapon key hidden by unchanged qty/revision invalidates")
goalOwned[3]="Harvester"
eq(growthC3.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
 "C8 original source can restore owned census without leaking trade actions")
eq(c8Gate:replay(c8Options,c8SellerStages).status,
 "OFFLINE_C8_ORIGINAL_CHAIN_RESEARCH_ONLY",
 "C8 recovers after changed raw owned weapon was rejected")
-- Finally change the partner's actual P4 GUI Amount without changing job,
-- partner, lease, owned census, or source after C6 saw the old offer.
local c8LateOffer={matchesOriginalBoundScope=c8Envelope.matchesOriginalBoundScope,
 summary=function()
  theirs:FindFirstChild("Container"):FindFirstChild("Amount").Text="x2"
  return c8Envelope.summary()
 end}
local c8LateOfferGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=c8PartnerChat,c7=c8LateOffer})
eq(c8LateOfferGate:replay(c8Options,c8SellerStages).reason,
 "C8_ORIGINAL_SOURCE_SCOPE_OR_OFFER_CHANGED_DURING_REPLAY",
 "C8 changed two-sided offer after C6/C7 refuses stale planned routes")
theirs:FindFirstChild("Container"):FindFirstChild("Amount").Text=""

-- C8 alternate legitimate client state: both visible GUI Accepted
-- indicators are ON for a coherent current offer, but this is NOT a
-- server-approved settlement and must never imply final Accept authority.
our:FindFirstChild("Accepted").Visible=true
their:FindFirstChild("Accepted").Visible=true
eq(growthC3.refreshOwn().status,"READONLY_OWN_MARKET_BOUND",
 "C8 renew client-census epoch after changed Accepted indicators")
local acceptedContext=growthC3.researchContext()
eq(acceptedContext.clientOfferRevision,1,
 "C8 accepted GUI state gets new local revision after scanner rebase")
eq(acceptedContext.offer.ourAccepted,true,
 "C8 original P4 observer sees client-side ours accepted")
eq(acceptedContext.offer.theirAccepted,true,
 "C8 original P4 observer sees client-side partner accepted")
local acceptedOptions={
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="Frostsaber",quantity=1}},
  receive={{id="SnowDagger",quantity=1},{id="Icepiercer",quantity=1}}},
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={{id="Iceblaster",quantity=1}},
  receive={{id="Icepiercer",quantity=1}}}
}
local acceptedScorer=c8C4Gate:compare(acceptedOptions)
eq(acceptedScorer.status,"CLIENT_SHADOW_PREFERS_OBSERVED_ACCEPTED_OFFER",
 "C8 C4 can flag exact observed accepted GUI offer only as client shadow")
eq(acceptedScorer.selectedIndexIsActionable,false,
 "C8 accepted client indicator is NOT a trade recommendation")
eq(acceptedScorer.authorizesAccept,false,
 "C8 accepted client indicator NEVER authorizes final Accept")
local acceptedChat=c6.new({
 bound=chatBound,crosswalk=market,
 readContext=function()return growthC3.researchContext()end,
 readScope=oldChatScope,now=now})
ok(acceptedChat~=nil,"C8 fresh C6 passive observer after GUI revision renewal")
local acceptedC6Signal=acceptedChat.ingest({
 speakerUserId=opponent.UserId,text="@MainTestUser_Alpha LF Harvester",
 messageId="C8_ACCEPTED_SHADOW_C6_CHAT",
 channelName="RBXGeneral",observedAt=monotonic})
eq(acceptedC6Signal.personalReplyProven,true,
 "C8 accepted GUI still requires independently attributable client speaker")
local acceptedEnvelope=c8V2.new({
 bound=c8Bound,salt=string.rep("j",48),
 nonce="C8_ACCEPTED_SHADOW_LOCAL_ONLY_NONCE_V2",
 cryptoSha256=c8TestDigest,
 readP3P4Lease=function()
  return {jobId=job,leaseId=lease,localUserId=localPlayer.UserId,
   partnerUserId=opponent.UserId,active=active,clientOnly=true}
 end})
ok(acceptedEnvelope~=nil,"C8 fresh C7 V2 client-local revision builder")
acceptedEnvelope.stage("MAIN_REQUEST_PENDING",
 c8Receipt("MAIN_REQUEST_PENDING",0,"P3_REQUEST_SUBMITTED"))
acceptedEnvelope.stage("PARTNER_REQUEST_ACCEPTED",
 c8Receipt("PARTNER_REQUEST_ACCEPTED",0,"P3_PARTNER_REQUEST_ACCEPTED"))
acceptedEnvelope.stage("PARTNER_OFFER_REVISION",
 c8Receipt("PARTNER_OFFER_REVISION",1,"P4_OFFER_REVISION_OBSERVED"))
local acceptedFullGate=c8GateSource.new({
 c3=growthC3,c4=c8C4Gate,c5=c8C5Gate,
 c6=acceptedChat,c7=acceptedEnvelope})
local acceptedFull=acceptedFullGate:replay(acceptedOptions,c8SellerStages)
eq(acceptedFull.status,"OFFLINE_C8_ORIGINAL_CHAIN_RESEARCH_ONLY",
 "C8 original accepted-but-client-only offer can pass research-only integration")
eq(acceptedFull.c4Status,"CLIENT_SHADOW_PREFERS_OBSERVED_ACCEPTED_OFFER",
 "C8 safe C4 preference is still nonactionable after all modules")
eq(acceptedFull.authorizesAccept,false,
 "C8 both sides Accepted indicators STILL never authorize a script Accept")
eq(acceptedFull.hasAuthenticatedGameSettlement,false,
 "C8 accepted indicator is not server settlement")
our:FindFirstChild("Accepted").Visible=false
their:FindFirstChild("Accepted").Visible=false

print("SYSTEM2_LIVE_MARKET_NATIVE_BRIDGE_ASSERTIONS_PASSED "..tostring(count))
