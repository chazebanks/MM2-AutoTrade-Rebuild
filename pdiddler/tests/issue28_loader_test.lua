-- Preserve actual loader/scanner/economics boundary tests with the new real policy.
local file=assert(io.open('pdiddler/tests/issue24_scanner_loader_test.lua'));local text=file:read('*a');file:close()
text=text:gsub('pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_5_SCANNER_EVIDENCE.lua','pdiddler_INTEGRATED_v15_7_INVENTORY_GROWTH.lua')
local needle="local source=file:read('*a');file:close()"
local add="\nsource=source:gsub('pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua','pdiddler4_balancer_SUPREME_v10_IMMEDIATE_SAFETY.lua')\nsource=source:gsub('pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua','pdiddler4_supreme_policy_v10_INVENTORY_GROWTH.lua')\n"
local p=assert(text:find(needle,1,true));text=text:sub(1,p+#needle)..add..text:sub(p+#needle+1)
local ending="local ending=\"assert(failed==0,tostring(failed)..' loader cases failed')\""
local extra=[=[
extra=extra..[[
for _,key in ipairs({'PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE','PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY'}) do
 test('active predecessor refuses strategy controller initialization '..key,function()
  local f=fixture();local old={jobId='job',running=true};f.env[key]=old
  assert(f:run(path)==old);f:advance(20)
  assert(f:count('p2')==0 and f.scannerLoads==nil and #f.guiCreated==0)
 end)
end
]]
]=]
local q=assert(text:find(ending,1,true));text=text:sub(1,q-1)..extra..text:sub(q)
assert(load(text,'issue28-loader-contract','t',_G))()
