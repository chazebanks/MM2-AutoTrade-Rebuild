-- PDIDDLER Part 1 BOT OBSERVER TEST v1
-- DIAGNOSTIC ONLY. Does not trade, accept, hop, or change known-good modules.
-- Paste/run standalone in Delta after joining MM2. Observe for 60 seconds.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

if type(ENV.PDIDDLER_BOT_OBSERVER_STOP) == "function" then
    pcall(ENV.PDIDDLER_BOT_OBSERVER_STOP)
end
ENV.PDIDDLER_BOT_OBSERVER_GEN = (tonumber(ENV.PDIDDLER_BOT_OBSERVER_GEN) or 0) + 1
local generation = ENV.PDIDDLER_BOT_OBSERVER_GEN
local active = true
local gui
local reportLabel
local stats = {}
local SAMPLE_INTERVAL = 1
local DURATION = 60
local MIN_VALID_SAMPLES = 12
local MOVING_DISTANCE = 1.5
local MAX_REASONABLE_SPEED = 120
local started = os.clock()

local function alive()
    return active and ENV.PDIDDLER_BOT_OBSERVER_GEN == generation
end
local function stop()
    if not active then return end
    active = false
    if gui then pcall(function() gui:Destroy() end) end
end
ENV.PDIDDLER_BOT_OBSERVER_STOP = stop

local function safeName(s)
    return tostring(s or ""):gsub("[\r\n|]", " "):sub(1,32)
end
local function ensureStat(p)
    local s = stats[p.UserId]
    if not s then
        s = {
            id=p.UserId, name=p.Name, samples=0, missing=0, dead=0,
            moving=0, movingNoTracks=0, still=0, playing=0,
            teleports=0, distance=0, verticalOutliers=0,
            lastPosition=nil, lastCharacter=nil, lastClock=nil,
            tracks={}, configured={}, rig="unknown"
        }
        stats[p.UserId] = s
    end
    return s
end
local function humanAnimConfig(hum,s)
    -- Nonzero description fields are configuration evidence, not proof of a
    -- particular animation package or of what is actually playing.
    local ok,desc=pcall(function() return hum:GetAppliedDescription() end)
    if not ok or not desc then return end
    for _,field in ipairs({"IdleAnimation","WalkAnimation","RunAnimation","JumpAnimation","FallAnimation","ClimbAnimation","SwimAnimation"}) do
        local v
        local got=pcall(function() v=desc[field] end)
        if got and tonumber(v) and tonumber(v)~=0 then
            s.configured[field]=tostring(v)
        end
    end
end
local function countTracks(hum,s)
    local animator=hum:FindFirstChildOfClass("Animator")
    if not animator then return 0,false end
    local ok,tracks=pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok or type(tracks)~="table" then return 0,false end
    local count=0
    for _,track in ipairs(tracks) do
        local playing=false
        pcall(function() playing=track.IsPlaying end)
        if playing then
            count+=1
            local id=""
            pcall(function()
                local animation=track.Animation
                if animation then id=tostring(animation.AnimationId or "") end
            end)
            if id~="" then s.tracks[id]=(s.tracks[id] or 0)+1 end
        end
    end
    return count,true
end
local function sample(p,now)
    local s=ensureStat(p)
    local char=p.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if char~=s.lastCharacter then
        s.lastCharacter=char
        s.lastPosition=nil
        s.lastClock=nil
    end
    if not char or not hum or not root or not root:IsA("BasePart") then
        s.missing+=1
        return
    end
    if hum.Health<=0 then
        s.dead+=1
        s.lastPosition=nil
        s.lastClock=nil
        return
    end
    local pos=root.Position
    s.samples+=1
    pcall(function() s.rig=tostring(hum.RigType.Name) end)
    local n,trackDataReady=countTracks(hum,s)
    if trackDataReady and n>0 then s.playing+=1 end
    local lastPos,lastClock=s.lastPosition,s.lastClock
    s.lastPosition,s.lastClock=pos,now
    if lastPos and lastClock then
        local dt=now-lastClock
        if dt>0.25 and dt<4 then
            local delta=(pos-lastPos).Magnitude
            local speed=delta/dt
            if speed>MAX_REASONABLE_SPEED then
                s.teleports+=1
            elseif delta>=MOVING_DISTANCE then
                s.moving+=1
                s.distance+=delta
                if trackDataReady and n==0 then
                    s.movingNoTracks+=1
                end
            else
                s.still+=1
            end
        end
    end
    -- We deliberately do not call unusual Y coordinates "under map":
    -- maps have floors at different heights and spectate cameras can clip.
end

local function percentage(a,b)
    if b<=0 then return "n/a" end
    return string.format("%.0f%%",a/b*100)
end
local function sortedKeys(dict)
    local t={}
    for k in pairs(dict) do t[#t+1]=k end
    table.sort(t,function(a,b) return tostring(a)<tostring(b) end)
    return t
end
local function animationsSummary(s)
    local keys=sortedKeys(s.tracks)
    local result={}
    for i=1,math.min(#keys,4) do
        local id=keys[i]
        result[#result+1]=id.." ("..s.tracks[id]..")"
    end
    return #result>0 and table.concat(result,", ") or "none captured"
end
local function classification(s)
    if s.samples<MIN_VALID_SAMPLES then
        return "INSUFFICIENT DATA","few valid living-character samples"
    end
    if s.moving<5 then
        return "INCONCLUSIVE","not enough sustained movement to test animations"
    end
    if s.movingNoTracks>=5 and s.movingNoTracks/s.moving>=0.70 then
        return "REVIEW","moving with no locally observed playing tracks; replication may explain"
    end
    return "NO STRONG MOTION ANOMALY","no sustained missing-track signal observed"
end
local function render(final)
    local lines={}
    local count,review,unknown=0,0,0
    for _,s in pairs(stats) do
        count+=1
        local status,why=classification(s)
        if status=="REVIEW" then review+=1 end
        if status=="INSUFFICIENT DATA" or status=="INCONCLUSIVE" then unknown+=1 end
        lines[#lines+1]=string.format(
            "%s | %s | valid=%d missing=%d dead=%d moving=%d still=%d noTrackWhileMoving=%d/%d (%s) teleportLike=%d rig=%s",
            safeName(s.name),status,s.samples,s.missing,s.dead,s.moving,s.still,
            s.movingNoTracks,s.moving,percentage(s.movingNoTracks,s.moving),
            s.teleports,s.rig
        )
        if final then
            print("[P1 OBS] "..lines[#lines])
            print("[P1 OBS]   reason="..why)
            print("[P1 OBS]   playing IDs="..animationsSummary(s))
            local conf=sortedKeys(s.configured)
            local cfg={}
            for _,field in ipairs(conf) do cfg[#cfg+1]=field..":"..s.configured[field] end
            print("[P1 OBS]   description animations="..(#cfg>0 and table.concat(cfg,", ") or "none/nonzero IDs unavailable"))
        end
    end
    table.sort(lines)
    local elapsed=math.min(DURATION,os.clock()-started)
    local header=string.format("PDIDDLER BOT OBSERVER | %.0f/%ds | players=%d review=%d inconclusive=%d\nNO HOP / NO TRADES / NOT A BOT VERDICT\n",elapsed,DURATION,count,review,unknown)
    if reportLabel then
        reportLabel.Text=header..table.concat(lines,"\n")
    end
    if final then
        print("[P1 OBS] FINAL | players="..count.." review="..review.." inconclusive="..unknown)
        print("[P1 OBS] NOTE: REVIEW is not proof of a bot. Animation tracks can be unreplicated.")
    end
end

local function createGui()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",8)
    if not pg then return end
    gui=Instance.new("ScreenGui")
    gui.Name="PdiddlerBotObserverTest"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=false
    local frame=Instance.new("Frame")
    frame.Size=UDim2.new(0.88,0,0.35,0)
    frame.Position=UDim2.new(0.06,0,0.05,0)
    frame.BackgroundColor3=Color3.fromRGB(36,25,55)
    frame.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,9)
    corner.Parent=frame
    local scroll=Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,-16,1,-12)
    scroll.Position=UDim2.fromOffset(8,6)
    scroll.BackgroundTransparency=1
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.CanvasSize=UDim2.new()
    scroll.ScrollBarThickness=5
    scroll.Parent=frame
    reportLabel=Instance.new("TextLabel")
    reportLabel.Size=UDim2.new(1,-8,0,0)
    reportLabel.AutomaticSize=Enum.AutomaticSize.Y
    reportLabel.BackgroundTransparency=1
    reportLabel.TextColor3=Color3.fromRGB(255,255,255)
    reportLabel.Font=Enum.Font.Code
    reportLabel.TextSize=12
    reportLabel.TextXAlignment=Enum.TextXAlignment.Left
    reportLabel.TextYAlignment=Enum.TextYAlignment.Top
    reportLabel.TextWrapped=true
    reportLabel.Text="Starting observer..."
    reportLabel.Parent=scroll
    gui.Parent=pg
end

print("[P1 OBS] START | observation-only, 60 seconds; no hopping or trading")
pcall(createGui)
task.spawn(function()
    local nextRender=0
    while alive() and os.clock()-started<DURATION do
        local t=os.clock()
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and alive() then
                local ok,err=pcall(sample,p,t)
                if not ok then
                    local s=ensureStat(p)
                    s.missing+=1
                end
            end
        end
        if t>=nextRender then
            pcall(render,false)
            nextRender=t+5
        end
        task.wait(SAMPLE_INTERVAL)
    end
    if alive() then
        pcall(render,true)
        print("[P1 OBS] COMPLETE | screenshot GUI or copy console output; send with bot/normal label")
    end
end)
