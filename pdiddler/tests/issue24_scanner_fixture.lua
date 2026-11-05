-- Actual P3 catalog resolver and inventory parser, with only catalog input/log/UI boundaries supplied.
local file=assert(io.open('pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua'))
local src=file:read('*a');file:close()
local function span(a,b) return src:sub(assert(src:find(a,1,true)),assert(src:find(b,1,true))-1) end
local code=span('local function norm(x)','log("START")')
 ..span('local function assetKey(x)','local function auditEligibleIdentityCollisions()')
 ..span('local function inventoryFromProfile(prof)','local function unwrapProfile(')
code=code:gsub('([%w_%.]+)%+=','%1=%1+')
return function(catalog)
 local scope=setmetatable({Meta={},Sync={Weapons=catalog,Item=catalog},log=function() end},{__index=_G})
 return assert(load(code..'\nreturn inventoryFromProfile','actual-scanner-parser','t',scope))()
end
