local file=assert(io.open('pdiddler/tests/v10_teleport_autoexec_test.lua'))
local source=file:read('*a');file:close()
source=source:gsub('V10','V15_2'):gsub('58c9aede108b60278b9baa9dd7da73f7a4d95ac5','612d18cd5351ac2e75989b57bb47351d8072948f')
source=source..[[
for _,key in ipairs({'PDIDDLER_V13_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V13_VISIBLE_READINESS'}) do
 test('preservedV13 owner prevents V15_2 queue '..key,function()
  local m=mock({queueMode='direct'});local old={jobId='job-1',started=true,running=true};m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
test('runtime endpoint never enters queued code or console output',function()
 local m=mock({queueMode='direct'});local private='runtime-private-value'
 m.env.PDIDDLER_DISCORD_WEBHOOK_URL=private;m:run()
 assert(not m.queue[1]:find(private,1,true),'runtime credential copied to executor queue')
 for _,line in ipairs(m.prints) do assert(not line:find(private,1,true)) end
 for _,line in ipairs(m.warnings) do assert(not line:find(private,1,true)) end
 local next=mock({queueMode='direct',job='job-2'});next:run(m.queue[1])
 assert(next.env.PDIDDLER_DISCORD_WEBHOOK_URL==nil)
end)

for _,key in ipairs({'PDIDDLER_V10_TELEPORT_AUTOBOOT_v1','PDIDDLER_V11_TELEPORT_AUTOBOOT_v1',
 'PDIDDLER_V12_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS',
 'PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER'}) do
 test('preserved owner '..key..' prevents V15_2 queue or probe',function()
  local m=mock({queueMode='direct'})
  local old={jobId='job-1'}
  if key:find('INTEGRATION',1,true) then old.running=true else old.started=true end
  m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
test('dirty V12 integration prevents V15_2 even after a partial launch',function()
 local m=mock({queueMode='direct'});local old={jobId='job-1',dirty=true}
 m.env.PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER=old
 assert(m:run()==old and #m.queue==0 and #m.fetches==0)
end)
test('independent P5 owner prevents another bootstrap queue',function()
 local m=mock({queueMode='direct'});m.env.PDIDDLER_PART5_CONTROLLER={}
 m:run();assert(#m.queue==0 and #m.fetches==0)
end)
for _,mode in ipairs({'throw','return'}) do
 test('private configuration never appears in queue '..mode..' failure',function()
  local m=mock({queueMode='direct'});local private='private-runtime-credential'
  m.env.PDIDDLER_DISCORD_WEBHOOK_URL=private
  m.sandbox.queue_on_teleport=function(source)
   if mode=='throw' then error('failed '..private..source) end
   return false,'failed '..private..source
  end
  m:run()
  for _,line in ipairs(m.warnings) do assert(not line:find(private,1,true),'queue failure leaked credential') end
 end)
end
for _,key in ipairs({'PDIDDLER_V14_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V14_VERIFIED_WORKFLOW'}) do
 test('active V14 blocks V15_2 '..key,function()
  local m=mock({queueMode='direct'});local old={jobId='job-1',started=true,running=true};m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
for _,key in ipairs({'PDIDDLER_V15_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_OPPONENT_ADDED'}) do
 test('old V15 blocks price refresh owner '..key,function()
  local m=mock({queueMode='direct'});local old={jobId='job-1',started=true,running=true};m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
for _,key in ipairs({'PDIDDLER_V15_1_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES'}) do
 test('V15.1 predecessor prevents GUI build queue '..key,function()
  local m=mock({queueMode='direct'});local old={jobId='job-1',started=true,running=true};m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
print('TOTAL '..tests..' V15_2 teleport tests')
]]
assert(load(source,'v13-bootstrap-contract','t',_G))()
