local E=dofile('pdiddler/pdiddler3_outgoing_eligibility_v1.lua')
local F=dofile('pdiddler/pdiddler3_feasibility_v1.lua')
local P=dofile('pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
local snapshot=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
local parse=dofile('pdiddler/tests/issue24_scanner_fixture.lua')({
 Seer={ItemName='Seer',Rarity='Godly',ItemType='Knife'},Boneblade={ItemName='Boneblade',Rarity='Godly',ItemType='Knife'},
 Batwing={ItemName='Batwing',Rarity='Ancient',ItemType='Knife'},Luger={ItemName='Luger',Rarity='Godly',ItemType='Gun'},
})
-- Actual outgoing physicalTap; only input/coordinate/executor boundaries are substituted.
local sourceFile=assert(io.open(arg[1] or 'pdiddler/pdiddler3_outgoing_ROTATING_v18_REACHABLE.lua'))
local inputSource=sourceFile:read('*a');sourceFile:close()
local first=assert(inputSource:find('    local function physicalTap(',1,true))
local last=assert(inputSource:find('\n    end',first,true))
local tapSource=inputSource:sub(first,last+7)..'\nreturn physicalTap'
local function input(guard,change)
 local clicks=0
 local scope=setmetatable({alive=function() return true end,visible=function() return true end,
  correctedCenter=function() if change then change() end;return 10,10 end,
  VIM={SendMouseButtonEvent=function(_,_,_,_,down) if down then clicks=clicks+1 end end},
  task={wait=function() end},print=function() end,game={}},{__index=_G})
 local tap=assert(load(tapSource,'actual-outgoing-input','t',scope))()
 local ok,why=tap({Name='Trade'},'Trade',guard)
 return clicks,ok,why
end
local n=0;local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function fixture()
 local f={now=0,reads=0,rows={},players={},rendered={}}
 f.p={UserId=2,Name='Target'};f.players={f.p}
 f.own=parse({Weapons={Owned={Boneblade=1}}});f.rows[2]={player=f.p,state='whitelist',inv=parse({Weapons={Owned={Batwing=1}}})}
 f.ctx={job='job',gui={},outgoing={},session=1,part4Session=1,phase='idle',allowed=true}
 f.profile={};for k,v in pairs(snapshot) do f.profile[k]=v end
 f.profile.isFresh=function() return not f.expired end
 f.scanner={getVerificationState=function(uid) return {player=f.p,record=f.rows[uid],scanning=f.scanning or false} end}
 f.e=E.new({scanner=f.scanner,profile=f.profile,strict=P,feasibility=F,now=function() return f.now end,
 context=function() return f.ctx end,readOwn=function() f.reads=f.reads+1;if f.onRead then f.onRead() end;return f.own,f.readError end,
 render=function(p,state,reason) f.renderCalls=(f.renderCalls or 0)+1;if f.suppressRender then return false end;f.rendered[p]={state,reason} end})
 function f:refresh() return self.e:refresh(true) end
 function f:queue(processed) return self.e:queue(self.players,processed or {}) end
 return f
end
test('unknown deadline is fixed despite fingerprint churn and scanner retries',function()
 local f=fixture();f.scanning=true;assert(f:queue().verificationPending)
 f.now=29;f.rows[2].inv.fingerprint='changed';assert(f:queue().verificationPending)
 f.now=30;local q=f:queue();assert(q.exhausted and not q.verificationPending)
 local a=f.e:assess(f.p);assert(a.state=='unknown' and a.reason=='verification-unavailable' and a.cause=='inventory-scan-active')
 f.now=300;assert(f:queue().exhausted and f.rendered[f.p][1]=='unknown')
end)
test('classification suppressed during an active request is rendered when request ownership releases',function()
 local f=fixture();f:refresh();f.suppressRender=true;f.e:assess(f.p);assert(not f.rendered[f.p])
 f.suppressRender=false;f.e:assess(f.p);assert(f.rendered[f.p] and f.rendered[f.p][1]=='reachable')
end)
test('own read retry offsets and no catch-up bursts are bounded',function()
 local f=fixture();f.own=nil
 for _,at in ipairs({0,1,4,5,6,14,15,16,29,30,44,45,46,89,90}) do f.now=at;f.e:refresh(false) end
 assert(f.reads==5,tostring(f.reads))
 local g=fixture();g.own=nil;g.now=0;g.e:refresh(false);g.now=100;g.e:refresh(false);g.e:refresh(false);assert(g.reads==2)
end)
test('fingerprinted partial own inventories retain bounded retry schedule',function()
 local f=fixture();f.own.unmapped=1
 for _,at in ipairs({0,1,4,5,6,14,15,16,29,30,44,45,46,89,90}) do f.now=at;f.e:refresh(false) end
 assert(f.reads==5,tostring(f.reads));assert(f.e:assess(f.p).state=='unknown')
end)
test('failed own read ages out only inventory uncertainty, never global protection',function()
 local f=fixture();f.own=nil;f.e:refresh(false);assert(f:queue().verificationPending)
 f.now=30;assert(f:queue().exhausted)
 for _,reason in ipairs({'price-expired','readiness','transaction-owned','pending-request'}) do
  f.ctx.allowed=false;f.ctx.reason=reason;f.now=1000
  local q=f:queue();assert(not q.exhausted and q.globalHold==reason)
 end
end)
test('processed players and stale player instances cannot block exhaustion',function()
 local f=fixture();f.scanning=true;assert(f:queue({[2]='ignored'}).exhausted)
 f.players={};assert(f:queue().exhausted)
end)
test('late authoritative reachability restores requests but identical cache recovery is not discovery',function()
 local f=fixture();f:refresh();f.rows[2].inv=parse({Weapons={Owned={Seer=1}}})
 assert(f:queue().exhausted);f.rows[2].inv=parse({Weapons={Owned={Batwing=1}}})
 local q=f:queue();assert(q.available and q.discovered)
 assert(not f:queue().discovered)
 f.e:invalidate();assert(f.e:assess(f.p).state=='unknown');f:refresh();assert(not f:queue().discovered)
 f.now=12;assert(f.e:assess(f.p).state=='unknown');f:refresh();assert(not f:queue().discovered)
end)
test('proof binds exact target and inventories across fresh own read and final nonyielding check',function()
 local f=fixture();f:refresh();local token=assert(f.e:authorize(f.p));local guard=assert(f.e:prepare(f.p,token))
 assert(guard());f.ctx.transaction={};assert(not guard())
end)
for _,change in ipairs({
 {'user id',function(f) f.p.UserId=3 end},
 {'exact player',function(f) f.p={UserId=2,Name='Target'} end},
 {'opponent fingerprint',function(f) f.rows[2].inv.fingerprint='changed' end},
 {'own inventory',function(f) f.own=parse({Weapons={Owned={Luger=1}}});f:refresh() end},
 {'JobId',function(f) f.ctx.job='new' end},
 {'GUI',function(f) f.ctx.gui={} end},
 {'outgoing owner',function(f) f.ctx.outgoing={} end},
 {'outgoing generation',function(f) f.ctx.session=2 end},
 {'P4 generation',function(f) f.ctx.part4Session=2 end},
 {'transaction owner',function(f) f.ctx.transaction={} end},
 {'transaction phase',function(f) f.ctx.phase='negotiating' end},
 {'price version',function(f) f.profile.version='changed' end},
 {'price freshness',function(f) f.expired=true end},
 {'active scan',function(f) f.scanning=true end},
 {'own read expiry',function(f) f.now=11 end},
}) do test('final click guard rejects '..change[1],function()
 local f=fixture();f:refresh();local token=assert(f.e:authorize(f.p));local guard=assert(f.e:prepare(f.p,token));local clicks,ok,why=input(guard,function() change[2](f) end);assert(clicks==0 and not ok and why=='eligibility-abort','unsafe mouse-down or incorrect abort')
end) end
test('unchanged final input proof permits exactly one mouse-down',function()
 local f=fixture();f:refresh();local token=assert(f.e:authorize(f.p));local guard=assert(f.e:prepare(f.p,token));local clicks,ok=input(guard);assert(clicks==1 and ok)
end)
test('own refresh result is discarded if a transaction starts during yielding read',function()
 local f=fixture();f.onRead=function() f.ctx.transaction={} end
 assert(not f:refresh());assert(f.e:assess(f.p).state=='unknown')
end)
test('prepare rejects failed read and changed ownership without making a new token',function()
 local f=fixture();f:refresh();local token=assert(f.e:authorize(f.p));f.own=nil
 assert(not f.e:prepare(f.p,token))
 local g=fixture();g:refresh();token=assert(g.e:authorize(g.p));g.onRead=function() g.ctx.allowed=false;g.ctx.reason='transaction-owned' end
 assert(not g.e:prepare(g.p,token))
end)
test('45 seconds counts only exhausted time and discoveries reset it',function()
 local c=E.clock(0)
 assert(not c:step(20,{exhausted=false}));assert(not c:step(30,{exhausted=true}))
 assert(not c:step(74.99,{exhausted=true}));assert(c:step(75,{exhausted=true}))
 assert(not c:step(76,{available=true,discovered=true}));assert(not c:step(80,{exhausted=true}))
 assert(c:step(125,{exhausted=true}))
end)
print('TOTAL '..n..' eligibility tests')
