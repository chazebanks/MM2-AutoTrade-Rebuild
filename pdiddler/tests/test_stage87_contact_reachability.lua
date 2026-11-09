-- Stage87 actual Lua5.4 tests for REAL price-independent contact path and
-- REAL outgoing verification controller, copied from reviewed Stage51 source.
-- All local test names and inventories are synthetic; no Roblox/actions.
local folder="pdiddler"
local p3=assert(loadfile(folder.."/new_part4/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua"))()
local outgoing=assert(loadfile(folder.."/pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua"))()
local groups=0
local function test(name,fn)
 local ok,e=pcall(fn)
 if not ok then error("FAIL: "..name.." -> "..tostring(e)) end
 groups=groups+1
 print("PASS "..name)
end
local function clone(t)
 local x={}
 for k,v in pairs(t) do x[k]=type(v)=="table" and clone(v) or v end
 return x
end
local function item(id,qty,page)
 return {id=id,cat="Weapons",type="Knife",page=page or "godly",
         qty=qty or 1,name=nil,checkerId="UNPRICED",value=nil,
         checkerMappingAuthenticated=false}
end
local function own()
 return {fingerprint="synthetic_owned_fp",unmapped=0,badQty=0,unpriced=3,
         items={item("test_owned",2),item("test_chroma",1,"chroma")}}
end
local function their()
 return {fingerprint="synthetic_their_fp",unmapped=0,badQty=0,unpriced=1,
         items={item("test_opponent",1,"ancient")}}
end
local function context(allowed)
 return {job="test_job",gui={},outgoing={},session=1,part4Session=1,
 transaction=false,phase="SCANNING",activeTarget=false,
 allowed=allowed~=false,reason="test_hold"}
end
local function scenario()
 local player={UserId=456,Name="test_player"}
 local profile={version="STALE_SYNTHETIC_MARKET",isFresh=function()return false end}
 local s={own=own(),opponent=their(),allowed=true,reading=0,now=100}
 local ctx=context(true)
 local scanning=false
 local retry=false
 local record={player=player,state="whitelist",inv=s.opponent}
 local scanner={getVerificationState=function(uid)
  assert(uid==456)
  return {player=player,record=record,scanning=scanning,retryScheduled=retry}
 end}
 local obj=outgoing.new({
  profile=profile,feasibility=p3,strict={reprice=function()error("repricer may not run")end},
  scanner=scanner,context=function()return ctx end,
  readOwn=function()
   s.reading=s.reading+1
   if s.afterRead then s.afterRead() end
   return s.own
  end,now=function()return s.now end,
  render=function()return true end
 })
 return obj,s,player,record,ctx,profile,
        function(v)scanning=v end,function(v)retry=v end
end
local function noAuthority(w)
 assert(w.contactEvidenceOnly==true)
 assert(w.authorizesTrade==false)
 assert(w.authorizesAccept==false)
 assert(w.mayReportProfit==false)
 assert(w.maySendDiscordWebhook==false)
 assert(w.mayUseForStrategyLearning==false)
end

test("P3 old priced feasibility unchanged and still fails closed",function()
 local old=own()
 local p={isFresh=function()return false end}
 local valid,why=p3.validateInventory(old,p,{reprice=function()return old end})
 assert(valid==nil and why=="source-expired")
 local status=p3.evaluate(old,their(),p,{reprice=function()return old end})
 assert(status=="unknown")
end)
test("new P3 request contact does NOT read value/checkerId or stale profile",function()
 local a=own();local b=their()
 a.items[1].checkerId=nil;a.items[1].value=nil
 b.items[1].checkerId="UNVERIFIED";b.items[1].value=false
 local status,reason,w=p3.evaluateContact(a,b)
 assert(status=="reachable" and reason=="CLIENT_ELIGIBLE_FOR_CONVERSATION_ONLY")
 assert(w.pricesVerified==false and w.authenticatedOwnedInventory==false)
 noAuthority(w)
end)
test("chroma Ancient and Godly accepted as contact candidates, NOT priced",function()
 local x=own()
 local verified,reason=p3.validateContactInventory(x)
 assert(reason==nil and verified.eligibleTypes==2)
 assert(verified.fingerprint==x.fingerprint)
end)
test("legitimate no-eligible opponent never becomes reachable",function()
 local b=their();b.items={};b.unpriced=0
 local status,reason,w=p3.evaluateContact(own(),b)
 assert(status=="unprofitable" and reason=="no-eligible-weapons-for-conversation")
 noAuthority(w)
end)
test("exact raw strings, no numeric coercion or duplicate data",function()
 for _,change in ipairs({
  function(x)x.items[1].id=53 end,
  function(x)x.items[1].id="test_chroma" end,
  function(x)x.items[1].id="" end,
  function(x)x.items[1].id=string.rep("x",129) end,
  function(x)x.items[1].id="evil\nkey" end,
  function(x)x.items[1].cat="Misc" end,
  function(x)x.items[1].page="legendary" end,
  function(x)x.items[1].type="Pet" end,
  function(x)x.items[1].qty=1.5 end,
  function(x)x.items[1].qty=0 end,
  function(x)x.items[1].qty=math.huge end,
  function(x)x.items[1].qty="1" end,
  function(x)x.unmapped=1 end,
  function(x)x.badQty=1 end,
  function(x)x.unpriced="0" end,
  function(x)x.fingerprint="" end,
  function(x)x.items[4]=item("test_sparse") end,
  function(x)x.items[2]=nil end,
 }) do
  local x=own();change(x)
  local status=p3.evaluateContact(x,their())
  assert(status=="unknown","unsafe candidate accepted")
 end
end)
test("outgoing controller contact reachability despite stale market",function()
 local obj,state,player=scenario()
 local ok,why=obj:refresh(true)
 assert(ok==true,why)
 local a=obj:assess(player)
 assert(a.state=="reachable" and a.reason=="CLIENT_ELIGIBLE_FOR_CONVERSATION_ONLY")
 noAuthority(a.witness)
 local q=obj:queue({player},{})
 assert(q.available and q.counts.reachable==1 and q.globalHold==nil)
 local tok,reason=obj:authorize(player)
 assert(type(tok)=="table",reason)
 assert(tok.contactOnly==true and tok.authorizesTrade==false and tok.authorizesAccept==false)
 local valid,why2=obj:validate(player,tok);assert(valid==true,why2)
 local ready,why3=obj:prepare(player,tok);assert(type(ready)=="function",why3)
 assert(ready()==true)
 assert(state.reading==2)
end)
test("no price repricer called in new controller path",function()
 local o,s,p=scenario()
 local ok=o:refresh(true);assert(ok)
 assert(o:assess(p).state=="reachable")
end)
test("request token invalidated by scan fingerprint, no offer identity spoof",function()
 local o,s,p,rec=scenario();assert(o:refresh(true))
 local token=assert(o:authorize(p))
 rec.inv.fingerprint="changed_fp"
 local ok=o:validate(p,token)
 assert(not ok)
end)
test("request token invalidated by job/session/owner/readiness context",function()
 for _,field in ipairs({"job","gui","outgoing","session","part4Session",
  "transaction","phase","activeTarget"}) do
  local o,s,p,rec,ctx=scenario();assert(o:refresh(true))
  local token=assert(o:authorize(p))
  ctx[field]="changed"
  assert(o:validate(p,token)==false,field)
 end
 local o,s,p,rec,ctx=scenario();assert(o:refresh(true))
 local token=assert(o:authorize(p));ctx.allowed=false
 assert(o:validate(p,token)==false)
 assert(o:authorize(p)==nil)
end)
test("unknown or re-scanning opponent stays UNKNOWN, not blacklist",function()
 local o,s,p,rec,ctx,profile,setScan,setRetry=scenario();assert(o:refresh(true))
 setScan(true);assert(o:assess(p).state=="unknown")
 setScan(false);setRetry(true);assert(o:assess(p).state=="unknown")
 setRetry(false);rec.state="unknown";assert(o:assess(p).state=="unknown")
 rec.state="whitelist";rec.inv=their();rec.inv.badQty=3
 assert(o:assess(p).state=="unknown")
end)
test("scanner whitelist contradictions stay UNKNOWN",function()
 local o,s,p,rec=scenario();assert(o:refresh(true))
 rec.inv.items={};rec.inv.unpriced=0
 assert(o:assess(p).state=="unknown")
 rec.state="blacklist";rec.inv=their()
 assert(o:assess(p).state=="unknown")
end)
test("verified 0-item blacklist is unprofitable not unknown or sendable",function()
 local o,s,p,rec=scenario();assert(o:refresh(true))
 rec.state="blacklist"
 rec.inv.items={};rec.inv.unpriced=0
 local a=o:assess(p);assert(a.state=="unprofitable")
 assert(o:authorize(p)==nil)
end)
test("own inventory missing/invalid blocks outgoing even if opponent valid",function()
 local o,s,p=scenario();s.own.unmapped=1
 local ok=o:refresh(true);assert(not ok)
 assert(o:assess(p).state=="unknown")
end)
test("in-flight context changes reject own proof after read",function()
 local o,s,p,rec,ctx=scenario()
 s.afterRead=function()ctx.session=2 end
 local ok,why=o:refresh(true)
 assert(ok==false and why=="own-read-context-changed")
 assert(o:authorize(p)==nil)
end)
test("new source version changes invalidate previously issued contact token",function()
 local o,s,p,rec,ctx,profile=scenario();assert(o:refresh(true))
 local token=assert(o:authorize(p));profile.version="test_other_version"
 assert(o:validate(p,token)==false)
end)
test("invalid request tokens cannot crash or authorize",function()
 local o,s,p=scenario();assert(o:refresh(true))
 for _,bad in ipairs({"fake",1,false,{contactOnly=true}, {authorizesTrade=true}}) do
  local ok,v=pcall(o.validate,o,p,bad)
  assert(ok and v==false)
 end
end)
test("400 deterministic malformed item/quantity/status mutations fail closed",function()
 math.randomseed(8701)
 for i=1,400 do
  local x=own()
  local n=i%10
  if n==0 then x.items[1].id=i
  elseif n==1 then x.items[1].qty=math.random()+0.1
  elseif n==2 then x.items[1].page="rare"
  elseif n==3 then x.items[2].cat="Unknown"
  elseif n==4 then x.fingerprint=""
  elseif n==5 then x.unpriced="UNVERIFIED"
  elseif n==6 then x.items[1].id=x.items[2].id
  elseif n==7 then x.unmapped=math.random(1,3)
  elseif n==8 then x.badQty=math.random(1,3)
  else x.items[1].qty=math.huge end
  local status=p3.evaluateContact(x,their())
  assert(status=="unknown","corrupt input accepted trial "..i)
 end
end)
print("STAGE87_CONTACT_REACHABILITY_PASS groups="..groups.." malformed=400")
