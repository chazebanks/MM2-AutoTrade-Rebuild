-- SUPERVISED FOUR-SLOT MANUAL TEST RUNNER (original MM2 only).
-- Reuses PR198 in-game instructions + clipboard, PR199 exact live GUI
-- snapshot/physical slot checks, PR200 user-approved offer plan and PR195
-- Gingerscope-guarded OfferItem. Manual target ONLY: this does NOT run P3
-- scanner auto-rotation; manual partner consent is NOT P3 eligibility proof.
-- NO final Accept, automatic request, hop, prices, profit or Discord.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT"
if game.PlaceId~=142823291 then
    warn("[SUPERVISED PILOT] original MM2 place required; no action")
    return nil
end
local cfg=E[KEY]
if type(cfg)~="table" or cfg.armed~=true or cfg.manualOfferOnly~=true
    or cfg.noAutomaticAcceptAcknowledged~=true
    or type(cfg.targetName)~="string" or
       #cfg.targetName<3 or #cfg.targetName>32 or
       not cfg.targetName:match("^[A-Za-z0-9_]+$") then
    warn("[SUPERVISED PILOT] Set targetName, weaponKeys[1..4], armed, manualOfferOnly, noAutomaticAcceptAcknowledged")
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
-- require a fresh server for the four-slot manual pilot.
if E.PDIDDLER_PART4_SESSION~=nil
    or E.PDIDDLER_OUTGOING_SESSION~=nil
    or (type(E.GINGERSCOPE_STAGE106_READONLY_WITNESS)=="table"
        and E.GINGERSCOPE_STAGE106_READONLY_WITNESS.running==true) then
    warn("[SUPERVISED PILOT] other trade/test session owner present; use a fresh server")
    return nil
end
if E.PDIDDLER_SUPERVISED_FOUR_SLOT_SPENT_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_FOUR_SLOT_GUIDE_JOB==game.JobId then
    warn("[SUPERVISED PILOT] a supervised test already ran in this job")
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
local bridgeModule=loadFrozen(
    "616f905739ffb7bf70183475a79ec6c278dc9ddb",
    "supervised/supervised_p3_p4_handoff.lua")
local planModule=loadFrozen(
    "27e061555321c6a87bdd835ce3d1ff557443a909",
    "supervised/supervised_four_slot_operator_plan.lua")
if not ioModule or type(ioModule.new)~="function"
    or not bridgeModule or type(bridgeModule.bind)~="function"
    or not planModule or type(planModule.run)~="function" then
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
        schema="gingerscope-supervised-four-slot-native-v1",
        status="BLOCKED",reason=reason,offerAttempts=0,
        clientVisibleAddedSlots=0,
        tradeOutcome="UNKNOWN",readOnly=false,
        authorizesTrade=false,authorizesAccept=false,
        serverCompletionProven=false,mayRecordCompletedTrade=false,
        mayReportProfit=false,maySendDiscordWebhook=false,
        mayUseForStrategyLearning=false,
    }
end

-- Export ONLY bounded, non-identifying client-status fields. Never copy
-- partner usernames, item keys, job IDs, private catalogue or inventory.
local function exportResult(report,guide)
    local function onScreen(copyStatus)
        if not guide or not guide.finished or guide.stopped
            or not guide.ui or not guide.ui.body then return end
        pcall(function()
            guide.ui.body.TextSize=12
            local detail=type(report.snapshotRejectReason)=="string"
                and report.snapshotRejectReason or "NO_DETAIL"
            if report.clipboardCopied==true then
                guide.ui.body.Text="COPIED. Cause: "..detail
                    ..". Paste report. MAIN manually Decline."
            else
                guide.ui.body.Text="COPY FAILED. Cause: "..detail
                    ..". Screenshot. MAIN manually Decline."
            end
        end)
    end
    if type(report)~="table" then return false end
    local payload={
        schema="gingerscope-supervised-four-slot-native-status-v1",
        status=tostring(report.status or "UNKNOWN"),
        reason=tostring(report.reason or "UNKNOWN"),
        -- Static anonymous controller code only, never partner/item/JobId.
        snapshotRejectReason=type(report.snapshotRejectReason)=="string"
          and report.snapshotRejectReason:match("^[A-Z_]+$")
          and #report.snapshotRejectReason<=72
          and report.snapshotRejectReason or nil,
        offerAttempts=tonumber(report.offerAttempts),
        offerAttemptsKnown=report.offerAttemptsKnown~=false,
        clientVisibleAddedSlots=tonumber(report.clientVisibleAddedSlots),
        clientVisibleAddedSlotsKnown=report.clientVisibleAddedSlotsKnown~=false,
        contactOrigin="MANUAL_CONSENT_CLIENT_ONLY",
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
        onScreen("COPY FAILED - SCREENSHOT")
        return false
    end
    E.PDIDDLER_SUPERVISED_FOUR_SLOT_LAST_SANITIZED_JSON=json
    local copyFn=type(setclipboard)=="function" and setclipboard
        or type(toclipboard)=="function" and toclipboard
        or type(E.setclipboard)=="function" and E.setclipboard
        or type(E.toclipboard)=="function" and E.toclipboard
        or nil
    local copied=false
    if copyFn then
        local okCopy,result=pcall(copyFn,json)
        copied=okCopy and result~=false
    end
    report.clipboardCopied=copied
    onScreen(copied and "COPIED - PASTE IN CHATGPT" or "COPY FAILED - SCREENSHOT")
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
            OFFER={"2/3 MAIN - APPROVED OFFER",
                "Checking the exact trade and approved multi-item plan. ALT: do not change offer."},
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
    -- Single CURRENT item instruction, with per-frame collision safety.
    -- Controller calls this only after preceding slot is GUI-verified.
    function guide:showItem(index,total,expected)
        if self.stopped or self.phase~="OFFER"
            or type(index)~="number" or type(total)~="number"
            or index~=math.floor(index) or total~=math.floor(total)
            or index<1 or total<1 or total>4 or index>total then
            return false,"ONSCREEN_STEP_INVALID"
        end
        local ok,why=self:refresh(expected)
        if not ok then return self:fail(why) end
        ui.title.Text="2/3 MAIN - ITEM "..index.."/"..total
        ui.body.Text="MAIN: confirming slot "..index.."/"..total..
            ". ALT: keep offer unchanged. NEVER press final Accept."
        ui.warning.Text="NEVER PRESS FINAL ACCEPT | CLIENT ONLY"
        self.updates+=1
        print("[SUPERVISED PILOT] 2/3 MAIN - ITEM "..index.."/"..total
            .." | prior GUI slots verified; protected next offer")
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
        ui.title.Text=report.status=="CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED"
            and "PASS - CLIENT SLOTS VISIBLE" or "STOP / CHECK RESULT"
        ui.body.TextSize=12
        ui.body.Text="Status: "..tostring(report.status)
            .." | Snapshot: "..tostring(report.snapshotRejectReason or "NO_DETAIL")
            .." | Outcome UNKNOWN. MAIN manually Decline."
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
local gate={}
local ioReady,io=pcall(ioModule.new,{
    resolveOfferEntry=function()return nil end
},gate)
if not ioReady or type(io)~="table" then
    warn("[SUPERVISED PILOT] protected TradeIO failed to initialize")
    return nil
end
local pg=lp:FindFirstChildOfClass("PlayerGui")
local guide,guideReason=makeGuide(pg)
if not guide then
    local r=blocked(guideReason or "ONSCREEN_GUIDE_UNAVAILABLE")
    E.PDIDDLER_SUPERVISED_FOUR_SLOT_RESULT=r
    exportResult(r,nil)
    return r
end
E.PDIDDLER_SUPERVISED_FOUR_SLOT_GUIDE_JOB=game.JobId
local function finalize(r)
    -- A client GUI success never proves a settled trade, valuation or profit.
    r.tradeOutcome="UNKNOWN"
    r.authorizesTrade=false
    r.authorizesAccept=false
    r.serverCompletionProven=false
    r.mayReportProfit=false
    r.maySendDiscordWebhook=false
    r.mayUseForStrategyLearning=false
    r.contactOrigin="MANUAL_CONSENT_CLIENT_ONLY"
    r.onScreenGuideShown=true
    r.onScreenGuideUpdates=guide.updates
    r.onScreenGuidePlacementFailures=guide.layoutFailures
    r.onScreenGuideFinalShown=guide:finish(r)
    E.PDIDDLER_SUPERVISED_FOUR_SLOT_RESULT=r
    exportResult(r,guide)
    return r
end
local step,stepWhy=guide:show("OPEN",nil)
if not step then return finalize(blocked(stepWhy)) end
local root
for _=1,120 do
    local active,why=guide:tradeRoot()
    if why then guide:fail(why);break end
    if active then root=active;break end
    if guide.stopped then break end
    task.wait(0.25)
end
if not root or guide.stopped then
    return finalize(blocked(guide.reason or "MANUAL_TRADE_OPEN_TIMED_OUT"))
end
-- Manual-consent adapter: supplies ONLY the exact operator-selected
-- target as a contact. It does not claim that actual Part3 sent a request,
-- classified a whitelist, or paused its autonomous rotation.
local target=players:FindFirstChild(cfg.targetName)
if not target or target==lp or target.Parent~=players then
    return finalize(blocked("EXACT_MANUAL_TARGET_NOT_IN_SERVER"))
end
local manualContact={
    getRecord=function(userId)
        if target.Parent==players and userId==target.UserId then
            return {player=target,state="whitelist"}
        end
    end,
    isWhitelisted=function(userId)
        return target.Parent==players and userId==target.UserId
    end,
}
local localEpoch=1
local manualWindow={
    session=localEpoch,
    isPaused=function() return io.trade()==root end,
    resume=function()
        return false,"MANUAL_MODE_HAS_NO_P3_OUTGOING_ROTATOR"
    end,
}
local liveContext={
    targetName=cfg.targetName,
    getJobId=function() return game.JobId end,
    getP3Session=function() return localEpoch end,
}
local bound,bindWhy=bridgeModule.bind(
    manualContact,manualWindow,io,players,lp,liveContext
)
if not bound then
    return finalize(blocked(
        type(bindWhy)=="table" and bindWhy.reason or
        "EXACT_MANUAL_TRADE_BINDING_REJECTED"))
end
-- Prevent the synthetic manual-contact adapter from being mistaken
-- for an actual Part3 request or autonomous contact-eligibility witness.
local capture=bound.capture
bound.capture=function()
    local r=capture()
    if type(r)=="table" and
       r.status=="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" then
        r.part3Paused=false
        r.requestOriginBound=false
        r.manualContactOnly=true
    end
    return r
end
step,stepWhy=guide:show("OFFER",root)
if not step then return finalize(blocked(stepWhy)) end
task.wait(0.15)
local physicalOffer=io.offerItem
io.offerItem=function(item)
    if io.trade()~=root then
        return false,"TRADE_ROOT_CHANGED"
    end
    local safe,why=guide:safeForOffer(root)
    if not safe then return false,why end
    return physicalOffer(item)
end
local safe,why=guide:safeForOffer(root)
if not safe then return finalize(blocked(why)) end

local ok,result=pcall(planModule.run,
    bound,io,gate,cfg,{
        wait=function(seconds)
            task.wait(seconds)
        end,
        onBeforeItem=function(index,total,priorVisible)
            if priorVisible~=index-1 then return false end
            local shown=guide:showItem(index,total,root)
            if shown~=true then return false end
            task.wait(0.05)
            local safe=guide:safeForOffer(root)
            return safe==true
        end,
    })
gate.checkOutbound=nil
if not ok or type(result)~="table" then
    -- A runtime exception could occur AFTER an OfferItem was dispatched.
    -- Never print a fabricated zero-attempt count or permit a retry.
    result=blocked("SUPERVISED_MULTISLOT_CONTROLLER_ERROR")
    result.status="INCONCLUSIVE"
    result.offerAttempts=nil
    result.offerAttemptsKnown=false
    result.clientVisibleAddedSlots=nil
    result.clientVisibleAddedSlotsKnown=false
end
if cfg._consumed==true then
    E.PDIDDLER_SUPERVISED_FOUR_SLOT_SPENT_JOB=game.JobId
end
if not guide.stopped then
    guide:show("VERIFY",root)
    task.wait(0.15)
end
return finalize(result)
