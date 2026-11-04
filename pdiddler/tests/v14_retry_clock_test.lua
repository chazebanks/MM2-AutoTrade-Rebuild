local O=dofile('pdiddler/pdiddler_webhook_outbox_v3.lua')
local function report()
 local function item(id,v) return {id=id,name=id,qty=1,value=v,demand=3} end
 return {id='clock-tx',job='job',version='p',kind='completed-trade',provenance='exact-raw-delta-v2',verified=true,
  rawInventoryVerified=true,give={item('A',100)},receive={item('B',115)},givenTotal=100,receivedTotal=115,
  profit=15,pricedInventoryTotal=115,inventoryTotal=115,unpricedTypes=0,unpricedCopies=0}
end
local wall=1000;local disk;local calls=0
local o=O.new({},true,{persist=function(s) disk=s;return true end,now=function() return wall end})
assert(o.enqueue(report()))
o.deliver('clock-tx',wall,function() calls=calls+1;wall=1009;return {status=429,retryAfter=5} end)
assert(o.ledger['clock-tx'].nextAttempt>=1014,'request duration shortened Retry-After')
local restored=O.new(disk,true,{persist=function(s) disk=s;return true end,now=function() return wall end})
restored.deliver('clock-tx',1009,function() calls=calls+1;return {status=200,receipt={acknowledged=true,messageId='123'}} end)
assert(calls==1,'restored retry ran before its wall-clock deadline')
wall=1014;assert(restored.deliver('clock-tx',wall,function() calls=calls+1;return {status=200,receipt={acknowledged=true,messageId='123'}} end))
assert(calls==2);print('PASS response-time wall clock preserves full retry delay across restart')
