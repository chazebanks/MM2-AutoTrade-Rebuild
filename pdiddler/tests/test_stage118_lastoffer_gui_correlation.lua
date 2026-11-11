local Bridge=assert(loadfile(assert(os.getenv("STAGE118_BRIDGE"))))()
local Audit=assert(loadfile(assert(os.getenv("STAGE118_AUDIT"))))()
local Stage9=assert(loadfile(assert(os.getenv("STAGE118_STAGE9"))))()
local tests=0
local function eq(a,b,msg)
 assert(a==b,(msg or "mismatch").." got="..tostring(a).." expected="..tostring(b))
end
local function denied(r)
 eq(r.clientOnly,true);eq(r.readOnly,true)
 for _,k in ipairs({"rawItemIdConfirmed","uniqueWeaponInstanceProven",
  "eventSessionAssociationProven","callbackCausalityProven", "serverTradeRevisionProven",
  "serverCompletionProven","authorizesTrade","authorizesOffer","authorizesAccept",
  "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning"}) do eq(r[k],false,k) end
 eq(r.tradeOutcome,"UNKNOWN")
 for _,x in pairs(r) do if type(x)=="string" then
  assert(not x:find("Batwing",1,true) and not x:find("Harvester",1,true)
    and not x:find("private",1,true),"PII/raw identity escaped")
 end end
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL Stage118 "..name..": "..tostring(err)) end
 tests=tests+1;print("PASS Stage118 "..name)
end
local function slot(label,qty)
 return {slot=1,label=label or "Harvester",chroma=false,amountText=qty==1 and "" or "x"..tostring(qty)}
end
local function copySlots(slots)
 local t={}
 for i,s in ipairs(slots) do
  t[i]={slot=s.slot,label=s.label,chroma=s.chroma,amountText=s.amountText}
 end
 return t
end
local function fixture()
 local st={time=1.0,live=true,ours={},theirs={}}
 local c={session="private_client_scope",jobId="private_job",root={},localPlayer={},partnerPlayer={}}
 local function capture()
  return {session=c.session,jobId=c.jobId,root=c.root,
   localPlayer=c.localPlayer,partnerPlayer=c.partnerPlayer,
   raw={session=c.session,tradeOpen=true,contextOK=true,
    our={complete=true,accepted=st.ownAccepted or false,slots=copySlots(st.ours)},
    their={complete=true,accepted=st.altAccepted or false,slots=copySlots(st.theirs)}}}
 end
 local bridge=assert(Bridge.new(c,{audit=Audit,stage9=Stage9,
  capture=capture,now=function()return st.time end,isLive=function()return st.live end}))
 local function packet(token,alt)
  return {LastOffer=token,Locked=false,
   Player1={Player=c.localPlayer,Accepted=false,Offer={}},
   Player2={Player=c.partnerPlayer,Accepted=false,
    Offer=alt and {{"Harvester",alt,"Weapons"}} or {}}}
 end
 return st,c,bridge,packet
end
local function ready(st,bridge)
 denied(bridge.begin())
 st.time=1.20
 eq(bridge.tick().reason,"ALT_MANUAL_ADD_ONE")
end
local function first(st,bridge,packet)
 ready(st,bridge)
 st.time=1.3;denied(bridge.onClientEvent(packet(12,1)))
 st.theirs={slot("Harvester",1)}
 st.time=1.4;denied(bridge.tick())
 st.time=1.6;eq(bridge.tick().reason,"ALT_MANUAL_REMOVE_ONE")
end
local function finish(st,bridge,packet,lastToken)
 st.time=1.7;denied(bridge.onClientEvent(packet(lastToken,nil)))
 st.theirs={}
 st.time=1.8;denied(bridge.tick())
 st.time=2.0;local r=bridge.tick()
 denied(r)
 eq(r.status,"CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED")
 eq(r.clientGuiCrossChecked,true)
 eq(r.callbackCount,2)
 eq(r.localGuiTransitions,2)
 return r
end
test("two real Stage9 GUI changes and changed LastOffer still client-only",function()
 local st,c,b,p=fixture();first(st,b,p)
 local r=finish(st,b,p,13)
 eq(r.lastOfferEqualityClass,"CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER")
end)
test("two GUI changes with SAME LastOffer remains unattributed",function()
 local st,c,b,p=fixture();first(st,b,p)
 local r=finish(st,b,p,12)
 eq(r.lastOfferEqualityClass,"CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER")
end)
test("GUI changes before callback block",function()
 local st,c,b,p=fixture();ready(st,b)
 st.theirs={slot("Harvester",1)};st.time=1.3
 eq(b.tick().status,"INCONCLUSIVE")
 denied(b.onClientEvent(p(12,1)))
end)
test("malformed packet cannot pass",function()
 local st,c,b,p=fixture();ready(st,b)
 local bad=p("wrong",1);bad.Player2.Player={}
 st.time=1.3;eq(b.onClientEvent(bad).status,"INCONCLUSIVE")
end)
test("packet may be mutated after callback without altering frozen quantities",function()
 local st,c,b,p=fixture();ready(st,b)
 local packet=p(12,1)
 st.time=1.3;denied(b.onClientEvent(packet))
 packet.Player2.Offer[1][2]=99;packet.LastOffer="attacker mutation"
 st.theirs={slot("Harvester",1)};st.time=1.4;denied(b.tick())
 st.time=1.6;eq(b.tick().reason,"ALT_MANUAL_REMOVE_ONE")
end)
test("packet and GUI quantity disagreement rejected",function()
 local st,c,b,p=fixture();ready(st,b)
 st.time=1.3;denied(b.onClientEvent(p(12,2)))
 st.theirs={slot("Harvester",1)};st.time=1.4
 eq(b.tick().reason,"CLIENT_PACKET_GUI_QUANTITIES_DISAGREE")
end)
test("duplicate callback and extra callback after result rejected",function()
 local st,c,b,p=fixture();ready(st,b)
 st.time=1.3;denied(b.onClientEvent(p(12,1)))
 st.time=1.31;eq(b.onClientEvent(p(13,1)).status,"INCONCLUSIVE")
 st,c,b,p=fixture();first(st,b,p);finish(st,b,p,13)
 st.time=2.1;eq(b.onClientEvent(p(14,nil)).status,"INCONCLUSIVE")
end)
test("wrong root, accepted GUI, cancelled session failclosed",function()
 local st,c,b,p=fixture();ready(st,b)
 c.root={};st.time=1.3
 eq(b.onClientEvent(p(12,1)).status,"INCONCLUSIVE")
 st,c,b,p=fixture();ready(st,b)
 st.live=false;st.time=1.3
 eq(b.onClientEvent(p(12,1)).status,"INCONCLUSIVE")
 st,c,b,p=fixture();ready(st,b)
 st.altAccepted=true;st.time=1.3
 eq(b.onClientEvent(p(12,1)).status,"INCONCLUSIVE")
end)
test("post-callback timeout, rollback and monotone clock",function()
 local st,c,b,p=fixture();ready(st,b)
 st.time=1.3;denied(b.onClientEvent(p(12,1)))
 st.time=5;eq(b.tick().status,"INCONCLUSIVE")
 st,c,b,p=fixture();ready(st,b)
 st.time=1.3;denied(b.onClientEvent(p(12,1)))
 st.time=1.1;eq(b.tick().status,"INCONCLUSIVE")
end)
test("identical client-visible two-event sequences never prove server provenance",function()
 for i=1,200 do
  local st,c,b,p=fixture();first(st,b,p)
  local r=finish(st,b,p,(i%2==0) and 12 or 13)
  eq(r.serverTradeRevisionProven,false);eq(r.authorizesAccept,false)
 end
end)
print("STAGE118_LASTOFFER_STAGE9_SOURCE_BOUND_PASS "..tests.." groups, 200 two-event cases")
