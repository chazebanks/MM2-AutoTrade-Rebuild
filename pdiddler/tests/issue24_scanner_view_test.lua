-- Actual catalog parser + current strict repricer; view has no UI, remotes or state owners.
local P=dofile('pdiddler/pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
local S=dofile('pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')
local profile={};for k,v in pairs(S) do profile[k]=v end
profile.isFresh=function() return S.isFresh(S.observedAtEpoch) end -- explicit historical test clock only
local parse=dofile('pdiddler/tests/issue24_scanner_fixture.lua')({
 Immortal={ItemName='Immortal',Rarity='Godly',ItemType='Knife'},
 Embersickle={ItemName='Embersickle',Rarity='Godly',ItemType='Knife'},
 ImmortalChroma={ItemName='Immortal',Rarity='Godly',ItemType='Knife',Chroma=true},
 NiksScythe={ItemName="Nik's Scythe",Rarity='Ancient',ItemType='Knife'},
})
local V
if arg[1]=='--baseline' then
 local file=assert(io.open('pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua'))
 local src=file:read('*a');file:close()
 local function span(a,b) return src:sub(assert(src:find(a,1,true)),assert(src:find(b,1,true))-1) end
 local helpers=span('local function fmtValue(v)','local Live = {'):gsub('n %+=','n = n +')
 local old=assert(load(helpers..'\nreturn {count=eligibleCopies,items=eligibleSummary,fmt=fmtValue}','actual-old-scanner-view','t',_G))()
 V={inventory=function(inv)
  return {countText=tostring(old.count(inv)),itemsText=old.items(inv),totalText=old.fmt(inv and inv.total),
   detail=old.items(inv),priceState='legacy'}
 end,row=function(rec,outgoing,request)
  return (request and request.state) or (outgoing and outgoing.state) or rec.state,old.items(rec.inv)
 end,summary=function(w,b,u) return string.format('Whitelist %d | Blacklist %d | Unknown %d',w,b,u) end}
else V=dofile('pdiddler/presentation/pdiddler3_scanner_view_v1.lua') end
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function contains(s,needle) assert(type(s)=='string' and s:find(needle,1,true),tostring(s)..' lacks '..needle) end
local function absent(s,needle) assert(not s:find(needle,1,true),s..' includes '..needle) end
local function inventory(owned) return parse({Weapons={Owned=owned}}) end
local function dump(x)
 if type(x)~='table' then return tostring(x) end
 local parts={};for k,v in pairs(x) do parts[#parts+1]=tostring(k)..'='..dump(v) end
 table.sort(parts);return '{'..table.concat(parts,'|')..'}'
end

test('Immortal and Embersickle display current canonical135 and95 instead of legacy140 and80',function()
 local inv=inventory({Immortal=1,Embersickle=1});assert(inv.total==220,'fixture no longer reproduces old snapshot')
 local view=V.inventory(inv,profile,P)
 assert(view.totalText=='230' and view.countText=='2' and view.priceState=='current')
 contains(view.itemsText,'Immortal');contains(view.itemsText,'135');contains(view.itemsText,'Embersickle');contains(view.itemsText,'95')
 absent(view.detail,'140');absent(view.detail,'80');contains(view.detail,'Supreme');contains(view.detail,profile.version)
end)
test('real quantities multiply only newly verified unit prices',function()
 local view=V.inventory(inventory({Immortal=2,Embersickle=3}),profile,P)
 assert(view.countText=='5' and view.totalText=='555')
 contains(view.itemsText,'Immortal x2');contains(view.itemsText,'270');contains(view.itemsText,'Embersickle x3');contains(view.itemsText,'285')
end)
test('normal and Chroma identities remain distinct',function()
 local view=V.inventory(inventory({Immortal=1,ImmortalChroma=1}),profile,P)
 assert(view.totalText=='1735');contains(view.itemsText,'Chroma Immortal');contains(view.itemsText,'1600')
end)
test('expired profile displays no cached or current numeric price as verified',function()
 local expired={};for k,v in pairs(profile) do expired[k]=v end;expired.isFresh=function() return false end
 local view=V.inventory(inventory({Immortal=1,Embersickle=1}),expired,P)
 assert(view.priceState=='expired');contains(view.totalText,'UNVERIFIED');contains(view.detail,'expired')
 absent(view.itemsText,'140');absent(view.itemsText,'135');absent(view.itemsText,'95');absent(view.itemsText,'80')
end)
test('missing profile metadata preserves raw eligible item as unpriced',function()
 local missing={};for k,v in pairs(profile) do missing[k]=v end
 missing.get=function(page,id) if id=='1032' then return nil end;return profile.get(page,id) end
 local view=V.inventory(inventory({Immortal=1,Embersickle=1}),missing,P)
 assert(view.priceState=='partial');contains(view.itemsText,'Immortal');contains(view.itemsText,'UNPRICED');contains(view.itemsText,'95')
 contains(view.totalText,'UNVERIFIED');absent(view.detail,'140');assert(view.totalText~='95')
end)
test('Priceless remains visible and unpriced instead of a zero-value item',function()
 local inv=inventory({NiksScythe=1});local view=V.inventory(inv,profile,P)
 contains(view.itemsText,"Nik's Scythe");contains(view.itemsText,'UNPRICED');contains(view.totalText,'UNVERIFIED')
 assert(view.totalText~='0');absent(view.itemsText,'(0)')
end)
test('malformed quantities and incomplete inventories visibly remain unverified',function()
 local inv=inventory({Immortal=1});inv.items[1].qty=0/0
 local view=V.inventory(inv,profile,P);contains(view.countText,'UNVERIFIED');contains(view.totalText,'UNVERIFIED')
 contains(view.itemsText,'Immortal');contains(view.itemsText,'UNVERIFIED');absent(view.itemsText,'nan')
 inv=inventory({Immortal=1});inv.unmapped=2
 view=V.inventory(inv,profile,P);contains(view.totalText,'UNVERIFIED');contains(view.detail,'unmapped=2')
 view=V.inventory({},profile,P);contains(view.totalText,'UNVERIFIED');assert(view.countText~='0')
end)
test('parser-dropped malformed quantities cannot display a verified zero-copy inventory',function()
 local inv=inventory({Immortal='bad quantity'});assert(inv.badQty==1 and #inv.items==0)
 local view=V.inventory(inv,profile,P)
 contains(view.countText,'UNVERIFIED');contains(view.totalText,'UNVERIFIED');contains(view.detail,'badQty=1')
end)
test('presentation never mutates scanner inventory or canonical market records',function()
 local inv=inventory({Immortal=2,Embersickle=1});local before=dump(inv);local marketBefore=dump(profile.profiles)
 V.inventory(inv,profile,P);V.row({state='whitelist',inv=inv},{state='unknown',reason='own-inventory-unavailable'},nil,profile,P)
 assert(dump(inv)==before and dump(profile.profiles)==marketBefore)
end)
test('outgoing own-proof pending cannot replace blacklist rarity header',function()
 local state,detail=V.row({state='blacklist',inv=inventory({})},{state='unknown',reason='own-proof-pending'},nil,profile,P)
 assert(state=='blacklist');contains(detail,'Inventory rarity: BLACKLIST');contains(detail,'Outgoing: UNKNOWN');contains(detail,'Own proof pending')
end)
test('outgoing paused reason preserves rarity instead of implying rarity uncertainty',function()
 local state,detail=V.row({state='whitelist',inv=inventory({Immortal=1})},{state='unknown',reason='transaction-owned'},nil,profile,P)
 assert(state=='whitelist');contains(detail,'Inventory rarity: WHITELIST');contains(detail,'Paused');contains(detail,'transaction-owned')
 local _,paused=V.row({state='whitelist',inv=inventory({Immortal=1})},{state='unknown',reason='own-proof-paused:active-trade'},nil,profile,P)
 contains(paused,'Paused');contains(paused,'active-trade')
end)
test('real request status has visual priority while raw rarity and outgoing reason stay explicit',function()
 local state,detail=V.row({state='whitelist',inv=inventory({Immortal=1})},{state='reachable',reason='verified-feasible-offer'},
  {state='requesting',extra='Waiting for opponent'},profile,P)
 assert(state=='requesting');contains(detail,'Waiting for opponent');contains(detail,'Inventory rarity: WHITELIST');contains(detail,'Outgoing: REACHABLE')
 contains(detail,'135');absent(detail,'140')
end)
test('missing record does not fabricate whitelist or eligible inventory',function()
 local state,detail=V.row(nil,{state='unknown',reason='inventory-unverified'},nil,profile,P)
 assert(state=='unknown');contains(detail,'Inventory rarity: UNKNOWN');contains(detail,'UNVERIFIED')
end)
test('summary labels raw rarity and outgoing uncertainty as separate counts',function()
 local summary=V.summary(2,1,0,{reachable=1,unprofitable=1,unknown=1})
 contains(summary,'Inventory rarity:');contains(summary,'Whitelist 2');contains(summary,'Blacklist 1');contains(summary,'Unknown 0')
 contains(summary,'\nOutgoing (unprocessed):');contains(summary,'Reachable 1');contains(summary,'Unprofitable 1');contains(summary,'Unknown 1')
 contains(V.summary(2,1,0,nil),'Outgoing: awaiting assessment')
end)
assert(failed==0,tostring(failed)..' view tests failed');print('TOTAL '..passed..' scanner-view tests')
