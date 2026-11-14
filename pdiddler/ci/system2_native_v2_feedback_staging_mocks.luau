-- C7 native V2 client envelope fixture. All account identifiers are synthetic.
-- Generates a temporary local JSON fixture for Python strict-V2 consumer replay,
-- does NOT send anything to Discord or real MM2 game services.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local source=luau.load(fs.readFile("pdiddler/system2/native_v2_client_response_envelope.lua"))()
local count=0
local function eq(a,b,reason)
 count+=1
 assert(a==b,reason..": expected "..tostring(b).." got "..tostring(a))
end
local function yes(x,reason)count+=1;assert(x,reason)end
local function crypto(msg)
 -- TEST HASH STUB, NOT CRYPTOGRAPHIC SHA256, NEVER USE IN A REAL CLIENT.
 local h=2166136261
 for i=1,#msg do
  h=bit32.bxor(h,string.byte(msg,i))
  h=(h*16777619)%4294967296
 end
 local t=string.format("%08x",h)
 return t..t..t..t..t..t..t..t
end
local config={
 salt=string.rep("f",48),nonce="synthetic_c7_event_nonce_1",
 bound={
  jobId="FAKE_JOB_ID_COMP7",leaseId="FAKE_LEASE_ID_COMP7",
  localUserId=500010001,partnerUserId=500010002,
  scope="PUBLIC_CLIENT_OBSERVATION",
 },
 cryptoSha256=crypto,
}
local active=true
config.readP3P4Lease=function()
 return {
   jobId=config.bound.jobId,leaseId=config.bound.leaseId,
   localUserId=config.bound.localUserId,
   partnerUserId=config.bound.partnerUserId,
   active=active,clientOnly=true,
 }
end
local staged,why=source.new(config)
yes(staged~=nil,"client-only staged envelope constructor")
local function receipt(kind,rev,witness)
 return {kind=kind,revision=rev,clientOnly=true,
   observedByReviewedP3P4=true,clientWitnessKind=witness}
end
eq(staged.stage("PARTNER_DECLINED",
 receipt("PARTNER_DECLINED",0,"P3_REQUEST_RESOLUTION_OBSERVED")).reason,
 "V2_REQUEST_BASELINE_REQUIRED","cannot record outcome without request baseline")
local a=staged.stage("MAIN_REQUEST_PENDING",
 receipt("MAIN_REQUEST_PENDING",0,"P3_REQUEST_SUBMITTED"))
eq(a.status,"CLIENT_V2_ENVELOPE_STAGED_NOT_SENT","baseline stored only locally")
eq(a.payload.event_seq,1,"first sequence 1")
eq(a.payload.kind,"MAIN_REQUEST_PENDING","private V2 event kind exact")
eq(a.payload.source,
 "PRIVATE_BOT_CLIENT_EVENT_CLAIM_NOT_SERVER_SETTLEMENT",
 "client only is not settlement")
eq(a.discordNetworkDeliveryVerified,false,"not sent to Discord")
eq(a.maySendDiscordWebhook,false,"not authorized to transmit")
local b=staged.stage("PARTNER_REQUEST_ACCEPTED",
 receipt("PARTNER_REQUEST_ACCEPTED",0,"P3_PARTNER_REQUEST_ACCEPTED"))
eq(b.payload.event_seq,2,"increment sequence")
eq(staged.stage("PARTNER_ACCEPT_INDICATOR",
 receipt("PARTNER_ACCEPT_INDICATOR",1,"P4_CLIENT_INDICATOR_OBSERVED")).reason,
 "V2_STALE_OR_FUTURE_OFFER_REVISION","indicator can't jump revision")
local c=staged.stage("PARTNER_OFFER_REVISION",
 receipt("PARTNER_OFFER_REVISION",1,"P4_OFFER_REVISION_OBSERVED"))
eq(c.payload.revision,1,"must witness offer revision")
local tentative=receipt("CHAT_DIRECT_CLIENT_ATTRIBUTED",1,
 "C6_PARTNER_CHAT_CLASSIFIED")
tentative.chatEvidenceClientOnly=true
eq(staged.stage("CHAT_DIRECT_CLIENT_ATTRIBUTED",tentative).reason,
 "V2_TENTATIVE_CHAT_NOT_DIRECT",
 "contextual chat cannot be certified as directed")
tentative.provenDirectedPartnerMessage=true
local d=staged.stage("CHAT_DIRECT_CLIENT_ATTRIBUTED",tentative)
eq(d.payload.kind,"CHAT_DIRECT_CLIENT_ATTRIBUTED","only C6 proven direct chat")
local e=staged.stage("PARTNER_ACCEPT_INDICATOR",
 receipt("PARTNER_ACCEPT_INDICATOR",1,"P4_CLIENT_INDICATOR_OBSERVED"))
eq(e.payload.revision,1,"accept indicator tied to current local revision")
local f=staged.stage("CLIENT_WINDOW_CLOSED_UNKNOWN",
 receipt("CLIENT_WINDOW_CLOSED_UNKNOWN",1,"P4_TRADE_WINDOW_OUTCOME_OBSERVED"))
eq(f.payload.kind,"CLIENT_WINDOW_CLOSED_UNKNOWN",
 "client window close never called completed settlement")
eq(staged.summary().clientSessionPhase,"TERMINAL","no events after terminal")
eq(staged.stage("MAIN_REQUEST_PENDING",
 receipt("MAIN_REQUEST_PENDING",0,"P3_REQUEST_SUBMITTED")).reason,
 "V2_CLIENT_EPISODE_TERMINAL","new request must use new lease")
for _,payload in ipairs({a.payload,b.payload,c.payload,d.payload,e.payload,f.payload}) do
 local prohibited={"username","user_id","item","weapon","rawChat","token","webhook_id",
   "channel_id","message_id","recorded_at_utc","completed"}
 for _,k in ipairs(prohibited) do
  eq(payload[k],nil,"V2 body excludes Discord transport and private raw data")
 end
 yes(type(payload.event_id)=="string" and #payload.event_id==64,
  "V2 local event digest is 64 hex test-only")
 yes(type(payload.partner_digest)=="string" and #payload.partner_digest==64,
  "V2 partner pseudonym does not contain user ID")
 eq(payload.client_provenance,"BOUND_CLIENT_OBSERVATION_UNVERIFIED_SERVER",
  "no server completion claim")
end
local broken=source.new({
 salt=string.rep("x",48),nonce="synthetic_c7_event_nonce_2",
 bound=config.bound,cryptoSha256=function()return string.rep("0",64)end,
 readP3P4Lease=config.readP3P4Lease,
})
eq(broken,nil,"same fixed digest for every field cannot establish source lineage")
local wrong,whyWrong=source.new({
 salt=string.rep("e",48),nonce="synthetic_c7_event_nonce_3",
 bound=config.bound,cryptoSha256=crypto,
 readP3P4Lease=config.readP3P4Lease,
})
yes(wrong~=nil,"second isolated local builder exists")
active=false
eq(wrong.stage("MAIN_REQUEST_PENDING",
 receipt("MAIN_REQUEST_PENDING",0,"P3_REQUEST_SUBMITTED")).reason,
 "V2_REVIEWED_LEASE_CHANGED","session/job/partner lease loss blocks all events")
active=true
local out={
 fixtureOnly=true,transportNeverSent=true,
 records={a.payload,b.payload,c.payload,d.payload,e.payload,f.payload},
}
fs.writeFile("pdiddler/ci/.generated_system2_v2_synthetic.json",serde.encode("json",out))
print("SYSTEM2_NATIVE_V2_ENVELOPE_STAGING_ASSERTIONS_PASSED "..tostring(count))
