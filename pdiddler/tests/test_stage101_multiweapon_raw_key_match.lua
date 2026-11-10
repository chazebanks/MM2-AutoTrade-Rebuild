-- Stage101: ACTUAL original Stage9 amount parser + Stage83 189-entry public
-- reference registry. Synthetic GUI/event input only. No Roblox remotes.
local M=assert(loadfile(assert(os.getenv("STAGE101_MODULE"))))()
local Original=assert(loadfile(assert(os.getenv("STAGE101_ORIGINAL_STAGE9"))))()
local Registry=assert(loadfile(assert(os.getenv("STAGE101_ORIGINAL_STAGE83"))))()
local groups=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("STAGE101 FAIL "..name..": "..tostring(err)) end
 groups=groups+1;print("PASS Stage101 "..name)
end
local function eq(a,b,n)
 assert(a==b,(n or "mismatch").." got="..tostring(a).." expected="..tostring(b))
end
local function denied(r)
 assert(type(r)=="table")
 for _,k in ipairs({
 "marketValueAuthority","eventSessionAssociationProven",
 "callbackCausalityProven","serverTradeRevisionProven",
 "rawItemIdConfirmed","uniqueWeaponInstanceProven","ownerSideSlotBound",
 "authenticatedOwnedInventory","numericSupremeCheckerIdVerified",
 "currentPricesVerified","priceForTradeVerified","sourcePublisherFresh",
 "serverAttestation","serverCompletionProven","authorizesTrade",
 "authorizesAccept","mayRecordCompletedTrade","mayReportProfit",
 "maySendDiscordWebhook","mayUseForStrategyLearning"
 }) do eq(r[k],false,k) end
 eq(r.tradeOutcome,"UNKNOWN")
 eq(r.readOnly,true);eq(r.clientOnly,true)
 for k,v in pairs(r) do
  if type(v)=="string" then
   for _,secret in ipairs({"Batwing","Scythe","Gingerscope",
     "ImmortalChroma","player_alt","secret_job"}) do
    assert(not v:find(secret,1,true),"private raw key/name in summary "..k)
   end
  end
 end
end
local function meta(key)
 local v=assert(Registry.entries[key],"archival public reference "..key)
 return {ItemName=v[1],ItemType=v[2],Rarity=v[3],Chroma=v[4]}
end
local Catalog={
 Scythe=meta("Scythe"),
 Gingerscope=meta("Gingerscope"),
 ImmortalChroma=meta("ImmortalChroma"),
 AmericaSword=meta("AmericaSword"),
}
local function slot(index,label,amount,chroma,rawId)
 local v={slot=index,label=label,amountText=amount or "",chroma=chroma==true}
 if rawId~=nil then v.rawId=rawId end
 return v
end
local function deepRows(rows)
 local out={}
 for i,v in ipairs(rows) do
  out[i]={slot=v.slot,label=v.label,amountText=v.amountText,
    chroma=v.chroma,rawId=v.rawId}
 end
 return out
end
local function snapshot(c,at,ours,theirs)
 return {
  at=at,session=c.session,jobId=c.jobId,root=c.root,
  localPlayer=c.localPlayer,partnerPlayer=c.partnerPlayer,
  raw={tradeOpen=true,contextOK=true,session=c.session,
   our={complete=true,accepted=false,slots=deepRows(ours or {})},
   their={complete=true,accepted=false,slots=deepRows(theirs or {})}}
 }
end
local function newFixture(options)
 options=options or {}
 local c={session="session_private",jobId="secret_job",root={},
  localPlayer={Name="player_main"},partnerPlayer={Name="player_alt"}}
 local ours=options.ourGui or {slot(1,"Batwing","",false)}
 local theirs=options.theirGui or {
  slot(1,"Gingerscope","",false),
  slot(2,"Immortal","x2",true)
 }
 local ourKeys=options.ourEvent or {{"Scythe",1,"Weapons"}}
 local theirKeys=options.theirEvent or {
  {"Gingerscope",1,"Weapons"},{"ImmortalChroma",2,"Weapons"}
 }
 local left={Player=c.localPlayer,Accepted=false,Offer=ourKeys}
 local right={Player=c.partnerPlayer,Accepted=false,Offer=theirKeys}
 if options.swapped then left,right=right,left end
 local root={LastOffer=12,Locked=false,Player1=left,Player2=right}
 local input={
  scope=c,eventCount=1,
  before=snapshot(c,100,options.beforeOur or {},
                     options.beforeTheir or {}),
  receipt={
   at=100.2,jobId=c.jobId,session=c.session,root=c.root,
   localPlayer=c.localPlayer,partnerPlayer=c.partnerPlayer,
   packed={n=1,[1]=root}
  },
  after1=snapshot(c,100.3,ours,theirs),
  after2=snapshot(c,100.5,ours,theirs)
 }
 return input
end
local function inspect(i,c,r)
 return M.inspect(i,c or Catalog,r or Registry,Original)
end
test("original source alias Batwing raw Scythe and two-sided stacked Chroma full match",function()
 eq(Registry.entries.Scythe[1],"Batwing")
 local input=newFixture()
 local r,private=inspect(input)
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(r.bothSidesReconciled,true)
 eq(r.ourMatchedSlotCount,1);eq(r.theirMatchedSlotCount,2)
 eq(r.guiNameOnlySlotCount,3)
 eq(r.guiRawTextSlotCount,0)
 eq(r.clientPerSlotRawKeyCandidateUnique,true)
 denied(r)
 assert(type(private)=="table")
 eq(private.validForAutomatedTrade,false)
 eq(private.validForAutomatedAccept,false)
 eq(private.rawKeyServerAuthenticated,false)
 eq(private.ours[1].key,"Scythe")
 eq(private.theirs[1].key,"Gingerscope")
 eq(private.theirs[2].key,"ImmortalChroma")
 eq(private.theirs[2].quantity,2)
end)
test("swapped Player1/2 resolves correct own vs other side",function()
 local r,private=inspect(newFixture({swapped=true}))
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(private.ours[1].key,"Scythe")
 eq(private.theirs[2].key,"ImmortalChroma")
 denied(r)
end)
test("one-sided earlier Stage97 shape maps, but still client-only",function()
 local i=newFixture({ourGui={},ourEvent={},
   theirGui={slot(1,"Batwing","",false)},
   theirEvent={{"Scythe",1,"Weapons"}}})
 local r,p=inspect(i)
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(r.ourMatchedSlotCount,0)
 eq(p.theirs[1].key,"Scythe");denied(r)
end)
test("GUI raw text present and correct increases corroboration but not authority",function()
 local i=newFixture({ourGui={slot(1,"Batwing","",false,"Scythe")},
   theirGui={slot(1,"Gingerscope","",false,"Gingerscope")}, 
   theirEvent={{"Gingerscope",1,"Weapons"}}})
 local r,p=inspect(i)
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(r.guiRawTextSlotCount,2);eq(r.guiNameOnlySlotCount,0)
 eq(r.rawItemIdConfirmed,false)
 denied(r)
end)
test("two identical event game keys and two identical GUI slots are key-unambiguous",function()
 local i=newFixture({ourGui={},ourEvent={},
  theirGui={slot(1,"Batwing","",false),slot(2,"Batwing","",false)},
  theirEvent={{"Scythe",1,"Weapons"},{"Scythe",1,"Weapons"}}})
 local r,p=inspect(i)
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(p.theirs[1].key,"Scythe");eq(p.theirs[2].key,"Scythe")
 denied(r)
end)
test("different raw keys with identical displayed name/variant are ambiguous",function()
 local i=newFixture({ourGui={},ourEvent={},
  theirGui={slot(1,"Batwing","",false),slot(2,"Batwing","",false)},
  theirEvent={{"Scythe",1,"Weapons"},{"TwinScythe",1,"Weapons"}}})
 local registry={}
 for k,v in pairs(Registry) do registry[k]=v end
 registry.entries={}
 for k,v in pairs(Registry.entries) do registry.entries[k]=v end
 registry.entries.TwinScythe={"Batwing","Knife","Ancient",false,"ancient","Batwing"}
 local cat={}
 for k,v in pairs(Catalog) do cat[k]=v end
 cat.TwinScythe=meta("Scythe")
 local r,p=inspect(i,cat,registry)
 eq(r.status,"INCONCLUSIVE")
 eq(r.reason,"THEIR_MULTIPLE_DISTINCT_CLIENT_RAW_KEYS_MATCH_GUI_SLOT")
 eq(p,nil);denied(r)
end)
test("exact GUI raw text resolves otherwise ambiguous identical display without promotion",function()
 local i=newFixture({ourGui={},ourEvent={},
  theirGui={slot(1,"Batwing","",false,"Scythe"),
    slot(2,"Batwing","",false,"TwinScythe")},
  theirEvent={{"Scythe",1,"Weapons"},{"TwinScythe",1,"Weapons"}}})
 local registry={}
 for k,v in pairs(Registry) do registry[k]=v end
 registry.entries={}
 for k,v in pairs(Registry.entries) do registry.entries[k]=v end
 registry.entries.TwinScythe={"Batwing","Knife","Ancient",false,"ancient","Batwing"}
 local cat={}
 for k,v in pairs(Catalog) do cat[k]=v end
 cat.TwinScythe=meta("Scythe")
 local r,p=inspect(i,cat,registry)
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(p.theirs[2].key,"TwinScythe")
 eq(r.rawItemIdConfirmed,false);denied(r)
end)
test("unknown key and independent metadata mismatch must not guess from a label",function()
 local variants={
  function(i)i.receipt.packed[1].Player2.Offer[1][1]="missingRaw" end,
  function(i)i.receipt.packed[1].Player2.Offer[1][1]="Scythe" end,
  function(i)i.after1.raw.their.slots[1].label="Batwing"
               i.after2.raw.their.slots[1].label="Batwing" end,
 }
 for x,fn in ipairs(variants) do
  local i=newFixture();fn(i)
  local r,p=inspect(i)
  eq(r.status,"INCONCLUSIVE","unknown variant "..x)
  eq(p,nil);denied(r)
 end
 local i=newFixture()
 local cat={Scythe=meta("Scythe"),Gingerscope=meta("Gingerscope"),
            ImmortalChroma=meta("ImmortalChroma")}
 cat.Gingerscope.ItemType="Knife"
 local r=inspect(i,cat)
 eq(r.status,"INCONCLUSIVE");denied(r)
end)
test("Chroma versus normal and x2 mismatches are refused",function()
 local variants={
  function(i)i.after1.raw.their.slots[2].chroma=false
               i.after2.raw.their.slots[2].chroma=false end,
  function(i)i.after1.raw.their.slots[2].amountText="x3"
               i.after2.raw.their.slots[2].amountText="x3" end,
  function(i)i.receipt.packed[1].Player2.Offer[2][2]=1 end,
  function(i)i.receipt.packed[1].Player2.Offer[2][3]="Pets" end,
 }
 for x,fn in ipairs(variants) do
  local i=newFixture();fn(i)
  local r,p=inspect(i)
  eq(r.status,"INCONCLUSIVE","variant mismatch "..x)
  eq(p,nil);denied(r)
 end
end)
test("partial event/GUI offer is rejected, not relabeled as fully matched",function()
 local vars={
  function(i)table.remove(i.receipt.packed[1].Player2.Offer,2) end,
  function(i)table.remove(i.after1.raw.their.slots,2)
               table.remove(i.after2.raw.their.slots,2) end,
  function(i)table.remove(i.receipt.packed[1].Player1.Offer,1) end,
  function(i)i.receipt.packed[1].Player2.Offer[3]={"Scythe",1,"Weapons"} end,
  function(i)i.after1.raw.their.slots[3]=slot(3,"Batwing","",false)
               i.after2.raw.their.slots[3]=slot(3,"Batwing","",false) end,
 }
 for x,fn in ipairs(vars) do
  local i=newFixture();fn(i)
  local r,p=inspect(i)
  eq(r.status,"INCONCLUSIVE","partial "..x)
  eq(p,nil);denied(r)
 end
end)
test("four physical slots allow five stacked copies without granting trade authority",function()
 -- MM2 permits four distinct slots, with duplicates stacked within one slot.
 local i=newFixture({ourGui={},ourEvent={},
   theirGui={slot(1,"Batwing","x5",false)},
   theirEvent={{"Scythe",5,"Weapons"}}})
 local r,p=inspect(i)
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(r.theirMatchedSlotCount,1);eq(p.theirs[1].quantity,5)
 denied(r)
end)
test("two physical slots may hold seven stacked copies",function()
 local i=newFixture({ourGui={},ourEvent={},
   theirGui={slot(1,"Batwing","x3",false),slot(2,"Batwing","x4",false)},
   theirEvent={{"Scythe",3,"Weapons"},{"Scythe",4,"Weapons"}}})
 local r,p=inspect(i)
 eq(r.status,"CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED",r.reason)
 eq(r.theirMatchedSlotCount,2)
 eq(p.theirs[1].quantity,3);eq(p.theirs[2].quantity,4)
 denied(r)
end)
test("original Stage9 quantity parser still rejects values above one million",function()
 local i=newFixture({ourGui={},ourEvent={},
   theirGui={slot(1,"Batwing","x1000001",false)},
   theirEvent={{"Scythe",1000001,"Weapons"}}})
 local r,p=inspect(i)
 eq(r.status,"INCONCLUSIVE");eq(p,nil);denied(r)
end)
test("five distinct physical slots remain invalid",function()
 local rows,events={},{}
 for j=1,5 do
   rows[j]=slot(j,"Batwing","",false)
   events[j]={"Scythe",1,"Weapons"}
 end
 local i=newFixture({ourGui={},ourEvent={},theirGui=rows,theirEvent=events})
 local r,p=inspect(i)
 eq(r.status,"INCONCLUSIVE");eq(p,nil);denied(r)
end)
test("client Player, root, job, acceptance and event session mismatch fail closed",function()
 local variants={
  function(i)i.after2.root={} end,
  function(i)i.before.jobId="old job" end,
  function(i)i.receipt.partnerPlayer={} end,
  function(i)i.receipt.packed[1].Player1.Player={} end,
  function(i)i.receipt.packed[1].Player1.Accepted=true end,
  function(i)i.after1.raw.their.accepted=true end,
  function(i)i.after2.raw.tradeOpen=false end,
  function(i)i.receipt.packed[1].Locked=true end,
  function(i)i.receipt.packed.n=2 end,
  function(i)i.eventCount=2 end,
  function(i)i.before.at=100.3 end,
  function(i)i.after2.at=100.31 end,
 }
 for x,fn in ipairs(variants) do
  local i=newFixture();fn(i)
  local r,p=inspect(i)
  eq(r.status,"INCONCLUSIVE","session mismatch "..x)
  eq(p,nil);denied(r)
 end
end)
test("no observed change and unstable post-event GUI refuse client binding",function()
 local i=newFixture()
 i.before=snapshot(i.scope,100,i.after1.raw.our.slots,
                             i.after1.raw.their.slots)
 local r,p=inspect(i);eq(r.status,"INCONCLUSIVE");eq(p,nil);denied(r)
 local j=newFixture()
 j.after2.raw.their.slots[2].amountText="x3"
 r,p=inspect(j);eq(r.status,"INCONCLUSIVE");eq(p,nil);denied(r)
end)
test("one event snapshot but both GUI offers empty is not a positive candidate",function()
 local i=newFixture({ourGui={},theirGui={},ourEvent={},theirEvent={}})
 local r,p=inspect(i)
 eq(r.status,"INCONCLUSIVE");eq(p,nil);denied(r)
end)
test("500 deterministic malformed or mutated inputs never authorize trade or Accept",function()
 for i=1,500 do
  local v=newFixture({swapped=i%5==0})
  local m=i%15
  if m==0 then v.eventCount=2 end
  if m==1 then v.receipt.jobId="new job" end
  if m==2 then v.receipt.packed[1].Locked=true end
  if m==3 then v.after1.raw.their.slots[2].label="Fake Item" end
  if m==4 then v.after2.raw.their.slots[2].amountText="x3" end
  if m==5 then v.receipt.packed[1].Player1.Accepted=true end
  if m==6 then v.receipt.packed[1].Player2.Accepted=true end
  if m==7 then v.after1.raw.their.slots[2].chroma=false end
  if m==8 then v.after2.raw.tradeOpen=false end
  if m==9 then v.before.at=101 end
  if m==10 then v.after2.root={} end
  if m==11 then v.receipt.packed[1].Player1.Offer={} end
  if m==12 then v.receipt.packed[1].Player2.Offer={} end
  if m==13 then v.after1.raw.our.slots[1].amountText="x2" end
  if m==14 then v.after1.raw.their.slots[2].rawId="mismatch" end
  local r,p=inspect(v)
  denied(r)
  eq(r.status,"INCONCLUSIVE","mutant "..i)
  eq(p,nil)
 end
end)
print("STAGE101_ORIGINAL_PART4_WEAPON_RECONCILE_PASS groups="..groups.." mutants=500")
