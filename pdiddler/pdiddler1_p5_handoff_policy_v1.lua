-- Pdiddler P1/P5 bot-classification handoff POLICY v1
-- Pure Luau. No game services, no remotes, no teleport. Never calls Part 5.
-- Input comes from a completed observation; default is HOLD.
local M={}
M.MinPopulation=8
M.MinMoving=6
M.MinConfirmed=3
M.MinReviewed=6
M.MinReviewedMovingRatio=.70
M.MinReviewedPopulationRatio=.55
M.MaxUnknownRatio=.35
M.MinStableOverlap=.80
M.MaxSnapshotAge=15

local function integer(n)
    return type(n)=="number" and n==n and n>=0 and n%1==0
end
local function membership(list)
    if type(list)~="table" then return nil end
    local set,count={},0
    for _,id in ipairs(list) do
        local key=tostring(id)
        if key=="" or set[key] then return nil end
        set[key]=true count+=1
    end
    return set,count
end
function M.assess(observation,context)
    context=context or {}
    if type(observation)~="table" then return "HOLD","missing-observation" end
    if context.jobId==nil or tostring(context.jobId)=="" then return "HOLD","missing-job-id" end
    if tostring(observation.jobId or "")~=tostring(context.jobId) then return "HOLD","different-job" end
    if context.criticalBusy==true or context.tradeVisible==true or context.outgoingOwned==true then
        return "HOLD","trade-or-request-busy"
    end
    if context.scannerPending==true or context.hopping==true then return "HOLD","system-busy" end
    if context.observerCurrent~=true then return "HOLD","stale-observer" end
    if observation.complete~=true then return "HOLD","observation-incomplete" end
    if not integer(observation.total) or not integer(observation.moving)
        or not integer(observation.confirmed) or not integer(observation.partial)
        or not integer(observation.unknown) then return "HOLD","invalid-counts" end
    local n,m,c,p,u=observation.total,observation.moving,observation.confirmed,observation.partial,observation.unknown
    if n==0 or m>n or c+p>m or u>n or u+m>n then
        return "HOLD","inconsistent-counts"
    end
    if type(observation.observedAt)~="number" or type(context.now)~="number"
        or observation.observedAt>context.now
        or context.now-observation.observedAt>M.MaxSnapshotAge then
        return "HOLD","stale-evidence"
    end
    if type(observation.appearance)~="table" or #observation.appearance~=2 then
        return "HOLD","missing-appearance-scans"
    end
    for i=1,2 do
        local a=observation.appearance[i]
        if type(a)~="table" or a.supporting~=true
            or not integer(a.loaded) or not integer(a.total)
            or a.total<M.MinPopulation or a.loaded> a.total
            or a.loaded/a.total<.8 then
            return "HOLD","appearance-not-corroborated"
        end
    end
    local previous,prevCount=membership(observation.initialIds)
    local current,currentCount=membership(context.currentIds)
    if not previous or not current then return "HOLD","missing-or-duplicate-membership" end
    if prevCount~=n or currentCount~=n then return "HOLD","population-changed" end
    local overlap=0
    for id in pairs(previous) do if current[id] then overlap+=1 end end
    if overlap~=n then return "HOLD","membership-changed" end
    if type(observation.appearance[1].ids)=="table" and type(observation.appearance[2].ids)=="table" then
        for i=1,2 do
            local ids,k=membership(observation.appearance[i].ids)
            if not ids or k~=n then return "HOLD","appearance-membership-changed" end
            for id in pairs(previous) do if not ids[id] then return "HOLD","appearance-membership-changed" end end
        end
    else
        return "HOLD","appearance-ids-unavailable"
    end
    if n<M.MinPopulation or m<M.MinMoving or u/n>M.MaxUnknownRatio then
        return "HOLD","insufficient-coverage"
    end
    local reviewed=c+p
    if c<M.MinConfirmed or reviewed<M.MinReviewed
        or reviewed/m<M.MinReviewedMovingRatio
        or reviewed/n<M.MinReviewedPopulationRatio then
        return "ALLOW","no-strong-combined-pattern"
    end
    return "REVIEW","combined-farm-pattern-not-proof"
end
return M
