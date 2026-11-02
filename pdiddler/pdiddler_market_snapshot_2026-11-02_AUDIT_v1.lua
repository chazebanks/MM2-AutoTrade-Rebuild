-- AUDIT-ONLY market profile snapshot. NOT WIRED INTO LIVE TRADING.
-- Supreme source pages were current as of 2026-11-02 12:34 PM.
-- MM2Values numbers are copied from the active v6.8 scanner snapshot (2026-10-31 12:31:12 EST).
-- Purpose: offline coverage/conflict audit before any v2.6 planner change.

local S={
  liveReady=false,
  snapshotDate="2026-11-02",
  supremeUpdated="2026-11-02 12:34 PM",
  mm2ValuesUpdated="2026-10-31 12:31:12 EST",
  coverage={ancient=16,chroma=46,godly=49,total=111},
  expectedEligible={ancient=16,chroma=46,godly=128,total=190},
  profiles={},
}

local function add(page,id,mm2,name,supreme,supremeLabel,demand,stability)
  local key=tostring(page)..":"..tostring(id)
  local disagreement=nil
  if tonumber(mm2) and tonumber(supreme) and tonumber(mm2)~=0 then
    disagreement=math.abs(tonumber(supreme)-tonumber(mm2))/tonumber(mm2)
  end
  S.profiles[key]={
    page=page,id=tostring(id),name=name,
    mm2Value=mm2,supremeValue=supreme,supremeLabel=supremeLabel,
    demand=demand,stability=stability,
    disagreementPct=disagreement and disagreement*100 or nil,
    profiled=true,verified=true,
  }
end

add("ancient","1",250000000,"Nik's Scythe",nil,"Priceless",11,"Overpaid For")
add("ancient","771",15250,"Gingerscope",15750,nil,6,"Stable")
add("ancient","743",7700,"Traveler's Axe",7500,nil,5,"Underpaid For")
add("ancient","860",1950,"Celestial",1950,nil,5,"Stable")
add("ancient","829",1375,"Vampire's Axe",1425,nil,6,"Stable")
add("ancient","1026",325,"Emberbow",375,nil,5,"Fluctuating")
add("ancient","1027",300,"Emberscythe",375,nil,5,"Fluctuating")
add("ancient","526",250,"Harvester",250,nil,3,"Stable")
add("ancient","661",165,"Icepiercer",160,nil,3,"Stable")
add("ancient","480",70,"Icebreaker",65,nil,1,"Stable")
add("ancient","3",45,"Batwing",42,nil,1,"Stable")
add("ancient","2",40,"Elderwood Scythe",38,nil,1,"Stable")
add("ancient","529",40,"Swirly Axe",38,nil,1,"Stable")
add("ancient","471",32,"Hallowscythe",30,nil,1,"Stable")
add("ancient","404",20,"Logchopper",18,nil,1,"Stable")
add("ancient","4",15,"Icewing",13,nil,1,"Stable")
add("chroma","739",140000,"Chroma Traveler's Gun",140000,nil,8,"Stable")
add("chroma","772",47000,"Chroma Evergun",47000,nil,7,"Stable")
add("chroma","773",33000,"Chroma Evergreen",33000,nil,7,"Stable")
add("chroma","855",29000,"Chroma Bauble",29000,nil,7,"Stable")
add("chroma","857",26000,"Chroma Constellation",27000,nil,6,"Stable")
add("chroma","831",25000,"Chroma Vampire's Gun",24500,nil,6,"Stable")
add("chroma","927",23000,"Chroma Alienbeam",23500,nil,6,"Stable")
add("chroma","1036",10000,"Chroma Emberscythe",10000,nil,6,"Fluctuating")
add("chroma","928",12500,"Chroma Raygun",12500,nil,5,"Stable")
add("chroma","899",8250,"Chroma Sunrise",8500,nil,5,"Stable")
add("chroma","962",7650,"Chroma Snowcannon",7750,nil,5,"Stable")
add("chroma","1030",4450,"Chroma Emberbow",4500,nil,6,"Fluctuating")
add("chroma","900",5500,"Chroma Sunset",5500,nil,5,"Stable")
add("chroma","957",5500,"Chroma Blizzard",5500,nil,5,"Stable")
add("chroma","958",4250,"Chroma Snowstorm",4250,nil,5,"Stable")
add("chroma","990",3400,"Chroma Heart Wand",3500,nil,5,"Stable")
add("chroma","960",2400,"Chroma Snow Dagger",2350,nil,5,"Stable")
add("chroma","810",2350,"Chroma Watergun",2300,nil,5,"Stable")
add("chroma","1006",1875,"Chroma Icecream",1850,nil,5,"Stable")
add("chroma","1033",1800,"Chroma Mortal",1600,nil,5,"Doing Well")
add("chroma","1034",1800,"Chroma Immortal",1600,nil,5,"Doing Well")
add("chroma","985",1800,"Chroma Ornament",1825,nil,5,"Stable")
add("chroma","992",1800,"Chroma Treat",1775,nil,5,"Stable")
add("chroma","991",1750,"Chroma Sweet",1725,nil,5,"Stable")
add("chroma","1007",1325,"Chroma Sands",1225,nil,5,"Stable")
add("chroma","1008",1275,"Chroma Beachy",1175,nil,5,"Stable")
add("chroma","1029",1100,"Chroma Embersickle",1300,nil,5,"Fluctuating")
add("chroma","447",60,"Chroma Darkbringer",65,nil,1,"Stable")
add("chroma","446",55,"Chroma Lightbringer",60,nil,1,"Stable")
add("chroma","6",48,"Chroma Luger",50,nil,1,"Stable")
add("chroma","8",40,"Chroma Laser",40,nil,1,"Stable")
add("chroma","525",40,"Chroma Candleflame",40,nil,1,"Stable")
add("chroma","13",35,"Chroma Deathshard",35,nil,1,"Stable")
add("chroma","527",35,"Chroma Swirly Gun",35,nil,1,"Stable")
add("chroma","616",35,"Chroma Elderwood Blade",37,nil,1,"Stable")
add("chroma","7",33,"Chroma Shark",32,nil,1,"Stable")
add("chroma","9",33,"Chroma Slasher",32,nil,1,"Stable")
add("chroma","10",33,"Chroma Fang",32,nil,1,"Stable")
add("chroma","439",33,"Chroma Gemstone",32,nil,1,"Stable")
add("chroma","11",30,"Chroma Heat",28,nil,1,"Stable")
add("chroma","659",30,"Chroma Cookiecane",32,nil,1,"Stable")
add("chroma","14",25,"Chroma Tides",27,nil,1,"Stable")
add("chroma","15",25,"Chroma Seer",28,nil,1,"Stable")
add("chroma","17",25,"Chroma Gingerblade",27,nil,1,"Stable")
add("chroma","12",22,"Chroma Saw",23,nil,1,"Stable")
add("chroma","16",20,"Chroma Boneblade",22,nil,1,"Stable")
add("godly","740",5150,"Traveler's Gun",5200,nil,5,"Stable")
add("godly","770",3425,"Evergun",3450,nil,5,"Stable")
add("godly","769",2700,"Evergreen",2700,nil,5,"Stable")
add("godly","856",2475,"Constellation",2500,nil,5,"Stable")
add("godly","830",1875,"Vampire's Gun",1900,nil,5,"Stable")
add("godly","762",1850,"Turkey",1850,nil,5,"Stable")
add("godly","926",1850,"Alienbeam",1900,nil,6,"Stable")
add("godly","925",1825,"Raygun",1875,nil,6,"Stable")
add("godly","741",1550,"Darkshot",1500,nil,5,"Underpaid For")
add("godly","742",1525,"Darksword",1475,nil,5,"Underpaid For")
add("godly","696",1160,"Blossom",1160,nil,5,"Stable")
add("godly","697",1150,"Sakura",1150,nil,5,"Stable")
add("godly","901",775,"Sunrise",800,nil,5,"Stable")
add("godly","961",680,"Snowcannon",675,nil,5,"Stable")
add("godly","854",675,"Bauble",675,nil,5,"Stable")
add("godly","902",650,"Sunset",650,nil,5,"Stable")
add("godly","833",625,"Soul",605,nil,5,"Underpaid For")
add("godly","832",615,"Spirit",595,nil,5,"Underpaid For")
add("godly","924",440,"Xenoshot",420,nil,4,"Stable")
add("godly","923",435,"Xenoknife",420,nil,4,"Stable")
add("godly","715",410,"Rainbow Gun",405,nil,4,"Stable")
add("godly","891",405,"Flora",400,nil,4,"Stable")
add("godly","714",400,"Rainbow",400,nil,4,"Stable")
add("godly","890",395,"Bloom",395,nil,4,"Stable")
add("godly","989",350,"Heart Wand",340,nil,4,"Stable")
add("godly","955",250,"Blizzard",250,nil,3,"Stable")
add("godly","956",250,"Snowstorm",250,nil,3,"Stable")
add("godly","728",240,"Ocean",245,nil,3,"Stable")
add("godly","795",235,"Flowerwood Gun",240,nil,3,"Stable")
add("godly","727",235,"Waves",240,nil,3,"Stable")
add("godly","794",230,"Flowerwood",235,nil,3,"Stable")
add("godly","959",170,"Snow Dagger",175,nil,3,"Stable")
add("godly","988",155,"Treat",155,nil,3,"Stable")
add("godly","1005",155,"Icecream",145,nil,3,"Stable")
add("godly","811",150,"Watergun",145,nil,3,"Stable")
add("godly","987",150,"Sweet",150,nil,3,"Stable")
add("godly","1031",140,"Mortal",140,nil,3,"Fluctuating")
add("godly","1032",140,"Immortal",140,nil,3,"Fluctuating")
add("godly","859",140,"Borealis",140,nil,2,"Stable")
add("godly","858",135,"Australis",135,nil,2,"Stable")
add("godly","618",120,"Bat",125,nil,2,"Stable")
add("godly","23",90,"Candy",80,nil,1,"Stable")
add("godly","1028",80,"Embersickle",90,nil,2,"Fluctuating")
add("godly","813",80,"Pearlshine",80,nil,1,"Stable")
add("godly","1003",80,"Beachy",75,nil,1,"Stable")
add("godly","1004",80,"Sands",75,nil,1,"Stable")
add("godly","812",75,"Pearl",75,nil,1,"Stable")
add("godly","512",65,"Heartblade",65,nil,1,"Stable")
add("godly","984",60,"Ornament",65,nil,1,"Stable")

return S