local n=0
local function test(name,fn) fn();n=n+1;print("PASS "..name) end
test("opponent-first quote is the one early response for its signature",function()
 local f=fixture();f.own.items={f:item("A",56),f:item("B",85),f:item("C",100)}
 f.partnerInv.items={f:item("T",150)};f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(7)
 eq(f:total(),85);eq(f.offers,1);eq(f.accepts,0)
end)
test("new visible lifetime rearms after old inventory result is fenced",function()
 local f=fixture();f.ownDelay=1;f.onInventory=function()
  f.onInventory=nil;f.root.Visible=false;f.root:GetPropertyChangedSignal("Visible"):Fire();f.root.Visible=true
 end
 f:start();f:advance(7);eq(f.controller.state.tradesSeen,2);eq(f.offers,1)
end)
test("paired manual Accepted is unconfirmed and cannot receive timeout decline",function()
 local f=fixture();f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(5)
 f.accepted.Visible=true;f.root.children.YourOffer.children.Accepted.Visible=true
 f:advance(70);eq(f.declines,0);eq(f.accepts,0)
 assert(f.controller.state.blocked==true);eq(f.controller.state.result,"completion-unconfirmed")
end)
test("verified late lift occurs once after real offer verification",function()
 local f=fixture();f.own.items={f:item("A",100),f:item("B",108)}
 f.partnerInv.items={f:item("T",200)}
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],"fixture-initial" end
 f.early={choose=function() return "spent" end}
 f.gate={read=function() return "ready" end,step=function() return true end}
 f:start();f:advance(3.4);eq(f:total(),100);f:setTheir({f.partnerInv.items[1]});f:advance(25)
 eq(f:total(),108);eq(f.offers,2);eq(f.accepts,0)
end)
test("paired Accepted cannot bypass changed-offer invalidation",function()
 local f=fixture();local tiny=f:item("Tiny",15);f.partnerInv.items[#f.partnerInv.items+1]=tiny
 f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(5)
 f.root.children.YourOffer.children.Accepted.Visible=true;f:advance(5.5)
 f.accepted.Visible=true;f:advance(6);f:setTheir({tiny});f:advance(7)
 eq(f.declines,1);eq(f.accepts,0);assert(f.controller.state.blocked~=true)
end)
test("failed late replacement cannot become a larger fresh opening quote",function()
 local f=fixture();f.own.items={f:item("A",38),f:item("B",50),f:item("C",60)}
 f.partnerInv.items={f:item("T",101)}
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],"fixture-initial" end
 f.early={choose=function() return "spent" end}
 f.gate={read=function() return "ready" end,step=function() return true end}
 f.onOffer=function() if f:total()==50 then f.ourPicks={};f:render("YourOffer",{}) end end
 f:start();f:advance(3.4);eq(f:total(),38);f:setTheir({f.partnerInv.items[1]});f:advance(25)
 eq(f.offers,2);eq(f.declines,1);eq(f:total(),0);eq(f.accepts,0)
end)
test("Accepted immediately after physical verification uses the verified signature",function()
 local f=fixture();f.own.items={f:item("A",56),f:item("B",85),f:item("C",100)}
 f.partnerInv.items={f:item("T",150)}
 f.onOffer=function() f.task.spawn(function()
  f.task.wait(.17);f.accepted.Visible=true;f.root.children.YourOffer.children.Accepted.Visible=true
 end) end
 f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(7)
 eq(f:total(),85);eq(f.declines,0);eq(f.accepts,0)
end)
print("TOTAL "..n.." V11 trading runtime tests")
