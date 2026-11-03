-- PDIDDLER Part 1 BOT OBSERVER TEST v2
-- Standalone, read-only diagnostic. No trading, teleporting or final decisions.
-- v1 and pdiddler1_KNOWN_GOOD.lua are unchanged.
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local E=(getgenv and getgenv()) or _G
if type(E.PDIDDLER_BOT_OBSERVER_STOP)=="function" then pcall(E.PDIDDLER_BOT_OBSERVER_STOP) end
E.PDIDDLER_BOT_OBSERVER_GEN=(tonumber(E.PDIDDLER_BOT_OBSERVER_GEN) or 0)+1
local GEN=E.PDIDDLER_BOT_OBSERVER_GEN
local RUN=true
local WINDOW=60
local STEP=1
local MOVE_MIN=1.5
local MAX_SPEED=100
local MIN_VALID=20
local MIN_MOVING=10
local MIN_MISSING=8
local MISSING_RATIO=0.80
local MIN_GROUP=3
local GROUP_RATIO=0.50
local begun=os.clock()
local db={}
local screen,label
local function alive() return RUN and E.PDIDDLER_BOT_OBSERVER_GEN==GEN end
local function stop()
    RUN=false
    if screen then pcall(function() screen:Destroy() end) end
end
E.PDIDDLER_BOT_OBSERVER_STOP=stop

local function getStat(p)
    local u=p.UserId
    if not db[u] then
        db[u]={name=p.Name,uid=u,valid=0,missing=0,dead=0,move=0,
            still=0,jumps=0,noTrack=0,trackMovement=0,animatorAbsent=0,
            badReads=0,tracks={},last=nil,lastTime=nil,char=nil,
            half={{move=0,noTrack=0},{move=0,noTrack=0}},positive=false}
    end
    return db[u]
end
local function resetBaseline(s)
    s.last=nil
    s.lastTime=nil
end
local function sample(p,t)
    local s=getStat(p)
    local char=p.Character
    if char~=s.char then
        s.char=char
        resetBaseline(s)
    end
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or not root:IsA("BasePart") then
        s.missing+=1
        resetBaseline(s)
        return
    end
    if hum.Health<=0 then
        s.dead+=1
        resetBaseline(s)
        return
    end
    s.valid+=1
    local pos=root.Position
    local animator=hum:FindFirstChildOfClass("Animator")
    local count=nil
    if not animator then
        s.animatorAbsent+=1
    else
        local ok,tracks=pcall(function() return animator:GetPlayingAnimationTracks() end)
        if ok and type(tracks)=="table" then
            count=0
            for _,track in ipairs(tracks) do
                local yes=false
                pcall(function() yes=track.IsPlaying end)
                if yes then
                    count+=1
                    local id=""
                    pcall(function()
                        local a=track.Animation
                        if a then id=tostring(a.AnimationId or "") end
                    end)
                    if id~="" then s.tracks[id]=(s.tracks[id] or 0)+1 end
                end
            end
            if count>0 then s.positive=true end
        else
            s.badReads+=1
        end
    end
    local old,oldt=s.last,s.lastTime
    s.last=pos
    s.lastTime=t
    if not old or not oldt then return end
    local dt=t-oldt
    if dt<=0.4 or dt>=3 then return end
    local dist=(pos-old).Magnitude
    if dist/dt>MAX_SPEED then
        -- Can be a map teleport, replication correction or scripted movement.
        -- Exclude from animation statistics; never score it as bot evidence.
        s.jumps+=1
        return
    end
    if dist<MOVE_MIN then
        s.still+=1
        return
    end
    -- A move only becomes animation-evaluable if Animator track read succeeded.
    if count==nil then return end
    s.move+=1
    local half=(t-begun<WINDOW/2) and 1 or 2
    s.half[half].move+=1
    if count==0 then
        s.noTrack+=1
        s.half[half].noTrack+=1
    else
        s.trackMovement+=1
    end
end
local function ratio(a,b)
    return b>0 and a/b or 0
end
local function pct(a,b)
    if b==0 then return "n/a" end
    return string.format("%.0f%%",100*a/b)
end
local function verdict(s)
    if s.valid<MIN_VALID then return "UNKNOWN","character not sufficiently observed" end
    if s.move<MIN_MOVING then return "UNKNOWN","insufficient evaluable movement" end
    if s.noTrack>=MIN_MISSING and ratio(s.noTrack,s.move)>=MISSING_RATIO then
        -- Two windows lower the chance that a single loading interruption
        -- accounts for every missing animation track.
        local h1,h2=s.half[1],s.half[2]
        if h1.move>=3 and h2.move>=3 and
            ratio(h1.noTrack,h1.move)>=MISSING_RATIO and
            ratio(h2.noTrack,h2.move)>=MISSING_RATIO then
            return "REVIEW","sustained missing locally observed tracks in both windows"
        end
        return "UNKNOWN","signal concentrated in one observation window"
    end
    return "NO SIGNAL","no sustained track absence during movement"
end
local function makeReport(printFinal)
    local lines,counts={}, {review=0,unknown=0,noSignal=0,moving=0,positive=0,total=0}
    for _,s in pairs(db) do
        counts.total+=1
        local v,why=verdict(s)
        if v=="REVIEW" then counts.review+=1
        elseif v=="UNKNOWN" then counts.unknown+=1
        else counts.noSignal+=1 end
        if s.move>=MIN_MOVING then counts.moving+=1 end
        if s.positive then counts.positive+=1 end
        local line=string.format("%s | %s | valid=%d move=%d noTrack=%d/%d(%s) | halves=%d/%d,%d/%d | jumps=%d missing=%d dead=%d",
            s.name,v,s.valid,s.move,s.noTrack,s.move,pct(s.noTrack,s.move),
            s.half[1].noTrack,s.half[1].move,s.half[2].noTrack,s.half[2].move,s.jumps,s.missing,s.dead)
        lines[#lines+1]=line
        if printFinal then
            print("[P1 V2] "..line)
            print("[P1 V2] reason="..why.." | animatorAbsent="..s.animatorAbsent.." badReads="..s.badReads)
            local ids={}
            for id,n in pairs(s.tracks) do ids[#ids+1]={id=id,n=n} end
            table.sort(ids,function(a,b) return a.n>b.n end)
            for i=1,math.min(3,#ids) do
                print("[P1 V2] track "..ids[i].id.." seen="..ids[i].n)
            end
        end
    end
    table.sort(lines)
    -- A review cluster is NOT a bot verdict and is never used to hop.
    -- Track-positive peers show that this client saw SOME other-player tracks;
    -- this does not prove track absence for any specific player.
    local eligible=counts.moving
    local group=counts.review>=MIN_GROUP and eligible>=MIN_GROUP+1
        and ratio(counts.review,eligible)>=GROUP_RATIO and counts.positive>=1
    local state
    if group then state="GROUP PATTERN FOR REVIEW"
    elseif eligible<MIN_GROUP+1 then state="INSUFFICIENT GROUP DATA"
    else state="NO STRONG GROUP PATTERN OBSERVED" end
    local header=string.format(
        "PDIDDLER P1 V2 | %.0f/%ds | %s\nplayers=%d eligible=%d review=%d unknown=%d trackPositive=%d\nNO HOP / NO TRADES / NOT A BOT VERDICT\n",
        math.min(WINDOW,os.clock()-begun),WINDOW,state,counts.total,eligible,counts.review,counts.unknown,counts.positive)
    if label then label.Text=header..table.concat(lines,"\n") end
    if printFinal then
        print("[P1 V2] FINAL "..header:gsub("\n"," | "))
        print("[P1 V2] WARNING: Roblox track replication is incomplete. Pattern is not proof.")
    end
end
local function makeGui()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",8)
    if not pg or not alive() then return end
    screen=Instance.new("ScreenGui")
    screen.Name="PdiddlerObserverV2"
    screen.ResetOnSpawn=false
    local frame=Instance.new("Frame")
    frame.Size=UDim2.new(0.9,0,0.36,0)
    frame.Position=UDim2.new(0.05,0,0.05,0)
    frame.BackgroundColor3=Color3.fromRGB(36,25,55)
    frame.Parent=screen
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=frame
    local scroll=Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,-16,1,-12)
    scroll.Position=UDim2.fromOffset(8,6)
    scroll.ScrollBarThickness=4
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.CanvasSize=UDim2.new()
    scroll.BackgroundTransparency=1
    scroll.Parent=frame
    label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,-8,0,0)
    label.AutomaticSize=Enum.AutomaticSize.Y
    label.BackgroundTransparency=1
    label.TextColor3=Color3.new(1,1,1)
    label.Font=Enum.Font.Code
    label.TextSize=12
    label.TextWrapped=true
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.TextYAlignment=Enum.TextYAlignment.Top
    label.Parent=scroll
    screen.Parent=pg
end
print("[P1 V2] BEGIN | 60 seconds | diagnostic only")
pcall(makeGui)
task.spawn(function()
    local nextView=0
    while alive() and os.clock()-begun<WINDOW do
        local t=os.clock()
        for _,p in ipairs(Players:GetPlayers()) do
            if not alive() then break end
            if p~=LP then
                local ok=pcall(sample,p,t)
                if not ok then
                    local s=getStat(p)
                    s.badReads+=1
                    resetBaseline(s)
                end
            end
        end
        if t>=nextView then
            pcall(makeReport,false)
            nextView=t+5
        end
        task.wait(STEP)
    end
    if alive() then
        pcall(makeReport,true)
        print("[P1 V2] COMPLETE | Send screenshots for labeled bot and normal servers")
    end
end)
