-- Stage 22: single-copy ADD offer transaction, pure logic.
-- No Roblox APIs. No default strategy permit or native action. No Accept.
-- A separate source-verified planner MUST inject validatePermit; Stage17
-- reviewOnly output is not such a permit.
local M={}
local function int(n,a,b)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
   and n==math.floor(n) and n>=a and n<=b
end
local function clock(t)
 return type(t)=="number" and t==t and t>=0 and t<math.huge
end
local function stop(s,reason)
 s.mode="STOPPED";s.pending=nil;s.reason=reason
 return "STOP",reason
end
local function escalate(s,reason)
 s.mode="ESCALATE";s.reason=reason
 -- Caller must enter defensive HOLD/withdrawal; never repeat uncertain ADD.
 return "ESCALATE",reason
end
local function counts(o)
 if type(o)~="table" or o.tradeOpen~=true or o.contextOK~=true
   or o.marketFresh~=true or o.theirResolved~=true
   or o.ourAccepted~=false or o.theirAccepted~=false
   or type(o.ourSig)~="string" or o.ourSig==""
   or type(o.theirSig)~="string" or o.theirSig==""
   or not int(o.ourSlots,0,4) or not int(o.theirSlots,1,4)
   or type(o.ownItems)~="table" or #o.ownItems~=o.ourSlots then
    return nil,"trade-or-market-proof-unavailable"
 end
 local out,slots,seen={}, {}, {}
 for _,r in ipairs(o.ownItems) do
  if type(r)~="table" or not int(r.slot,1,4) or seen[r.slot]
      or type(r.id)~="string" or r.id==""
      or not int(r.qty,1,1000000) then return nil,"own-offer-invalid" end
  seen[r.slot]=true
  out[r.id]=(out[r.id] or 0)+r.qty
  slots[#slots+1]=r.slot
 end
 return out,nil
end
local function same(a,b)
 for k,v in pairs(a) do if b[k]~=v then return false end end
 for k,v in pairs(b) do if a[k]~=v then return false end end
 return true
end
function M.new(session,opts)
 assert(type(session)=="string" and session~="","session required")
 opts=opts or {}
 assert(type(opts.validatePermit)=="function",
    "independent source-backed strategy permit validator required")
 local timeout=opts.verifySeconds or 1.5
 local dispatch=opts.dispatchSeconds or 0.35
 assert(clock(timeout) and timeout>0 and timeout<=5,"verify timeout invalid")
 assert(clock(dispatch) and dispatch>0 and dispatch<=1,"dispatch timeout invalid")
 return {session=session,validatePermit=opts.validatePermit,
   verifySeconds=timeout,dispatchSeconds=dispatch,serial=0,
   mode="IDLE",pending=nil,reason="ready"}
end
function M.prepare(s,proposal,o,now)
 assert(type(s)=="table" and s.session,"executor required")
 if s.mode=="STOPPED" then return "STOP","already-stopped" end
 if s.mode=="ESCALATE" then return "ESCALATE",s.reason end
 if s.mode~="IDLE" then return "HOLD","previous-offer-not-verified" end
 if not clock(now) then return escalate(s,"invalid-time") end
 local own,why=counts(o)
 if not own or o.session~=s.session then return "HOLD",why or "session-changed" end
 if o.ourSlots>=4 then return "HOLD","no-free-trade-slot" end
 if type(proposal)~="table" or proposal.session~=s.session
     or type(proposal.id)~="string" or proposal.id==""
     or type(proposal.page)~="string"
     or (proposal.page~="godly" and proposal.page~="chroma"
            and proposal.page~="ancient")
     or type(proposal.checkerId)~="string"
     or not proposal.checkerId:match("^%d+$")
     or proposal.qty~=1
     or proposal.ourSig~=o.ourSig or proposal.theirSig~=o.theirSig then
    return "HOLD","proposal-incomplete-or-stale"
 end
 if own[proposal.id] then return "HOLD","stack-add-not-yet-native-verified" end
 -- In particular: simply handing in a Stage16/17 REVIEW output never
 -- creates authorization; absence of this independently supplied callback
 -- or a false result prevents all sends.
 local ok,authorized=pcall(s.validatePermit,proposal,o,now)
 if not ok or authorized~=true then return "HOLD","independent-permit-unverified" end
 s.serial=s.serial+1
 local intent={kind="ADD_ONE",token=s.serial,session=s.session,
   id=proposal.id,page=proposal.page,checkerId=proposal.checkerId,
   qty=1,ourSig=o.ourSig,theirSig=o.theirSig}
 local expected={}
 for k,v in pairs(own) do expected[k]=v end
 expected[proposal.id]=1
 s.pending={intent=intent,expected=expected,before=own,at=now}
 s.mode="RESERVED"
 return "DISPATCH",intent
end
function M.dispatched(s,intent,receipt,now)
 assert(type(s)=="table","executor required")
 if s.mode~="RESERVED" or not s.pending then
  return escalate(s,"no-reserved-intent")
 end
 local p=s.pending
 if type(intent)~="table" or intent~=p.intent or
    intent.session~=s.session or intent.token~=p.intent.token then
  return escalate(s,"intent-mismatch")
 end
 if not clock(now) or now<p.at or now-p.at>s.dispatchSeconds then
  return escalate(s,"dispatch-window-expired")
 end
 if type(receipt)~="table" or receipt.status~="SENT_ONCE"
    or receipt.attempted~=true then
  return escalate(s,"native-send-uncertain")
 end
 s.mode="SENT";p.sentAt=now
 return "WAIT","await-independent-inventory-offer-observation"
end
function M.observe(s,o,now)
 assert(type(s)=="table","executor required")
 if s.mode=="STOPPED" then return "STOP","already-stopped" end
 if s.mode=="ESCALATE" then return "ESCALATE",s.reason end
 if s.mode~="SENT" or not s.pending then return "HOLD","no-pending-insertion" end
 local p=s.pending
 if not clock(now) or now<p.sentAt then return escalate(s,"invalid-verification-time") end
 if type(o)~="table" or o.tradeOpen~=true
   or o.session~=s.session then return stop(s,"trade-closed-or-session-changed") end
 if o.theirSig~=p.intent.theirSig or o.ourAccepted~=false
   or o.theirAccepted~=false then return escalate(s,"quote-or-accepted-state-changed") end
 local actual,why=counts(o)
 if not actual then return escalate(s,"unverified-after-send:"..tostring(why)) end
 if same(actual,p.expected)
   and o.ourSig~=p.intent.ourSig
   and o.ourSlots<=4 then
    s.mode="IDLE";s.pending=nil;s.reason="native-add-confirmed-by-new-observation"
    return "VERIFIED",s.reason
 end
 if not same(actual,p.before) or o.ourSig~=p.intent.ourSig then
  return escalate(s,"unexpected-offer-mutation")
 end
 if now-p.sentAt>=s.verifySeconds then
  return escalate(s,"no-visible-add-confirmation")
 end
 return "HOLD","awaiting-offer-add-replication"
end
function M.stop(s)
 if type(s)=="table" then s.mode="STOPPED";s.pending=nil;s.reason="stopped" end
end
return M
