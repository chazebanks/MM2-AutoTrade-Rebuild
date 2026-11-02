-- Pure offline market logic. No Roblox services, remotes, GUI, or network calls.
local M={}

local STABILITY_SCORE={
  ["Underpaid For"]=-2,
  ["Fluctuating"]=-1,
  ["Stable"]=0,
  ["Doing Well"]=1,
  ["Overpaid For"]=2,
}

local function num(v)
  local n=tonumber(v)
  if not n or n~=n or n==math.huge or n==-math.huge then return nil end
  return n
end

local function qtyOf(item)
  local q=num(item and item.qty)
  if q==nil then q=1 end
  q=math.floor(q)
  if q<0 then q=0 end
  return q
end

local function demandScore(d)
  d=num(d)
  if not d then return 0 end
  if d<=2 then return -2 end
  if d<=4 then return -1 end
  if d==5 then return 0 end
  if d<=7 then return 1 end
  return 2
end

local function stabilityScore(s)
  return STABILITY_SCORE[s] or 0
end

function M.materialDisagreement(mm2Value,supremeValue)
  local mm2=num(mm2Value)
  local supreme=num(supremeValue)
  if not mm2 or not supreme or mm2<=0 then return false,nil,nil end
  local absDiff=math.abs(supreme-mm2)
  local pctDiff=(absDiff/mm2)*100
  return absDiff>=25 and pctDiff>=5,absDiff,pctDiff
end

local function completeProfile(p)
  if type(p)~="table" or p.profiled~=true or p.verified~=true then return false end
  if not num(p.demand) then return false end
  if STABILITY_SCORE[p.stability]==nil then return false end
  local sv=num(p.supremeValue)
  local hasLabel=type(p.supremeLabel)=="string" and p.supremeLabel~=""
  return sv~=nil or hasLabel
end

function M.itemAssessment(item,side,profileRecord)
  side=(side=="ours") and "ours" or "theirs"
  local raw=num(item and item.value) or 0
  local qty=qtyOf(item)
  local confidence=completeProfile(profileRecord)
  local material,absDiff,pctDiff=false,nil,nil
  local protected=raw
  local exitScore=0
  local riskPoints=2

  if confidence then
    local supreme=num(profileRecord.supremeValue)
    if supreme then
      material,absDiff,pctDiff=M.materialDisagreement(raw,supreme)
      if material then
        if side=="ours" then protected=math.max(raw,supreme)
        else protected=math.min(raw,supreme) end
      end
    end
    exitScore=demandScore(profileRecord.demand)+stabilityScore(profileRecord.stability)-(material and 1 or 0)
    riskPoints=0
    local d=num(profileRecord.demand)
    if d<=2 then riskPoints=riskPoints+2 elseif d<=4 then riskPoints=riskPoints+1 end
    if profileRecord.stability=="Underpaid For" then riskPoints=riskPoints+2
    elseif profileRecord.stability=="Fluctuating" then riskPoints=riskPoints+1 end
    if material then riskPoints=riskPoints+1 end
  end

  return {
    page=item and item.page or nil,
    id=item and tostring(item.id) or nil,
    name=item and item.name or nil,
    qty=qty,
    rawUnitValue=raw,
    protectedUnitValue=protected,
    rawValue=raw*qty,
    protectedValue=protected*qty,
    confidence=confidence,
    exitScore=exitScore,
    riskPoints=riskPoints,
    materialDisagreement=material,
    disagreementAbs=absDiff,
    disagreementPct=pctDiff,
  }
end

local function getProfile(lookup,page,id)
  if type(lookup)=="function" then
    local ok,res=pcall(lookup,page,tostring(id))
    if ok then return res end
    return nil
  end
  if type(lookup)=="table" then
    if type(lookup.get)=="function" then
      local ok,res=pcall(lookup.get,page,tostring(id))
      if ok then return res end
    end
    return lookup[tostring(page)..":"..tostring(id)]
  end
  return nil
end

function M.bundleAssessment(items,side,profileLookup)
  local out={
    rawTotal=0,protectedTotal=0,eligibleCopies=0,
    exitScore=0,riskPoints=0,confidence=true,
    materialDisagreementValue=0,disputedCopies=0,unprofiledCopies=0,
    items={},
  }
  local weightedExit,weightedRisk=0,0
  if type(items)~="table" then items={} end
  for _,item in ipairs(items) do
    local p=getProfile(profileLookup,item.page,item.id)
    local a=M.itemAssessment(item,side,p)
    out.items[#out.items+1]=a
    out.rawTotal=out.rawTotal+a.rawValue
    out.protectedTotal=out.protectedTotal+a.protectedValue
    out.eligibleCopies=out.eligibleCopies+a.qty
    weightedExit=weightedExit+a.exitScore*a.rawValue
    weightedRisk=weightedRisk+a.riskPoints*a.rawValue
    if not a.confidence then
      out.confidence=false
      out.unprofiledCopies=out.unprofiledCopies+a.qty
    end
    if a.materialDisagreement then
      out.disputedCopies=out.disputedCopies+a.qty
      out.materialDisagreementValue=out.materialDisagreementValue+(a.disagreementAbs or 0)*a.qty
    end
  end
  if out.rawTotal>0 then
    out.exitScore=weightedExit/out.rawTotal
    out.riskPoints=weightedRisk/out.rawTotal
  else
    out.exitScore=0
    out.riskPoints=0
    out.confidence=false
  end
  if out.eligibleCopies==0 then out.confidence=false end
  return out
end

return M
