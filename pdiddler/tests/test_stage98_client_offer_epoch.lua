-- Stage98 actual Lua5.4 research-only offer revision contract regression suite.
-- Uses the ORIGINAL unchanged Stage9 quantity parser pinned by Git blob SHA.
local MODULE=assert(os.getenv("STAGE98_MODULE"))
local CONTRACT=assert(os.getenv("STAGE98_ORIGINAL_STAGE9"))
local M=assert(loadfile(MODULE))()
local Stage9=assert(loadfile(CONTRACT))()
local Guard=assert(loadfile(assert(os.getenv("STAGE98_ORIGINAL_GUARD"))))()
local groups=0
local function eq(a,b,msg)
 assert(a==b, (msg or "mismatch")..": got="..tostring(a)..", expected="..tostring(b))
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL Stage98 "..name..": "..tostring(err)) end
 groups=groups+1
 print("PASS Stage98 "..name)
end
local function scope()
 return {root={},session="private_client_session",jobId="private_server_job",
   localPlayer={},partnerPlayer={}}
end
local function slot(i,label,qty,chroma,rawId)
 local t={slot=i,label=label or "Batwing",
  amountText=qty==nil and "" or qty,chroma=chroma==nil and false or chroma}
 if rawId~=nil then t.rawId=rawId end
 return t
end
local function snapshot(c,at,ours,theirs)
 return {at=at,root=c.root,session=c.session,jobId=c.jobId,
 localPlayer=c.localPlayer,partnerPlayer=c.partnerPlayer,
 raw={tradeOpen=true,contextOK=true,session=c.session,
   our={complete=true,accepted=false,slots=ours or {}},
   their={complete=true,accepted=false,slots=theirs or {}}}}
end
local function event(c,at)
 return {at=at,root=c.root,session=c.session,jobId=c.jobId,
   localPlayer=c.localPlayer,partnerPlayer=c.partnerPlayer}
end
local function denied(r)
 assert(type(r)=="table")
 for _,k in ipairs({
  "serverTradeRevisionProven","eventSessionAssociationProven",
  "callbackCausalityProven","rawOfferKeyBoundToPreprofile",
  "rawItemIdConfirmed","uniqueWeaponInstanceProven",
  "currentPricesVerified","priceForTradeVerified",
  "authenticatedOwnedInventory","numericSupremeCheckerIdVerified",
  "serverAttestation","serverCompletionProven","authorizesTrade",
  "authorizesAccept","mayRecordCompletedTrade","mayReportProfit",
  "maySendDiscordWebhook","mayUseForStrategyLearning"
 }) do eq(r[k],false,k) end
 eq(r.tradeOutcome,"UNKNOWN")
 eq(r.readOnly,true)
 eq(r.clientOnly,true)
 for k,v in pairs(r) do
  if type(v)=="string" then
   assert(not v:find("Batwing",1,true) and
          not v:find("Scythe",1,true) and
          not v:find("private_client",1,true) and
          not v:find("private_server",1,true),"private data in report "..tostring(k))
  end
 end
end
local function create()
 local c=scope()
 local s=assert(M.new(c,Stage9))
 denied(M.observe(s,snapshot(c,10)))
 denied(M.observe(s,snapshot(c,10.20)))
 return s,c
end
local function ready()
 local s,c=create()
 local r=M.observe(s,snapshot(c,10.30,{}, {slot(1,"Batwing")}))
 eq(r.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED");denied(r)
 r=M.observe(s,snapshot(c,10.51,{}, {slot(1,"Batwing")}))
 eq(r.status,"CLIENT_OFFER_STABLE_RESEARCH_ONLY");denied(r)
 local t,why=M.freezePreview(s,10.55)
 assert(t,"expected only local research token")
 denied(why)
 eq(why.status,"CLIENT_PREVIEW_TOKEN_CREATED_RESEARCH_ONLY")
 return s,c,t
end
test("initial EMPTY offer requires two distinct stable GUI reads",function()
 local c=scope();local s=assert(M.new(c,Stage9))
 local r=M.observe(s,snapshot(c,1))
 eq(r.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED")
 eq(r.localObservationRevision,1)
 denied(r)
 local token,reason=M.freezePreview(s,1.01)
 eq(token,nil);eq(reason.status,"CLIENT_PREVIEW_NOT_READY")
 local same=M.observe(s,snapshot(c,1.2))
 eq(same.status,"CLIENT_OFFER_STABLE_RESEARCH_ONLY")
 denied(same)
end)
test("one ALT item add yields local research token, NEVER trade permission",function()
 local s,c,t=ready()
 local r=M.checkPreview(s,t,10.6)
 eq(r.status,"CLIENT_PREVIEW_STILL_CURRENT_RESEARCH_ONLY")
 eq(r.theirCopyCount,1)
 eq(r.nameOnlyGuiSlotCount,1)
 eq(r.authorizesAccept,false)
 denied(r)
end)
test("ALT item removal invalidates previously stable research preview",function()
 local s,c,t=ready()
 local r=M.observe(s,snapshot(c,10.7))
 eq(r.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED")
 eq(r.theirCopyCount,0)
 eq(M.checkPreview(s,t,10.71).status,"CLIENT_PREVIEW_REVOKED")
 denied(r)
end)
test("stack x2 / x3, slot reordering, chroma and raw ID mutations invalidate",function()
 for _,fn in ipairs({
  function(v)v[1].amountText="x2" end,
  function(v)v[1].amountText="×2" end,
  function(v)v[1].slot=2 end,
  function(v)v[1].chroma=true end,
  function(v)v[1].rawId="Scythe" end,
  function(v)v[1].label="Chroma Batwing" end,
 }) do
  local s,c,t=ready()
  local a={slot(1,"Batwing")}
  fn(a)
  local r=M.observe(s,snapshot(c,10.8,{},a))
  eq(r.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED")
  eq(M.checkPreview(s,t,10.81).status,"CLIENT_PREVIEW_REVOKED")
  denied(r)
 end
end)
test("sequential extra slot and four-slot maximum supported, fifth refused",function()
 local s,c,t=ready()
 local rows={slot(1,"Batwing"),slot(2,"Harvester")}
 eq(M.observe(s,snapshot(c,10.8,{},rows)).theirSlotCount,2)
 eq(M.checkPreview(s,t,10.81).status,"CLIENT_PREVIEW_REVOKED")
 rows[3]=slot(3,"Immortal")
 rows[4]=slot(4,"Emberbow")
 local r=M.observe(s,snapshot(c,11,{},rows))
 eq(r.theirSlotCount,4)
 eq(r.theirCopyCount,4)
 denied(r)
 rows[5]=slot(5,"Gingerscope")
 r=M.observe(s,snapshot(c,11.1,{},rows))
 eq(r.status,"INCONCLUSIVE")
 eq(r.reason,"SIDE_OR_ACCEPT_STATE_UNVERIFIED")
 denied(r)
end)
test("four-copy conservative limit blocks five copies even in four slots",function()
 local s,c,t=ready()
 local rows={slot(1,"Batwing","x2"),slot(2,"Harvester","x2"),
             slot(3,"Immortal","")}
 local r=M.observe(s,snapshot(c,10.8,{},rows))
 eq(r.status,"INCONCLUSIVE")
 eq(r.reason,"FOUR_COPY_CONSERVATIVE_LIMIT_EXCEEDED")
 denied(r)
end)
test("one client UpdateTrade callback revokes old token without claiming causality",function()
 local s,c,t=ready()
 local r=M.noteClientCallback(s,event(c,10.61))
 eq(r.status,"CLIENT_CALLBACK_INVALIDATED_PRIOR_PREVIEW")
 eq(r.pendingClientCallback,true)
 eq(M.checkPreview(s,t,10.62).status,"CLIENT_PREVIEW_REVOKED")
 eq(M.freezePreview(s,10.65),nil)
 denied(r)
 local gui=M.observe(s,snapshot(c,10.78,{}, {slot(1,"Batwing"),slot(2,"Harvester")}))
 eq(gui.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED")
 eq(gui.pendingClientCallback,false)
 eq(gui.eventSessionAssociationProven,false)
 denied(gui)
end)
test("duplicate callback, stale callback, wrong root or job causes terminal stop",function()
 for _,mode in ipairs({"duplicate","late","badRoot","badJob","before"}) do
  local s,c,t=ready()
  local e=event(c,10.6)
  if mode=="badRoot" then e.root={} end
  if mode=="badJob" then e.jobId="different" end
  if mode=="before" then e.at=10.2 end
  if mode=="late" then e.at=14 end
  if mode=="duplicate" then M.noteClientCallback(s,e) end
  local r=M.noteClientCallback(s,e)
  eq(r.status,"INCONCLUSIVE",mode)
  eq(r.reason,"CLIENT_CALLBACK_OUTSIDE_SINGLE_OBSERVATION_WINDOW")
  eq(M.checkPreview(s,t,10.65).status,"CLIENT_PREVIEW_REVOKED")
  denied(r)
 end
end)
test("callback without GUI mutation remains pending and expires terminally",function()
 local s,c,t=ready()
 M.noteClientCallback(s,event(c,10.7))
 local r=M.observe(s,snapshot(c,10.8,{}, {slot(1,"Batwing")}))
 eq(r.status,"CLIENT_EVENT_WITHOUT_GUI_CHANGE_PENDING")
 denied(r)
 r=M.observe(s,snapshot(c,13.71,{}, {slot(1,"Batwing")}))
 eq(r.status,"INCONCLUSIVE")
 eq(r.reason,"CLIENT_CALLBACK_WITHOUT_GUI_REVISION")
 eq(M.checkPreview(s,t,13.72).status,"CLIENT_PREVIEW_REVOKED")
 denied(r)
end)
test("identical visual amount texts normalize to same quantity, no spurious revision",function()
 local s,c,t=ready()
 local x=M.observe(s,snapshot(c,10.7,{}, {slot(1,"Batwing","x2")}))
 eq(x.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED")
 local y=M.observe(s,snapshot(c,10.91,{}, {slot(1,"Batwing","×2")}))
 eq(y.status,"CLIENT_OFFER_STABLE_RESEARCH_ONLY")
 eq(y.localObservationRevision,x.localObservationRevision)
 eq(M.checkPreview(s,t,10.92).status,"CLIENT_PREVIEW_REVOKED")
 denied(y)
end)
test("same root but changed partner, job or session is terminal",function()
 for _,kind in ipairs({"root","partner","job","session"}) do
  local s,c,t=ready()
  local v=snapshot(c,10.9,{}, {slot(1,"Batwing")})
  if kind=="root" then v.root={} end
  if kind=="partner" then v.partnerPlayer={} end
  if kind=="job" then v.jobId="different" end
  if kind=="session" then v.session="old" end
  local r=M.observe(s,v)
  eq(r.status,"INCONCLUSIVE")
  eq(r.reason,"CLIENT_SCOPE_OR_MONOTONIC_CLOCK_CHANGED")
  denied(r)
  eq(M.checkPreview(s,t,10.91).status,"CLIENT_PREVIEW_REVOKED")
 end
end)
test("both accept flags and trade closure terminate research token",function()
 for _,kind in ipairs({"ours","theirs","closed","context"}) do
  local s,c,t=ready()
  local v=snapshot(c,10.7,{}, {slot(1,"Batwing")})
  if kind=="ours" then v.raw.our.accepted=true end
  if kind=="theirs" then v.raw.their.accepted=true end
  if kind=="closed" then v.raw.tradeOpen=false end
  if kind=="context" then v.raw.contextOK=false end
  local r=M.observe(s,v)
  eq(r.status,"INCONCLUSIVE")
  denied(r)
  eq(M.checkPreview(s,t,10.71).status,"CLIENT_PREVIEW_REVOKED")
 end
end)
test("sparse duplicate slot, invalid chroma, invalid key and nil amount rejected",function()
 local mutate={
  function(v)v[2]=slot(1,"Harvester") end,
  function(v)v[1].slot=0 end,
  function(v)v[1].slot=5 end,
  function(v)v[1].chroma=nil end,
  function(v)v[1].rawId=17 end,
  function(v)v[1].rawId="\nabc" end,
  function(v)v[1].amountText=nil end,
  function(v)v[1].amountText="x0" end,
  function(v)v[1].label=" " end,
  function(v)v[1].label=42 end,
  function(v)v[1].amountText="x999" end,
 }
 for i,fn in ipairs(mutate) do
  local s,c,t=ready()
  local rows={slot(1,"Batwing")}
  fn(rows)
  local r=M.observe(s,snapshot(c,10.8,{},rows))
  eq(r.status,"INCONCLUSIVE","corruption "..i)
  eq(M.checkPreview(s,t,10.81).status,"CLIENT_PREVIEW_REVOKED")
  denied(r)
 end
end)
test("invalid frozen token, other session token and old observation age fail closed",function()
 local s,c,t=ready()
 eq(M.checkPreview(s,t,13).status,"CLIENT_PREVIEW_REVOKED")
 eq(M.checkPreview(s,t,10.4).status,"CLIENT_PREVIEW_REVOKED")
 local other,otherc=create()
 eq(M.checkPreview(other,t,10.6).status,"CLIENT_PREVIEW_REVOKED")
 eq(M.checkPreview(s,{epoch=s.epoch,owner=s},10.6).status,"CLIENT_PREVIEW_REVOKED")
 local token,status=M.freezePreview(s,15)
 eq(token,nil);eq(status.status,"CLIENT_PREVIEW_NOT_READY")
 denied(status)
end)
test("nonempty startup is terminal, never retroactively baseline an old trade",function()
 local c=scope();local s=M.new(c,Stage9)
 local r=M.observe(s,snapshot(c,10,{}, {slot(1,"Batwing")}))
 eq(r.status,"INCONCLUSIVE")
 eq(r.reason,"INITIAL_CLIENT_GUI_NOT_BOTH_EMPTY")
 denied(r)
end)
test("actual prior Stage105 offer guard rejects Stage98 invalidated local revision",function()
 local c=scope();local state=M.new(c,Stage9)
 M.observe(state,snapshot(c,10))
 M.observe(state,snapshot(c,10.2))
 local same=snapshot(c,10.4,{slot(1,"Batwing")},{slot(1,"Gingerscope")})
 local changed=M.observe(state,same)
 eq(changed.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED")
 M.observe(state,snapshot(c,10.61,{slot(1,"Batwing")},{slot(1,"Gingerscope")}))
 local token,tokenReport=M.freezePreview(state,10.7)
 assert(token);denied(tokenReport)
 local now=1794159000
 local proposal={sessionId="test_session",jobId="test_job",
   partnerKey="test_alt",catalogVersion="synthetic_stage98_catalogue",
   offerRevision=changed.localObservationRevision,observedAtUnix=now,
   ours={{index=1,key="test_ours",quantity=1}},
   theirs={{index=1,key="test_theirs",quantity=1}}}
 local obs={sessionId=proposal.sessionId,jobId=proposal.jobId,
   partnerKey=proposal.partnerKey,catalogVersion=proposal.catalogVersion,
   offerRevision=proposal.offerRevision,observedAtUnix=now,
   tradeOpen=true,exactPartnerBound=true,ourAccepted=false,
   theirAccepted=false,offerMutationPending=false,
   ours={{index=1,key="test_ours",quantity=1}},
   theirs={{index=1,key="test_theirs",quantity=1}}}
 local item=function(v)return {value=v,demand=7,stability="Stable",
   identityLinkEvidence="INDEPENDENT_EXACT"} end
 local catalog={version=proposal.catalogVersion,
   source="SUPREME_DISPLAY_RESEARCH_ONLY",
   publisherUpdatedAtUnix=now-100,retrievedAtUnix=now-3,
   items={test_ours=item(100),test_theirs=item(105)}}
 local research=Guard.evaluate(proposal,obs,catalog,now,5,4)
 eq(research.status,"RESEARCH_CANDIDATE_ONLY")
 eq(research.authorizesAccept,false)
 eq(research.authorizesTrade,false)
 -- A stale +5 research display MUST NOT survive a physical item removal.
 local removed=M.observe(state,snapshot(c,10.8,{slot(1,"Batwing")},{}))
 eq(removed.status,"CLIENT_LOCAL_OFFER_REVISION_CHANGED")
 eq(M.checkPreview(state,token,10.81).status,"CLIENT_PREVIEW_REVOKED")
 obs.offerRevision=removed.localObservationRevision
 obs.theirs={}
 local blocked=Guard.evaluate(proposal,obs,catalog,now,5,4)
 eq(blocked.status,"REJECTED")
 eq(blocked.reason,"OFFER_REVISION_CHANGED")
 eq(blocked.authorizesAccept,false)
 eq(blocked.mayReportProfit,false)
 denied(removed)
end)
test("700 deterministic adverse changes never create trade or Accept authority",function()
 for i=1,700 do
  local s,c,t=ready()
  local v=snapshot(c,10.7,{}, {slot(1,"Batwing")})
  local m=i%14
  if m==0 then v.at=10.1 end
  if m==1 then v.root={} end
  if m==2 then v.raw.their.slots[1].amountText="x0" end
  if m==3 then v.raw.their.slots[1].amountText="x2" end
  if m==4 then v.raw.their.slots[1].chroma=true end
  if m==5 then v.raw.their.slots[1].rawId="Scythe" end
  if m==6 then v.raw.our.accepted=true end
  if m==7 then v.raw.their.accepted=true end
  if m==8 then v.raw.tradeOpen=false end
  if m==9 then v.raw.our.slots={slot(1,"Gingerscope")} end
  if m==10 then v.raw.their.slots={slot(1,"Batwing"),slot(1,"Batwing")} end
  if m==11 then v.raw.their.slots={slot(1,"Batwing","x5")} end
  if m==12 then v.partnerPlayer={} end
  if m==13 then v.raw.their.slots={} end
  local r=M.observe(s,v)
  denied(r)
  eq(M.checkPreview(s,t,10.75).status,"CLIENT_PREVIEW_REVOKED","mutant "..i)
 end
end)
print("STAGE98_ORIGINAL_P4_PARSER_REVISIONS_PASS groups="..groups.." mutations=700")
