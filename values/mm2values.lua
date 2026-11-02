-- MM2Values verified corrections (snapshot 2026-11-01)
-- Source: https://www.mm2values.com/
-- This is a verified correction subset, NOT a complete catalog.
local Values = {
  updated = "2026-11-01",
  complete = false,
  source = "https://www.mm2values.com/",
  items = {
    ["Gingerscope"]={value=15250,category="Ancient"},
    ["Travelers Axe"]={value=7700,category="Ancient"},
    ["Celestial"]={value=1950,category="Ancient"},
    ["Vampires Axe"]={value=1375,category="Ancient"},
    ["Emberbow"]={value=325,category="Ancient"},
    ["Emberscythe"]={value=300,category="Ancient"},
    ["Travelers Gun"]={value=5150,category="Godly"},
    ["Evergun"]={value=3425,category="Godly"},
    ["Constellation"]={value=2475,category="Godly"},
    ["Alienbeam"]={value=1850,category="Godly"},
    ["Raygun"]={value=1825,category="Godly"},
    ["Chroma Raygun"]={value=12500,category="Chroma Godly"},
    ["Chroma Sunrise"]={value=8250,category="Chroma Godly"},
    ["Chroma Snowcannon"]={value=7650,category="Chroma Godly"},
    ["Chroma Emberbow"]={value=4450,category="Chroma Ancient"},
    ["Chroma Emberscythe"]={value=10000,category="Chroma Ancient"},
    ["Chroma WaterGun"]={value=2350,category="Chroma Godly"},
    ["Chroma Sweet"]={value=1750,category="Chroma Godly"},
    ["Chroma Sands"]={value=1325,category="Chroma Godly"},
    ["Chroma Beachy"]={value=1275,category="Chroma Godly"},
  }
}
function Values.get(name) return Values.items[name] end
return Values
