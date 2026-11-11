-- Original MM2 native PR219 Stage101 raw weapon candidate witness.
-- Separate from the PROVEN P3-only and auto-offer runners; originals unchanged.
-- ARM P3 may send ONE ALT-only trade REQUEST after physical human approval.
-- MAIN & ALT must MANUALLY add one low-value eligible weapon each.
-- This diagnostic NEVER sends OfferItem/Accept/Decline, no price or Discord.
-- Display names and raw client UpdateTrade are NOT server-authenticated.
-- Does not prove item transfer, transaction nonce or completed trade.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE"
local cfg=E[KEY]
if game.PlaceId~=142823291 or type(cfg)~="table"
    or cfg.enableNativeSupervisor~=true
    or cfg.finalAcceptMustRemainManual~=true
    or cfg.altOnlyTest~=true
    or cfg.stage119LastOfferReadOnly~=true
    or type(cfg.targetName)~="string" or
       #cfg.targetName<3 or #cfg.targetName>32 or
       not cfg.targetName:match("^[A-Za-z0-9_]+$") then
    warn("[P3 NATIVE] Original MM2 and explicit configuration required")
    return nil
end
if E.PDIDDLER_SUPERVISED_P3_USED_JOB==game.JobId
    or E.PDIDDLER_STAGE101_IDENTITY_USED_JOB==game.JobId
    or E.PDIDDLER_STAGE119_P3_USED_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB==game.JobId
    or E.PDIDDLER_P3_OWNED_PICKER_USED_JOB==game.JobId
    or E.PDIDDLER_P3_AUTO_OWNED_PICKER_USED_JOB==game.JobId
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
local stage9Contract=loadFrozen("1971b93d324f0275e6a9affb472ac3e804439ed8",
    "new_part4/p4_observer_contract.lua")
local stage9Native=loadFrozen("1971b93d324f0275e6a9affb472ac3e804439ed8",
    "new_part4/p4_native_observer.lua")
local lastOfferModule=loadFrozen("7c12a2e9768ef294b411086deef9ddaf2bee8d21",
    "intelligence_lab/trade_lastoffer_client_audit.lua")
local stage118=loadFrozen("891d548d2ef77763e9f7e3a679984a646bb9d4b4",
    "intelligence_lab/stage118_lastoffer_gui_correlation.lua")
if not geometry or type(geometry.choose)~="function"
    or not ioModule or type(ioModule.new)~="function"
    or not bridge or type(bridge.bind)~="function"
    or not coordinator or type(coordinator.new)~="function"
    or not outgoingModule or type(outgoingModule.run)~="function"
    or not bootModule or type(bootModule.new)~="function"
    or not watchdogModule or type(watchdogModule.new)~="function"
    or not stage9Contract or type(stage9Contract.normalize)~="function"
    or type(stage9Contract.parseQuantity)~="function"
    or not stage9Native or type(stage9Native.new)~="function"
    or type(stage9Native.capture)~="function"
    or not lastOfferModule or type(lastOfferModule.new)~="function"
    or not stage118 or type(stage118.new)~="function" then
    warn("[P3 NATIVE] Immutable source unavailable: P3 remains disabled")
    return nil
end
local owner={job=game.JobId,running=true}
E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER=owner
-- Client-observed milestones are sticky even after terminal STOP.
-- These do NOT authenticate a network-delivered request or any settlement.
local evidence={
    p3ArmObservedClient=false,
    clientTradeWindowObserved=false,clientResumeObserved=false,
    lastObservedStatus="NONE",clientLastOfferStatus="NOT_STARTED",
    clientLastOfferReason="NOT_STARTED",
    lastOfferEqualityClass="NONE",
    callbackCount=0,guiQuantityTransitions=0,
    clientGuiQuantityCrossChecked=false,
    clientGuiCrossChecked=false,
    protectedP3P4LeaseCrossChecked=false
}
local function statusRecord(status,reason)
    return {
        schema="gingerscope-stage119-protected-p3-lastoffer-native-v2",
        status=tostring(status or "UNKNOWN"),
        reason=tostring(reason or "UNKNOWN"),
        p3ArmObservedClient=evidence.p3ArmObservedClient,
        clientTradeWindowObserved=evidence.clientTradeWindowObserved,
        clientResumeObserved=evidence.clientResumeObserved,
        lastObservedStatus=evidence.lastObservedStatus,
        clientLastOfferStatus=evidence.clientLastOfferStatus,
        clientLastOfferReason=evidence.clientLastOfferReason,
        lastOfferEqualityClass=evidence.lastOfferEqualityClass,
        callbackCount=evidence.callbackCount,
        guiQuantityTransitions=evidence.guiQuantityTransitions,
        clientGuiQuantityCrossChecked=evidence.clientGuiQuantityCrossChecked,
        clientGuiCrossChecked=false,
        protectedP3P4LeaseCrossChecked=evidence.protectedP3P4LeaseCrossChecked,
        rawItemIdConfirmed=false,
        eventSessionAssociationProven=false,callbackCausalityProven=false,
        serverTradeRevisionProven=false,uniqueWeaponInstanceProven=false,
        readOnly=true,clientOnly=true,
        actualOffers=0,actualAccepts=0,actualDeclines=0,
        actualTeleports=0,
        authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
        serverCompletionProven=false,mayReportProfit=false,
        maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
        tradeOutcome="UNKNOWN",
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
    ui.screen.Name="PDIDDLER_P3_STAGE101_ReadonlyIdentity"
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
    ui.warning.Text="READ ONLY | NEVER FINAL ACCEPT"
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
end)
if not made then
    E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER=nil
    if ui.screen then pcall(function()ui.screen:Destroy()end) end
    warn("[P3 NATIVE] GUI construction failed; no P3 requested")
    return nil
end
local guide={stopped=false,phase="PREPARED",layoutFailures=0}
local armed=false
local watcher=nil
local supervisor=nil
local identityPhase="BEFORE_ARM"
local identityWitness=nil
local stage9Handle=nil
local eventConnection=nil
local baselineSig=nil
local baselineAt=nil
local boundScope=nil
local currentStage9Raw=nil
local terminalResult=false
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
    if identityPhase=="RESULT" or identityPhase=="FAILED" then
        ui.title.Text=identityPhase=="RESULT"
             and "5/5 CLIENT LASTOFFER OBSERVED" or "5/5 CLIENT LASTOFFER INCONCLUSIVE"
        ui.body.Text="MAIN: manually DECLINE the trade, then tap STOP / COPY. NEVER final Accept."
    elseif identityPhase=="WAIT_ALT_REMOVE" or identityPhase=="WAIT_REMOVE_GUI" then
        ui.title.Text="4/5 ALT — REMOVE THAT WEAPON"
        ui.body.Text="ALT: manually REMOVE the same weapon. MAIN stays EMPTY. Wait for result."
    elseif identityPhase=="WAIT_ALT_ADD" or identityPhase=="WAIT_ADD_GUI" then
        ui.title.Text="3/5 ALT — ADD ONE WEAPON"
        ui.body.Text="ALT: manually ADD ONE inexpensive eligible weapon NOW. MAIN stays EMPTY."
    elseif status=="P3_SUPERVISOR_PREPARED_NOT_ARMED" then
        ui.title.Text="1/5 MAIN — ARM P3"
        ui.body.Text="MAIN: tap ARM P3 to request only your ALT. No item will be automatically offered."
    elseif identityPhase=="WAIT_EMPTY" or identityPhase=="WAIT_EMPTY_STABLE" then
        ui.title.Text="2/5 ALT — ACCEPT REQUEST"
        ui.body.Text="ALT: manually ACCEPT the P3 trade REQUEST. Keep BOTH offers EMPTY."
    else
        ui.title.Text="PROTECTED P3/P4 LASTOFFER"
        ui.body.Text="Waiting for original protected trade. Never press final Accept."
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
    if eventConnection then pcall(function()eventConnection:Disconnect()end) end
    eventConnection=nil
    if identityWitness then pcall(identityWitness.stop) end
    if watcher then pcall(watcher.stop) end
    if supervisor then pcall(supervisor.stop) end
    local r=statusRecord("STOPPED",reason or "OPERATOR_STOPPED")
    last=r
    clipboard(r)
    pcall(function()ui.screen:Destroy()end)
    E.PDIDDLER_SUPERVISED_P3_USED_JOB=game.JobId
    E.PDIDDLER_STAGE119_P3_USED_JOB=game.JobId
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
-- All identity tests need the PR215 read-only lease. The previous pinned
-- frozen P3 supervisor did not expose currentBoundReadOnly() at all,
-- while offline mocks silently used the newer local source. Refuse at
-- STARTUP rather than letting MAIN/ALT manually reach the trade window
-- and fail after placing their real weapons.
if type(supervisor.currentBoundReadOnly)~="function" then
    stop("FROZEN_P3_BOUND_LEASE_INTERFACE_MISSING")
    return nil
end

-- Separate observational state machine. The only outgoing P3 operation is
-- the existing explicitly ARM-ed request to the exact consenting ALT.
-- No OfferItem/Accept/Decline method is reachable from this observer.
local function completeIdentity(status,reason,report)
    if terminalResult then return end
    terminalResult=true
    identityPhase=status=="CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED"
        and "RESULT" or "FAILED"
    evidence.clientLastOfferStatus=status
    evidence.clientLastOfferReason=reason or "CLIENT_EVIDENCE_UNATTRIBUTED"
    if type(report)=="table" then
        evidence.lastOfferEqualityClass=tostring(report.lastOfferEqualityClass or "NONE")
        evidence.callbackCount=math.min(2,tonumber(report.callbackCount) or 0)
        evidence.guiQuantityTransitions=math.min(2,tonumber(report.localGuiTransitions) or 0)
        evidence.clientGuiQuantityCrossChecked=report.clientGuiQuantityCrossChecked==true
    end
    if eventConnection then
        pcall(function()eventConnection:Disconnect()end)
        eventConnection=nil
    end
    if identityWitness then pcall(identityWitness.stop) end
    if watcher then pcall(watcher.stop) end
    last=statusRecord("CLIENT_LASTOFFER_RESULT",evidence.clientLastOfferReason)
    clipboard(last)
    -- Continue refreshing the STOP / COPY panel after the protected watcher
    -- has stopped; never leave a stale panel covering moved Accept/Decline UI.
    task.spawn(function()
        while owner.running and terminalResult do
            local safe,ok=pcall(guide.refresh,guide)
            if not safe or ok~=true then
                pcall(function()ui.panel.Visible=false end)
                clipboard(statusRecord("INCONCLUSIVE","FINAL_GUIDE_NO_SAFE_SPACE"))
                break
            end
            task.wait(0.1)
        end
    end)
end

local function exactUpdateTradeRemote()
    local RS=game:GetService("ReplicatedStorage")
    local trade=RS:FindFirstChild("Trade")
    if not trade then return nil end
    local good,nodes=pcall(function()return trade:GetDescendants()end)
    if not good or type(nodes)~="table" or #nodes>12000 then return nil end
    local match,count=nil,0
    for _,node in ipairs(nodes) do
        if node.Name=="UpdateTrade" and node:IsA("RemoteEvent") then
            match=node
            count+=1
        end
    end
    return count==1 and match or nil
end

-- Original PR219 independent Stage9 versus protected P4 physical comparison.
local function norm(s)
 if type(s)~="string" or #s<1 then return nil end
 return s:lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
end
local function natural(x,lo,hi)
 return type(x)=="number" and x==math.floor(x) and x>=lo and x<=hi
end
local function verifyPhysical(side,entries,parser)
 if type(side)~="table" or side.complete~=true or
    side.accepted~=false or type(side.slots)~="table" or
    type(entries)~="table" or
    #side.slots~=#entries or #entries>4 then return false end
 local observed={}
 for _,row in ipairs(entries) do
  if type(row)~="table" or not natural(row.physicalSlot,1,4)
    or observed[row.physicalSlot] or not natural(row.quantity,1,4)
    or not norm(row.displayCandidate) or
    type(row.chromaCandidate)~="boolean" or
    row.rawItemIdAuthenticated~=false then return false end
  observed[row.physicalSlot]=row
 end
 local seen={}
 for _,slot in ipairs(side.slots) do
  if type(slot)~="table" or not natural(slot.slot,1,4) or
     seen[slot.slot] or type(slot.chroma)~="boolean" or
     not norm(slot.label) then return false end
  seen[slot.slot]=true
  local row=observed[slot.slot]
  local okQty,qty=pcall(parser,slot.amountText)
  if not row or not okQty or qty~=row.quantity or
    slot.chroma~=row.chromaCandidate or
    norm(slot.label)~=norm(row.displayCandidate) then return false end
 end
 return true
end

local function prepareWitness(root)
 if not owner.running or not watcher or not watcher.isReady() or
   not armed or io.trade()~=root or supervisor.isP3Paused()~=true or
   not targetStillExact() then
  return false,"P3_EXACT_PAUSED_TRADE_UNAVAILABLE"
 end
 local epoch=E.PDIDDLER_OUTGOING_SESSION
 if type(epoch)~="number" or epoch~=math.floor(epoch) or epoch<1 then
  return false,"P3_NATIVE_EPOCH_UNAVAILABLE"
 end
 local remote=exactUpdateTradeRemote()
 if not remote then return false,"UNIQUE_UPDATE_TRADE_UNAVAILABLE" end
 local exactJob=tostring(game.JobId)
 boundScope={jobId=exactJob,session="p3stage119:"..tostring(epoch),
   root=root,localPlayer=LP,partnerPlayer=target}
 local proxy={normalize=function(raw,_)
   currentStage9Raw=raw
   return stage9Contract.normalize(raw,{marketFresh=false})
 end}
 local good,handle=pcall(stage9Native.new,{
   game=game,players=Players,root=root,session=boundScope.session,
   jobId=exactJob,partnerUserId=targetUid,localUserId=LP.UserId,
   contract=proxy,ownInventory=nil,opponentInventory=nil,
   marketFresh=function()return false end
 })
 if not good or type(handle)~="table" then
  return false,"ORIGINAL_STAGE9_NATIVE_OBSERVER_UNAVAILABLE"
 end
 stage9Handle=handle
 local function currentProtected()
  if not stillLive() or not targetStillExact() or
    io.trade()~=root or E.PDIDDLER_OUTGOING_SESSION~=epoch or
    supervisor.isP3Paused()~=true or not watcher.isReady() then
   return nil,"PROTECTED_P3_P4_BOUND_SCOPE_LOST"
  end
  local ok,lease,meta=pcall(supervisor.currentBoundReadOnly)
  if not ok or type(lease)~="table" or type(lease.capture)~="function" or
     type(meta)~="table" or
     meta.status~="P3_BOUND_CANDIDATE_READ_ONLY" or
     meta.authorizesOffer~=false or meta.authorizesAccept~=false then
   return nil,"PROTECTED_P3_P4_BOUND_LEASE_UNAVAILABLE"
  end
  local yes,snap=pcall(lease.capture)
  if not yes or type(snap)~="table" or
    snap.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" or
    snap.partnerExactClientBound~=true or
    snap.part3Paused~=true or snap.part4TradeVisible~=true or
    snap.authorizesOffer~=false or snap.authorizesAccept~=false or
    snap.rawItemIdsAuthenticated~=false or
    snap.serverCompletionProven~=false or
    snap.tradeOutcome~="UNKNOWN" or
    type(snap.ours)~="table" or type(snap.theirs)~="table" then
   return nil,"PROTECTED_P3_P4_SNAPSHOT_UNVERIFIED"
  end
  return snap,nil
 end
 local function capture()
  local snap,why=currentProtected()
  if not snap then return nil,why end
  currentStage9Raw=nil
  local ok,out,diag=pcall(stage9Native.capture,stage9Handle)
  if not ok or type(out)~="table" or type(diag)~="table" or
     out.tradeOpen~=true or out.session~=boundScope.session or
     out.quoteSafe~=false or diag.authorizesTrade~=false or
     diag.authorizesAccept~=false or
     type(currentStage9Raw)~="table" or
     currentStage9Raw.tradeOpen~=true or
     currentStage9Raw.contextOK~=true or
     currentStage9Raw.session~=boundScope.session or
     not verifyPhysical(currentStage9Raw.our,snap.ours,stage9Contract.parseQuantity) or
     not verifyPhysical(currentStage9Raw.their,snap.theirs,stage9Contract.parseQuantity) then
   return nil,"ORIGINAL_STAGE9_PROTECTED_P4_GUI_DISAGREEMENT"
  end
  evidence.protectedP3P4LeaseCrossChecked=true
  return {jobId=exactJob,session=boundScope.session,root=root,
    localPlayer=LP,partnerPlayer=target,raw=currentStage9Raw}
 end
 local witness=stage118.new(boundScope,{
   audit=lastOfferModule,stage9=stage9Contract,
   capture=capture,now=function()return os.clock()end,
   isLive=function()
    return stillLive() and targetStillExact() and armed and
      watcher.isReady()==true and supervisor.isP3Paused()==true and
      io.trade()==root and E.PDIDDLER_OUTGOING_SESSION==epoch
   end
 })
 if not witness then return false,"PROTECTED_STAGE118_ADAPTER_UNAVAILABLE" end
 identityWitness=witness
 local r=witness.begin()
 if type(r)~="table" or r.status~="WAITING" or
     r.reason~="EMPTY_GUI_FIRST_READ" then
  return false,type(r)=="table" and tostring(r.reason)
     or "PROTECTED_STAGE118_EMPTY_BASELINE_REFUSED"
 end
 identityPhase="WAIT_EMPTY_STABLE"
 evidence.clientLastOfferStatus="WAITING"
 evidence.clientLastOfferReason="ORIGINAL_BOUND_EMPTY_TRADE_BEFORE_ALT_ADD"
 -- Listener will attach ONLY AFTER original P4/Stage9 empty baseline stabilizes.
 local function attachWhenReady()
  if eventConnection then return true end
  local connected,conn=pcall(function()
   return remote.OnClientEvent:Connect(function(...)
    if terminalResult then return end
    -- Exact original bound P3/P4 MUST be rechecked before each callback.
    local bound,why=currentProtected()
    if not bound then
     completeIdentity("INCONCLUSIVE",why)
     return
    end
    if identityPhase~="WAIT_ALT_ADD" and
       identityPhase~="WAIT_ALT_REMOVE" then
     completeIdentity("INCONCLUSIVE","UNEXPECTED_OR_DUPLICATE_CLIENT_EVENT")
     return
    end
    local pack=table.pack(...)
    if pack.n~=1 then
     completeIdentity("INCONCLUSIVE","CLIENT_CALLBACK_ARGUMENT_SHAPE_UNVERIFIED")
     return
    end
    local good,observed=pcall(identityWitness.onClientEvent,pack[1])
    if not good or type(observed)~="table" or
        observed.status=="INCONCLUSIVE" then
     completeIdentity("INCONCLUSIVE",type(observed)=="table"
         and observed.reason or "CLIENT_LASTOFFER_CALLBACK_REJECTED")
     return
    end
    evidence.callbackCount=math.min(2,tonumber(observed.callbackCount) or 0)
    identityPhase=identityPhase=="WAIT_ALT_ADD"
        and "WAIT_ADD_GUI" or "WAIT_REMOVE_GUI"
   end)
  end)
  if not connected or not conn or
    type(conn.Disconnect)~="function" then
   return false
  end
  eventConnection=conn
  return true
 end
 return true,"PROTECTED_STAGE119_EMPTY_TRADE_WITNESS_READY",attachWhenReady
end

local function witnessTick(observed)
 if terminalResult or not armed then return end
 if observed.status=="P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED" or
    observed.status=="BLOCKED" then
  completeIdentity("INCONCLUSIVE","PROTECTED_P3_TRADE_CLOSED_OR_INVALIDATED")
  return
 end
 if observed.status~="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
  if identityPhase=="WAIT_EMPTY_STABLE" or
     identityPhase=="WAIT_ALT_ADD" or
     identityPhase=="WAIT_ADD_GUI" or
     identityPhase=="WAIT_ALT_REMOVE" or
     identityPhase=="WAIT_REMOVE_GUI" then
   completeIdentity("INCONCLUSIVE","CURRENT_PROTECTED_P4_TRADE_LOST")
  end
  return
 end
 local root=io.trade()
 if not root or not targetStillExact() then
  completeIdentity("INCONCLUSIVE","EXACT_P4_ROOT_OR_ALT_UNAVAILABLE")
  return
 end
 if identityPhase=="WAIT_EMPTY" then
  if observed.ownPhysicalSlots~=0 or observed.theirPhysicalSlots~=0 then
   completeIdentity("INCONCLUSIVE","PROTECTED_INITIAL_TRADE_NOT_EMPTY")
   return
  end
  local ok,why,attach=prepareWitness(root)
  if not ok then completeIdentity("INCONCLUSIVE",why)
  else stage119Attach=attach end
  return
 end
 if identityPhase=="WAIT_EMPTY_STABLE" or identityPhase=="WAIT_ALT_ADD" or
     identityPhase=="WAIT_ADD_GUI" or identityPhase=="WAIT_ALT_REMOVE" or
     identityPhase=="WAIT_REMOVE_GUI" then
  if not identityWitness then
   completeIdentity("INCONCLUSIVE","PROTECTED_STAGE119_WITNESS_UNAVAILABLE")
   return
  end
  local ok,r=pcall(identityWitness.tick)
  if not ok or type(r)~="table" then
   completeIdentity("INCONCLUSIVE","PROTECTED_STAGE119_WITNESS_RUNTIME_ERROR")
   return
  end
  evidence.callbackCount=math.min(2,tonumber(r.callbackCount) or 0)
  evidence.guiQuantityTransitions=math.min(2,tonumber(r.localGuiTransitions) or 0)
  if r.status=="CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED" then
   completeIdentity(r.status,r.reason,r)
  elseif r.status=="INCONCLUSIVE" then
   completeIdentity("INCONCLUSIVE",r.reason)
  elseif r.reason=="ALT_MANUAL_ADD_ONE" then
   if not stage119Attach or stage119Attach()~=true then
    completeIdentity("INCONCLUSIVE","PROTECTED_UPDATE_TRADE_LISTENER_NOT_ATTACHED")
    return
   end
   identityPhase="WAIT_ALT_ADD"
  elseif r.reason=="ALT_MANUAL_REMOVE_ONE" then
   identityPhase="WAIT_ALT_REMOVE"
  end
 end
end

local watchdogCtx={
    getJobId=ctx.getJobId,
    isLive=stillLive,
    onStatus=function(r)
        if r.status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
            evidence.clientTradeWindowObserved=true
        elseif r.status=="P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED" then
            evidence.clientResumeObserved=true
        end
        evidence.lastObservedStatus=tostring(r.status or "UNKNOWN")
        -- Read-only Stage101 identity comparisons are performed after the
        -- protected P3/P4 poll and before presenting the next exact step.
        local okIdentity=pcall(witnessTick,r)
        if not okIdentity then
            completeIdentity("INCONCLUSIVE","STAGE101_WATCHDOG_ADAPTER_FAILURE")
        end
        last=statusRecord(r.status,r.reason)
        local ok=pcall(guide.show,guide,last)
        if not ok then
            last=statusRecord("BLOCKED","ONSCREEN_P3_GUIDE_UNAVAILABLE")
            clipboard(last)
            error("P3 on-screen guide failed")
        end
        suppressLegacyScannerGUI()
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
    if not stillLive() or armed or not watcher.isReady() then return end
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
        identityPhase="WAIT_EMPTY"
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
E.PDIDDLER_STAGE119_P3_RUNNER={
    stop=function()return stop("OPERATOR_STOPPED")end,
    status=function()return statusRecord(last.status,last.reason)end,
    isArmed=function()return armed and owner.running end,
}
print("[P3 STAGE119 READONLY] ARM P3, ALT accept original request with BOTH empty, ALT manually ADD then REMOVE ONE. MAIN never offers. STOP/COPY throughout.")
return E.PDIDDLER_STAGE119_P3_RUNNER
