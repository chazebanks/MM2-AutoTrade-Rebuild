-- System2: ONE MAIN-only operator tap assesses MULTIPLE read-only inventory features.
-- This is a NEW catalog/variant test, NOT a repeat of the closed two-snapshot test.
-- Never invokes P3/P4, sends requests, offers, Accept, Decline, Discord or hops.
local E=(type(getgenv)=="function" and getgenv()) or _G
local OWNER_KEY="PDIDDLER_S2_MULTIFEATURE_OWNER"
local USED_KEY="PDIDDLER_S2_MULTIFEATURE_USED_JOB"
if game.PlaceId~=142823291 or type(game.JobId)~="string" or
   #game.JobId<8 or #game.JobId>100 or
   E[OWNER_KEY]~=nil or E[USED_KEY]==game.JobId or
   E.PDIDDLER_SYSTEM2_OWN_CENSUS_NATIVE_OWNER~=nil or
   E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil or
   E.PDIDDLER_STAGE119_LASTOFFER_OWNER~=nil or
   E.PDIDDLER_PART4_SESSION~=nil or E.PDIDDLER_OUTGOING_SESSION~=nil or
   E.PDIDDLER_PART4_CONTROLLER_ACTIVE==true or
   E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE==true or
   E.PDIDDLER_AUTOTRADE_ACTIVE==true then
    warn("[S2 MULTI] Original MM2, fresh job, no competing owner required")
    return nil
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local World=game:GetService("Workspace")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
if not PG or not World or not World.CurrentCamera or not
    Run or not Run.Heartbeat or not RS or not Http then
    warn("[S2 MULTI] Client GUI and read-only services unavailable")
    return nil
end
local function frozen(rev,path)
    local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
       ..rev.."/pdiddler/"..path
    local ok,raw=pcall(function()return game:HttpGet(url)end)
    local compiler=loadstring or load
    if not ok or type(raw)~="string" or #raw<300 or
       #raw>25000 or type(compiler)~="function" then return nil end
    local loaded,res=pcall(function()return assert(compiler(raw))()end)
    return loaded and type(res)=="table" and res or nil
end
local core=frozen("139311e7eb5dc8d155652218ac1acc30e33955c5",
    "system2/native_multifeature_catalog_core.lua")
local geometry=frozen("5b8ee35d7f281c23d9c2181abd97a063e59a0660",
    "new_part4/stage100_screen_prompt_overlay.lua")
if not core or type(core.assess)~="function" or not geometry or
   type(geometry.choose)~="function" then
    warn("[S2 MULTI] Immutable source not loadable; no client inventory read")
    return nil
end
local function tradeVisible()
    for _,name in ipairs({"TradeGUI","TradeGUI_Phone"}) do
        local g=PG:FindFirstChild(name)
        local container=g and g:FindFirstChild("Container")
        local trade=container and container:FindFirstChild("Trade")
        if g and g.Enabled==true and container and
            container.Visible==true and trade and trade.Visible==true then
            return true
        end
    end
    return false
end
if tradeVisible() then
    warn("[S2 MULTI] Close all trades before MAIN-only read-only witness")
    return nil
end
local owner={active=true,phase="READY",busy=false,reads=0,job=game.JobId}
E[OWNER_KEY]=owner
local ui={}
local built=pcall(function()
    ui.root=Instance.new("ScreenGui")
    ui.root.Name="PDIDDLER_S2_Multifeature_ReadOnly"
    ui.root.ResetOnSpawn=false
    ui.root.IgnoreGuiInset=true
    ui.root.DisplayOrder=150
    ui.root.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    ui.root.Parent=PG
    ui.panel=Instance.new("Frame")
    ui.panel.Name="SafePrompt"
    ui.panel.BackgroundColor3=Color3.fromRGB(28,23,40)
    ui.panel.BorderSizePixel=0
    ui.panel.Active=false
    ui.panel.Visible=false
    ui.panel.Parent=ui.root
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=ui.panel
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(177,128,239)
    stroke.Thickness=1
    stroke.Parent=ui.panel
    local function label(n,y,h,size)
        local v=Instance.new("TextLabel")
        v.Name=n
        v.BackgroundTransparency=1
        v.TextColor3=Color3.fromRGB(255,255,255)
        v.Font=Enum.Font.GothamBold
        v.TextSize=size
        v.TextWrapped=true
        v.TextXAlignment=Enum.TextXAlignment.Left
        v.Position=UDim2.fromOffset(12,y)
        v.Size=UDim2.fromOffset(280,h)
        v.Parent=ui.panel
        return v
    end
    ui.title=label("Step",7,23,14)
    ui.body=label("Instruction",32,53,12)
    ui.warning=label("Safety",90,16,10)
    ui.warning.Text="READ ONLY | NO TRADES | NEVER FINAL ACCEPT"
    local function button(n,x)
        local b=Instance.new("TextButton")
        b.Name=n
        b.TextSize=13
        b.TextColor3=Color3.fromRGB(255,255,255)
        b.BackgroundColor3=Color3.fromRGB(88,55,129)
        b.Position=UDim2.fromOffset(x,110)
        b.Size=UDim2.fromOffset(128,30)
        b.Visible=false
        b.Active=false
        b.Parent=ui.panel
        return b
    end
    ui.capture=button("CaptureCatalogBatch",12)
    ui.stop=button("CopyClose",164)
end)
if not built then
    E[OWNER_KEY]=nil
    owner.active=false
    if ui.root then pcall(function()ui.root:Destroy()end) end
    warn("[S2 MULTI] Safe on-screen GUI construction failed")
    return nil
end
local last={
    schema="gingerscope-system2-native-multifeature-v1",
    status="PREPARED",reason="NO_OWN_PROFILE_READ",
}
local allowed={
    "schema","status","reason","features","readOnly","clientOnly",
    "serverInventoryAuthoritative","gameItemInstanceProven",
    "sourceEditionAuthenticated","activeTradeSessionProven",
    "offerRevisionAuthenticated","serverTradeRevisionProven",
    "serverCompletionProven","measuredLiquidityVerified",
    "authorizesTrade","authorizesOffer","authorizesAccept",
    "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning",
    "tradeOutcome","actualOffers","actualAccepts","actualDeclines",
    "actualTeleports","inventoryRecordsExported","rawIdsExported",
    "sessionIdentifiersExported","liveOfferRankingAuthorized"
}
local function publicReport()
    local out={}
    for _,key in ipairs(allowed) do
        if last[key]~=nil then out[key]=last[key] end
    end
    -- These are fixed, never inferred from incoming client data.
    out.readOnly=true;out.clientOnly=true
    out.serverInventoryAuthoritative=false;out.gameItemInstanceProven=false
    out.sourceEditionAuthenticated=false;out.activeTradeSessionProven=false
    out.offerRevisionAuthenticated=false;out.serverTradeRevisionProven=false
    out.serverCompletionProven=false;out.measuredLiquidityVerified=false
    out.authorizesTrade=false;out.authorizesOffer=false;out.authorizesAccept=false
    out.mayReportProfit=false;out.maySendDiscordWebhook=false
    out.mayUseForStrategyLearning=false;out.tradeOutcome="UNKNOWN"
    out.actualOffers=0;out.actualAccepts=0;out.actualDeclines=0;out.actualTeleports=0
    out.inventoryRecordsExported=false;out.rawIdsExported=false
    out.sessionIdentifiersExported=false;out.liveOfferRankingAuthorized=false
    out.readAttempts=owner.reads
    return out
end
local function copy()
    local ok,s=pcall(function()return Http:JSONEncode(publicReport())end)
    if not ok or type(s)~="string" then return false end
    E.PDIDDLER_S2_MULTI_LAST_JSON=s
    local clip=type(setclipboard)=="function" and setclipboard or
        type(toclipboard)=="function" and toclipboard or nil
    if clip then pcall(clip,s) end
    print("[S2 MULTI SAFE RESULT] "..s)
    return true
end
local function layout()
    if not owner.active or E[OWNER_KEY]~=owner or
       game.JobId~=owner.job or game.PlaceId~=142823291 or
       ui.root.Parent~=PG or ui.panel.Parent~=ui.root or
       tradeVisible() then return false,"CLIENT_OWNER_OR_TRADE_CONFLICT" end
    local camera=World.CurrentCamera
    local viewport=camera and camera.ViewportSize
    if not viewport then return false,"CAMERA_OR_VIEWPORT_MISSING" end
    local pos,why=geometry.choose({x=viewport.X,y=viewport.Y},nil,{w=304,h=148})
    if not pos then return false,why end
    local ok=pcall(function()
        ui.panel.Position=UDim2.fromOffset(pos.x,pos.y)
        ui.panel.Size=UDim2.fromOffset(pos.w,pos.h)
        ui.panel.Visible=true
    end)
    return ok,ok and "SAFE" or "GUI_LAYOUT_FAILED"
end
local function show()
    local ok,why=layout()
    if not ok then return false,why end
    ui.capture.Visible=owner.phase=="READY"
    ui.capture.Active=ui.capture.Visible and not owner.busy
    ui.capture.Text="RUN 5 CHECKS"
    ui.stop.Visible=true;ui.stop.Active=true
    ui.stop.Text=owner.phase=="DONE" and "COPY / CLOSE" or "STOP / COPY"
    if owner.phase=="READY" then
        ui.title.Text="MAIN — 1/2 RUN SYSTEM 2 CHECKS"
        ui.body.Text="Tap RUN 5 CHECKS once. Catalog, Chroma, stacks, exclusions and freshness. No ALT needed."
    elseif owner.phase=="READING" then
        ui.title.Text="MAIN — CHECKING READ-ONLY DATA"
        ui.body.Text="Reading MAIN profile once and matching exact game Sync metadata. No trading."
    else
        ui.title.Text=last.status=="CLIENT_MULTI_FEATURE_REPORT"
            and "2/2 CHECKS COMPLETE — CLIENT ONLY" or
            "2/2 STOPPED / INCONCLUSIVE"
        ui.body.Text="Tap COPY / CLOSE. Paste sanitized per-feature report in ChatGPT. Never final Accept."
    end
    return true
end
local heartbeat
local terminalState=false
local function finish(result)
    if terminalState then return end
    terminalState=true
    owner.busy=false
    owner.phase="DONE"
    last=result or {status="BLOCKED",reason="UNKNOWN"}
    owner.first=nil
    local ok=show()
    if not ok then
        -- Never leave a blocked overlay visible above trade controls.
        copy()
        owner.active=false
        E[USED_KEY]=game.JobId;E[OWNER_KEY]=nil
        pcall(function()ui.root:Destroy()end)
        if heartbeat then pcall(function()heartbeat:Disconnect()end) end
    end
end
local function runOne()
    if terminalState or owner.busy or owner.phase~="READY" then return end
    local safe=layout()
    if not safe then finish({status="BLOCKED",reason="CLIENT_UI_NOT_SAFE"});return end
    owner.busy=true;owner.phase="READING"
    show()
    local remotes=RS:FindFirstChild("Remotes")
    local inventory=remotes and remotes:FindFirstChild("Inventory")
    local rf=inventory and inventory:FindFirstChild("GetProfileData")
    if not rf or not rf:IsA("RemoteFunction") then
        finish({status="BLOCKED",reason="OWN_PROFILE_READ_REMOTE_MISSING"});return
    end
    local started=os.clock()
    owner.reads+=1
    local done=false
    local ok=false
    local data=nil
    task.spawn(function()
        ok,data=pcall(function()return rf:InvokeServer()end)
        done=true
    end)
    while not done and os.clock()-started<6 do
        if not owner.active or terminalState or E[OWNER_KEY]~=owner or
           game.JobId~=owner.job or tradeVisible() then
            finish({status="BLOCKED",reason="CONTEXT_CHANGED_DURING_READ"})
            return
        end
        task.wait(0.05)
    end
    if not done then finish({status="BLOCKED",reason="OWN_PROFILE_READ_TIMEOUT"});return end
    if not ok or type(data)~="table" then
        finish({status="BLOCKED",reason="OWN_PROFILE_READ_FAILED"});return
    end
    if not owner.active or terminalState or game.JobId~=owner.job or
       E[OWNER_KEY]~=owner or tradeVisible() then
        finish({status="BLOCKED",reason="CONTEXT_CHANGED_AFTER_READ"});return
    end
    local db=RS:FindFirstChild("Database")
    local module=db and db:FindFirstChild("Sync")
    local sync=nil
    if module and module:IsA("ModuleScript") then
        local loaded,m=pcall(require,module)
        if loaded and type(m)=="table" then sync=m end
    end
    local result
    local worked,answer=pcall(core.assess,data,sync,owner.job,started,os.clock())
    data=nil;sync=nil
    if worked and type(answer)=="table" and
        answer.schema=="gingerscope-system2-native-multifeature-v1" then
        result=answer
    else
        result={status="BLOCKED",reason="FEATURE_CLASSIFIER_EXCEPTION"}
    end
    finish(result)
end
local first=show()
if not first then
    finish({status="BLOCKED",reason="INITIAL_SAFE_PANEL_UNAVAILABLE"})
    return nil
end
heartbeat=Run.Heartbeat:Connect(function()
    if owner.active and not terminalState then
        local ok=layout()
        if not ok then
            finish({status="BLOCKED",reason="DYNAMIC_UI_OR_JOB_CONTEXT_LOST"})
        end
    end
end)
ui.capture.Activated:Connect(function()if owner.active then runOne() end end)
ui.stop.Activated:Connect(function()
    if not owner.active then return end
    if not terminalState then
        finish({status="STOPPED",reason="OPERATOR_STOPPED"})
    else
        copy()
        owner.active=false
        E[USED_KEY]=game.JobId;E[OWNER_KEY]=nil
        if heartbeat then pcall(function()heartbeat:Disconnect()end) end
        pcall(function()ui.root:Destroy()end)
    end
end)
return {status=publicReport, stop=function()
    finish({status="STOPPED",reason="OPERATOR_STOPPED"})
end}
