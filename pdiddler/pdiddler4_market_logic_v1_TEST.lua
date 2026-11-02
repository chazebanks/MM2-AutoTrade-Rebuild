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

local function max2(a,b) if a>b then return a else return b end end

function M.requiredProfit(ourBundle,theirBundle)
  ourBundle=type(ourBundle)=="table" and ourBundle or {}
  theirBundle=type(theirBundle)=="table" and theirBundle or {}
  local ourCopies=tonumber(ourBundle.eligibleCopies) or 0
  local theirCopies=tonumber(theirBundle.eligibleCopies) or 0
  local ourProtected=tonumber(ourBundle.protectedTotal) or 0
  local kind
  local flat,pct
  if ourCopies==1 and theirCopies>=3 then
    kind="BIG DOWNGRADE"; flat=30; pct=0.08
  elseif theirCopies>ourCopies then
    kind="DOWNGRADE"; flat=20; pct=0.06
  elseif ourCopies>theirCopies then
    kind="UPGRADE"; flat=15; pct=0.03
  else
    kind="NORMAL"; flat=15; pct=0.03
  end
  local baseRequired=max2(flat,ourProtected*pct)
  local marketPremium=0
  local theirRisk=tonumber(theirBundle.riskPoints) or 0
  local ourExit=tonumber(ourBundle.exitScore) or 0
  local theirExit=tonumber(theirBundle.exitScore) or 0
  local receivingMoreOrWeaker=(kind=="DOWNGRADE" or kind=="BIG DOWNGRADE" or theirExit<ourExit)
  if receivingMoreOrWeaker and theirRisk>0 and ourProtected>0 then
    local premiumPct=math.min(0.10,theirRisk*0.02)
    marketPremium=premiumPct*ourProtected
  end
  return baseRequired+marketPremium,kind,baseRequired,marketPremium
end

function M.tradeDecision(ourBundle,theirBundle)
  ourBundle=type(ourBundle)=="table" and ourBundle or {}
  theirBundle=type(theirBundle)=="table" and theirBundle or {}
  local ourRaw=tonumber(ourBundle.rawTotal) or 0
  local theirRaw=tonumber(theirBundle.rawTotal) or 0
  local ourProtected=tonumber(ourBundle.protectedTotal) or 0
  local theirProtected=tonumber(theirBundle.protectedTotal) or 0
  local rawProfit=theirRaw-ourRaw
  local protectedProfit=theirProtected-ourProtected
  local required,kind,baseRequired,marketPremium=M.requiredProfit(ourBundle,theirBundle)
  local qualityGain=(tonumber(theirBundle.exitScore) or 0)-(tonumber(ourBundle.exitScore) or 0)
  local ratio=(ourRaw>0) and (theirRaw/ourRaw) or math.huge
  local decision={
    ok=false,kind=kind,mode="reject",rawProfit=rawProfit,protectedProfit=protectedProfit,
    requiredProfit=required,baseRequired=baseRequired,marketPremium=marketPremium,
    qualityGain=qualityGain,ratio=ratio,ourRaw=ourRaw,theirRaw=theirRaw,
    reason="raw-underpay",
  }

  if rawProfit>=required and protectedProfit>=required then
    decision.ok=true
    decision.mode="profit"
    decision.reason="profit"
    return decision
  end

  local ourCopies=tonumber(ourBundle.eligibleCopies) or 0
  local theirCopies=tonumber(theirBundle.eligibleCopies) or 0
  if kind=="UPGRADE" and ourCopies>theirCopies and theirCopies>0 then
    if ourBundle.confidence~=true or theirBundle.confidence~=true then
      decision.reason="upgrade-confidence"
      return decision
    end
    if (tonumber(ourBundle.disputedCopies) or 0)>0 or (tonumber(theirBundle.disputedCopies) or 0)>0 then
      decision.reason="upgrade-disagreement"
      return decision
    end
    if qualityGain<2 then
      decision.reason="upgrade-quality-insufficient"
      return decision
    end
    local rawCap=ourRaw*0.03
    local protectedCap=ourProtected*0.03
    if rawProfit < -rawCap then
      decision.reason="upgrade-raw-loss"
      return decision
    end
    if protectedProfit < -protectedCap then
      decision.reason="upgrade-protected-loss"
      return decision
    end
    decision.ok=true
    decision.mode="quality-upgrade"
    decision.reason="quality-upgrade"
    return decision
  end

  if rawProfit>=required and protectedProfit<required then
    decision.reason="protected-underpay"
  elseif marketPremium>0 and rawProfit>=baseRequired and rawProfit<required then
    decision.reason="weak-downgrade-premium"
  end
  return decision
end

local function canonicalPickKey(plan)
  local keys={}
  if type(plan)~="table" or type(plan.picks)~="table" then return "" end
  for _,pick in ipairs(plan.picks) do
    if type(pick)=="table" then
      keys[#keys+1]=tostring(pick.page or "")..":"..tostring(pick.id or "")
    else
      keys[#keys+1]=tostring(pick)
    end
  end
  table.sort(keys)
  return table.concat(keys,"|")
end

function M.rankPlans(plans,theirBundle)
  local out={}
  if type(plans)=="table" then
    for _,plan in ipairs(plans) do
      if type(plan)=="table" and plan.mode~="reject" and plan.ok~=false then
        out[#out+1]=plan
      end
    end
  end
  local theirRaw=tonumber(type(theirBundle)=="table" and theirBundle.rawTotal) or 0
  local window=math.min(25,math.max(5,theirRaw*0.02))
  local minProfit=nil
  for _,plan in ipairs(out) do
    if plan.mode=="profit" then
      local rp=tonumber(plan.rawProfit) or -math.huge
      if minProfit==nil or rp<minProfit then minProfit=rp end
    end
  end
  local function modeRank(plan)
    if plan.mode=="profit" then return 0 end
    if plan.mode=="quality-upgrade" then return 1 end
    return 2
  end
  local function profitBand(plan)
    if plan.mode~="profit" or minProfit==nil then return 0 end
    local diff=(tonumber(plan.rawProfit) or math.huge)-minProfit
    if diff<=0 then return 0 end
    return math.floor(math.max(0,diff-1e-9)/window)
  end
  table.sort(out,function(a,b)
    local am,bm=modeRank(a),modeRank(b)
    if am~=bm then return am<bm end

    if am==0 then
      local ab,bb=profitBand(a),profitBand(b)
      if ab~=bb then return ab<bb end
      local ae,be=tonumber(a.givenExitScore) or 0,tonumber(b.givenExitScore) or 0
      if ae~=be then return ae<be end
      local ar,br=tonumber(a.rawTotal) or 0,tonumber(b.rawTotal) or 0
      if ar~=br then return ar>br end
    elseif am==1 then
      local ap,bp=tonumber(a.rawProfit) or -math.huge,tonumber(b.rawProfit) or -math.huge
      if ap~=bp then return ap>bp end
      local ae,be=tonumber(a.givenExitScore) or 0,tonumber(b.givenExitScore) or 0
      if ae~=be then return ae<be end
    end

    local ad,bd=tonumber(a.disputedCopies) or 0,tonumber(b.disputedCopies) or 0
    if ad~=bd then return ad<bd end
    local au,bu=tonumber(a.unprofiledCopies) or 0,tonumber(b.unprofiledCopies) or 0
    if au~=bu then return au<bu end
    local ak,bk=canonicalPickKey(a),canonicalPickKey(b)
    if ak~=bk then return ak<bk end
    return tostring(a.id or "")<tostring(b.id or "")
  end)
  return out
end

return M
