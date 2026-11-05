local folder=arg[1] or '.'
package.path=folder..'/?.lua;'..package.path
local P=require('p4_stage12b_quantity_probe')
local tests=0
local function test(name,fn)
  local ok,err=pcall(fn)
  if not ok then error('TEST '..name..' FAILED: '..tostring(err)) end
  tests=tests+1
end
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b)) end
for _,sample in ipairs({'1','x1','x 2','X2','×2','× 12',' 10 '}) do
  test('quantity:'..sample,function()assert(P.parseQuantity(sample))end)
end
for _,sample in ipairs({'','0','x0','x','x-2','-1','Infinity','nil','2.5','abc','1000001'}) do
  test('quantity-invalid:'..sample,function()eq(P.parseQuantity(sample),nil)end)
end
for _,sample in ipairs({false,12,{}}) do
  test('quantity-invalidtype:'..tostring(sample),function()eq(P.parseQuantity(sample),nil)end)
end
test('quantity-explicit-nil',function()eq(P.parseQuantity(nil),nil)end)
test('quantity-x2',function() eq(P.parseQuantity('x2'),2) end)
test('quantity-multiplication-symbol',function() eq(P.parseQuantity('×2'),2) end)
test('quantity-upper-x',function()eq(P.parseQuantity('X15'),15)end)
local function side(slots,accepted)return{present=true,slots=slots or {},accepted=accepted}end
local function snap(their,ours)return{tradeOpen=true,session=1,rootVariant='TradeGUI',activeRoots=1,partnerMatched='YES',ours=ours or side({},false),theirs=their or side({},false),actionAccept='VISIBLE',actionDecline='VISIBLE'}end
local function slot(i,id,qty)return{slot=i,rawId=id,label=id,amountText=qty,chroma=false,chromaTag=false}end
test('empty-offer',function() assert(P.describe(snap()):find('THEIRS=EMPTY',1,true)) end)
test('partner-add-changes-signature',function()
  local before=P.snapshotSignature(snap(side({},false)))
  local after=P.snapshotSignature(snap(side({slot(1,'WatergunChroma','1')},false)))
  assert(before~=after)
end)
test('partner-removal-changes-signature',function()
  local before=P.snapshotSignature(snap(side({slot(1,'WatergunChroma','1')},false)))
  local after=P.snapshotSignature(snap(side({},false)))
  assert(before~=after)
end)
test('stack-quantity-changes-signature',function()
  local before=P.snapshotSignature(snap(nil,side({slot(1,'Immortal','x2')},false)))
  local after=P.snapshotSignature(snap(nil,side({slot(1,'Immortal','x1')},false)))
  assert(before~=after)
end)
test('acceptance-changes-signature',function()
  assert(P.snapshotSignature(snap(side({},false)))~=P.snapshotSignature(snap(side({},true))))
end)
test('unknown-acceptance-distinct-from-false',function()
  assert(P.snapshotSignature(snap(side({},nil)))~=P.snapshotSignature(snap(side({},false))))
end)
test('null-quantity-rendered-unverified',function()
  assert(P.lineForSide('OURS',side({slot(1,'Immortal',nil)},false)):find('NO_QTY',1,true))
end)
test('no-trade-signature',function()eq(P.snapshotSignature({tradeOpen=false}),'NO_TRADE')end)
test('missing-side',function()eq(P.sideSignature({present=false}),'side-missing')end)
-- Mock minimal Roblox objects: read-only API interface, no Roblox mutation/click APIs.
local Node={};Node.__index=Node
function Node:new(name,kind,props)
  local n=setmetatable({Name=name,Kind=kind or 'Frame',Visible=true,Enabled=true,Children={},Parent=nil,attrs={}},Node)
  for k,v in pairs(props or {}) do n[k]=v end
  return n
end
function Node:add(child)child.Parent=self;self.Children[#self.Children+1]=child;return child end
function Node:FindFirstChild(name,rec)
  for _,ch in ipairs(self.Children)do if ch.Name==name then return ch end end
  if rec then for _,ch in ipairs(self.Children) do local found=ch:FindFirstChild(name,true);if found then return found end end end
end
function Node:IsA(kind)
  if self.Kind==kind then return true end
  if kind=='GuiObject' then return self.Kind=='Frame' or self.Kind=='TextLabel' or self.Kind=='TextButton' end
  return false
end
function Node:GetAttribute(n)return self.attrs[n]end
function Node:GetDescendants()
  local out={}
  local function walk(n)
    for _,c in ipairs(n.Children)do out[#out+1]=c;walk(c)end
  end
  walk(self)
  return out
end
local function makeTrade()
  local pg=Node:new('PlayerGui','PlayerGui')
  local screen=pg:add(Node:new('TradeGUI','ScreenGui'))
  local root=screen:add(Node:new('Container')):add(Node:new('Trade'))
  local our=root:add(Node:new('YourOffer'))
  local their=root:add(Node:new('TheirOffer'))
  our:add(Node:new('Container'));their:add(Node:new('Container'))
  our:add(Node:new('Accepted','Frame',{Visible=false}))
  their:add(Node:new('Accepted','Frame',{Visible=false}))
  their:add(Node:new('Username','TextLabel',{Text='(Opponent)'}))
  local function addSlot(side,idx,id,qty)
    local s=side:FindFirstChild('Container'):add(Node:new('NewItem'..idx))
    s.attrs.ItemId=id
    s:add(Node:new('ItemName')):add(Node:new('Label','TextLabel',{Text=id}))
    s:add(Node:new('Container')):add(Node:new('Amount','TextLabel',{Text=qty}))
    return s
  end
  addSlot(our,1,'Immortal','x2');addSlot(their,1,'WatergunChroma','1')
  local players={GetPlayers=function()return{{Name='Opponent'}}end}
  return pg,root,our,their,players
end
test('native-inspect-basic',function()
 local pg,_,_,_,players=makeTrade()
 local s=P.inspect(pg,players,nil,1)
 eq(s.tradeOpen,true);eq(s.activeRoots,1);eq(s.partnerMatched,'YES');eq(s.ours.slots[1].qty,2)
 eq(s.theirs.slots[1].rawId,'WatergunChroma');eq(s.ours.accepted,false)
end)
test('native-inspect-quantity-missing',function()
 local pg,_,our,_,players=makeTrade()
 local item=our:FindFirstChild('Container'):FindFirstChild('NewItem1')
 local amount=item:FindFirstChild('Container'):FindFirstChild('Amount');amount.Text='?'
 local s=P.inspect(pg,players,nil,1)
 eq(s.ours.slots[1].qty,nil)
end)
test('native-inspect-no-trade',function()
 local pg,root,_,_,players=makeTrade();root.Visible=false
 local s=P.inspect(pg,players,nil,1)
 eq(s.tradeOpen,false)
end)
test('native-inspect-multiple-gui',function()
 local pg,_,_,_,players=makeTrade()
 local phone=pg:add(Node:new('TradeGUI_Phone','ScreenGui'))
 phone:add(Node:new('Container')):add(Node:new('Trade'))
 local s=P.inspect(pg,players,nil,1)
 eq(s.tradeOpen,false);eq(s.ambiguous,true);eq(s.activeRoots,2)
end)
test('native-unknown-accept-when-missing',function()
 local pg,_,our,_,players=makeTrade()
 for i,v in ipairs(our.Children)do if v.Name=='Accepted' then table.remove(our.Children,i)break end end
 local s=P.inspect(pg,players,nil,1)
 eq(s.ours.accepted,nil)
end)
test('native-phone-layout',function()
 local pg,root,_,_,players=makeTrade()
 root.Parent.Parent.Name='TradeGUI_Phone'
 local s=P.inspect(pg,players,nil,1)
 eq(s.tradeOpen,true);eq(s.rootVariant,'TradeGUI_Phone')
end)
test('native-partner-identity-mismatch',function()
 local pg,_,_,their,players=makeTrade()
 their:FindFirstChild('Username').Text='(OtherPlayer)'
 local s=P.inspect(pg,players,nil,1)
 eq(s.partnerMatched,'NO')
end)
test('native-missing-amount-is-not-one',function()
 local pg,_,our,_,players=makeTrade()
 local box=our:FindFirstChild('Container'):FindFirstChild('NewItem1'):FindFirstChild('Container')
 box.Children={}
 local s=P.inspect(pg,players,nil,1)
 eq(s.ours.slots[1].qty,nil);eq(s.ours.slots[1].amountText,nil)
end)
test('native-hidden-accepted-is-false',function()
 local pg,_,our,_,players=makeTrade()
 our:FindFirstChild('Accepted').Visible=false
 local s=P.inspect(pg,players,nil,1)
 eq(s.ours.accepted,false)
end)
test('native-hidden-screen-not-active',function()
 local pg,root,_,_,players=makeTrade()
 root.Parent.Parent.Enabled=false
 local s=P.inspect(pg,players,nil,1)
 eq(s.tradeOpen,false)
end)
test('native-accept-change',function()
 local pg,_,our,_,players=makeTrade()
 local before=P.snapshotSignature(P.inspect(pg,players,nil,1))
 our:FindFirstChild('Accepted').Visible=true
 local after=P.snapshotSignature(P.inspect(pg,players,nil,1))
 assert(before~=after)
end)

test('stage12b-empty-amount-audit-not-quantity-one',function()
  local _,_,our=makeTrade()
  local slot=our:FindFirstChild('Container'):FindFirstChild('NewItem1')
  local amount=slot:FindFirstChild('Container'):FindFirstChild('Amount')
  amount.Text=''
  local result=P.amountAudit(slot)
  assert(result:find('Amount=EMPTY/VISIBLE',1,true))
  assert(not result:find('Qty=1',1,true))
end)
test('stage12b-explicit-stack-amount',function()
  local _,_,our=makeTrade()
  local slot=our:FindFirstChild('Container'):FindFirstChild('NewItem1')
  assert(P.amountAudit(slot):find('Amount=x2/VISIBLE',1,true))
end)
test('stage12b-hidden-quantity-label',function()
  local _,_,our=makeTrade()
  local slot=our:FindFirstChild('Container'):FindFirstChild('NewItem1')
  local amount=slot:FindFirstChild('Container'):FindFirstChild('Amount')
  amount.Visible=false
  assert(P.amountAudit(slot):find('HIDDEN',1,true))
end)
test('stage12b-quantity-attribute-only-safe-numeric',function()
  local _,_,our=makeTrade()
  local slot=our:FindFirstChild('Container'):FindFirstChild('NewItem1')
  slot.attrs.Quantity=2
  slot.attrs.ItemId='DO_NOT_LEAK'
  local res=P.amountAudit(slot)
  assert(res:find('slot.Quantity=2',1,true))
  assert(not res:find('DO_NOT_LEAK',1,true))
end)
test('stage12b-other-text-in-slot-observed',function()
  local _,_,our=makeTrade()
  local slot=our:FindFirstChild('Container'):FindFirstChild('NewItem1')
  slot:add(Node:new('StackBox')):add(Node:new('StackCount','TextLabel',{Text='×2'}))
  local res=P.amountAudit(slot)
  assert(res:find('StackBox/StackCount=×2/V',1,true))
end)
test('stage12b-audit-signature-changes-even-if-amount-blank',function()
  local pg,_,our,_,players=makeTrade()
  local slot=our:FindFirstChild('Container'):FindFirstChild('NewItem1')
  slot:FindFirstChild('Container'):FindFirstChild('Amount').Text=''
  local sig1=P.snapshotSignature(P.inspect(pg,players,nil,1))
  slot:add(Node:new('StackCount','TextLabel',{Text='2'}))
  local sig2=P.snapshotSignature(P.inspect(pg,players,nil,1))
  assert(sig1~=sig2)
end)

print('PASS',tests,'Stage12b quantity-evidence diagnostics tests')
