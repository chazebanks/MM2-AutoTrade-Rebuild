-- PDIDDLER P1 bot observer v3 | read-only, standalone diagnostic
-- Keeps confirmed working modules untouched. Never trades or teleports.
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local E=(getgenv and getgenv()) or _G
if type(E.PDIDDLER_BOT_OBSERVER_STOP)=="function" then pcall(E.PDIDDLER_BOT_OBSERVER_STOP) end
E.PDIDDLER_BOT_OBSERVER_GEN=(tonumber(E.PDIDDLER_BOT_OBSERVER_GEN) or 0)+1
local G=E.PDIDDLER_BOT_OBSERVER_GEN
local running=true
local T=90
local started=os.clock()
local stats,frame,screen,display={}

local function live() return running and E.PDIDDLER_BOT_OBSERVER_GEN==G end
local function stop()
    running=false
    if screen then pcall(function() screen:Destroy() end) end
end
E.PDIDDLER_BOT_OBSERVER_STOP=stop
local function pct(a,b) if b==0 then return "n/a" end return string.format("%.0f%%",100*a/b) end
local function stat(p)
    local s=stats[p.UserId]
    if not s then
        s={id=p.UserId,name=p.Name,character=nil,prev=nil,when=nil,valid=0,missing=0,dead=0,
            eval=0,noTrack=0,withTrack=0,still=0,small=0,jumps=0,jumpTimes={},
            staticFacing=0,wallNearby=0,readFail=0,animMissing=0,tracks={},
            halves={{m=0,n=0},{m=0,n=0}},active=true}
        stats[p.UserId]=s
    end
    return s
end
local function clear(s) s.prev=nil s.when=nil end
local function playingTracks(h,s)
    local a=h:FindFirstChildOfClass("Animator")
    if not a then s.animMissing+=1 return nil end
    local ok,tracks=pcall(function() return a:GetPlayingAnimationTracks() end)
    if not ok or type(tracks)~="table" then s.readFail+=1 return nil end
    local n=0
    for _,tr in ipairs(tracks) do
        local active=false
        pcall(function() active=tr.IsPlaying end)
        if active then
            n+=1
            local id=""
            pcall(function()
                if tr.Animation then id=tostring(tr.Animation.AnimationId or "") end
            end)
            if id~="" then s.tracks[id]=(s.tracks[id] or 0)+1 end
        end
    end
    return n
end
local function hasWall(root,char)
    -- A wall is context, NOT a bot vote. Check only on a living, stable character.
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={char}
    local origin=root.Position+Vector3.new(0,1,0)
    local direction=root.CFrame.LookVector*2.5
    local ok,hit=pcall(function() return workspace:Raycast(origin,direction,params) end)
    return ok and hit~=nil
end
local function sample(p,now)
    local s=stat(p)
    local c=p.Character
    if c~=s.character then s.character=c clear(s) end
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not h or not root or not root:IsA("BasePart") then s.missing+=1 clear(s) return end
    if h.Health<=0 then s.dead+=1 clear(s) return end
    local pos=root.Position
    s.valid+=1
    local tracks=playingTracks(h,s)
    local old,oldt=s.prev,s.when
    s.prev=pos s.when=now
    if not old or not oldt then return end
    local dt=now-oldt
    if dt<0.45 or dt>2.5 then return end
    local dist=(pos-old).Magnitude
    local speed=dist/dt
    if speed>100 then
        s.jumps+=1
        s.jumpTimes[#s.jumpTimes+1]=now-started
        -- A global round teleport is a common alternative explanation.
        return
    end
    if dist>=1.5 then
        if tracks~=nil then
            s.eval+=1
            local i=(now-started<T/2) and 1 or 2
            s.halves[i].m+=1
            if tracks==0 then
                s.noTrack+=1
                s.halves[i].n+=1
            else
                s.withTrack+=1
            end
        end
    else
        s.still+=1
        if dist>0.3 then s.small+=1 end
        if dist<0.3 and hasWall(root,c) then
            s.wallNearby+=1
            if tracks~=nil then s.staticFacing+=1 end
        end
    end
end
local function personSignal(s)
    if s.valid<25 then return "UNKNOWN","character data incomplete" end
    local a,b=s.halves[1],s.halves[2]
    if s.eval>=10 and s.noTrack>=8 and s.noTrack/s.eval>=0.8
        and a.m>=3 and b.m>=3 and a.n/a.m>=0.8 and b.n/b.m>=0.8
    then return "ANIMATION REVIEW","no locally observed tracks while moving in both windows" end
    if s.eval>=10 then return "NO ANIMATION SIGNAL","movement tracked with no sustained missing-track pattern" end
    return "UNKNOWN","insufficient evaluable movement; wall or jumps alone do not classify"
end
local function jumpSummary()
    local bins,byPlayer={},{}
    for id,s in pairs(stats) do
        for _,t in ipairs(s.jumpTimes) do
            local bin=math.floor(t/3)
            bins[bin]=bins[bin] or {}
            bins[bin][id]=true
        end
    end
    local bursts=0
    for _,group in pairs(bins) do
        local distinct=0
        for id in pairs(group) do distinct+=1 end
        if distinct>=3 then bursts+=1 end
    end
    return bursts
end
local function report(final)
    local rows={}
    local total,review,unknown,withSignal,movable=0,0,0,0,0
    for _,s in pairs(stats) do
        total+=1
        local v,reason=personSignal(s)
        if v=="ANIMATION REVIEW" then review+=1
        elseif v=="UNKNOWN" then unknown+=1
        else withSignal+=1 end
        if s.eval>=10 then movable+=1 end
        local line=string.format("%s | %s | valid=%d moving=%d noTracks=%d/%d(%s) windows=%d/%d,%d/%d | jumps=%d wallNear=%d still=%d",
            s.name,v,s.valid,s.eval,s.noTrack,s.eval,pct(s.noTrack,s.eval),
            s.halves[1].n,s.halves[1].m,s.halves[2].n,s.halves[2].m,
            s.jumps,s.wallNearby,s.still)
        rows[#rows+1]=line
        if final then
            print("[P1 V3] "..line)
            print("[P1 V3]   "..reason.." | animatorMissing="..s.animMissing.." badReads="..s.readFail.." dead="..s.dead.." missing="..s.missing)
            local top={}
            for id,n in pairs(s.tracks) do top[#top+1]={id=id,count=n} end
            table.sort(top,function(x,y) return x.count>y.count end)
            for i=1,math.min(2,#top) do print("[P1 V3]   animation "..top[i].id.." x"..top[i].count) end
        end
    end
    table.sort(rows)
    local bursts=jumpSummary()
    local state
    if review>=3 and movable>=4 and review/movable>=0.5 then
        state="ANIMATION CLUSTER FOR REVIEW"
    elseif movable<4 then state="INSUFFICIENT MOVING-PLAYER COVERAGE"
    else state="NO STRONG ANIMATION CLUSTER" end
    -- Jump bursts and wall checks are diagnostic context, never rejection votes.
    local header=string.format("PDIDDLER BOT OBSERVER V3 | %ds/%ds | %s\nplayers=%d movingEligible=%d review=%d unknown=%d synchronizedJumpWindows=%d\nNO HOP / NO TRADE / NO AUTOMATIC BOT VERDICT\n",
        math.min(T,math.floor(os.clock()-started)),T,state,total,movable,review,unknown,bursts)
    if display then display.Text=header..table.concat(rows,"\n") end
    if final then
        print("[P1 V3] FINAL "..header:gsub("\n"," | "))
        print("[P1 V3] Jumps can be normal MM2 round transitions; wall proximity does not prove botting.")
    end
end
local function gui()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",8)
    if not pg or not live() then return end
    screen=Instance.new("ScreenGui")
    screen.Name="PdiddlerObserverV3"
    screen.ResetOnSpawn=false
    local bg=Instance.new("Frame")
    bg.Size=UDim2.new(0.90,0,0.38,0)
    bg.Position=UDim2.new(0.05,0,0.06,0)
    bg.BackgroundColor3=Color3.fromRGB(36,25,55)
    bg.Parent=screen
    local radius=Instance.new("UICorner")
    radius.CornerRadius=UDim.new(0,8)
    radius.Parent=bg
    local scroll=Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,-14,1,-12)
    scroll.Position=UDim2.fromOffset(7,6)
    scroll.BackgroundTransparency=1
    scroll.ScrollBarThickness=5
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.CanvasSize=UDim2.new()
    scroll.Parent=bg
    display=Instance.new("TextLabel")
    display.Size=UDim2.new(1,-8,0,0)
    display.AutomaticSize=Enum.AutomaticSize.Y
    display.BackgroundTransparency=1
    display.TextColor3=Color3.new(1,1,1)
    display.Font=Enum.Font.Code
    display.TextSize=12
    display.TextWrapped=true
    display.TextXAlignment=Enum.TextXAlignment.Left
    display.TextYAlignment=Enum.TextYAlignment.Top
    display.Parent=scroll
    screen.Parent=pg
end
print("[P1 V3] BEGIN | 90-second observation only")
pcall(gui)
task.spawn(function()
    local nextView=0
    while live() and os.clock()-started<T do
        local now=os.clock()
        for _,p in ipairs(Players:GetPlayers()) do
            if not live() then break end
            if p~=LP then
                local ok=pcall(sample,p,now)
                if not ok then
                    local s=stat(p)
                    s.readFail+=1
                    clear(s)
                end
            end
        end
        if now>=nextView then pcall(report,false) nextView=now+5 end
        task.wait(1)
    end
    if live() then
        pcall(report,true)
        print("[P1 V3] COMPLETE | Send labeled bot or normal server results")
    end
end)
