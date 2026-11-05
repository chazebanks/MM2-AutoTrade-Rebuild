local file=assert(io.open('pdiddler/tests/issue24_scanner_bootstrap_test.lua'));local text=file:read('*a');file:close()
text=text:gsub('V15_5','V15_6'):gsub('V15.5 teleport tests','V15.6 teleport tests')
text=text:gsub("'PDIDDLER_V15_4_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_4_REACHABLE'", "'PDIDDLER_V15_4_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_4_REACHABLE','PDIDDLER_V15_5_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE'")
assert(load(text,'issue27-bootstrap-contract','t',_G))()
