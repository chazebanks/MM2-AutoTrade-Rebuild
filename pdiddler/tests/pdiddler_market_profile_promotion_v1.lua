local root=os.getenv and (os.getenv("MM2_INTEGRATION_ROOT")) or "."

local candidate=assert(dofile(root.."/pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua"))
local ok,validated=pcall(dofile,root.."/pdiddler/pdiddler_market_profile_2026-11-02_v1_VALIDATED.lua")
assert(ok,"validated profile must load: "..tostring(validated))
assert(type(validated)=="table","validated profile must return table")
assert(validated.liveReady==true,"validated profile must be liveReady=true")
assert(validated.validation and validated.validation.deltaMatrixPass==true,"Delta matrix validation metadata missing")

local function keyset(t)
  local out,n={},0
  for k in pairs(t) do out[k]=true n=n+1 end
  return out,n
end

local ck,cn=keyset(candidate.profiles)
local vk,vn=keyset(validated.profiles)
assert(cn==190 and vn==190,"expected 190 candidate and validated rows")
for k in pairs(ck) do assert(vk[k],"validated missing "..k) end
for k in pairs(vk) do assert(ck[k],"validated extra "..k) end

local fields={"page","id","name","mm2Value","supremeValue","supremeLabel","demand","stability","profiled","verified","disagreementPct"}
for k,c in pairs(candidate.profiles) do
  local v=assert(validated.profiles[k],"missing "..k)
  for _,field in ipairs(fields) do
    local a,b=c[field],v[field]
    if type(a)=="number" and type(b)=="number" then
      assert(math.abs(a-b)<1e-9,k.." field mismatch "..field)
    else
      assert(a==b,k.." field mismatch "..field.." candidate="..tostring(a).." validated="..tostring(b))
    end
  end
end

local c=validated.coverage()
assert(c.ancient==16 and c.chroma==46 and c.godly==128 and c.total==190,"validated coverage mismatch")
print("PASS validated profile promotion 190/190 exact")
