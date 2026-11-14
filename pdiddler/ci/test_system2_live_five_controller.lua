-- Executes actual System2 five-scenario Lua controller against injectable
-- original protected P3/P4 adapter contract. NO live Roblox activity here.
local M=dofile("pdiddler/system2/system2_live_five_controller.lua")
local passed=0
local function eq(a,b,label)
 if a~=b then error((label or "mismatch").." expected "..tostring(b).." got "..tostring(a)) end
end
local function item(slot,name,qty,chroma)
 return {physicalSlot=slot,displayCandidate=name,quantity=qty or 1,
  chromaCandidate=chroma==true,rawItemIdAuthenticated=false,
  internalIdCandidate=name}
end
local function build(opts)
 opts=opts or {}
 local st={round=0,job=1,root=nil,ours={},theirs={},
  stops=0,req=0,offer=0,remove=0,decline=0,receipt=nil,accepted=0,
  added={},revised={},cleared={},mutations=0}
 local api={}
 function api.startEpoch(round,nonce)
  eq(nonce,round,"fresh epoch")
  st.round=round;st.root={};st.ours={};st.theirs={}
  st.req=st.req+1
  return true,"epoch_"..tostring(round)
 end
 function api.inspect(round,epoch)
  eq(round,st.round,"bound round")
  eq(epoch,"epoch_"..tostring(round),"bound epoch")
  if opts.poisonPartner and round==opts.poisonPartner then
   return {sessionFresh=true,exactPartner=false,
    noOtherController=true,p3Status="P3_BOUND",
    root=st.root}
  end
  local ob={sessionFresh=true,exactPartner=true,
    noOtherController=true,p3Status="P3_BOUND",root=st.root}
  if st.root then
   ob.snapshot={
    status="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT",
    partnerExactClientBound=true,part3Paused=true,part4TradeVisible=true,
    requestOriginBound=false,authorizesAccept=false,authorizesOffer=false,
    rawItemIdsAuthenticated=false,pricesAuthenticated=false,
    offerRevisionAuthenticated=false,serverCompletionProven=false,
    mayReportProfit=false,maySendDiscordWebhook=false,
    tradeOutcome="UNKNOWN",
    physicalOwnSlots=#st.ours,physicalTheirSlots=#st.theirs,
    ours=st.ours,theirs=st.theirs}
   if opts.poisonAccepted and round==opts.poisonAccepted then
    ob.snapshot.authorizesAccept=true
   end
  end
  return ob
 end
 function api.offerApproved(round,n,epoch,choice)
  eq(round,st.round,"offer round");eq(choice,1,"choice index")
  eq(#st.ours,0,"preoffer own empty")
  eq(#st.theirs,0,"preoffer their empty")
  for i=1,n do st.ours[i]=item(i,"MainSafe"..tostring(i),1,false) end
  st.offer=st.offer+n
  return {status="CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
   authorizesAccept=false,serverCompletionProven=false,
   tradeOutcome="UNKNOWN",offerAttempts=n,clientVisibleAddedSlots=n}
 end
 function api.removeOwnOne(round,root,epoch,allowAlt)
  eq(round,st.round,"remove round");eq(root,st.root,"remove root")
  eq(#st.theirs,0,"remove must have empty ALT")
  eq(allowAlt,false,"no unapproved ALT present")
  table.remove(st.ours,1)
  st.remove=st.remove+1
  return true
 end
 function api.decline(round,root,epoch)
  eq(round,st.round,"decline round")
  eq(root,st.root,"decline root")
  eq(#st.ours,0,"decline own empty")
  eq(#st.theirs,0,"decline their empty")
  st.root=nil;st.decline=st.decline+1
  return true
 end
 function api.endEpoch(round,epoch)
  eq(round,st.round,"end epoch round")
  eq(st.root,nil,"root must be nil on end")
  return true
 end
 function api.stopAll()st.stops=st.stops+1;return true end
 function api.copyReport(r)st.receipt=r;return true end
 local controller,err=M.new(api,{
  exactConsentingAlt=true,explicitFiveLiveConsent=true,
  finalAcceptDisabled=true,offlinePrerequisitesReviewed=true,
  twoDistinctCheapOwnItemsApproved=true,requestTimeout=30,
  altStepTimeout=90,actionTimeout=15,
 })
 assert(controller,err)
 return st,controller
end
local function walk(opts)
 local st,c=build(opts)
 local r=nil
 for i=1,1500 do
  local state=c.status()
  local rd=state.round
  local ph=state.phase
  if opts and opts.poisonFiveSlots and rd==opts.poisonFiveSlots and
     ph=="WAIT_ALT_FIRST" and #st.theirs==0 then
   for k=1,5 do st.theirs[k]=item(k,"Injected"..k) end
  elseif ph=="WAIT_ALT_FIRST" and not st.added[rd] then
   st.added[rd]=true
   st.theirs={item(1,"AltFirst"..rd,rd==4 and 2 or 1,false)}
  elseif ph=="WAIT_ALT_REVISED" and not st.revised[rd] then
   st.revised[rd]=true
   st.theirs={item(1,"AltSecond"..rd,1,true)}
  elseif ph=="WAIT_ALT_CLEAR" and not st.cleared[rd] then
   st.cleared[rd]=true;st.theirs={}
  end
  r=c.tick(i*0.2)
  if r.phase=="STOPPED" or r.phase=="EXPECTED_TERMINAL_STOP" then
   return st,c,r
  end
 end
 error("live five controller stuck, round "..tostring(c.status().round)..
   " phase "..tostring(c.status().phase).." reason "..c.status().reason)
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL ["..name.."] "..tostring(err))end
 passed=passed+1;print("PASS "..name)
end

test("five distinct bound epochs automatic progression with terminal revision",function()
 local st,c,r=walk()
 eq(r.phase,"EXPECTED_TERMINAL_STOP")
 eq(r.completedStages,5)
 eq(st.req,5)
 eq(st.offer,3)
 eq(st.remove,3)
 eq(st.decline,4)
 eq(st.stops,1)
 eq(r.actions.finalAccepts,0)
 eq(r.scenarios[1].status,"BLOCKED_PREREQUISITE")
 eq(r.scenarios[2].status,"LIVE_PASS")
 eq(r.scenarios[3].status,"BLOCKED_PREREQUISITE")
 eq(r.scenarios[4].status,"BLOCKED_PREREQUISITE")
 eq(r.scenarios[5].status,"LIVE_PASS")
 eq(r.scenarios[5].offerRevisionsObserved,1)
 eq(r.scenarios[3].candidateOffersClientObserved,2)
 eq(r.actions.clientClosedWindows,4)
 eq(r.discordV2DeliveryVerified,false)
 eq(r.realMarketSourceAuthenticated,false)
 eq(r.serverCompletionProven,false)
 eq(r.authorizesAccept,false)
 eq(r.tradeOutcome,"UNKNOWN")
 assert(st.receipt~=nil)
end)

test("fail closed on wrong exact client partner",function()
 local st,c,r=walk({poisonPartner=2})
 eq(r.phase,"STOPPED");eq(r.round,2)
 eq(r.completedStages,1)
 eq(st.req,2);eq(st.stops,1)
 eq(r.firstFailureScenario,"PARTNER_RESPONSE_REVISIONS")
end)

test("reject forged accept authority from native snapshot",function()
 local st,c,r=walk({poisonAccepted=1})
 eq(r.phase,"STOPPED")
 eq(r.reason,"PROTECTED_CLIENT_SNAPSHOT_INVALID")
 eq(st.req,1);eq(r.actions.finalAccepts,0)
end)

test("reject fabricated fifth physical trade slot",function()
 local st,c,r=walk({poisonFiveSlots=2})
 eq(r.phase,"STOPPED")
 eq(r.round,2);eq(st.req,2)
 eq(r.reason,"PROTECTED_CLIENT_SNAPSHOT_INVALID")
end)

test("explicit scoped authorization cannot be omitted",function()
 local x,y=M.new({}, {})
 eq(x,nil);eq(y,"EXPLICIT_LIVE_TEST_CONTRACT_MISSING")
end)

test("no fake live learning and market authority after client success",function()
 local _,__,r=walk()
 for _,v in ipairs(r.scenarios) do
  eq(v.sourcePriceVerified,false)
  eq(v.discordV2Delivered,false)
  eq(v.clientOutcomeOnly,true)
 end
 eq(r.mayUseForStrategyLearning,false)
 eq(r.mayReportProfit,false)
 eq(r.maySendDiscordWebhook,false)
 eq(r.authorizesOffer,false)
 eq(r.authorizesTrade,false)
 eq(r.authorizesAccept,false)
 eq(r.publicFinalAcceptAuthorized,false)
end)

print("SYSTEM2_LIVE_FIVE_SOURCE_BOUND_LUA54_PASS "..tostring(passed).." groups")
