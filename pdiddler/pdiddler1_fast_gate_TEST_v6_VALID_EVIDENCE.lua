-- PDIDDLER P1 FAST GATE V6 | measurement-focused 10-second test
-- Existing thresholds/scoring retained; incomplete/stale evidence is rejected.
-- Does not execute trade actions, change servers, or allow Part 5 to hop.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local LP=Players.LocalPlayer
local E=(getgenv and getgenv()) or _G
if type(E.PDIDDLER_FAST_GATE_STOP)=="function" then pcall(E.PDIDDLER_FAST_GATE_STOP) end
E.PDIDDLER_FAST_GATE_GEN=(tonumber(E.PDIDDLER_FAST_GATE_GEN) or 0)+1
local gen=E.PDIDDLER_FAST_GATE_GEN
local jobId=game.JobId
local alive=true
local t0=os.clock()
local END_AT=t0+10
local gui,label
local rows={}
local appearance={}
local attempts={}
local failures={}
local samples=0
local lastSample=0
local closed=false
local sampling=false
E.PDIDDLER_FAST_GATE_RESULT=nil
local function live() return alive and E.PDIDDLER_FAST_GATE_GEN==gen and game.JobId==jobId end
local function roster()
    local ids={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then ids[#ids+1]=tostring(p.UserId) end end
    table.sort(ids)
    return table.concat(ids,",")
end
local function status(message)
    if label then label.Text=message end
end
local function setupGui()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",2)
    if not pg or not live() then return end
    gui=Instance.new("ScreenGui")
    gui.Name="PdiddlerFastGateV6"
    gui.ResetOnSpawn=false
    local frame=Instance.new("Frame")
    frame.Size=UDim2.new(.90,0,0,170)
    frame.Position=UDim2.new(.05,0,.12,0)
    frame.BackgroundColor3=Color3.fromRGB(36,25,55)
    frame.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,9)
    corner.Parent=frame
    label=Instance.new("TextLabel")
    label.Position=UDim2.fromOffset(10,8)
    label.Size=UDim2.new(1,-20,1,-16)
    label.BackgroundTransparency=1
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.TextYAlignment=Enum.TextYAlignment.Top
    label.TextColor3=Color3.new(1,1,1)
    label.Font=Enum.Font.Code
    label.TextSize=13
    label.TextWrapped=true
    label.Text="PDIDDLER FAST GATE V6 | collecting evidence"
    label.Parent=frame
    gui.Parent=pg
end
pcall(setupGui)
local function stop()
    alive=false
    if gui then pcall(function() gui:Destroy() end) end
end
E.PDIDDLER_FAST_GATE_STOP=stop

-- Frozen Part1 scoring function (same implementation, no custom scoring).
local function createScanner()
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer

    local C = {
        BotWaitForLobby = 6,
        BotConfirmDelay = 2.5,
        BotMinPlayers = 6,
        BotThreshold = 60,

        BotStrongClusterRatio = 0.55,
        BotStrongClusterMin = 5,
        BotMediumClusterRatio = 0.45,
        BotMediumClusterMin = 4,

        BotNewAccountDays = 30,
        BotVeryNewDays = 7,

        -- New diversified-farm rule.
        DiversifiedMinPlayers = 8,

        -- Strong diversified rule.
        DiversifiedSimpleRatio = 0.80,  -- >=80% avatars have <=1 accessory
        DiversifiedTrait1Ratio = 0.70,  -- >=70% usernames show >=1 generated trait
        DiversifiedTrait2Ratio = 0.40,  -- >=40% usernames show >=2 generated traits

        -- Medium diversified rule.
        DiversifiedMediumSimpleRatio = 0.70,
        DiversifiedMediumTrait1Ratio = 0.60,
        DiversifiedMediumTrait2Ratio = 0.30,

        -- Narrow rule added after a confirmed bot lobby scored only 45:
        -- 11/11 avatars had <=1 accessory, 9/11 names had >=1 generated trait,
        -- and 4/11 had >=2 generated traits.
        NearUniformMinPlayers = 9,
        NearUniformSimpleRatio = 0.90,
        NearUniformTrait1Ratio = 0.80,
        NearUniformTrait2Ratio = 0.30,

        -- Confirmed missed-bot pattern:
        -- usernames can be overwhelmingly generated even when avatars are diversified.
        NameMajorityMinPlayers = 9,
        NameMajorityTrait1Ratio = 0.90,
        NameMajorityTrait2Ratio = 0.55,

        -- Confirmed missed-bot pattern:
        -- 9/11 avatars had <=1 accessory and 10/11 names had >=1 generated trait,
        -- while only 1/11 had >=2 traits.
        BroadSimpleNameMinPlayers = 9,
        BroadSimpleRatio = 0.80,
        BroadTrait1Ratio = 0.90,

        -- Confirmed missed-bot pattern:
        -- 11/11 usernames had >=1 generated trait and 8/11 avatars were simple.
        -- This rule requires an almost unanimous weak-name signal so the simple-avatar
        -- threshold can safely be lower.
        NearUnanimousNameMinPlayers = 9,
        NearUnanimousTrait1Ratio = 0.95,
        NearUnanimousSimpleRatio = 0.70,
    }

    local DESC_FIELDS = {
        "Shirt","Pants","GraphicTShirt","Face","Head","Torso",
        "LeftArm","RightArm","LeftLeg","RightLeg",
        "HatAccessory","HairAccessory","FaceAccessory","NeckAccessory",
        "ShouldersAccessory","ShoulderAccessory","FrontAccessory",
        "BackAccessory","WaistAccessory"
    }

    local ACCESSORY_FIELDS = {
        "HatAccessory",
        "HairAccessory",
        "FaceAccessory",
        "NeckAccessory",
        "ShouldersAccessory",
        "ShoulderAccessory",
        "FrontAccessory",
        "BackAccessory",
        "WaistAccessory",
    }

    local function splitCount(v)
        local s = tostring(v or "")
        if s == "" or s == "0" then
            return 0
        end

        local n = 0
        for token in s:gmatch("[^,]+") do
            token = token:gsub("%s+","")
            if token ~= "" and token ~= "0" then
                n += 1
            end
        end
        return n
    end

    local function avatarData(plr)
        local char = plr and plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then
            return nil
        end

        local okDesc, desc = pcall(function()
            return hum:GetAppliedDescription()
        end)

        if not live() or plr.Character~=char or not okDesc or not desc then
            return nil
        end
        local function fieldValid(value)
            return type(value)=="string" or type(value)=="number"
                and value==value and value~=math.huge and value~=-math.huge
        end
        -- Missing fields must not collapse unrelated avatars into one empty
        -- fingerprint. ShoulderAccessory is a compatibility alias; one works.
        local shoulderReadable=false

        local parts = {}
        for _, field in ipairs(DESC_FIELDS) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if okField and fieldValid(val) then
                parts[#parts+1] = field.."="..tostring(val)
                if field=="ShoulderAccessory" or field=="ShouldersAccessory" then shoulderReadable=true end
            elseif field~="ShoulderAccessory" and field~="ShouldersAccessory" then
                return nil
            end
        end

        for _, field in ipairs({
            "BodyTypeScale","DepthScale","HeadScale",
            "HeightScale","ProportionScale","WidthScale"
        }) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if not okField or type(val)~="number" or not fieldValid(val) then return nil end
            parts[#parts+1] = field.."="..string.format("%.2f",val)
        end

        if not shoulderReadable then return nil end
        local accessoryCount = 0
        for _, field in ipairs(ACCESSORY_FIELDS) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if okField then
                accessoryCount += splitCount(val)
            end
        end

        return {
            fingerprint = table.concat(parts, "|"),
            accessories = accessoryCount,
        }
    end

    local function alphaPrefix(name)
        name = tostring(name or ""):lower():gsub("[^a-z0-9]", "")
        local p = name:match("^([a-z]+)")
        if not p or #p < 5 then
            return ""
        end
        return p:sub(1, 5)
    end

    local function generatedTraits(name)
        local raw = tostring(name or "")
        local compact = raw:gsub("[^%w]", "")
        local lower = compact:lower()
        local traits = 0

        local suffix = compact:match("(%d+)$")
        if suffix and #suffix >= 4 then
            traits += 1
        end

        local letters = compact:gsub("[^A-Za-z]", "")
        local transitions = 0

        for i = 2, #letters do
            local a = letters:sub(i-1, i-1)
            local b = letters:sub(i, i)

            if (a:match("%l") and b:match("%u"))
                or (a:match("%u") and b:match("%l"))
            then
                transitions += 1
            end
        end

        if transitions >= 3 then
            traits += 1
        end

        if lower:find("qwe",1,true)
            or lower:find("asd",1,true)
            or lower:find("zxc",1,true)
        then
            traits += 1
        end

        if #compact >= 17 then
            traits += 1
        end

        local body =
            suffix and compact:sub(1, #compact - #suffix)
            or compact

        if body:find("%d") then
            traits += 1
        end

        local _, vowels =
            letters:lower():gsub("[aeiou]", "")

        if #letters >= 10
            and vowels / math.max(1, #letters) < 0.18
        then
            traits += 1
        end

        return traits
    end

    local function scan()
        local others = {}

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                others[#others+1] = p
            end
        end

        local total = #others

        local fingerprints = {}
        local prefixes = {}

        local loaded = 0
        local new30 = 0
        local new7 = 0

        local generated1 = 0
        local generated2 = 0

        local simple1 = 0
        local simple2 = 0

        local generatedNames = {}

        for _, p in ipairs(others) do
            if not live() then return nil end
            local av = avatarData(p)
            if not live() then return nil end

            if av then
                loaded += 1

                fingerprints[av.fingerprint] =
                    fingerprints[av.fingerprint] or {}

                table.insert(
                    fingerprints[av.fingerprint],
                    p
                )

                if av.accessories <= 1 then
                    simple1 += 1
                end

                if av.accessories <= 2 then
                    simple2 += 1
                end
            end

            local age = tonumber(p.AccountAge) or 999999

            if age <= C.BotNewAccountDays then
                new30 += 1
            end

            if age <= C.BotVeryNewDays then
                new7 += 1
            end

            local prefix = alphaPrefix(p.Name)

            if prefix ~= "" then
                prefixes[prefix] =
                    prefixes[prefix] or {}

                table.insert(prefixes[prefix], p)
            end

            local traits = generatedTraits(p.Name)

            if traits >= 1 then
                generated1 += 1
            end

            if traits >= 2 then
                generated2 += 1
                generatedNames[#generatedNames+1] = p
            end
        end

        local largest = {}
        local unique = 0
        local repeatedGroups = 0
        local repeatedMembers = 0

        for _, group in pairs(fingerprints) do
            unique += 1

            if #group > #largest then
                largest = group
            end

            if #group >= 2 then
                repeatedGroups += 1
                repeatedMembers += #group
            end
        end

        local prefixLargest = {}

        for _, group in pairs(prefixes) do
            if #group > #prefixLargest then
                prefixLargest = group
            end
        end

        local loadedDen = math.max(1, loaded)
        local totalDen = math.max(1, total)

        local cluster = #largest
        local clusterRatio = cluster / loadedDen
        local new30Ratio = new30 / totalDen
        local new7Ratio = new7 / totalDen
        local prefixRatio = #prefixLargest / totalDen

        local trait1Ratio = generated1 / totalDen
        local trait2Ratio = generated2 / totalDen
        local simple1Ratio = simple1 / loadedDen
        local simple2Ratio = simple2 / loadedDen

        local repeatedRatio = repeatedMembers / loadedDen

        local minPlayers = math.max(2, C.BotMinPlayers)
        local score = 0
        local reasons = {}

        -- Proven old exact-avatar rules.
        if loaded >= minPlayers
            and cluster >= C.BotStrongClusterMin
            and clusterRatio >= C.BotStrongClusterRatio
        then
            score += 70
            reasons[#reasons+1] =
                ("identical avatar cluster %d/%d (%.0f%%)"):format(
                    cluster,
                    loaded,
                    clusterRatio * 100
                )

        elseif loaded >= minPlayers
            and cluster >= C.BotMediumClusterMin
            and clusterRatio >= C.BotMediumClusterRatio
        then
            score += cluster >= 5 and 60 or 45
            reasons[#reasons+1] =
                ("large avatar cluster %d/%d (%.0f%%)"):format(
                    cluster,
                    loaded,
                    clusterRatio * 100
                )
        end

        if loaded >= minPlayers
            and loaded >= math.floor(total * 0.70)
        then
            local diversity = unique / loadedDen

            if diversity <= 0.30 then
                score += 25
                reasons[#reasons+1] =
                    ("low avatar diversity %d unique/%d loaded"):format(
                        unique,
                        loaded
                    )

            elseif diversity <= 0.45 then
                score += 12
                reasons[#reasons+1] =
                    ("reduced avatar diversity %d/%d"):format(
                        unique,
                        loaded
                    )
            end
        end

        if loaded >= math.max(minPlayers, 8)
            and repeatedGroups >= 2
            and repeatedMembers >= 6
            and repeatedRatio >= 0.55
        then
            score += 60
            reasons[#reasons+1] =
                ("multiple repeated avatar groups %d/%d across %d groups"):format(
                    repeatedMembers,
                    loaded,
                    repeatedGroups
                )

        elseif loaded >= minPlayers
            and repeatedGroups >= 2
            and repeatedMembers >= 5
            and repeatedRatio >= 0.45
        then
            score += 25
            reasons[#reasons+1] =
                ("possible repeated avatar groups %d/%d across %d groups"):format(
                    repeatedMembers,
                    loaded,
                    repeatedGroups
                )
        end

        if total >= minPlayers
            and new7Ratio >= 0.45
        then
            score += 25
            reasons[#reasons+1] =
                ("%.0f%% accounts <=%d days old"):format(
                    new7Ratio * 100,
                    C.BotVeryNewDays
                )

        elseif total >= minPlayers
            and new30Ratio >= 0.60
        then
            score += 18
            reasons[#reasons+1] =
                ("%.0f%% accounts <=%d days old"):format(
                    new30Ratio * 100,
                    C.BotNewAccountDays
                )
        end

        if total >= minPlayers
            and #prefixLargest >= 4
            and prefixRatio >= 0.40
        then
            score += 12
            reasons[#reasons+1] =
                ("username-prefix cluster %d/%d"):format(
                    #prefixLargest,
                    total
                )
        end

        -- Near-unanimous weak-name + simple-avatar rule.
        -- Added after a confirmed bot lobby showed 11/11 usernames with >=1
        -- generated trait and 8/11 avatars with <=1 accessory.
        if total >= C.NearUnanimousNameMinPlayers
            and loaded >= math.floor(total * 0.80)
            and trait1Ratio >= C.NearUnanimousTrait1Ratio
            and simple1Ratio >= C.NearUnanimousSimpleRatio
        then
            score += 70

            reasons[#reasons+1] =
                ("near-unanimous generated-name/simple-avatar farm: trait1 %.0f%% | simple avatars %.0f%%"):format(
                    trait1Ratio * 100,
                    simple1Ratio * 100
                )
        end

        -- Broad simple-avatar + weak-name-majority rule.
        -- Added after a confirmed bot lobby showed 9/11 simple avatars,
        -- 10/11 usernames with >=1 generated trait, but only 1/11 with >=2.
        if total >= C.BroadSimpleNameMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.BroadSimpleRatio
            and trait1Ratio >= C.BroadTrait1Ratio
        then
            score += 70

            reasons[#reasons+1] =
                ("broad simple-avatar/name bot farm: simple avatars %.0f%% | generated-name trait1 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100
                )
        end

        -- Strong generated-name-majority rule.
        -- Added after a confirmed bot lobby showed:
        -- 11/11 names with >=1 generated-name trait and 7/11 with >=2,
        -- while avatar repetition/simple-avatar ratios were not strong enough.
        if total >= C.NameMajorityMinPlayers
            and trait1Ratio >= C.NameMajorityTrait1Ratio
            and trait2Ratio >= C.NameMajorityTrait2Ratio
        then
            score += 70

            reasons[#reasons+1] =
                ("generated-name majority bot farm: trait1 %.0f%% | trait2 %.0f%%"):format(
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )
        end

        -- Narrow diversified-farm override:
        -- catches lobbies where almost every avatar is extremely simple AND
        -- most usernames look generated, even if exact avatar duplication is low.
        if total >= C.NearUniformMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.NearUniformSimpleRatio
            and trait1Ratio >= C.NearUniformTrait1Ratio
            and trait2Ratio >= C.NearUniformTrait2Ratio
        then
            score += 70

            reasons[#reasons+1] =
                ("near-uniform simple-avatar bot farm: simple avatars %.0f%% | generated-name trait1 %.0f%% | trait2 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )
        end

        -- New diversified-farm rule.
        if not (
            total >= C.NearUniformMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.NearUniformSimpleRatio
            and trait1Ratio >= C.NearUniformTrait1Ratio
            and trait2Ratio >= C.NearUniformTrait2Ratio
        )
            and total >= C.DiversifiedMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.DiversifiedSimpleRatio
            and trait1Ratio >= C.DiversifiedTrait1Ratio
            and trait2Ratio >= C.DiversifiedTrait2Ratio
        then
            score += 80

            reasons[#reasons+1] =
                ("diversified bot farm: simple avatars %.0f%% | generated-name trait1 %.0f%% | trait2 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )

        elseif total >= C.DiversifiedMinPlayers
            and loaded >= math.floor(total * 0.70)
            and simple1Ratio >= C.DiversifiedMediumSimpleRatio
            and trait1Ratio >= C.DiversifiedMediumTrait1Ratio
            and trait2Ratio >= C.DiversifiedMediumTrait2Ratio
        then
            score += 45

            reasons[#reasons+1] =
                ("possible diversified farm: simple avatars %.0f%% | trait1 %.0f%% | trait2 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )
        end

        local names = {}

        local reportGroup =
            (#generatedNames >= 5)
            and generatedNames
            or largest

        for _, p in ipairs(reportGroup) do
            names[#names+1] =
                p.Name.."("..tostring(p.AccountAge).."d)"
        end

        return {
            total = total,
            loaded = loaded,

            score = score,
            bot =
                total >= minPlayers
                and score >= C.BotThreshold,

            reasons =
                #reasons > 0
                and table.concat(reasons, " | ")
                or "no strong bot pattern",

            clusterNames = names,

            cluster = cluster,
            simple1 = simple1,
            simple2 = simple2,
            simple1Ratio = simple1Ratio,
            simple2Ratio = simple2Ratio,

            trait1 = generated1,
            trait2 = generated2,
            trait1Ratio = trait1Ratio,
            trait2Ratio = trait2Ratio,

            repeatedMembers = repeatedMembers,
        }
    end


    return scan
end


-- Each character instance maintains independent history, including a respawn.
-- Missing animator, dead characters, teleporting and missing replication
-- are never counted as strong animation evidence.
local function measure(now)
    if sampling then return end
    sampling=true
    for _,p in ipairs(Players:GetPlayers()) do
        if not live() then break end
        if p~=LP then
            local id=p.UserId
            local char=p.Character
            local h=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local s=rows[id]
            if not s or s.player~=p or s.char~=char then
                s={player=p,char=char,last=nil,when=nil,moving=0,
                   absence=0,present=0,still=0,teleports=0,bad=0,
                   early=0,late=0,earlyAbsent=0,lateAbsent=0}
                rows[id]=s
            end
            if h and root and root:IsA("BasePart") and h.Health>0 then
                local old,prev=s.last,s.when
                s.last=root.Position s.when=now
                if old and prev then
                    local dt=now-prev
                    if dt>=.08 and dt<=.6 then
                        local displacement=(root.Position-old).Magnitude
                        local speed=displacement/dt
                        if speed>75 then
                            s.teleports+=1
                        elseif displacement>=.20 then
                            local animator=h:FindFirstChildOfClass("Animator")
                            if animator then
                                local ok,tracks=pcall(function()
                                    return animator:GetPlayingAnimationTracks()
                                end)
                                if ok and type(tracks)=="table" then
                                    local hasTrack=false
                                    for _,tr in ipairs(tracks) do
                                        local yes=false
                                        pcall(function() yes=tr.IsPlaying end)
                                        if yes then hasTrack=true break end
                                    end
                                    local early=now-t0<5
                                    s.moving+=1
                                    if early then s.early+=1 else s.late+=1 end
                                    if not hasTrack then
                                        s.absence+=1
                                        if early then s.earlyAbsent+=1 else s.lateAbsent+=1 end
                                    else s.present+=1 end
                                else s.bad+=1 end
                            else s.bad+=1 end
                        else s.still+=1 end
                    end
                end
            else
                s.last=nil s.when=nil
            end
        end
    end
    samples+=1
    sampling=false
end
local function overview()
    local total,eligible,absent,oneWindow,tracked,stationary,teleports,bad=0,0,0,0,0,0,0,0
    local details={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            total+=1
            local s=rows[p.UserId]
            if s and s.player==p then
                stationary+=s.still teleports+=s.teleports bad+=s.bad
                if s.moving>=4 then
                    eligible+=1
                    if s.present>0 then tracked+=1 end
                    local ratio=s.absence/s.moving
                    if ratio>=.85 and s.absence>=4 then
                        if s.earlyAbsent>=1 and s.lateAbsent>=1 then absent+=1
                        else oneWindow+=1 end
                    end
                end
                details[#details+1]=string.format("%s %d/%d E%d L%d T%d",
                    p.Name,s.absence,s.moving,s.early,s.late,s.teleports)
            end
        end
    end
    table.sort(details)
    return {total=total,eligible=eligible,absent=absent,
        oneWindow=oneWindow,tracked=tracked,stationary=stationary,
        teleports=teleports,bad=bad,details=details,
        suspicious=absent+oneWindow}
end
local function finish(state,reason)
    if not live() then return end
    alive=false
    local m=overview()
    local elapsed=os.clock()-t0
    local score=0
    local count=0
    for _,v in ipairs(appearance) do
        if v.valid then count+=1 score=math.max(score,v.score or 0) end
    end
    E.PDIDDLER_FAST_GATE_RESULT={
        state=state,reason=reason,elapsed=elapsed,
        total=m.total,eligible=m.eligible,absent=m.absent,
        partial=m.oneWindow,tracked=m.tracked,stationary=m.stationary,
        teleports=m.teleports,badReads=m.bad,appearanceScore=score,
        appearanceScans=count,animationSamples=samples,
        details=m.details,part5Compatible=false,jobId=game.JobId,
        evidenceVersion=6,generation=gen,roster=roster(),automaticHopAllowed=false,
        recommendationOnly=true}
    local summary=string.format(
        "PDIDDLER FAST GATE V6 | %s\n%s\n%.1fs/10s | players=%d moving=%d confirmed=%d partial=%d tracks=%d\n"
        .."cluster=%d/%d | appearance=%d score=%d | ticks=%d\nNO HOP / NO TRADE",
        state,reason,elapsed,m.total,m.eligible,m.absent,m.oneWindow,
        m.tracked,m.suspicious,m.eligible,count,score,samples)
    status(summary)
    print("[P1 FAST V5] "..summary:gsub("\n"," | "))
    for i=1,math.min(12,#m.details) do
        print("[P1 FAST V5] "..m.details[i])
    end
end
-- Appearance scans happen independently; a hung description fetch must not
-- delay sampling or exceed the hard 10-second deadline.
local function launchAppearance()
    local entry={valid=false,done=false,roster=roster(),at=os.clock()}
    appearance[#appearance+1]=entry
    task.spawn(function()
        local ok,result=pcall(function()
            return createScanner()()
        end)
        if not live() then return end
        entry.done=true
        if ok and type(result)=="table" and roster()==entry.roster then
            entry.valid=true
            entry.score=result.score or 0
            entry.bot=result.bot==true
            entry.total=result.total
            entry.loaded=result.loaded
        end
    end)
end
-- A separate watchdog owns completion, even when scan calls yield.
task.spawn(function()
    while live() and os.clock()<END_AT do task.wait(.04) end
    if not live() then return end
    local m=overview()
    local a,b=appearance[1],appearance[2]
    local corroborated=a and b and a.valid and b.valid
        and a.roster==b.roster and b.roster==roster() and a.bot and b.bot
        and a.loaded>=math.ceil(a.total*.8)
        and b.loaded>=math.ceil(b.total*.8)
    -- Partial players have adequate total movement, but most movement
    -- occurred in just one half of our ten-second screen. They are not
    -- "normal" simply because the window split prevented confirmation.
    local animationCluster=m.eligible>=4 and m.absent>=4
        and m.absent/m.eligible>=.70
        and m.absent/math.max(1,m.total)>=.50
    local concentratedPartial=m.eligible>=4
        and m.oneWindow>=4
        and m.suspicious>=4
        and m.suspicious/m.eligible>=.75
        and m.tracked<=1
        and samples>=35
    -- Preserve the distinction between TWO COMPLETED appearance scans and
    -- POSITIVE avatar/account corroboration. A score of zero is not support.
    local twoValidScans=a and b and a.valid and b.valid
        and a.roster==b.roster and b.roster==roster()
        and a.total==m.total and b.total==m.total
        and a.loaded>=math.ceil(m.total*.8)
        and b.loaded>=math.ceil(m.total*.8)
    -- This is a new narrow diagnostic label, NOT proof and NOT a hop command.
    -- Small observed cohorts have large uncertainty; mark as suspicious only
    -- after observing all evaluated movers without normal track evidence.
    local lowCoverageCluster=twoValidScans and m.total>=9
        and m.eligible>=3 and m.eligible<=4
        and m.suspicious==m.eligible
        and m.absent>=2 and m.tracked==0
        and samples>=35
    local state,reason
    if corroborated then
        state="BOT_PATTERN_FOR_REVIEW"
        reason="two positive known-good appearance scans"
    elseif animationCluster then
        state="ANIMATION_CLUSTER_FOR_REVIEW"
        reason="sustained short-window group signal; replication uncertain"
    elseif concentratedPartial then
        state="HIGH_SUSPICION_CLUSTER"
        reason="clustered one-window missing tracks; not corroborated"
    elseif lowCoverageCluster then
        state="LOW_COVERAGE_CLUSTER_FOR_REVIEW"
        reason="all 3-4 evaluated movers lacked tracks; needs independent confirmation"
    else
        state="PROCEED_UNVERIFIED"
        reason=m.eligible<4 and "insufficient movement coverage" or
            "no strong short-window pattern; not proof of normal server"
    end
    finish(state,reason)
end)
task.spawn(function()
    local second=false
    local first=false
    local nextSample=0
    while live() and os.clock()<END_AT do
        local now=os.clock()
        if now>=nextSample then
            local ok,err=pcall(measure,now)
            if not ok then
                sampling=false
                failures[#failures+1]=tostring(err)
            end
            nextSample=now+.12
        end
        if not first and now-t0>=.5 then first=true launchAppearance() end
        if not second and now-t0>=5.4 then second=true launchAppearance() end
        if label then
            local m=overview()
            status(string.format(
                "PDIDDLER FAST GATE V6 | SAMPLING %.1f/10s\n"
                .."players=%d movement coverage=%d | missing=%d partial=%d\n"
                .."ticks=%d | avatar scans=%d/2 | no hop / trade",
                now-t0,m.total,m.eligible,m.absent,m.oneWindow,samples,#appearance))
        end
        task.wait(.035)
    end
end)
