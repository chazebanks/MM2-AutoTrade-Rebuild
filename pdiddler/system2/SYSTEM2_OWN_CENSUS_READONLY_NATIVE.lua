-- System2 NEW read-only MAIN iPad census witness, intentionally separate from P3/P4.
-- Exactly two OPERATOR-tapped own GetProfileData reads; NO trade requests,
-- OfferItem, Accept, Decline, hops, price lookups, Discord or P3 rotation.
-- Do not use this to infer server ownership/settlement or accept authority.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_SYSTEM2_OWN_CENSUS_NATIVE_OWNER"
if game.PlaceId~=142823291 or
    E[KEY]~=nil or E.PDIDDLER_S2_CENSUS_USED_JOB==game.JobId or
    E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil or
    E.PDIDDLER_PART4_SESSION~=nil or
    E.PDIDDLER_OUTGOING_SESSION~=nil or
    E.PDIDDLER_STAGE119_LASTOFFER_OWNER~=nil or
    E.PDIDDLER_AUTOTRADE_ACTIVE==true or
    E.PDIDDLER_PART4_CONTROLLER_ACTIVE==true then
    warn("[S2 CENSUS] Original MM2 fresh job, no competing owner required")
    return nil
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local World=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
if not PG or not World or not World.CurrentCamera or
   not RunService or not RunService.Heartbeat then
    warn("[S2 CENSUS] Required local UI services unavailable")
    return nil
end
local function frozen(rev,path)
    local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
        ..rev.."/pdiddler/"..path
    local ok,raw=pcall(function()return game:HttpGet(url)end)
    local loader=loadstring or load
    if not ok or type(raw)~="string" or #raw<250 or #raw>18000 or
       type(loader)~="function" then return nil end
    local ok2,module=pcall(function()return assert(loader(raw))()end)
    return ok2 and type(module)=="table" and module or nil
end
-- First is the Git-immutable pure core from this new research branch.
local core=frozen("85a633eb54010e0b2aba770e857bccf0d33e8b21",
    "system2/native_own_census_core.lua")
local geometry=frozen("5b8ee35d7f281c23d9c2181abd97a063e59a0660",
    "new_part4/stage100_screen_prompt_overlay.lua")
if not core or type(core.observe)~="function" or
   type(core.compare)~="function" or
   not geometry or type(geometry.choose)~="function" then
    warn("[S2 CENSUS] Source-pin module unavailable; no census requested")
    return nil
end
local function tradeVisible()
    local active=0
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local g=PG:FindFirstChild(name)
        local c=g and g:FindFirstChild("Container")
        local t=c and c:FindFirstChild("Trade")
        if g and g.Enabled==true and c and c.Visible==true
            and t and t.Visible==true then
            active+=1
        end
    end
    return active>0
end
if tradeVisible() then
    warn("[S2 CENSUS] Close all trade windows before isolated census test")
    return nil
end
local owner={active=true,busy=false,phase="FIRST",first=nil,reads=0}
E[KEY]=owner
local ui={}
local built=pcall(function()
    ui.screen=Instance.new("ScreenGui")
    ui.screen.Name="PDIDDLER_System2_OwnCensus_Readonly"
    ui.screen.ResetOnSpawn=false
    ui.screen.IgnoreGuiInset=true
    ui.screen.DisplayOrder=150
    ui.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    ui.screen.Parent=PG
    ui.panel=Instance.new("Frame")
    ui.panel.Name="ReadOnlyGuide"
    ui.panel.BackgroundColor3=Color3.fromRGB(28,23,40)
    ui.panel.BorderSizePixel=0
    ui.panel.Active=false
    ui.panel.Visible=false
    ui.panel.Parent=ui.screen
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=ui.panel
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(177,128,239)
    stroke.Thickness=1
    stroke.Parent=ui.panel
    local function label(name,y,height,size)
        local obj=Instance.new("TextLabel")
        obj.Name=name;obj.BackgroundTransparency=1
        obj.TextColor3=Color3.fromRGB(255,255,255)
        obj.Font=Enum.Font.GothamBold
        obj.TextSize=size;obj.TextWrapped=true
        obj.TextXAlignment=Enum.TextXAlignment.Left
        obj.Position=UDim2.fromOffset(12,y)
        obj.Size=UDim2.fromOffset(280,height)
        obj.Parent=ui.panel
        return obj
    end
    ui.title=label("Step",7,24,14)
    ui.body=label("Instruction",32,56,12)
    ui.warning=label("Safety",95,18,11)
    ui.warning.Text="READ ONLY | NO TRADES | NO FINAL ACCEPT"
    local function button(name,x)
        local obj=Instance.new("TextButton")
        obj.Name=name
        obj.TextSize=13;obj.TextColor3=Color3.fromRGB(255,255,255)
        obj.BackgroundColor3=Color3.fromRGB(88,55,129)
        obj.Position=UDim2.fromOffset(x,117)
        obj.Size=UDim2.fromOffset(128,30)
        obj.Visible=false;obj.Active=false
        obj.Parent=ui.panel
        return obj
    end
    ui.capture=button("ManualCapture",12)
    ui.stop=button("StopCopy",164)
end)
if not built then
    owner.active=false;E[KEY]=nil
    if ui.screen then pcall(function()ui.screen:Destroy()end) end
    warn("[S2 CENSUS] Unable to construct safe in-game panel")
    return nil
end
local last={
    schema="gingerscope-system2-native-own-census-v1",
    status="PREPARED",reason="NO_CLIENT_READ_YET",
    readOnly=true,clientOnly=true,
    authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
    serverCompletionProven=false,serverInventoryAuthoritative=false,
    mayReportProfit=false,maySendDiscordWebhook=false,
    mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
}
local function sanitized(x)
    return {
        schema="gingerscope-system2-native-own-census-v1",
        status=tostring(x.status or "INCONCLUSIVE"),
        reason=tostring(x.reason or "UNKNOWN"),
        readOnly=true,clientOnly=true,
        clientCensusChanged=x.clientCensusChanged,
        firstDistinctKeys=x.firstDistinctKeys,
        secondDistinctKeys=x.secondDistinctKeys,
        firstCopies=x.firstCopies,secondCopies=x.secondCopies,
        observationGapSeconds=x.observationGapSeconds,
        readAttempts=owner.reads,
        nativeSourceAuthenticated=false,
        currentGameItemInstanceProven=false,
        serverInventoryAuthoritative=false,
        activeTradeSessionProven=false,
        offerRevisionAuthenticated=false,
        serverTradeRevisionProven=false,
        serverCompletionProven=false,
        researchDecisionReusable=false,
        authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
        mayReportProfit=false,maySendDiscordWebhook=false,
        mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
        actualOffers=0,actualAccepts=0,actualDeclines=0,
        actualTeleports=0,
    }
end
local function copy()
    local report=sanitized(last)
    local ok,json=pcall(function()return Http:JSONEncode(report)end)
    if not ok or type(json)~="string" then return false end
    E.PDIDDLER_S2_CENSUS_LAST_JSON=json
    local fn=type(setclipboard)=="function" and setclipboard or
        type(toclipboard)=="function" and toclipboard or nil
    local copied=false
    if fn then
        local success,res=pcall(fn,json)
        copied=success and res~=false
    end
    print("[S2 CENSUS SAFE RESULT] "..json)
    return copied
end
local function layout()
    if not owner.active or not World.CurrentCamera or
       ui.screen.Parent~=PG or ui.panel.Parent~=ui.screen or
       tradeVisible() then return false,"SESSION_OR_TRADE_UI_CONFLICT" end
    local v=World.CurrentCamera.ViewportSize
    if not v then return false,"VIEWPORT_MISSING" end
    local position,reason=geometry.choose({x=v.X,y=v.Y},nil,{w=304,h=154})
    if not position then return false,reason end
    local ok=pcall(function()
        ui.panel.Position=UDim2.fromOffset(position.x,position.y)
        ui.panel.Size=UDim2.fromOffset(position.w,position.h)
        ui.panel.Visible=true
    end)
    return ok,ok and "SAFE" or "LAYOUT_FAILED"
end
local function show()
    local ok,reason=layout()
    if not ok then return false,reason end
    ui.capture.Visible=owner.phase=="FIRST" or owner.phase=="SECOND"
    ui.capture.Active=ui.capture.Visible and not owner.busy
    ui.stop.Visible=true;ui.stop.Active=true
    if owner.phase=="FIRST" then
        ui.title.Text="1/2 MAIN — READ OWN INVENTORY"
        ui.body.Text="MAIN: tap CAPTURE 1 once. No trading, offers, or ALT needed."
        ui.capture.Text="CAPTURE 1"
    elseif owner.phase=="SECOND" then
        ui.title.Text="2/2 MAIN — READ AGAIN"
        ui.body.Text="MAIN: after 2 seconds, tap CAPTURE 2. Do not trade or leave server."
        ui.capture.Text="CAPTURE 2"
    else
        ui.title.Text=last.status=="CLIENT_TWO_READS_STABLE"
            and "COMPLETE — CLIENT READS MATCH" or
            "STOPPED / CLIENT-ONLY RESULT"
        ui.body.Text="MAIN: tap COPY / CLOSE, then paste the sanitized JSON here."
    end
    ui.stop.Text=owner.phase=="FINISHED" and "COPY / CLOSE" or "STOP / COPY"
    return true
end
local function terminal(status,reason)
    owner.busy=false
    owner.first=nil
    owner.phase="FINISHED"
    last={status=status,reason=reason}
    local ok=show()
    if not ok then
        copy()
        owner.active=false
        E.PDIDDLER_S2_CENSUS_USED_JOB=game.JobId
        E[KEY]=nil
        pcall(function()ui.screen:Destroy()end)
    end
end
local function readOnce()
    if not owner.active or owner.busy or owner.phase=="FINISHED" then return end
    if E[KEY]~=owner or E.PDIDDLER_S2_CENSUS_USED_JOB==game.JobId then
        terminal("BLOCKED","CLIENT_OWNER_CHANGED")
        return
    end
    if not layout() then terminal("BLOCKED","SAFE_PANEL_OR_TRADE_CONFLICT");return end
    if owner.phase=="SECOND" and os.clock()-owner.first.monotonic<2 then
        last={status="WAITING",reason="SECOND_READ_MUST_BE_TWO_SECONDS_LATER"}
        show()
        return
    end
    local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local inv=remotes and remotes:FindFirstChild("Inventory")
    local rf=inv and inv:FindFirstChild("GetProfileData")
    if not rf or not rf:IsA("RemoteFunction") then
        terminal("BLOCKED","OWN_READ_ONLY_PROFILE_REMOTE_MISSING");return
    end
    owner.busy=true
    ui.capture.Active=false
    owner.reads+=1
    local began=os.clock()
    local finished=false
    local success=false
    local profile=nil
    task.spawn(function()
        success,profile=pcall(function()return rf:InvokeServer()end)
        finished=true
    end)
    while not finished and os.clock()-began<6 do
        if not owner.active or E[KEY]~=owner or tradeVisible() or
            game.PlaceId~=142823291 or game.JobId~=owner.job then
            terminal("BLOCKED","CLIENT_CONTEXT_CHANGED_DURING_READ")
            return
        end
        task.wait(0.05)
    end
    if not finished then
        terminal("BLOCKED","PROFILE_READ_TIMEOUT_NO_RETRY_IN_JOB")
        return
    end
    if not success then terminal("BLOCKED","PROFILE_READ_FAILED");return end
    if not owner.active or E[KEY]~=owner or tradeVisible() then
        terminal("BLOCKED","CLIENT_CONTEXT_CHANGED_AFTER_READ");return
    end
    local stamp,result=core.observe(profile,game.JobId,os.clock())
    profile=nil
    if not stamp then terminal(result.status,result.reason);return end
    if owner.phase=="FIRST" then
        owner.first=stamp
        owner.phase="SECOND"
        owner.busy=false
        if not show() then terminal("BLOCKED","SECOND_PROMPT_NO_SAFE_SPACE") end
    else
        local verdict=core.compare(owner.first,stamp)
        last=verdict
        owner.first=nil;owner.busy=false;owner.phase="FINISHED"
        if not show() then terminal("BLOCKED","RESULT_PROMPT_NO_SAFE_SPACE") end
    end
end
owner.job=game.JobId
local ok,reason=show()
if not ok then
    terminal("BLOCKED","FIRST_PROMPT_NO_SAFE_SPACE")
    return nil
end
local closed=false
local heartbeat=RunService.Heartbeat:Connect(function()
    if owner.active then
        local okay=layout()
        if not okay then terminal("BLOCKED","PANEL_OR_TRADE_CONTEXT_LOST") end
    end
end)
ui.capture.Activated:Connect(function()
    if owner.active and not owner.busy then readOnce() end
end)
ui.stop.Activated:Connect(function()
    if closed then return end
    if owner.phase~="FINISHED" then
        terminal("STOPPED","OPERATOR_STOPPED")
    else
        closed=true
        copy()
        owner.active=false
        owner.first=nil
        E.PDIDDLER_S2_CENSUS_USED_JOB=game.JobId
        E[KEY]=nil
        pcall(function()heartbeat:Disconnect()end)
        pcall(function()ui.screen:Destroy()end)
    end
end)
return {status=function()return sanitized(last)end,stop=function()
    terminal("STOPPED","OPERATOR_STOPPED") end}
