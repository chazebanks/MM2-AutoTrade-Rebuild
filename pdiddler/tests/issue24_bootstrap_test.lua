-- Preserve complete queue/re-entry contract against the actual successor bootstrap.
local file=assert(io.open('pdiddler/tests/gui_bootstrap_test.lua'));local source=file:read('*a');file:close()
local boot=assert(io.open('pdiddler/pdiddler_V15_4_TELEPORT_AUTOBOOT_v1.lua'));local code=boot:read('*a');boot:close()
local pin=assert(code:match('local V15_4_SHA="([0-9a-f]+)"'))
source=source:gsub("'V15_3'","'V15_4'"):gsub('5f95a76571795cc3c3fd551d2cfe11e8b4700694',pin)
local insert=[=[
source=source..[[
for _,key in ipairs({'PDIDDLER_V15_3_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_3_GUI_STATUS'}) do
 test('V15.3 predecessor prevents reachable build queue '..key,function()
  local m=mock({queueMode='direct'});local old={jobId='job-1',started=true,running=true};m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0)
 end)
end
print('TOTAL '..tests..' V15.4 teleport tests')
]]
]=]
local marker="assert(load(source,'v13-bootstrap-contract','t',_G))()"
local pos=assert(source:find(marker,1,true));source=source:sub(1,pos-1)..insert..source:sub(pos)
assert(load(source,'reachable-bootstrap-contract','t',_G))()
