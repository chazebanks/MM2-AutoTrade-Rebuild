-- Test real GitHub-public four-page 189 key JSON against the original
-- native C9 source gate under synthetic clocks and lease revocations.
-- The payload is from a real GitHub Actions HTML capture, NOT fabricated.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local original=luau.load(fs.readFile(
 "pdiddler/system2/native_c9_immutable_market_research_gate.lua"))()
local marketTxt=fs.readFile(
 "pdiddler/system2/c9_research_public_189_crosswalk.json")
local receiptTxt=fs.readFile(
 "pdiddler/system2/c9_research_public_source_admission.json")
local market=serde.decode("json",marketTxt)
local receipt=serde.decode("json",receiptTxt)
local date=market.sourceRetrievedUtc
local yyyy,mm,dd,hh,mi,ss=date:match(
 "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
assert(yyyy and ss,"C9 actual source UTC must be parseable")
local epoch=os.time({year=tonumber(yyyy),month=tonumber(mm),
 day=tonumber(dd),hour=tonumber(hh),min=tonumber(mi),sec=tonumber(ss),
 isdst=false})
local clock=epoch+30
local lease=true
local networkCount=0
local left=marketTxt
local right=receiptTxt
local function clone(x)return serde.decode("json",serde.encode("json",x))end
local function eq(x,y,msg)
 assert(x==y,tostring(msg)..": "..tostring(x).." != "..tostring(y))
end
local function make(deps)
 local d=deps or {}
 return original.new({
  fetch=function(url)
   networkCount+=1
   if d.afterFirstFetch and networkCount%2==1 then d.afterFirstFetch() end
   if url==original.SOURCE_URL then return left end
   if url==original.RECEIPT_URL then return right end
   error("C9 unpinned or unexpected URL rejected")
  end,
  decode=function(s)return serde.decode("json",s)end,
  isoToEpoch=function(s)
   if s==date then return epoch end
   error("non-current source timestamp denied")
  end,
  utcNow=function()return clock end,
  isBoundSession=function()return lease end,
 })
end
local tests=0
local function check(x,y,msg)tests+=1;eq(x,y,msg)end
check(original.SNAPSHOT_COMMIT,
 "734a316ee8d1afa14da50216a3d38de1ddd8694c",
 "immutable live capture commit exact pin")
check(market.matchedHistoricalGameKeys,189,"real source exact historical game key roster")
check(market.marketEdition,"2026-11-15","real publisher edition")
check(receipt.fourPageReadObserved,true,"true 4-page feed validated off-device")
check(market.crosswalkRowsSha256,receipt.crosswalkRowsSha256,
 "native original price rows fingerprint equals reviewed source receipt")
local engine=make()
local actual,err=engine:open()
check(type(actual),"table","genuine C9 source JSON admitted under synthetic fresh time")
check(err,nil,"current-source gate no error")
check(actual.status,"PUBLIC_SOURCE_RESEARCH_ONLY_READY",
 "C9 original native research source opened without trading authority")
check(actual.sourceRetrievedEpoch,epoch,
 "source timestamp is read from the captured file, not restamped")
check(actual.market.marketEdition,"2026-11-15","actual downloaded market file is preserved")
check(actual.market.crosswalkRowsSha256,
 "6540923609ddd6344306bb248861eddba7dd46cd00ba016f446eda3327f152ac",
 "actual original 189 rows digest matches CI publication")
check(actual.authorizesTrade,false,"C9 source gate cannot offer/accept")
check(actual.mayUseForLiveOffer,false,"publisher data is NOT server trade authority")
check(actual.livePublisherAuthenticated,false,"unsigned market site not first-party attested")
local target
for _,r in ipairs(actual.market.items) do
 if r.rawGameKeyCandidate=="Gingerscope" then target=r end
end
check(target~=nil,true,"exact genuine Gingerscope raw key observed")
check(target.outgoingGingerscopeProtected,true,"never outbound Gingerscope")
check(target.mm2Listed,16000,"Nov15 public snapshot value, no future price guarantee")
clock=epoch+21600
check(engine:open().status,"PUBLIC_SOURCE_RESEARCH_ONLY_READY",
 "C9 research source still valid at exact six-hour limit")
clock=epoch+21601
local stale,errStale=engine:open()
check(stale,nil,"C9 price expires one second after six hours")
check(errStale.reason,"C9_REAL_PUBLIC_SOURCE_EXPIRED_OR_CLOCK_CHANGED",
 "C9 no silent restamp after expiry")
clock=epoch-1
local future,errFuture=engine:open()
check(future,nil,"C9 future advertised source blocked")
check(errFuture.reason,"C9_REAL_PUBLIC_SOURCE_EXPIRED_OR_CLOCK_CHANGED",
 "C9 client clock older than original source must not be trusted")
clock=epoch+30
lease=false
local unbound,unboundReason=engine:open()
check(unbound,nil,"C9 no source without P3/P4 original live lease")
check(unboundReason.reason,"C9_ORIGINAL_PROTECTED_LEASE_NOT_ACTIVE",
 "C9 original P3 protected lease is prerequisite for market read")
lease=true
local broken=clone(receipt);broken.authorizesAccept=true
right=serde.encode("json",broken)
local forged,bad=engine:open()
check(forged,nil,"C9 forged Accept claim in public receipt never used")
check(bad.reason,"C9_RESEARCH_CROSSWALK_ADMISSION_MISMATCH",
 "C9 no source publisher can authorize Accept")
right=receiptTxt
local wrong=clone(market);wrong.items[1].rawGameKeyCandidate="Gingerscope"
left=serde.encode("json",wrong)
local duplicate,whyDup=engine:open()
check(duplicate,nil,"C9 original key duplication must block")
check(whyDup.reason,"C9_MARKET_GAME_KEY_SET_INVALID",
 "C9 duplicate false name cannot rewrite original 189 keys")
left=marketTxt
local mismatch=clone(receipt);mismatch.crosswalkRowsSha256=string.rep("0",64)
right=serde.encode("json",mismatch)
local notSame,whyNotSame=engine:open()
check(notSame,nil,"C9 mismatched source fingerprints never matched")
check(whyNotSame.reason,"C9_RESEARCH_CROSSWALK_ADMISSION_MISMATCH",
 "C9 original 189 rows must match reviewed CI receipt")
right=receiptTxt
local stolen=clone(market)
for _,r in ipairs(stolen.items) do
 if r.rawGameKeyCandidate=="Gingerscope" then
  r.outgoingGingerscopeProtected=false
 end
end
left=serde.encode("json",stolen)
local steal,reasonSteal=engine:open()
check(steal,nil,"C9 original target cannot be marked outbound")
check(reasonSteal.reason,"C9_GINGERSCOPE_SOURCE_OR_PROTECTION_INVALID",
 "C9 target loss prevented even in research")
left=marketTxt
local revoking=make({afterFirstFetch=function()lease=false end})
local gone,reasonGone=revoking:open()
check(gone,nil,"C9 original lease revoked during data fetch")
check(reasonGone.reason,"C9_PROTECTED_LEASE_OR_SOURCE_CHANGED_DURING_FETCH",
 "C9 cannot reuse source after session loss")
lease=true
local omitReceipt=clone(receipt)
omitReceipt.sourcePublisherSignatureVerified=true
right=serde.encode("json",omitReceipt)
local bogus,bogusReason=engine:open()
check(bogus,nil,"C9 fake original publisher signature rejected")
check(bogusReason.reason,"C9_RESEARCH_CROSSWALK_ADMISSION_MISMATCH",
 "C9 first-party verification cannot be fabricated")
right=receiptTxt
print("SYSTEM2_C9_ACTUAL_IMMUTABLE_FRESH_PUBLIC_SOURCE_ASSERTIONS_PASSED "..tostring(tests))
