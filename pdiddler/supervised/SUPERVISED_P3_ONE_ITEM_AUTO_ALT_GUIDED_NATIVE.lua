-- Distinct guided P3 post-auto-offer ALT ADD/REMOVE evidence test.
-- Forks the proven original; never alter the pinned PR218 runner.
-- Preauthorized ONE item by a separate actual user tap in the owned picker.
-- ARM P3 only after the panel discloses the single upcoming automatic offer.
-- Only the first exact stable P3/P4 trade may trigger a single guarded item
-- placement. No automatic final Accept, trading decisions, Discord or hop.
-- The proven PR214 and PR216 runners remain unchanged.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE"
local cfg=E[KEY]
if game.PlaceId~=142823291 or type(cfg)~="table"
    or cfg.enableNativeSupervisor~=true
    or cfg.finalAcceptMustRemainManual~=true
    or cfg.altOnlyTest~=true
    or cfg.allowOneItemPilot~=true
    or cfg.manualOfferOnly~=true
    or cfg.noAutomaticAcceptAcknowledged~=true
    or cfg.altMutationGuidedReadOnlyTest~=true
    or type(cfg.autoConsent)~="table"
    or cfg.autoConsent.origin~="PICKER_HUMAN_APPROVED_AUTO_ONE"
    or cfg.autoConsent.explicitOneAutomaticPlacement~=true
    or cfg.autoConsent.singleConsentingAltOnly~=true
    or cfg.autoConsent.finalAcceptMustRemainManual~=true
    or cfg.autoConsent.rawKey~=cfg.approvedRawKey
    or cfg.autoConsent.display~=cfg.approvedDisplayName
    or cfg.autoConsent.chroma~=cfg.approvedChromaFlag
    or cfg.autoConsent.job~=game.JobId
    or type(cfg.approvedRawKey)~="string" or
       #cfg.approvedRawKey<1 or #cfg.approvedRawKey>24 or
       not cfg.approvedRawKey:match("^[A-Za-z0-9_]+$") or
    type(cfg.approvedDisplayName)~="string" or
       #cfg.approvedDisplayName<1 or #cfg.approvedDisplayName>24 or
       cfg.approvedDisplayName:find("[%c]") or
    type(cfg.approvedChromaFlag)~="boolean" or
    cfg.approvedRawKey:lower():find("gingerscope",1,true) or
    cfg.approvedDisplayName:lower():find("gingerscope",1,true) or
    type(cfg.targetName)~="string" or
       #cfg.targetName<3 or #cfg.targetName>32 or
       not cfg.targetName:match("^[A-Za-z0-9_]+$") then
    warn("[P3 NATIVE] Original MM2 and explicit configuration required")
    return nil
end
if E.PDIDDLER_SUPERVISED_P3_USED_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_USED_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil
    or E.PDIDDLER_OUTGOING_SESSION~=nil
    or E.PDIDDLER_PART4_SESSION~=nil
    or E.PDIDDLER_SUPERVISED_FOUR_SLOT_GUIDE_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_ONE_ITEM_GUIDE_JOB==game.JobId
    or (type(E.GINGERSCOPE_STAGE106_READONLY_WITNESS)=="table"
        and E.GINGERSCOPE_STAGE106_READONLY_WITNESS.running==true)
    or E.PDIDDLER_PART4_CONTROLLER_ACTIVE==true
    or E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE==true
    or E.PDIDDLER_AUTOTRADE_ACTIVE==true then
    warn("[P3 NATIVE] Another P3/P4 owner or previous test in this job")
    return nil
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local World=game:GetService("Workspace")
if not PG or not World or not World.CurrentCamera then
    warn("[P3 NATIVE] GUI and live camera required")
    return nil
end
local target=Players:FindFirstChild(cfg.targetName)
if not target or target==LP or target.Parent~=Players
   or target.Name~=cfg.targetName or
   Players:GetPlayerByUserId(target.UserId)~=target then
    warn("[P3 NATIVE] Exact consenting ALT must be present first")
    return nil
end
local targetUid=target.UserId
local function targetStillExact()
    return target.Parent==Players
       and target.Name==cfg.targetName
       and Players:FindFirstChild(cfg.targetName)==target
       and Players:GetPlayerByUserId(targetUid)==target
end
local function loadFrozen(rev,path,maxSize)
    local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
       ..rev.."/pdiddler/"..path
    local ok,source=pcall(function()return game:HttpGet(url)end)
    if not ok or type(source)~="string" or #source<100
        or #source>(maxSize or 95000) then return nil end
    local compiler=loadstring or load
    if type(compiler)~="function" then return nil end
    local okLoad,result=pcall(function()
       return assert(compiler(source))()
    end)
    return okLoad and type(result)=="table" and result or nil
end
local geometry=loadFrozen("5b8ee35d7f281c23d9c2181abd97a063e59a0660",
    "new_part4/stage100_screen_prompt_overlay.lua")
local ioModule=loadFrozen("a599c31c53d25e6799b9d631f45f282b445dcda0",
    "supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridge=loadFrozen("2f556afac5e5fd9cfdbf9e081eeea01a542d293",
    "supervised/supervised_p3_p4_handoff.lua")
local coordinator=loadFrozen("9138751b5a57415939ffa1618ac57811d7c8ec7b",
    "supervised/supervised_real_p3_rotation_handoff.lua")
local outgoingModule=loadFrozen("2036ae5bd937620f21d46600f99550a1b233a654",
    "supervised/pdiddler3_outgoing_START_GATED_v1.lua")
local bootModule=loadFrozen("af84b23173620b03e919187b08cd352c101ba4ea",
    "supervised/supervised_p3_startup_supervisor.lua")
local watchdogModule=loadFrozen("48c4b0fee594639c74f1bed408581db7a5bc6f1b",
    "supervised/supervised_p3_continuous_watchdog.lua")
local planModule=loadFrozen("27e061555321c6a87bdd835ce3d1ff557443a909",
    "supervised/supervised_four_slot_operator_plan.lua")
local operatorModule=loadFrozen("b124488a7a879b2d6a1bfb21401f497d7bfef677",
    "supervised/supervised_p3_one_item_operator.lua")
local autoModule=loadFrozen("9a5a3c4db018ed7a00f8eacd6ca988cca3152a33",
    "supervised/supervised_p3_one_item_auto_gate.lua")
local altGuideModule=loadFrozen("2f4478ed23743060bb3bd3a56daad47dc59f494e",
    "supervised/supervised_p3_postoffer_alt_guide.lua")
if not geometry or type(geometry.choose)~="function"
    or not ioModule or type(ioModule.new)~="function"
    or not bridge or type(bridge.bind)~="function"
    or not coordinator or type(coordinator.new)~="function"
    or not outgoingModule or type(outgoingModule.run)~="function"
    or not bootModule or type(bootModule.new)~="function"
    or not watchdogModule or type(watchdogModule.new)~="function"
    or not planModule or type(planModule.run)~="function"
    or not operatorModule or type(operatorModule.new)~="function"
    or not autoModule or type(autoModule.new)~="function"
    or not altGuideModule or type(altGuideModule.new)~="function" then
    warn("[P3 NATIVE] Immutable source unavailable: P3 remains disabled")
    return nil
end
local nonceOk,runNonce=pcall(function()
    return game:GetService("HttpService"):GenerateGUID(false)
end)
if not nonceOk or type(runNonce)~="string" or
   not runNonce:match("^[0-9a-fA-F%-]+$") or #runNonce>48 or #runNonce<20 then
    warn("[P3 ALT GUIDE] Nonprivate unique run token unavailable")
    return nil
end
local altGuide=altGuideModule.new()
if type(altGuide)~="table" or type(altGuide.observe)~="function" or
   type(altGuide.current)~="function" then
    warn("[P3 ALT GUIDE] Guide source not usable")
    return nil
end
local owner={job=game.JobId,running=true}
E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER=owner
-- Client-observed milestones are sticky even after terminal STOP.
-- These do NOT authenticate a network-delivered request or any settlement.
local evidence={
    oneItemTapObservedClient=false,
    autoOfferPreauthorizedClient=true,
    autoOfferTriggeredClient=false,
    oneItemOfferStatus="NOT_ATTEMPTED",
    oneItemSnapshotRejectReason="NONE",
    oneItemOfferAttempts=0,
    clientVisibleAddedSlots=0,
    offerAttemptsKnown=true,
    p3ArmObservedClient=false,
    clientTradeWindowObserved=false,
    clientResumeObserved=false,
    lastObservedStatus="NONE",
}
local function statusRecord(status,reason)
    return {
        schema="gingerscope-p3-one-item-alt-guided-native-v1",
        runNonce=runNonce,
        altTestPhase=altGuide.current().phase,
        altAddClientObserved=altGuide.current().altAddClientObserved,
        altRemoveClientObserved=altGuide.current().altRemoveClientObserved,
        altSequenceClientComplete=altGuide.current().completedClientSequence,
        altMutationEvidenceTier="CLIENT_ONLY_UNATTRIBUTED",
        status=tostring(status or "UNKNOWN"),
        reason=tostring(reason or "UNKNOWN"),
        oneItemTapObservedClient=evidence.oneItemTapObservedClient,
        autoOfferPreauthorizedClient=evidence.autoOfferPreauthorizedClient,
        autoOfferTriggeredClient=evidence.autoOfferTriggeredClient,
        oneItemOfferStatus=evidence.oneItemOfferStatus,
        snapshotRejectReason=evidence.oneItemSnapshotRejectReason,
        offerAttempts=evidence.oneItemOfferAttempts,
        offerAttemptsKnown=evidence.offerAttemptsKnown,
        clientVisibleAddedSlots=evidence.clientVisibleAddedSlots,
        p3ArmObservedClient=evidence.p3ArmObservedClient,
        clientTradeWindowObserved=evidence.clientTradeWindowObserved,
        clientResumeObserved=evidence.clientResumeObserved,
        lastObservedStatus=evidence.lastObservedStatus,
        authorizesOffer=false,authorizesAccept=false,
        serverCompletionProven=false,mayReportProfit=false,
        maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
    }
end
local last=statusRecord("LOADING","P3_DEFAULT_CLOSED")
local function clipboard(r)
    local obj=statusRecord(r.status,r.reason)
    local http=game:GetService("HttpService")
    local ok,json=pcall(function()return http:JSONEncode(obj)end)
    if not ok or type(json)~="string" then
        warn("[P3 NATIVE] Result serialization unavailable")
        return false
    end
    E.PDIDDLER_SUPERVISED_P3_LAST_JSON=json
    local fn=type(setclipboard)=="function" and setclipboard
      or type(toclipboard)=="function" and toclipboard
      or type(E.setclipboard)=="function" and E.setclipboard
      or nil
    local copied=false
    if fn then
        local a,b=pcall(fn,json)
        copied=a and b~=false
    end
    print("[P3 NATIVE RESULT JSON] "..json)
    return copied
end
local ui={}
local made=pcall(function()
    ui.screen=Instance.new("ScreenGui")
    ui.screen.Name="PDIDDLER_P3_ExplicitArm"
    ui.screen.ResetOnSpawn=false
    ui.screen.IgnoreGuiInset=true
    ui.screen.DisplayOrder=150
    ui.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    ui.screen.Parent=PG
    ui.panel=Instance.new("Frame")
    ui.panel.Name="LiveStatus"
    ui.panel.BackgroundColor3=Color3.fromRGB(28,23,40)
    ui.panel.BorderSizePixel=0
    ui.panel.Active=false
    ui.panel.Visible=false
    ui.panel.Parent=ui.screen
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(177,128,239)
    stroke.Thickness=1
    stroke.Parent=ui.panel
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=ui.panel
    local function label(n,y,h,size)
        local q=Instance.new("TextLabel")
        q.Name=n
        q.BackgroundTransparency=1
        q.TextColor3=Color3.fromRGB(255,255,255)
        q.TextSize=size
        q.TextWrapped=true
        q.TextXAlignment=Enum.TextXAlignment.Left
        q.Font=Enum.Font.GothamBold
        q.Position=UDim2.fromOffset(12,y)
        q.Size=UDim2.fromOffset(280,h)
        q.Parent=ui.panel
        return q
    end
    ui.title=label("CurrentStep",7,24,14)
    ui.body=label("WhatToDo",32,52,12)
    ui.warning=label("Safety",90,18,11)
    ui.warning.Text="NO FINAL ACCEPT | 1 AUTO ITEM ONLY"
    local function action(n,text,x)
        local q=Instance.new("TextButton")
        q.Name=n
        q.Text=text
        q.TextSize=13
        q.TextColor3=Color3.fromRGB(255,255,255)
        q.BackgroundColor3=Color3.fromRGB(88,55,129)
        q.Position=UDim2.fromOffset(x,111)
        q.Size=UDim2.fromOffset(128,28)
        q.Parent=ui.panel
        q.Active=false
        q.Visible=false
        return q
    end
    ui.arm=action("ArmP3","ARM P3",12)
    ui.stop=action("StopP3","STOP / COPY",164)
    -- No extra on-trade button: consent came from the preceding owned picker.
    -- The only in-game action here is ARM P3 after reading the warning.
end)
if not made then
    E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER=nil
    if ui.screen then pcall(function()ui.screen:Destroy()end) end
    warn("[P3 NATIVE] GUI construction failed; no P3 requested")
    return nil
end
local guide={stopped=false,phase="PREPARED",layoutFailures=0}
local armed=false
local offerBusy=false
local offerSpent=false
local pilot=nil
local autoGate=nil
local watcher=nil
local supervisor=nil
local function visibleTrade()
    local roots={}
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local g=PG:FindFirstChild(name)
        local container=g and g:FindFirstChild("Container")
        local t=container and container:FindFirstChild("Trade")
        if g and g.Enabled==true and container
           and container.Visible==true and t and t.Visible==true then
            roots[#roots+1]=t
        end
    end
    if #roots>1 then return nil,"MULTIPLE_TRADE_ROOTS" end
    return roots[1],nil
end
function guide:refresh()
    if self.stopped or not owner.running or
      ui.screen.Parent~=PG or ui.panel.Parent~=ui.screen then
        return false,"GUIDE_REMOVED_OR_STOPPED"
    end
    local camera=World.CurrentCamera
    if not camera then return false,"CAMERA_MISSING" end
    local ok,v=pcall(function()return camera.ViewportSize end)
    if not ok or not v then return false,"VIEWPORT_UNAVAILABLE" end
    local trade,err=visibleTrade()
    if err then return false,err end
    local bounds=nil
    if trade then
        local good,p,sz=pcall(function()
            return trade.AbsolutePosition,trade.AbsoluteSize
        end)
        if not good or not p or not sz then
           return false,"TRADE_BOUNDS_MISSING"
        end
        bounds={x=p.X,y=p.Y,w=sz.X,h=sz.Y}
    end
    local pos,why=geometry.choose(
        {x=v.X,y=v.Y},bounds,{w=304,h=148})
    if not pos then return false,why end
    local laid=pcall(function()
        ui.panel.Position=UDim2.fromOffset(pos.x,pos.y)
        ui.panel.Size=UDim2.fromOffset(pos.w,pos.h)
        ui.panel.Visible=true
    end)
    if not laid then return false,"PANEL_LAYOUT_FAILED" end
    return true,"NONOVERLAPPING_P3_PANEL"
end
function guide:show(r)
    local ok,why=self:refresh()
    if not ok then
        self.layoutFailures+=1
        ui.panel.Visible=false
        error("P3_GUIDE_"..tostring(why))
    end
    local status=r.status or "UNKNOWN"
    self.phase=status
    local ap=altGuide.current().phase
    if ap=="WAIT_ALT_ADD" then
        ui.title.Text="3/5 ALT — ADD ONE WEAPON"
        ui.body.Text="ALT: manually ADD 1 cheap weapon. MAIN: do nothing. Wait for step 4/5. NO final Accept."
    elseif ap=="WAIT_ALT_REMOVE" then
        ui.title.Text="4/5 ALT — REMOVE SAME WEAPON"
        ui.body.Text="ALT: manually REMOVE the same weapon. MAIN: do nothing. Wait for step 5/5. NO final Accept."
    elseif ap=="READY_MANUAL_DECLINE" then
        ui.title.Text="5/5 MAIN — MANUALLY DECLINE"
        ui.body.Text="MAIN: manually DECLINE trade, then STOP / COPY. NEVER final Accept."
    elseif ap=="BLOCKED" then
        ui.title.Text="ALT TEST STOPPED — INCONCLUSIVE"
        ui.body.Text="Test incomplete. MAIN: manually DECLINE if safe, then STOP / COPY. No retry in this server."
    elseif status=="P3_SUPERVISOR_PREPARED_NOT_ARMED" then
        ui.title.Text="1/5 MAIN — ARM REAL P3"
        ui.body.Text="MAIN: "..cfg.approvedDisplayName..
            " will AUTO OFFER ONCE to your ALT. Tap ARM to allow that one offer. No final Accept."
    elseif status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
        ui.title.Text="2/5 MAIN — AUTO OFFER ONCE"
        ui.body.TextSize=11
        if offerSpent and not offerBusy then
            ui.body.Text="MAIN: wait for guarded placement confirmation. Then the guide will show 3/5 ALT ADD. Never final Accept."
        elseif offerBusy then
            ui.body.Text="Checking approved own weapon and P4 slot. No final Accept."
        else
            ui.body.Text="Waiting for stable ALT P4 session, then auto-offering "..cfg.approvedDisplayName.." x1."
        end
    else
        ui.title.Text="MAIN — WATCHING SAFE P3/P4"
        ui.body.Text="Status: "..tostring(status)..
           ". MAIN: STOP/COPY if needed. Final Accept OFF."
    end
    ui.arm.Visible=not armed and
        watcher~=nil and watcher.isReady()
    ui.arm.Active=ui.arm.Visible
    ui.stop.Visible=true
    ui.stop.Active=true
end
local function stop(reason)
    if not owner.running then return false end
    owner.running=false
    if autoGate then pcall(autoGate.stop) end
    if altGuide then pcall(altGuide.stop) end
    if watcher then pcall(watcher.stop) end
    if supervisor then pcall(supervisor.stop) end
    local r=statusRecord("STOPPED",reason or "OPERATOR_STOPPED")
    last=r
    clipboard(r)
    pcall(function()ui.screen:Destroy()end)
    E.PDIDDLER_SUPERVISED_P3_USED_JOB=game.JobId
    E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_USED_JOB=game.JobId
    E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB=game.JobId
    E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER=nil
    return true
end
ui.stop.Activated:Connect(function()
    stop("OPERATOR_STOPPED")
end)
-- Hide original scanner's large GUI: do not obscure MM2 trade controls.
local function suppressLegacyScannerGUI()
    local roots={PG,game:GetService("CoreGui")}
    if type(gethui)=="function" then
        local ok,h=pcall(gethui)
        if ok and h then roots[#roots+1]=h end
    end
    for _,root in ipairs(roots) do
        local gui=root and root:FindFirstChild("MM2EligibilityScannerT41")
        if gui and gui:IsA("ScreenGui") then gui.Enabled=false end
    end
end
local rawScanner=loadFrozen("2036ae5bd937620f21d46600f99550a1b233a654",
     "pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua")
if not rawScanner or type(rawScanner.getRecord)~="function"
    or type(rawScanner.getWhitelist)~="function"
    or type(rawScanner.isWhitelisted)~="function" then
    stop("ORIGINAL_SCANNER_UNAVAILABLE")
    return nil
end
-- The original scanner can read server eligibility but the actual P3
-- outgoing queue receives ONLY the chosen consenting ALT. Even eligible
-- strangers cannot enter the request queue in this FIRST native test.
local scanner=setmetatable({},{__index=rawScanner})
function scanner.isWhitelisted(uid)
    if uid~=targetUid or not targetStillExact() then return false end
    local ok,v=pcall(rawScanner.isWhitelisted,uid)
    return ok and v==true
end
function scanner.getRecord(uid)
    if not scanner.isWhitelisted(uid) then return nil end
    local ok,record=pcall(rawScanner.getRecord,uid)
    if not ok or type(record)~="table" or
       record.player~=target or record.state~="whitelist" then
        return nil
    end
    return record
end
function scanner.getWhitelist()
    if not targetStillExact() then return {} end
    local ok,list=pcall(rawScanner.getWhitelist)
    if not ok or type(list)~="table" then return {} end
    for _,p in ipairs(list) do
       if p==target and scanner.getRecord(targetUid) then
           return {target}
       end
    end
    return {}
end
suppressLegacyScannerGUI()
local gate={}
local okIO,io=pcall(ioModule.new,{
  resolveOfferEntry=function()return nil end
},gate)
if not okIO or type(io)~="table" then
    stop("PROTECTED_TRADEIO_UNAVAILABLE")
    return nil
end
local function stillLive()
    return owner.running and E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER==owner
       and game.JobId==owner.job and LP.Parent==Players
       and LP:FindFirstChildOfClass("PlayerGui")==PG
       and ui.screen.Parent==PG
end
local ctx={
    getJobId=function()return game.JobId end,
    getP3Session=function()return E.PDIDDLER_OUTGOING_SESSION end,
    onScreenSafe=function()
        local ok,safe=pcall(guide.refresh,guide)
        return ok and safe==true
    end,
    watchdogReady=function()
        return watcher~=nil and watcher.isReady()==true
    end,
    noOtherTransactionOwner=function()
        return not E.PDIDDLER_PART4_SESSION and
          E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE~=true and
          E.PDIDDLER_PART4_CONTROLLER_ACTIVE~=true and
          E.PDIDDLER_AUTOTRADE_ACTIVE~=true
    end,
    readyCheck=function()
        local ok,a=pcall(scanner.getWhitelist)
        return ok and type(a)=="table" and
           targetStillExact() and stillLive()
    end,
}
local sup,why=bootModule.new(scanner,outgoingModule,coordinator,
    bridge,io,Players,LP,ctx)
if not sup then
    stop(type(why)=="table" and why.reason or "ATOMIC_SUPERVISOR_NOT_AVAILABLE")
    return nil
end
supervisor=sup
local newPilot,whyPilot=operatorModule.new(
    supervisor,io,gate,planModule,rawScanner,cfg,{
        isSafe=function()
            return stillLive() and watcher~=nil and
                watcher.isReady()==true and guide:refresh()==true
        end,
        altStillExact=targetStillExact,
        showItemStep=function(raw,shown,chroma)
            if not stillLive() or not offerBusy or
                raw~=cfg.approvedRawKey or
                shown~=cfg.approvedDisplayName or
                chroma~=cfg.approvedChromaFlag then return false end
            local safe=guide:refresh()
            if safe~=true then return false end
            ui.title.Text="MAIN — OFFERING APPROVED ITEM"
            ui.body.Text="MAIN: "..shown.." (raw "..raw..
                ") x1 being confirmed. ALT: do not change. Never final Accept."
            return true
        end,
        wait=function(seconds)task.wait(seconds)end,
    })
if not newPilot then
    stop(type(whyPilot)=="table" and whyPilot.reason
        or "ONE_ITEM_OPERATOR_NOT_AVAILABLE")
    return nil
end
pilot=newPilot
-- A prior real human choice and ARM consent are strictly separate.
-- A stable, same-root original P3/P4 ALT session may trigger once.
local auto,autoWhy=autoModule.new(pilot,cfg.autoConsent,{
    getJobId=function()return game.JobId end,
    now=function()return os.clock()end,
    isLive=stillLive,
    isArmed=function()return armed and supervisor~=nil
        and supervisor.isP3Paused()==true end,
    isExactAlt=function(id)return id==targetUid and targetStillExact()end,
    getTradeRoot=function()return io.trade()end,
    onTrigger=function(raw,display,chroma,root)
        if offerBusy or offerSpent or not stillLive() or
          not watcher or not watcher.isReady() or
          not armed or io.trade()~=root or
          raw~=cfg.approvedRawKey or display~=cfg.approvedDisplayName
          or chroma~=cfg.approvedChromaFlag then return false end
        -- Spend before any yielding / running of owned-profile RPC.
        offerBusy=true
        offerSpent=true
        evidence.autoOfferTriggeredClient=true
        E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB=game.JobId
        task.spawn(function()
            -- The original PR216 operator requires an explicit approval
            -- argument. Here true derives ONLY from the prior physical
            -- picker "AUTHORIZE ONE AUTO OFFER" tap and this current
            -- exact ALT stable P3/P4 session. The base operator still
            -- performs its own fresh ownership and lease checks.
            local good,receipt=pcall(pilot.execute,true)
            offerBusy=false
            evidence.oneItemOfferStatus=good and type(receipt)=="table"
                and tostring(receipt.status or "INCONCLUSIVE")
                or "INCONCLUSIVE"
            if good and type(receipt)=="table" then
                if type(receipt.snapshotRejectReason)=="string" and
                    receipt.snapshotRejectReason:match("^[A-Z_]+$") and
                    #receipt.snapshotRejectReason<=72 then
                    evidence.oneItemSnapshotRejectReason=receipt.snapshotRejectReason
                end
                if type(receipt.offerAttempts)=="number" then
                    evidence.oneItemOfferAttempts=receipt.offerAttempts
                else
                    evidence.oneItemOfferAttempts=nil
                    evidence.offerAttemptsKnown=false
                end
                if type(receipt.clientVisibleAddedSlots)=="number" then
                    evidence.clientVisibleAddedSlots=receipt.clientVisibleAddedSlots
                else
                    evidence.clientVisibleAddedSlots=nil
                end
            else
                evidence.oneItemOfferAttempts=nil
                evidence.clientVisibleAddedSlots=nil
                evidence.offerAttemptsKnown=false
            end
            evidence.lastObservedStatus=evidence.oneItemOfferStatus
            last=statusRecord(evidence.oneItemOfferStatus,
              good and type(receipt)=="table" and
              tostring(receipt.reason or "UNKNOWN")
              or "AUTO_ONE_ITEM_OPERATOR_THROWN_AFTER_POSSIBLE_SEND")
            clipboard(last)
            pcall(guide.show,guide,last)
        end)
        return true
    end,
})
if not auto then
    stop(type(autoWhy)=="table" and autoWhy.reason or
       "AUTO_ONE_ITEM_PRIOR_CONSENT_REJECTED")
    return nil
end
autoGate=auto
local watchdogCtx={
    getJobId=ctx.getJobId,
    isLive=stillLive,
    onStatus=function(r)
        -- Capture prior completion BEFORE this callback may synchronously run
        -- the auto one-shot send. The r slot snapshot was captured on entry:
        -- never compare it against an item placed later in this same tick.
        local offerConfirmedAtTickStart=
            evidence.autoOfferTriggeredClient==true
            and evidence.oneItemOfferStatus=="CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED"
            and evidence.oneItemOfferAttempts==1
            and evidence.clientVisibleAddedSlots==1
        if r.status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
            evidence.clientTradeWindowObserved=true
        elseif r.status=="P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED" then
            evidence.clientResumeObserved=true
        end
        evidence.lastObservedStatus=tostring(r.status or "UNKNOWN")
        last=statusRecord(r.status,r.reason)
        local ok=pcall(guide.show,guide,last)
        if not ok then
            last=statusRecord("BLOCKED","ONSCREEN_P3_GUIDE_UNAVAILABLE")
            clipboard(last)
            error("P3 on-screen guide failed")
        end
        suppressLegacyScannerGUI()
        if autoGate then
            local good,a=pcall(autoGate.observe,r.status)
            if not good or type(a)~="table" then
                last=statusRecord("BLOCKED","AUTO_ONE_SHOT_GATE_OBSERVER_FAILED")
                clipboard(last)
                error("preauthorized one-shot gate failed")
            end
            if a.status=="BLOCKED" or a.status=="INCONCLUSIVE" then
                last=statusRecord(a.status,a.reason)
                clipboard(last)
            end
        end
        -- NEW distinct test: following the original one-shot placement, track
        -- independent protected P4 physical client slots on every watchdog tick.
        -- Never credit ALT actions merely because the runner displayed a step.
        local guideOK,clientStep=pcall(altGuide.observe,{
            now=os.clock(),
            status=r.status,
            clientBound=r.status=="P4_TWO_SIDED_CLIENT_SNAPSHOT"
                and supervisor~=nil and supervisor.isP3Paused()==true
                and targetStillExact(),
            root=io.trade(),
            ownSlots=r.ownPhysicalSlots,
            theirSlots=r.theirPhysicalSlots,
            oneShotComplete=offerConfirmedAtTickStart,
        })
        if not guideOK or type(clientStep)~="table" then
            last=statusRecord("INCONCLUSIVE","ALT_GUI_WITNESS_THROWN")
            clipboard(last)
            error("ALT client guide failed closed")
        end
        if clientStep.phase=="BLOCKED" then
            last=statusRecord("INCONCLUSIVE",clientStep.reason)
            clipboard(last)
        end
        local shown=pcall(guide.show,guide,last)
        if not shown then
            last=statusRecord("INCONCLUSIVE","ALT_STEP_PANEL_UNSAFE")
            clipboard(last)
            error("ALT guide must not cover trade")
        end
        if r.status=="BLOCKED" then clipboard(last) end
    end,
}
local monitor,whyMonitor=watchdogModule.new(
    supervisor,{
       isPaused=function()return supervisor.isP3Paused()end,
    },io,watchdogCtx,{
       spawn=function(fn)task.spawn(fn)end,
       wait=function(seconds)task.wait(seconds)end,
       now=function()return os.clock()end,
    })
if not monitor then
    stop(type(whyMonitor)=="table" and whyMonitor.reason
        or "WATCHDOG_CONSTRUCTION_FAILED")
    return nil
end
watcher=monitor
ui.arm.Activated:Connect(function()
    if not stillLive() or armed or not watcher.isReady()
        or not autoGate or autoGate.isSpent() then return end
    local safe=ctx.onScreenSafe()
    if not safe or io.trade()~=nil then return end
    -- The only transition enabling REAL original P3 outgoing requests:
    -- one explicit, actual user tap on this safe on-screen ARM button.
    local success,reason=supervisor.arm({
        explicitUserAuthorization=true,
        allowRealP3RequestRotation=true,
        finalAcceptMustRemainManual=true,
    })
    if success==true then
        armed=true
        evidence.p3ArmObservedClient=true
        evidence.lastObservedStatus="P3_ARMED_BY_OPERATOR"
        E.PDIDDLER_SUPERVISED_P3_USED_JOB=game.JobId
        last=statusRecord("P3_ARMED_BY_OPERATOR",
             "P3_REQUESTS_ENABLED_NO_FINAL_ACCEPT")
        pcall(guide.show,guide,last)
    else
        last=statusRecord("BLOCKED",reason or "P3_ARM_REFUSED")
        pcall(guide.show,guide,last)
    end
end)
local started,startReason=watcher.start()
if started~=true then
    stop(startReason or "WATCHDOG_NOT_SCHEDULED")
    return nil
end
E.PDIDDLER_SUPERVISED_P3_RUNNER={
    stop=function()return stop("OPERATOR_STOPPED")end,
    status=function()return statusRecord(last.status,last.reason)end,
    isArmed=function()return armed and owner.running end,
}
print("[P3 AUTO ONE] Human-approved selected weapon will be offered ONCE after exact ALT P4 trade opens. Tap ARM P3; final Accept OFF.")
return E.PDIDDLER_SUPERVISED_P3_RUNNER
