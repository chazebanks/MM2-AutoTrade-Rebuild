-- Stage116: passive read-only MM2 ON-SCREEN CLIENT EVIDENCE summary.
-- DOES NOT RUN Stage106, listen to trade remotes, read inventory, or automate.
-- Can only show already cached Stage106 local report and OPTIONAL previously
-- exported sanitized Stage115 OFFLINE replay output. These records are UNLINKED.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE116_READONLY_EVIDENCE_PANEL"
if game.PlaceId ~= 142823291 then
    warn("[STAGE116] original MM2 place only; no evidence panel shown")
    return nil
end
if E[KEY] ~= nil then
    return E[KEY]
end
local witness=E.GINGERSCOPE_STAGE106_READONLY_WITNESS
if type(witness)=="table" and witness.running==true then
    warn("[STAGE116] existing Stage106 is still running; do not obstruct test")
    return nil
end
for _,owner in ipairs({
    "PDIDDLER_OUTGOING_CONTROLLER",
    "PDIDDLER_OUTGOING_SESSION",
    "PDIDDLER_PART4_SESSION",
    "PDIDDLER_PART5_CONTROLLER",
    "PDIDDLER_HOPPING_SESSION",
}) do
    if E[owner] ~= nil then
        warn("[STAGE116] another pdiddler owner present; no display")
        return nil
    end
end

-- Pinned immutable source commit containing ONLY pure display view and
-- nonoverlapping safe-geometry. Fetches GitHub code, NEVER item/player data.
-- No outbound HTTP with inventory/account payloads; no game trade remotes.
local PIN="31cdd660f2d82ab50b548e5c8bc4e179c28312e6"
local REPO="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local function getPure(name)
    if name~="stage116_client_evidence_view" and
       name~="stage116_safe_panel_geometry" then
        return nil
    end
    local good,result=pcall(function()
        local source=game:HttpGet(REPO..PIN.."/pdiddler/new_part4/"..name..".lua")
        assert(type(source)=="string" and #source>100 and #source<20000)
        local compiler=loadstring or load
        assert(type(compiler)=="function")
        return assert(compiler(source))()
    end)
    if not good or type(result)~="table" then return nil end
    return result
end
local view=getPure("stage116_client_evidence_view")
local geometry=getPure("stage116_safe_panel_geometry")
if not view or type(view.build)~="function"
    or not geometry or type(geometry.choose)~="function" then
    warn("[STAGE116] pinned pure view/geometry unavailable; no display")
    return nil
end

local stage106=nil
if type(witness)=="table" and witness.running==false
    and type(witness.report)=="table" then
    stage106=witness.report
end
-- This is ONLY an optional independently generated OFFLINE replay report.
-- It has no authenticated session link to Stage106 or actual game inventory.
local stage115=E.PDIDDLER_STAGE116_SANITIZED_REPLAY_REPORT
local ok,diagnostic=pcall(view.build,stage106,stage115)
if not ok or type(diagnostic)~="table"
    or diagnostic.readOnly~=true
    or diagnostic.tradeOutcome~="UNKNOWN"
    or diagnostic.authorizesAccept~=false
    or diagnostic.authorizesTrade~=false
    or diagnostic.mayRecordCompletedTrade~=false
    or diagnostic.mayReportProfit~=false
    or diagnostic.relationProven~=false then
    warn("[STAGE116] rejected unexpected view authority")
    return nil
end

local players=game:GetService("Players")
local me=players.LocalPlayer
local pg=me and me:FindFirstChildOfClass("PlayerGui")
local world=game:GetService("Workspace")
local runService=game:GetService("RunService")
if not pg or not world or not world.CurrentCamera or not runService then
    warn("[STAGE116] missing live PlayerGui/viewport; no display")
    return nil
end
local function visible(node)
    local current=node
    while current and current~=pg do
        if current:IsA("ScreenGui") and current.Enabled~=true then
            return false
        end
        if current:IsA("GuiObject") and current.Visible~=true then
            return false
        end
        current=current.Parent
    end
    return current==pg
end
local function tradeBounds()
    local active={}
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local screen=pg:FindFirstChild(name)
        local container=screen and screen:FindFirstChild("Container")
        local root=container and container:FindFirstChild("Main")
        if root and visible(root) then
            table.insert(active,root)
        end
    end
    if #active>1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
    if #active==0 then return nil,nil end
    local okRect,point,dim=pcall(function()
        return active[1].AbsolutePosition,active[1].AbsoluteSize
    end)
    if not okRect or not point or not dim then
        return nil,"TRADE_BOUNDS_UNAVAILABLE"
    end
    return {x=point.X,y=point.Y,w=dim.X,h=dim.Y},nil
end
local function place()
    local camera=world.CurrentCamera
    if not camera then return nil,"VIEWPORT_UNAVAILABLE" end
    local okVP,v=pcall(function()return camera.ViewportSize end)
    if not okVP or not v then return nil,"VIEWPORT_UNAVAILABLE" end
    local trade,reason=tradeBounds()
    if reason then return nil,reason end
    return geometry.choose({x=v.X,y=v.Y},trade,{w=304,h=144})
end
-- Fail closed before allocating any persistent UI.
local firstRect,firstReason=place()
if not firstRect then
    warn("[STAGE116] no safe panel area: "..tostring(firstReason))
    return nil
end
local ui=nil
local created,problem=pcall(function()
    local screen=Instance.new("ScreenGui")
    screen.Name="PDIDDLER_Stage116_ClientEvidence_ReadOnly"
    screen.ResetOnSpawn=false
    screen.IgnoreGuiInset=true
    screen.DisplayOrder=150
    screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    screen.Parent=pg
    ui={screen=screen}

    local frame=Instance.new("Frame")
    frame.Name="ClientEvidence"
    frame.BackgroundColor3=Color3.fromRGB(28,23,40)
    frame.BorderSizePixel=0
    frame.BackgroundTransparency=0.05
    frame.ZIndex=10
    frame.Active=false
    frame.Parent=screen
    ui.frame=frame
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=frame
    local stroke=Instance.new("UIStroke")
    stroke.Thickness=1
    stroke.Color=Color3.fromRGB(177,128,239)
    stroke.Parent=frame

    local function label(name,color,size,y,h,content,font)
        local x=Instance.new("TextLabel")
        x.Name=name
        x.BackgroundTransparency=1
        x.TextColor3=color
        x.TextSize=size
        x.Font=font or Enum.Font.Gotham
        x.TextWrapped=true
        x.TextXAlignment=Enum.TextXAlignment.Left
        x.TextYAlignment=Enum.TextYAlignment.Center
        x.ZIndex=11
        x.Active=false
        x.Position=UDim2.fromOffset(10,y)
        x.Size=UDim2.fromOffset(282,h)
        x.Text=content
        x.Parent=frame
        return x
    end
    label("Outcome",Color3.fromRGB(232,202,255),14,5,20,
          "OUTCOME UNKNOWN - CLIENT ONLY",Enum.Font.GothamBold)
    label("OfferCandidate",Color3.fromRGB(255,255,255),12,30,36,
          diagnostic.offerText)
    label("Readback",Color3.fromRGB(255,255,255),12,66,32,
          diagnostic.readbackText)
    label("NotLinked",Color3.fromRGB(249,213,163),10,100,32,
          "UNLINKED RECORDS. Not proof of completed trade.")
    local dismiss=Instance.new("TextButton")
    dismiss.Name="DismissReadOnly"
    dismiss.Text="X"
    dismiss.TextColor3=Color3.fromRGB(255,255,255)
    dismiss.BackgroundColor3=Color3.fromRGB(76,52,103)
    dismiss.TextSize=12
    dismiss.Font=Enum.Font.GothamBold
    dismiss.Position=UDim2.fromOffset(278,4)
    dismiss.Size=UDim2.fromOffset(22,20)
    dismiss.ZIndex=12
    dismiss.Parent=frame
    ui.dismiss=dismiss
end)
if not created or not ui or not ui.screen or not ui.frame then
    if ui and ui.screen then pcall(function()ui.screen:Destroy()end) end
    warn("[STAGE116] panel creation failed: no user-visible result")
    return nil
end

local state={readOnly=true,report=diagnostic,running=true,
             status="CLIENT_EVIDENCE_DISPLAY_ONLY"}
local link=nil
local function stop()
    if not state.running then return end
    state.running=false
    if link then link:Disconnect();link=nil end
    pcall(function()ui.screen:Destroy()end)
    E[KEY]=nil
end
local function reposition()
    local rect,reason=place()
    if not rect then
        ui.frame.Visible=false
        state.status="INCONCLUSIVE_NO_SAFE_PANEL_AREA"
        return false
    end
    local okSet=pcall(function()
        ui.frame.Position=UDim2.fromOffset(rect.x,rect.y)
        ui.frame.Size=UDim2.fromOffset(rect.w,rect.h)
        ui.frame.Visible=true
    end)
    if not okSet then
        ui.frame.Visible=false
        state.status="INCONCLUSIVE_LAYOUT_FAILURE"
        return false
    end
    state.status="CLIENT_EVIDENCE_DISPLAY_ONLY"
    return true
end
if not reposition() then
    stop()
    warn("[STAGE116] panel layout failed")
    return nil
end
ui.dismiss.Activated:Connect(stop)
local last=os.clock()
link=runService.RenderStepped:Connect(function()
    if not state.running then return end
    local now=os.clock()
    if now-last>=0.25 then
        last=now
        reposition() -- Hide immediately if trade GUI moves into every safe area.
    end
end)
E[KEY]=state
-- Fixed, privacy-preserving text only; never raw source inventory, user IDs
-- or full client callback packet.
print("[STAGE116 CLIENT EVIDENCE ONLY] "..diagnostic.offerText..
    " | "..diagnostic.readbackText..
    " | OUTCOME UNKNOWN / UNLINKED RECORDS / NO TRADE AUTHORITY")
return state
