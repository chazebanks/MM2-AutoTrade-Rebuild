-- Executable Lua 5.4 Stage 9 pure observation contract regression tests.
local dir=arg[1] or './'
package.path=dir..'/?.lua;'..dir..'/../pdiddler_stage8/?.lua;'..package.path
local O=require('p4_observer_contract')
local S=require('p4_safety_core')
local total=0
local function check(name,fn)
    local ok,err=pcall(fn)
    if not ok then error('FAILED '..name..': '..tostring(err)) end
    total=total+1
end
local function equal(actual,expected)
    assert(actual==expected,tostring(actual)..' ~= '..tostring(expected))
end
local function stock()
    return {unmapped=0,unpriced=0,badQty=0,items={
        {id='Immortal',name='Immortal',qty=2,checkerId='1032',page='godly',cat='Weapons',type='Gun'},
        {id='Mortal',name='Mortal',qty=1,checkerId='1031',page='godly',cat='Weapons',type='Knife'},
        {id='EmbersickleChroma',name='Chroma Embersickle',qty=1,checkerId='1029',page='chroma',cat='Weapons',type='Knife'},
    }}
end
local function other()
    return {unmapped=0,unpriced=0,badQty=0,items={
        {id='WatergunChroma',name='Chroma Watergun',qty=1,checkerId='810',page='chroma',cat='Weapons',type='Gun'},
        {id='Sugar',name='Sugar',qty=1,checkerId='22',page='godly',cat='Weapons',type='Gun'},
    }}
end
local function slot(n,id,name,qty,chroma)
    return {slot=n,rawId=id,label=name,amountText=qty or 'x1',chroma=chroma or false}
end
local function fixture()
    return {tradeOpen=true,contextOK=true,session='job:trade:P2',
        our={complete=true,accepted=false,slots={slot(1,'Immortal','Immortal','x2',false),slot(2,'Mortal','Mortal','1',false)}},
        their={complete=true,accepted=false,slots={slot(1,'WatergunChroma','Watergun','x1',true)}}}
end
local function normalize(raw,own,them,fresh)
    return O.normalize(raw,{ownInventory=own or stock(),opponentInventory=them or other(),marketFresh=fresh~=false})
end
check('parses exact x2, ×2, 2 and 1',function()
    for _,q in ipairs({'x2','X2','×2','2',' x 2 '}) do equal(O.parseQuantity(q),2) end
    equal(O.parseQuantity('1'),1)
end)
check('rejects missing, decimals, negatives, zero, scientific and giant qty',function()
    for _,q in ipairs({' ','x','0','-1','1.0','1e4','x-2','x1000001','999999999999999','1,000','x2 boxes'}) do
        equal(O.parseQuantity(q),nil)
    end
    equal(O.parseQuantity(nil),nil)
end)
check('native blank amount means exactly one copy, not missing quantity',function()
    equal(O.parseQuantity(''),1)
    equal(O.parseQuantity('x2'),2)
    equal(O.parseQuantity(nil),nil)
    equal(O.parseQuantity(false),nil)
    equal(O.parseQuantity('  '),nil)
end)
check('blank Amount with unique inventory match resolves to one',function()
    local x=fixture()
    x.our.slots[2].amountText=''
    x.their.slots[1].amountText=''
    x.their.slots[1].rawId=nil
    local o,d=normalize(x)
    equal(o.contextOK,true)
    equal(o.ownItems[2].qty,1)
    equal(o.theirResolved,true)
    equal(d.theirItems[1].qty,1)
    equal(d.theirItems[1].origin,'unique-scanner-name')
    equal(o.quoteSafe,false)
end)
check('blank Amount never rescues a missing weapon name',function()
    local x=fixture()
    x.our.slots[2].amountText=''
    x.our.slots[2].label=''
    local o,d=normalize(x)
    equal(o.contextOK,false)
    assert(table.concat(d.errors,'|'):find('name-unavailable',1,true))
end)
check('verified quantities and slot layout pass to safety core shape',function()
    local o,d=normalize(fixture())
    equal(o.tradeOpen,true);equal(o.contextOK,true);equal(o.ourSlots,2)
    equal(o.theirSlots,1);equal(o.theirResolved,true)
    equal(#o.ownItems,2);equal(o.ownItems[1].qty,2);equal(o.ownItems[1].id,'Immortal')
    equal(d.theirItems[1].id,'WatergunChroma')
    equal(d.theirItems[1].origin,'raw-id')
    equal(o.quoteSafe,false)
end)
check('a read-only observation never authorizes price or acceptance',function()
    local o,d=normalize(fixture())
    equal(d.authorizesTrade,false);equal(d.authorizesAccept,false)
    equal(d.provesCompletion,false);equal(d.marketValueAuthority,false)
    equal(o.quoteSafe,false)
end)
check('market freshness only comes from explicit trusted input',function()
    local o=normalize(fixture(),nil,nil,false)
    equal(o.marketFresh,false)
    equal(o.quoteSafe,false)
end)
check('opponent removal changes physical signature, not our signature',function()
    local original=fixture()
    local before=normalize(original)
    local changed=fixture();changed.their.slots={}
    local after=normalize(changed)
    equal(before.ourSig,after.ourSig)
    assert(before.theirSig~=after.theirSig)
    equal(after.theirResolved,true)
    equal(after.theirSlots,0)
end)
check('opponent swaps item at same price or same count invalidates signature',function()
    local before=normalize(fixture())
    local changed=fixture();changed.their.slots[1]=slot(1,'Sugar','Sugar','x1',false)
    local after=normalize(changed)
    assert(before.theirSig~=after.theirSig)
end)
check('changed slot order alone does not change identity signature',function()
    local a=fixture()
    local b=fixture();b.our.slots[1],b.our.slots[2]=b.our.slots[2],b.our.slots[1]
    equal(normalize(a).ourSig,normalize(b).ourSig)
end)
check('repositioned item changes physical signature',function()
    local a=fixture();local b=fixture();b.our.slots[1].slot=4
    assert(normalize(a).ourSig~=normalize(b).ourSig)
end)
check('raw id plus incorrect visible label cannot silently pass',function()
    local x=fixture();x.their.slots[1].label='Sugar'
    local o,d=normalize(x)
    equal(o.theirResolved,false)
    assert(table.concat(d.errors,'|'):find('raw-id-name-disagreement',1,true))
end)
check('missing attribute can resolve only unique scanner name',function()
    local x=fixture();x.their.slots[1].rawId=nil
    local o,d=normalize(x)
    equal(o.theirResolved,true)
    equal(d.theirItems[1].origin,'unique-scanner-name')
end)
check('ambiguous display identity refused when raw id absent',function()
    local inv=other()
    inv.items[#inv.items+1]={id='WatergunClone',name='Chroma Watergun',qty=1,checkerId='811',page='chroma',cat='Weapons',type='Gun'}
    local x=fixture();x.their.slots[1].rawId=nil
    local o,d=normalize(x,nil,inv)
    equal(o.theirResolved,false)
    assert(table.concat(d.errors,'|'):find('unproven-or-ambiguous',1,true))
end)
check('missing amount text never assumes 1',function()
    local x=fixture();x.our.slots[1].amountText=nil
    local o,d=normalize(x)
    equal(o.contextOK,false);equal(#o.ownItems,0)
    assert(table.concat(d.errors,'|'):find('quantity-unverified',1,true))
end)
check('x2 stack quantity must not exceed scanner ownership',function()
    local x=fixture();x.our.slots[1].amountText='x3'
    local o,d=normalize(x)
    equal(o.contextOK,false)
    assert(table.concat(d.errors,'|'):find('quantity-exceeds-scanner',1,true))
end)
check('aggregate duplicate identity cannot exceed owned qty',function()
    local x=fixture();x.our.slots[2]=slot(2,'Immortal','Immortal','x2',false)
    local o,d=normalize(x)
    equal(o.contextOK,false)
    assert(table.concat(d.errors,'|'):find('aggregate-quantity-exceeds',1,true))
end)
check('opponent unknown item is unresolved and cannot be considered safe',function()
    local x=fixture();x.their.slots[1]=slot(1,'Nonexistent','Nonexistent','x1',false)
    local o=normalize(x)
    equal(o.theirResolved,false)
    equal(o.quoteSafe,false)
end)
check('missing accepted indicator does not default to false',function()
    local x=fixture();x.our.accepted=nil
    local o,d=normalize(x)
    equal(o.ourAccepted,nil)
    equal(o.contextOK,false)
    assert(table.concat(d.errors,'|'):find('our-accept-unverified',1,true))
end)
check('visible true and false acceptance is retained as evidence',function()
    local x=fixture();x.our.accepted=true;x.their.accepted=true
    local o=normalize(x)
    equal(o.ourAccepted,true);equal(o.theirAccepted,true)
end)
check('duplicate physical slot rejected',function()
    local x=fixture();x.our.slots[2].slot=1
    local o=normalize(x)
    equal(o.contextOK,false)
end)
check('too many items rejected',function()
    local x=fixture()
    for n=3,5 do x.our.slots[n]=slot(n,'Mortal','Mortal','x1',false) end
    local o=normalize(x)
    equal(o.contextOK,false)
end)
check('scanner record with unmapped weapons cannot prove identities',function()
    local inv=stock();inv.unmapped=1
    local o=normalize(fixture(),inv)
    equal(o.contextOK,false)
end)
check('session unverified blocks context',function()
    local x=fixture();x.contextOK=false
    local o=normalize(x)
    equal(o.contextOK,false)
end)
check('unverified visible chroma cannot be treated as nonchroma',function()
    local x=fixture();x.their.slots[1].chroma=nil
    local o=normalize(x)
    equal(o.theirResolved,false)
end)
check('closed trade makes no acceptance or completion claim',function()
    local x=fixture();x.tradeOpen=false
    local o,d=normalize(x)
    equal(o.tradeOpen,false)
    equal(d.provesCompletion,false)
end)
check('no external proof object may mark a trade safe',function()
    local x=fixture();x.quoteSafe=true;x.profit=999999;x.accept=true
    local o=normalize(x)
    equal(o.quoteSafe,false)
end)
check('Stage8 integration issues REMOVAL for an unproven current quote',function()
    local x=fixture();local obs=normalize(x)
    local core=S.new('job:trade:P2')
    local action=S.step(core,obs,0)
    equal(action,'REMOVE_ONE')
    -- Research state machine output only. NO native executor is connected.
end)
print('PASS',total,'Stage 9 contract tests')