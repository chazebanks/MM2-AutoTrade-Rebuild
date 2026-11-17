-- Test the C9 consent gate/immutable SHA-pinned research loader.
-- Original Stage119 native runner/host tests are a SEPARATE test suite.
-- This loader test uses NO player network, arm, trade, offer or Accept.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_START.lua")
local pinned=fs.readFile("pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua")
local count=0
local function eq(actual,expected,msg)
 count+=1
 assert(actual==expected,tostring(msg)..": "..tostring(actual).." ~= "..tostring(expected))
end
local function fixture(opts)
 opts=opts or {}
 local e={}
 local plan={
  explicitOperatorWantsC9Research=true,
  understandsArmSendsP3TradeRequest=true,
  consentVerifiedForNamedAlt=true,
  operatorApprovedManualItemChanges=true,
  manualWeaponChangesSupervisedOnly=true,
  noAutomaticWeaponOffers=true,
  neverFinalAcceptDuringTest=true,
  operatorConfirmedReadOnlyInventoryRpc=true,
  understandsCurrentSourceMayExpire=true,
  finalAcceptMustRemainManual=true,
  supremeOnlyResearchRequested=true,
  explicitOwnInventoryReadRpcConsent=true,
  automaticP3ArmForbidden=true,
  targetName="TestAlt",
 }
 for k,v in pairs(plan) do e.GINGERSCOPE_C9_SUPREME_FIVE_TEST_PLAN=
  e.GINGERSCOPE_C9_SUPREME_FIVE_TEST_PLAN or {}
  e.GINGERSCOPE_C9_SUPREME_FIVE_TEST_PLAN[k]=v
 end
 local players={}
 local me={Name="FakeMain",UserId=1352,Parent=players}
 local alt={Name="TestAlt",UserId=2325,Parent=players}
 players.LocalPlayer=me
 function players:FindFirstChild(n)
  if alt.Parent==players and n==alt.Name then return alt end
 end
 function players:GetPlayerByUserId(n)
  if alt.Parent==players and n==alt.UserId then return alt end
 end
 local calls={http=0,compiler=0,runtime=0,warnings={},stop=0,arm=0}
 local game={PlaceId=142823291,JobId="C9_PREPARE_TEST_JOB_001"}
 function game:GetService(n)
  if n=="Players" then return players end
  error("unexpected original game service "..tostring(n))
 end
 function game:HttpGet(url)
  calls.http+=1
  local good="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
   "32ee770234ff6c3a38d73b183ae4c41cbc2a3472/pdiddler/"..
   "supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua"
  eq(url,good,"C9 only exact GitHub immutable source URI")
  if opts.badNetwork then error("offline fake CDN") end
  if opts.badSource then return "NOT_A_NATIVE_RUNNER" end
  return pinned
 end
 local runtime={stop=function()
    calls.stop+=1
    return true
   end,
   status=function()return{status="P3_SUPERVISOR_PREPARED_NOT_ARMED"}end,
   isArmed=function()return false end,
   c9ReadOnlyLeaseStatus=function()return{status="BLOCKED"}end,
   c9SupremeOnlyReadOnlyPreview=function()return{status="BLOCKED"}end}
 local DateTime={
  now=function()
   return {UnixTimestamp=opts.expiredSource and 1794946012
       or opts.futureSource and 1794924410
       or 1794924441}
  end
 }
 if opts.noDateTime then DateTime=nil end
 local env={game=game,DateTime=DateTime,getgenv=function()return e end,
  warn=function(msg)calls.warnings[#calls.warnings+1]=msg end,
  loadstring=function(actual)
   calls.compiler+=1
   eq(actual,pinned,"C9 only exact immutable native SHA source compiled")
   return function()
    calls.runtime+=1
    if opts.badRuntime then return {arm=function()end} end
    if opts.directArmDanger then runtime.arm=function()
      calls.arm+=1
    end end
    return runtime
   end
  end}
 local run=function()
  return luau.load(source,{environment=env,injectGlobals=true})()
 end
 return {run=run,e=e,plan=e.GINGERSCOPE_C9_SUPREME_FIVE_TEST_PLAN,
  players=players,me=me,alt=alt,game=game,calls=calls,runtime=runtime}
end
do
 local a=fixture({expiredSource=true})
 eq(a.run(),nil,"expired Supreme price capture must reject BEFORE manual trade ARM")
 eq(a.calls.http,0,"expired source must prevent even frozen host fetch")
 eq(a.calls.arm,0,"expired source does not arm P3")
end
do
 local a=fixture({futureSource=true})
 eq(a.run(),nil,"source from the future must fail before P3")
 eq(a.calls.http,0,"no source when client UTC clock is before capture")
end
do
 local a=fixture({noDateTime=true})
 eq(a.run(),nil,"no reliable Roblox UTC clock blocks startup")
 eq(a.calls.http,0,"clock API absent must prevent host startup")
end
do
 local a=fixture()
 a.e.GINGERSCOPE_C9_SUPREME_FIVE_TEST_PLAN=nil
 eq(a.run(),nil,"No active operator plan must fail closed")
 eq(a.calls.http,0,"No public source fetch without an explicit operator plan")
 eq(a.calls.compiler,0,"No code compile without approval")
 eq(a.calls.arm,0,"No automatic P3 request")
end
do
 local a=fixture()
 a.plan.operatorConfirmedReadOnlyInventoryRpc=false
 eq(a.run(),nil,"C9 inventory READ RPC needs explicit independent operator authorization")
 eq(a.calls.http,0,"Unconsented C9 market data does not start")
end
do
 local a=fixture()
 a.plan.understandsCurrentSourceMayExpire=false
 eq(a.run(),nil,"C9 publicly retrieved source may be stale six hours later")
 eq(a.calls.http,0,"C9 no stale-source plan cannot start")
end
do
 local a=fixture()
 a.plan.supremeOnlyResearchRequested=false
 eq(a.run(),nil,"user must opt in to strict one-publisher Supreme source")
 eq(a.calls.http,0,"no source fetch without one-publisher consent")
end
do
 local a=fixture()
 a.plan.explicitOwnInventoryReadRpcConsent=false
 eq(a.run(),nil,"read-only inventory RPC needs explicit independent consent")
 eq(a.calls.http,0,"no startup on missing separate scanner consent")
end
do
 local a=fixture()
 a.plan.operatorApprovedManualItemChanges=false
 eq(a.run(),nil,"manual changes require explicit operator authorization")
 eq(a.calls.http,0,"no network on unapproved manual tests")
end
do
 local a=fixture()
 a.plan.manualWeaponChangesSupervisedOnly=false
 eq(a.run(),nil,"reject unspecified who modifies inventory")
 eq(a.calls.http,0,"no network on ambiguous manual test")
end
do
 local a=fixture()
 a.plan.noAutomaticWeaponOffers=false
 eq(a.run(),nil,"reject accidental automatic offer authorization")
 eq(a.calls.http,0,"no network on auto offers")
end
do
 local a=fixture()
 a.plan.neverFinalAcceptDuringTest=false
 eq(a.run(),nil,"test must prohibit final Accept regardless of old manual flag")
 eq(a.calls.http,0,"no network when final Accept not prohibited")
end
do
 local a=fixture()
 a.plan.noWeaponAddOrRemoveTests=true
 eq(a.run(),nil,"Old five gift lane must not be permitted")
 eq(a.calls.http,0,"Gift-lane request does not load C9 runner")
end
do
 local a=fixture()
 a.plan.understandsArmSendsP3TradeRequest=false
 eq(a.run(),nil,"Human must understand ARM sends a real P3 request")
 eq(a.calls.http,0,"No request-lane source loaded on missing acknowledgment")
end
do
 local a=fixture()
 a.plan.targetName="WrongAlt"
 eq(a.run(),nil,"Unknown consenting ALT is not accepted")
 eq(a.calls.http,0,"Unknown ALT cannot load source")
end
do
 local a=fixture()
 a.game.PlaceId=99999
 eq(a.run(),nil,"Wrong Roblox place blocked")
 eq(a.calls.http,0,"Non-MM2 never loads runner")
end
do
 local a=fixture()
 a.alt.Parent=nil
 eq(a.run(),nil,"Departed consenting ALT blocked")
 eq(a.calls.http,0,"No loading with missing player")
end
do
 local a=fixture()
 a.e.PDIDDLER_OUTGOING_SESSION=11
 eq(a.run(),nil,"Conflicting P3 owner/session blocked before network")
 eq(a.calls.http,0,"No duplicate controller load")
end
do
 local a=fixture({badNetwork=true})
 eq(a.run(),nil,"Unavailable pinned source must fail closed")
 eq(a.calls.compiler,0,"Network failure cannot compile fallback")
end
do
 local a=fixture({badSource=true})
 eq(a.run(),nil,"Invalid GitHub response must fail closed")
 eq(a.calls.compiler,0,"Wrong source never compiles")
end
do
 local a=fixture({badRuntime=true})
 eq(a.run(),nil,"Unreviewed public ARM runtime refused")
 eq(a.calls.compiler,1,"Bad result after one pinned compile")
 eq(a.e.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE,nil,
    "Failed loader clears protected P3 test startup config")
end
do
 local a=fixture({directArmDanger=true})
 eq(a.run(),nil,"Unexpected public arm method refused")
 eq(a.calls.stop,1,"Unsafe controller stopped on return validation")
 eq(a.calls.arm,0,"Loader never calls unexpected public P3 ARM")
end
do
 local a=fixture()
 local runtime=a.run()
 eq(type(runtime),"table","Only reviewed client-only status interface returned")
 eq(a.calls.http,1,"Exactly one immutable GitHub source fetch on approved init")
 eq(a.calls.compiler,1,"One pinned source compiled")
 eq(a.calls.runtime,1,"One source invocation")
 eq(a.calls.arm,0,"C9 never auto arms original P3 request")
 eq(runtime.arm,nil,"No external arm controller exported")
 eq(runtime.offer,nil,"No OfferItem controller exported")
 eq(runtime.accept,nil,"No final Accept exposed")
 eq(runtime.isArmed(),false,"Original P3 button not clicked after startup")
 eq(a.e.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.c9ResearchOnly,true,
    "Special C9 research-only mode set")
 eq(a.e.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.c9SupremeOnlyReadOnly,true,
    "C9 market method read only and manual invocation")
 eq(a.e.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.operatorConfirmedReadOnlyInventoryRpc,true,
    "C9 original profile GetProfileData READ consent explicit")
 eq(runtime.c9SupremeOnlyReadOnlyPreview().status,"BLOCKED",
    "C9 initial market preflight no protected P3/P4 lease, no network")
 eq(a.e.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.targetName,"TestAlt",
    "Existing consenting partner scoped exactly")
 eq(a.run(),nil,"Same-job second C9 startup refused")
 eq(a.calls.http,1,"Duplicate start cannot refetch")
end
print("STAGE119_C9_SUPREME_ONLY_BOOTSTRAP_ASSERTIONS_PASSED "..tostring(count))
