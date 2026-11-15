-- Real ORIGINAL C3/P4 -> C4 -> C9 preflight combined with the
-- GitHub-Actions-admitted REAL 189 item public snapshot, client-only.
-- Host adapter stand-in uses the C3 original bound lease; the actual
-- P3 coordinator/host adapter is separately tested by original Stage119.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local M={}
function M.run(d)
 local base="pdiddler/system2/"
 local eq,ok=d.eq,d.ok
 local marketGate=luau.load(fs.readFile(base..
  "native_c9_immutable_market_research_gate.lua"))()
 local composerModule=luau.load(fs.readFile(base..
  "native_c9_original_host_market_composer.lua"))()
 local preflightFactory=luau.load(fs.readFile(base..
  "native_c9_device_readonly_preflight.lua"))()
 local x=fs.readFile(base.."c9_research_public_189_crosswalk.json")
 local y=fs.readFile(base.."c9_research_public_source_admission.json")
 local m=serde.decode("json",x)
 local token=m.sourceRetrievedUtc
 local yyyy,mm,dd,hh,mi,ss=token:match(
  "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
 ok(yyyy~=nil,"C9 actual published crosswalk UTC")
 local epoch=os.time({year=tonumber(yyyy),month=tonumber(mm),
  day=tonumber(dd),hour=tonumber(hh),min=tonumber(mi),sec=tonumber(ss),
  isdst=false})
 local at=epoch+20
 local bound=true
 local countFetches=0
 local function boundSession()
  return bound and d.isBoundSession()
 end
 local host={
  scope=d.scope,readOnly=true,clientOnly=true,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  isBoundSession=boundSession,
  status=function()
   return {schema="gingerscope-c9-original-p3-host-lease-v1",
    status=boundSession() and "ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND"
      or "BLOCKED",
    clientOnly=true,readOnly=true,authorizesOffer=false,
    authorizesTrade=false,authorizesAccept=false,
    serverCompletionProven=false}
  end,
 }
 local function sourceFetch(url)
  countFetches+=1
  if url==marketGate.SOURCE_URL then return x end
  if url==marketGate.RECEIPT_URL then return y end
  error("C9 unexpected URL: "..tostring(url))
 end
 local cfg={
  hostHandle=host,consentedToReadOnlyInventoryRpc=true,
  marketGate=marketGate,devicePreflight=preflightFactory,
  marketCore=d.core,captureAdapter=d.capture,
  marketBridgeModule=d.glue,
  bilateralCore=d.nativeBilateral,
  bilateralBridgeModule=d.nativeBilateralBridge,
  growthFirstModule=d.c9Source,
  scannerApi=d.growthScanner,sync=d.sync,
  nameResolver=d.resolver,players=d.players,game=d.game,
  sourceHttpGet=sourceFetch,
  jsonDecode=function(s)return serde.decode("json",s)end,
  utcNow=function()return at end,monoNow=d.now,
  isoToEpoch=function(s)
   if s==token then return epoch end
   error("C9 unverified source timestamp")
  end
 }
 local badCfg={}
 for k,v in pairs(cfg) do badCfg[k]=v end
 badCfg.consentedToReadOnlyInventoryRpc=false
 local refused,why=composerModule.new(badCfg)
 eq(refused,nil,"C9 host cannot invoke inventory READ RPC without explicit consent")
 eq(why,"C9_REVIEWED_ORIGINAL_HOST_COMPONENTS_OR_OPERATOR_CONSENT_MISSING",
  "C9 private scanner must be read with separately authorized consent")
 local runner,reason=composerModule.new(cfg)
 ok(runner~=nil,"C9 genuine protected host+fresh real public source+original modules composed")
 eq(reason,nil,"C9 composite prepared no error")
 local before=countFetches
 bound=false
 local noLease=runner:run()
 eq(noLease.reason,"C9_ORIGINAL_PROTECTED_HOST_LEASE_LOST",
  "C9 refuses BEFORE fetching external source if client lease inactive")
 eq(countFetches,before,"C9 no external requests before bound client session")
 bound=true
 local sample=runner:run()
 eq(sample.status,"C9_PROTECTED_READONLY_PREFLIGHT_OBSERVED",
  "C9 real original C3/P4 GUI scanner admitted actual 189 row source")
 eq(sample.innerStatus,"C9_LOCAL_READONLY_INVENTORY_AND_GUI_OBSERVED",
  "C9 exact actual original native GUI/census, research only")
 eq(sample.marketEdition,"2026-11-15",
  "C9 actual public publisher edition, not user-invented value")
 eq(sample.sourceAgeSeconds,20,
  "C9 source age corresponds to actual fetched source timestamp")
 eq(sample.authorizesTrade,false,"C9 no OfferItem sender")
 eq(sample.authorizesAccept,false,"C9 no final Accept")
 eq(sample.mayUseForStrategyLearning,false,"C9 no training from client-only source")
 eq(sample.serverSettlementProven,false,
  "C9 original GUI is not server settlement")
 eq(countFetches,before+2,"C9 two immutable source files fetched exactly once")
 local strategy=runner:run(d.c9RealOptions)
 eq(strategy.status,"C9_PROTECTED_READONLY_PREFLIGHT_OBSERVED",
  "C9 original C3+C4+growth-first scored actual public historical-key source")
 eq(strategy.innerStatus,"C9_LOCAL_READONLY_STRATEGY_RESEARCH_OBSERVED",
  "C9 actual 189 row source supports long-term quality preview")
 eq(strategy.reviewedOptionCount,2,
  "C9 evaluates TWO alternative routes, never a script offer")
 eq(strategy.authorizesAccept,false,
  "C9 growth-first risk toleration still cannot accept trade")
 local out=serde.encode("json",strategy)
 for _,secret in ipairs({d.job,d.lease,tostring(d.localPlayer.UserId),
  tostring(d.opponent.UserId),"MainTestUser_Alpha","Harvester",
  "Frostsaber","SnowDagger","Icepiercer"}) do
  eq(out:find(secret,1,true),nil,
   "C9 composer's public receipt must not export raw user/item details")
 end
 at=epoch+21601
 local stale=runner:run(d.c9RealOptions)
 eq(stale.status,"BLOCKED","C9 real market 6h age invalidates native planner")
 eq(stale.reason,"C9_REAL_PUBLIC_SOURCE_EXPIRED_OR_CLOCK_CHANGED",
  "C9 no history restamping or expired snapshot reuse")
 at=epoch+20
 bound=false
 eq(runner:run().reason,"C9_ORIGINAL_PROTECTED_HOST_LEASE_LOST",
  "C9 P3/P4 lease invalidation stops new source/rpc")
 bound=true
 print("SYSTEM2_C9_REAL_MARKET_ORIGINAL_HOST_COMPOSITION_PASSED")
end
return M
