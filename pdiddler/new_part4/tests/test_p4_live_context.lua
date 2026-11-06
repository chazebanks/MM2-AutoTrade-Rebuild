-- Stage24: mocked existing Part3 stable scan evidence into Stage17 context.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local Adapter=require("p4_live_context")
local count=0
local function test(name,fn)
 local ok,reason=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(reason)) end
 count=count+1
end
local function fixture()
 local clock=200
 local wall=1800000010
 local game={JobId="job-verified"}
 local player={UserId=1002,Parent={}}
 local a={id="Mortal",page="godly",checkerId="1031",name="Mortal",
    cat="Weapons",type="Knife",qty=1}
 local b={id="WatergunChroma",page="chroma",checkerId="810",
    name="Chroma Watergun",cat="Weapons",type="Gun",qty=1}
 local own={fingerprint="own-scan-A",unmapped=0,badQty=0,unpriced=0,items={a}}
 local their={fingerprint="their-scan-B",unmapped=0,badQty=0,unpriced=0,items={b}}
 local rec={player=player,state="whitelist",inv=their,scanProof={
    kind="local-stable-scan-publication-v1",jobId="job-verified",
    playerUserId=1002,fingerprint="their-scan-B",
    completedAtMono=198,sequence=7}}
 local profile={liveReady=true,version="test-2026-11-05",
   observedAtEpoch=wall-60,expiresAtEpoch=wall+60,
   isFresh=function(t) return t>=wall-60 and t<wall+60 end,
   get=function(p,id)
     if p=="godly" and id=="1031" then
       return {page=p,id=id,name="Mortal",supremeValue=135,demand=3,
         stability="Fluctuating",verified=true}
     elseif p=="chroma" and id=="810" then
       return {page=p,id=id,name="Chroma Watergun",supremeValue=2300,
         demand=5,stability="Stable",verified=true}
     end
   end}
 local scanner={
    getOwnInventory=function()return own,nil end,
    getRecord=function()return rec end,
    getVerificationState=function()
       return {player=player,record=rec,scanning=false,retryScheduled=false}
    end}
 local config={scanner=scanner,profile=profile,player=player,
   game=game,jobId="job-verified",session="sess-1",
   clock=function()return clock end,wall=function()return wall end}
 local h=Adapter.new(config)
 local function ready()return Adapter.refreshOwn(h)end
 return {h=h,own=own,their=their,rec=rec,
    scanner=scanner,profile=profile,game=game,player=player,
    ready=ready,mono=function(n)clock=n end,
    wall=function(n)wall=n end,config=config}
end
test("genuine stamped existing scan yields Stage17 exact market/identity",function()
 local f=fixture()
 assert(f.ready()==true)
 local ctx,why=Adapter.build(f.h)
 assert(ctx,why)
 assert(ctx.session=="sess-1" and ctx.market.sourceId=="test-2026-11-05")
 assert(ctx.ownInventory["godly:1031:checker-id"]==1)
 assert(ctx.opponentInventory["chroma:810:checker-id"]==1)
 assert(ctx.rawOwn["godly:1031:checker-id"].id=="Mortal")
 assert(ctx.market.items["godly:1031:checker-id"].valueCents==13500)
 assert(ctx.market.items["godly:1031:checker-id"].stability=="fluctuating")
 assert(ctx.market.items["chroma:810:checker-id"].valueCents==230000)
 assert(ctx.market.items["chroma:810:checker-id"].stability=="stable")
 assert(ctx.scanProvenance=="local-client-stable-read-only")
 assert(ctx.opponentScanSequence==7)
end)
test("scanner record lacking completion stamp is held",function()
 local f=fixture();assert(f.ready())
 f.rec.scanProof=nil
 local v,why=Adapter.build(f.h)
 assert(v==nil and why=="opponent-scan-age-or-identity-unproven")
end)
test("stale opponent record rejected without re-scanning",function()
 local f=fixture();assert(f.ready())
 f.mono(231)
 local v,why=Adapter.build(f.h)
 assert(v==nil and why=="own-scan-stale-or-missing")
 f.mono(225);f.rec.scanProof.completedAtMono=190
 local v2,why2=Adapter.build(f.h)
 assert(v2==nil and why2=="opponent-scan-age-or-identity-unproven")
end)
test("wrong player ID or server ID blocks",function()
 local f=fixture();assert(f.ready())
 f.rec.scanProof.playerUserId=400
 assert(Adapter.build(f.h)==nil)
 f.rec.scanProof.playerUserId=1002
 f.game.JobId="other-server"
 assert(Adapter.build(f.h)==nil)
end)
test("wrong opponent fingerprint blocks",function()
 local f=fixture();assert(f.ready())
 f.their.fingerprint="swapped"
 assert(Adapter.build(f.h)==nil)
end)
test("cannot use current-looking timestamp from different job",function()
 local f=fixture();assert(f.ready())
 f.rec.scanProof.jobId="wrong"
 assert(Adapter.build(f.h)==nil)
end)
test("scan in progress cannot prove completion",function()
 local f=fixture();assert(f.ready())
 f.scanner.getVerificationState=function()return {
   player=f.player,record=f.rec,scanning=true,retryScheduled=false}end
 assert(Adapter.build(f.h)==nil)
end)
test("temporary retry state cannot authorise trade evidence",function()
 local f=fixture();assert(f.ready())
 f.scanner.getVerificationState=function()return {
   player=f.player,record=f.rec,scanning=false,retryScheduled=true}end
 assert(Adapter.build(f.h)==nil)
end)
test("outdated source returns no Stage17 context",function()
 local f=fixture();assert(f.ready())
 f.wall(1800000100)
 assert(Adapter.build(f.h)==nil)
end)
test("changed market version invalidates cached own scan",function()
 local f=fixture();assert(f.ready())
 f.profile.version="new-valuation"
 assert(Adapter.build(f.h)==nil)
end)
test("raw name mismatch against price checker is a hard hold",function()
 local f=fixture();assert(f.ready())
 f.their.items[1].name="Chroma Another Gun"
 assert(Adapter.build(f.h)==nil)
end)
test("ambiguous duplicate canonical ID blocks",function()
 local f=fixture();assert(f.ready())
 f.their.items[2]={}
 for k,v in pairs(f.their.items[1]) do f.their.items[2][k]=v end
 assert(Adapter.build(f.h)==nil)
end)
test("unpriced or unmapped item cannot silently be skipped",function()
 local f=fixture();assert(f.ready())
 f.their.unpriced=1
 assert(Adapter.build(f.h)==nil)
 f.their.unpriced=0;f.their.unmapped=1
 assert(Adapter.build(f.h)==nil)
end)
test("original quantity is not mutated",function()
 local f=fixture();assert(f.ready())
 local c=Adapter.build(f.h)
 assert(c~=nil and f.own.items[1].qty==1
   and f.their.items[1].qty==1)
end)
test("native own read failure never returns yesterday's stock",function()
 local f=fixture();assert(f.ready())
 f.scanner.getOwnInventory=function()return nil,"remote-timeout"end
 assert(Adapter.refreshOwn(f.h)==false)
 assert(Adapter.build(f.h)==nil)
end)
test("a slow own remote response invalidates its scan",function()
 local f=fixture()
 f.scanner.getOwnInventory=function()
   f.mono(210)
   return f.own
 end
 assert(Adapter.refreshOwn(f.h)==false)
 assert(Adapter.build(f.h)==nil)
end)
test("profile copies unknown status are rejected",function()
 local f=fixture();assert(f.ready())
 f.profile.get=function()return {
    page="godly",id="1031",name="Mortal",supremeValue=135,
    demand=3,stability="Mooning",verified=true}end
 assert(Adapter.build(f.h)==nil)
end)
test("missing scanner player identity rejects",function()
 local f=fixture();assert(f.ready())
 f.rec.player={UserId=1002,Parent={}}
 assert(Adapter.build(f.h)==nil)
end)
print("PASS",count,"Stage24 existing-scanner-stamps-to-Stage17-native-context tests")
