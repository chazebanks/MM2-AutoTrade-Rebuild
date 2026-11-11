-- Stage95 actual original Stage9 native GUI adapter + original contract tests.
-- Real original Stage83 189-entry PUBLIC registry, with NO trade action.
-- All module paths are SHA-verified and supplied by the CI workflow.
local function source(env)
 local p=os.getenv(env)
 assert(type(p)=="string" and #p>0,"pinned source missing: "..env)
 local fn=assert(loadfile(p))
 return fn()
end
local Stage95=source("STAGE95_MODULE")
local Stage9=source("STAGE95_ORIGINAL_CONTRACT")
local Native=source("STAGE95_ORIGINAL_NATIVE")
local Registry=source("STAGE95_ORIGINAL_REGISTRY")
local count=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL "..name.." "..tostring(err)) end
 count=count+1
 print("PASS "..name)
end
local function eq(a,b,why)
 assert(a==b,(why or "").." got="..tostring(a).." want="..tostring(b))
end
local function meta(key)
 local x=assert(Registry.entries[key],"missing historical key "..tostring(key))
 return {ItemName=x[1],ItemType=x[2],Rarity=x[3],Chroma=x[4]}
end
local catalog={
 Gingerscope=meta("Gingerscope"),
 Scythe=meta("Scythe"),
 ImmortalChroma=meta("ImmortalChroma"),
 BattleAxe2=meta("BattleAxe2"),
}
local function row(which,key,qty,chroma,label)
 local m=key and catalog[key]
 return {slot=which,rawId=key,label=label or (m and m.ItemName or "Gingerscope"),
  amountText=qty==nil and "" or qty,chroma=chroma==nil and (m and m.Chroma or false) or chroma}
end
local function capture(ours,theirs)
 return {tradeOpen=true,contextOK=true,session="one-test-job:alt",
  our={complete=true,accepted=false,slots=ours or {}},
  their={complete=true,accepted=false,slots=theirs or {}}}
end
local function inspect(raw,cat,reg)
 return Stage95.inspect(raw,cat or catalog,reg or Registry,Stage9.parseQuantity)
end
local function denied(v)
 for _,k in ipairs({"authorizesTrade","authorizesAccept","serverAttestation",
  "serverCompletionProven","numericSupremeCheckerIdVerified",
  "currentPricesVerified","priceForTradeVerified","marketValueAuthority",
  "currentOwnedRawKeyAuthenticated","rawOfferKeyBoundToPreprofile",
  "offerKeyOriginVerified","uniqueWeaponInstanceProven",
  "eventSessionAssociationProven","mayRecordCompletedTrade","mayReportProfit",
  "maySendDiscordWebhook","mayUseForStrategyLearning",
  "currentGameCatalogueAuthenticated"}) do
  eq(v[k],false,k)
 end
 eq(v.tradeOutcome,"UNKNOWN")
 eq(v.historicalPublicReferenceOnly,true)
end
test("Original 189 public source registry is present",function()
 local n=0
 for _ in pairs(Registry.entries) do n=n+1 end
 eq(n,189)
 eq(Registry.publisherExpiryUtc,"2026-11-09T15:56:07Z")
end)
test("GUI raw Gingerscope matches same client metadata plus reviewed public reference",function()
 local v=inspect(capture({}, {row(1,"Gingerscope","",false)}))
 eq(v.status,"CLIENT_GUI_PUBLIC_REFERENCE_CANDIDATES_ONLY")
 eq(v.clientRawKeyCandidateCount,1)
 eq(v.theirGuiCopyCount,1)
 eq(v.theirSlots[1].status,"GUI_RAW_TEXT_EQUALS_CURRENT_CLIENT_PUBLIC_REFERENCE_ONLY")
 denied(v)
end)
test("No GUI raw key never inherits Stage50 proof: only a display candidate",function()
 local x=row(1,nil,"x2",false,"Gingerscope")
 local v=inspect(capture({}, {x}))
 eq(v.nameOnlyUnboundCount,1)
 eq(v.clientRawKeyCandidateCount,0)
 eq(v.theirGuiCopyCount,2)
 eq(v.reason,"GUI_NAMES_WITHOUT_RAW_KEYS_NOT_IDENTITY")
 eq(v.status,"CLIENT_DISPLAY_ONLY_UNBOUND")
 denied(v)
end)
test("Actual Stage12 blank one and x2 quantity parsed by original Stage9",function()
 local v=inspect(capture({row(1,"Scythe","",false)}, {row(4,"Gingerscope","×2",false)}))
 eq(v.ourGuiCopyCount,1)
 eq(v.theirGuiCopyCount,2)
 eq(v.clientRawKeyCandidateCount,2)
 denied(v)
end)
test("Chroma Ancient/Godly variant keeps base rarity and Chroma item prefix",function()
 local v=inspect(capture({}, {row(1,"ImmortalChroma","x2",true)}))
 eq(v.clientRawKeyCandidateCount,1)
 eq(v.theirGuiCopyCount,2)
 denied(v)
end)
test("Chroma mismatch or full name confusion explicitly rejected",function()
 local x=row(1,"ImmortalChroma","",false,"Immortal")
 local v=inspect(capture({}, {x}))
 eq(v.rejectedSlotCount,1)
 eq(v.clientRawKeyCandidateCount,0)
 denied(v)
end)
test("Missing id with uniquely looking name still never becomes raw-key identity",function()
 local x=row(1,nil,"",false,"Batwing")
 local v=inspect(capture({}, {x}))
 eq(v.nameOnlyUnboundCount,1)
 eq(v.clientRawKeyCandidateCount,0)
 denied(v)
end)
test("A numeric GUI id never gets tostring coerced into source key by Stage95",function()
 local x=row(1,"Gingerscope","",false);x.rawId=123
 local v=inspect(capture({}, {x}))
 eq(v.rejectedSlotCount,1)
 eq(v.theirSlots[1].status,"RAW_GUI_ID_TYPE_OR_SHAPE_INVALID")
 denied(v)
end)
test("Invalid raw key, unknown catalogue, and mismatch refuse identity",function()
 for _,bad in ipairs({"Unknown","GingerscopeChroma","Immortal","0"}) do
  local x=row(1,"Gingerscope","",false)
  x.rawId=bad
  local v=inspect(capture({}, {x}))
  eq(v.rejectedSlotCount,1)
  eq(v.clientRawKeyCandidateCount,0)
  denied(v)
 end
 local changed={Gingerscope=meta("Gingerscope")}
 changed.Gingerscope.ItemType="Knife"
 local v=inspect(capture({}, {row(1,"Gingerscope","",false)}),changed)
 eq(v.rejectedSlotCount,1)
 denied(v)
end)
test("Bad quantity unknown, x0 and missing amount cannot become one",function()
 for _,q in ipairs({"x0","", "x-1","x1.5","x999999999999","x2 knives"}) do
  local x=row(1,"Gingerscope","",false)
  if q=="" then x.amountText=nil else x.amountText=q end
  local v=inspect(capture({}, {x}))
  eq(v.rejectedSlotCount,1)
  denied(v)
 end
end)
test("Duplicate or out-of-range physical slot is a hard incomplete capture",function()
 local x=capture({}, {row(1,"Gingerscope"),row(1,"Gingerscope")})
 local v=inspect(x)
 eq(v.status,"INCONCLUSIVE")
 eq(v.reason,"SLOT_DUPLICATED_OR_OUT_OF_RANGE")
 denied(v)
 x=capture({}, {row(5,"Gingerscope")})
 v=inspect(x)
 eq(v.status,"INCONCLUSIVE")
 denied(v)
end)
test("Acceptance, different partner and missing session cannot authorize candidate",function()
 for _,mutation in ipairs({"partner","accepted","session","closed"}) do
  local x=capture({}, {row(1,"Gingerscope")})
  if mutation=="partner" then x.contextOK=false end
  if mutation=="accepted" then x.their.accepted=true end
  if mutation=="session" then x.session="" end
  if mutation=="closed" then x.tradeOpen=false end
  local v=inspect(x)
  eq(v.status,"INCONCLUSIVE")
  denied(v)
 end
end)
test("Incomplete historical source or forged current-price field rejected",function()
 for _,mutation in ipairs({"expiredFlag","remove","page","num"}) do
  local r={}
  for k,v in pairs(Registry) do r[k]=v end
  if mutation=="expiredFlag" then r.currentPricesVerified=true end
  if mutation=="remove" then r.entries={} end
  if mutation=="page" then r.publisherExpiryUtc="2026-11-19T15:56:07Z" end
  if mutation=="num" then r.authorizesAccept=true end
  local v=inspect(capture({}, {row(1,"Gingerscope")}),catalog,r)
  eq(v.status,"INCONCLUSIVE")
  denied(v)
 end
end)
-- Fake Roblox UI objects to exercise *ACTUAL ORIGINAL* Stage9 M.capture
-- and the new proxy without changing the original module source.
local function node(class,name,parent)
 local n={ClassName=class,Name=name,Parent=parent,Visible=true,Enabled=true,
          children={},attrs={},Text=""}
 function n:IsA(k)
  return k==self.ClassName or (k=="GuiObject" and
    (self.ClassName=="Frame" or self.ClassName=="TextLabel" or
     self.ClassName=="TextButton"))
 end
 function n:FindFirstChild(nm,recursive)
  local c=self.children[nm]
  if c then return c end
  if recursive then
   for _,v in pairs(self.children) do
    local hit=v:FindFirstChild(nm,true)
    if hit then return hit end
   end
  end
  return nil
 end
 function n:GetAttribute(k)return self.attrs[k] end
 if parent then parent.children[name]=n end
 return n
end
local function originalScenario(mode)
 mode=mode or {}
 local players={}; local lp={UserId=1,Parent=players}
 local other={UserId=2,Name="consenting_alt",Parent=players}
 players.LocalPlayer=lp
 function players:GetPlayerByUserId(n)
  return n==2 and other or n==1 and lp or nil end
 local pg=node("PlayerGui","PlayerGui")
 function lp:FindFirstChildOfClass(k)
  return k=="PlayerGui" and pg or nil end
 local gui=node("ScreenGui","TradeGUI_Phone",pg)
 local container=node("Frame","Container",gui)
 local trade=node("Frame","Trade",container)
 local own=node("Frame","YourOffer",trade)
 local theirs=node("Frame","TheirOffer",trade)
 local username=node("TextLabel","Username",theirs)
 username.Text=mode.wrongPartner and "(wrong)" or "(consenting_alt)"
 local oc=node("Frame","Container",own)
 local tc=node("Frame","Container",theirs)
 for _,side in ipairs({own,theirs}) do
  local a=node("Frame","Accepted",side)
  a.Visible=false
 end
 local target=node("Frame","NewItem1",tc)
 if mode.physicalId then target.attrs.ItemId="Gingerscope" end
 local iname=node("Frame","ItemName",target)
 local label=node("TextLabel","Label",iname); label.Text="Gingerscope"
 local ic=node("Frame","Container",target)
 local amount=node("TextLabel","Amount",ic);amount.Text=mode.qty or ""
 local g={PlaceId=142823291,JobId=mode.job or "trusted-job"}
 local proxy=Stage95.wrapOriginalContract(Stage9,catalog,Registry)
 local h=Native.new({game=g,players=players,root=trade,
     session="test-trade",
     jobId="trusted-job",partnerUserId=2,localUserId=1,
     contract=proxy,ownInventory=nil,opponentInventory=nil,
     marketFresh=function()return false end})
 local result,diag=Native.capture(h)
 return result,diag,h,g,label,other
end
test("Actual original Stage9 native adapter + proxy: name-only GUI stays unbound",function()
 local x,d=originalScenario()
 eq(x.tradeOpen,true)
 eq(x.quoteSafe,false)
 assert(d.stage95,"Stage95 proxy not called by original GUI adapter")
 eq(d.stage95.status,"CLIENT_DISPLAY_ONLY_UNBOUND")
 eq(d.stage95.nameOnlyUnboundCount,1)
 eq(d.stage95.clientRawKeyCandidateCount,0)
 denied(d.stage95)
end)
test("Actual original Stage9 native GetAttribute exact key becomes CLIENT candidate only",function()
 local x,d=originalScenario({physicalId=true,qty="x2"})
 eq(x.quoteSafe,false)
 eq(d.stage95.clientRawKeyCandidateCount,1)
 eq(d.stage95.theirGuiCopyCount,2)
 eq(d.stage95.priceForTradeVerified,false)
 denied(d.stage95)
end)
test("Partial valid plus invalid slot always makes whole preview inconclusive",function()
 local x=capture({}, {row(1,"Gingerscope","",false),row(2,"Gingerscope","x2",false)})
 x.their.slots[2].rawId="nonexistent"
 local v=inspect(x)
 eq(v.clientRawKeyCandidateCount,1)
 eq(v.rejectedSlotCount,1)
 eq(v.status,"INCONCLUSIVE")
 eq(v.reason,"AT_LEAST_ONE_PHYSICAL_SLOT_IDENTITY_REJECTED")
 denied(v)
end)
test("Native Stage9 wrong GUI partner cannot yield source-bound candidate",function()
 local x,d=originalScenario({wrongPartner=true,physicalId=true})
 eq(x.quoteSafe,false)
 eq(d.stage95.status,"INCONCLUSIVE")
 eq(d.stage95.exactCurrentPlayerBound,false)
 denied(d.stage95)
end)
test("Native Stage9 job change closes observer and proxy keeps all permissions false",function()
 local x,d,h,g=originalScenario({physicalId=true})
 g.JobId="other-job"
 local y,z=Native.capture(h)
 eq(y.tradeOpen,false)
 eq(z.stage95.status,"INCONCLUSIVE")
 denied(z.stage95)
end)
test("400 deterministic mutations never produce identity or trade authority",function()
 local valid=capture({}, {row(1,"Gingerscope")})
 for i=1,400 do
  local x=capture({}, {row(1,"Gingerscope")})
  local m=i%10
  if m==0 then x.their.slots[1].rawId=tostring(i) end
  if m==1 then x.their.slots[1].rawId=nil end
  if m==2 then x.their.slots[1].label="Chroma Gingerscope" end
  if m==3 then x.their.slots[1].chroma=true end
  if m==4 then x.their.slots[1].amountText="x0" end
  if m==5 then x.their.slots[1].slot=5 end
  if m==6 then x.contextOK=false end
  if m==7 then x.our.accepted=true end
  if m==8 then x.their.slots[1].amountText="x2" end
  if m==9 then x.their.slots[1].rawId=0 end
  local v=inspect(x)
  denied(v)
  assert(v.currentPricesVerified==false and v.authorizesAccept==false)
  if m~=8 then eq(v.clientRawKeyCandidateCount,0,i) end
 end
end)
print("STAGE95_ACTUAL_STAGE9_AND_STAGE83_PASS groups="..count.." negativeCases=400")
