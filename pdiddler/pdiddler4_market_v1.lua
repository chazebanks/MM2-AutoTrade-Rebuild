-- pdiddler Part 4 market-quality snapshot v1
-- Base item VALUES are NOT stored here and are never overridden here.
-- Raw values always come from the frozen scanner resolver.
-- This file only supplies demand/stability context for effective-value scoring.
--
-- Conservative rule:
--   missing market metadata = neutral modifier, but NO controlled upgrade overpay.
-- Snapshot assembled from MM2Values demand/stability pages on 2026-11-02.

local M={}

local function norm(x)
    return tostring(x or "")
        :gsub("’","'")
        :lower()
        :gsub("[^%w]","")
end

local Data={}

local function add(page,name,demand,stability)
    Data[norm(page).."|"..norm(name)]={
        demand=tonumber(demand),
        stability=tostring(stability or "Unknown"),
    }
end

-- Ancient
add("ancient","Niks Scythe",11,"Overpaid For")
add("ancient","Gingerscope",6,"Stable")
add("ancient","Travelers Axe",5,"Stable")
add("ancient","Celestial",4.5,"Stable")
add("ancient","Vampires Axe",5.5,"Doing Well")
add("ancient","Emberbow",4,"Underpaid For")
add("ancient","Emberscythe",4,"Underpaid For")
add("ancient","Harvester",3,"Stable")
add("ancient","Icepiercer",2.5,"Stable")
add("ancient","Icebreaker",2,"Stable")
add("ancient","Batwing",2,"Stable")
add("ancient","Elderwood Scythe",1.5,"Stable")
add("ancient","SwirlyAxe",1.5,"Stable")
add("ancient","Hallowscythe",1.5,"Stable")
add("ancient","Log Chopper",1.5,"Stable")
add("ancient","Ice Wing",2,"Stable")

-- Chroma: current high/mid movers plus risk-tagged items.
add("chroma","Chroma Travelers Gun",7,"Stable")
add("chroma","Chroma Evergun",6,"Stable")
add("chroma","Chroma Evergreen",6,"Stable")
add("chroma","Chroma Bauble",6,"Stable")
add("chroma","Chroma Constellation",6,"Stable")
add("chroma","Chroma Vampires Gun",6,"Stable")
add("chroma","Chroma Alienbeam",6,"Stable")
add("chroma","Chroma Emberscythe",7,"Fluctuating")
add("chroma","Chroma Raygun",5,"Stable")
add("chroma","Chroma Sunrise",4.5,"Stable")
add("chroma","Chroma Snowcannon",4,"Stable")
add("chroma","Chroma Emberbow",6,"Fluctuating")
add("chroma","Chroma Sunset",4.5,"Stable")
add("chroma","Chroma Blizzard",5,"Stable")
add("chroma","Chroma Snowstorm",4,"Stable")
add("chroma","Chroma Heart Wand",4.5,"Stable")
add("chroma","Chroma Snow Dagger",5,"Stable")
add("chroma","Chroma WaterGun",4,"Stable")
add("chroma","Chroma Icecream",5,"Stable")
add("chroma","Chroma Mortal",5.5,"Fluctuating")
add("chroma","Chroma Immortal",5.5,"Fluctuating")
add("chroma","Chroma Ornament",3,"Stable")
add("chroma","Chroma Treat",4.5,"Stable")
add("chroma","Chroma Sweet",4.5,"Stable")
add("chroma","Chroma Sands",5,"Stable")
add("chroma","Chroma Beachy",5,"Stable")
add("chroma","Chroma Embersickle",4,"Underpaid For")
add("chroma","Chroma Darkbringer",1.5,"Stable")
add("chroma","Chroma Lightbringer",2,"Stable")
add("chroma","Chroma Luger",1.5,"Stable")
add("chroma","Chroma Laser",1.5,"Stable")
add("chroma","Chroma Candleflame",1,"Stable")
add("chroma","Chroma DeathShard",1,"Stable")
add("chroma","Chroma Swirlygun",1,"Stable")
add("chroma","Chroma Elderwood Blade",1,"Stable")
add("chroma","Chroma Shark",1.5,"Stable")
add("chroma","Chroma Slasher",1.5,"Stable")
add("chroma","Chroma Fang",1,"Stable")
add("chroma","Chroma Gemstone",1,"Stable")
add("chroma","Chroma Heat",1,"Stable")
add("chroma","Chroma Cookiecane",1,"Stable")
add("chroma","Chroma Tides",1,"Stable")
add("chroma","Chroma Seer",1,"Stable")
add("chroma","Chroma Gingerblade",1,"Stable")
add("chroma","Chroma Saw",1,"Stable")
add("chroma","Chroma Boneblade",1,"Stable")

-- Godly: current demand leaders + all known non-stable entries relevant to
-- the verified scanner snapshot. Unlisted godlies remain neutral/unknown.
add("godly","Evergreen",6,"Stable")
add("godly","Raygun",6,"Stable")
add("godly","Alienbeam",6,"Stable")
add("godly","Evergun",5,"Stable")
add("godly","Vampires Gun",5,"Stable")
add("godly","Spirit",5,"Stable")
add("godly","Soul",5,"Stable")
add("godly","Constellation",5,"Stable")
add("godly","Rainbow",5,"Stable")
add("godly","Rainbow Gun",5,"Stable")
add("godly","Travelers Gun",5,"Stable")
add("godly","Darkshot",5,"Underpaid For")
add("godly","Darksword",5,"Underpaid For")
add("godly","Turkey",5,"Stable")
add("godly","Bloom",4.5,"Stable")
add("godly","Flora",4.5,"Stable")
add("godly","Xenoknife",4.5,"Stable")
add("godly","Xenoshot",4.5,"Stable")
add("godly","Blossom",4.5,"Stable")
add("godly","Sakura",4.5,"Stable")
add("godly","Snowcannon",4.5,"Stable")
add("godly","Heart Wand",4.5,"Stable")
add("godly","Bauble",4,"Stable")
add("godly","Sunrise",4,"Stable")
add("godly","Sunset",4,"Stable")
add("godly","Flowerwood Knife",3.5,"Stable")
add("godly","Flowerwood Gun",3.5,"Stable")
add("godly","Blizzard",3.5,"Stable")
add("godly","Snowstorm",3.5,"Stable")
add("godly","Waves",3.5,"Stable")
add("godly","Ocean",3.5,"Stable")
add("godly","Mortal",3,"Fluctuating")
add("godly","Immortal",3,"Fluctuating")
add("godly","Australis",2.5,"Stable")
add("godly","Borealis",2.5,"Stable")
add("godly","Sweet",2.5,"Stable")
add("godly","Treat",2.5,"Stable")
add("godly","Heartblade",2,"Stable")
add("godly","Embersickle",2,"Underpaid For")
add("godly","WaterGun",2,"Stable")
add("godly","Pearl",2,"Stable")
add("godly","Pearlshine",2,"Stable")
add("godly","Bat",2,"Stable")
add("godly","Snow Dagger",2,"Stable")
add("godly","Ornament",2,"Stable")
add("godly","Beachy",2,"Stable")
add("godly","Sands",2,"Stable")
add("godly","Icecream",2,"Stable")
add("godly","Candleflame",1.5,"Stable")
add("godly","Elderwood Revolver",1.5,"Stable")
add("godly","Lightbringer",1.5,"Stable")
add("godly","Darkbringer",1.5,"Stable")
add("godly","Hallowgun",1.5,"Stable")
add("godly","Iceblaster",1.5,"Stable")

local StabilityModifier={
    ["hyped"]=0.05,
    ["overpaidfor"]=0.05,
    ["doingwell"]=0.03,
    ["stable"]=0,
    ["stabilizing"]=0,
    ["fluctuating"]=-0.02,
    ["losinghype"]=-0.05,
    ["underpaidfor"]=-0.08,
    ["decreasing"]=-0.10,
}

local function demandModifier(d)
    d=tonumber(d)

    if not d then return 0 end
    if d>=7 then return 0.02 end
    if d>=5 then return 0.01 end
    if d<=1 then return -0.015 end
    if d<=1.5 then return -0.01 end
    return 0
end

function M.info(item)
    if type(item)~="table" then
        return {
            known=false,
            demand=nil,
            stability="Unknown",
            modifier=0,
            weak=false,
            severe=false,
            positive=false,
        }
    end

    local rec=Data[norm(item.page).."|"..norm(item.name)]

    if not rec then
        return {
            known=false,
            demand=nil,
            stability="Unknown",
            modifier=0,
            weak=false,
            severe=false,
            positive=false,
        }
    end

    local stabilityKey=norm(rec.stability)
    local mod=(StabilityModifier[stabilityKey] or 0)+demandModifier(rec.demand)
    mod=math.max(-0.12,math.min(0.07,mod))

    return {
        known=true,
        demand=rec.demand,
        stability=rec.stability,
        modifier=mod,
        weak=(
            stabilityKey=="underpaidfor"
            or stabilityKey=="losinghype"
            or stabilityKey=="decreasing"
        ),
        severe=(stabilityKey=="decreasing"),
        positive=(
            stabilityKey=="hyped"
            or stabilityKey=="overpaidfor"
            or stabilityKey=="doingwell"
        ),
    }
end

function M.itemEffective(item)
    local raw=tonumber(item and item.value) or 0
    local info=M.info(item)
    return raw*(1+info.modifier),info
end

function M.offerStats(items)
    local out={
        raw=0,
        effective=0,
        units=0,
        knownUnits=0,
        unknownUnits=0,
        demandWeighted=0,
        demandWeight=0,
        weak=false,
        severe=false,
        positive=false,
        minModifier=0,
        maxModifier=0,
        details={},
    }

    for _,item in ipairs(items or {}) do
        local qty=math.max(1,tonumber(item.qty) or 1)
        local raw=(tonumber(item.value) or 0)*qty
        local effEach,info=M.itemEffective(item)
        local effective=effEach*qty

        out.raw+=raw
        out.effective+=effective
        out.units+=qty

        if info.known then
            out.knownUnits+=qty
        else
            out.unknownUnits+=qty
        end

        if info.demand then
            local weight=math.max(1,raw)
            out.demandWeighted+=info.demand*weight
            out.demandWeight+=weight
        end

        out.weak=out.weak or info.weak
        out.severe=out.severe or info.severe
        out.positive=out.positive or info.positive
        out.minModifier=math.min(out.minModifier,info.modifier)
        out.maxModifier=math.max(out.maxModifier,info.modifier)

        out.details[#out.details+1]={
            id=item.id,
            name=item.name,
            qty=qty,
            raw=raw,
            effective=effective,
            demand=info.demand,
            stability=info.stability,
            modifier=info.modifier,
            known=info.known,
        }
    end

    out.avgDemand=
        out.demandWeight>0
        and (out.demandWeighted/out.demandWeight)
        or nil

    out.allKnown=out.units>0 and out.unknownUnits==0

    return out
end

return M
