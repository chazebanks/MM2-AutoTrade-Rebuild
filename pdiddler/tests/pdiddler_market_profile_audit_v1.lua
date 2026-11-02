local root = os.getenv and (os.getenv("MM2_MATRIX_ROOT")) or "."
local ok, profile = pcall(dofile, root .. "/pdiddler/pdiddler_market_profile_2026-11-02_v1_CANDIDATE.lua")
assert(ok, "candidate profile module must load: "..tostring(profile))
assert(type(profile)=="table", "profile module must return table")
assert(profile.liveReady==false, "candidate must remain liveReady=false")

local c=profile.coverage()
assert(c.ancient==16 and c.chroma==46 and c.godly==128 and c.total==190, "coverage mismatch")

local seen,n={},0
for key,row in pairs(profile.profiles) do
  assert(not seen[key], "duplicate key "..key)
  seen[key]=true
  n=n+1
  assert(key==tostring(row.page)..":"..tostring(row.id), "canonical key mismatch "..key)
end
assert(n==190, "expected 190 unique rows, got "..tostring(n))

local e=assert(profile.get("ancient","1027"),"missing Emberscythe")
assert(e.name=="Emberscythe" and e.mm2Value==300 and e.supremeValue==375, "Emberscythe mapping mismatch")

local m=assert(profile.get("chroma","1033"),"missing Chroma Mortal")
assert(m.name=="Chroma Mortal" and m.mm2Value==1800 and m.supremeValue==1600, "Chroma Mortal mapping mismatch")

local candy=assert(profile.get("godly","23"),"missing Candy")
assert(candy.name=="Candy" and candy.mm2Value==90 and candy.supremeValue==80, "Candy mapping mismatch")

print("PASS profile audit 190/190")
