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
if E.PDIDDLER_SUPERVISED_ONE_ITEM_SPENT_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_ONE_ITEM_GUIDE_JOB==game.JobId then
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


-- Reuse the verified Stage100 PURE non-overlapping geometry; only the UI
-- adapter is specific to this supervised pilot. No game input is simulated.
local geometry=loadFrozen(
    "5b8ee35d7f281c23d9c2181abd97a063e59a0660",
    "new_part4/stage100_screen_prompt_overlay.lua")
if type(geometry)~="table" or type(geometry.choose)~="function" then
    warn("[SUPERVISED PILOT] immutable screen geometry unavailable; no offer")
    return nil
end

local function blocked(reason)
    return {
        schema="gingerscope-supervised-one-item-pilot-v1",
        status="BLOCKED",reason=reason,offerCount=0,
        tradeOutcome="UNKNOWN",readOnly=false,
        authorizesTrade=false,authorizesAccept=false,
        serverCompletionProven=false,mayRecordCompletedTrade=false,
        mayReportProfit=false,maySendDiscordWebhook=false,
        mayUseForStrategyLearning=false,
    }
end

-- Export ONLY bounded, non-identifying client-status fields. Never copy
-- partner usernames, item keys, job IDs, private catalogue or inventory.
local function exportResult(report)
    if type(report)~="table" then return false end
    local payload={
        schema="gingerscope-supervised-one-item-pilot-status-v1",
        status=tostring(report.status or "UNKNOWN"),
        reason=tostring(report.reason or "UNKNOWN"),
        offerCount=tonumber(report.offerCount) or 0,
        clientOfferVisible=report.clientOfferVisible==true,
        onScreenGuideShown=report.onScreenGuideShown==true,
        onScreenGuideFinalShown=report.onScreenGuideFinalShown==true,
        onScreenGuidePlacementFailures=
            tonumber(report.onScreenGuidePlacementFailures) or 0,
        tradeOutcome="UNKNOWN",
        authorizesAccept=false,
        serverCompletionProven=false,
        mayReportProfit=false,
        maySendDiscordWebhook=false,
    }
    local ok,json=pcall(function()
        return game:GetService("HttpService"):JSONEncode(payload)
    end)
    if not ok or type(json)~="string" then
        report.clipboardCopied=false
        warn("[PILOT RESULT] JSON export unavailable; screenshot the status")
        return false
    end
    E.PDIDDLER_SUPERVISED_ONE_ITEM_LAST_SANITIZED_JSON=json
    local copyFn=type(setclipboard)=="function" and setclipboard
        or type(toclipboard)=="function" and toclipboard
        or type(E.setclipboard)=="function" and E.setclipboard
        or type(E.toclipboard)=="function" and E.toclipboard
        or nil
    local copied=false
    if copyFn then
        copied=pcall(copyFn,json)
    end
    report.clipboardCopied=copied
    print("[PILOT RESULT JSON] "..json)
    print(copied and "[PILOT] RESULT COPIED TO CLIPBOARD"
        or "[PILOT] CLIPBOARD UNAVAILABLE; USE RESULT JSON OR SCREENSHOT")
    return copied
end

local function makeGuide(pg)
    local world=game:GetService("Workspace")
    local run=game:GetService("RunService")
    if not pg or not world or not world.CurrentCamera
        or not run or not run.RenderStepped then
        return nil,"ONSCREEN_GUIDE_VIEWPORT_OR_RENDER_UNAVAILABLE"
    end
    local ui={}
    local created=pcall(function()
        ui.screen=Instance.new("ScreenGui")
        ui.screen.Name="PDIDDLER_Supervised_OneItem_Steps"
        ui.screen.ResetOnSpawn=false
        ui.screen.IgnoreGuiInset=true
        ui.screen.DisplayOrder=150
        ui.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        ui.screen.Parent=pg

        ui.frame=Instance.new("Frame")
        ui.frame.Name="CurrentStep"
        ui.frame.BackgroundColor3=Color3.fromRGB(28,23,40)
        ui.frame.BorderSizePixel=0
        ui.frame.Active=false
        ui.frame.Visible=false
        ui.frame.Parent=ui.screen
        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,10)
        corner.Parent=ui.frame
        local stroke=Instance.new("UIStroke")
        stroke.Color=Color3.fromRGB(177,128,239)
        stroke.Thickness=1
        stroke.Parent=ui.frame

        local function label(name,y,h,size,color)
            local o=Instance.new("TextLabel")
            o.Name=name
            o.BackgroundTransparency=1
            o.TextColor3=color
            o.TextSize=size
            o.TextWrapped=true
            o.Active=false
            o.TextXAlignment=Enum.TextXAlignment.Left
            o.Font=Enum.Font.GothamBold
            o.Position=UDim2.fromOffset(12,y)
            o.Size=UDim2.fromOffset(280,h)
            o.Parent=ui.frame
            return o
        end
        ui.title=label("Step",8,23,14,Color3.fromRGB(218,187,255))
        ui.body=label("Action",33,48,14,Color3.fromRGB(255,255,255))
        ui.warning=label("Warning",88,18,11,Color3.fromRGB(255,215,185))
        ui.warning.Text="NEVER PRESS FINAL ACCEPT | CLIENT ONLY"

        ui.dismiss=Instance.new("TextButton")
        ui.dismiss.Name="DismissAfterFinish"
        ui.dismiss.Size=UDim2.fromOffset(26,22)
        ui.dismiss.Position=UDim2.fromOffset(268,4)
        ui.dismiss.BackgroundColor3=Color3.fromRGB(76,52,103)
        ui.dismiss.TextColor3=Color3.fromRGB(255,255,255)
        ui.dismiss.Text="X"
        ui.dismiss.Visible=false
        ui.dismiss.Active=false
        ui.dismiss.Parent=ui.frame
    end)
    if not created then
        if ui.screen then pcall(function()ui.screen:Destroy()end) end
        return nil,"ONSCREEN_GUIDE_CREATION_FAILED"
    end
    local guide={ui=ui,stopped=false,finished=false,
                 reason=nil,phase=nil,updates=0,layoutFailures=0,link=nil}

    -- The original MM2 has both TradeGUI and TradeGUI_Phone layouts.
    -- Ambiguous visible roots or unavailable physical dimensions fail shut.
    function guide:tradeRoot()
        local roots={}
        for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
            local screen=pg:FindFirstChild(name)
            if screen and screen.Enabled==true then
                local container=screen:FindFirstChild("Container")
                local root=container and (
                    container:FindFirstChild("Trade")
                    or container:FindFirstChild("Main"))
                if root and container.Visible==true and root.Visible==true then
                    roots[#roots+1]=root
                end
            end
        end
        if #roots>1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
        return roots[1],nil
    end
    function guide:refresh(expected)
        if self.stopped then return false,self.reason or "ONSCREEN_GUIDE_STOPPED" end
        if ui.screen.Parent~=pg or ui.frame.Parent~=ui.screen then
            self.stopped=true
            return false,"ONSCREEN_GUIDE_REMOVED"
        end
        local camera=world.CurrentCamera
        if not camera then return false,"VIEWPORT_UNAVAILABLE" end
        local ok,v=pcall(function()return camera.ViewportSize end)
        if not ok or not v then return false,"VIEWPORT_UNAVAILABLE" end
        local root,why=self:tradeRoot()
        if why then return false,why end
        if expected and root~=expected then
            return false,"TRADE_ROOT_CHANGED_OR_HIDDEN"
        end
        local trade=nil
        if root then
            local good,p,z=pcall(function()
                return root.AbsolutePosition,root.AbsoluteSize
            end)
            if not good or not p or not z then
                return false,"TRADE_BOUNDS_UNAVAILABLE"
            end
            trade={x=p.X,y=p.Y,w=z.X,h=z.Y}
        end
        local rect,reason=geometry.choose(
            {x=v.X,y=v.Y},trade,{w=304,h=120})
        if not rect then return false,reason end
        local laid=pcall(function()
            ui.frame.Position=UDim2.fromOffset(rect.x,rect.y)
            ui.frame.Size=UDim2.fromOffset(rect.w,rect.h)
            ui.frame.Visible=true
        end)
        if not laid then return false,"ONSCREEN_GUIDE_LAYOUT_FAILED" end
        return true,"NONOVERLAPPING_PANEL"
    end
    function guide:fail(why)
        self.stopped=true
        local raw=tostring(why or "UNAVAILABLE")
        self.reason=raw:find("^ONSCREEN_GUIDE_") and raw
            or ("ONSCREEN_GUIDE_"..raw)
        self.layoutFailures+=1
        ui.frame.Visible=false
        return false,self.reason
    end
    function guide:show(phase,expected)
        if self.stopped then return false,self.reason end
        local steps={
            OPEN={"1/3 MAIN - OPEN TRADE",
                "Manually open an EMPTY trade with the consenting ALT. Keep both offers unchanged."},
            OFFER={"2/3 MAIN - ONE ITEM",
                "Checking exact partner and safe layout; attempting ONE approved item. ALT: do not change offer."},
            VERIFY={"3/3 MAIN - VERIFY",
                "Inspect the item in your offer. Manually Decline after recording the result."},
        }
        local info=steps[phase]
        if not info then return self:fail("INVALID_STEP") end
        local ok,reason=self:refresh(expected)
        if not ok then return self:fail(reason) end
        ui.title.Text=info[1]
        ui.body.Text=info[2]
        ui.dismiss.Visible=false
        self.phase=phase
        self.updates+=1
        print("[SUPERVISED PILOT] "..info[1].." | "..info[2])
        return true
    end
    function guide:finish(report)
        self.finished=true
        if self.link then self.link:Disconnect();self.link=nil end
        local ok,reason=self:refresh()
        if not ok then
            -- No misleading status card over live trade controls.
            self:fail(reason)
            return false
        end
        ui.title.Text=report.status=="CLIENT_OFFER_VISIBLE_UNATTRIBUTED"
            and "PASS - CLIENT OFFER VISIBLE" or "STOP / CHECK RESULT"
        ui.body.Text="Status: "..tostring(report.status)
            .." | Outcome UNKNOWN. Result auto-copies when possible; MAIN manually Decline."
        ui.warning.Text="NEVER PRESS FINAL ACCEPT"
        ui.dismiss.Visible=true
        ui.dismiss.Active=true
        return true
    end
    function guide:safeForOffer(expected)
        local ok,why=self:refresh(expected)
        if not ok then return self:fail(why) end
        return self.phase=="OFFER",self.phase=="OFFER" and "SAFE" or "WRONG_PHASE"
    end
    ui.dismiss.Activated:Connect(function()
        if not guide.finished then return end
        pcall(function()ui.screen:Destroy()end)
    end)
    local okConnect,link=pcall(function()
        return run.RenderStepped:Connect(function()
            if guide.finished or guide.stopped then return end
            local safe,reason=guide:refresh()
            if not safe then guide:fail(reason) end
        end)
    end)
    if not okConnect or not link then
        pcall(function()ui.screen:Destroy()end)
        return nil,"ONSCREEN_GUIDE_RENDER_HOOK_FAILED"
    end
    guide.link=link
    return guide,nil
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


-- Guide starts BEFORE the operator opens the trade. Never start by asking
-- the user to perform steps that the game cannot display.
local pg=lp:FindFirstChildOfClass("PlayerGui")
local guide,guideWhy=makeGuide(pg)
if not guide then
    warn("[SUPERVISED PILOT] "..tostring(guideWhy).."; no offer attempted")
    local report=blocked(guideWhy)
    E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=report
    exportResult(report)
    return report
end
E.PDIDDLER_SUPERVISED_ONE_ITEM_GUIDE_JOB=game.JobId
local shown,showWhy=guide:show("OPEN",nil)
if not shown then
    warn("[SUPERVISED PILOT] "..tostring(showWhy).."; no offer attempted")
    local report=blocked(showWhy)
    E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=report
    exportResult(report)
    return report
end
local visibleRoot=nil
for _=1,120 do
    local root,why=guide:tradeRoot()
    if why then
        guide:fail(why)
        break
    end
    if root then visibleRoot=root;break end
    if guide.stopped then break end
    task.wait(0.25)
end
if not visibleRoot or guide.stopped then
    local why=guide.reason or "MANUAL_TRADE_OPEN_TIMED_OUT"
    local report=blocked(why)
    guide:finish(report)
    E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=report
    exportResult(report)
    return report
end
shown,showWhy=guide:show("OFFER",visibleRoot)
if not shown then
    local report=blocked(showWhy)
    guide:finish(report)
    E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=report
    exportResult(report)
    return report
end
task.wait(0.15) -- allow the current on-screen instruction to render
-- Enforce the guide at the exact OfferItem boundary, not only beforehand.
local underlyingOffer=io.offerItem
io.offerItem=function(item)
    local root=io.trade()
    if root~=visibleRoot then
        return false,"TRADE_ROOT_CHANGED_OR_HIDDEN"
    end
    local safe,reason=guide:safeForOffer(root)
    if not safe then return false,reason end
    return underlyingOffer(item)
end
local safe,reason=guide:safeForOffer(visibleRoot)
if not safe then
    local report=blocked(reason)
    guide:finish(report)
    E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=report
    exportResult(report)
    return report
end
local okRun,report=pcall(pilot.run,io,gate,players,lp,cfg)

if not okRun or type(report)~="table" then
    gate.checkOutbound=nil
    local failed=blocked("PILOT_RUNTIME_FAILURE")
    guide:finish(failed)
    E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=failed
    exportResult(failed)
    warn("[SUPERVISED PILOT] local preflight failed; no completion claimed")
    return failed
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
-- Show the third instruction after the actual client offer observation.
-- It does not authorize a second attempt or any final Accept.
if not guide.stopped then
    guide:show("VERIFY",visibleRoot)
    task.wait(0.15)
end
-- Leave final on-screen PASS/STOP visible until the user dismisses it.
-- These are client-side observations only; never infer settlement/profit.
report.onScreenGuideShown=true
report.onScreenGuideUpdates=guide.updates
report.onScreenGuidePlacementFailures=guide.layoutFailures
report.onScreenGuideFinalShown=guide:finish(report)
report.onScreenGuideNonOverlappingTrade=report.onScreenGuideFinalShown
E.PDIDDLER_SUPERVISED_ONE_ITEM_RESULT=report
exportResult(report)
print("[PDIDDLER SUPERVISED]",tostring(report.status),
    tostring(report.reason),"outcome UNKNOWN; NEVER FINAL ACCEPT")
return report
