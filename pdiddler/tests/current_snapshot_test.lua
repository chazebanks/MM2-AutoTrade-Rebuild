local old=dofile('pdiddler/pdiddler_supreme_snapshot_2026_11_03_ISSUE4.lua')
local s=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
local P=dofile('pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
assert(not old.isFresh(s.observedAtEpoch))
assert(not s.isFresh(s.observedAtEpoch-1))
assert(s.isFresh(s.observedAtEpoch) and s.isFresh(s.expiresAtEpoch-1))
assert(not s.isFresh(s.expiresAtEpoch) and not s.isFresh(s.expiresAtEpoch+1))
local c=s.coverage();assert(c.total==190 and c.finite==189 and c.unpriced==1)
assert(s.version~=old.version and s.observedAtEpoch>old.expiresAtEpoch)
local asOf={}
for k,v in pairs(s) do asOf[k]=v end
asOf.isFresh=function() return s.isFresh(s.observedAtEpoch) end -- historical test time, never the runtime profile
local changed=0;local seen={}
for key,row in pairs(s.profiles) do
 local prior=old.profiles[key];assert(prior and prior.name==row.name and prior.page==row.page and prior.id==row.id)
 assert(not seen[key]);seen[key]=true
 if prior.supremeValue~=row.supremeValue then changed=changed+1 end
 if row.supremeValue then
  local item={page=row.page,checkerId=row.id,id='raw-'..key,name=row.name,qty=1,cat='Weapons',type='Knife',value=999999}
  local inv,why=P.reprice({items={item}},asOf);assert(not why and #inv.items==1 and inv.items[1].value==row.supremeValue)
 end
end
assert(changed==22)
assert(s.get('ancient','1').supremeValue==nil)
assert(not P.tradeDecision({rawTotal=100,confidence=true},{rawTotal=114.99,confidence=true}).ok)
assert(P.tradeDecision({rawTotal=100,confidence=true},{rawTotal=115,confidence=true}).ok)
print('PASS190 canonical identities,189 repricings,22 changed prices,expiry edges and +15 floor')
