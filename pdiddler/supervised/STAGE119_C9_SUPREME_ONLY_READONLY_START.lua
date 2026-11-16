-- C9 ORIGINAL P3/P4 consented SUPREME-ONLY protected research launcher.
-- Does not ARM, request, offer, Accept/Decline, chat, hop, or train.
-- A user must independently approve any actual native test, then the
-- separate original P3 GUI ARM can send ONE controlled request to ALT.
-- Calls new Supreme-only read-only evaluator ONLY after original P3/P4 binding.
-- NOT a device test, signed publisher source, server settlement or autonomy.
local E=(type(getgenv)=="function" and getgenv()) or _G
local plan=E.GINGERSCOPE_C9_SUPREME_ONLY_PLAN
local function refuse(why)
    warn("[C9 RESEARCH START] "..tostring(why))
    return nil
end
if type(plan)~="table" or
   plan.explicitOperatorWantsC9Research~=true or
   plan.understandsArmSendsP3TradeRequest~=true or
   plan.consentVerifiedForNamedAlt~=true or
   plan.noWeaponAddOrRemoveTests~=true or
   plan.operatorConfirmedReadOnlyInventoryRpc~=true or
   plan.understandsCurrentSourceMayExpire~=true or
   plan.finalAcceptMustRemainManual~=true or
   plan.supremeOnlyResearchRequested~=true or
   plan.explicitOwnInventoryReadRpcConsent~=true or
   plan.automaticP3ArmForbidden~=true or
   type(plan.targetName)~="string" or
   #plan.targetName<3 or #plan.targetName>32 or
   not plan.targetName:match("^[A-Za-z0-9_]+$") then
    return refuse("EXPLICIT_C9_MANUAL_REQUEST_AND_NO_GIFT_TEST_PLAN_REQUIRED")
end
if game.PlaceId~=142823291 or type(game.JobId)~="string" or
   #game.JobId<8 or
   E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE~=nil or
   E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil or
   E.PDIDDLER_SUPERVISED_P3_USED_JOB==game.JobId or
   E.PDIDDLER_STAGE101_IDENTITY_USED_JOB==game.JobId or
   E.PDIDDLER_STAGE119_P3_USED_JOB==game.JobId or
   E.PDIDDLER_STAGE119_LASTOFFER_OWNER~=nil or
   E.PDIDDLER_STAGE119_LASTOFFER_USED_JOB==game.JobId or
   E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB==game.JobId or
   E.PDIDDLER_P3_OWNED_PICKER_USED_JOB==game.JobId or
   E.PDIDDLER_P3_AUTO_OWNED_PICKER_USED_JOB==game.JobId or
   E.PDIDDLER_OUTGOING_SESSION~=nil or
   E.PDIDDLER_PART4_SESSION~=nil or
   E.PDIDDLER_PART4_CONTROLLER_ACTIVE==true or
   E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE==true or
   E.PDIDDLER_AUTOTRADE_ACTIVE==true or
   (type(E.GINGERSCOPE_STAGE106_READONLY_WITNESS)=="table" and
     E.GINGERSCOPE_STAGE106_READONLY_WITNESS.running==true) then
    return refuse("C9_ORIGINAL_MM2_NEW_JOB_AND_NO_OTHER_TRANSACTION_OWNER_REQUIRED")
end
local okPlayers,players=pcall(function()
    return game:GetService("Players")
end)
if not okPlayers or not players then
    return refuse("C9_PLAYERS_SERVICE_UNAVAILABLE")
end
local me=players.LocalPlayer
local target=players:FindFirstChild(plan.targetName)
if not me or me.Parent~=players or not target or target==me or
   target.Parent~=players or target.Name~=plan.targetName then
    return refuse("C9_EXACT_CONSENTING_ALT_NOT_PRESENT")
end
local exact,checked=pcall(players.GetPlayerByUserId,players,target.UserId)
if not exact or checked~=target then
    return refuse("C9_ALT_ACCOUNT_IDENTITY_NOT_CURRENT")
end
local pinned="392afac77c00fb33b41c0d5d090bdbb05cfd5a8e"
local path="pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_READONLY_NATIVE.lua"
local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
    ..pinned.."/"..path
local ok,source=pcall(function()return game:HttpGet(url)end)
if not ok or type(source)~="string" or #source<39000 or
   #source>90000 or
   not source:find("cfg.c9ResearchOnly~=true",1,true) or
   not source:find("c9ReadOnlyLeaseStatus=c9ReadOnlyLeaseStatus",1,true) or
   not source:find("c9SupremeOnlyReadOnlyPreview=c9SupremeOnlyReadOnlyPreview",1,true) then
    return refuse("C9_IMMUTABLE_RESEARCH_RUNNER_UNAVAILABLE")
end
local compiler=loadstring or load
if type(compiler)~="function" then
    return refuse("C9_COMPILER_UNAVAILABLE")
end
-- The ONLY action on load is preparing the original guarded client GUI.
-- A real P3 request can occur ONLY after a separate manual ARM button tap.
E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE={
    enableNativeSupervisor=true,finalAcceptMustRemainManual=true,
    altOnlyTest=true,stage119LastOfferReadOnly=true,
    c9ResearchOnly=true,c9SupremeOnlyReadOnly=true,
    operatorConfirmedReadOnlyInventoryRpc=true,
    targetName=plan.targetName,
}
local success,runtime=pcall(function()
    return assert(compiler(source))()
end)
if not success or type(runtime)~="table" or
   type(runtime.stop)~="function" or
   type(runtime.status)~="function" or
   type(runtime.isArmed)~="function" or
   type(runtime.c9ReadOnlyLeaseStatus)~="function" or
   type(runtime.c9SupremeOnlyReadOnlyPreview)~="function" or
   runtime.arm~=nil or runtime.offer~=nil or
   runtime.accept~=nil or runtime.decline~=nil or
   runtime.sendChat~=nil or
   runtime.c9ReadOnlyMarketPreflight~=nil then
    if success and type(runtime)=="table" and
       type(runtime.stop)=="function" then
        pcall(runtime.stop)
    end
    E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE=nil
    return refuse("C9_PINNED_STAGE119_RESEARCH_RUNTIME_REFUSED")
end
return runtime
