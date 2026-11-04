-- Reuse the existing eight executor-boundary tests against the new fixed build.
local file=assert(io.open('pdiddler/tests/v10_teleport_autoexec_test.lua'))
local source=file:read('*a');file:close()
source=source:gsub('V10','V11'):gsub('58c9aede108b60278b9baa9dd7da73f7a4d95ac5','e6472342ca39df0f6cd5217c368631bd06613c20')
source=source..[[
test('legacy bootstrap cannot create a competing V11 teleport queue',function()
 local m=mock({queueMode='direct'});local old={jobId='job-1',started=true}
 m.env.PDIDDLER_V10_TELEPORT_AUTOBOOT_v1=old
 assert(m:run()==old and #m.queue==0 and #m.fetches==0)
end)
print('TOTAL '..tests..' V11 teleport tests')
]]
assert(load(source,'v11-bootstrap-regressions','t',_G))()
