-- Stage23: PURE candidate-to-permit validation. No Roblox/network/actions.
-- Stage17 review-only result is NEVER an execution permit by itself.
local M={}
local function validId(s)
 if type(s)~="string" then return false end
 local p,n=s:match("^(%a+):(%d+):checker%-id$")
 return (p=="godly" or p=="ancient" or p=="chroma") and n and #n<=8
end
local function key(rows)
 if type(rows)~="table" or #rows<1 or #rows>4 then return nil end
 local keys,total,seen={},0,{}
 for _,r in ipairs(rows) do
  if type(r)~="table" or not validId(r.id)
    or type(r.qty)~="number" or r.qty<1 or r.qty>4 or r.qty%1~=0
    or seen[r.id] then return nil end
  seen[r.id]=true;total=total+r.qty
  if total>4 then return nil end
  keys[#keys+1]=r.id.."#"..r.qty
 end
 table.sort(keys)
 return table.concat(keys,"|")
end
local function offered(o,diag)
 if type(diag)~="table" or type(diag.theirItems)~="table"
    or #diag.theirItems~=o.theirSlots then return nil end
 local rows={}
 for _,r in ipairs(diag.theirItems) do
  if type(r)~="table" or type(r.checkerId)~="string" or
   not r.checkerId:match("^%d+$") then return nil end
  rows[#rows+1]={id=tostring(r.page)..":"..r.checkerId..":checker-id",qty=r.qty}
 end
 return key(rows)
end
local function ready(s,o)
 return type(o)=="table" and o.session==s.session and o.tradeOpen==true
   and o.contextOK==true and o.marketFresh==true
   and o.theirResolved==true and o.ourAccepted==false
   and o.theirAccepted==false and o.ourSlots==0
   and type(o.theirSlots)=="number" and o.theirSlots>0
   and type(o.ourSig)=="string" and o.ourSig~=""
   and type(o.theirSig)=="string" and o.theirSig~=""
end
local function inspect(s,o,diag,ctx,candidate)
 if not ready(s,o) or type(ctx)~="table" or ctx.session~=s.session
  or type(ctx.market)~="table" or type(ctx.rawOwn)~="table"
  or type(ctx.ownInventory)~="table"
  or type(ctx.opponentInventory)~="table" then return nil end
 local market=ctx.market
 local current=s.source()
 local now=s.wall()
 if type(current)~="string" or current=="" or
    market.sourceId~=current or market.verified~=true
    or type(now)~="number" or now%1~=0
    or ctx.now~=now or type(market.observedAt)~="number"
    or type(market.validUntil)~="number"
    or now<market.observedAt or now>=market.validUntil then return nil end
 if type(candidate)~="table" or type(candidate.give)~="table"
    or #candidate.give~=1 or candidate.give[1].qty~=1 then return nil end
 local a=key(candidate.give)
 local b=key(candidate.receive)
 if not a or not b or b~=offered(o,diag) then return nil end
 local given=candidate.give[1]
 local physical=ctx.rawOwn[given.id]
 if type(physical)~="table" or type(physical.id)~="string"
    or physical.id=="" or type(physical.checkerId)~="string"
    or physical.page..":"..physical.checkerId..":checker-id"~=given.id
    or type(physical.qty)~="number" or physical.qty<1
    or (physical.type~="Knife" and physical.type~="Gun")
    or physical.cat~="Weapons"
    or type(ctx.ownInventory[given.id])~="number"
    or ctx.ownInventory[given.id]<1 then return nil end
 local review=s.reviewer.assess(ctx,candidate)
 if type(review)~="table" or review.case=="BLOCKED"
  or review.reviewOnly~=true or review.quoteSafe~=false
  or review.authorizesTrade~=false or review.authorizesAccept~=false
  or type(review.ourGainCents)~="number"
  or type(review.sellerSurplusCents)~="number" then return nil end
 return {raw=physical,review=review,
   digest=market.sourceId.."|"..market.observedAt.."|"..market.validUntil
    .."|"..(ctx.ownFingerprint or "").."|"..(ctx.opponentFingerprint or "")
    .."|"..a.."|"..b.."|"..review.ourGainCents.."|"..review.sellerSurplusCents,
   candidateKey=a.."=>"..b}
end
function M.new(cfg)
 assert(type(cfg)=="table" and type(cfg.session)=="string" and cfg.session~="")
 for _,name in ipairs({"context","source","wall","choose","approve"}) do
  assert(type(cfg[name])=="function","missing Stage23 "..name)
 end
 assert(type(cfg.reviewer)=="table" and type(cfg.reviewer.assess)=="function")
 return {session=cfg.session,context=cfg.context,source=cfg.source,
  wall=cfg.wall,choose=cfg.choose,approve=cfg.approve,reviewer=cfg.reviewer,
  issued=nil,used=false,closed=false,serial=0}
end
function M.next(s,o,diag,now)
 if s.closed or s.issued or not ready(s,o) then return nil end
 local ok,ctx=pcall(s.context)
 if not ok then return nil end
 local chosenOk,candidate=pcall(s.choose,o,diag,ctx)
 if not chosenOk then return nil end
 local pass,proof=pcall(inspect,s,o,diag,ctx,candidate)
 if not pass or not proof then return nil end
 local approved,stamp=pcall(s.approve,candidate,proof.review,ctx,o)
 if not approved or type(stamp)~="table" or stamp.allowed~=true
   or stamp.session~=s.session or stamp.ourSig~=o.ourSig
   or stamp.theirSig~=o.theirSig
   or stamp.source~=ctx.market.sourceId
   or stamp.candidateKey~=proof.candidateKey then return nil end
 if type(now)~="number" or now~=now or now<0 then return nil end
 s.serial=s.serial+1
 local raw=proof.raw
 local proposal={session=s.session,id=raw.id,page=raw.page,
  checkerId=raw.checkerId,qty=1,ourSig=o.ourSig,
  theirSig=o.theirSig,serial=s.serial}
 s.issued={proposal=proposal,proof=proof,stamp=stamp,at=now,
   candidate=candidate,diagnostics=diag}
 return proposal
end
function M.validate(s,proposal,o,now)
 local p=s.issued
 if s.closed or s.used or not p or proposal~=p.proposal
  or type(now)~="number" or now<p.at or now-p.at>.25
  or not ready(s,o) or proposal.ourSig~=o.ourSig
  or proposal.theirSig~=o.theirSig then return false end
 local ok,ctx=pcall(s.context)
 if not ok then return false end
 local good,proof=pcall(inspect,s,o,p.diagnostics,ctx,p.candidate)
 if not good or not proof or proof.digest~=p.proof.digest then return false end
 s.used=true
 return true
end
function M.stop(s)
 if type(s)=="table" then s.closed=true;s.issued=nil end
end
return M
