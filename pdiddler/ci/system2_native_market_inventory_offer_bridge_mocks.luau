-- Real Lune executes production pure market bridge, exact GUI adapter, and glue.
-- Market prices are actual current source-crosswalk JSON produced by this CI job.
-- Roblox service objects and scanner snapshots are *mocked*: NOT original-game PASS.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local base="pdiddler/system2/"
local market=serde.decode("json",fs.readFile(base.."research_market_crosswalk_current.json"))
local sourceEpoch=tonumber(fs.readFile(base.."research_market_epoch.txt"))
local core=luau.load(fs.readFile(base.."native_market_inventory_offer_core.lua"))()
local capture=luau.load(fs.readFile(base.."native_market_offer_client_capture.lua"))()
local glue=luau.load(fs.readFile(base.."native_market_inventory_offer_bridge.lua"))()
local count=0
local function eq(x,y,label)
 count+=1
 assert(x==y,label..": expected "..tostring(y)..", got "..tostring(x))
end
local function ok(x,label)count+=1;assert(x,label)end
local rows={}
for _,row in ipairs(market.items) do rows[row.rawGameKeyCandidate]=row end
eq(#market.items,189,"actual market count")
eq(rows.Gingerscope.mm2Listed,16000,"real live Gingerscope MM2")
eq(rows.FlowerwoodKnife.marketSlug,"flowerwood-knife","site alias")
eq(rows.FlowerwoodKnife.supremeListed,nil,"missing published Supreme stays nil")
eq(rows.EmberbowChroma.gameRarity,"Ancient","chroma ancient")
eq(rows.ChromaDarkbringer.gameRarity,"Godly","chroma godly")

local sync={Weapons={}}
for _,row in ipairs(market.items) do
 sync.Weapons[row.rawGameKeyCandidate]={
  ItemName=row.expectedGameName,ItemType=row.gameItemType,
  Rarity=row.gameRarity,Chroma=row.gameChroma,
 }
end
local scannerReads=0
local profileItems={"EmberbowChroma","FlowerwoodKnife","Gingerscope"}
local quantities={EmberbowChroma=6,FlowerwoodKnife=1,Gingerscope=1}
local function scannerSnapshot()
 local result={items={},seen={},rawOwned=8,unmapped=0,badQty=0,
   unpriced=8,total=999999999,fingerprint=""}
 for _,id in ipairs(profileItems) do
  local r=rows[id]
  table.insert(result.items,{
   id=id,cat="Weapons",name=(r.gameChroma and "Chroma " or "")..r.expectedGameName,
   qty=quantities[id],page=r.marketCategory,type=r.gameItemType,
   value=777777777,checkerId="UNPRICED",valueSource="2026-10-31",
   identity="irrelevant-stale-checker",year="",event=""
  })
  table.insert(result.seen,id.."x"..tostring(quantities[id]))
 end
 table.sort(result.seen)
 result.fingerprint=table.concat(result.seen,"|")
 return result
end
local reader={getOwnInventory=function()
 scannerReads+=1
 return scannerSnapshot(),nil
end}
local function node(kind,name)
 local o={ClassName=kind,Name=name,children={},Visible=true,Enabled=true,
  Text="",Attributes={}}
 function o:IsA(k)
  if self.ClassName==k then return true end
  if k=="GuiObject" then
   return self.ClassName=="Frame" or self.ClassName=="TextLabel" or
    self.ClassName=="TextButton" or self.ClassName=="ImageLabel"
  end
  return false
 end
 function o:FindFirstChild(n,recursive)
  local x=self.children[n]
  if x then return x end
  if recursive then
   for _,c in pairs(self.children) do
    local y=c:FindFirstChild(n,true)
    if y then return y end
   end
  end
  return nil
 end
 function o:FindFirstChildOfClass(k)
  if k=="PlayerGui" and self.children.PlayerGui then return self.children.PlayerGui end
  for _,v in pairs(self.children) do if v:IsA(k) then return v end end
 end
 function o:GetAttribute(name) return self.Attributes[name] end
 function o:put(v) v.Parent=self;self.children[v.Name]=v;return v end
 return o
end
local players={}
local pg=node("PlayerGui","PlayerGui")
local localPlayer={UserId=121111112}
function localPlayer:FindFirstChildOfClass(n)
 if n=="PlayerGui" then return pg end
end
players.LocalPlayer=localPlayer
local opponent={UserId=565555552,Name="PartnerUser",Parent=players}
function players:GetPlayerByUserId(id)
 return id==opponent.UserId and opponent or nil
end
local screen=pg:put(node("ScreenGui","TradeGUI"))
local root=screen:put(node("Frame","Container")):put(node("Frame","Trade"))
local function makeSide(name)
 local side=root:put(node("Frame",name))
 side:put(node("Frame","Accepted")).Visible=false
 local container=side:put(node("Frame","Container"))
 return side,container
end
local our,ourList=makeSide("YourOffer")
local their,theirList=makeSide("TheirOffer")
their:put(node("TextLabel","Username")).Text="(PartnerUser)"
local function appendSlot(parent,num,id,label,amount,chroma)
 local slot=parent:put(node("Frame","NewItem"..tostring(num)))
 slot.Attributes.ItemId=id
 slot:put(node("Frame","ItemName")):put(node("TextLabel","Label")).Text=label
 slot:put(node("Frame","Container")):put(node("TextLabel","Amount")).Text=amount
 if chroma then slot:put(node("Frame","Tags")):put(node("Frame","Chroma")) end
 return slot
end
local ours=appendSlot(ourList,1,"EmberbowChroma","Chroma Emberbow","x6",true)
local theirs=appendSlot(theirList,1,"Iceblaster","Iceblaster","",false)
local job="MAIN_ORIGINAL_JOB_001"
local lease="REAL_P3_LEASE_001"
local game={PlaceId=142823291,JobId=job}
local scope={jobId=job,leaseId=lease,localUserId=localPlayer.UserId,
 partnerUserId=opponent.UserId,root=root}
local active=true
local monotonic=1.0
local utc=sourceEpoch+20
local function now()return monotonic end
local function tick()return utc end
local adapter,why=capture.new({game=game,players=players,scope=scope,
 isBoundSession=function()return active end})
ok(adapter~=nil,"actual P4 style GUI capture adapter built")
local firstFrame=adapter.capture()
eq(firstFrame.doubleReadStable,true,"real-geometry two-read stable")
eq(firstFrame.ourSlots[1].rawId,"EmberbowChroma","exact attribute raw id")
eq(firstFrame.theirSlots[1].amountText,"","single stack empty amount preserved")
local bridge,reason=glue.new({core=core,captureAdapter=capture,scope=scope,
 game=game,players=players,sync=sync,scannerApi=reader,crosswalk=market,
 isBoundSession=function()return active end,
 utcNow=tick,monoNow=now,sourceRetrievedEpoch=sourceEpoch})
ok(bridge~=nil,"scanner and P4 GUI bridge actually wired")
local stale=bridge.observeOffer()
eq(stale.reason,"OWN_CENSUS_EXPIRED_REFRESH_REQUIRED","must inventory first")
local own=bridge.refreshOwn()
eq(own.status,"READONLY_OWN_MARKET_BOUND","real mapped market + stale scanner input")
eq(own.matchedEligibleKeys,3,"three raw ids")
eq(own.matchedEligibleCopies,8,"six-copy Chroma stack one item")
eq(own.mm2ListedSubtotal,6*rows.EmberbowChroma.mm2Listed+
 rows.FlowerwoodKnife.mm2Listed+rows.Gingerscope.mm2Listed,"source value own")
eq(own.supremeListedSubtotal,nil,"single-source Flowerwood missing Supreme")
eq(own.scannerLegacyPriceIgnored,true,"no October 31 price")
eq(scannerReads,1,"existing scanner called once")
local observe=bridge.observeOffer()
eq(observe.status,"CLIENT_OFFER_OBSERVATION_READONLY","observed real shape")
eq(observe.clientRevision,1,"initial client revision")
eq(observe.our.physicalSlots,1,"one physical slot with six copies")
eq(observe.our.items[1].quantity,6,"six actual copies in single slot")
eq(observe.their.items[1].id,"Iceblaster","opponent raw ID")
eq(observe.mm2ListedDelta,rows.Iceblaster.mm2Listed-
 6*rows.EmberbowChroma.mm2Listed,"current site bilateral delta")
eq(observe.serverOfferRevisionProven,false,"not server proof")
eq(observe.authorizesAccept,false,"never accepts")
local repeatFrame=bridge.observeOffer()
eq(repeatFrame.clientRevision,1,"unchanged stable client revision")
ours:FindFirstChild("Container"):FindFirstChild("Amount").Text="x5"
local changed=bridge.observeOffer()
eq(changed.status,"CLIENT_OFFER_CHANGED_PREVIEW_INVALIDATED","offer changed")
eq(changed.clientRevision,2,"revision advanced")
eq(changed.priorPreviewInvalidated,true,"old preview invalidated")
ours:FindFirstChild("Container"):FindFirstChild("Amount").Text="x7"
eq(bridge.observeOffer().reason,"OUR_OUTGOING_TARGET_OR_QUANTITY_INVALID",
   "outgoing qty greater than profile")
ours:FindFirstChild("Container"):FindFirstChild("Amount").Text="x6"
ours.Attributes.ItemId="Gingerscope"
ours:FindFirstChild("Tags").children.Chroma.Visible=false
ours:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Gingerscope"
eq(bridge.observeOffer().reason,"OUR_OUTGOING_TARGET_OR_QUANTITY_INVALID",
   "Gingerscope never outbound")
ours.Attributes.ItemId="EmberbowChroma"
ours:FindFirstChild("Tags").children.Chroma.Visible=true
ours:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Chroma Emberbow"
ours:FindFirstChild("Tags").children.Chroma.Visible=false
eq(bridge.observeOffer().reason,"OUR_OFFER_RAW_KEY_LABEL_OR_CHROMA_CONFLICT",
   "wrong chroma tag fails closed")
ours:FindFirstChild("Tags").children.Chroma.Visible=true
ours.Attributes.ItemId=nil
eq(bridge.observeOffer().reason,"OFFER_SESSION_PARTNER_OR_ROOT_UNVERIFIED",
   "no raw slot key rejects name-only")
ours.Attributes.ItemId="EmberbowChroma"
opponent.Name="SomeoneElse"
eq(bridge.observeOffer().reason,"OFFER_SESSION_PARTNER_OR_ROOT_UNVERIFIED",
   "changed partner GUI association rejects")
opponent.Name="PartnerUser"
active=false
eq(bridge.observeOffer().reason,"OFFER_SESSION_PARTNER_OR_ROOT_UNVERIFIED",
   "stolen or invalidated lease")
active=true
monotonic=40
eq(bridge.observeOffer().reason,"OWN_CENSUS_EXPIRED_REFRESH_REQUIRED",
   "own profile max age 30 seconds")
monotonic=1.4
utc=sourceEpoch+21601
eq(bridge.refreshOwn().reason,"SOURCE_CROSSWALK_EXPIRED_OR_UNVERIFIED",
   "source 6hr expires and stops")
utc=sourceEpoch+20
local counterfeit=serde.decode("json",fs.readFile(base.."research_market_crosswalk_current.json"))
counterfeit.authorizesTrade=true
local nope,err=core.new({scannerApi=reader,sync=sync,crosswalk=counterfeit,
 captureOffer=adapter.capture,utcNow=tick,monoNow=now,
 sourceRetrievedEpoch=sourceEpoch,jobId=job,leaseId=lease,
 partnerUserId=opponent.UserId})
eq(nope,nil,"forged trade authorization rejected")
eq(err,"SOURCE_CROSSWALK_CONTRACT_INVALID","source authority denial")
print("SYSTEM2_LIVE_MARKET_NATIVE_BRIDGE_ASSERTIONS_PASSED "..tostring(count))
