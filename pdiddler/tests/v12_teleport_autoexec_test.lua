local file=assert(io.open('pdiddler/tests/v10_teleport_autoexec_test.lua'))
local source=file:read('*a');file:close()
source=source:gsub('V10','V12'):gsub('58c9aede108b60278b9baa9dd7da73f7a4d95ac5','8bd4fd7f08301ae2752ed67bfa013d4302f6cb9a')
source=source..[[
for _,key in ipairs({'PDIDDLER_V10_TELEPORT_AUTOBOOT_v1','PDIDDLER_V11_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS'}) do
 test('preserved owner '..key..' prevents competing V12 reentry',function()
  local m=mock({queueMode='direct'});local old={jobId='job-1',started=true,running=true};m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
print('TOTAL '..tests..' V12 teleport tests')
]]
assert(load(source,'v12-bootstrap-contract','t',_G))()
