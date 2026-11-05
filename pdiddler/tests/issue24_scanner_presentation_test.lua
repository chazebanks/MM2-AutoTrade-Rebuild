-- Actual scanner formatting/row bridge and GUI rendering; only Instance/storage boundaries supplied.
local path=arg[1] or 'pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua'
local file=assert(io.open(path));local source=file:read('*a');file:close()
local function span(a,b) return source:sub(assert(source:find(a,1,true)),assert(source:find(b,1,true))-1) end
local code=span('local function guiSetSummary(', 'local function rowColor(')
 ..span('local function rowColor(', '\ncreateGui()')
 ..span('local function fmtValue(', 'local Live = {')
 ..span('local ScannerAPI={}', 'local OwnInventoryGate={')
 ..span('function ScannerAPI.restoreWhitelist(', source:find('-- Scanner refreshes can redraw',1,true) and '-- Scanner refreshes can redraw' or '-- One presentation owner')
 ..span('local function applyPlayerResult(', 'scheduleUnknownRetry = function(')
code=code..span('scanPlayerLive = function(', '\n-- Attach live listeners')
code=code:gsub('([%w_%.]+)%s*%+=%s*','%1=%1+')
local parse=dofile('pdiddler/tests/issue24_scanner_fixture.lua')({
 Immortal={ItemName='Immortal',ItemType='Knife',Rarity='Godly'},
 Embersickle={ItemName='Embersickle',ItemType='Knife',Rarity='Godly'},
})
local P=dofile('pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
local snap=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
local viewFile=io.open('pdiddler/presentation/pdiddler3_scanner_view_v1.lua')
local V=viewFile and dofile('pdiddler/presentation/pdiddler3_scanner_view_v1.lua') or {};if viewFile then viewFile:close() end
local passed,failed=0,0
local function test(name,fn) local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end end
local function fixture(owned,state)
 local f={};f.players={};f.p={UserId=2,Name='Target',DisplayName='Target',Parent=f.players}
 f.profile={};for k,v in pairs(snap) do f.profile[k]=v end
 f.profile.isFresh=function() return not f.expired and snap.isFresh(snap.observedAtEpoch) end
 f.inv=parse({Weapons={Owned=owned or {}}})
 f.live={scanning={},retrying={},retryCount={},byUserId={['2']={player=f.p,state=state or 'whitelist',inv=f.inv}},order={['2']=1},white=state=='blacklist' and 0 or 1,black=state=='blacklist' and 1 or 0,unknown=0}
 f.label={Text='',LayoutOrder=1,FindFirstChild=function() return nil end}
 f.gui={list=true,rows={['2']=f.label},rowRenderCache={},summary={Text=''},summaryRenderCache=nil}
 local scope=setmetatable({GUI=f.gui,Live=f.live,Players=f.players,DISPLAY_PROFILE=f.profile,DISPLAY_POLICY=P,DISPLAY_VIEW=V,EconomicSummary=nil,
  ENV={},waitForScannerWindow=function() return true end,trackedCount=function() return 1 end,scanOne=function() f.duringScan=f.label.Text;return 'whitelist',f.inv end,getOrder=function() return 1 end,recount=function() end,print=function() end,Color3={fromRGB=function(r,g,b) return r+g+b end},guiSetStatus=function() return false end},{__index=_G})
 f.api,f.helpers=assert(load(code..'\nreturn ScannerAPI,{summary=guiSetSummary,items=eligibleSummary,base=scannerApiBaseText,apply=applyPlayerResult,scan=scanPlayerLive}','@'..path,'t',scope))()
 function f:outgoing(state,reason)
  if self.api.setOutgoingState then self.api.setOutgoingState(self.p,state,reason)
  else self.api.setRequestState(self.p,state=='reachable' and 'whitelist' or 'unknown','Outgoing: '..state..' | '..reason) end
 end
 return f
end
test('own-proof pending preserves verified BLACKLIST heading and exposes economic reason separately',function()
 local f=fixture({},'blacklist');f:outgoing('unknown','own-proof-pending')
 assert(f.label.Text:find('[BLACKLIST]',1,true),f.label.Text)
 assert(f.label.Text:find('Own proof pending',1,true),f.label.Text)
 assert(f.live.byUserId['2'].state=='blacklist')
end)
test('scanner base and initial item formatter show canonical current Immortal135 and Embersickle95',function()
 local f=fixture({Immortal=1,Embersickle=1});local initial=f.helpers.items(f.inv)
 assert(initial:find('135',1,true) and initial:find('95',1,true),initial)
 f.api.setRequestState(f.p,'requesting','native request pending')
 assert(f.label.Text:find('135',1,true) and f.label.Text:find('95',1,true),f.label.Text)
 assert(not f.label.Text:find('(140)',1,true) and not f.label.Text:find('(80)',1,true))
 assert(f.inv.total==220 and f.inv.items[1].value==140,'raw scanner input mutated')
end)
test('economic pause cannot overwrite REQUESTING or PROCESSED request state',function()
 local f=fixture({Immortal=1})
 for _,state in ipairs({'requesting','processed'}) do
  f.api.setRequestState(f.p,state,'native request state')
  f:outgoing('unknown','own-proof-paused:pending-request')
  assert(f.label.Text:find('['..state:upper()..']',1,true),f.label.Text)
  assert(f.label.Text:find('Paused',1,true) or f.label.Text:find('paused',1,true),f.label.Text)
 end
end)
test('a rescan result published after a request starts preserves request and outgoing fields atomically',function()
 local f=fixture({Immortal=1});f.api.setRequestState(f.p,'requesting','native pending')
 f:outgoing('unknown','own-proof-paused:pending-request')
 f.helpers.apply(f.p,'whitelist',f.inv)
 assert(f.label.Text:find('[REQUESTING]',1,true) and f.label.Text:find('Outgoing:',1,true),f.label.Text)
end)
test('raw rarity and outgoing counts are separately labeled',function()
 local f=fixture({},'blacklist')
 if f.api.setOutgoingSummary then f.api.setOutgoingSummary({reachable=1,unprofitable=2,unknown=3}) else f.helpers.summary(0,1,0) end
 assert(f.gui.summary.Text:find('Blacklist 1',1,true) and f.gui.summary.Text:find('Unknown 0',1,true),f.gui.summary.Text)
 assert(f.gui.summary.Text:find('Outgoing',1,true) and f.gui.summary.Text:find('3',1,true),f.gui.summary.Text)
end)
test('periodic repaint reflects price expiry without changing raw eligibility or request ownership',function()
 local f=fixture({Immortal=1});f.api.setRequestState(f.p,'processed','attempt finished');f:outgoing('reachable','verified-feasible-witness')
 f.api.setOutgoingSummary({reachable=1,unprofitable=0,unknown=0})
 f.expired=true
 if f.api.refreshPresentation then f.api.refreshPresentation() else f.api.setRequestState(f.p,'processed','attempt finished') end
 assert(not f.label.Text:find('(140)',1,true) and not f.label.Text:find('(135)',1,true),f.label.Text)
 assert(f.label.Text:lower():find('expired',1,true) or f.label.Text:find('UNAVAILABLE',1,true),f.label.Text)
 assert(f.label.Text:find('[PROCESSED]',1,true) and f.live.byUserId['2'].state=='whitelist')
 assert(not f.label.Text:find('Outgoing: REACHABLE',1,true),f.label.Text)
 assert(f.gui.summary.Text:lower():find('expired',1,true) and not f.gui.summary.Text:find('Reachable 1',1,true),f.gui.summary.Text)
end)
test('clearing request state restores rarity heading with current economic detail',function()
 local f=fixture({Immortal=1});f:outgoing('reachable','verified-feasible-witness');f.api.setRequestState(f.p,'requesting','pending')
 f.api.clearRequestState(f.p)
 assert(f.label.Text:find('[WHITELIST]',1,true) and f.label.Text:find('Outgoing',1,true),f.label.Text)
end)
test('periodic scan startup preserves processed request heading during inventory RPC',function()
 local f=fixture({Immortal=1})
 f.api.setRequestState(f.p,'processed','attempt finished')
 f:outgoing('unknown','own-proof-pending')
 f.helpers.scan(f.p,'periodic')
 assert(f.duringScan:find('[PROCESSED]',1,true),f.duringScan)
 assert(f.duringScan:find('Outgoing:',1,true),f.duringScan)
end)
assert(failed==0,tostring(failed)..' presentation cases failed');print('TOTAL '..passed..' actual scanner presentation cases')
