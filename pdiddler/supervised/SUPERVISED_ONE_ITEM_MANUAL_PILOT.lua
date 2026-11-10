-- PDIDDLER SUPERVISED 1-ITEM MANUAL PILOT (original MM2 only)
-- This never sends a trade request, searches partners, chooses market offers,
-- rebalances, declines, auto Accepts, or reports profit/settlement.
-- The operator must MANUALLY OPEN one trade with an exact consenting partner
-- first and explicitly choose ONE raw weapon key and arm the pilot.
-- One-shot action: try exactly ONE OfferItem; outcome is always UNKNOWN.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_SUPERVISED_ONE_ITEM_PILOT"
if game.PlaceId~=142823291 then
    warn("[SUPERVISED PILOT] original MM2 place required; no action")
    return nil
end
local cfg=E[KEY]
if type(cfg)~="table" or cfg.armed~=true or cfg.manualOfferOnly~=true then
    warn("[SUPERVISED PILOT] Set exact targetName, weaponKey, armed=true, manualOfferOnly=true")
    return nil
end
-- Do not permit an old Part3/4 auto-trader to own this trade simultaneously.
for _,owner in ipairs({
    "PDIDDLER_PART4_CONTROLLER_ACTIVE",
    "PDIDDLER_OUTGOING_CONTROLLER_ACTIVE",
    "PDIDDLER_AUTOTRADE_ACTIVE",
}) do
    if E[owner]==true then
        warn("[SUPERVISED PILOT] automatic controller present; no action")
        return nil
    end
end
-- Older Part3/Part4 controllers use these actual session owners, not the
-- generic _ACTIVE flags above. Even a stale owner marker is a reason to
-- require a fresh server for the one-item manual pilot.
if E.PDIDDLER_PART4_SESSION~=nil
    or E.PDIDDLER_OUTGOING_SESSION~=nil
    or (type(E.GINGERSCOPE_STAGE106_READONLY_WITNESS)=="table"
        and E.GINGERSCOPE_STAGE106_READONLY_WITNESS.running==true) then
    warn("[SUPERVISED PILOT] other trade/test session owner present; use a fresh server")
    return nil
end
if E.PDIDDLER_SUPERVISED_ONE_ITEM_SPENT_JOB==game.JobId then
    warn("[SUPERVISED PILOT] one offer already attempted in this job")
    return nil
end

local function loadFrozen(rev,path)
    local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
        ..rev.."/pdiddler/"..path
    local ok,source=pcall(function()return game:HttpGet(url)end)
    if not ok or type(source)~="string" or #source<100 or #source>30000 then
        return nil
    end
    local compiler=loadstring or load
    if type(compiler)~="function" then return nil end
    local okLoad,module=pcall(function()
        return assert(compiler(source))()
    end)
    if okLoad and type(module)=="table" then return module end
    return nil
end
-- Public SOURCE CODE reads only. No source website price/identity is
-- treated as verified, and no client/game inventory is uploaded.
local ioModule=loadFrozen(
    "a599c31c53d25e6799b9d631f45f282b445dcda0",
    "supervised/pdiddler4_tradeio_supervised_v2.lua")
local pilot=loadFrozen(
    "9540fc5fc3576729f9dd308d8d8222d848e27063",
    "supervised/supervised_one_item_policy.lua")
if not ioModule or type(ioModule.new)~="function"
    or not pilot or type(pilot.run)~="function" then
    warn("[SUPERVISED PILOT] pinned source unavailable; no action")
    return nil
end

local players=game:GetService("Players")
local lp=players.LocalPlayer
if not lp then
    warn("[SUPERVISED PILOT] LocalPlayer unavailable")
    return nil
end
-- Only original OfferItem path is required. NO scanner, price lookup,
-- other players' inventories or trade planner is activated.
local scanner={resolveOfferEntry=function()return nil end}
local gate={}
local okIO,io=pcall(ioModule.new,scanner,gate)
if not okIO or type(io)~="table" then
    warn("[SUPERVISED PILOT] guarded TradeIO could not initialize; no action")
    return nil
end

local okRun,report=pcall(pilot.run,io,gate,players,lp,cfg)
if not okRun or type(report)~="table" then
    gate.checkOutbound=nil
    warn("[SUPERVISED PILOT] local preflight failed; no completion claimed")
    return nil
end
local status=report.status
-- One-shot consumed ONLY after passing all preflight checks and invoking
-- guarded TradeIO. Never retry automatically, even on UI replication delay.
if cfg._consumed==true then
    E.PDIDDLER_SUPERVISED_ONE_ITEM_SPENT_JOB=game.JobId
end

if status=="OFFER_REMOTE_FIRED_CLIENT_ONLY" then
    local selectedKey=cfg.weaponKey
    task.wait(0.35)
    local t=io.trade()
    local found=false
    if t then
        local okRead,match=pcall(io.ourOfferContains,t,{
            id=selectedKey,name=selectedKey
        })
        found=okRead and match==true
    end
    report.clientOfferVisible=found
    report.status=found
        and "CLIENT_OFFER_VISIBLE_UNATTRIBUTED"
        or "OFFER_REMOTE_FIRED_GUI_UNCONFIRMED"
else
    report.clientOfferVisible=false
end
-- Entire persisted/printed result is a bounded status WITHOUT item name,
-- partner username, IDs, game JobId, market price or trade outcome claims.
report.tradeOutcome="UNKNOWN"
report.authorizesAccept=false
report.authorizesTrade=false
report.mayRecordCompletedTrade=false
report.mayReportProfit=false
report.maySendDiscordWebhook=false
report.mayUseForStrategyLearning=false
E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=report
local userText="Manual offer pilot: "..tostring(report.status)
    .." | final Accept NOT touched | outcome UNKNOWN"
print("[PDIDDLER SUPERVISED]",userText)
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title="PDIDDLER - MANUAL OFFER",
        Text=userText,
        Duration=7,
    })
end)
return report
