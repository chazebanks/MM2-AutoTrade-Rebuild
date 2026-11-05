-- Preserve complete outgoing/clock/ownership loader suite and add presentation binding regressions.
local file=assert(io.open('pdiddler/tests/issue24_loader_test.lua'));local source=file:read('*a');file:close()
local path=arg[1] or 'pdiddler/pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_5_SCANNER_EVIDENCE.lua'
-- The predecessor's row-relabel assertion intentionally describes the bug fixed here;
-- replace that one test with explicit raw-rarity/outgoing/request separation below.
local oldRowTest="test('scanner rows distinguish reachable unprofitable and unknown with reasons',function()"
local oldStart=source:find(oldRowTest,1,true)
if oldStart then
 local oldEnd=assert(source:find("\ntest(",oldStart+#oldRowTest,true))
 source=source:sub(1,oldStart-1)..source:sub(oldEnd+1)
end

source=source:gsub("local path=arg%[1%] or '[^']+'",function() return 'local path='..string.format('%q',path) end)
source=source:gsub(" Luger={ItemName='Luger',Rarity='Godly',ItemType='Gun'},", " Luger={ItemName='Luger',Rarity='Godly',ItemType='Gun'},\n Immortal={ItemName='Immortal',Rarity='Godly',ItemType='Knife'},\n Embersickle={ItemName='Embersickle',Rarity='Godly',ItemType='Knife'},")
local needle=' return f\nend\n\ntest('
local setup=[=[
 local function loadActual(name)
  local input=assert(io.open('pdiddler/'..name));local code=input:read('*a');input:close()
  return assert(load(code,'@'..name,'t',f.scope))()
 end
 for _,name in ipairs({'presentation/pdiddler3_scanner_view_v1.lua','pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua'}) do
  local filename=name
  f.sources[filename:match('([^/]+)$')]=function() return loadActual(filename) end
 end
 f.requestStateCalls={};f.outgoingStates={};f.requestStates={};f.displayRows={};f.presentationRefreshes=0
 local function repaint(p)
  if not f.boundView then return end
  local state,detail=f.boundView.row(f.records[p.UserId],f.outgoingStates[p.UserId],f.requestStates[p.UserId],f.profile,f.boundPolicy)
  f.displayRows[p.UserId]={state=state,detail=detail}
 end
 f.scanner.setRequestState=function(p,state,extra)
  f.requestStateCalls[#f.requestStateCalls+1]={player=p,state=state,extra=extra}
  f.requestStates[p.UserId]={state=state,extra=extra};repaint(p)
 end
 f.scanner.setOutgoingState=function(p,state,reason)
  f.outgoingStates[p.UserId]={state=state,reason=reason};repaint(p)
 end
 f.scanner.setOutgoingSummary=function(counts)
  f.summaryCounts=counts
  if f.boundView then
   local w,b,u=0,0,0
   for _,p in ipairs(f.roster) do if p~=f.lp then
    local rec=f.records[p.UserId]
    if rec and rec.state=='whitelist' then w=w+1 elseif rec and rec.state=='blacklist' then b=b+1 else u=u+1 end
   end end
   f.summaryText=f.boundView.summary(w,b,u,counts)
  end
 end
 f.scanner.refreshPresentation=function()
  f.presentationRefreshes=f.presentationRefreshes+1
  for _,p in ipairs(f.roster) do if p~=f.lp then repaint(p) end end
 end
 local scannerBoundary=f.sources['pdiddler3_scanner_MODULE_v6_9_VERIFICATION_STATE.lua']
 f.sources['pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua']=function(profile,strict,view)
  assert(profile==f.profile,'scanner did not receive current profile before execution')
  assert(strict==f.controller.strict and type(strict.reprice)=='function','scanner strict policy binding missing')
  assert(view==f.controller.scannerView and type(view.inventory)=='function' and type(view.row)=='function','scanner view binding missing')
  f.boundView=view;f.boundPolicy=strict;f.initialRows={}
  for _,p in ipairs(f.roster) do if p~=f.lp then
   f.initialRows[p.UserId]=view.inventory(f.records[p.UserId] and f.records[p.UserId].inv,profile,strict)
   repaint(p)
  end end
  return scannerBoundary()
 end
 return f
end

test(]=]
local point=assert(source:find(needle,1,true));source=source:sub(1,point-1)..setup..source:sub(point+#needle)
local extra=[=[
test('scanner executes with current profile strict policy and view before its initial rows',function()
 local f=fixture();local p=f:target(2,{Immortal=1,Embersickle=1});f:run(path);f:advance(20);f:check()
 local initial=assert(f.initialRows and f.initialRows[p.UserId],'initial scanner profile/view binding absent')
 assert(initial.totalText=='230' and initial.priceState=='current',initial.detail)
 assert(initial.itemsText:find('135',1,true) and initial.itemsText:find('95',1,true),initial.detail)
 assert(not initial.itemsText:find('(140)',1,true) and not initial.itemsText:find('(80)',1,true),initial.detail)
 assert(f.records[p.UserId].inv.total==220,'raw source inventory was repriced in place')
end)
test('own proof pending never repaints rarity blacklist as UNKNOWN',function()
 local f=fixture();local p=f:target(2,{},'blacklist');f.ownUnavailable=true
 f:run(path);f:advance(20);f:check()
 local row=assert(f.displayRows[p.UserId],'separate economic display was not updated')
 assert(row.state=='blacklist' and row.detail:find('Inventory rarity: BLACKLIST',1,true),row.detail)
 assert(row.detail:find('Own proof pending',1,true) or row.detail:find('no-eligible',1,true),row.detail)
 assert(#f.requestStateCalls==0,'economic assessment wrote request status')
end)
test('economic refresh never writes request state or overrides an active request header',function()
 local f=fixture();local p=f:target(2,{Immortal=1});f:run(path);f:advance(20);f:check()
 assert(#f.requestStateCalls==0,'loader economics used setRequestState')
 f.scanner.setRequestState(p,'requesting','native pending request')
 f.ownUnavailable=true;f.controller.eligibility:invalidate();f:advance(25)
 local row=assert(f.displayRows[p.UserId]);assert(row.state=='requesting',row.detail)
 assert(#f.requestStateCalls==1,'economic repaint replaced native request state')
 assert(row.detail:find('Inventory rarity: WHITELIST',1,true),row.detail)
end)
test('outgoing summary counts remain distinct from raw rarity counts through global holds',function()
 local f=fixture();f:target(2,{Immortal=1});f:target(3,{Seer=1});f:target(4,{},'blacklist')
 f:run(path);f:advance(20);f:check();local counts=assert(f.summaryCounts,'outgoing summary bridge not called')
 assert(counts.reachable==1 and counts.unprofitable==2 and counts.unknown==0)
 assert(f.summaryText:find('Whitelist 2',1,true) and f.summaryText:find('Blacklist 1',1,true),f.summaryText)
 assert(f.summaryText:find('Outgoing (unprocessed)',1,true),f.summaryText)
 f.p4.state.active=true;f:advance(25)
 counts=assert(f.summaryCounts);assert(counts.reachable==0 and counts.unprofitable==1 and counts.unknown==2,
  'global hold lost zero-inventory proof or froze economic counts')
 assert(f:count('hop')==0)
 f.out.state.processed[3]='ignored';f:advance(26)
 counts=assert(f.summaryCounts)
 assert(counts.unprofitable==1 and counts.unknown==1,'processed player remained in outgoing unprocessed summary')
 assert(f.summaryText:find('Whitelist 2',1,true),'processing incorrectly changed raw rarity summary')
end)
test('bound scanner presentation reflects profile expiry without fallback to legacy prices',function()
 local f=fixture();local p=f:target(2,{Immortal=1,Embersickle=1});f:run(path);f:advance(20);f:check()
 f.expired=true;f:advance(25);f.scanner.refreshPresentation()
 local row=assert(f.displayRows[p.UserId]);assert(not row.detail:find('(135)',1,true) and not row.detail:find('(140)',1,true),row.detail)
 assert(row.detail:find('expired',1,true),row.detail)
 assert(f.controller.stage=='PRICE_HOLD' and f:count('hop')==0)
end)
test('expired own proof cannot authorize a click while display preserves raw rarity',function()
 local f=fixture();local p=f:target(2,{Immortal=1});f:run(path);f:advance(20);f:check()
 f.ownUnavailable=true;f:advance(36)
 local token,why=f.tradingScanner.authorizeOutgoing(p)
 assert(not token,'stale own proof authorized outgoing click')
 local row=assert(f.displayRows[p.UserId]);assert(row.state=='whitelist',row.detail)
 assert(row.detail:find('Own proof pending',1,true) or row.detail:find('verification-unavailable',1,true),row.detail)
end)
test('active V15.4 predecessor refuses new scanner display and controller initialization',function()
 local f=fixture();local old={jobId='job',running=true};f.env.PDIDDLER_INTEGRATION_V15_4_REACHABLE=old
 assert(f:run(path)==old);f:advance(20)
 assert(f:count('p2')==0 and f.scannerLoads==nil and #f.guiCreated==0)
end)
]=]
local ending="assert(failed==0,tostring(failed)..' loader cases failed')"
local position=assert(source:find(ending,1,true));source=source:sub(1,position-1)..extra..source:sub(position)
assert(load(source,'actual-scanner-evidence-loader-tests','t',_G))()
