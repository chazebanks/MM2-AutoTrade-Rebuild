-- PDIDDLER P1 FAST BOT GATE TEST v1
-- Single loader. Reuses frozen known-good scoring, not the 90s observer.
-- Diagnostic only: no trading, no teleport, no final server hop.
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local E=(getgenv and getgenv()) or _G
if type(E.PDIDDLER_FAST_GATE_STOP)=="function" then pcall(E.PDIDDLER_FAST_GATE_STOP) end
E.PDIDDLER_FAST_GATE_GEN=(tonumber(E.PDIDDLER_FAST_GATE_GEN) or 0)+1
local GEN=E.PDIDDLER_FAST_GATE_GEN
E.PDIDDLER_FAST_GATE_RESULT=nil
local active=true
local gui,label
local started=os.clock()
local BUDGET=10
local SCAN_TIMEOUT=3
local MIN_SETTLE=1
local RECHECK_DELAY=2
local SCAN_GAP=.65
local phase="INITIALIZING"
local function current()
    return active and E.PDIDDLER_FAST_GATE_GEN==GEN
end
local function finish(state,why,details)
    if not current() then return end
    active=false
    phase=state
    local elapsed=os.clock()-started
    E.PDIDDLER_FAST_GATE_RESULT={
        version=1,jobId=game.JobId,generation=GEN,
        state=state,reason=why,elapsed=elapsed,
        observedAt=os.clock(),details=details or {},
        part5Compatible=false
    }
    local summary=string.format(
        "PDIDDLER FAST GATE | %s\n%s\nElapsed %.1fs | NO HOP / NO TRADE\n",
        state,tostring(why),elapsed)
    if details then
        summary=summary..string.format(
            "Players %d | avatars %d | score %d | scanCount %d",
            details.total or 0,details.loaded or 0,details.score or 0,
            details.scans or 0)
    end
    if label then label.Text=summary end
    print("[P1 FAST] FINAL "..summary:gsub("\n"," | "))
end
local function stop()
    active=false
    if gui then pcall(function() gui:Destroy() end) end
end
E.PDIDDLER_FAST_GATE_STOP=stop
local function playerIds()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then t[#t+1]=tostring(p.UserId) end
    end
    table.sort(t)
    return table.concat(t,",")
end
local function update(message)
    if label then
        label.Text=string.format(
            "PDIDDLER FAST GATE | %s | %.1f/%ds\n%s\nNo hop / no trades",
            phase,math.min(BUDGET,os.clock()-started),BUDGET,message or "")
    end
end
local function setup()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",3)
    if not pg or not current() then return end
    gui=Instance.new("ScreenGui")
    gui.Name="PdiddlerFastGateTestV1"
    gui.ResetOnSpawn=false
    local panel=Instance.new("Frame")
    panel.Size=UDim2.new(.85,0,0,105)
    panel.Position=UDim2.new(.075,0,.08,0)
    panel.BackgroundColor3=Color3.fromRGB(37,26,54)
    panel.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=panel
    label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,-16,1,-12)
    label.Position=UDim2.fromOffset(8,6)
    label.BackgroundTransparency=1
    label.TextColor3=Color3.new(1,1,1)
    label.Font=Enum.Font.Code
    label.TextSize=14
    label.TextWrapped=true
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.TextYAlignment=Enum.TextYAlignment.Top
    label.Text="Starting..."
    label.Parent=panel
    gui.Parent=pg
end
pcall(setup)
task.spawn(function()
    local loaded,lib=pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/feature/p1-bot-gate-safety-v1/pdiddler/pdiddler1_fast_scoring_from_known_good_v1.lua",
            true))()
    end)
    if not current() then return end
    if not loaded or type(lib)~="table" or type(lib.createScanner)~="function" then
        finish("PROCEED_UNVERIFIED","frozen scoring module unavailable")
        return
    end
    local ok,scanner=pcall(lib.createScanner)
    if not ok or type(scanner)~="function" then
        finish("PROCEED_UNVERIFIED","frozen scan initialization failed")
        return
    end
    -- No infinite wait for a complete lobby. Hard cutoff lets the trading
    -- controller proceed under its existing eligibility rules.
    while current() and os.clock()-started<MIN_SETTLE do task.wait(.1) end
    local firstSuspicious=nil
    local completed=0
    while current() and os.clock()-started<BUDGET do
        local pre=playerIds()
        local t0=os.clock()
        local completedHere=false
        local okScan,result
        phase=firstSuspicious and "CONFIRMING" or "SCANNING"
        update("Checking known-good avatar/name signals")
        task.spawn(function()
            local good,res=pcall(scanner)
            okScan=good
            result=res
            completedHere=true
        end)
        while current() and not completedHere
            and os.clock()-t0<SCAN_TIMEOUT
            and os.clock()-started<BUDGET do
            task.wait(.05)
        end
        if not current() then return end
        if not completedHere then
            finish("PROCEED_UNVERIFIED","scan exceeded bounded timeout; no rejection")
            return
        end
        local post=playerIds()
        if not okScan or type(result)~="table" then
            finish("PROCEED_UNVERIFIED","scoring read failed")
            return
        end
        if pre~=post then
            -- Never use a score from two different populations.
            firstSuspicious=nil
            update("Population changed; discarding this scan")
        else
            completed+=1
            local total=tonumber(result.total) or 0
            local avatars=tonumber(result.loaded) or 0
            local score=tonumber(result.score) or 0
            local detail={total=total,loaded=avatars,score=score,scans=completed}
            -- A name-only score may still occur with zero avatar descriptions.
            -- Never declare a bot farm until at least 70% of avatars loaded.
            local adequate=total>=6 and avatars>=math.ceil(total*.7)
            local suspicious=result.bot==true and adequate
            if suspicious then
                if firstSuspicious
                    and firstSuspicious.roster==pre
                    and os.clock()-firstSuspicious.at>=RECHECK_DELAY then
                    finish("BOT_PATTERN_FOR_REVIEW",
                        "two matching strong known-good scores (not proof)",detail)
                    return
                end
                if not firstSuspicious then
                    firstSuspicious={roster=pre,at=os.clock()}
                end
                update(string.format("Suspicious %d/%d loaded, score=%d; confirming",
                    avatars,total,score))
            else
                if adequate and not firstSuspicious then
                    -- This is deliberately advisory, not a permanent allowlist.
                    finish("PROCEED","no strong bot-farm score in loaded lobby",detail)
                    return
                end
                if firstSuspicious and adequate then
                    finish("PROCEED","suspected pattern did not persist",detail)
                    return
                end
                update("Insufficient loaded data; will not block trading")
            end
        end
        local untilTime=os.clock()+SCAN_GAP
        while current() and os.clock()<untilTime and os.clock()-started<BUDGET do
            task.wait(.05)
        end
    end
    if current() then
        finish("PROCEED_UNVERIFIED","10-second screening budget expired; no safe bot conclusion")
    end
end)
