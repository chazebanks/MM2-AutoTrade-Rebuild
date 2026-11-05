-- Execute the inherited native queue/re-entry contract against the new bootstrap.
local file=assert(io.open('pdiddler/tests/issue24_scanner_bootstrap_test.lua'));local text=file:read('*a');file:close()
text=text:gsub('V15_5','V15_8'):gsub('V15.5 teleport tests','V15.8 teleport tests')
text=text:gsub("'PDIDDLER_V15_4_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_4_REACHABLE'", "'PDIDDLER_V15_4_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_4_REACHABLE','PDIDDLER_V15_5_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE','PDIDDLER_V15_6_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY','PDIDDLER_V15_7_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH'")
assert(load(text,'insertion-bootstrap-contract','t',_G))()
