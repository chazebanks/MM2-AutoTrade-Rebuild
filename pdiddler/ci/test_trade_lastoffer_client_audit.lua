local M=assert(loadfile(assert(os.getenv("LASTOFFER_MODULE"))))()
local tests=0
local function eq(a,b,label)
    assert(a==b, (label or "unexpected").." got "..tostring(a).." expected "..tostring(b))
end
local function scope()
    return {session="private_session",jobId="private_job",root={},localPlayer={},partnerPlayer={}}
end
local function packet(c,token,ours,theirs,swap)
    local mine={Player=c.localPlayer,Accepted=false,Offer=ours or {}}
    local other={Player=c.partnerPlayer,Accepted=false,Offer=theirs or {}}
    return {LastOffer=token,Locked=false,
        Player1=swap and other or mine,Player2=swap and mine or other}
end
local function item(key,n)
    return {key,n or 1,"Weapons"}
end
local function denied(r)
    eq(r.clientOnly,true);eq(r.readOnly,true)
    for _,k in ipairs({"serverTradeRevisionProven","eventSessionAssociationProven",
      "callbackCausalityProven","rawItemIdConfirmed","uniqueWeaponInstanceProven",
      "serverCompletionProven","authorizesTrade","authorizesOffer","authorizesAccept",
      "mayRecordCompletedTrade","mayReportProfit","maySendDiscordWebhook",
      "mayUseForStrategyLearning","lastOfferValueExposed","clientGuiCrossChecked"}) do
        eq(r[k],false,k)
    end
    eq(r.tradeOutcome,"UNKNOWN")
    for k,v in pairs(r) do
        if type(v)=="string" then
            assert(not v:find("private",1,true) and
                   not v:find("Batwing",1,true) and
                   not v:find("Harvester",1,true) and
                   not v:find("v_secret",1,true),"private data leaked in "..k)
        end
    end
end
local function test(label,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..label..": "..tostring(err)) end
    tests=tests+1;print("PASS LastOffer "..label)
end
local function base()
    local c=scope();local a=assert(M.new(c))
    local r=a.observe(c,packet(c,12,{item("Batwing")},{item("Harvester")}),1)
    eq(r.status,"CLIENT_LASTOFFER_FIRST_EVENT_UNATTRIBUTED");denied(r)
    return c,a
end
test("baseline is never server evidence",function()
    local c,a=base();eq(a.stop().status,"STOPPED")
    local r=a.observe(c,packet(c,13),2)
    eq(r.status,"INCONCLUSIVE");denied(r)
end)
test("changed LastOffer with changed offer is only correlation",function()
    local c,a=base()
    local r=a.observe(c,packet(c,13,{item("Batwing")},{item("Harvester"),item("Chroma Fang",2)}),2)
    eq(r.status,"CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER")
    eq(r.changedTokenAndOffer,1);denied(r)
end)
test("same token with changed offer exposes weak token hypothesis",function()
    local c,a=base()
    local r=a.observe(c,packet(c,12,{item("Batwing")},{item("Harvester",2)}),2)
    eq(r.status,"CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER")
    eq(r.unchangedTokenChangedOffer,1);denied(r)
end)
test("same offer changed token is not a revision proof",function()
    local c,a=base()
    local r=a.observe(c,packet(c,"v_secret",{item("Batwing")},{item("Harvester")}),2)
    eq(r.status,"CLIENT_LASTOFFER_CHANGED_WITH_SAME_OFFER")
    eq(r.changedTokenUnchangedOffer,1);denied(r)
end)
test("same token and same offer is possibly duplicate",function()
    local c,a=base()
    local r=a.observe(c,packet(c,12,{item("Batwing")},{item("Harvester")}),2)
    eq(r.status,"CLIENT_LASTOFFER_UNCHANGED_WITH_SAME_OFFER")
    eq(r.unchangedTokenUnchangedOffer,1);denied(r)
end)
test("swapped Player1/2 and valid stacked x5 accepted",function()
    local c=scope();local a=assert(M.new(c))
    local r=a.observe(c,packet(c,1,{item("Batwing",5)},{item("Harvester",6)},true),1)
    eq(r.observedClientCallbacks,1);denied(r)
    r=a.observe(c,packet(c,2,{item("Batwing",5)},{item("Harvester",7)},false),2)
    eq(r.status,"CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER");denied(r)
end)
test("mutable callback table does not alter frozen first observation",function()
    local c=scope();local a=assert(M.new(c))
    local p=packet(c,1,{item("Batwing")},{item("Harvester")})
    denied(a.observe(c,p,1))
    p.LastOffer=2;p.Player2.Offer[1][1]="Faked"
    local r=a.observe(c,packet(c,1,{item("Batwing")},{item("Harvester")}),2)
    eq(r.status,"CLIENT_LASTOFFER_UNCHANGED_WITH_SAME_OFFER");denied(r)
end)
test("reject wrong scope and never revive",function()
    for _,field in ipairs({"session","jobId","root","localPlayer","partnerPlayer"}) do
        local c,a=base()
        local changed={session=c.session,jobId=c.jobId,root=c.root,
          localPlayer=c.localPlayer,partnerPlayer=c.partnerPlayer}
        changed[field]=field=="session" and "other" or {}
        local r=a.observe(changed,packet(c,13),2)
        eq(r.status,"INCONCLUSIVE");denied(r)
        eq(a.observe(c,packet(c,13),3).status,"INCONCLUSIVE")
    end
end)
test("malformed tokens and malformed packets failclosed",function()
    local kinds={true,{},-1,math.huge,0/0,"","A\nB",string.rep("z",129)}
    for _,token in ipairs(kinds) do
        local c,a=base();local r=a.observe(c,packet(c,token),2)
        eq(r.status,"INCONCLUSIVE");denied(r)
    end
    local malformed={
      function(p) p.Locked=true end,
      function(p) p.ExtraServerSignedNonce="false" end,
      function(p) p.Player1.Accepted=true end,
      function(p) p.Player1.Offer={item("Bad",0)} end,
      function(p) p.Player1.Offer={item("Bad",1000001)} end,
      function(p) p.Player1.Offer={item("Bad",1),item("B",1),item("C",1),item("D",1),item("E",1)} end,
      function(p) p.Player2.Player={} end,
      function(p) p.Player1.Offer={{"Batwing",1,"Pets"}} end,
      function(p) p.Player1.Offer={{"Batwing",1,"Weapons","extra"}} end,
      function(p) p.Player1.Offer={[2]=item("Batwing")} end,
    }
    for _,change in ipairs(malformed) do
        local c,a=base();local p=packet(c,2);change(p)
        local r=a.observe(c,p,2)
        eq(r.status,"INCONCLUSIVE");denied(r)
    end
end)
test("reject clocks, expiry and bound event count",function()
    local c,a=base();eq(a.observe(c,packet(c,13),1).status,"INCONCLUSIVE")
    c,a=base();eq(a.observe(c,packet(c,13),122).status,"INCONCLUSIVE")
    c,a=base()
    for t=2,12 do denied(a.observe(c,packet(c,t),t)) end
    eq(a.observe(c,packet(c,13),13).status,"INCONCLUSIVE")
end)
test("indistinguishable late old event can never authorize Accept",function()
    -- Same callback objects, timing, offer rows and token can arise from two
    -- distinct physical histories; this client-only observer cannot know which.
    local x,a=base();local y,b=base()
    local p=packet(x,13,{item("Batwing")},{item("Harvester",2)})
    local q=packet(y,13,{item("Batwing")},{item("Harvester",2)})
    local r1=a.observe(x,p,2);local r2=b.observe(y,q,2)
    eq(r1.status,r2.status);eq(r1.authorizesAccept,false)
    denied(r1);denied(r2)
end)
print("LASTOFFER_CLIENT_ONLY_PASS "..tests.." named groups")
