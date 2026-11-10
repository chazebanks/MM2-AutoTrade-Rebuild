-- Stage96 ACTUAL Lua5.4 tests reusing Stage9 parser, Stage42+44 orientation,
-- Stage83 historical public registry and Stage95 physical-slot boundary.
-- No native Roblox/client actions or request/Accept/offer code.
local function pinned(k)
 local path=os.getenv(k)
 assert(type(path)=="string" and #path>0,"Missing pinned "..k)
 return assert(loadfile(path))()
end
local M=pinned("STAGE96_MODULE")
local Stage9=pinned("STAGE96_ORIGINAL_STAGE9")
local Stage42=pinned("STAGE96_ORIGINAL_STAGE42")
local Stage43=pinned("STAGE96_ORIGINAL_STAGE43")
local Stage44=pinned("STAGE96_ORIGINAL_STAGE44")
local Stage83=pinned("STAGE96_ORIGINAL_STAGE83")
local Stage95=pinned("STAGE96_STAGE95")
local groups=0
local function check(name,fn)
 local ok,errorText=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(errorText)) end
 groups=groups+1
 print("PASS Stage96 "..name)
end
local function eq(actual,expected,msg)
 if actual~=expected then
  error((msg or "mismatch")..": got "..tostring(actual).." expected "..tostring(expected))
 end
end
local function assertNoAuth(r)
 local deny={"eventSessionAssociationProven","callbackCausalityProven","ownerSideSlotBound",
 "rawItemIdConfirmed","uniqueWeaponInstanceProven","authenticatedOwnedInventory",
 "currentGameCatalogueAuthenticated","sourcePublisherFresh","currentPricesVerified",
 "priceForTradeVerified","numericSupremeCheckerIdVerified","serverAttestation",
 "serverCompletionProven","authorizesTrade","authorizesAccept",
 "mayRecordCompletedTrade","mayReportProfit","maySendDiscordWebhook",
 "mayUseForStrategyLearning"}
 for _,key in ipairs(deny) do eq(r[key],false,key) end
 eq(r.tradeOutcome,"UNKNOWN")
 eq(r.clientOnly,true)
 eq(r.readOnly,true)
 for k,v in pairs(r) do
  assert(not tostring(k):match("rawKey") or k=="proposedRawKeyIsPrivate","key privacy")
  if type(v)=="string" then
   assert(not v:find("Scythe",1,true) and
          not v:find("Gingerscope",1,true) and
          not v:find("Batwing",1,true),"raw private item escaped")
  end
 end
end
local function meta(raw)
 local row=assert(Stage83.entries[raw],"missing archived raw key "..raw)
 return {ItemName=row[1],ItemType=row[2],Rarity=row[3],Chroma=row[4]}
end
local cats={Scythe=meta("Scythe"),Gingerscope=meta("Gingerscope"),
            ImmortalChroma=meta("ImmortalChroma"),BattleAxe2=meta("BattleAxe2")}
local function blankSide(slots)
 return {complete=true,accepted=false,slots=slots or {}}
end
local function physicalSlot(raw,qt,display,chroma)
 local m=raw and cats[raw]
 return {slot=1,rawId=nil,label=display or (m and m.ItemName or "Batwing"),
  chroma=chroma==nil and (m and m.Chroma or false) or chroma,
  amountText=qt or ""}
end
local function pack(root)
 return {n=1,[1]=root}
end
local function fixture(opts)
 opts=opts or {}
 local me={Name="MAIN"}; local them={Name="ALT"}
 local root={}
 local scope={session="s96:new",jobId="JOB_A",root=root,
              localPlayer=me,partnerPlayer=them}
 local key=opts.key or "Scythe"
 local qt=opts.quantity or 1
 local physical=physicalSlot(key,qt==1 and "" or "x"..qt,opts.label,opts.chroma)
 if opts.rawGui then physical.rawId=key end
 local p1={Player=me,Accepted=false,Offer={}}
 local p2={Player=them,Accepted=false,Offer={{key,qt,"Weapons"}}}
 if opts.localSecond then
  p1,p2={Player=them,Accepted=false,Offer={{key,qt,"Weapons"}}},
         {Player=me,Accepted=false,Offer={}}
 end
 local eventRoot={LastOffer=2,Locked=false,Player1=p1,Player2=p2}
 local before={tradeOpen=true,contextOK=true,session=scope.session,
   our=blankSide(),their=blankSide()}
 local after1={tradeOpen=true,contextOK=true,session=scope.session,
   our=blankSide(),their=blankSide({physical})}
 local second={slot=physical.slot,rawId=physical.rawId,label=physical.label,
  chroma=physical.chroma,amountText=physical.amountText}
 local after2={tradeOpen=true,contextOK=true,session=scope.session,
   our=blankSide(),their=blankSide({second})}
 local function record(raw,at)
  return {raw=raw,at=at,session=scope.session,jobId=scope.jobId,
   root=root,localPlayer=me,partnerPlayer=them}
 end
 local f={scope=scope,before=record(before,100),
     receipt={packed=pack(eventRoot),at=100.2,session=scope.session,jobId=scope.jobId,
       root=root,localPlayer=me,partnerPlayer=them},
     after1=record(after1,100.3),after2=record(after2,100.5),
     eventCount=1}
 return f,me,them
end
local function run(f,cat,reg)
 return M.inspect(f,cat or cats,reg or Stage83,Stage9,Stage95)
end
check("one partner Batwing raw Scythe event maps displayed Batwing by name/quantity only",function()
 local f=fixture()
 local r=run(f)
 eq(r.status,"CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED")
 eq(r.clientGuiNameOnlyUnbound,true)
 eq(r.sameClientPlayerReferencesMatched,true)
 eq(r.oneVisiblePartnerGuiSlotMatched,true)
 eq(r.guiStableTwoSamples,true)
 eq(r.clientEventRawTextMatchesGuiRawText,false)
 eq(r.eventSessionAssociationProven,false)
 assertNoAuth(r)
end)
check("physical raw GUI attribute equal to event key remains client-only",function()
 local f=fixture({rawGui=true})
 local r=run(f)
 eq(r.status,"CLIENT_PARTNER_EVENT_GUI_RAW_TEXT_CONSISTENT_UNATTRIBUTED")
 eq(r.clientEventRawTextMatchesGuiRawText,true)
 eq(r.clientGuiNameOnlyUnbound,false)
 assertNoAuth(r)
end)
check("original Stage42 actor orientation passes either player ordering",function()
 for _,second in ipairs({false,true}) do
  local f,me,them=fixture({localSecond=second})
  local result=Stage42.inspect(f.receipt.packed,me,them)
  eq(result.status,"CLIENT_REFERENCE_ORIENTATION_OBSERVED")
  eq(result.orientation,second and "LOCAL_SECOND" or "LOCAL_FIRST")
  local r=run(f)
  eq(r.status,"CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED")
  assertNoAuth(r)
 end
end)
check("Stage43 original own Batwing tuple must reject partner-side event",function()
 local f,me,them=fixture()
 local old=Stage43.inspect(f.receipt.packed,"Scythe",me,them)
 eq(old.status,"HYPOTHESIS_REJECTED")
 eq(old.firstFailedStage,"OFFER_LIST_MISMATCH")
 local newer=run(f)
 eq(newer.partnerEventTupleObserved,true)
 assertNoAuth(newer)
end)
check("Stage44 original OWN-only inspector must reject new partner-side positive",function()
 local f,me,them=fixture()
 local old=Stage44.inspect(f.receipt.packed,"Scythe",me,them)
 eq(old.status,"HYPOTHESIS_REJECTED")
 eq(old.firstFailedStage,"PARTNER_OFFER_NOT_EMPTY")
 local r=run(f)
 eq(r.partnerEventTupleObserved,true)
 assertNoAuth(r)
end)
check("true Chroma Godly stack x2 matches only same base rarity and chroma",function()
 local f=fixture({key="ImmortalChroma",quantity=2})
 local r=run(f)
 eq(r.status,"CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED")
 eq(r.clientQuantityCompared,true)
 assertNoAuth(r)
end)
check("public game key versus display name mismatch from Stage50 is not guessed",function()
 local f=fixture()
 eq(Stage83.entries["Scythe"][1],"Batwing")
 eq(Stage83.entries["Batwing"],nil)
 local r=run(f)
 eq(r.oneVisiblePartnerGuiSlotMatched,true)
 eq(r.rawItemIdConfirmed,false)
 assertNoAuth(r)
end)
check("late, early, duplicate, reversed, replay-like client windows refused",function()
 local edits={
  function(f)f.receipt.at=99.9 end,
  function(f)f.receipt.at=100.9 end,
  function(f)f.after1.at=103.9 end,
  function(f)f.after2.at=100.32 end,
  function(f)f.after2.at=105 end,
  function(f)f.eventCount=2 end,
  function(f)f.eventCount=0 end,
  function(f)f.before.at=100.3 end,
 }
 for i,fn in ipairs(edits) do
  local f=fixture();fn(f)
  local r=run(f)
  eq(r.status,"INCONCLUSIVE","timing/duplicate case "..i)
  eq(r.oneVisiblePartnerGuiSlotMatched,false)
  assertNoAuth(r)
 end
end)
check("wrong player reference / ambiguous player orientation refused",function()
 local edits={
  function(f) f.receipt.packed[1].Player2.Player={Name="IMPOSTER"} end,
  function(f) f.receipt.packed[1].Player1.Player=f.scope.partnerPlayer end,
  function(f) f.receipt.packed[1].Player2.Player=f.scope.localPlayer end,
  function(f) f.receipt.packed[1].Player1.Accepted=true end,
  function(f) f.receipt.packed[1].Player2.Accepted=true end,
 }
 for i,fn in ipairs(edits) do
  local f=fixture();fn(f)
  local r=run(f)
  eq(r.status,"INCONCLUSIVE","player case "..i)
  assertNoAuth(r)
 end
end)
check("changed root, partner, session, job, acceptance and offer-side fail",function()
 local edits={
  function(f)f.after2.root={} end,
  function(f)f.after2.partnerPlayer={} end,
  function(f)f.receipt.root={} end,
  function(f)f.receipt.session="old" end,
  function(f)f.before.jobId="stale" end,
  function(f)f.after2.raw.contextOK=false end,
  function(f)f.after1.raw.their.accepted=true end,
  function(f)f.after2.raw.our.slots={physicalSlot("Gingerscope")} end,
  function(f)f.before.raw.their.slots={physicalSlot("Gingerscope")} end,
 }
 for i,fn in ipairs(edits) do
  local f=fixture();fn(f)
  local r=run(f)
  eq(r.status,"INCONCLUSIVE","scope case "..i)
  assertNoAuth(r)
 end
end)
check("invalid player-relative UpdateTrade root/pack/rows/locks denied",function()
 local edits={
  function(f)f.receipt.packed.n=2 end,
  function(f)f.receipt.packed[2]=true end,
  function(f)f.receipt.packed[1].Extra=true end,
  function(f)f.receipt.packed[1].LastOffer=0/0 end,
  function(f)f.receipt.packed[1].Locked=true end,
  function(f)f.receipt.packed[1].Player2.Offer={{"Scythe",1,"Weapons"},{"Scythe",1,"Weapons"}} end,
  function(f)f.receipt.packed[1].Player2.Offer={{"Scythe",1,"Weapons","noise"}} end,
  function(f)f.receipt.packed[1].Player1.Offer={{"Gingerscope",1,"Weapons"}} end,
  function(f)f.receipt.packed[1].Player2.Offer={{"Scythe",0,"Weapons"}} end,
  function(f)f.receipt.packed[1].Player2.Offer={{"Scythe",5,"Weapons"}} end,
  function(f)f.receipt.packed[1].Player2.Offer={{"Scythe",1,"Pets"}} end,
  function(f)f.receipt.packed[1].Player2.Offer={{123,1,"Weapons"}} end,
  function(f)f.receipt.packed[1].Player2.Offer={{"Batwing",1,"Weapons"}} end,
 }
 for i,fn in ipairs(edits) do
  local f=fixture();fn(f)
  local r=run(f)
  eq(r.status,"INCONCLUSIVE","event case "..i)
  assertNoAuth(r)
 end
end)
check("physical offer label, quantity, chroma, GUI raw text disagreement rejected",function()
 local edits={
  function(f)f.after1.raw.their.slots[1].label="wrong" end,
  function(f)f.after1.raw.their.slots[1].amountText="x2" end,
  function(f)f.after1.raw.their.slots[1].chroma=true end,
  function(f)f.after2.raw.their.slots[1].label="wrong" end,
  function(f)f.after1.raw.their.slots[1].rawId="Gingerscope"
     f.after2.raw.their.slots[1].rawId="Gingerscope" end,
  function(f)f.after1.raw.their.slots[1].slot=5
     f.after2.raw.their.slots[1].slot=5 end,
  function(f)f.after1.raw.their.slots[1].amountText=nil
     f.after2.raw.their.slots[1].amountText=nil end,
 }
 for i,fn in ipairs(edits) do
  local f=fixture();fn(f)
  local r=run(f)
  eq(r.status,"INCONCLUSIVE","physical case "..i)
  assertNoAuth(r)
 end
end)
check("public source catalogue mutation / wrong variant cannot inherit Stage95",function()
 local cases={
  function(cat) cat.Scythe.ItemName="Some Other Weapon" end,
  function(cat) cat.Scythe.Chroma=true end,
  function(cat) cat.Scythe.ItemType="Gun" end,
  function(cat) cat.Scythe.Rarity="Godly" end,
 }
 for i,fn in ipairs(cases) do
  local c={Scythe=meta("Scythe"),Gingerscope=meta("Gingerscope"),
           ImmortalChroma=meta("ImmortalChroma"),BattleAxe2=meta("BattleAxe2")}
  fn(c)
  local r=run(fixture(),c)
  eq(r.status,"INCONCLUSIVE","metadata case "..i)
  assertNoAuth(r)
 end
 local forged={}
 for k,v in pairs(Stage83) do forged[k]=v end
 forged.currentPricesVerified=true
 local r=run(fixture(),cats,forged)
 eq(r.status,"INCONCLUSIVE")
 assertNoAuth(r)
end)
check("500 deterministic adversarial input changes never claim authorization",function()
 for i=1,500 do
  local f=fixture({rawGui=(i%7==0),localSecond=(i%5==0)})
  local m=i%12
  if m==0 then f.receipt.at=99 end
  if m==1 then f.receipt.packed[1].Player2.Offer={{"Scythe",3,"Weapons"}} end
  if m==2 then f.after2.raw.their.slots[1].rawId="wrong" end
  if m==3 then f.after1.raw.their.slots[1].label="mismatch" end
  if m==4 then f.after2.jobId="different" end
  if m==5 then f.eventCount=2 end
  if m==6 then f.after2.raw.their.slots[1].chroma=true end
  if m==7 then f.after2.raw.our.accepted=true end
  if m==8 then f.after1.raw.their.slots[1].amountText="x4" end
  if m==9 then f.receipt.packed[1].Player1.Player={} end
  if m==10 then f.receipt.packed[1].Locked=true end
  if m==11 then f.before.raw.their.slots={physicalSlot("Scythe")} end
  local r=run(f)
  assertNoAuth(r)
  eq(r.status,"INCONCLUSIVE","mutant "..i)
 end
end)
print("STAGE96_ACTUAL_ORIGINAL_SOURCE_TESTS_PASS groups="..groups.." mutants=500")
