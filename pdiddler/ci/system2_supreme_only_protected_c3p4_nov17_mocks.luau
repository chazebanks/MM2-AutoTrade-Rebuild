-- ACTUAL read-only original P4 GUI capture module + source-specific
-- Supreme-only adapter + Supreme-only price core under native Lune runtime.
-- Roblox Instances/scanner are synthetic mocks, NOT a physical iPad test.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local root="pdiddler/system2/"
local sourceBytes=fs.readFile(root.."supreme_only_189_research_catalog_2026_11_17_214118z_refresh.json")
-- Keep the earlier verified source solely as an adversarial stale-input fixture.
local legacySourceBytes=fs.readFile(root.."supreme_only_189_research_catalog_2026_11_17_refresh.json")
local catalog=serde.decode("json",sourceBytes)
local SOURCE_SHA256="fd657db48c00c996705093dadc384c1a0ddd4630398826108b5585ca76c2eca4"
local sha=luau.load(fs.readFile(root.."native_sha256_rfc6234_readonly.lua"))()
local function shaValue(s)return sha.hex(s)end
assert(shaValue("")=="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
assert(shaValue("abc")=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
assert(shaValue(sourceBytes)==SOURCE_SHA256,"pure Luau 189-row source SHA")
assert(serde.hash("sha256",sourceBytes)==SOURCE_SHA256,"actual source must be SHA256 pinned")
assert(shaValue(legacySourceBytes)~=SOURCE_SHA256,"earlier real catalog must not pass renewed SHA")
local supreme=luau.load(fs.readFile(root.."native_supreme_only_bilateral_research_nov17.lua"))()
local protected=luau.load(fs.readFile(root.."native_supreme_only_protected_c3p4_adapter_nov17.lua"))()
local p4=luau.load(fs.readFile(root.."native_market_offer_client_capture.lua"))()
local SOURCE_PIN="958038a6b22c43e8d0359cb15e6704bc84253430"
local CAPTURE=1794951678
local CLOCK=CAPTURE+30
local count=0
local function eq(a,b,why)
 count+=1
 assert(a==b,why..": expected "..tostring(b)..", got "..tostring(a))
end
local function yes(a,why)count+=1;assert(a,why)end
-- Both genuine publisher catalog pin and bounded simulated clock must agree.
eq(supreme.sourceStatus(catalog,SOURCE_PIN,CLOCK).status,
 "SUPREME_ONLY_RESEARCH_SOURCE_CHECKED","renewed source preflight")
eq(supreme.sourceStatus(catalog,"1497e9644ae271ff7a144aa5de43c30609f5c722",CLOCK).status,
 "BLOCKED","previous Git blob must not become a valid current catalog pin")
local function copy(t)return serde.decode("json",serde.encode("json",t))end
local function node(class,name)
 local self={ClassName=class,Name=name,Visible=true,Enabled=true,
  Text="",Attributes={},children={}}
 function self:IsA(t)
  if self.ClassName==t then return true end
  if t=="GuiObject" then
   return class=="Frame" or class=="TextLabel" or
     class=="TextButton" or class=="ImageLabel"
  end
  return false
 end
 function self:FindFirstChild(name,recursive)
  if self.children[name] then return self.children[name] end
  if recursive then for _,c in pairs(self.children) do
   local hit=c:FindFirstChild(name,true)
   if hit then return hit end end end
  return nil
 end
 function self:GetAttribute(name)return self.Attributes[name]end
 function self:put(x)x.Parent=self;self.children[x.Name]=x;return x end
 return self
end
local players={}
local pg=node("PlayerGui","PlayerGui")
local lp={UserId=121111112,Parent=players}
function lp:FindFirstChildOfClass(k)if k=="PlayerGui" then return pg end end
players.LocalPlayer=lp
local opponent={UserId=565555552,Name="SyntheticPartner",Parent=players}
function players:GetPlayerByUserId(id)
 if id==opponent.UserId and opponent.Parent==players then return opponent end
 return nil
end
local game={PlaceId=142823291,JobId="SYNTHETIC_ORIGINAL_JOB_NOV16"}
local http={}
function http:JSONDecode(bytes)return serde.decode("json",bytes)end
function game:GetService(s)
 if s=="Players" then return players end
 if s=="HttpService" then return http end
end
local screen=pg:put(node("ScreenGui","TradeGUI"))
local trade=screen:put(node("Frame","Container")):put(node("Frame","Trade"))
local function side(name)
 local n=trade:put(node("Frame",name))
 local a=n:put(node("Frame","Accepted"));a.Visible=false
 local c=n:put(node("Frame","Container"))
 return n,c,a
end
local ours,ourSlots,ourAccepted=side("YourOffer")
local theirs,theirSlots,theirAccepted=side("TheirOffer")
local name=theirs:put(node("TextLabel","Username"))
name.Text="(SyntheticPartner)"
local function insert(parent,number,key,label,amount,chroma)
 local slot=parent:put(node("Frame","NewItem"..number))
 slot.Attributes.ItemId=key
 slot:put(node("Frame","ItemName")):put(node("TextLabel","Label")).Text=label
 local amountLabel=slot:put(node("Frame","Container")):put(node("TextLabel","Amount"))
 amountLabel.Text=amount
 if chroma then
  slot:put(node("Frame","Tags")):put(node("Frame","Chroma"))
 end
 return slot,amountLabel
end
local ownSlot,amountOur=insert(ourSlots,1,"Harvester","Harvester","",false)
local theirSlot,amountTheir=insert(theirSlots,1,"FlowerwoodKnife","Flowerwood","x2",false)
local rawScope={jobId=game.JobId,leaseId="SYNTHETIC_PROTECTED_LEASE_NOV16",
 localUserId=lp.UserId,partnerUserId=opponent.UserId,root=trade}
local active=true
local scanReads=0
local readingClock=0
local changeOwnOnSecond=false
local catalogRows={}
local sync={Weapons={}}
for _,r in ipairs(catalog.rows) do
 catalogRows[r.rawGameKeyCandidate]=r
 local chroma=r.category=="chroma"
 local ancientChroma=(r.rawGameKeyCandidate=="EmberbowChroma" or
   r.rawGameKeyCandidate=="EmberscytheChroma")
 sync.Weapons[r.rawGameKeyCandidate]={
  ItemName=r.officialName,
  ItemType=(r.rawGameKeyCandidate=="Gingerscope" and "Gun" or "Knife"),
  Rarity=(r.category=="ancient" or ancientChroma) and "Ancient" or "Godly",
  Chroma=chroma,
 }
end
local quantities={Harvester=1,FlowerwoodKnife=2,Gingerscope=1}
local extraEligible=false
local scanner={getOwnInventory=function()
 scanReads+=1
 if extraEligible then
  sync.Weapons.UnknownHiddenWeapon={ItemName="Unknown Hidden Weapon",
    ItemType="Knife",Rarity="Godly",Chroma=false}
 end
 local raw=copy(quantities)
 if extraEligible then raw.UnknownHiddenWeapon=1 end
 if changeOwnOnSecond and scanReads==2 then
  raw.Harvester=2
 end
 local result={items={},seen={},unmapped=0,badQty=0,
  rawOwned=0,fingerprint="",value=99999999}
 for k,q in pairs(raw) do
  result.rawOwned+=q
  result.seen[#result.seen+1]=k.."x"..q
  if catalogRows[k] then
   local r=catalogRows[k]
   result.items[#result.items+1]={
    id=k,qty=q,cat="Weapons",page=r.category,
    name=r.officialName,type=sync.Weapons[k].ItemType,
    checkerId="STALE",value=7777777}
  end
 end
 table.sort(result.seen)
 result.fingerprint=table.concat(result.seen,"|")
 return result,nil
end}
local function hostHandle()
 return {
  scope=rawScope,readOnly=true,clientOnly=true,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  isBoundSession=function()return active end,
  status=function()
   return {schema="gingerscope-c9-original-p3-host-lease-v1",
    status=active and "ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND" or "BLOCKED",
    readOnly=true,clientOnly=true,serverCompletionProven=false,
    authorizesTrade=false,authorizesOffer=false,authorizesAccept=false}
  end,
 }
end
local clock=CLOCK
local function config(changes)
 local cfg={
  consentedToReadOnlyInventoryRpc=true,
  hostHandle=hostHandle(),game=game,players=players,
  sync=sync,scannerApi=scanner,captureAdapter=p4,
  supremeCore=supreme,sourceBytes=sourceBytes,
  sha256=sha.hex,
  utcNow=function()return clock end,
  monoNow=function()readingClock+=0.01;return readingClock end,
 }
 for key,val in pairs(changes or {}) do cfg[key]=val end
 return cfg
end
local function alt(give,receive)
 return {kind="HYPOTHETICAL_RESEARCH_ONLY",valueSource="SUPREME_ONLY",
  give=give,receive=receive}
end
local function item(id,q)return {id=id,quantity=q or 1}end
local option=alt({item("Harvester")},{item("FlowerwoodKnife",2)})
local function new(modified)
 local a,err=protected.new(config(modified))
 yes(a~=nil,"adapter new: "..tostring(err))
 return a
end
local bridge=new()
local result=bridge:preview({option})
eq(result.status,"SUPREME_ONLY_PROTECTED_C3_P4_SHADOW_OBSERVED",
 "actual protected scanner and P4 GUI bind Supreme-only core")
eq(result.valueSource,"SUPREME_ONLY","one publisher in native integration")
eq(result.hypotheticalAlternatives[1].supremeListedGain,195,
 "native partner 2 Flowerwood for our Harvester")
eq(result.hypotheticalAlternatives[1].demandIncoming,3,
 "current Supreme demand")
eq(result.authorizesTrade,false,"not a trade")
eq(result.authorizesOffer,false,"not an offer")
eq(result.authorizesAccept,false,"not an accept")
eq(result.realPlayerAcceptanceOrSettlementProven,false,"client only")
eq(result.publisherBytesAuthenticatedOnClient,false,"no signed proof")
eq(result.originalGameInstanceIdentityServerProven,false,"client item attributes not server proof")
eq(scanReads,2,"fresh scanner twice to defeat revision reset")
yes(result.hypotheticalAlternatives[1].tradeActionable==false,"research route never executable")
local encoded=serde.encode("json",result)
for _,private in ipairs({game.JobId,rawScope.leaseId,
 "SyntheticPartner",tostring(opponent.UserId),tostring(lp.UserId)}) do
 yes(string.find(encoded,private,1,true)==nil,"sensitive info not emitted")
end
scanReads=0
local noConsent,reason=protected.new(config({consentedToReadOnlyInventoryRpc=false}))
eq(noConsent,nil,"explicit consent absent")
eq(reason,"SUPREME_ONLY_PROTECTED_INPUT_OR_INVENTORY_CONSENT_MISSING",
 "read-only scanner RPC requires opt-in")
eq(scanReads,0,"no read when no consent")
local legacy,legacyWhy=protected.new(config({sourceBytes=legacySourceBytes}))
eq(legacy,nil,"genuine prior capture cannot substitute for current approved catalog")
eq(legacyWhy,"SUPREME_ONLY_SOURCE_SHA256_VERIFICATION_FAILED",
 "source integrity fails closed on old authentic but no longer pinned bytes")
eq(scanReads,0,"stale catalog rejected before any own-inventory scanner RPC")
clock=CAPTURE+21601
local expired,expiredWhy=protected.new(config())
eq(expired,nil,"expired source blocked before scanner RPC")
eq(expiredWhy,"SUPREME_ONLY_SOURCE_EXPIRED_OR_UNVERIFIED","no fallback for stale source")
eq(scanReads,0,"no scanner read when source expired")
clock=CLOCK
local injected=copy(catalog)
injected.rows[1].alternateMarketPrice=123456
local badSource,whyBadSource=protected.new(config({sourceBytes=serde.encode("json",injected)}))
eq(badSource,nil,"price injection into catalog blocked by byte digest")
eq(whyBadSource,"SUPREME_ONLY_SOURCE_SHA256_VERIFICATION_FAILED",
 "alternate row cannot be passed off as approved Supreme catalog")
local inflated=copy(catalog)
for _,r in ipairs(inflated.rows) do
 if r.rawGameKeyCandidate=="Harvester" then r.supremeListed=1000000 end
end
local forgedPrice,forgedWhy=protected.new(config({sourceBytes=serde.encode("json",inflated)}))
eq(forgedPrice,nil,"modified Supreme price blocked before scanner read")
eq(forgedWhy,"SUPREME_ONLY_SOURCE_SHA256_VERIFICATION_FAILED",
 "same logical source header cannot launder altered Supreme listed price")
local noId=new()
ownSlot.Attributes.ItemId=nil
eq(noId:preview({option}).status,"BLOCKED",
 "missing client GUI raw attribute must block, not infer name")
ownSlot.Attributes.ItemId="Harvester"
local wrongPartner=new()
name.Text="(AnotherUser)"
eq(wrongPartner:preview({option}).status,"BLOCKED",
 "partner GUI mismatch blocks")
name.Text="(SyntheticPartner)"
local wrongPlace=new()
game.PlaceId=999
eq(wrongPlace:preview({option}).status,"BLOCKED",
 "not in original MM2")
game.PlaceId=142823291
local wrongJob=new()
game.JobId="SYNTHETIC_DIFFERENT_JOB"
eq(wrongJob:preview({option}).status,"BLOCKED",
 "job change revokes")
game.JobId=rawScope.jobId
local wrongLease=new()
active=false
eq(wrongLease:preview({option}).status,"BLOCKED",
 "protected original lease change blocks")
active=true
scanReads=0
local race=new()
changeOwnOnSecond=true
eq(race:preview({option}).reason,
 "ORIGINAL_C3_OWN_CENSUS_CHANGED_DURING_STRATEGY",
 "second scanner census notices ownership change")
changeOwnOnSecond=false
scanReads=0
local missing=new()
extraEligible=true
eq(missing:preview({option}).reason,
 "ORIGINAL_SCANNER_ELIGIBLE_WEAPON_OMITTED",
 "raw fingerprint cannot drop newly eligible weapon")
extraEligible=false
sync.Weapons.UnknownHiddenWeapon=nil
local wrongRarity=new()
sync.Weapons.Harvester.Rarity="Godly"
eq(wrongRarity:preview({option}).status,"BLOCKED",
 "secret/ordinary rarity class confusion fails")
sync.Weapons.Harvester.Rarity="Ancient"
local wrongOffer=new()
eq(wrongOffer:preview({
 alt({item("Harvester")},{item("Gingerscope")})}).reason,
 "OPPONENT_ITEM_NOT_EXACTLY_PRESENT_IN_BOUND_GUI",
 "cannot invent opponent's Gingerscope to reach target")
local changedOwn=new()
local badGive=copy(option)
badGive.give[1].id="FlowerwoodKnife"
eq(changedOwn:preview({badGive}).reason,
 "OWN_ITEM_NOT_EXACTLY_PRESENT_IN_BOUND_GUI",
 "do not price a different outbound weapon than actual protected P4 GUI")
local changedQuantity=new()
local badQty=copy(option)
badQty.receive[1].quantity=1
eq(changedQuantity:preview({badQty}).reason,
 "OPPONENT_ITEM_NOT_EXACTLY_PRESENT_IN_BOUND_GUI",
 "never evaluate a partial or stale incoming quantity as current physical trade")
local noFallback=new()
local mixed=copy(option)
mixed.valueSource="MM2VALUES"
eq(noFallback:preview({mixed}).status,"BLOCKED","mixed source rejected")
local fifth=new()
local five=insert(theirSlots,5,"Gingerscope","Gingerscope","",false)
eq(fifth:preview({option}).status,"BLOCKED",
 "fifth physical offer slot blocked by original capture")
five.Visible=false
-- The capture adapter remains actual native P4 module; adversarial
-- wrappers deliberately mutate GUI/Accept after first completed frame.
local readCount=0
local base=p4
local altered={new=function(args)
 local actual,why=base.new(args)
 if not actual then return nil,why end
 return {capture=function()
  readCount+=1
  local r=actual.capture()
  if readCount==1 then amountTheir.Text="x3" end
  return r
 end},nil
end}
local raceOffer=new({captureAdapter=altered})
eq(raceOffer:preview({option}).reason,
 "ORIGINAL_P4_OFFER_ACCEPTANCE_OR_STACK_CHANGED",
 "changed opponent x2 to x3 after price preview blocked")
amountTheir.Text="x2"
local changedAccept={new=function(args)
 local actual=base.new(args)
 local calls=0
 return {capture=function()
  calls+=1
  local got=actual.capture()
  if calls==1 then theirAccepted.Visible=true end
  return got
 end},nil
end}
local acceptance=new({captureAdapter=changedAccept})
eq(acceptance:preview({option}).reason,
 "ORIGINAL_P4_OFFER_ACCEPTANCE_OR_STACK_CHANGED",
 "changed Accept state blocks")
theirAccepted.Visible=false
-- Nov25 exact archived source is accepted only in its own replay window.
local renewedBytes=fs.readFile(root.."supreme_only_189_research_catalog_2026_11_25_publication_nov23.json")
local renewedCatalog=serde.decode("json",renewedBytes)
local renewedPin="b6f5c1eec48d59b422f53baa4d83a54ce6837b72"
local renewedCapture=1795586999
local renewedDigest="3f0996b9ac20f3c4689519e1faf65e83796bce8b2d6afe6ad4d2e705ffca525e"
eq(shaValue(renewedBytes),renewedDigest,"renewed pure Luau SHA")
eq(serde.hash("sha256",renewedBytes),renewedDigest,"renewed independent SHA")
eq(supreme.sourceStatus(renewedCatalog,renewedPin,renewedCapture).status,
 "SUPREME_ONLY_RESEARCH_SOURCE_CHECKED","new edition source admitted")
eq(supreme.sourceStatus(renewedCatalog,SOURCE_PIN,renewedCapture).status,
 "BLOCKED","new edition cannot borrow old pin")
eq(supreme.sourceStatus(renewedCatalog,renewedPin,renewedCapture-1).status,
 "BLOCKED","future capture blocked")
eq(supreme.sourceStatus(renewedCatalog,renewedPin,renewedCapture+21600).status,
 "SUPREME_ONLY_RESEARCH_SOURCE_CHECKED","exact expiry boundary")
eq(supreme.sourceStatus(renewedCatalog,renewedPin,renewedCapture+21601).status,
 "BLOCKED","renewed source expiry")
clock=renewedCapture+30
local renewed=new({sourceBytes=renewedBytes})
local newReport=renewed:preview({option})
eq(newReport.status,"SUPREME_ONLY_PROTECTED_C3_P4_SHADOW_OBSERVED","new edition protected preview")
eq(newReport.hypotheticalAlternatives[1].supremeListedGain,160,"new edition exact values")
eq(newReport.sourceAgeSeconds,30,"correct archive clock")
eq(newReport.authorizesAccept,false,"renewal never enables accept")
local prior,priorWhy=protected.new(config())
eq(prior,nil,"historic source not valid at new clock")
eq(priorWhy,"SUPREME_ONLY_SOURCE_EXPIRED_OR_UNVERIFIED","no old source fallback")
local changed=copy(renewedCatalog)
changed.rows[1].supremeListed+=1
local tampered,tamperedWhy=protected.new(config({sourceBytes=serde.encode("json",changed)}))
eq(tampered,nil,"changed renewed source bytes rejected")
eq(tamperedWhy,"SUPREME_ONLY_SOURCE_SHA256_VERIFICATION_FAILED","new edition hash enforced")
clock=renewedCapture+21601
local expiredNew,expiredNewWhy=protected.new(config({sourceBytes=renewedBytes}))
eq(expiredNew,nil,"renewed expired source denied")
eq(expiredNewWhy,"SUPREME_ONLY_SOURCE_EXPIRED_OR_UNVERIFIED","renewed expiry before scanner")
clock=CLOCK
local frozenLua=fs.readFile(root.."native_supreme_only_protected_c3p4_adapter_nov17.lua")
for _,forbidden in ipairs({
 "native_market_inventory_offer_core","native_bilateral_attractiveness_shadow",
 "native_c9_growth_first_preview","mm2Listed","mm2Values","FireServer",
 "InvokeServer","PostAsync","TeleportService","AcceptTrade","DeclineTrade"}) do
 yes(not string.find(frozenLua,forbidden,1,true),
  "Supreme native integration avoids dual/active path: "..forbidden)
end
print("SUPREME_ONLY_PROTECTED_C3_P4_REAL_MODULE_MOCK_PASS assertions="..tostring(count))
