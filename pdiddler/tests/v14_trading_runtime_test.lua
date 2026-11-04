local count=0
local function test(name,fn) fn();count=count+1;print('PASS V14 '..name) end
test('accepted window closing retains outcome ownership',function()
 local f=fixture();f.held=nil;f.telemetry.holdOutcome=function(reason) f.held=reason end
 f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(5)
 f.accepted.Visible=true;f.root.children.YourOffer.children.Accepted.Visible=true;f:advance(5.5)
 f.root.Visible=false;f:advance(7)
 assert(f.controller.state.blocked and f.held,'accepted closure released an unconfirmed transaction')
 eq(f.accepts,0);eq(f.declines,0)
end)
test('first safe quote agrees after an unsafe opener or opponent first',function()
 local function run(opponentFirst)
  local f=fixture();f.partnerInv.items={f:item('T',100)}
  f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
  f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
  f:start();f:advance(opponentFirst and 1 or 3.4)
  f:setTheir({f.partnerInv.items[1]});f:advance(8)
  eq(f.accepts,0);eq(f.declines,0);return f:total()
 end
 eq(run(false),run(true));eq(run(true),40)
end)
test('tied market conditions do not trigger an immediate value-only increase',function()
 local f=fixture();f.own.items={f:item('A',7),f:item('B',20),f:item('C',38)}
 for _,it in ipairs(f.own.items) do f.rows['godly:'..it.id].demand=1 end
 f.partnerInv.items={f:item('T',101)};f.rows['godly:T'].demand=1
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
 f:start();f:advance(3.4);f:setTheir({f.partnerInv.items[1]});f:advance(8)
 eq(f:total(),7);eq(f.offers,1);eq(f.accepts,0)
end)
test('accepted indicator observed between polling frames survives close',function()
 local f=fixture();f.telemetry.holdOutcome=function() f.held=true end
 f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(5)
 local indicator=f.root.children.YourOffer.children.Accepted
 indicator.Visible=true;indicator:GetPropertyChangedSignal('Visible'):Fire()
 f.root.Visible=false;f.root:GetPropertyChangedSignal('Visible'):Fire();f:advance(6)
 assert(f.controller.state.blocked and f.held)
end)
test('normal unaccepted decline still releases the existing rotation',function()
 local f=fixture();f:start();f:advance(3.5);f.root.Visible=false;f:advance(5)
 assert(not f.controller.state.blocked and f.controller.state.active==false)
 eq(f.accepts,0)
end)
test('accepted offer modification cannot cause a completed report',function()
 local f=fixture();f:start();f:advance(1);f:setTheir({f.partnerInv.items[1]});f:advance(5)
 f.root.children.YourOffer.children.Accepted.Visible=true;f:advance(5.4)
 local tiny=f:item('Tiny',15);f.partnerInv.items[#f.partnerInv.items+1]=tiny
 f:setTheir({tiny});f:advance(8)
 eq(f.declines,1);eq(f.accepts,0);assert(f.controller.state.blocked)
 assert(f.controller.state.completedTrades==nil)
end)
test('legacy globals cannot invent native contract verification',function()
 local f=fixture();f.env.PDIDDLER_AUTO_ACCEPT=true;f:start();f:advance(1)
 f:setTheir({f.partnerInv.items[1]});f:advance(10);eq(f.accepts,0)
end)
test('native two-step negotiation budget and final decline remain bounded',function()
 local f=fixture();f.own.items={f:item('A',50),f:item('B',58),f:item('C',63),f:item('D',68)}
 f.partnerInv.items={f:item('T',100)}
 f.policy={};for k,v in pairs(POLICY) do f.policy[k]=v end
 f.policy.selectOpener=function() return f.own.items[1],'fixture-opener' end
 f.early={choose=function() return 'keep' end}
 f.gate={read=function() return 'ready' end,step=function() return true end}
 f:start();f:advance(3.4);f:setTheir({f.partnerInv.items[1]});f:advance(45)
 eq(f.offers,3);eq(f.declines,1);eq(f.accepts,0)
end)
test('opponent adding one of our items replaces the mirrored quote',function()
 local f=fixture();f:start();f:advance(1);f:setTheir({f.partnerInv.items[2]});f:advance(7)
 eq(f:total(),40)
 local duplicate=f:item('C',30);f.partnerInv.items[#f.partnerInv.items+1]=duplicate
 f:setTheir({f.partnerInv.items[2],duplicate});f:advance(12)
 for _,pick in ipairs(f.ourPicks) do assert(pick.id~='C','mirrored C remained after replanning') end
 assert(f:total()>0 and f:total()<=115);eq(f.accepts,0)
end)
test('no nonmatching safe plan declines instead of offering their item',function()
 local f=fixture();local a=f:item('A',30);f.own.items={a}
 local incoming=f:item('A',30);f.partnerInv.items={incoming,f:item('T',100)}
 f:start();f:advance(1);f:setTheir(f.partnerInv.items);f:advance(6)
 eq(f.offers,0);eq(f.declines,1);eq(f.accepts,0)
end)
test('evidenced fixture executes one accept then reconciles and reports once',function()
 local f=fixture();f.partnerInv.items={f:item('T',100)}
 f.verifier=VERIFICATION
 f.outbox=OUTBOX.new({},true,{persist=function(snapshot) f.persisted=snapshot;return true end})
 local button=node('NativeAccept','TextButton',f.root)
 local service=f.game.GetService
 f.game.GetService=function(self,name)
  if name=='VirtualInputManager' then return {SendMouseButtonEvent=function(_,x,y,b,pressed)
   if not pressed then
    f.accepts=f.accepts+1
    local indicator=f.root.children.YourOffer.children.Accepted
    indicator.Visible=true;indicator:GetPropertyChangedSignal('Visible'):Fire()
   end
  end} end
  return service(self,name)
 end
 f.native={approved=true,evidenceId='OFFLINE-NATIVE-FIXTURE-ONLY',placeId=142823291,
  acceptControlVerified=true,completionVerified=true,inventoryVerified=true,
  read=function() return {stage='accept',ready=true,control=button} end,
  bind=function(fn) f.nativeEvent=fn;return {Disconnect=function() end} end,
  classifyCompletion=function(event) return event end,
  readInventory=function(c,stage)
   local counts={A=1,B=1,C=1,D=1};local items=f.own.items
   if stage=='after' then
    counts={A=1,B=1,C=0,D=0,T=1};items={f.own.items[1],f.own.items[2],f.partnerInv.items[1]}
   end
   return {id=c.id,job=c.job,epoch=c.epoch,version=f.profile.version,counts=counts,items=items,complete=true}
  end}
 f:start();f:advance(1);f:setTheir(f.partnerInv.items);f:advance(5)
 eq(f:total(),40);eq(f.accepts,1);eq(f.declines,0)
 local a=f.lifecycle.state.active
 f.nativeEvent({kind='completed',id=a.id,job=a.job,epoch=a.epoch,partner=a.partner,ourSig=a.ourSig,theirSig=a.theirSig,time=123})
 f.root.Visible=false;f:advance(5.5)
 assert(not f.controller.state.blocked,'native correlated completion was prematurely held')
 assert(not f.lifecycle:poll());f:advance(6.1);assert(f.lifecycle:poll())
 eq(f.lifecycle.state.completed,1);assert(f.lifecycle:canStartWork())
 local report=f.lifecycle.state.lastReport;eq(report.profit,60);eq(report.inventoryTotal,270)
 local sent=0
 local function send(completed)
  assert(f.persisted[report.id].state=='sending');assert(OUTBOX.payload(completed).embeds[1])
  sent=sent+1;return {status=200,receipt={acknowledged=true,messageId='12345'}}
 end
 assert(f.outbox.deliver(report.id,7,send));assert(not f.outbox.deliver(report.id,8,send))
 eq(sent,1);eq(f.persisted[report.id].state,'sent');eq(f.accepts,1)
end)
test('native before-read cannot escape a close and reopen between polling frames',function()
 local f=fixture();local reads=0;local offeredIn
 f.verifier=VERIFICATION
 f.native={approved=true,evidenceId='OFFLINE-LIFETIME-FIXTURE',placeId=142823291,
  acceptControlVerified=true,completionVerified=true,inventoryVerified=true,
  read=function() return {ready=false} end,bind=function() return {Disconnect=function() end} end,
  classifyCompletion=function(e) return e end,
  readInventory=function(c)
   reads=reads+1
   if reads==1 then
    f.root.Visible=false;f.root:GetPropertyChangedSignal('Visible'):Fire()
    f.root.Visible=true;f.root:GetPropertyChangedSignal('Visible'):Fire()
   end
   return {id=c.id,job=c.job,epoch=c.epoch,complete=true,counts={A=1,B=1,C=1,D=1}}
  end}
 f.onOffer=function() offeredIn=f.controller.state.tradesSeen end
 f:start();f:advance(5)
 assert(offeredIn~=1,'an old visible lifetime offered after the yielding before-read')
 assert(f.controller.state.tradesSeen>=2)
end)
print('TOTAL '..count..' V14 production P4 tests')
