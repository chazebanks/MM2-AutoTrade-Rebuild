local file=assert(io.open('pdiddler/tests/v10_teleport_autoexec_test.lua'))
local source=file:read('*a');file:close()
source=source:gsub('V10','V13'):gsub('58c9aede108b60278b9baa9dd7da73f7a4d95ac5','3ba20eeade3fdeca08d58bc53c836ec36d0b1eec')
source=source..[[
for _,key in ipairs({'PDIDDLER_V10_TELEPORT_AUTOBOOT_v1','PDIDDLER_V11_TELEPORT_AUTOBOOT_v1',
 'PDIDDLER_V12_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS',
 'PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER'}) do
 test('preserved owner '..key..' prevents V13 queue or probe',function()
  local m=mock({queueMode='direct'})
  local old={jobId='job-1'}
  if key:find('INTEGRATION',1,true) then old.running=true else old.started=true end
  m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
test('dirty V12 integration prevents V13 even after a partial launch',function()
 local m=mock({queueMode='direct'});local old={jobId='job-1',dirty=true}
 m.env.PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER=old
 assert(m:run()==old and #m.queue==0 and #m.fetches==0)
end)
test('independent P5 owner prevents another bootstrap queue',function()
 local m=mock({queueMode='direct'});m.env.PDIDDLER_PART5_CONTROLLER={}
 m:run();assert(#m.queue==0 and #m.fetches==0)
end)
print('TOTAL '..tests..' V13 teleport tests')
]]
assert(load(source,'v13-bootstrap-contract','t',_G))()
