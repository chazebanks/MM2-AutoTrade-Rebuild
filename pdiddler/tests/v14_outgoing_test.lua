local file=assert(io.open('pdiddler/tests/outgoing_v16_test.lua'));local src=file:read('*a');file:close()
src=src:gsub('pdiddler3_outgoing_ROTATING_v16_EXACT_IDENTITY.lua','pdiddler3_outgoing_ROTATING_v17_TRANSACTION_LEASE.lua')
src=src:gsub('os%.exit%(failed==0 and 0 or 1%)','')
src=src..[[
test('outcome ownership survives trade GUI disappearance in outgoing guards',function()
 local f=fixture();f.scope.scanner=f.scanner
 f.scanner.hasActiveTradeLifecycle=function() return true end
 local h=compileHelpers(f,true);assert(h.tradeOpen()==true)
 local player=f:add('Exact_User');assert(h.tradeBelongsTo(player)==nil)
 f.scanner.hasActiveTradeLifecycle=function() return false end
 assert(not h.tradeOpen())
end)
test('unreadable lifecycle never grants outgoing permission',function()
 local f=fixture();f.scope.scanner=f.scanner
 f.scanner.hasActiveTradeLifecycle=function() error('unavailable') end
 assert(compileHelpers(f,true).tradeOpen()==true)
end)
assert(failed==0);print('TOTAL '..passed..' V14 outgoing tests')
]]
assert(load(src,'v17-outgoing-contract','t',_G))()
