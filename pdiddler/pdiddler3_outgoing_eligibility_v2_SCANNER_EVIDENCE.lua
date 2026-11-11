-- Outgoing evidence with independent opponent proof and bounded verification.
-- Scanner presentation may observe evidence during a global hold; authorization never bypasses it.
local M={}
local fields={'job','gui','outgoing','session','part4Session','transaction','phase','activeTarget'}
local function contextCopy(c)
 local out={};for _,k in ipairs(fields) do out[k]=c[k] end;out.allowed=c.allowed;out.reason=c.reason;return out
end
local function same(a,b)
 if not a or not b or a.allowed~=true or b.allowed~=true then return false end
 for _,k in ipairs(fields) do if a[k]~=b[k] then return false end end
 return true
end
function M.new(o)
 local now=o.now or os.clock
 local self={history={},own=nil,ownAt=nil,nextRead=0,readEpisode=nil,reading=false}
 local function context() return contextCopy(o.context()) end
 -- Market quote freshness is not request/contact eligibility. The only
 -- authority granted here is a short-lived, context-bound request token.
 function self:invalidate() self.own=nil;self.ownAt=nil end
 function self:refresh(force)
  local before=context();if not before.allowed then return false,before.reason or 'global-hold' end
  local t=now()
  if self.reading then return false,'own-inventory-busy' end
  if not force and t<self.nextRead then return self.own~=nil,'read-not-due' end
  self.readEpisode=self.readEpisode or t
  local elapsed=t-self.readEpisode
  -- Advance to the next future slot before yielding; missed slots never burst.
  if elapsed<5 then self.nextRead=self.readEpisode+5
  elseif elapsed<15 then self.nextRead=self.readEpisode+15
  else self.nextRead=self.readEpisode+(math.floor(elapsed/45)+1)*45 end
  self.reading=true
  local version=o.profile.version
  local ok,inv,why=pcall(o.readOwn)
  self.reading=false
  if not same(before,context()) or o.profile.version~=version then
   self:invalidate();return false,'own-read-context-changed'
  end
  if not ok or type(inv)~='table' or type(inv.fingerprint)~='string' or why then
   self:invalidate();return false,why or 'own-read-unavailable'
  end
  local contact,validationWhy=o.feasibility.validateContactInventory(inv)
  if not contact or contact.eligibleTypes==0 then
   self:invalidate();return false,validationWhy or 'no-client-eligible-owned-weapons'
  end
  self.own=inv;self.ownAt=now();self.readEpisode=nil;self.nextRead=now()+5
  return true
 end
 local function history(p)
  local h=self.history[p]
  if not h then h={};self.history[p]=h end
  return h
 end
 function self:assess(p)
  local h=history(p);local c=context();local a={state='unknown',reason='inventory-unavailable',player=p}
  -- P3 contact readiness does not import priced market or checker ID claims.
  -- True transaction/world/ownership holds still apply, including to physical
  -- request authorization. An expired price alone is not an eligibility veto.
  if not c.allowed then a.globalHold=true;a.globalReason=c.reason or 'global-hold' end
   local v=o.scanner.getVerificationState(p.UserId)
   local rec=v and v.record
   if not v or v.player~=p or (rec and rec.player~=p) then a.reason='player-or-record-unavailable'
   elseif v.scanning or v.retryScheduled then a.reason='inventory-scan-active-or-retrying'
   elseif not rec or rec.state=='unknown' then a.reason='inventory-unverified'
   elseif rec.state~='whitelist' and rec.state~='blacklist' then a.reason='inventory-unverified'
   elseif type(rec.inv)~='table' or type(rec.inv.fingerprint)~='string' then a.reason='inventory-fingerprint-unavailable'
   else
    local contact,why=o.feasibility.validateContactInventory(rec.inv)
    if not contact then a.reason=why or 'inventory-unverified'
    elseif rec.state=='blacklist' and contact.eligibleTypes>0 then a.reason='inventory-state-inconsistent'
    elseif rec.state=='whitelist' and contact.eligibleTypes==0 then a.reason='inventory-state-inconsistent'
    elseif rec.state=='blacklist' and contact.eligibleTypes==0 then
     -- A fully scanned zero-eligible opponent is not a request target.
     -- This classification is NOT a market-value or profit conclusion.
     a.state='unprofitable';a.reason='no-eligible-opponent-items';a.theirFingerprint=rec.inv.fingerprint
    elseif not c.allowed then a.reason='own-proof-paused:'..a.globalReason
    elseif not self.own or not self.ownAt or now()-self.ownAt>=10 or self.reading then a.reason='own-proof-pending'
    else
     a.state,a.reason,a.witness=o.feasibility.evaluateContact(self.own,rec.inv)
     a.theirFingerprint=rec.inv.fingerprint;a.ownFingerprint=self.own.fingerprint
    end
   end
  if a.state=='unknown' then
   if not a.globalHold then
    h.unknownSince=h.unknownSince or now()
    a.verificationPending=now()-h.unknownSince<30
    if not a.verificationPending then a.cause=a.reason;a.reason='verification-unavailable' end
   end
  else
   h.unknownSince=nil
   if a.state=='reachable' and h.conclusive~='reachable' then h.discovery=true end
   h.conclusive=a.state
  end
  local message=a.reason..(a.cause and (' ('..a.cause..')') or '')
  if h.rendered~=a.state..':'..message then
   local rendered=not o.render or o.render(p,a.state,message)~=false
   if rendered then h.rendered=a.state..':'..message end
  end
  return a
 end
 function self:queue(players,processed)
  local q={available=false,discovered=false,verificationPending=false,exhausted=false,
   counts={reachable=0,unprofitable=0,unknown=0}}
  local c=context()
  if not c.allowed then q.globalHold=c.reason or 'global-hold' end
  local present={}
  for _,p in ipairs(players) do
   present[p]=true
   if not processed[p.UserId] then
    local a=self:assess(p);local h=history(p)
    q.counts[a.state]=q.counts[a.state]+1
    if a.globalHold then q.globalHold=a.globalReason or q.globalHold or a.reason end
    if a.state=='reachable' and not a.globalHold then q.available=true end
    if a.verificationPending then q.verificationPending=true end
    if h.discovery and not q.globalHold then q.discovered=true;h.discovery=nil end
   end
  end
  for p in pairs(self.history) do if not present[p] then self.history[p]=nil end end
  q.exhausted=not q.globalHold and not q.available and not q.verificationPending
  return q
 end
 function self:authorize(p)
  local a=self:assess(p)
  if a.state~='reachable' then return nil,a.reason end
  return {player=p,userId=p.UserId,ownFingerprint=a.ownFingerprint,theirFingerprint=a.theirFingerprint,
   contactOnly=true,authorizesTrade=false,authorizesAccept=false,
   version=o.profile.version,context=context()}
 end
 function self:validate(p,token)
  if type(token)~='table' or token.contactOnly~=true or token.authorizesTrade~=false
   or token.authorizesAccept~=false or p~=token.player or p.UserId~=token.userId
   or o.profile.version~=token.version or not same(token.context,context()) then
   return false,'authorization-context-changed'
  end
  local a=self:assess(p)
  return a.state=='reachable' and a.ownFingerprint==token.ownFingerprint and a.theirFingerprint==token.theirFingerprint,
   'authorization-evidence-changed'
 end
 function self:prepare(p,token)
  local ok,why=self:validate(p,token);if not ok then return nil,why end
  ok,why=self:refresh(true);if not ok then return nil,why end
  ok,why=self:validate(p,token);if not ok then return nil,why end
  -- Caller invokes this after all input preparation, with no yield before mouse-down.
  return function() return self:validate(p,token) end
 end
 return self
end
function M.clock(start)
 local c={last=start,elapsed=0,wasExhausted=false}
 function c:step(t,q)
  if q.discovered then self.elapsed=0 end
  if q.exhausted and self.wasExhausted then self.elapsed=self.elapsed+math.max(0,t-self.last) end
  self.last=t;self.wasExhausted=q.exhausted==true
  return q.exhausted and self.elapsed>=45
 end
 return c
end
return M
