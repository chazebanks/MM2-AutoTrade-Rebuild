-- Execute the additive production API; only Players/Live are boundary data.
local path=arg[1] or 'pdiddler/reachability/pdiddler3_scanner_MODULE_v6_9_VERIFICATION_STATE.lua'
local file=assert(io.open(path));local source=file:read('*a');file:close()
local first=assert(source:find('function ScannerAPI.getVerificationState(userId)',1,true),'missing production verification-state API')
local last=assert(source:find('\nfunction ScannerAPI.',first+1,true))
local body=source:sub(first,last-1)
local current={UserId=42,Name='Current'}
local stale={UserId=42,Name='Stale'}
local roster={[42]=current}
local calls=0
local players={GetPlayerByUserId=function(_,id)
 assert(type(id)=='number','UserId must be numeric');calls=calls+1;return roster[id]
end}
local rec={player=stale,state='whitelist',inv={fingerprint='42x1'}}
local live={byUserId={['42']=rec},scanning={},retrying={}}
local scanner={}
local scope=setmetatable({Players=players,Live=live,ScannerAPI=scanner},{__index=_G})
assert(load(body,'@'..path..':getVerificationState','t',scope))()
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end

test('exact current player is distinct from stale record identity',function()
 local result=scanner.getVerificationState(42)
 assert(result.player==current and result.record==rec and result.record.player==stale)
 assert(not result.scanning and not result.retryScheduled)
end)
test('numeric and string UserIds resolve the same scanner key',function()
 local result=scanner.getVerificationState('42')
 assert(result.player==current and result.record==rec)
end)
test('retained whitelist record cannot hide an active scan',function()
 live.scanning['42']=true
 local result=scanner.getVerificationState(42)
 assert(result.scanning and result.record==rec and result.record.state=='whitelist')
 assert(live.scanning['42']==true and live.byUserId['42']==rec)
end)
test('retained blacklist record cannot hide an active scan',function()
 rec.state='blacklist'
 local result=scanner.getVerificationState(42)
 assert(result.scanning and result.record==rec and result.record.state=='blacklist')
end)
test('scheduled retry and scan are independently observable',function()
 live.scanning['42']=nil;live.retrying['42']=true
 local result=scanner.getVerificationState(42)
 assert(not result.scanning and result.retryScheduled)
 assert(live.retrying['42']==true)
end)
test('departed player does not inherit a stale record identity',function()
 roster[42]=nil
 local result=scanner.getVerificationState(42)
 assert(result.player==nil and result.record==rec)
end)
test('new player without a record remains observable without inventing data',function()
 local player={UserId=43};roster[43]=player
 local result=scanner.getVerificationState(43)
 assert(result.player==player and result.record==nil and not result.scanning and not result.retryScheduled)
end)
test('invalid UserId does not call native player lookup',function()
 local before=calls;local result=scanner.getVerificationState('invalid')
 assert(result.player==nil and result.record==nil and calls==before)
end)
print('TOTAL '..n..' scanner verification-state tests')
