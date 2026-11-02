local root=os.getenv and (os.getenv("MM2_MATRIX_ROOT")) or "."
local ok,M=pcall(dofile,root.."/pdiddler/pdiddler4_market_logic_v1_TEST.lua")
assert(ok,"market logic module must load: "..tostring(M))

local function eq(a,b,msg)
  assert(a==b,(msg or "eq failed").." expected="..tostring(b).." got="..tostring(a))
end
local function near(a,b,eps,msg)
  assert(math.abs(a-b)<=eps,(msg or "near failed").." expected="..tostring(b).." got="..tostring(a))
end
local function item(page,id,name,value,qty)
  return {page=page,id=tostring(id),name=name,value=value,qty=qty or 1}
end
local function profile(mm2,supreme,demand,stability,verified)
  return {mm2Value=mm2,supremeValue=supreme,demand=demand,stability=stability,profiled=true,verified=verified~=false}
end

local mat,absd,pct=M.materialDisagreement(300,375)
eq(mat,true,"300 vs 375 material") eq(absd,75,"abs 75") near(pct,25,1e-9,"pct 25")
local low,lowAbs,lowPct=M.materialDisagreement(5,7)
eq(low,false,"5 vs 7 not material") eq(lowAbs,2,"low abs") near(lowPct,40,1e-9,"low pct")
local cm=M.materialDisagreement(1800,1600)
eq(cm,true,"1800 vs 1600 material")

local ember=item("ancient","1027","Emberscythe",300,1)
local ep=profile(300,375,5,"Fluctuating")
local ours=M.itemAssessment(ember,"ours",ep)
local theirs=M.itemAssessment(ember,"theirs",ep)
eq(ours.protectedUnitValue,375,"ours protects high")
eq(theirs.protectedUnitValue,300,"theirs credits low")
eq(ours.materialDisagreement,true,"ember disputed")

local missing=M.itemAssessment(item("godly","x","Unknown",100,1),"theirs",nil)
eq(missing.protectedUnitValue,100,"missing baseline") eq(missing.confidence,false,"missing confidence") eq(missing.exitScore,0,"missing exit neutral")

local malformed=M.itemAssessment(item("godly","m","Malformed",100,1),"ours",{profiled=true,verified=true,supremeValue="bad",demand="bad",stability=99})
eq(malformed.protectedUnitValue,100,"malformed baseline") eq(malformed.confidence,false,"malformed confidence") eq(malformed.exitScore,0,"malformed exit neutral")

local partial=M.itemAssessment(item("godly","p","Partial",100,1),"theirs",{profiled=true,verified=true,supremeValue=105,demand=nil,stability="Stable"})
eq(partial.confidence,false,"missing demand incomplete") eq(partial.exitScore,0,"partial cannot get quality score")

local lookup={["godly:dup"]=profile(50,50,5,"Stable")}
local b=M.bundleAssessment({item("godly","dup","Dup",50,2)},"ours",function(page,id) return lookup[page..":"..id] end)
eq(b.rawTotal,100,"qty raw doubled") eq(b.protectedTotal,100,"qty protected doubled") eq(b.eligibleCopies,2,"qty copies doubled")

local zero=M.bundleAssessment({item("godly","z","Zero",0,1)},"theirs",function() return profile(0,0,5,"Stable") end)
eq(zero.rawTotal,0,"zero raw") eq(zero.exitScore,0,"zero exit neutral") eq(zero.confidence,false,"zero cannot support quality confidence")

print("PASS evaluator tests")
