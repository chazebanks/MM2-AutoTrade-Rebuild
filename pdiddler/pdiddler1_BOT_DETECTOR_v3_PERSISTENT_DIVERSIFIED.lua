-- pdiddler1 v3: v2 readiness gate + persistent diversified-farm confirmation
-- Standalone module: returns function that approves/rejects current server.
-- T3.6 PROVEN BOT-SERVER DETECTOR — RUNS FIRST
-- ============================================================
local Decision={}

function Decision.needsConfirm(report)
    report=type(report)=="table" and report or {}
    return report.bot==true
        or report.possibleDiversified==true
end

function Decision.rejectAfterConfirm(first,second)
    first=type(first)=="table" and first or {}
    second=type(second)=="table" and second or {}

    if second.bot==true then
        return true,"threshold"
    end

    if first.possibleDiversified==true
        and second.possibleDiversified==true
    then
        return true,"persistent-diversified"
    end

    return false,"cleared"
end

local function runBotGate()
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer

    local C = {
        BotWaitForLobby = 6,
        BotConfirmDelay = 2.5,
        BotMinPlayers = 6,
        BotThreshold = 60,

        -- v2 readiness gate: do not approve a lobby while most avatar
        -- descriptions are still missing. Uses ceil so 11 players requires
        -- 9 loaded descriptions (actual >=80%), not floor(8.8)=8.
        BotAvatarReadyRatio = 0.80,
        BotAvatarReadyRetries = 4,
        BotAvatarReadyRetryDelay = 0.75,

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

        local possibleDiversified =
            total >= C.DiversifiedMinPlayers
            and loaded >= math.floor(total * 0.70)
            and simple1Ratio >= C.DiversifiedMediumSimpleRatio
            and trait1Ratio >= C.DiversifiedMediumTrait1Ratio
            and trait2Ratio >= C.DiversifiedMediumTrait2Ratio

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

            possibleDiversified = possibleDiversified,
            repeatedMembers = repeatedMembers,
        }
    end

    local function printScan(label, r)
        print(
            "[MM2 Bot Test T3.6]",
            label,
            "| score", r.score,
            "| players", r.total,
            "| avatars", r.loaded,
            "| largest cluster", r.cluster,
            "| accessories<=1", r.simple1.."/"..r.loaded,
            "| trait>=1", r.trait1.."/"..r.total,
            "| trait>=2", r.trait2.."/"..r.total,
            "| repeated", r.repeatedMembers,
            "|", r.reasons
        )

        if #r.clusterNames > 0 then
            print(
                "[MM2 Bot Test T3.6]",
                label,
                "| flagged group:",
                table.concat(r.clusterNames, ", ")
            )
        end
    end

    local function avatarDataReady(report)
        report=type(report)=="table" and report or {}

        local total=tonumber(report.total) or 0
        local loaded=tonumber(report.loaded) or 0

        if total < C.BotMinPlayers then
            return true
        end

        local requiredLoaded=
            math.ceil(report.total * C.BotAvatarReadyRatio)

        return loaded >= requiredLoaded
    end

    print("[MM2 Bot Test T3.6] START")
    print(
        "[MM2 Bot Test T3.6] Waiting",
        C.BotWaitForLobby,
        "seconds for lobby/avatar data..."
    )

    task.wait(C.BotWaitForLobby)

    local first = scan()
    printScan("SCAN 1", first)

    local readinessRetries=0

    while not avatarDataReady(first)
        and readinessRetries < C.BotAvatarReadyRetries
    do
        readinessRetries += 1

        warn(
            "[MM2 Bot Test T3.6] AVATAR DATA INCOMPLETE | loaded",
            first.loaded,
            "of",
            first.total,
            "| retry",
            readinessRetries,
            "of",
            C.BotAvatarReadyRetries
        )

        task.wait(C.BotAvatarReadyRetryDelay)

        first=scan()
        printScan("READINESS RETRY "..tostring(readinessRetries), first)
    end

    if not avatarDataReady(first) then
        warn(
            "[MM2 Bot Test T3.6] AVATAR DATA INCOMPLETE | bounded retries exhausted | loaded",
            first.loaded,
            "of",
            first.total,
            "| proceeding with available signals"
        )
    end

    if not Decision.needsConfirm(first) then
        print(
            "[MM2 Bot Test T3.6] SUCCESS - SERVER APPROVED | score",
            first.score,
            "| below threshold",
            C.BotThreshold
        )
        return true
    end

    local firstReason =
        first.bot
        and "threshold"
        or "possible diversified farm"

    warn(
        "[MM2 Bot Test T3.6] SUSPICIOUS SERVER | "
        ..firstReason
        .." | confirming in",
        C.BotConfirmDelay,
        "seconds"
    )

    task.wait(C.BotConfirmDelay)

    local second = scan()
    printScan("SCAN 2", second)

    local reject,confirmWhy=
        Decision.rejectAfterConfirm(first,second)

    if reject then
        warn(
            "[MM2 Bot Test T3.6] BOT SERVER CONFIRMED | reason",
            confirmWhy,
            "| score",
            second.score,
            "|", second.reasons
        )

        if #second.clusterNames > 0 then
            warn(
                "[MM2 Bot Test T3.6] BOT GROUP:",
                table.concat(second.clusterNames, ", ")
            )
        end

        warn(
            "[MM2 Bot Test T3.6] BOT GATE BLOCKED - startup modules will NOT run"
        )
        return false
    else
        print(
            "[MM2 Bot Test T3.6] SUCCESS - SUSPICION CLEARED ON CONFIRMATION | score",
            second.score
        )
        return true
    end
end
return {run = runBotGate, decision = Decision}
