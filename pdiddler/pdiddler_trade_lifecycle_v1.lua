-- One transaction owner. Native methods are injected by a pinned, evidenced
-- adapter; no environment flag or inferred event can establish that contract.
local L={}
local function copy(t) local c={};for k,v in pairs(t or {}) do c[k]=v end;return c end
local function cents(n)
 if type(n)~='number' or n~=n or n<=0 or n==math.huge then return nil end
 local c=math.floor(n*100+.5);if math.abs(c-n*100)>1e-6 then return nil end;return c
end
local function countsKey(snapshot)
 if type(snapshot)~='table' or snapshot.complete~=true or type(snapshot.counts)~='table' then return nil end
 local out={}
 for id,q in pairs(snapshot.counts) do
  if type(id)~='string' or id=='' or type(q)~='number' or q~=q or q<0 or q%1~=0 or q==math.huge then return nil end
  out[#out+1]=#id..':'..id..':'..q
 end
 table.sort(out);return table.concat(out,'|')
end
local function key(p)
 local out={};for _,k in ipairs({'id','job','epoch','partner','root','gui','version','ourSig','theirSig','ourTotal','theirTotal'}) do
  local s=tostring(p[k]);out[#out+1]=#s..':'..s
 end;return table.concat(out,'|')
end
function L.new(options)
 local o=options or {};local now=o.now or os.clock;local native=o.native
 local approved=type(native)=='table' and native.approved==true and native.placeId==142823291
  and type(native.evidenceId)=='string' and native.evidenceId~=''
  and native.acceptControlVerified==true and native.completionVerified==true and native.inventoryVerified==true
  and type(native.read)=='function' and type(native.readInventory)=='function'
  and type(native.classifyCompletion)=='function' and type(native.bind)=='function'
  and type(o.verifier)=='table' and type(o.verifier.reconcile)=='function' and type(o.policy)=='table'
 local self={state={phase='idle',completed=0,closed=0,attempts=0,mutations=0,startedAt=now()},
  capabilities={autoAccept=approved,completion=approved and o.verifier~=nil,discord=false},
  blocker=approved and nil or 'native-contract-unverified'}
 function self:hold(reason)
  if self.state.phase=='unconfirmed' then return false,reason end
  self.state.phase='unconfirmed';self.state.reason=reason
  if o.onHold then pcall(o.onHold,reason) end;return false,reason
 end
 function self:canStartWork()
  return self.state.active==nil and self.state.phase~='unconfirmed'
 end
 function self:setOutbox(outbox)
  if self.state.active then return false,'active-transaction' end
  o.outbox=outbox;return true
 end
 function self:begin(context)
  if not self:canStartWork() then return false,'transaction-already-owned' end
  if type(context)~='table' or context.job~=o.jobId then return false,'transaction-context-invalid' end
  for _,k in ipairs({'id','epoch','partner','root','gui','version'}) do if context[k]==nil then return false,'transaction-context-invalid' end end
  local a=copy(context);a.actions={};a.openedAt=now()
  self.state.active=a;self.state.phase='negotiating';self.state.attempts=self.state.attempts+1
  if approved then
   local ok,before=pcall(native.readInventory,copy(context),'before')
   if not ok or not countsKey(before) or before.id~=a.id or before.job~=a.job or before.epoch~=a.epoch then
    return self:hold('complete-before-inventory-unavailable')
   end
   local liveOK,current=pcall(function() return (not o.live or o.live()) and type(context.isCurrent)=='function' and context.isCurrent() end)
   if self.state.active~=a or not liveOK or current~=true then
    if a.acceptanceObserved then return self:hold('accepted-context-changed-during-before-read') end
    self.state.active=nil;self.state.phase='closed-unconfirmed'
    return false,'transaction-context-changed-during-inventory'
   end
   a.before=copy(before.counts);a.beforeComplete=true
  end
  return true
 end
 local function valid(p)
  local a=self.state.active
  if not a or type(p)~='table' or self.state.phase=='unconfirmed' or (o.live and not o.live()) then return false end
  for _,k in ipairs({'id','job','epoch','partner','root','gui','version'}) do if p[k]~=a[k] then return false end end
  local currentOK,current=pcall(function() return not a.isCurrent or a.isCurrent() end)
  if not currentOK or current~=true then return false end
  local profile=o.profile;local ok,fresh=pcall(function() return profile and profile.version==a.version and profile.isFresh() end)
  local ours,theirs=cents(p.ourTotal),cents(p.theirTotal)
  return ok and fresh==true and ours and theirs and theirs-ours>=1500
   and type(p.ourSig)=='string' and p.ourSig~='' and type(p.theirSig)=='string' and p.theirSig~=''
   and p.plannedOurSig==p.ourSig and p.valuedTheirSig==p.theirSig
   and p.identitiesVerified==true and p.quantitiesVerified==true and p.changing==false
 end
 function self:accepted(id)
  local a=self.state.active;if not a or a.id~=id then return false end
  a.acceptanceObserved=true;self.state.phase='accepted';return true
 end
 function self:consider(proof,click,revalidate)
  if not approved then return false,'native-contract-unverified' end
  if not valid(proof) then
   if self.state.active then self.state.active.readyKey=nil end
   return false,'offer-proof-invalid'
  end
  local a=self.state.active;local before=key(proof)
  local ok,control=pcall(native.read,proof.root,proof)
  local read,fresh=pcall(function() return revalidate and revalidate() or proof end)
  if not read then a.readyKey=nil;return false,'proof-read-failed' end
  if not ok or type(control)~='table' or control.ready~=true or control.control==nil
   or not valid(fresh) or key(fresh)~=before then a.readyKey=nil;return false,'native-control-or-context-changed' end
  local stage=control.stage
  if stage~='accept' and stage~='confirm' then a.readyKey=nil;return false,'unknown-native-stage' end
  if stage=='accept' and fresh.ourAccepted~=false then return false,'already-accepted-or-unknown' end
  if stage=='confirm' and (fresh.ourAccepted~=true or fresh.theirAccepted~=true) then return false,'acceptance-pair-unverified' end
  if a.approvedKey and a.approvedKey~=before then return self:hold('approval-offer-changed') end
  local actionKey=stage..'|'..before
  if a.actions[actionKey] then return false,'action-already-consumed' end
  if a.readyKey~=actionKey then a.readyKey=actionKey;a.readySince=now();return false,'final-verification-second' end
  if now()-a.readySince<1 then return false,'final-verification-second' end
  read,fresh=pcall(function() return revalidate and revalidate() or proof end)
  if not read then a.readyKey=nil;return false,'proof-read-failed' end
  if not valid(fresh) or key(fresh)~=before then a.readyKey=nil;return false,'final-proof-changed' end
  -- Consume before the action, including a lost acknowledgement or exception.
  a.actions[actionKey]=true;a.approvedKey=before;a.acceptanceObserved=true
  a.ourSig=fresh.ourSig;a.theirSig=fresh.theirSig;a.give=fresh.give;a.receive=fresh.receive
  a.submittedAt=now();self.state.phase='submitted'
  a.submission={verified=true,atEpoch=(o.wallTime or os.time)(),id=a.id,job=a.job,epoch=a.epoch,
   partner=a.partner,ourSig=a.ourSig,theirSig=a.theirSig,version=a.version}
  local sent,result=pcall(click,control.control,stage)
  if not sent or result~=true then return self:hold('native-action-outcome-unconfirmed') end
  return true,'native-action-submitted'
 end
 function self:close(id,reason)
  local a=self.state.active;if not a or a.id~=id then return false,'stale-transaction' end
  if a.closed then return false,'close-already-observed' end
  a.closed=true;a.closedAt=now();self.state.closed=self.state.closed+1
  if a.acceptanceObserved then
   if self.capabilities.completion then self.state.phase='reconciling';return false,'reconciliation-pending' end
   return self:hold('accepted-close-requires-native-completion-and-raw-reconciliation')
  end
  self.state.active=nil;self.state.phase='closed-unconfirmed';self.state.reason=reason
  return true,'closed-without-completion-claim'
 end
 function self:settle(event,after)
  local a=self.state.active
  if not self.capabilities.completion or not a or not a.acceptanceObserved or type(event)~='table' or event.kind~='completed' then return false,'completion-contract-unverified' end
  if a.settling then return false,'settlement-in-progress' end
  a.settling=true
  local report=a.completedReport
  if not report then
   local ok,value,why=pcall(o.verifier.reconcile,a,event,after,o.profile,o.policy)
   if not ok then a.settling=false;return self:hold('completion-verifier-failed') end
   if not value then a.settling=false;return false,why end
   report=value;a.completedReport=report;a.completedInventory=after
   self.state.completed=self.state.completed+1;self.state.lastReport=report;self.state.inventory=after
   self.state.actualOutcome='completed'
  end
  if o.outbox and not a.reportPersisted then
   local saved,result=pcall(o.outbox.enqueue,report)
   if not saved or result~=true then
    a.settling=false;self.state.deliveryState='not-persisted'
    return self:hold('verified-completion-report-not-persisted')
   end
   a.reportPersisted=true
  end
  a.settling=false;self.state.deliveryState=o.outbox and 'persisted' or 'reporting-unavailable'
  self.state.active=nil;self.state.phase='completed';self.state.reason='exact-raw-delta-reconciled'
  return true,report
 end
 function self:poll()
  local a=self.state.active
  if not approved or not a or not a.acceptanceObserved then return false end
  if o.live and not o.live() then return self:hold('outcome-session-changed') end
  if now()-(a.closedAt or a.submittedAt or a.openedAt)>15 then return self:hold('completion-observation-timeout') end
  if not a.pendingEvent or a.readBusy or (a.nextRead and now()<a.nextRead) then return false end
  a.readBusy=true
  local ok,after=pcall(native.readInventory,copy(a),'after')
  a.readBusy=false;a.nextRead=now()+.5
  if self.state.active~=a then return false,'stale-inventory-response' end
  local fingerprint=ok and countsKey(after)
  if not fingerprint or after.id~=a.id or after.job~=a.job or after.epoch~=a.epoch then return false,'after-inventory-unverified' end
  if fingerprint==a.afterKey then a.stableReads=(a.stableReads or 0)+1 else a.afterKey=fingerprint;a.stableReads=1 end
  if a.stableReads<2 then return false,'awaiting-stable-inventory' end
  after=copy(after);after.stableReads=a.stableReads
  return self:settle(a.pendingEvent,after)
 end
 if approved then
  local ok,binding=pcall(native.bind,function(raw)
   local a=self.state.active
   if not a or not a.acceptanceObserved then return end
   local read,event=pcall(native.classifyCompletion,raw)
   if not read or type(event)~='table' or event.kind~='completed' then return end
   for _,field in ipairs({'id','job','epoch','partner','ourSig','theirSig'}) do if event[field]~=a[field] then return end end
   a.pendingEvent=copy(event)
  end)
  if not ok or not binding then approved=false;self.capabilities.autoAccept=false;self.capabilities.completion=false;self.blocker='native-observer-unavailable' end
  self.binding=binding
 end
 function self:stop()
  if self.binding and type(self.binding.Disconnect)=='function' then pcall(self.binding.Disconnect,self.binding) end
  if self.state.active then self:hold('transaction-owner-stopped') end
 end
 return self
end
return L
