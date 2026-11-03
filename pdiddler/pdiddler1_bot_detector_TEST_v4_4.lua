-- PDIDDLER P1 bot observer v4.4 | read-only, standalone diagnostic
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
local stats={}
local screen,display
local connections={}
local appearanceScans={}
local finished=false
local MAX_RUNTIME=120
-- v4.4 does not publish the older schema: v1 requires identical rosters
-- and must not accidentally consume a cohort-based result.
E.PDIDDLER_P1_EVIDENCE_V1=nil
E.PDIDDLER_P1_COHORT_EVIDENCE_V2=nil
local function playerIds()
    local ids={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then ids[#ids+1]=tostring(p.UserId) end
    end
    table.sort(ids)
    return ids
end
local function live() return not finished and E.PDIDDLER_BOT_OBSERVER_GEN==G end
local function stop()
    finished=true
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if screen then pcall(function() screen:Destroy() end) end
    E.PDIDDLER_P1_COHORT_EVIDENCE_V2=nil
end
E.PDIDDLER_BOT_OBSERVER_STOP=stop
local function pct(a,b)a,b) if b==0 then return "n/a" end return string.format("%.0f%%",100*a/b) end
local function stat(p)
    local s=stats[p.UserId]
    if not s then
        s={id=p.UserId,name=p.Name,character=nil,prev=nil,when=nil,valid=0,missing=0,dead=0,
            eval=0,noTrack=0,withTrack=0,still=0,small=0,jumps=0,jumpTimes={},
            staticFacing=0,wallNearby=0,readFail=0,animMissing=0,tracks={},
            halves={{m=0,n=0},{m=0,n=0}},firstSeen=os.clock(),active=true}
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
            local i=(now-s.firstSeen<T/2) and 1 or 2
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
    if s.eval<10 then return "UNKNOWN","insufficient evaluable movement" end
    local a,b=s.halves[1],s.halves[2]
    local ratio=s.noTrack/s.eval
    if s.noTrack>=8 and ratio>=0.80 then
        if a.m>=3 and b.m>=3 and a.n/a.m>=0.80 and b.n/b.m>=0.80 then
            return "CONFIRMED REVIEW","missing locally observed tracks in both windows"
        end
        -- Retain usable evidence with uneven movement rather than labeling
        -- 100% missing-track players as NO SIGNAL.
        return "PARTIAL REVIEW","high missing-track ratio; uneven window coverage"
    end
    return "NO ANIMATION SIGNAL","no sustained missing-track pattern"
end
local function jumpSummary()
    local bins={}
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

-- Independent appearance scan. A subset of frozen Part 1's signals, not a
-- second execution of that module (which would block startup).
local ACC={"HatAccessory","HairAccessory","FaceAccessory","NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory"}
local FIELDS={"Shirt","Pants","GraphicTShirt","Face","Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","HatAccessory","HairAccessory","FaceAccessory","NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory"}
local function nameTraits(name)
    local compact=tostring(name):gsub("[^%w]","")
    local lower=compact:lower()
    local letters=compact:gsub("[^A-Za-z]","")
    local n=0
    local suffix=compact:match("(%d+)$")
    if suffix and #suffix>=4 then n+=1 end
    local changes=0
    for i=2,#letters do
        local a,b=letters:sub(i-1,i-1),letters:sub(i,i)
        if (a:match("%l") and b:match("%u")) or (a:match("%u") and b:match("%l")) then changes+=1 end
    end
    if changes>=3 then n+=1 end
    if lower:find("qwe",1,true) or lower:find("asd",1,true) or lower:find("zxc",1,true) then n+=1 end
    if #compact>=17 then n+=1 end
    local body=suffix and compact:sub(1,#compact-#suffix) or compact
    if body:find("%d") then n+=1 end
    local _,vowels=letters:lower():gsub("[aeiou]","")
    if #letters>=10 and vowels/math.max(1,#letters)<0.18 then n+=1 end
    return n
end
local function appearanceScan()
    -- Store per-player data; aggregate only over the same stable cohort later.
    local out={byId={},at=os.clock()}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                local ok,d=pcall(function() return hum:GetAppliedDescription() end)
                if ok and d then
                    local attrs,accessories={},0
                    for _,field in ipairs(FIELDS) do
                        local success,value=pcall(function() return d[field] end)
                        if success then attrs[#attrs+1]=field.."="..tostring(value or "") end
                    end
                    for _,field in ipairs(ACC) do
                        local success,value=pcall(function() return d[field] end)
                        if success and value then
                            for token in tostring(value):gmatch("[^,]+") do
                                local t=token:gsub("%s+","")
                                if t~="" and t~="0" then accessories+=1 end
                            end
                        end
                    end
                    out.byId[tostring(p.UserId)]={
                        fp=table.concat(attrs,"|"),
                        accessories=accessories,
                        traits=nameTraits(p.Name)
                    }
                end
            end
        end
    end
    return out
end
local function cohort()
    if #appearanceScans<2 then return {},{} end
    local a,b=appearanceScans[1],appearanceScans[2]
    local players={}
    local ids={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local k=tostring(p.UserId)
            if a.byId[k] and b.byId[k] and stats[p.UserId] then
                players[#players+1]=p
                ids[#ids+1]=k
            end
        end
    end
    table.sort(ids)
    return players,ids
end
local function aggregate(scan,ids)
    local r={total=#ids,loaded=0,simple=0,trait1=0,trait2=0,largest=0}
    local fingerprints={}
    for _,id in ipairs(ids) do
        local d=scan.byId[id]
        if d then
            r.loaded+=1
            if d.accessories<=1 then r.simple+=1 end
            if d.traits>=1 then r.trait1+=1 end
            if d.traits>=2 then r.trait2+=1 end
            fingerprints[d.fp]=(fingerprints[d.fp] or 0)+1
        end
    end
    for _,n in pairs(fingerprints) do r.largest=math.max(r.largest,n) end
    local sufficient=r.total>=8 and r.loaded>=math.ceil(r.total*.8)
    r.supporting=sufficient and (
        (r.largest>=5 and r.largest/r.loaded>=.55) or
        (r.simple/r.loaded>=.8 and r.trait1/r.total>=.7) or
        (r.total>=9 and r.trait1/r.total>=.9 and r.trait2/r.total>=.55))
    return r
end
local function report(final)
    local members,ids=cohort()
    local now=os.clock()
    local rows={}
    local total,confirmed,partial,unknown,movable=0,0,0,0,0
    local selected={}
    for _,p in ipairs(members) do
        local row=stats[p.UserId]
        -- Joining near the first scan still requires a full personal observation
        -- period for two-window confirmation.
        if row then
            total+=1
            selected[p.UserId]=true
            local v,reason=personSignal(row)
            if v=="CONFIRMED REVIEW" then confirmed+=1
            elseif v=="PARTIAL REVIEW" then partial+=1
            elseif v=="UNKNOWN" then unknown+=1 end
            if row.eval>=10 then movable+=1 end
            local line=string.format("%s | %s | valid=%d moving=%d missingTracks=%d/%d(%s) windows=%d/%d,%d/%d",
                row.name,v,row.valid,row.eval,row.noTrack,row.eval,pct(row.noTrack,row.eval),
                row.halves[1].n,row.halves[1].m,row.halves[2].n,row.halves[2].m)
            rows[#rows+1]=line
            if final then print("[P1 V4.4] "..line.." | "..reason) end
        end
    end
    table.sort(rows)
    local a,b=appearanceScans[1],appearanceScans[2]
    local aggA=a and aggregate(a,ids) or nil
    local aggB=b and aggregate(b,ids) or nil
    local reviewed=confirmed+partial
    local adequate=total>=8 and movable>=6 and unknown/total<=.35
    local animationStrong=adequate and confirmed>=3 and reviewed>=6
        and reviewed/movable>=.70 and reviewed/total>=.55
    local appearances=aggA and aggB and aggA.supporting and aggB.supporting
    local state
    if total<8 then state="INSUFFICIENT STABLE COHORT"
    elseif animationStrong and appearances then state="COMBINED FARM PATTERN FOR REVIEW"
    elseif animationStrong then state="ANIMATION PATTERN ONLY"
    elseif not adequate then state="INSUFFICIENT MOVEMENT COVERAGE"
    else state="NO STRONG COMBINED PATTERN" end
    local recentCount=#playerIds()
    local text=string.format(
        "PDIDDLER V4.4 | %ds/%ds | %s\ncohort=%d currentPlayers=%d moving=%d confirmed=%d partial=%d unknown=%d\nNo automatic hopping or trading\n",
        math.min(T,math.floor(now-started)),T,state,total,recentCount,movable,confirmed,partial,unknown)
    if aggA and aggB then
        text=text..string.format("A1 simple=%d names=%d/%d largest=%d support=%s | A2 simple=%d names=%d/%d largest=%d support=%s\n",
            aggA.simple,aggA.trait1,aggA.trait2,aggA.largest,tostring(aggA.supporting),
            aggB.simple,aggB.trait1,aggB.trait2,aggB.largest,tostring(aggB.supporting))
    end
    if display then display.Text=text..table.concat(rows,"\n") end
    if final then
        print("[P1 V4.4] FINAL "..text:gsub("\n"," | "))
        -- Advisory-only schema; the existing P5 policy does not accept it.
        E.PDIDDLER_P1_COHORT_EVIDENCE_V2={
            jobId=game.JobId,session=G,observedAt=os.clock(),complete=true,
            cohortIds=ids,total=total,moving=movable,confirmed=confirmed,
            partial=partial,unknown=unknown,groupPattern=animationStrong and appearances,
            diagnosticState=state,compatibleWithPart5=false
        }
    end
end
local function gui()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",8)
    if not pg or not live() then return end
    screen=Instance.new("ScreenGui")
    screen.Name="PdiddlerObserverV4.4"
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
local function finalInconclusive(why)
    E.PDIDDLER_P1_COHORT_EVIDENCE_V2=nil
    local msg="PDIDDLER V4.4 | INCONCLUSIVE | "..tostring(why).."\nNO HOP / NO TRADE"
    if display then display.Text=msg end
    warn("[P1 V4.4] "..msg:gsub("\n"," | "))
end
print("[P1 V4.4] BEGIN | fixed 90s window | per-player preservation")
pcall(gui)
task.spawn(function()
    local nextRender=0
    while live() and os.clock()-started<T do
        local now=os.clock()
        if #appearanceScans==0 and now-started>=20 then
            local ok,snapshot=pcall(appearanceScan)
            if ok then appearanceScans[1]=snapshot end
        end
        if #appearanceScans==1 and now-started>=70 then
            local ok,snapshot=pcall(appearanceScan)
            if ok then appearanceScans[2]=snapshot end
        end
        for _,p in ipairs(Players:GetPlayers()) do
            if not live() then break end
            if p~=LP then
                local ok=pcall(sample,p,now)
                if not ok then
                    local row=stat(p)
                    row.readFail+=1
                    clear(row)
                end
            end
        end
        if now>=nextRender then
            -- UI refresh only; insufficient cohort before second scan is expected.
            pcall(report,false)
            nextRender=now+5
        end
        task.wait(1)
    end
    if live() then
        if #appearanceScans<2 then
            finalInconclusive("missing appearance snapshots")
        else
            local oldIds=playerIds()
            local ok,err=pcall(report,true)
            if not ok then finalInconclusive("report error: "..tostring(err))
            elseif table.concat(oldIds,",")~=table.concat(playerIds(),",") then
                finalInconclusive("roster changed during final report")
            else
                print("[P1 V4.4] COMPLETE")
            end
        end
    end
    finished=true
end)
