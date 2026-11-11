-- Actual frozen Stage101 + original Stage9 parser + 189-entry Stage83 registry.
-- All inputs are synthetic; no live Roblox action is called.
local Witness=assert(loadfile(assert(os.getenv("STAGE117_WITNESS"))))()
local Stage101=assert(loadfile(assert(os.getenv("STAGE117_STAGE101"))))()
local Stage9=assert(loadfile(assert(os.getenv("STAGE117_STAGE9"))))()
local Registry=assert(loadfile(assert(os.getenv("STAGE117_STAGE83"))))()
local tests=0
local function eq(a,b,msg)
 tests=tests+1
 assert(a==b,tostring(msg)..": "..tostring(a).." != "..tostring(b))
end
local function denied(r)
 eq(type(r),"table","receipt table")
 for _,k in ipairs({
  "currentPricesVerified","marketValueAuthority",
  "eventSessionAssociationProven","callbackCausalityProven",
  "serverTradeRevisionProven","rawItemIdConfirmed",
  "uniqueWeaponInstanceProven","authenticatedOwnedInventory",
  "serverCompletionProven","authorizesTrade","authorizesOffer",
  "authorizesAccept","mayRecordCompletedTrade","mayReportProfit",
  "maySendDiscordWebhook","mayUseForStrategyLearning"
 }) do
  eq(r[k],false,"no authority: "..k)
 end
 eq(r.tradeOutcome,"UNKNOWN","no server completion claim")
 for k,v in pairs(r) do
  if type(v)=="string" then
   for _,secret in ipairs({"Scythe","ImmortalChroma","Batwing",
     "SECRET_JOB","Gingerscope","secretAlt"}) do
    eq(v:find(secret,1,true),nil,"private data excluded "..k)
   end
  end
 end
end
local function meta(key)
 local r=assert(Registry.entries[key],"archived catalog "..key)
 return {ItemName=r[1],ItemType=r[2],Rarity=r[3],Chroma=r[4]}
end
local catalog={
 Scythe=meta("Scythe"),
 ImmortalChroma=meta("ImmortalChroma"),
 Gingerscope=meta("Gingerscope")
}
local function slot(i,name,amount,chroma,raw)
 return {slot=i,label=name,amountText=amount,chroma=chroma,rawId=raw}
end
local function raw(our,their)
 return {
  tradeOpen=true,contextOK=true,session="S98",
  our={complete=true,accepted=false,slots=our},
  their={complete=true,accepted=false,slots=their}
 }
end
local function candidate(i,name,q,chroma)
 return {
  physicalSlot=i,quantity=q,displayCandidate=name,
  chromaCandidate=chroma,rawItemIdAuthenticated=false
 }
end
local function fixture(opt)
 opt=opt or {}
 local state={time=100,live=true,root={},main={Name="MAIN"},
  alt={Name="secretAlt"},job="SECRET_JOB",session="S98",
  allowBound=true,metadataStatus="P3_BOUND_CANDIDATE_READ_ONLY",
  ownAccepted=false,theirAccepted=false}
 state.raw=raw({}, {slot(1,"Immortal","x2",true)})
 state.scope={jobId=state.job,session=state.session,root=state.root,
   localPlayer=state.main,partnerPlayer=state.alt}
 local deps={
  getScope=function()
   return {jobId=state.job,session=state.session,root=state.root,
    localPlayer=state.main,partnerPlayer=state.alt}
  end,
  now=function()return state.time end,
  isLive=function()return state.live end,
  getBound=function()
   if not state.allowBound then return nil,{status="BLOCKED"}end
   local bound={capture=function()
    local function side(rows)
     local s={}
     for _,v in ipairs(rows.slots) do
      local qty=Stage9.parseQuantity(v.amountText)
      s[#s+1]=candidate(v.slot,v.label,qty,v.chroma)
     end
     return s
    end
    return {status="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT",
      partnerExactClientBound=true,part3Paused=true,
      part4TradeVisible=true,authorizesOffer=false,
      authorizesAccept=false,rawItemIdsAuthenticated=false,
      serverCompletionProven=false,tradeOutcome="UNKNOWN",
      ours=state.ownOverride or side(state.raw.our),
      theirs=state.theirOverride or side(state.raw.their)}
   end}
   return bound,{status=state.metadataStatus,authorizesOffer=false,
     authorizesAccept=false}
  end,
  captureStage9Raw=function()return state.raw end,
  stage101=Stage101,stage9=Stage9,catalogue=catalog,registry=Registry
 }
 local witness,initial=Witness.new(state.scope,deps)
 local payload={
  LastOffer=12,Locked=false,
  Player1={Player=state.main,Accepted=false,
    Offer={{"Scythe",1,"Weapons"}}},
  Player2={Player=state.alt,Accepted=false,
    Offer={{"ImmortalChroma",2,"Weapons"}}}
 }
 if opt.swapped then payload.Player1,payload.Player2=payload.Player2,payload.Player1 end
 local packet={n=1,[1]=payload}
 local function after()
  state.raw=raw({slot(1,"Batwing","",false)},
    {slot(1,"Immortal","x2",true)})
 end
 return state,witness,packet,after,initial
end
local function proof(opt)
 local s,w,p,after=fixture(opt)
 eq(w.begin().status,"WAITING","live original P3/P4 ALT baseline")
 s.time=100.2
 eq(w.onClientEvent(p).status,"WAITING","one exact UpdateTrade packet")
 after()
 s.time=100.3
 eq(w.tick().status,"WAITING","first GUI after frame")
 s.time=100.5
 local r=w.tick()
 return r,s,w,p,after
end
do
 local r,s,w=proof()
 eq(r.status,"CLIENT_BOTH_SIDES_RAW_KEY_CANDIDATES_UNATTRIBUTED",
  "two-sided real Stage101 raw candidates crosschecked with original bound/GUI")
 eq(r.p3P4LeaseChecked,true,"real protected client lease checked")
 eq(r.physicalGuiCrossChecked,true,"two independent local side GUI readers agree")
 eq(r.exactOneClientEventObserved,true,"one witnessed callback")
 eq(r.clientBothSidesCandidateConsistent,true,"both sides matched")
 eq(r.uniqueRawWeaponTypeCandidate,true,"unique client candidate per slot")
 eq(r.matchedOwnSlots,1,"one MAIN physical slot")
 eq(r.matchedTheirSlots,1,"one ALT physical slot")
 denied(r)
 eq(w.tick().status,r.status,"terminal frame cannot send or revisit")
 denied(w.stop())
end
do
 local r=proof({swapped=true})
 eq(r.status,"CLIENT_BOTH_SIDES_RAW_KEY_CANDIDATES_UNATTRIBUTED",
  "swapped actual Player1 Player2 remains oriented by exact player objects")
 denied(r)
end
do
 local s,w=fixture()
 s.root={}
 eq(w.begin().status,"WAITING","scope frozen after first exact environment")
 s.time=100.2
 s.root={}
 eq(w.tick().status,"BLOCKED","client P3 root replaced during lease")
 denied(w.status())
end
do
 local s,w,p,after=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 s.ownOverride={candidate(1,"WrongWeapon",1,false)}
 after();s.time=100.3
 eq(w.tick().status,"BLOCKED","stage9 GUI must independently agree with protected IO")
 denied(w.status())
end
do
 local s,w,p,after=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 s.allowBound=false
 after();s.time=100.3
 eq(w.tick().status,"BLOCKED","no verification after original lease disappears")
end
do
 local s,w,p,after=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 after();s.time=100.3
 w.tick()
 p[1].Player1.Offer[1][1]="Gingerscope"
 s.time=100.5
 local r=w.tick()
 eq(r.status,"INCONCLUSIVE","client payload mutated after capture? fail closed until clone available")
 denied(r)
end
do
 local s,w,p=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 s.time=100.21
 eq(w.onClientEvent(p).status,"BLOCKED","two concurrent callbacks void evidence")
 denied(w.status())
end
do
 local s,w,p,after=fixture()
 w.begin();after();s.time=100.2
 eq(w.onClientEvent(p).status,"BLOCKED","GUI changed before callback never becomes causal evidence")
 denied(w.status())
end
do
 local s,w,p,after=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 after();s.time=100.3;w.tick()
 s.raw=raw({slot(1,"Batwing","x2",false)},
           {slot(1,"Immortal","x2",true)})
 s.time=100.5
 eq(w.tick().status,"BLOCKED","unstable after second GUI frame cannot pass")
end
do
 local s,w,p,after=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 after();s.time=100.3;w.tick()
 s.time=101.5
 eq(w.tick().status,"BLOCKED","post-event stability must be <=1s")
end
do
 local s,w=fixture()
 w.begin();s.time=104.5
 eq(w.tick().status,"BLOCKED","first event window has 3s bound")
end
do
 local s,w,p,after=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 after();s.time=100.3;w.tick()
 s.time=100.5
 p[1].Player1.Accepted=true
 eq(w.tick().status,"INCONCLUSIVE","changed event accepted invalid")
end
do
 local s,w,p=fixture()
 w.begin();s.time=100.2
 w.stop()
 eq(w.onClientEvent(p).status,"BLOCKED","STOP prevents future callback")
 denied(w.status())
end
do
 local s,w,p,after=fixture()
 s.ownOverride={candidate(1,"Batwing",1,false)}
 eq(w.begin().status,"BLOCKED","baseline physical original protected/GUI mismatch")
 denied(w.status())
end
do
 local s,w,p,after=fixture()
 w.begin();s.time=100.2;w.onClientEvent(p)
 after();s.time=100.3;w.tick()
 s.time=100.5
 p[1].Player2.Offer={{"UnknownWeapon",2,"Weapons"}}
 local r=w.tick()
 eq(r.status,"INCONCLUSIVE","unknown actual client raw key cannot pass")
 denied(r)
end
print("[PASS] Stage101 original P3/P4 two-sided client identity witness: "..tests.." assertions")
