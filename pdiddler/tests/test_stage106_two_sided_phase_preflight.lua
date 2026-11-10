-- Stage106 pure two-sided phase verification, exercising real Stage9
-- quantity parser, original Stage83 catalog and stack-fixed Stage101 matcher.
-- Neither client consistency nor tests prove server transaction causality.
local Preflight=assert(loadfile("pdiddler/intelligence_lab/stage106_two_sided_phase_preflight.lua"))()
local Matcher=assert(loadfile(assert(os.getenv("STAGE106_ORIGINAL_STAGE101"))))()
local Stage9=assert(loadfile(assert(os.getenv("STAGE106_ORIGINAL_STAGE9"))))()
local Registry=assert(loadfile(assert(os.getenv("STAGE106_ORIGINAL_STAGE83"))))()
local total=0
local function eq(a,b,msg)
 assert(a==b,(msg or "mismatch").." got="..tostring(a).." expected="..tostring(b))
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("STAGE106 FAIL "..name..": "..tostring(err)) end
 total=total+1;print("PASS Stage106 "..name)
end
local function meta(key)
 local v=assert(Registry.entries[key],"registry key "..key)
 return {ItemName=v[1],ItemType=v[2],Rarity=v[3],Chroma=v[4]}
end
local Catalog={Scythe=meta("Scythe"),Gingerscope=meta("Gingerscope"),
 ImmortalChroma=meta("ImmortalChroma")}
local function slot(i,label,quantity,chroma)
 return {slot=i,label=label,amountText=quantity==1 and "" or
   "x"..tostring(quantity),chroma=chroma==true}
end
local function side(slots)
 local rows={}
 for i,v in ipairs(slots) do
  rows[i]={slot=v.slot,label=v.label,amountText=v.amountText,
   chroma=v.chroma,rawId=v.rawId}
 end
 return {complete=true,accepted=false,slots=rows}
end
local function frame(s,at,ours,theirs)
 return {session=s.session,jobId=s.jobId,root=s.root,
  localPlayer=s.localPlayer,partnerPlayer=s.partnerPlayer,at=at,
  raw={tradeOpen=true,contextOK=true,session=s.session,
    our=side(ours),their=side(theirs)}}
end
local function fixture(swapped,quantity)
 local scope={root={},localPlayer={},partnerPlayer={},
   session="private_stage106",jobId="private_job"}
 local own={slot(1,"Batwing",quantity or 1,false)}
 local alt={slot(1,"Gingerscope",1,false)}
 local row1={Player=scope.localPlayer,Accepted=false,
  Offer={{"Scythe",quantity or 1,"Weapons"}}}
 local row2={Player=scope.partnerPlayer,Accepted=false,
  Offer={{"Gingerscope",1,"Weapons"}}}
 if swapped then row1,row2=row2,row1 end
 return {
  scope=scope,empty1=frame(scope,100,{},{}),
  empty2=frame(scope,100.2,{},{}),
  alt1=frame(scope,100.4,{},alt),
  alt2=frame(scope,100.6,{},alt),
  listenerArmedAt=100.65,eventCount=1,
  receipt={at=100.8,session=scope.session,jobId=scope.jobId,
    root=scope.root,localPlayer=scope.localPlayer,
    partnerPlayer=scope.partnerPlayer,
    packed={n=1,[1]={LastOffer=12,Locked=false,Player1=row1,Player2=row2}}},
  after1=frame(scope,100.9,own,alt),
  after2=frame(scope,101.12,own,alt)
 }
end
local function inspect(x)
 return Preflight.inspect(x,Catalog,Registry,Stage9,Matcher)
end
local function denied(r)
 eq(r.readOnly,true);eq(r.clientOnly,true)
 eq(r.eventSessionAssociationProven,false)
 eq(r.callbackCausalityProven,false)
 eq(r.authorizesTrade,false);eq(r.authorizesAccept,false)
 eq(r.serverCompletionProven,false);eq(r.rawItemIdConfirmed,false)
 eq(r.currentPricesVerified,false);eq(r.priceForTradeVerified,false)
 eq(r.mayReportProfit,false);eq(r.maySendDiscordWebhook,false)
 eq(r.tradeOutcome,"UNKNOWN")
 for _,v in pairs(r) do
  if type(v)=="string" then
   for _,private in ipairs({"Batwing","Scythe","Gingerscope",
      "private_stage106","private_job"}) do
    assert(not v:find(private,1,true),"private raw key in report")
   end
  end
 end
end
test("ALT-only two stable frames then exactly one MAIN callback creates client-only match",function()
 local r=inspect(fixture())
 eq(r.status,"CLIENT_TWO_SIDED_RAW_KEY_GUI_CANDIDATES_UNATTRIBUTED",r.reason)
 eq(r.ourMatchedSlotCount,1);eq(r.theirMatchedSlotCount,1)
 eq(r.phaseSequenceObserved,true);denied(r)
end)
test("swapped actor Player1 and Player2 orientation remains client-only",function()
 local r=inspect(fixture(true))
 eq(r.status,"CLIENT_TWO_SIDED_RAW_KEY_GUI_CANDIDATES_UNATTRIBUTED",r.reason)
 denied(r)
end)
test("single physical MAIN x5 stack is NOT five trade slots",function()
 local r=inspect(fixture(false,5))
 eq(r.status,"CLIENT_TWO_SIDED_RAW_KEY_GUI_CANDIDATES_UNATTRIBUTED",r.reason)
 denied(r)
end)
test("ALT only callback arriving after listener cannot masquerade as MAIN add",function()
 local x=fixture()
 x.receipt.packed[1].Player1.Offer={}
 local r=inspect(x)
 eq(r.status,"INCONCLUSIVE");eq(r.reason,"CLIENT_RAW_KEY_GUI_CANDIDATE_NOT_PROVEN");denied(r)
end)
test("stage106 refuses protected outgoing Gingerscope even if event matches",function()
 local x=fixture()
 x.after1.raw.our.slots={slot(1,"Gingerscope",1,false)}
 x.after2.raw.our.slots={slot(1,"Gingerscope",1,false)}
 x.receipt.packed[1].Player1.Offer={{"Gingerscope",1,"Weapons"}}
 local r=inspect(x)
 eq(r.status,"INCONCLUSIVE")
 eq(r.reason,"PROTECTED_GINGERSCOPE_IN_OUR_OFFER");denied(r)
end)
test("listener must be armed after ALT two-frame baseline",function()
 local x=fixture()
 x.listenerArmedAt=x.alt1.at
 local r=inspect(x)
 eq(r.reason,"LISTENER_PHASE_OR_SINGLE_CALLBACK_NOT_VERIFIED");denied(r)
end)
test("duplicate or absent UpdateTrade callbacks fail closed",function()
 for _,n in ipairs({0,2,3}) do
  local x=fixture();x.eventCount=n
  local r=inspect(x)
  eq(r.reason,"LISTENER_PHASE_OR_SINGLE_CALLBACK_NOT_VERIFIED");denied(r)
 end
end)
test("changed ALT slot across MAIN add cannot pass even when event appears valid",function()
 local x=fixture()
 x.after1.raw.their.slots={slot(1,"Batwing",1,false)}
 x.after2.raw.their.slots={slot(1,"Batwing",1,false)}
 local r=inspect(x)
 eq(r.reason,"MAIN_ONLY_CHANGE_OR_ALT_ITEM_UNVERIFIED");denied(r)
end)
test("ALT baseline mutation and missing empty trade fail closed",function()
 local x=fixture()
 x.alt1.raw.their.slots={slot(1,"Batwing",1,false)}
 eq(inspect(x).reason,"ALT_ONLY_CLIENT_BASELINE_NOT_STABLE")
 x=fixture();x.empty2.raw.their.slots={slot(1,"Batwing",1,false)}
 eq(inspect(x).reason,"INITIAL_CLIENT_OFFERS_NOT_EMPTY")
end)
test("partner, job, root and acceptance cannot change across frames",function()
 for _,kind in ipairs({"job","partner","root","accept","closed","ambiguous"}) do
  local x=fixture()
  if kind=="job" then x.after2.jobId="other" end
  if kind=="partner" then x.alt2.partnerPlayer={} end
  if kind=="root" then x.after1.root={} end
  if kind=="accept" then x.after2.raw.our.accepted=true end
  if kind=="closed" then x.after1.raw.tradeOpen=false end
  if kind=="ambiguous" then x.after1.raw.their.slots[2]=slot(2,"Batwing",1,false) end
  local r=inspect(x)
  eq(r.status,"INCONCLUSIVE");denied(r)
 end
end)
test("late/missing callback and unstable GUI final sample refuse",function()
 local x=fixture();x.receipt.at=103.8
 eq(inspect(x).status,"INCONCLUSIVE")
 x=fixture();x.after2.at=x.after1.at+0.02
 eq(inspect(x).reason,"TWO_SIDED_CLIENT_PHASE_CLOCK_INVALID")
 x=fixture();x.after2.raw.our.slots[1].amountText="x2"
 eq(inspect(x).reason,"MAIN_ONLY_CHANGE_OR_ALT_ITEM_UNVERIFIED")
end)
test("stage106 360 adverse cases cannot elevate any final authority",function()
 for i=1,360 do
  local x=fixture(i%2==0,1+i%7)
  local j=i%15
  if j==0 then x.receipt.at=100.4 end
  if j==1 then x.eventCount=2 end
  if j==2 then x.listenerArmedAt=100.35 end
  if j==3 then x.after2.raw.our.accepted=true end
  if j==4 then x.after1.raw.their.accepted=true end
  if j==5 then x.after1.raw.their.slots[1].chroma=true end
  if j==6 then x.receipt.packed[1].Locked=true end
  if j==7 then x.alt2.raw.our.slots={slot(1,"Batwing",1)} end
  if j==8 then x.alt1.raw.their.slots={} end
  if j==9 then x.empty1.raw.our.slots={slot(1,"Batwing",1)} end
  if j==10 then x.after2.jobId="other" end
  if j==11 then x.receipt.packed[1].Player1.Accepted=true end
  if j==12 then x.after1.raw.our.slots[1].amountText="x0" end
  if j==13 then x.after2.raw.our.slots[1].label="Gingerscope" end
  if j==14 then x.receipt.packed[1].Player2.Offer={} end
  local r=inspect(x);denied(r)
  eq(r.status,"INCONCLUSIVE","mutant "..i)
 end
end)
print("STAGE106_PHASE_PREFLIGHT_REAL_ORIGINAL_SOURCE_PASS groups="..total.." mutations=360")
