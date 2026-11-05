-- Run preserved identity/ownership tests plus actual scanner→planner→queue reproductions.
local file=assert(io.open('pdiddler/tests/outgoing_v16_test.lua'));local src=file:read('*a');file:close()
local path=arg[1] or 'pdiddler/pdiddler3_outgoing_ROTATING_v18_REACHABLE.lua'
src=src:gsub('local path=arg%[1%] or [^\n]+',function() return 'local path='..string.format('%q',path) end)
src=src:gsub('os%.exit%(failed==0 and 0 or 1%)','')
-- Existing identity tests exercise queue mechanics with explicitly reachable targets.
src=src:gsub('f.scanner={getWhitelist=',"f.scanner={getOutgoingEligibility=function() return 'reachable' end,refreshOutgoingInventory=function() end,authorizeOutgoing=function() return {} end,prepareOutgoing=function() return function() return true end end,getWhitelist=")
src=src..[==[
local parse=dofile('pdiddler/tests/issue24_scanner_fixture.lua')({
 Seer={ItemName='Seer',Rarity='Godly',ItemType='Knife'},
 Boneblade={ItemName='Boneblade',Rarity='Godly',ItemType='Knife'},
 Batwing={ItemName='Batwing',Rarity='Ancient',ItemType='Knife'},
 Luger={ItemName='Luger',Rarity='Godly',ItemType='Gun'},
})
local P=dofile('pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
local snapshot=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
local historical={};for k,v in pairs(snapshot) do historical[k]=v end
historical.isFresh=function() return snapshot.isFresh(snapshot.observedAtEpoch) end
local function inv(owned) return P.reprice(parse({Weapons={Owned=owned}}),historical) end
local ours=inv({Boneblade=1})
local function wire(f)
 f.scanner.getOutgoingEligibility=function(p)
  local theirs=inv(f.records[p.UserId].owned)
  return dofile('pdiddler/pdiddler3_feasibility_v1.lua').evaluate(ours,theirs,historical,P)
 end
end
test('Seer3 is skipped by actual P3 rotation after actual scanner and planner verify no +15 plan',function()
 local f=fixture();local seer=f:add('allykyli45');f.records[seer.UserId].owned={Seer=1};wire(f)
 local their=inv({Seer=1});eq(their.total,3);eq(ours.total,7)
 local c=compileConsumer(f).run(f.scanner)
 eq(c.testNext(),nil);eq(c.state.processed[seer.UserId],nil)
end)
test('rotation skips Seer3 and chooses Batwing42 plus Luger18 without processing the skip',function()
 local f=fixture();local low=f:add('allykyli45');local rich=f:add('Keongot_motion350')
 f.records[low.UserId].owned={Seer=1};f.records[rich.UserId].owned={Batwing=1,Luger=1};wire(f)
 local c=compileConsumer(f).run(f.scanner);eq(c.testNext(),rich);eq(c.state.processed[low.UserId],nil)
 c.testMark(rich,'ignored');eq(c.testNext(),nil)
 f.records[low.UserId].owned={Batwing=1};eq(c.testNext(),low)
 c.testMark(low,'uncertain-timeout');f.records[low.UserId].owned={Batwing=2};eq(c.testNext(),nil)
end)
test('target becoming unreachable during yielding card navigation is not tapped',function()
 local f=fixture();local p=f:add('Changed');local state='reachable';local taps=0
 f.scanner.getOutgoingEligibility=function() return state end
 f.scanner.prepareOutgoing=function() state='unprofitable';return nil end
 f.scope.testButton=node('Trade','TextButton');f.scope.testCard=node('Card','Frame')
 f.scope.visible=function() state='unprofitable';return true end
 f.scope.testTap=function() taps=taps+1;return true end
 f.scope.task.wait=function(t) f.now=f.now+t end
 local c=compileConsumer(f,true).run(f.scanner)
 c.testSend(p);eq(taps,0);eq(c.state.processed[p.UserId],nil)
end)
assert(failed==0,tostring(failed)..' failed');print('TOTAL '..passed..' Issue24 outgoing tests')
]==]
assert(load(src,'issue24-production-outgoing','t',_G))()
