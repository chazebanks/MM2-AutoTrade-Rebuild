-- PDIDDLER P1 FAST GATE V2 | 10-second bounded diagnostic
-- The frozen known-good scanner below is retained without scoring changes.
-- Animation evidence is separate, group-only, and experimental.
-- NO TRADING, NO SERVER HOPPING. No Part5 compatibility.
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local E=(getgenv and getgenv()) or _G
if type(E.PDIDDLER_FAST_GATE_STOP)=="function" then
    pcall(E.PDIDDLER_FAST_GATE_STOP)
end
E.PDIDDLER_FAST_GATE_GEN=(tonumber(E.PDIDDLER_FAST_GATE_GEN) or 0)+1
local gen=E.PDIDDLER_FAST_GATE_GEN
local alive=true
local begun=os.clock()
local DEADLINE=10
local gui,label
local output=nil
E.PDIDDLER_FAST_GATE_RESULT=nil
E.PDIDDLER_P1_EVIDENCE_V1=nil
E.PDIDDLER_P1_COHORT_EVIDENCE_V2=nil
local function current() return alive and E.PDIDDLER_FAST_GATE_GEN==gen end
local function roster()
    local ids={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then ids[#ids+1]=tostring(p.UserId) end
    end
    table.sort(ids)
    return table.concat(ids,",")
end
local function setText(x) if label then label.Text=x end end
local function completed(state,reason,detail)
    if not current() then return end
    alive=false
    local elapsed=os.clock()-begun
    detail=detail or {}
    output={version=2,state=state,reason=reason,elapsed=elapsed,
        jobId=game.JobId,generation=gen,at=os.clock(),
        appearanceScore=detail.score or 0,
        players=detail.players or 0,loaded=detail.loaded or 0,
        animationStrong=detail.strong or 0,
        animationObserved=detail.observed or 0,
        appearanceScans=detail.scans or 0,part5Compatible=false}
    E.PDIDDLER_FAST_GATE_RESULT=output
    local summary=string.format(
       "PDIDDLER FAST GATE V2 | %s\n%s\n%.1fs / 10s | NO HOP / NO TRADE\nPlayers %d | avatars %d | score %d | animation %d/%d | scans %d",
       state,reason,elapsed,output.players,output.loaded,
       output.appearanceScore,output.animationStrong,
       output.animationObserved,output.appearanceScans)
    setText(summary)
    print("[P1 FAST V2] "..summary:gsub("\n"," | "))
end
E.PDIDDLER_FAST_GATE_STOP=function()
    alive=false
    if gui then pcall(function() gui:Destroy() end) end
end
local function makeGui()
    local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",2)
    if not pg or not current() then return end
    gui=Instance.new("ScreenGui")
    gui.Name="PdiddlerFastGateV2"
    gui.ResetOnSpawn=false
    local panel=Instance.new("Frame")
    panel.Size=UDim2.new(.88,0,0,138)
    panel.Position=UDim2.new(.06,0,.12,0)
    panel.BackgroundColor3=Color3.fromRGB(36,25,55)
    panel.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=panel
    label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,-18,1,-12)
    label.Position=UDim2.fromOffset(9,6)
    label.BackgroundTransparency=1
    label.TextColor3=Color3.new(1,1,1)
    label.Font=Enum.Font.Code
    label.TextSize=13
    label.TextWrapped=true
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.TextYAlignment=Enum.TextYAlignment.Top
    label.Text="PDIDDLER FAST GATE V2 | starting"
    label.Parent=panel
    gui.Parent=pg
end
pcall(makeGui)

-- Authoritative copied known-good appearance/name scanner:
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

        if not okDesc or not desc then
            return nil
        end

        local parts = {}
        for _, field in ipairs(DESC_FIELDS) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if okField then
                parts[#parts+1] = field.."="..tostring(val or "")
            end
        end

        for _, field in ipairs({
            "BodyTypeScale","DepthScale","HeadScale",
            "HeightScale","ProportionScale","WidthScale"
        }) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if okField then
                parts[#parts+1] =
                    field.."="..string.format("%.2f", tonumber(val) or 0)
            end
        end

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
            local av = avatarData(p)

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


local tracker={}
local function sampleAnimations(now)
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local s=tracker[p.UserId]
            if not s or s.player~=p then
                s={player=p,character=nil,position=nil,last=nil,
                   m={0,0},absent={0,0}}
                tracker[p.UserId]=s
            end
            local c=p.Character
            if c~=s.character then
                s.character=c
                s.position=nil
                s.last=nil
            end
            local h=c and c:FindFirstChildOfClass("Humanoid")
            local root=c and c:FindFirstChild("HumanoidRootPart")
            if h and root and root:IsA("BasePart") and h.Health>0 then
                local elapsed=now-begun
                local window=(elapsed<5.5) and 1 or 2
                local old,previous=s.position,s.last
                s.position=root.Position
                s.last=now
                if old and previous and now-previous>=.12 and now-previous<=.7 then
                    local dist=(root.Position-old).Magnitude
                    local speed=dist/(now-previous)
                    -- Ignore large map teleports and nearly stationary samples.
                    if speed<=70 and dist>=.45 then
                        local animator=h:FindFirstChildOfClass("Animator")
                        if animator then
                            local ok,tracks=pcall(function()
                                return animator:GetPlayingAnimationTracks()
                            end)
                            if ok and type(tracks)=="table" then
                                local playing=false
                                for _,track in ipairs(tracks) do
                                    local activeTrack=false
                                    pcall(function() activeTrack=track.IsPlaying end)
                                    if activeTrack then playing=true break end
                                end
                                s.m[window]+=1
                                if not playing then s.absent[window]+=1 end
                            end
                        end
                    end
                end
            else
                s.position=nil
                s.last=nil
            end
        end
    end
end
local function animationSummary()
    local strong,observed=0,0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local s=tracker[p.UserId]
            if s and s.player==p then
                local a,b=s.m[1],s.m[2]
                local x,y=s.absent[1],s.absent[2]
                if a+b>=6 then
                    observed+=1
                    if a>=2 and b>=2 and
                        (x+y)/(a+b)>=.90 and
                        x/a>=.90 and y/b>=.90 then
                        strong+=1
                    end
                end
            end
        end
    end
    return strong,observed
end
-- Blocking GetAppliedDescription can yield; keep scanning in isolated tasks,
-- accept results only within deadline and for an unchanged roster.
local function startScan()
    local slot={done=false,ok=false,value=nil,roster=roster()}
    task.spawn(function()
        local ok,fn=pcall(createScanner)
        if ok and type(fn)=="function" then
            local success,result=pcall(fn)
            slot.ok=success
            slot.value=result
        end
        slot.done=true
    end)
    return slot
end

-- Independent deadline includes all avatar reads and GUI initialization.
task.spawn(function()
    while current() and os.clock()-begun<DEADLINE do task.wait(.05) end
    if current() then
        local strong,observed=animationSummary()
        completed("PROCEED_UNVERIFIED","10-second budget reached; not enough verified evidence",
            {strong=strong,observed=observed})
    end
end)

task.spawn(function()
    local first=nil
    local second=nil
    local scans=0
    local last=nil
    local nextAnim=0
    local initialRoster=nil
    while current() do
        local now=os.clock()
        if now>=nextAnim then
            sampleAnimations(now)
            nextAnim=now+.2
        end
        local elapsed=now-begun
        local ids=roster()
        if initialRoster==nil then initialRoster=ids end
        -- Join/leave cannot create a false positive: abandon earlier
        -- appearance scores; preserve individual animation samples.
        if ids~=initialRoster then
            initialRoster=ids
            first=nil
            second=nil
            scans=0
        end
        if elapsed>=.8 and not first then
            first=startScan()
        end
        if first and first.done and not first.handled then
            first.handled=true
            if first.ok and type(first.value)=="table" and first.roster==ids then
                last=first.value
                scans=1
            else
                -- Retry one more time instead of trusting missing data.
                last=nil
            end
        end
        if elapsed>=5.5 and not second then
            second=startScan()
        end
        if second and second.done and not second.handled then
            second.handled=true
            if second.ok and type(second.value)=="table" and second.roster==ids then
                scans+=1
                local a=first and first.value
                local b=second.value
                if first and first.ok and a and first.roster==ids then
                    local total=tonumber(b.total) or 0
                    local loaded=tonumber(b.loaded) or 0
                    local score=tonumber(b.score) or 0
                    local strong,observed=animationSummary()
                    local detail={players=total,loaded=loaded,score=score,
                        strong=strong,observed=observed,scans=scans}
                    local adequate=total>=8 and loaded>=math.ceil(total*.80)
                    -- Two independent paths: repeated strong appearance
                    -- or unusually widespread missing tracks with supporting
                    -- appearance evidence. Short animation signals are provisional.
                    local appearanceStrong=adequate and a.bot==true and b.bot==true
                    local animationStrong=adequate and strong>=6 and observed>=6
                        and strong/observed>=.75 and strong/total>=.55
                    local appearanceSupport=(tonumber(a.score) or 0)>=25
                        or (tonumber(b.score) or 0)>=25
                        or (tonumber(b.simple1Ratio) or 0)>=.70
                        and (tonumber(b.trait1Ratio) or 0)>=.70
                    if appearanceStrong or (animationStrong and appearanceSupport) then
                        completed("BOT_PATTERN_FOR_REVIEW",
                            appearanceStrong and "two strong appearance scans" or
                            "short animation cluster with appearance support",detail)
                        return
                    end
                    -- No early approval before both scan windows have been seen.
                    if not animationStrong and not appearanceStrong then
                        completed("PROCEED_UNVERIFIED",
                            "no confirmed farm pattern in short observation",detail)
                        return
                    end
                end
            end
        end
        if elapsed>=9.5 and current() then
            local strong,observed=animationSummary()
            completed("PROCEED_UNVERIFIED","screening incomplete; proceeding without bot verdict",
                {players=last and last.total or 0,
                 loaded=last and last.loaded or 0,
                 score=last and last.score or 0,
                 strong=strong,observed=observed,scans=scans})
            return
        end
        if label then
            label.Text=string.format(
                "PDIDDLER FAST GATE V2 | SCANNING %.1f/10s\n"
                .."Appearance scans: %d/2 | animation coverage: %d\n"
                .."Early approval disabled | no hop / no trade",
                math.min(10,elapsed),scans,select(2,animationSummary()))
        end
        task.wait(.1)
    end
end)
