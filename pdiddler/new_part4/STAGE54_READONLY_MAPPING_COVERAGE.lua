-- Gingerscope Stage54: read-only live MM2 raw->legacy checker mapping COVERAGE audit.
-- Source resolver copied verbatim from Stage51 scanner PR90 SHA 7a289d62ef3f0be0a299506eb451c57435493be3.
-- Reference rows retain page/ID/image ONLY; all numeric prices are replaced by ZERO.
-- Frozen snapshot images are not current nor independently authenticated MM2 key mapping.
-- No webhooks, trade offers, player reads, inventory remotes, or game-state mutations.
local marker="[GINGERSCOPE STAGE54 MAPPING COVERAGE]"
local R={schema="gingerscope-stage54-mapping-coverage-v1",readOnly=true,clientOnly=true,
 mappingAuthenticated=false,externalCheckerIdentityVerified=false,
 sourceSnapshotIsFrozen=true,currentPriceSourceUsed=false,uniqueWeaponInstanceProven=false,
 eventSessionAssociationProven=false,serverCompletionProven=false,serverAttestation=false,
 authorizesTrade=false,authorizesAccept=false,mayRecordCompletedTrade=false,mayReportProfit=false,
 tradeOutcome="UNKNOWN",status="INCOMPLETE",catalogRows=0,eligible=0,excluded=0,
 explicitInternal=0,displayAlias=0,fuzzy=0,ambiguous=0,unresolved=0,
 otherResolverFail=0,invalidCatalogRows=0,printableKeyCollisions=0,
 duplicateTargetGroups=0,duplicateTargetEntries=0,yearHintConflicts=0,
 yearHintsComparable=0,placeholderArtworkMatches=0,filteredChroma=0}
-- Best-effort local clipboard convenience. Only the anonymized aggregate report
-- may leave the observer; no raw catalogue data or inventory is ever copied.
local function tryClipboard(fn,line)
 if type(fn)~="function" then return false end
 local ok,accepted=pcall(fn,line)
 return ok and accepted~=false
end
local function copySummary(line)
 if tryClipboard(setclipboard,line) then return true end
 if tryClipboard(toclipboard,line) then return true end
 if type(getgenv)=="function" then
  local ok,env=pcall(getgenv)
  if ok and type(env)=="table" then
   if tryClipboard(env.setclipboard,line) then return true end
   if tryClipboard(env.toclipboard,line) then return true end
  end
 end
 return false
end
local function emit(status)
 R.status=status
 local ok,result=pcall(function()return game:GetService("HttpService"):JSONEncode(R)end)
 if not ok or type(result)~="string" then
  print(marker.." REPORT_ENCODING_FAILED")
  return R
 end
 local line=marker.." "..result
 -- Clipboard failure cannot suppress the diagnostic; the console remains usable.
 local copied=copySummary(line)
 print(line)
 if copied then print("[STAGE54] CLIPBOARD_COPIED")
 else print("[STAGE54] CLIPBOARD_UNAVAILABLE_COPY_REPORT_FROM_CONSOLE") end
 return R
end
local function norm(x)
 return tostring(x or ""):gsub("’","'"):lower():gsub("[^%w]","")
end
local function identityName(meta)
 if not meta then return "" end
 local name=tostring(meta.name or meta.id or "")
 if meta.chroma then
  return name:lower():match("^chroma%s") and name or ("Chroma "..name)
 end
 return name
end
local function log(...) end -- frozen reference builder's legacy log intentionally silent
local VALUE_SNAPSHOT_UPDATED="FROZEN_LEGACY_NOT_A_PRICE_SOURCE"
local Checker={rows={},byId={},ready=false}
-- BEGIN FROZEN IMAGE REF (not prices)
Checker.raw=[==[
ancient|1|0|NiksScythe.png
ancient|771|0|Gingerscope.png
ancient|743|0|TravellersAxe.png
ancient|860|0|Celestial.png
ancient|829|0|vampsaxe.png
ancient|1026|0|Emberbow.png
ancient|1027|0|Emberscythe.png
ancient|526|0|harvester.png
ancient|661|0|Icepiercer.png
ancient|480|0|Icebreaker.png
ancient|3|0|BatwingUpdated.png
ancient|2|0|ewscythe.png
ancient|529|0|SwirlAxe.png
ancient|471|0|HallowscytheUp.png
ancient|404|0|LogchopperUp.png
ancient|4|0|IcewingknifeUp.png
chroma|739|0|ChromaTravGun.png
chroma|772|0|Chroma_Evergun.png
chroma|773|0|Chroma_Evergreen.png
chroma|855|0|CBauble.png
chroma|857|0|ChromaConstellation.png
chroma|831|0|chromavampsgun.png
chroma|927|0|ChromaAlienbeam.png
chroma|1036|0|Chroma_Emberscythe.png
chroma|928|0|ChromaRaygun.png
chroma|899|0|ChromaSunsetGun.png
chroma|962|0|Chroma_Snowcannon.png
chroma|1030|0|Chroma_Emberbow.png
chroma|900|0|ChromaSunsetKnife.png
chroma|957|0|ChromaBlizzard.png
chroma|958|0|Chroma_Snowstorm.png
chroma|990|0|CHeartwand.png
chroma|960|0|Chroma_Snow_Dagger.png
chroma|810|0|Chroma_Watergun.png
chroma|1006|0|C_Icecream.png
chroma|1033|0|coming.png
chroma|1034|0|coming.png
chroma|985|0|Chroma_Ornament.png
chroma|992|0|Ctreat.png
chroma|991|0|Csweet.png
chroma|1007|0|CSands.png
chroma|1008|0|CBeachy.png
chroma|1029|0|Chroma_Embersickle.png
chroma|447|0|Chroma_Darkbringer.png
chroma|446|0|Chroma_Lightbringer.png
chroma|6|0|chromaluger.png
chroma|8|0|chromalaser.png
chroma|525|0|chromacandle.png
chroma|13|0|chromads.png
chroma|527|0|chromaswirlygun.png
chroma|616|0|ChromaElderwoodBlade.png
chroma|7|0|chromashark.png
chroma|9|0|chromaslasher.png
chroma|10|0|chromafang.png
chroma|439|0|chromagem.png
chroma|11|0|chromaheat.png
chroma|659|0|ChromaCookiecane.png
chroma|14|0|chromatides.png
chroma|15|0|chromaseer.png
chroma|17|0|Chroma_Gingerblade.png
chroma|12|0|chromasaw.png
chroma|16|0|Chroma_Boneblade.png
godly|740|0|TravGun.png
godly|770|0|Evergun.png
godly|769|0|Evergreen.png
godly|856|0|2024Constellation.png
godly|830|0|vampsgun.png
godly|762|0|Turkey.png
godly|926|0|Alienbeam.png
godly|925|0|Raygun.png
godly|741|0|Darkshot.png
godly|742|0|Darksword.png
godly|696|0|BlossomGun.png
godly|697|0|Sakura.png
godly|901|0|SunsetGun.png
godly|961|0|Snowcannon.png
godly|854|0|Bauble.png
godly|902|0|SunsetKnife.png
godly|833|0|soul.png
godly|832|0|spirit.png
godly|924|0|Xenoshot.png
godly|923|0|Xenoknife.png
godly|715|0|rainbowgun.png
godly|891|0|Flora_Gun.png
godly|714|0|Rainbowblade.png
godly|890|0|Bloom_Knife.png
godly|989|0|Heartwand.png
godly|955|0|Blizzard.png
godly|956|0|Snowstorm.png
godly|728|0|Ocean_gun.png
godly|795|0|Flowerwood_Gun.png
godly|727|0|Waves_knife.png
godly|794|0|Flowerwood_Knife.png
godly|959|0|Snow_Dagger.png
godly|988|0|Treat.png
godly|1005|0|Icecream_knife.png
godly|811|0|WaterGun.png
godly|987|0|Sweet.png
godly|1031|0|Mortal.png
godly|1032|0|Immortal.png
godly|859|0|2024Borealis.png
godly|858|0|2024Australis.png
godly|618|0|Bat_Zombie.png
godly|23|0|Updated_Candy.png
godly|1028|0|Embersickle.png
godly|813|0|Pearlsh.png
godly|1003|0|BeachyGodly2026.png
godly|1004|0|SandsGodly2026.png
godly|812|0|Pearl.png
godly|512|0|HeartBladeUp.png
godly|984|0|ornagodly.png
godly|20|0|Red_Luger.png
godly|620|0|Phantom_Shop.png
godly|621|0|Spectre.png
godly|524|0|candleflame.png
godly|18|0|ewrev.png
godly|448|0|DarkbringerUpdated.png
godly|481|0|IceblasterUP.png
godly|22|0|Sugar_v2.png
godly|617|0|Makeshift.png
godly|445|0|LightbringerUpdated.png
godly|619|0|ElderwoodBlade.png
godly|21|0|Green_Luger.png
godly|30|0|AmeriUP.png
godly|46|0|LaserUpdated.png
godly|472|0|hallowgunup.png
godly|532|0|IceBeamUP.png
godly|48|0|SharkUP.png
godly|572|0|Plasmabeam.png
godly|63|0|NightBladeUp.png
godly|528|0|SwirlGunUP.png
godly|531|0|IceFlakeUP.png
godly|32|0|BattleAxe2UP.png
godly|34|0|PixelUp.png
godly|36|0|Ginger_LugerUP.png
godly|31|0|OldGloryUp.png
godly|35|0|BlasterUP.png
godly|39|0|LugerUpdated.png
godly|573|0|Plasmablade.png
godly|37|0|VirtualUP.png
godly|43|0|SlasherUP.png
godly|405|0|MintyUp.png
godly|408|0|LugerCaneUP.png
godly|473|0|VampiresedgeUP.png
godly|482|0|JinglegunUP.png
godly|660|0|Cookiecane.png
godly|662|0|Gingermint.png
godly|522|0|NebulaUp.png
godly|530|0|SwirlyBladeUP.png
godly|49|0|DeathshardUp.png
godly|57|0|Battleaxe1UP.png
godly|60|0|GingerbladeUP.png
godly|379|0|eternalcane.png
godly|440|0|GemstoneUP.png
godly|24|0|ChillUpdated4.png
godly|28|0|ClockworkUp.png
godly|33|0|SpiderUP.png
godly|40|0|HeatUP.png
godly|42|0|TidesUP.png
godly|47|0|FangUp.png
godly|26|0|EternalUpdated.png
godly|41|0|XmasUP.png
godly|58|0|FrostsaberUP.png
godly|441|0|eternal3.png
godly|444|0|Mm2bioblade.png
godly|467|0|Eternal4UP.png
godly|25|0|Handsaw_Png.png
godly|29|0|HallowEdgeUp.png
godly|59|0|IceShardUP.png
godly|19|0|Eternal_2UP.png
godly|27|0|BonebladeUP.png
godly|44|0|PumpkingUP.png
godly|45|0|SawUP.png
godly|62|0|ghostblade.png
godly|38|0|FlamesUp.png
godly|50|0|WinterEdgeUP.png
godly|51|0|IceDragonUp.png
godly|64|0|HallowsbladeUP.png
godly|407|0|FrostbiteUP.png
godly|521|0|EggbladeUP.png
godly|61|0|SnowflakeUP.png
godly|468|0|PrismaticUp.png
godly|479|0|peppermint.png
godly|483|0|CookiebladeUP.png
godly|52|0|redseer.png
godly|53|0|blueseer.png
godly|54|0|purpleseer.png
godly|889|0|Seer.png
godly|55|0|orangeseer.png
godly|56|0|yellowseer.png
]==]
-- END FROZEN IMAGE REF
-- BEGIN VERBATIM RESOLVER FROM REVIEWED STAGE51 SCANNER
local function checkerPage(meta)
 if not meta then return nil end
 if meta.chroma then return "chroma" end
 local r=norm(meta.rarity)
 if r=="ancient" or r=="godly" then return r end
 return nil
end

local function allowedPage(page) return page=="ancient" or page=="godly" or page=="chroma" end

local function qualifyingMeta(meta)
 if not meta then return false end
 if not allowedPage(checkerPage(meta)) then return false end

 local t=norm(meta.type)
 if t~="knife" and t~="gun" then return false end

 local d=meta.data or {}

 -- Evolution stages are catalog/progression entries, not normal tradable
 -- weapons. Examples: Reaver_Ancient, IceHammer_Ancient,
 -- Gingerscythe_Ancient, Synthwave_Ancient.
 if d.EvoBaseID~=nil or d.EvoIndex~=nil then
  return false
 end

 -- MM2 contains placeholder/test Godly entries named "???" such as
 -- Emptybringer. They must never create a whitelist target.
 if norm(meta.name)==""
  or tostring(meta.name)=="???"
 then
  return false
 end

 -- Honor explicit non-trade metadata when MM2 supplies it. Missing flags are
 -- not treated as non-tradable, so ordinary catalog items remain eligible.
 if d.Tradable==false
  or d.CanTrade==false
  or d.Untradable==true
  or d.NonTradable==true
 then
  return false
 end

 return true
end

local function checkerBuild()
 if Checker.ready then return true end
 local count=0
 for line in tostring(Checker.raw):gmatch("[^\r\n]+") do
  local page,id,val,img=line:match("^([^|]+)|([^|]+)|([^|]+)|(.+)$")
  val=tonumber(val)
  if page and id and val and img then
   Checker.rows[page]=Checker.rows[page] or {}
   Checker.byId[page]=Checker.byId[page] or {}
   local rec={page=page,id=tostring(id),v=val,img=tostring(img)}
   Checker.rows[page][#Checker.rows[page]+1]=rec
   Checker.byId[page][rec.id]=rec
   count=count+1
  end
 end
 Checker.ready=count>0
 log("IDENTITY MAP READY",count,"legacy mapping reference",VALUE_SNAPSHOT_UPDATED,"| displayed values use pinned Supreme")
 return Checker.ready
end

local function checkerCanon(x,page,itemType,level)
 local raw=tostring(x or ""):gsub("%.[^%.]+$","")
 local q=norm(raw)
 q=q:gsub("travellers","traveler"):gsub("travelers","traveler"):gsub("strarry","starry"):gsub("knfie","knife"):gsub("spearmingun","spearmintgun"):gsub("brozen","bronze"):gsub("pumpin","pumpkin")
 if q:sub(1,8)=="travsaxe" then q="traveleraxe"..q:sub(9)
 elseif q:sub(1,7)=="travgun" then q="travelergun"..q:sub(8)
 elseif q:sub(1,8)=="vampsaxe" then q="vampiresaxe"..q:sub(9)
 elseif q:sub(1,8)=="vampsgun" then q="vampiresgun"..q:sub(9)
 elseif q:sub(1,7)=="vampaxe" then q="vampiresaxe"..q:sub(8)
 elseif q:sub(1,6)=="gscope" then q="gingerscope"..q:sub(7)
 elseif q:sub(1,8)=="ewscythe" then q="elderwoodscythe"..q:sub(9) end
 if (tonumber(level) or 0)>=1 then
  q=q:gsub("20%d%d",""):gsub("updated",""):gsub("update",""):gsub("godly","")
  if #q>4 and q:sub(-2)=="up" then q=q:sub(1,-3) end
  if #q>4 and q:sub(-2)=="v2" then q=q:sub(1,-3) end
  if page=="chroma" then
   if q:sub(1,6)=="chroma" then q=q:sub(7) elseif q:sub(1,1)=="c" and #q>4 then q=q:sub(2) end
  end
 end
 if (tonumber(level) or 0)>=2 then
  local t=norm(itemType)
  if t~="" and #q>#t+2 and q:sub(-#t)==t then q=q:sub(1,#q-#t) end
  if t=="knife" and #q>4 and q:sub(-1)=="k" then q=q:sub(1,-2)
  elseif t=="gun" and #q>4 and q:sub(-1)=="g" then q=q:sub(1,-2) end
 end
 return q
end

local CheckerInternalKey={
 godly={
  BattleAxe="57",
  Bioblade="444",
  Chill="24",
  Handsaw="25",
  Phantom2022="620",
  Rainbow_K="714",
 },
 chroma={
  CandleflameChroma="525",
 },
 ancient={}
}

local function checkerInternalAlias(page,meta)
 if not meta then return nil end
 local bucket=CheckerInternalKey[page]
 return bucket and bucket[tostring(meta.id)] or nil
end

local function checkerAlias(page,name,typ)
 local q,t=norm(name),norm(typ)
 if page=="chroma" and (q=="chromadeathshard" or q=="deathshard") then return "13" end
 if page=="chroma" and (q=="chromatravelersgun" or q=="chromatravellersgun" or q=="travelersgun" or q=="travellersgun") then return "739" end
 if page=="chroma" and (q=="chromavampiresgun" or q=="vampiresgun") then return "831" end
 if page=="godly" and q=="pearlshine" then return "813" end
 if page=="godly" and q=="bat" then return "618" end
 if page=="godly" and q=="ornament" then return "984" end
 if page=="godly" and q=="amerilaser" then return "30" end
 if page=="godly" and (q=="swirlygun" or q=="swirlgun") then return "528" end
 if page=="godly" and (q=="hallowsedge" or q=="hallowedge") then return "29" end
 if page=="godly" and (q=="elderwoodrevolver" or q=="ewrevolver") then return "18" end
 if page=="ancient" and (q=="swirlyaxe" or q=="swirlaxe") then return "529" end
 if page=="godly" and (q=="wintersedge" or q=="winteredge") then return "50" end
 if page=="godly" and q=="sunrise" and (t=="" or t=="gun") then return "901" end
 if page=="godly" and q=="sunset" and (t=="" or t=="knife") then return "902" end
 if page=="chroma" and (q=="chromasunrise" or q=="sunrise") and (t=="" or t=="gun") then return "899" end
 if page=="chroma" and (q=="chromasunset" or q=="sunset") and (t=="" or t=="knife") then return "900" end
 if page=="chroma" and (q=="chromagemstone" or q=="gemstone") then return "439" end
 if page=="chroma" and (q=="chromamortal" or q=="mortal") then return "1033" end
 if page=="chroma" and (q=="chromaimmortal" or q=="immortal") then return "1034" end
end

local checkerCache={}
local function checkerResolve(name,opts)
 if not checkerBuild() then return nil,"snapshot unavailable" end
 opts=type(opts)=="table" and opts or {}
 local shown=tostring(name or "")
 local pageHint=tostring(opts.page or "")
 local typ=tostring(opts.type or "")
 local iid=tostring(opts.id or "")
 local chroma=opts.chroma==true
 local meta=opts.meta
 if shown=="" and meta then shown=identityName(meta) end
 if pageHint=="" and meta then pageHint=checkerPage(meta) or "" end
 if typ=="" and meta then typ=tostring(meta.type or "") end
 if iid=="" and meta then iid=tostring(meta.id or "") end
 if meta and meta.chroma then chroma=true end
 if pageHint~="" and not allowedPage(pageHint) then return nil,"tier excluded" end
 local ck=table.concat({norm(shown),pageHint,norm(typ),norm(iid),chroma and "1" or "0"},"|")
 local cached=checkerCache[ck]
 if cached then
  -- Never degrade a previously determined source method into "cache".
  -- A hit is only a performance detail, not new item-ID evidence.
  return cached.rec,cached.mappingMethod
 end
 if pageHint~="" then
  local internalId=checkerInternalAlias(pageHint,meta)
  local internalRec=internalId
   and Checker.byId[pageHint]
   and Checker.byId[pageHint][internalId]

  if internalRec then
   checkerCache[ck]={rec=internalRec,mappingMethod="internal-key"}
   return internalRec,"internal-key"
  end

  local aid=checkerAlias(pageHint,shown,typ)
  local rec=aid and Checker.byId[pageHint] and Checker.byId[pageHint][aid]
  if rec then
   checkerCache[ck]={rec=rec,mappingMethod="alias"}
   return rec,"alias"
  end
 end
 local pages={}
 if pageHint~="" then
  pages[1]=pageHint
 else
  return nil,"missing-tier"
 end
 local best,bestScore,tied,tiedSame=nil,-100000,false,true
 local md=meta and meta.data or {}
 local itemYear=tostring(md.Year or md.EventYear or ""):match("(20%d%d)")
 if not itemYear then itemYear=iid:match("(20%d%d)") end
 for _,page in ipairs(pages) do
  local n0,n1,n2=checkerCanon(shown,page,typ,0),checkerCanon(shown,page,typ,1),checkerCanon(shown,page,typ,2)
  local mn=meta and identityName(meta) or ""
  local m0,m1,m2=checkerCanon(mn,page,typ,0),checkerCanon(mn,page,typ,1),checkerCanon(mn,page,typ,2)
  local i0,i1,i2=checkerCanon(iid,page,typ,0),checkerCanon(iid,page,typ,1),checkerCanon(iid,page,typ,2)
  for _,rec in ipairs(Checker.rows[page] or {}) do
   local c0,c1,c2=checkerCanon(rec.img,page,typ,0),checkerCanon(rec.img,page,typ,1),checkerCanon(rec.img,page,typ,2)
   local score=-100000
   if n0~="" and c0==n0 then score=340 elseif n1~="" and c1==n1 then score=285 elseif n2~="" and c2==n2 then score=240 end
   if m0~="" and c0==m0 then score=math.max(score,360) elseif m1~="" and c1==m1 then score=math.max(score,300) elseif m2~="" and c2==m2 then score=math.max(score,255) end
   if i0~="" and c0==i0 then score=math.max(score,430) elseif i1~="" and c1==i1 then score=math.max(score,350) elseif i2~="" and c2==i2 then score=math.max(score,290) end
   if page==pageHint then score=score+45 end
   local rawImg,t=norm(rec.img),norm(typ)
   if t=="gun" then if rawImg:find("knife",1,true) then score=score-180 elseif rawImg:find("gun",1,true) then score=score+20 end
   elseif t=="knife" then if rawImg:find("gun",1,true) then score=score-180 elseif rawImg:find("knife",1,true) then score=score+20 end end
   local checkerYear=tostring(rec.img):match("(20%d%d)")
   if itemYear and checkerYear then if itemYear==checkerYear then score=score+65 else score=score-120 end end
   if score>bestScore then best,bestScore,tied,tiedSame=rec,score,false,true
   elseif score==bestScore and best and rec.id~=best.id then tied=true; if math.abs((rec.v or 0)-(best.v or 0))>.000001 then tiedSame=false end end
  end
 end
 if best and bestScore>=200 and not tied then
  local origin="match:"..bestScore
  checkerCache[ck]={rec=best,mappingMethod=origin}
  return best,origin
 end
 if tied then return nil,"ambiguous" end
 return nil,"unresolved"
end

-- END VERBATIM RESOLVER FROM REVIEWED STAGE51 SCANNER
if type(game)~="table" and type(game)~="userdata" then return emit("GAME_UNAVAILABLE") end
if game.PlaceId~=142823291 then return emit("WRONG_GAME") end
local originalJob=tostring(game.JobId or "")
local ok,rs=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not rs then return emit("REPLICATED_STORAGE_UNAVAILABLE") end
local db=rs:FindFirstChild("Database")
local module=db and db:FindFirstChild("Sync")
if not module then return emit("SYNC_MODULE_MISSING") end
local success,sync=pcall(require,module)
if (not success or type(sync)~="table") and setthreadidentity then
 local old
 if getthreadidentity then pcall(function()old=getthreadidentity()end)end
 pcall(setthreadidentity,2)
 success,sync=pcall(require,module)
 pcall(setthreadidentity,old or 8)
end
if not success or type(sync)~="table" then return emit("SYNC_UNAVAILABLE") end
if tostring(game.JobId or "")~=originalJob then return emit("SERVER_CHANGED") end
if type(sync.Weapons)~="table" then return emit("WEAPONS_CATALOG_MISSING") end
local seenKeys,targets={},{}
for raw,data in pairs(sync.Weapons) do
 if (type(raw)~="string" and type(raw)~="number") or type(data)~="table" then
  R.invalidCatalogRows=R.invalidCatalogRows+1
 else
  R.catalogRows=R.catalogRows+1
  local printable=tostring(raw)
  if seenKeys[printable] then R.printableKeyCollisions=R.printableKeyCollisions+1 end
  seenKeys[printable]=true
  local meta={id=printable,name=data.ItemName or data.Name or printable,
    data=data,chroma=data.Chroma==true,type=data.ItemType or "",rarity=data.Rarity or ""}
  if qualifyingMeta(meta) then
   R.eligible=R.eligible+1
   if meta.chroma then R.filteredChroma=R.filteredChroma+1 end
   local page=checkerPage(meta)
   local done,rec,why=pcall(checkerResolve,identityName(meta),
     {page=page,type=meta.type,id=meta.id,chroma=meta.chroma,meta=meta})
   if not done then R.otherResolverFail=R.otherResolverFail+1
   elseif rec==nil then
    if why=="ambiguous" then R.ambiguous=R.ambiguous+1
    elseif why=="unresolved" then R.unresolved=R.unresolved+1
    else R.otherResolverFail=R.otherResolverFail+1 end
   else
    if why=="internal-key" then R.explicitInternal=R.explicitInternal+1
    elseif why=="alias" then R.displayAlias=R.displayAlias+1
    elseif type(why)=="string" and why:match("^match:%d+$") then R.fuzzy=R.fuzzy+1
    else R.otherResolverFail=R.otherResolverFail+1 end
    local target=tostring(page)..":"..tostring(rec.id)
    targets[target]=(targets[target] or 0)+1
    local fromYear=tostring(data.Year or data.EventYear or ""):match("(20%d%d)")
    if not fromYear then fromYear=printable:match("(20%d%d)") end
    local imageYear=tostring(rec.img or ""):match("(20%d%d)")
    if fromYear and imageYear then
     R.yearHintsComparable=R.yearHintsComparable+1
     if fromYear~=imageYear then R.yearHintConflicts=R.yearHintConflicts+1 end
    end
    if norm(rec.img)=="comingpng" then R.placeholderArtworkMatches=R.placeholderArtworkMatches+1 end
   end
  else R.excluded=R.excluded+1 end
 end
end
for _,n in pairs(targets) do
 if n>1 then
  R.duplicateTargetGroups=R.duplicateTargetGroups+1
  R.duplicateTargetEntries=R.duplicateTargetEntries+n
 end
end
if tostring(game.JobId or "")~=originalJob then return emit("SERVER_CHANGED") end
if R.invalidCatalogRows>0 or R.printableKeyCollisions>0 then return emit("INVALID_CATALOG_SHAPE") end
if R.otherResolverFail>0 then return emit("RESOLVER_ERRORS_OR_MISSING_SNAPSHOT") end
if R.duplicateTargetGroups>0 or R.yearHintConflicts>0 or R.placeholderArtworkMatches>0 then
 return emit("CLIENT_MAPPING_RISK_COUNTS_UNVERIFIED")
end
return emit("CLIENT_MAPPING_COVERAGE_UNVERIFIED")
