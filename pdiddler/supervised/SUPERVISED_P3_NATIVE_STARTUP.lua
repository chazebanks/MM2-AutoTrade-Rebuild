-- ORIGINAL MM2, native supervised PART3 activation runner.
-- P3 scanner + real gated outgoing + protected P4 observer + watchdog.
-- THIS RUNNER DOES NOT OFFER ITEMS OR PRESS FINAL ACCEPT.
-- P3 requests can start ONLY AFTER a LIVE human taps ARM P3 in the game.
-- All source dependencies are exact SHA pinned. Never use legacy balancer.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_SUPERVISED_P3_NATIVE"
local cfg=E[KEY]
if game.PlaceId~=142823291 or type(cfg)~="table"
    or cfg.enableNativeSupervisor~=true
    or cfg.finalAcceptMustRemainManual~=true
    or cfg.altOnlyTest~=true
    or type(cfg.targetName)~="string" or
       #cfg.targetName<3 or #cfg.targetName>32 or
       not cfg.targetName:match("^[A-Za-z0-9_]+$") then
    warn("[P3 NATIVE] Original MM2 and explicit configuration required")
    return nil
end
if E.PDIDDLER_SUPERVISED_P3_USED_JOB==game.JobId
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
local coordinator=loadFrozen("dfcfc7d52ce5f9cc64390bb5e28ce79512f1c001",
    "supervised/supervised_real_p3_rotation_handoff.lua")
local outgoingModule=loadFrozen("2036ae5bd937620f21d46600f99550a1b233a654",
    "supervised/pdiddler3_outgoing_START_GATED_v1.lua")
local bootModule=loadFrozen("eed876c67d916d6acee89bb8fdc450e5e397dd9c",
    "supervised/supervised_p3_startup_supervisor.lua")
local watchdogModule=loadFrozen("48c4b0fee594639c74f1bed408581db7a5bc6f1b",
    "supervised/supervised_p3_continuous_watchdog.lua")
if not geometry or type(geometry.choose)~="function"
    or not ioModule or type(ioModule.new)~="function"
    or not bridge or type(bridge.bind)~="function"
    or not coordinator or type(coordinator.new)~="function"
    or not outgoingModule or type(outgoingModule.run)~="function"
    or not bootModule or type(bootModule.new)~="function"
    or not watchdogModule or type(watchdogModule.new)~="function" then
    warn("[P3 NATIVE] Immutable source unavailable: P3 remains disabled")
    return nil
end
local owner={job=game.JobId,running=true}
E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER=owner
local function statusRecord(status,reason)
    return {
        schema="gingerscope-p3-native-rotation-status-v1",
        status=tostring(status or "UNKNOWN"),
        reason=tostring(reason or "UNKNOWN"),
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
    ui.warning.Text="NO FINAL ACCEPT | NO AUTO OFFERS"
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
    if status=="P3_SUPERVISOR_PREPARED_NOT_ARMED" then
        ui.title.Text="1/2 MAIN — ARM REAL P3"
        ui.body.Text="MAIN: tap ARM for one consenting ALT ONLY. ALT: accept request manually. No final Accept."
    elseif status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
        ui.title.Text="2/2 MAIN — TRADE WINDOW OPEN"
        ui.body.Text="MAIN: inspect the open trade, manually Decline to continue. ALT: no action."
    else
        ui.title.Text="2/2 MAIN — P3 OBSERVER"
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
    if watcher then pcall(watcher.stop) end
    if supervisor then pcall(supervisor.stop) end
    local r=statusRecord("STOPPED",reason or "OPERATOR_STOPPED")
    last=r
    clipboard(r)
    pcall(function()ui.screen:Destroy()end)
    E.PDIDDLER_SUPERVISED_P3_USED_JOB=game.JobId
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
local watchdogCtx={
    getJobId=ctx.getJobId,
    isLive=stillLive,
    onStatus=function(r)
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
print("[P3 NATIVE] Supervisor prepared. Tap ARM P3 on the purple game panel to enable outgoing requests. Final Accept OFF.")
return E.PDIDDLER_SUPERVISED_P3_RUNNER
