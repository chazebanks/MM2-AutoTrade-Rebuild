-- Stage25 synthetic read-only, anonymized scanner evidence.
local dir=arg[1] or "pdiddler/new_part4"
local Probe=assert(loadfile(dir.."/STAGE25_READONLY_DIAGNOSTIC.lua"))()
local passed=0
local function test(name,fn)
 local ok,reason=pcall(fn)
 if not ok then error(name..": "..tostring(reason)) end
 passed=passed+1
end
local function fixture()
 local Players={}
 local me={UserId=100,Parent=Players}
 local other={UserId=200,Parent=Players}
 local inv={fingerprint="proof-x",unmapped=0,unpriced=0,badQty=0,
    items={{id="Mortal",name="Mortal",checkerId="101",page="godly",
        qty=1,cat="Weapons",type="Knife"}}}
 local rec={player=other,state="whitelist",inv=inv,
   scanProof={kind="local-stable-scan-publication-v1",
     jobId="same-job",playerUserId=200,fingerprint="proof-x",
     completedAtMono=99,sequence=1}}
 local scan={getRecord=function(id)assert(id==200);return rec end,
     getVerificationState=function()
       return {player=other,record=rec,scanning=false,retryScheduled=false}
     end}
 local ctx={scanner=scan,players=Players,localPlayer=me,
    roster={me,other},jobId="same-job",mono=100,maxAgeSeconds=30,
    marketFresh=true}
 return ctx,rec,other
end
test("recent source/client-scan is classified but not server attested",function()
 local c=fixture();local r=Probe.capture(c)
 assert(r.cachedPlayers==1 and r.recent==1 and r.stale==0)
 assert(r.scanFreshnessProvenForAll==true)
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.serverAttestation==false)
 assert(r.records[1].label=="P1" and r.records[1].ageSeconds==1)
end)
test("old scan expires",function()
 local c=fixture();c.mono=140
 local r=Probe.capture(c)
 assert(r.stale==1 and r.recent==0)
end)
test("no scan proof cannot fabricate recency",function()
 local c,rec=fixture();rec.scanProof=nil
 local r=Probe.capture(c)
 assert(r.unverified==1 and r.recent==0)
end)
test("mismatched job or fingerprint is not trusted",function()
 local c,rec=fixture();rec.scanProof.jobId="other"
 assert(Probe.capture(c).unverified==1)
 rec.scanProof.jobId="same-job"
 rec.scanProof.fingerprint="bad"
 assert(Probe.capture(c).unverified==1)
end)
test("scan in progress is not considered completed",function()
 local c,rec,player=fixture()
 c.scanner.getVerificationState=function()return {
    player=player,record=rec,scanning=true,retryScheduled=false}end
 assert(Probe.capture(c).unverified==1)
end)
test("unknown source record is not a valid whitelist",function()
 local c,rec=fixture();rec.state="unknown"
 assert(Probe.capture(c).unverified==1)
end)
test("unmapped eligible weapon is not silently assumed complete",function()
 local c,rec=fixture();rec.inv.unmapped=1
 assert(Probe.capture(c).unverified==1)
end)
test("blacklist with eligible item fails",function()
 local c,rec=fixture();rec.state="blacklist"
 assert(Probe.capture(c).unverified==1)
end)
test("status reports source freshness independently",function()
 local c=fixture();c.marketFresh=false
 local r=Probe.capture(c)
 assert(r.sourceFresh==false and r.recent==1)
 assert(r.authorizesTrade==false)
end)
test("no opponent does not produce false completeness",function()
 local c=fixture();c.roster={c.localPlayer}
 local r=Probe.capture(c)
 assert(r.cachedPlayers==0 and r.scanFreshnessProvenForAll==false)
end)
test("never leaks ids, player names, or job in report",function()
 local c=fixture();local r=Probe.capture(c)
 for k in pairs(r) do
  assert(k~="UserId" and k~="jobId" and k~="Name")
 end
 for _,row in ipairs(r.records) do
  assert(row.userId==nil and row.jobId==nil and row.name==nil)
 end
end)
print("PASS",passed,"Stage25 read-only scanner proof diagnostic tests")
