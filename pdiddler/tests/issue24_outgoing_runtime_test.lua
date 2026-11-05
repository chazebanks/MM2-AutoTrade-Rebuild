-- The entire outgoing module runs unchanged. Fixtures implement only Roblox/executor boundaries.
local parse=NEW_PARSER({
 Seer={ItemName='Seer',Rarity='Godly',ItemType='Knife'},
 Boneblade={ItemName='Boneblade',Rarity='Godly',ItemType='Knife'},
 Batwing={ItemName='Batwing',Rarity='Ancient',ItemType='Knife'},
 Luger={ItemName='Luger',Rarity='Godly',ItemType='Gun'},
})
local function signal(f)
 local callbacks={}
 return {Connect=function(_,fn)
  callbacks[#callbacks+1]=fn
  return {Disconnect=function() for i,v in ipairs(callbacks) do if v==fn then table.remove(callbacks,i);break end end end}
 end,Fire=function(_,...) local args={...};for _,fn in ipairs(callbacks) do f.task.spawn(function() fn(table.unpack(args)) end) end end}
end
local function fixture()
 local f=boundaryFixture()
 f.now=0;f.queue={};f.errors={};f.logs={};f.hits={};f.requests={};f.rows={};f.reads=0
 f.own=parse({Weapons={Owned={Boneblade=1}}})
 local function schedule(co,at) f.queue[#f.queue+1]={co=co,at=at};return co end
 f.task={}
 function f.task.spawn(fn,...) local args={...};return schedule(coroutine.create(function() fn(table.unpack(args)) end),f.now) end
 function f.task.delay(t,fn) return schedule(coroutine.create(fn),f.now+t) end
 function f.task.wait(t) return coroutine.yield(math.max(t or .03,.001)) end
 function f.task.cancel(co) for _,q in ipairs(f.queue) do if q.co==co then q.cancelled=true end end end
 function f:advance(untilTime)
  local steps=0
  while true do
   table.sort(self.queue,function(a,b) return a.at<b.at end)
   local q=self.queue[1];if not q or q.at>untilTime then break end
   table.remove(self.queue,1);self.now=q.at
   if not q.cancelled then
    local ok,delay=coroutine.resume(q.co)
    if not ok then self.errors[#self.errors+1]=delay
    elseif coroutine.status(q.co)~='dead' then schedule(q.co,self.now+(delay or .03)) end
   end
   steps=steps+1;assert(steps<200000,'scheduler runaway')
  end
  self.now=untilTime
  assert(#self.errors==0,table.concat(self.errors,'; ')..'\n'..table.concat(self.logs,'\n'))
 end
 f.players.PlayerAdded=signal(f);f.players.PlayerRemoving=signal(f)
 local rs=node('ReplicatedStorage','ReplicatedStorage')
 local tradeFolder=node('Trade','Folder',rs)
 local decline=node('DeclineRequest','RemoteEvent',tradeFolder);decline.OnClientEvent=signal(f)
 function decline:FireServer() f.phone.sending.Visible=false end
 local vim={}
 local gui={GetGuiInset=function() return {X=0,Y=0} end}
 f.game.GetService=function(_,name)
  if name=='Players' then return f.players elseif name=='ReplicatedStorage' then return rs
  elseif name=='VirtualInputManager' then return vim elseif name=='GuiService' then return gui end
  error('unexpected service '..name)
 end
 function f:register(n,x,y,fn)
  n.AbsolutePosition={X=x,Y=y};n.AbsoluteSize={X=100,Y=20}
  self.hits[tostring(x+50)..':'..tostring(y+10)]={node=n,fn=fn}
 end
 function vim:SendMouseButtonEvent(x,y,_,down)
  local hit=assert(f.hits[tostring(x)..':'..tostring(y)],'input missed a real native control')
  if down then
   if hit.node==f.tradeButton then
    f.requests[#f.requests+1]={player=f.selected,at=f.now}
   end
  elseif hit.fn then hit.fn() end
 end
 local popup=node('Popup','Frame',f.phone.board,{Visible=false});f.popup=popup
 local container=node('Container','Frame',popup)
 local username=node('Username','TextLabel',container,{Text=''})
 local action=node('Action','Frame',container)
 f.tradeButton=node('Trade','TextButton',action,{Text='Trade'})
 local close=node('Close','TextButton',container,{Text='Close'})
 local list=node('PlayerList','Frame',f.phone.container)
 local tg=node('TradeGUI_Phone','ScreenGui',f.pg)
 local tc=node('Container','Frame',tg)
 f.nativeTrade=node('Trade','Frame',tc,{Visible=false})
 local their=node('TheirOffer','Frame',f.nativeTrade)
 f.partner=node('Username','TextLabel',their,{Text=''})
 f:register(close,850,200,function() popup.Visible=false end)
 function f:openTrade(p)
  self.phone.sending.Visible=false;self.popup.Visible=false
  self.partner.Text='('..p.Name..')';self.nativeTrade.Visible=true
 end
 function f:closeTrade() self.nativeTrade.Visible=false;self.transaction=nil end
 f:register(f.tradeButton,700,300,function()
  assert(f.selected,'Trade click missing exact selected player')
  popup.Visible=false
  if f.response=='pending' then
   f.phone.sending.Visible=true;f.phone.sending.children.Username.Text=f.selected.Name
  elseif f.response=='open' then f:openTrade(f.selected) end
 end)
 f:register(f.phone.sending.children.Cancel,800,500,function() f.phone.sending.Visible=false end)
 local receiving=f.phone.request.children.ReceivingRequest
 node('Username','TextLabel',receiving,{Text=''})
 local incomingDecline=node('Decline','TextButton',receiving,{Text='Decline'})
 node('Accept','TextButton',receiving,{Text='Accept'})
 f:register(incomingDecline,800,550,function() receiving.Visible=false;f.incomingClicks=(f.incomingClicks or 0)+1 end)
 local baseAdd=f.add
 function f:add(name,owned)
  local p=baseAdd(self,name)
  self.records[p.UserId].inv=parse({Weapons={Owned=owned or {Batwing=1}}})
  local row=node(name,'Frame',list)
  local uf=node('UsernameFrame','Frame',row)
  local label=node('PlayerLabel','TextLabel',uf,{Text=name})
  self:register(label,100,100+p.UserId*30,function()
   self.selected=p;username.Text=p.Name;popup.Visible=true
   self.cardClicks=(self.cardClicks or 0)+1
  end)
  if self.started then self.players.PlayerAdded:Fire(p) end
  return p
 end
 local profile={};for k,v in pairs(SNAPSHOT) do profile[k]=v end
 profile.isFresh=function() return not f.expired and SNAPSHOT.isFresh(SNAPSHOT.observedAtEpoch) end
 f.scanner.getVerificationState=function(uid)
  return {player=f.players:GetPlayerByUserId(uid),record=f.records[uid],scanning=f.scanning==uid}
 end
 f.scanner.hasActiveTradeLifecycle=function() return f.transaction~=nil end
 f.scanner.setRequestState=function(p,state,reason) f.rows[p.UserId]={state=state,reason=reason} end
 f.scanner.setStatus=function(text) f.status=text end
 local function context()
  return {job=f.game.JobId,gui=f.lp:FindFirstChildOfClass('PlayerGui'),outgoing=f.env.PDIDDLER_OUTGOING_CONTROLLER,
   session=f.env.PDIDDLER_OUTGOING_SESSION,part4Session=f.env.PDIDDLER_PART4_SESSION,
   transaction=f.transaction,phase=f.transaction and 'negotiating' or 'idle',
   activeTarget=f.controller and f.controller.state.active,
   allowed=not f.nativeTrade.Visible and not f.phone.sending.Visible and not receiving.Visible and not f.transaction and not f.expired,
   reason='native-ui-or-transaction'}
 end
 f.e=ELIGIBILITY.new({scanner=f.scanner,profile=profile,strict=POLICY,feasibility=FEASIBILITY,
  now=function() return f.now end,context=context,readOwn=function()
   f.reads=f.reads+1;f.task.wait(.03)
   if f.onRead then f.onRead(f.reads) end
   return f.own
  end,render=function(p,state,reason)
   if f.controller and f.controller.state.active==p then return false end
   f.rows[p.UserId]={state=state,reason=reason}
  end})
 f.scanner.refreshOutgoingInventory=function() return f.e:refresh(false) end
 f.scanner.getOutgoingEligibility=function(p) local a=f.e:assess(p);return a.state,a.reason,a.witness end
 f.scanner.authorizeOutgoing=function(p) return f.e:authorize(p) end
 f.scanner.prepareOutgoing=function(p,token) return f.e:prepare(p,token) end
 function f:start()
  self.started=true;self.module=NEW_OUTGOING(self);self.controller=self.module.run(self.scanner)
  return self.controller
 end
 function f:count(p) local n=0;for _,r in ipairs(self.requests) do if r.player==p then n=n+1 end end;return n end
 return f
end
local total=0
local function test(name,fn) fn();total=total+1;print('PASS '..name) end

test('complete outgoing worker skips Seer3 and owns one reachable request for15 seconds',function()
 local f=fixture();local low=f:add('allykyli45',{Seer=1});local rich=f:add('Keongot_motion350',{Batwing=1,Luger=1})
 f:start();f:advance(10)
 assert(f:count(low)==0,'Seer3 physically requested by production rotation')
 assert(f:count(rich)==1 and f.controller.state.processed[rich.UserId]=='trade-tapped')
 assert(f.controller.state.uncertainOutgoing and f.env.PDIDDLER_OUTGOING_BUSY_SESSION~=nil)
 local sentAt=f.requests[1].at
 f:advance(sentAt+14.99)
 assert(f.controller.state.uncertainOutgoing and f.controller.state.processed[rich.UserId]=='trade-tapped','response ownership ended before15 seconds')
 f:advance(sentAt+15.5)
 assert(f.controller.state.processed[rich.UserId]=='uncertain-timeout')
 assert(f.controller.state.uncertainTimeouts==1 and f.controller.state.accepted==0)
 assert(f.controller.state.processed[low.UserId]==nil and not f.controller.state.uncertainOutgoing)
 f:advance(50);assert(f:count(low)==0 and f:count(rich)==1,'processed target retried')
 assert(f.reads>=2 and f.cardClicks==1,'real preparation/navigation did not run')
end)
test('native pending request is cancelled after15 seconds and marked ignored once',function()
 local f=fixture();local p=f:add('Pending_Target');f.response='pending';f:start();f:advance(20)
 assert(f:count(p)==1 and not f.phone.sending.Visible)
 assert(f.controller.state.processed[p.UserId]=='ignored' and f.controller.state.ignored==1)
 f:advance(45);assert(f:count(p)==1 and f.controller.state.accepted==0)
end)
test('native trade opening pauses rotation and closure resumes toward a newly joined target',function()
 local f=fixture();local p=f:add('Accepted_Target');f.response='open';f:start();f:advance(5)
 assert(f:count(p)==1 and f.controller.state.paused and f.controller.state.processed[p.UserId]=='trade-open')
 local nextPlayer=f:add('New_Target');f:advance(15)
 assert(f:count(nextPlayer)==0 and f.controller.state.paused,'rotation ran inside native trade')
 f:closeTrade();f.response=nil;f:advance(25)
 assert(not f.controller.state.paused and f:count(nextPlayer)==1,'closed trade did not resume/new player missed')
 assert(f:count(p)==1 and f.controller.state.accepted==1,'request-open state mistaken for repeated/completed trade')
end)
test('fresh own inventory changing during actual card preparation aborts before Trade input',function()
 local f=fixture();local p=f:add('Own_Changed',{Batwing=1})
 f.onRead=function(count) if count==2 then f.own=parse({Weapons={Owned={Batwing=1}}}) end end
 f:start();f:advance(10)
 assert(f.cardClicks==1 and f.reads>=2,'actual navigation/fresh own read omitted')
 assert(f:count(p)==0 and f.controller.state.processed[p.UserId]==nil,'changed own evidence allowed request or marked processed')
 assert(f.e:assess(p).state=='unprofitable')
end)
test('opponent inventory changing during actual fresh read aborts without processing',function()
 local f=fixture();local p=f:add('Opponent_Changed',{Batwing=1})
 f.onRead=function(count) if count==2 then f.records[p.UserId].inv=parse({Weapons={Owned={Seer=1}}}) end end
 f:start();f:advance(10)
 assert(f.cardClicks==1 and f:count(p)==0 and f.controller.state.processed[p.UserId]==nil)
 assert(f.e:assess(p).state=='unprofitable')
end)
test('incoming request remains secondary and outgoing rotation continues',function()
 local f=fixture();local p=f:add('Outgoing_Target')
 local incoming=f.phone.request.children.ReceivingRequest
 incoming.Visible=true;incoming.children.Username.Text=p.Name
 f:start();f:advance(10)
 assert(f.incomingClicks==1 and not incoming.Visible and f:count(p)==1)
 assert(f.controller.state.incomingDeclined==1)
end)
print('TOTAL '..total..' complete outgoing runtime tests')
