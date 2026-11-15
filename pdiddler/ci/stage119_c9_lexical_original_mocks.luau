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
 'local runner=fs.readFile("pdiddler/supervised/STAGE119_C9_READONLY_RESEARCH_NATIVE.lua")',
 "C9 must truly run new protected host research variant")
swap('   stage119LastOfferReadOnly=true,',
 '   stage119LastOfferReadOnly=true,c9ResearchOnly=true,',
 "C9 dedicated operator research opt-in remains mandatory")
swap('eq(#x.readSources,12,"exact 12 frozen modules including protected P3 and Stage118")',
 'eq(#x.readSources,13,"exact original P3/P4 source plus pinned C9 adapter")',
 "C9 original boot must load exactly one additional pinned module")
swap('   if url:find("stage100_screen_prompt_overlay.lua",1,true) then',
 [[   if url:find("native_c9_original_p3_protected_host_adapter.lua",1,true) then
     return fs.readFile("pdiddler/system2/native_c9_original_p3_protected_host_adapter.lua")
   elseif url:find("stage100_screen_prompt_overlay.lua",1,true) then]],
 "C9 adapter immutable remote supplied from actual tested module")
local insert=[[
-- C9 NEW experimental tests on original Stage119 code's lexical scope.
-- No alt item gifts; stop before first identity witness manually adds weapons.
do
 local x=fakeEnv()
 local runtime=x.run()
 eq(type(runtime),"table","C9 true original supervised Stage119 research fork loaded")
 local before=runtime.c9ReadOnlyLeaseStatus()
 eq(before.status,"BLOCKED","C9 no client lease BEFORE real P3 ARM")
 eq(#x.offers,0,"C9 unarmed cannot offer a weapon")
 eq(x.E.__P3.armCalls,0,"C9 no synthetic P3 arm")
 x.armButton().Activated:Fire()
 eq(x.E.__P3.armCalls,1,"C9 original P3 ARM only explicit human UI event")
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "C9 original host not bound until real processed P3 trade")
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.screen.Enabled=true
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
    "C9 first original P3→P4 actual protected GUI read")
 eq(x.named("CurrentStep").Text,"C9 READ-ONLY | 2/2 P3/P4 OBSERVED",
    "C9 operator sees read-only research instruction, not old five-gift UI")
 eq(x.named("WhatToDo").Text:find("NO weapon add/remove",1,true)~=nil,
    true,"C9 original host must explicitly prohibit legacy ALT gift lane")
 x.setTime(100.22)
 x.E.__WATCH.tick()
 local c9=runtime.c9ReadOnlyLeaseStatus()
 eq(c9.status,"ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND",
    "C9 in real Stage119 lexical host consumes the ORIGINAL revocable P3/P4 facade")
 eq(c9.authorizesOffer,false,"C9 no OfferItem exposed from original host")
 eq(c9.authorizesAccept,false,"C9 final Accept still unavailable")
 eq(c9.serverCompletionProven,false,"C9 P4 GUI never proves settlement")
 eq(c9.mayUseForStrategyLearning,false,"C9 no client-only feedback training")
 eq(#x.offers,0,"C9 lexical host status never dispatches offers")
 local username=x.their:FindFirstChild("Username")
 username.Text="WrongClientPartner"
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "C9 original Stage119 protected facade revoked on partner GUI spoof")
 username.Text="TrustedAlt"
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "C9 original hosted read facade cannot revive after partner spoof restored")
 eq(#x.offers,0,"C9 revoked host never sends a trade offer")
 x.stopButton().Activated:Fire()
 eq(runtime.c9ReadOnlyLeaseStatus().status,"BLOCKED",
    "C9 stopped original P3 owner cannot be reused")
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE.c9ResearchOnly=false
 eq(x.run(),nil,"C9 research fork refuses absent dedicated opt-in")
 eq(#x.offers,0,"C9 unapproved research mode never offers")
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
print("C9_TRUE_ORIGINAL_STAGE119_LEXICAL_HOST_NATIVE_PASS")
