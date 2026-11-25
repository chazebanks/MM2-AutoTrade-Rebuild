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
 'local runner=fs.readFile("pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_BUTTON_NATIVE.lua")',
 "C9 must truly run new protected host research variant")
swap('   stage119LastOfferReadOnly=true,',
 '   stage119LastOfferReadOnly=true,c9ResearchOnly=true,c9SupremeOnlyReadOnly=true,operatorConfirmedReadOnlyInventoryRpc=true,',
 "C9 dedicated operator research opt-in remains mandatory")
swap('eq(#x.readSources,12,"exact 12 frozen modules including protected P3 and Stage118")',
 'eq(#x.readSources,13,"exact original P3/P4 source plus pinned C9 adapter")',
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
 return {items={{id="Gingerscope",cat="Weapons",name="Gingerscope",
  qty=1,page="ancient",type="Gun"}},seen={"Gingerscopex1"},
  rawOwned=1,unmapped=0,badQty=0,unpriced=1,total=999999999,
  fingerprint="Gingerscopex1"},nil
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
 "C9 synthetic timestamp is taken from the original November17 archive")
swap('setTime=function(t)clock=t end,now=function()return clock end,',
 'setTime=function(t)clock=t end,now=function()return clock end,\n  setMarketTime=function(v)marketNow=v end,sourceEpoch=startEpoch,',
 "C9 test has distinct UTC market clock independent of P3 GUI clock")
swap('   if url:find("native_c9_original_p3_protected_host_adapter.lua",1,true) then',
 [[   if url:find("/pdiddler/system2/supreme_only_189_research_catalog_2026_11_17_refresh.json",1,true) then
     return fs.readFile("pdiddler/system2/supreme_only_189_research_catalog_2026_11_17_refresh.json")
   elseif url:find("/pdiddler/system2/native_",1,true) then
     local filename=url:match("/system2/(native_[^/]+%.lua)$")
     assert(filename,"C9 original immutable native module path invalid")
     -- Historical test must load the exact archived module version, not HEAD.
     if filename=="native_supreme_only_bilateral_research_nov17.lua" or
        filename=="native_supreme_only_protected_c3p4_adapter_nov17.lua" then
       assert(url=="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/3d23aeb45efe6dc87840b0f4f8a89198d0d8b4e3/pdiddler/system2/"..filename,
         "historical fixture immutable module pin mismatch")
       return fs.readFile("pdiddler/ci/fixtures/supreme_nov17_original/"..filename..".fixture")
     end
     return fs.readFile("pdiddler/system2/"..filename)
   elseif url:find("native_c9_original_p3_protected_host_adapter.lua",1,true) then]],
 "C9 source-pinned actual nine modules and two real public JSON files")

local insert=[[
-- Real ORIGINAL Stage119/mock P3 and protected P4 host entrypoint tested.
do
 local x=fakeEnv()
 local runtime=x.run()
 eq(type(runtime),"table","protected Supreme host fork compiled")
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "original P3 lease absent before manual ARM")
 local q={kind="HYPOTHETICAL_RESEARCH_ONLY",valueSource="SUPREME_ONLY",
   give={{id="Gingerscope",quantity=1}},
   receive={{id="Harvester",quantity=1}}}
 eq(runtime.c9SupremeOnlyReadOnlyPreview({q}).status,"BLOCKED",
    "no scanner read or source without original P3 arm")
 eq(#x.offers,0,"C9 start never offers")
 eq(x.E.__P3.armCalls,0,"C9 start never automatically arms trade request")
 x.armButton().Activated:Fire()
 eq(x.E.__P3.armCalls,1,"one original P3 request only after user GUI ARM")
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "no protected trade GUI until partner responds")
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.screen.Enabled=true
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
    "original bound partner trade visible")
 x.setTime(100.22)
 x.E.__WATCH.tick()
 eq(runtime.c9ReadOnlyLeaseStatus().status,"ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND",
    "original in-host lease genuinely bound")
 eq(x.named("SupremePreview").Visible,true,
    "preview replaces ARM in original non-overlapping safe panel only after protected lease")
 eq(x.named("ArmP3").Visible,false,
    "manual ARM hidden after original P3 already armed")
 eq(x.named("StopP3").Visible,true,
    "STOP remains available during protected preview")
 x.named("SupremePreview").Activated:Fire()
 eq(#x.offers,0,"preview button cannot offer item")
 eq(x.E.__P3.armCalls,1,"preview never triggers another P3 trade request")
 eq(x.named("WhatToDo").Text:find("SUPREME",1,true)~=nil,true,
    "preview status shown inside original safe GUI without Delta Execute")

 local before=runtime.c9SupremeOnlyReadOnlyPreview({q})
 eq(before.valueSource,"SUPREME_ONLY","no old market list source")
 eq(before.status,"BLOCKED","opponent Harvester not in original empty offer")
 eq(before.reason,"OPPONENT_ITEM_NOT_EXACTLY_PRESENT_IN_BOUND_GUI",
    "real original C3/P4 bridge rejects invented opponent source stock")
 eq(before.authorizesOffer,false,"no physical offer authorized")
 eq(before.authorizesAccept,false,"no final Accept authorized")
 eq(#x.offers,0,"no actual item placements on research preview")
 local serialized=serde.encode("json",before)
 for _,s in ipairs({"TrustedAlt","FAKE_JOB_P3",tostring(x.E.__P3.session)}) do
  eq(serialized:find(s,1,true),nil,"do not return original private identities")
 end
 x.setMarketTime(x.sourceEpoch+21601)
 local expired=runtime.c9SupremeOnlyReadOnlyPreview({q})
 eq(expired.status,"BLOCKED","genuinely expired Supreme data blocks")
 eq(expired.reason,"SUPREME_ONLY_SOURCE_EXPIRED_OR_UNVERIFIED",
    "only Supreme expiry, no backup list")
 eq(#x.offers,0,"expired source does not mutate player inventory")
 local username=x.their:FindFirstChild("Username")
 username.Text="WrongClientPartner"
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "original lease revokes on GUI nickname mismatch")
 username.Text="TrustedAlt"
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "revoked original lease cannot reactivate")
 x.stopButton().Activated:Fire()
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "STOP revokes protected private lease")
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.c9SupremeOnlyReadOnly=false
 eq(x.run(),nil,"missing Supreme-only operator flag blocks original host")
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.operatorConfirmedReadOnlyInventoryRpc=false
 eq(x.run(),nil,"no original GetProfileData read without explicit consent")
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
print("C9_SUPREME_ONLY_ORIGINAL_STAGE119_HOST_NATIVE_PASS")
