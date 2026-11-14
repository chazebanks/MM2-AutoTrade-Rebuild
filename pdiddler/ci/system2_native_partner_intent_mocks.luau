-- Executes actual System2 C6 passive intent core and TextChatService adapter.
-- Real current 189-key public market source, MOCKED player/game chat events.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local root="pdiddler/system2/"
local market=serde.decode("json",fs.readFile(root.."research_market_crosswalk_current.json"))
local engine=luau.load(fs.readFile(root.."native_partner_intent_observer.lua"))()
local adapterModule=luau.load(fs.readFile(root.."native_partner_textchat_receiver.lua"))()
local count=0
local function eq(a,b,why)
 count+=1
 assert(a==b,why..": expected "..tostring(b).." got "..tostring(a))
end
local function yes(v,why) count+=1;assert(v,why)end
local function copy(v)return serde.decode("json",serde.encode("json",v))end
local rows={}
for _,r in ipairs(market.items) do rows[r.rawGameKeyCandidate]=r end
eq(#market.items,189,"actual public-key market source loaded")
yes(rows.Harvester~=nil and rows.FangChroma~=nil and rows.Iceblaster~=nil,
 "all item preference keys come from actual source")
local own=700000001
local opponent=700000009
local time=500
local revision=4
local offerWitnessAt=492
local offerWitnessRevision=revision
local witness=true
local active=true
local job="SYNTHETIC_JOB_C6"
local lease="SYNTHETIC_BOUND_LEASE"
local username="MainTestUser_Alpha"
local dname="TradeReader"
local otherDisplay="NotTradeReader"
local scope={jobId=job,leaseId=lease,localUserId=own,partnerUserId=opponent,
 mainUsername=username}
local game={PlaceId=142823291,JobId=job}
local lp={UserId=own,Name=username,DisplayName=dname}
local partner={UserId=opponent,Name="PartnerA",DisplayName="PartnerDisplay"}
local unrelated={UserId=700000099,Name="Spectator",DisplayName=otherDisplay}
local players={LocalPlayer=lp}
partner.Parent=players
unrelated.Parent=players
function players:GetPlayerByUserId(id)
 if id==opponent then return partner end
 if id==unrelated.UserId then return unrelated end
 return nil
end
function players:GetPlayers()return {lp,partner,unrelated} end
local msgs={}
local signal={callbacks={}}
function signal:Connect(fn)
 local connection={running=true,callback=fn}
 self.callbacks[#self.callbacks+1]=connection
 function connection:Disconnect()self.running=false end
 return connection
end
function signal:emit(msg)
 for _,c in ipairs(self.callbacks) do
  if c.running then c.callback(msg) end
 end
end
local svc={MessageReceived=signal}
local function ctx()
 return {
 schema="gingerscope-system2-local-bilateral-context-v1",
 status="LOCAL_READONLY_MARKET_OFFER_CONTEXT",
 ownCounts={Harvester=1,Iceblaster=1},
 offer={clientRevision=revision,clientOnly=true,readOnly=true,
  sourceAgeSeconds=90,ownedCensusAgeSeconds=1,
  our={items={}},their={items={{id="Harvester",quantity=1}}},
  authorizesOffer=false,authorizesAccept=false},
 clientOnly=true,readOnly=true,authorizesOffer=false,authorizesAccept=false,
 clientOfferRevision=revision,
 crosswalkRowsSha256=market.crosswalkRowsSha256,
 sourceRetrievedUtc=market.sourceRetrievedUtc,
 }
end
local mainBridge={researchContext=ctx}
local api,why=adapterModule.new({
 core=engine,game=game,players=players,textChatService=svc,
 bound=scope,marketBridge=mainBridge,crosswalk=market,
 isOriginalTradeLeaseActive=function()return active end,
 monotonicSeconds=function()return time end,
 getReviewedOwnOfferWitness=function()
  if not witness then return nil end
  return {kind="REVIEWED_CLIENT_OUR_OFFER_REVISION",jobId=job,
   leaseId=lease,clientOfferRevision=offerWitnessRevision,
   monotonicTime=offerWitnessAt}
 end})
yes(api~=nil,"original reader C3 + TextChatService actual UserId adapter constructed")
eq(api.start().status,"PASSIVE_CLIENT_CHAT_LISTENER_ATTACHED","passive subscribe only")
local n=0
local function msg(text,user,channel)
 n+=1
 return {Text=text,TextSource=user and {UserId=user} or nil,
  TextChannel={Name=channel or "RBXGeneral"},MessageId="test-message-"..tostring(n),
  PrefixText="UNTRUSTED_DISPLAY_NAME_NOT_USED"}
end
local function emit(text,user,channel)
 local m=msg(text,user or opponent,channel)
 signal:emit(m)
 return api.lastResult(),m
end
local ignored=emit("LF Harvester",unrelated.UserId)
eq(ignored.status,"IGNORED_OTHER_SPEAKER","never learn another player's chat as partner")
local system=emit("LF Harvester",nil)
-- Default test wrapper uses opponent for nil, explicit system is tested below.
local sys=api.readonlyProcessDeliveredTextChatMessage({
 Text="LF Harvester",TextSource=nil,TextChannel={Name="RBXGeneral"},MessageId="sys"})
eq(sys.reason,"TEXTSOURCE_USERID_MISSING_OR_SYSTEM_MESSAGE",
 "system chat not a player source")
local public=emit("LF Harvester")
eq(public.status,"PASSIVE_ITEM_PREFERENCE","public LF classified stated wish")
eq(public.addressType,"TENTATIVE_IN_CURRENT_TRADE_AFTER_OWN_OFFER",
 "recent own offer makes unaddressed phrase contextual but NOT proof of personal reply")
eq(public.personalReplyProven,false,"mere active trade is not a proven address")
local direct,firstMsg=emit("@MainTestUser_Alpha LF Harvester, NLF Chroma Fang")
eq(direct.status,"PASSIVE_ITEM_PREFERENCE","explicit trade chat contains two preferences")
eq(direct.personalReplyProven,true,"exact main username mention is directed")
eq(direct.addressType,"EXPLICIT_UNIQUE_MENTION","not PrefixText or display-name attribution")
local preferences={}
for _,p in ipairs(direct.itemPreferences) do preferences[p.key]=p.intent end
eq(preferences.Harvester,"WANTS","exact current market item wished")
eq(preferences.FangChroma,"AVOIDS","NLF Chroma Fang overrides public demand")
local flowerwood=emit("@MainTestUser_Alpha LF Flowerwood Gun")
eq(flowerwood.itemPreferences[1].key,"FlowerwoodGun",
 "full Flowerwood Gun beats prefix alias for Flowerwood Knife")
local orange=emit("@MainTestUser_Alpha NLF Orange Seer")
eq(orange.itemPreferences[1].key,"OrangeSeer",
 "full color Seer variant beats generic Seer suffix")
local again=api.readonlyProcessDeliveredTextChatMessage(firstMsg)
eq(again.status,"IGNORED_DUPLICATE_MESSAGE","roblox duplicate MessageReceived not double-learn")
local differentTarget=emit("@OtherUser nty")
eq(differentTarget.status,"AMBIGUOUS_RECIPIENT",
 "whisper/chat for another player must not become our refusal")
local accepted=emit("nty @MainTestUser_Alpha")
eq(accepted.signalType,"CHAT_REFUSAL_NOT_TRADE_DECLINE","chat nty not native trade decline")
eq(accepted.itemPreferenceIsAcceptedOffer,false,"chat never authorizes or proves trade")
local unknown=emit("@MainTestUser_Alpha I have Harvester")
eq(unknown.status,"PASSIVE_NO_DECODABLE_INTENT",
 "having item is not wanting or giving it")
local query=emit("what do you want?")
eq(query.signalType,"ASKS_WHAT_WE_WANT","contextual question without username detected")
eq(query.personalReplyProven,false,"contextual-only evidence remains tentative")
eq(query.addressType,"TENTATIVE_IN_CURRENT_TRADE_AFTER_OWN_OFFER",
 "only current witnessed own offer opens context")
local add=emit("can you add @MainTestUser_Alpha?")
eq(add.signalType,"REQUESTS_ADDS","add request is not known accepted trade")
local op=emit("need overpay @MainTestUser_Alpha")
eq(op.signalType,"REQUESTS_OVERPAY_UNQUANTIFIED",
 "overpay desire explicitly not a percentage")
local constraints=emit("@MainTestUser_Alpha no dupes, no seers, no pets, fewer items")
eq(constraints.constraints.noDuplicates,true,"no dupes captured")
eq(constraints.constraints.noSeers,true,"no seers captured")
eq(constraints.constraints.noPets,true,"no pets captured")
eq(constraints.constraints.compactInventory,true,"compact stock preference captured")
local negated=emit("@MainTestUser_Alpha LF Harvester but not Iceblaster")
local parsed={}
for _,it in ipairs(negated.itemPreferences) do parsed[it.key]=it.intent end
eq(parsed.Harvester,"WANTS","LF first item retains positive interest")
eq(parsed.Iceblaster,"AVOIDS","but not excludes second named item")
local tentative=emit("@MainTestUser_Alpha LF Harvester maybe Iceblaster")
local maybe={}
for _,it in ipairs(tentative.itemPreferences) do maybe[it.key]=it.intent end
eq(maybe.Iceblaster,"MENTION_ONLY",
 "maybe cannot upgrade a speculative item into a confirmed wishlist")
local snapshot=api.snapshot()
eq(snapshot.status,"CLIENT_ONLY_PASSIVE_PARTNER_PREFERENCE_RESEARCH",
 "only client evidence local snapshot")
eq(snapshot.explicitDirectedSignals>=4,true,"explicitly directed statements counted separately")
eq(snapshot.completedTradeProven,false,"never output successful trade")
eq(snapshot.empiricalAcceptanceProbability,nil,"no invented conversion estimate")
eq(snapshot.noRawChatRetained,true,"raw content not saved")
local dump=serde.encode("json",snapshot)
eq(dump:find("MainTestUser_Alpha",1,true),nil,
 "snapshot must not leak operator username or raw chat")
eq(dump:find("700000009",1,true),nil,
 "snapshot must not leak current partner account ID")
local compared=api.compareResearchOptions({
 {give={{id="Harvester",quantity=1}},receive={{id="Iceblaster",quantity=1}}},
 {give={{id="FangChroma",quantity=1}},receive={{id="Iceblaster",quantity=1}}},
})
eq(compared.status,"CLIENT_ONLY_PREFERENCE_COMPATIBILITY_RESEARCH",
 "actual current-source keys evaluated, not actions")
eq(compared.options[1].itemCompatibility,"MATCHES_STATED_ITEM_INTEREST",
 "Harvester wishlist matches offered item")
eq(compared.options[2].itemCompatibility,"CONFLICTS_STATED_PREFERENCE",
 "NLF Chroma Fang vetoes offer compatibility")
eq(compared.options[1].actualWillingnessToTrade,false,
 "wishlist does not prove they accept our exchange")
eq(compared.authorizesChat,false,"no bot message sent")
eq(compared.authorizesOffer,false,"no offer action")

local whisper=emit("LF Icepiercer",opponent,
 "RBXWhisper:"..tostring(own).."_"..tostring(opponent))
eq(whisper.addressType,"DIRECT_BOUND_WHISPER","strict matching whisper addressed to us")
eq(whisper.personalReplyProven,true,"whisper between exact client user IDs")
local otherWhisper=emit("LF Harvester",opponent,
 "RBXWhisper:"..tostring(opponent).."_"..tostring(unrelated.UserId))
eq(otherWhisper.status,"BLOCKED","whisper with someone else ignored")
local noDisplay=emit("@TradeReader LF Iceblaster")
eq(noDisplay.personalReplyProven,true,"unique current display name allowed")
unrelated.DisplayName=dname
local ambiguousDisplay=emit("@TradeReader LF Harvester")
eq(ambiguousDisplay.personalReplyProven,false,
 "nonunique display name never used as proof")
eq(ambiguousDisplay.status,"AMBIGUOUS_RECIPIENT",
 "ambiguous display mention never direct")
unrelated.DisplayName=otherDisplay
time=515
local afterWindow=emit("what do you want?")
eq(afterWindow.addressType,"PUBLIC_UNADDRESSED",
 "expired 12-second own-offer witness cannot bind unaddressed chat")
time=503
witness=false
local noWitness=emit("can you add?")
eq(noWitness.addressType,"PUBLIC_UNADDRESSED",
 "unverified own offer witness never creates attribution")
witness=true
-- A fresh witness bound to a DIFFERENT revision must never prove address.
offerWitnessRevision=99
local mismatchWitness=emit("can you add?")
eq(mismatchWitness.addressType,"PUBLIC_UNADDRESSED",
 "witness to wrong revision rejected")
offerWitnessRevision=revision
local commonSpeech=emit("what u want")
eq(commonSpeech.signalType,"ASKS_WHAT_WE_WANT",
 "documented real-player-style shorthand recognized as a question, not acceptance")
eq(commonSpeech.personalReplyProven,false,
 "shorthand alone does not imply user-directed recipient")
unrelated.Name="TradeReader"
local otherUsernameCollision=emit("@TradeReader LF Icepiercer")
eq(otherUsernameCollision.status,"AMBIGUOUS_RECIPIENT",
 "someone else's username colliding with our display name cannot prove address")
unrelated.Name="Spectator"
local old=api.snapshot()
yes(old.activeSignals>0,"brief in-session state kept for research")
revision+=1
local stale=api.snapshot()
eq(stale.activeSignals,0,
 "old-revision NTY and response signals do not apply to a new offer")
local portable={}
for _,p in ipairs(stale.itemPreferences) do portable[p.rawGameKeyCandidate]=p end
eq(portable.FangChroma.intent,"AVOIDS",
 "explicit NLF remains short-lived within same partner lease")
eq(portable.FangChroma.carriedAcrossOfferChange,true,
 "carried preference is visibly tagged from earlier offer revision")
local duplicateAfterRevision=api.readonlyProcessDeliveredTextChatMessage(firstMsg)
eq(duplicateAfterRevision.status,"IGNORED_DUPLICATE_MESSAGE",
 "same TextChatMessage cannot be reintroduced on new revision")
revision-=1
eq(api.snapshot().reason,"CLIENT_OFFER_REVISION_ROLLBACK",
 "stale or malicious client revision rollback blocked")
revision+=1

local wrongItem=api.compareResearchOptions({
 {give={{id="CompletelyInventedWeapon",quantity=1}},receive={}},
})
eq(wrongItem.status,"BLOCKED","unknown raw game id cannot match wishlist")
local badSpeaker=api.readonlyProcessDeliveredTextChatMessage({
 Text="LF Harvester",TextSource={UserId=0},
 TextChannel={Name="RBXGeneral"},MessageId="bad-source"})
eq(badSpeaker.reason,"TEXTSOURCE_USERID_MALFORMED",
 "missing or spoofed invalid source ID cannot be attributed")
active=false
eq(api.snapshot().status,"BLOCKED","original P3/P4 lease invalidates evidence")
active=true
local afterLeaseReopened=api.snapshot()
eq(afterLeaseReopened.activeSignals,0,"no chat evidence survives a lease gap")
eq(#afterLeaseReopened.itemPreferences,0,
 "no old wishlist contaminates restarted bound scope")
local beforeHop=emit("@MainTestUser_Alpha LF Harvester")
eq(beforeHop.status,"PASSIVE_ITEM_PREFERENCE","new active session reestablishes evidence")
game.JobId="CHANGED_SERVER"
eq(api.snapshot().status,"BLOCKED","server hop invalidates prior message binding")
game.JobId=job
eq(api.snapshot().activeSignals,0,"server hop clears retained preferences")
eq(api.stop().status,"PASSIVE_CHAT_LISTENER_DETACHED","can unsubscribe")
eq(api.start().status,"PASSIVE_CLIENT_CHAT_LISTENER_ATTACHED","one listener after explicit restart")
api.stop()

local oldAge=engine.new({
 bound=scope,crosswalk=market,
 readContext=function()
  local c=ctx();c.offer.sourceAgeSeconds=-1;return c end,
 readScope=function()
  return {jobId=job,leaseId=lease,localUserId=own,partnerUserId=opponent,
   mainUsername=username,tradeOpen=true,leaseActive=true} end,
 now=function()return time end})
yes(oldAge~=nil,"adversarial core exists for negative price-age input")
eq(oldAge.snapshot().status,"BLOCKED",
 "negative source-age cannot pass as a current offer")
local toggled=false
local changed=engine.new({
 bound=scope,crosswalk=market,
 readContext=function()
  local c=ctx()
  if toggled then c.clientOfferRevision+=1;c.offer.clientRevision+=1 end
  toggled=true
  return c
 end,
 readScope=function()
  return {jobId=job,leaseId=lease,localUserId=own,partnerUserId=opponent,
   mainUsername=username,tradeOpen=true,leaseActive=true}
 end,
 now=function()return time end,
})
yes(changed~=nil,"pure observer mock for mid-message revision change")
local mid=changed.ingest({
 speakerUserId=opponent,text="@MainTestUser_Alpha LF Harvester",
 messageId="revision-invalidation",channelName="RBXGeneral",observedAt=time})
eq(mid.reason,"PARTNER_OFFER_LEASE_OR_SOURCE_CHANGED_MID_MESSAGE",
 "changed offer between two context reads blocks evidence")
print("SYSTEM2_CHAT_PARTNER_IDENTITY_NATIVE_ASSERTIONS_PASSED "..tostring(count))
