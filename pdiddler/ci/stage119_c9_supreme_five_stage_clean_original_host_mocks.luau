-- Exercise original Stage119 P3/P4 mocked-hardware harness on NEW C9 host
-- research fork. Do NOT edit or weaken frozen original Stage119 source/harness.
-- Fixture source substitutions affect tests ONLY; production fork is read verbatim.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local old=fs.readFile("pdiddler/ci/stage119_p3_bound_original_mocks.luau")
local function swap(before,after,why)
 assert(old:find(before,1,true),why.." original pinned harness anchor missing")
 old=old:gsub(before:gsub("([^%w])","%%%1"),function()return after end,1)
end
swap('local runner=fs.readFile("pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua")',
 'local runner=fs.readFile("pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua")',
 "C9 must truly run new protected host research variant")
swap('   stage119LastOfferReadOnly=true,',
 '   stage119LastOfferReadOnly=true,c9ResearchOnly=true,c9SupremeOnlyReadOnly=true,c9FiveScenarioManualTest=true,operatorApprovedManualItemChanges=true,noAutomaticWeaponOffers=true,neverFinalAcceptDuringTest=true,operatorConfirmedReadOnlyInventoryRpc=true,',
 "C9 dedicated operator research opt-in remains mandatory")
swap('eq(#x.readSources,12,"exact 12 frozen modules including protected P3 and Stage118")',
 'eq(#x.readSources,14,"exact original P3/P4 sources plus one GUI presenter")',
 "C9 original boot must load exactly one additional pinned module")
swap('   if url:find("stage100_screen_prompt_overlay.lua",1,true) then',
 [[   if url:find("native_c9_original_p3_protected_host_adapter.lua",1,true) then
     return fs.readFile("pdiddler/system2/native_c9_original_p3_protected_host_adapter.lua")
   elseif url:find("stage100_screen_prompt_overlay.lua",1,true) then]],
 "C9 adapter immutable remote supplied from actual tested module")
-- Test-only original Stage119 scanner API gains its genuine read-only
-- OWN profile shape. Native actual scanner retains the real GetProfileData
-- read RPC; here there is NO network call or item transfer.
swap('function api.hasPendingWork()return false end',
 [[function api.hasPendingWork()return false end
function api.getOwnInventory()
 return {items={
   {id="Gingerscope",cat="Weapons",name="Gingerscope",
    qty=1,page="ancient",type="Gun"},
   {id="Scythe",cat="Weapons",name="Batwing",
    qty=1,page="ancient",type="Knife"}
  },seen={"Gingerscopex1","Scythex1"},
  rawOwned=2,unmapped=0,badQty=0,unpriced=1,total=999999999,
  fingerprint="Gingerscopex1|Scythex1"},nil
end]],
 "C9 synthetic original scanner has exact one owned raw key and no remote")

swap('HttpService={JSONEncode=function(_,r)return serde.encode("json",r)end}',
 [[HttpService={JSONEncode=function(_,r)return serde.encode("json",r)end,
  JSONDecode=function(_,s)return serde.decode("json",s)end}]],
 "C9 original test HttpService supports read-only public JSON decode")
swap('local env={game=game,getgenv=function()return E end,',
 [[local crosswalk=serde.decode("json",fs.readFile(
 "pdiddler/system2/supreme_only_189_research_catalog_2026_11_17_refresh.json"))
local yr,mo,da,hr,mi,se=crosswalk.sourceCapturedUtc:match(
 "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
local startEpoch=os.time({year=tonumber(yr),month=tonumber(mo),
 day=tonumber(da),hour=tonumber(hr),min=tonumber(mi),sec=tonumber(se),
 isdst=false})
local marketNow=startEpoch+20
local dt={
 fromIsoDate=function(s)
  if s==crosswalk.sourceCapturedUtc then
   return {UnixTimestamp=startEpoch} end
 end,
 now=function()return {UnixTimestamp=marketNow}end,
}
local env={game=game,DateTime=dt,getgenv=function()return E end,]],
 "C9 synthetic exact timestamp is taken from genuine November15 file")
swap('setTime=function(t)clock=t end,now=function()return clock end,',
 'setTime=function(t)clock=t end,now=function()return clock end,\n  setMarketTime=function(v)marketNow=v end,sourceEpoch=startEpoch,',
 "C9 test has distinct UTC market clock independent of P3 GUI clock")
swap('   if url:find("native_c9_original_p3_protected_host_adapter.lua",1,true) then',
 [[   if url:find("/pdiddler/system2/supreme_only_189_research_catalog_2026_11_17_refresh.json",1,true) then
     return fs.readFile("pdiddler/system2/supreme_only_189_research_catalog_2026_11_17_refresh.json")
   elseif url:find("/pdiddler/system2/native_",1,true) then
     local filename=url:match("/system2/(native_[^/]+%.lua)$")
     assert(filename,"C9 original immutable native module path invalid")
     return fs.readFile("pdiddler/system2/"..filename)
   elseif url:find("native_c9_original_p3_protected_host_adapter.lua",1,true) then]],
 "C9 source-pinned actual nine modules and two real public JSON files")

local insert=[[
-- Actual original frozen P3/P4 host + manual GUI item mutations, no game RPC.
do
 local x=fakeEnv()
 local runtime=x.run()
 eq(type(runtime),"table","real original protected host compiled")
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
   "no P3 lease before ARM")
 eq(runtime.status().fiveScenarioCompleted,0,"five-scenario result starts at zero")
 eq(x.named("ArmP3").Position.X.Offset,12,
    "GUI factory preserves original ARM x=12")
 eq(x.named("SupremePreview").Position.X.Offset,12,
    "GUI factory preserves preview x=12")
 eq(x.named("StopP3").Position.X.Offset,164,
    "GUI factory preserves STOP x=164")
 eq(x.named("Safety").Text,"MANUAL ITEM TEST | NEVER FINAL ACCEPT",
    "GUI factory preserves manual-only warning")

 eq(#x.offers,0,"no script offers at startup")
 eq(x.E.__P3.armCalls,0,"no automatic trade request")
 x.armButton().Activated:Fire()
 eq(x.E.__P3.armCalls,1,"exactly one manually armed request to consenting ALT")
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.screen.Enabled=true
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
    "protected original bound P3/P4 observed")
 x.setTime(100.22);x.E.__WATCH.tick()
 eq(runtime.c9ReadOnlyLeaseStatus().status,
    "ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND",
    "original private protected lease live")
 local button=x.named("SupremePreview")
 eq(button.Visible,true,"preview shown after real guarded lease")
 eq(x.named("StopP3").Visible,true,"STOP/COPY remains available")
 eq(x.named("ArmP3").Visible,false,"ARM hidden after request")
 button.Activated:Fire()
 eq(runtime.status().fiveScenarioCompleted,2,
    "single empty click records startup and distinct both-empty scenario")
 eq(runtime.status().fiveScenarioResults[1].code,"S1_PASS",
    "separate startup outcome")
 eq(runtime.status().fiveScenarioResults[2].code,"S2_PASS",
    "empty case expected BLOCK, recorded PASS")
 eq(#x.offers,0,"empty case never offers")
 -- Synthetic manual MAIN-side add. This is a mock UI mutation ONLY,
 -- not a script-issued OfferItem or live account trade.
 local ourItem=x.addWeapon("MAIN","Batwing","",false)
 ourItem.attributes.ItemId="Scythe"
 x.setTime(100.33);x.E.__WATCH.tick()
 button.Activated:Fire()
 eq(runtime.status().fiveScenarioCompleted,3,
    "one-sided manual change gives distinct stage3 pass")
 eq(runtime.status().fiveScenarioResults[3].code,"S3_PASS",
    "single-side block confirmed")
 -- Manually add a listed Chroma on partner side. Preserve original item
 -- raw game key distinct from Supreme site official id.
 local theirItem=x.addWeapon("ALT","Chroma Immortal","",true)
 theirItem.attributes.ItemId="ImmortalChroma"
 x.setTime(100.51);x.E.__WATCH.tick()
 -- Deliberately erase raw id to show Stage4 cannot pass from displayed name.
 theirItem.attributes.ItemId=nil
 button.Activated:Fire()
 eq(runtime.status().fiveScenarioCompleted,3,
    "no Stage4 from item label when exact GUI raw ItemId missing")
 theirItem.attributes.ItemId="ImmortalChroma"
 x.setTime(100.62);x.E.__WATCH.tick()
 button.Activated:Fire()
 eq(runtime.status().fiveScenarioCompleted,4,
    "Stage4 actual two-side Supreme-only listed comparison passed")
 eq(runtime.status().fiveScenarioResults[4].code,"S4_PASS",
    "two-sided stage receipt separate")
 eq(#x.offers,0,"no offer automation after manual items")
 eq(x.E.__P3.armCalls,1,"still only initial ARM trade request")
 -- Stage5 requires a *different* physical raw weapon/quantity state.
 x.setTime(100.72);x.E.__WATCH.tick()
 button.Activated:Fire()
 eq(runtime.status().fiveScenarioCompleted,4,
    "same offer re-preview cannot pass dynamic-change scenario")
 local amount=theirItem:FindFirstChild("Container"):FindFirstChild("Amount")
 amount.Text="x2"
 x.setTime(100.83);x.E.__WATCH.tick()
 button.Activated:Fire()
 eq(runtime.status().fiveScenarioCompleted,5,
    "Stage5 detects manually changed stack and verifies fresh re-quote")
 eq(runtime.status().fiveScenarioResults[5].code,"S5_PASS",
    "all five distinct scenarios verified")
 eq(runtime.status().authorizesAccept,false,"test does not allow final Accept")
 eq(runtime.status().authorizesOffer,false,"test does not allow automated OfferItem")
 eq(#x.offers,0,"still no script-issued real item operations")
 eq(x.named("StopP3").Visible,true,"manual STOP persists")
 x.stopButton().Activated:Fire()
 local record=serde.decode("json",x.copied[#x.copied])
 eq(record.fiveScenarioCompleted,5,"five stage passes survive STOP/COPY")
 eq(record.fiveScenarioResults[5].code,"S5_PASS","end result sanitized")
 eq(record.actualOffers,0,"no actual offers")
 eq(record.actualAccepts,0,"no final accepts")
 eq(record.actualDeclines,0,"no automation decline")
 for _,secret in ipairs({"TrustedAlt","FAKE_JOB_P3",
                          "Scythe","ImmortalChroma","Gingerscope"}) do
  eq(x.copied[#x.copied]:find(secret,1,true),nil,
     "STOP/COPY never includes weapon/account identity")
 end
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.c9FiveScenarioManualTest=false
 eq(x.run(),nil,"five-scenario host requires distinct multi-test flag")
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.neverFinalAcceptDuringTest=false
 eq(x.run(),nil,"final Accept remains disabled even with manual item changes")
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.noAutomaticWeaponOffers=false
 eq(x.run(),nil,"scripted weapon mutation always forbidden in manual tests")
end
]]
local key=table.concat({"do"," local x=fakeEnv()"," start(x)"," local r=conclude(x,13)"},"\n")
assert(old:find(key,1,true),"C9 injected regression anchor not found")
-- Existing Stage119's five-step ALT add/remove tests run UNCHANGED
-- in the preceding original-frozen suite. The C9 fork deliberately does
-- not run the gift lane; cut at its first test AFTER loading the same
-- original fixture constructors and use only new C9 observations.
local at=old:find(key,1,true)
assert(at,"C9 original harness test-lane boundary missing")
old=old:sub(1,at-1)..insert.."\n"
luau.load(old)()
print("GINGERSCOPE_SUPREME_FIVE_SCENARIO_ORIGINAL_STAGE119_HOST_NATIVE_PASS")
