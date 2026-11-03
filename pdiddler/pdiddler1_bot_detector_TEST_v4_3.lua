-- PDIDDLER P1 bot observer v4.3 | read-only, standalone diagnostic
-- Keeps confirmed working modules untouched. Never trades or teleports.
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local E=(getgenv and getgenv()) or _G
if type(E.PDIDDLER_BOT_OBSERVER_STOP)=="function" then pcall(E.PDIDDLER_BOT_OBSERVER_STOP) end
E.PDIDDLER_BOT_OBSERVER_GEN=(tonumber(E.PDIDDLER_BOT_OBSERVER_GEN) or 0)+1
local G=E.PDIDDLER_BOT_OBSERVER_GEN
local running=true
local T=90
local MAX_RESTARTS=2
local SETTLE_SECONDS=3
local attempts=0
local appearanceScans={}
local populationChanged=false
local membershipBaseline=nil
local changeAt=nil
local changeSerial=0
local connections={}
local phase="OBSERVING"
E.PDIDDLER_P1_EVIDENCE_V1=nil
local function playerIds()
    local ids={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then ids[#ids+1]=tostring(p.UserId) end
    end
    table.sort(ids)
    return ids
end
local function signature(ids) return table.concat(ids,",") end
local started=os.clock()
local stats,screen,display={}

local function live() return running and E.PDIDDLER_BOT_OBSERVER_GEN==G end
local function stop()
    running=false
    for _,connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
    if screen then pcall(function() screen:Destroy() end) end
end
E.PDIDDLER_BOT_OBSERVER_STOP=stop
local function markChange()
    if not live() then return end
    changeSerial+=1
    changeAt=os.clock()
    populationChanged=true
end
connections[#connections+1]=Players.PlayerAdded:Connect(function(p)
    if p~=LP then markChange() end
end)
connections[#connections+1]=Players.PlayerRemoving:Connect(function(p)
    if p~=LP then markChange() end
end)
local function resetWindow(now, ids)
    stats={}
    appearanceScans={}
    membershipBaseline=ids
    started=now
    populationChanged=false
    E.PDIDDLER_P1_EVIDENCE_V1=nil
end
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
    local r={total=0,loaded=0,simple=0,trait1=0,trait2=0,largest=0,unique=0}
    local fingerprints={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            r.total+=1
            local nt=nameTraits(p.Name)
            if nt>=1 then r.trait1+=1 end
            if nt>=2 then r.trait2+=1 end
            local c=p.Character
            local h=c and c:FindFirstChildOfClass("Humanoid")
            if h then
                local ok,d=pcall(function() return h:GetAppliedDescription() end)
                if ok and d then
                    local parts,accessories={},0
                    for _,f in ipairs(FIELDS) do
                        local got,val=pcall(function() return d[f] end)
                        if got then parts[#parts+1]=f.."="..tostring(val or "") end
                    end
                    for _,f in ipairs(ACC) do
                        local got,val=pcall(function() return d[f] end)
                        if got and val then
                            for token in tostring(val):gmatch("[^,]+") do
                                local t=token:gsub("%s+","")
                                if t~="" and t~="0" then accessories+=1 end
                            end
                        end
                    end
                    r.loaded+=1
                    if accessories<=1 then r.simple+=1 end
                    local fp=table.concat(parts,"|")
                    fingerprints[fp]=(fingerprints[fp] or 0)+1
                end
            end
        end
    end
    for _,n in pairs(fingerprints) do
        r.unique+=1
        if n>r.largest then r.largest=n end
    end
    local loadedEnough=r.total>=6 and r.loaded>=math.ceil(r.total*0.8)
    r.supporting=loadedEnough and (
        (r.largest>=5 and r.largest/r.loaded>=0.55) or
        (r.total>=8 and r.simple/r.loaded>=0.8 and r.trait1/r.total>=0.7) or
        (r.total>=9 and r.trait1/r.total>=0.9 and r.trait2/r.total>=0.55))
    r.ids=playerIds()
    return r
end
local function appearanceText()
    local t={}
    for i,r in ipairs(appearanceScans) do
        t[#t+1]=string.format("A%d loaded=%d/%d simple=%d names=%d/%d largest=%d corroborates=%s",i,r.loaded,r.total,r.simple,r.trait1,r.trait2,r.largest,tostring(r.supporting))
    end
    return table.concat(t," | ")
end

local function report(final)
    local rows={}
    local total,confirmed,partial,unknown,movable=0,0,0,0,0
    for _,s in pairs(stats) do
        -- Only assess players still present in this server.
        local p=Players:GetPlayerByUserId(s.id)
        if p and p~=LP then
            total+=1
            local v,reason=personSignal(s)
            if v=="CONFIRMED REVIEW" then confirmed+=1
            elseif v=="PARTIAL REVIEW" then partial+=1
            elseif v=="UNKNOWN" then unknown+=1 end
            if s.eval>=10 then movable+=1 end
            local line=string.format("%s | %s | valid=%d moving=%d noTracks=%d/%d(%s) windows=%d/%d,%d/%d | jumps=%d wallNear=%d still=%d",
                s.name,v,s.valid,s.eval,s.noTrack,s.eval,pct(s.noTrack,s.eval),
                s.halves[1].n,s.halves[1].m,s.halves[2].n,s.halves[2].m,
                s.jumps,s.wallNearby,s.still)
            rows[#rows+1]=line
            if final then
                print("[P1 V4.3] "..line)
                print("[P1 V4.3]   "..reason.." | animatorMissing="..s.animMissing.." badReads="..s.readFail.." dead="..s.dead.." missing="..s.missing)
            end
        end
    end
    table.sort(rows)
    local bursts=jumpSummary()
    local reviewed=confirmed+partial
    local adequate=total>=8 and movable>=6 and unknown/total<=0.35
    -- At least three two-window confirmations. Partial evidence may fill the
    -- remaining group only when appearance independently corroborates twice.
    local animationStrong=adequate and confirmed>=3 and reviewed>=6
        and reviewed/movable>=0.70 and reviewed/total>=0.55
    local a,b=appearanceScans[1],appearanceScans[2]
    local appearanceStrong=a and b and a.supporting and b.supporting
    local state
    if animationStrong and appearanceStrong then
        state="COMBINED FARM PATTERN FOR REVIEW"
    elseif animationStrong then
        state="ANIMATION CLUSTER ONLY - NO APPEARANCE CORROBORATION"
    elseif not adequate then
        state="INSUFFICIENT GROUP COVERAGE"
    else
        state="NO STRONG COMBINED PATTERN"
    end
    -- No automatic reject/hop. Missing tracks may be a replication artifact.
    local header=string.format("PDIDDLER BOT OBSERVER V4.3 | %ds/%ds | %s\nplayers=%d movingEligible=%d confirmed=%d partial=%d unknown=%d jumpsWindows=%d | restarts=%d/%d\nNO HOP / NO TRADE / NOT A BOT VERDICT\n",
        math.min(T,math.floor(os.clock()-started)),T,state,total,movable,confirmed,partial,unknown,bursts,attempts,MAX_RESTARTS)
    header=header..appearanceText().."\n"
    if display then display.Text=header..table.concat(rows,"\n") end
    if final then
        local lastIds=playerIds()
        local stable=not populationChanged and phase=="OBSERVING" and membershipBaseline~=nil
            and signature(membershipBaseline)==signature(lastIds)
            and a~=nil and b~=nil
            and signature(a.ids or {})==signature(lastIds)
            and signature(b.ids or {})==signature(lastIds)
        -- Even a strong diagnostic pattern is advisory. No hopping here.
        E.PDIDDLER_P1_EVIDENCE_V1={
            jobId=game.JobId, session=G, complete=true, observedAt=os.clock(),
            total=total,moving=movable,confirmed=confirmed,
            partial=partial,unknown=unknown,
            initialIds=membershipBaseline,appearance={
                a and {supporting=a.supporting,loaded=a.loaded,total=a.total,ids=a.ids} or {},
                b and {supporting=b.supporting,loaded=b.loaded,total=b.total,ids=b.ids} or {}
            },
            stable=stable,groupPattern=animationStrong and appearanceStrong,
            diagnosticState=state,
        }
        if not stable then
            warn("[P1 V4.3] CHURN DETECTED | results advisory, cannot hand off")
        end
        print("[P1 V4.3] FINAL "..header:gsub("\n"," | "))
        print("[P1 V4.3] Track replication, walls, and MM2 teleports are NOT proof of botting.")
    end
end
local function gui()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",8)
    if not pg or not live() then return end
    screen=Instance.new("ScreenGui")
    screen.Name="PdiddlerObserverV4.3"
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
local function markInconclusive(reason)
    E.PDIDDLER_P1_EVIDENCE_V1=nil
    phase="INCONCLUSIVE"
    local line=string.format(
        "PDIDDLER OBSERVER V4.3 | INCONCLUSIVE | %s\nrestarts=%d/%d | no valid handoff evidence\nNO HOP / NO TRADE",
        tostring(reason),attempts,MAX_RESTARTS)
    if display then display.Text=line end
    warn("[P1 V4.3] "..line:gsub("\n"," | "))
end

print("[P1 V4.3] BEGIN | 90s per stable window | max 2 restarts")
pcall(gui)
task.spawn(function()
    local nextView=0
    local pendingInitial=true
    local deadline=os.clock()+300
    while live() do
        local now=os.clock()
        if now>=deadline then
            markInconclusive("overall 300-second deadline reached")
            break
        end
        local ids=playerIds()
        if pendingInitial then
            -- First snapshot only after the player set stops changing briefly.
            if changeAt==nil then changeAt=now end
            if now-changeAt>=SETTLE_SECONDS then
                resetWindow(now,ids)
                pendingInitial=false
                print("[P1 V4.3] OBSERVING | attempt="..tostring(attempts+1))
            end
        else
            if signature(ids)~=signature(membershipBaseline) then markChange() end
            if populationChanged then
                E.PDIDDLER_P1_EVIDENCE_V1=nil
                if attempts>=MAX_RESTARTS then
                    markInconclusive("population changed after retry limit")
                    break
                end
                -- Stop sampling old roster immediately, then wait for stability.
                attempts+=1
                pendingInitial=true
                print("[P1 V4.3] RESTART "..attempts.."/"..MAX_RESTARTS.." | player population changed")
            elseif now-started>=T then
                -- Scan functions can yield; cross-check both generation and roster
                -- before publishing the final completed evidence.
                if #appearanceScans<2 then
                    markInconclusive("appearance snapshots unavailable")
                    break
                end
                local serial=changeSerial
                local before=signature(playerIds())
                if not live() or before~=signature(membershipBaseline) then
                    markChange()
                else
                    local reportOk,reportErr=pcall(report,true)
                    local after=signature(playerIds())
                    if not reportOk then
                        markInconclusive("final report failed: "..tostring(reportErr))
                    elseif changeSerial~=serial or after~=before then
                        markInconclusive("membership changed during final report")
                    else
                        print("[P1 V4.3] COMPLETE | restarts="..attempts)
                    end
                    break
                end
            else
                -- Only use the population of the current stable window.
                if #appearanceScans==0 and now-started>=20 then
                    local serial=changeSerial
                    local snapshot=appearanceScan()
                    if serial==changeSerial and signature(snapshot.ids)==signature(membershipBaseline) then
                        appearanceScans[1]=snapshot
                    else markChange() end
                end
                if #appearanceScans==1 and now-started>=70 and not populationChanged then
                    local serial=changeSerial
                    local snapshot=appearanceScan()
                    if serial==changeSerial and signature(snapshot.ids)==signature(membershipBaseline) then
                        appearanceScans[2]=snapshot
                    else markChange() end
                end
                if not populationChanged then
                    for _,p in ipairs(Players:GetPlayers()) do
                        if not live() or populationChanged then break end
                        if p~=LP then
                            local ok=pcall(sample,p,now)
                            if not ok then
                                local row=stat(p)
                                row.readFail+=1
                                clear(row)
                            end
                        end
                    end
                    if now>=nextView and not populationChanged then
                        pcall(report,false)
                        nextView=now+5
                    end
                end
            end
        end
        task.wait(1)
    end
    -- Do not destroy report GUI; remove only event listeners.
    for _,connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
end)
