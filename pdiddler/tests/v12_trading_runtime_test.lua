local v12n=0
local function test12(name,fn) fn();v12n=v12n+1;print('PASS V12 '..name) end
test12('guarded comparable quote avoids a tiny disconnected initial region',function()
 local f=fixture();f.own.items={f:item('Small',23),f:item('Comparable',145)}
 f.rows['godly:Small'].demand=1;f.rows['godly:Comparable'].demand=3
 f.partnerInv.items={f:item('T',235)};f:start();f:advance(1)
 f:setTheir({f.partnerInv.items[1]});f:advance(7)
 eq(f:total(),145);eq(f.offers,1);eq(f.accepts,0)
end)
test12('equivalent opponent edits cannot refill early spending',function()
 local f=fixture();f.own.items={f:item('A',7),f:item('B',38),f:item('C',54),f:item('D',65)}
 for _,x in ipairs(f.own.items) do f.rows['godly:'..x.id].demand=1 end
 f.partnerInv.items={f:item('T1',101),f:item('T2',101),f:item('T3',101)}
 for _,x in ipairs(f.partnerInv.items) do f.rows['godly:'..x.id].demand=1 end
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
 f:start();f:advance(3.4);f:setTheir({f.partnerInv.items[1]});f:advance(8);eq(f:total(),38)
 f:setTheir({f.partnerInv.items[2]});f:advance(12)
 f:setTheir({f.partnerInv.items[3]});f:advance(16)
 eq(f:total(),38);eq(f.offers,2);eq(f.accepts,0)
end)
test12('two late verified steps remain global across exact offer changes',function()
 local f=fixture();f.own.items={f:item('A',50),f:item('B',58),f:item('C',63),f:item('D',68)}
 f.partnerInv.items={f:item('T1',100),f:item('T2',100)}
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
 f.early={choose=function() return 'spent' end}
 f.gate={read=function() return 'ready' end,step=function() return true end}
 f:start();f:advance(3.4);f:setTheir({f.partnerInv.items[1]});f:advance(26)
 eq(f:total(),63);f:setTheir({f.partnerInv.items[2]});f:advance(40)
 eq(f:total(),63);eq(f.offers,3);eq(f.accepts,0)
end)
test12('equal giveaway economics retain the less concentrated portfolio',function()
 local f=fixture();f.own.items={f:item('A',33),f:item('B',33,3)}
 f.partnerInv.items={f:item('T',65)};f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(7)
 eq(f:total(),33);eq(f.ourPicks[1].id,'B');eq(f.offers,1);eq(f.accepts,0)
end)
test12('an unprofitable first reply can safely reduce our real opener',function()
 local f=fixture();f:start();f:advance(3.4);eq(f:total(),100)
 f:setTheir({f.partnerInv.items[2]});f:advance(8)
 assert(f:total()>0 and f:total()<=85,'first unsafe opener was not safely rebalanced')
 eq(f.accepts,0);eq(f.declines,0)
end)
test12('an opponent edit after apply verification cannot make an increase free',function()
 local f=fixture();f.own.items={f:item('A',7),f:item('B',38),f:item('C',54),f:item('D',65)}
 for _,x in ipairs(f.own.items) do f.rows['godly:'..x.id].demand=1 end
 f.partnerInv.items={f:item('T1',101),f:item('T2',101)}
 for _,x in ipairs(f.partnerInv.items) do f.rows['godly:'..x.id].demand=1 end
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
 local original=f.scanner.getRecord;local after=0
 f.scanner.getRecord=function(id)
  if f.offers==2 then after=after+1;if after==2 then f:setTheir({f.partnerInv.items[2]}) end end
  return original(id)
 end
 f:start();f:advance(3.4);f:setTheir({f.partnerInv.items[1]});f:advance(12)
 eq(f.offers,2);eq(f.accepts,0);assert(f.controller.state.active==false or f.controller.state.blocked)
end)
test12('failed physical removal cannot repeat a cancelled reservation',function()
 local f=fixture();f.own.items={f:item('A',7),f:item('B',38)};f.partnerInv.items={f:item('T',101)}
 for _,x in ipairs(f.own.items) do f.rows['godly:'..x.id].demand=1 end;f.rows['godly:T'].demand=1
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
 local service=f.game.GetService;local attempts=0
 f.game.GetService=function(self,name)
  if name=='VirtualInputManager' then return {SendMouseButtonEvent=function() attempts=attempts+1;error('fixture physical input failed') end} end
  return service(self,name)
 end
 f:start();f:advance(3.4);f:setTheir({f.partnerInv.items[1]});f:advance(15)
 eq(attempts,1);eq(f.offers,1);eq(f:total(),7);eq(f.accepts,0)
 f:advance(70);eq(f.declines,1)
end)
test12('a falling offer in the post-apply race closes promptly',function()
 local f=fixture();f.own.items={f:item('A',7),f:item('B',38),f:item('C',20),f:item('D',54),f:item('E',65)}
 for _,x in ipairs(f.own.items) do f.rows['godly:'..x.id].demand=1 end
 f.partnerInv.items={f:item('T1',101),f:item('T2',45)}
 for _,x in ipairs(f.partnerInv.items) do f.rows['godly:'..x.id].demand=1 end
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
 local original=f.scanner.getRecord;local after=0
 f.scanner.getRecord=function(id)
  if f.offers==2 then after=after+1;if after==2 then f:setTheir({f.partnerInv.items[2]}) end end
  return original(id)
 end
 f:start();f:advance(3.4);f:setTheir({f.partnerInv.items[1]});f:advance(12)
 eq(f.offers,2);eq(f.declines,1);eq(f.accepts,0);eq(f.controller.state.active,false)
end)
print('TOTAL '..v12n..' V12 actual P4 runtime tests')
