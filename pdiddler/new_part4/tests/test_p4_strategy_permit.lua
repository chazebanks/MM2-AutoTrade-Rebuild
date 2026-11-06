-- Stage23: synthetic Lua review-to-permit contract. No Roblox actions.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local Risk=require("p4_risk_review")
local Dual=require("p4_dual_perspective")
local Permit=require("p4_strategy_permit")
local passed=0
local function test(label,fn)
 local ok,why=pcall(fn)
 if not ok then error(label..": "..tostring(why)) end
 passed=passed+1
end
local A="godly:11:checker-id"
local B="chroma:12:checker-id"
local source="synthetic-only"
local wall=1800000010
local function fixture(give,recv)
 give=give or 100;recv=recv or 105
 local ctx={session="session-1",now=wall,
  ownFingerprint="own-a",opponentFingerprint="their-b",
  ownInventory={[A]=1},opponentInventory={[B]=1},
  rawOwn={[A]={id="Mortal",page="godly",checkerId="11",qty=1,
    type="Knife",cat="Weapons"}},
  market={sourceId=source,verified=true,
    observedAt=wall-100,validUntil=wall+100,
    items={
     [A]={valueCents=give*100,demand=3,stability="stable",
        tradable=true,verified=true},
     [B]={valueCents=recv*100,demand=5,stability="stable",
        tradable=true,verified=true}
    }}}
 local obs={session="session-1",tradeOpen=true,contextOK=true,
  marketFresh=true,ourAccepted=false,theirAccepted=false,
  ourSlots=0,theirSlots=1,ourSig="empty-own",theirSig="theirs-B",
  theirResolved=true,ownItems={}}
 local diag={theirItems={{page="chroma",checkerId="12",qty=1}},
  authorizesAccept=false}
 local selected={give={{id=A,qty=1}},receive={{id=B,qty=1}}}
 local decision="allow"
 local callbackCount=0
 local approved=0
 local function approval(c,review,context,o)
  approved=approved+1
  if decision~="allow" then return nil end
  assert(review.reviewOnly==true and review.quoteSafe==false)
  assert(review.authorizesAccept==false)
  return {allowed=true,session=o.session,ourSig=o.ourSig,
    theirSig=o.theirSig,source=context.market.sourceId,
    candidateKey=A.."#1=>"..B.."#1"}
 end
 local engine=Permit.new({session="session-1",reviewer=Dual,
  context=function()callbackCount=callbackCount+1;return ctx end,
  source=function()return source end,wall=function()return wall end,
  choose=function()return selected end,approve=approval})
 return {ctx=ctx,obs=obs,diag=diag,selected=selected,
  engine=engine,permit=function()return Permit.next(engine,obs,diag,1)end,
  deny=function()decision="deny"end,
  callbacks=function()return callbackCount end,
  approvals=function()return approved end}
end

test("actual Stage17 is invoked; gain +5, no +15 rule",function()
 local f=fixture()
 local result=Dual.assess(f.ctx,f.selected)
 assert(result.ourGainCents==500 and result.sellerSurplusCents==-500)
 assert(result.reviewOnly==true and result.authorizesTrade==false)
 local proposal=f.permit()
 assert(type(proposal)=="table" and proposal.id=="Mortal")
 assert(Permit.validate(f.engine,proposal,f.obs,1.1)==true)
 assert(Permit.validate(f.engine,proposal,f.obs,1.2)==false)
end)
test("Stage17 result alone does NOT authorize a send",function()
 local f=fixture();f.deny()
 assert(f.permit()==nil)
 assert(f.approvals()==1)
 assert(not f.engine.used)
end)
test("explicit approval can evaluate strategic nominal loss",function()
 local f=fixture(105,100)
 local review=Dual.assess(f.ctx,f.selected)
 assert(review.case~="BLOCKED" and review.ourGainCents==-500)
 local proposal=f.permit()
 assert(proposal and Permit.validate(f.engine,proposal,f.obs,1.1))
end)
test("stale market fails closed",function()
 local f=fixture()
 f.ctx.market.validUntil=wall
 assert(f.permit()==nil)
end)
test("unverified profile source fails",function()
 local f=fixture();f.ctx.market.verified=false
 assert(f.permit()==nil)
end)
test("wrong source version fails",function()
 local f=fixture();f.ctx.market.sourceId="unmatched"
 assert(f.permit()==nil)
end)
test("visible offer must equal exact candidate receive",function()
 local f=fixture();f.diag.theirItems[1].qty=2
 assert(f.permit()==nil)
end)
test("missing live counterpart item does not invent a candidate",function()
 local f=fixture();f.diag.theirItems={}
 assert(f.permit()==nil)
end)
test("a candidate cannot offer more than one local copy",function()
 local f=fixture();f.selected.give[1].qty=2
 assert(f.permit()==nil)
end)
test("wrong raw checker ID blocks a lookalike item",function()
 local f=fixture();f.ctx.rawOwn[A].checkerId="99"
 assert(f.permit()==nil)
end)
test("a vintage name is not a canonical eligible identity",function()
 local f=fixture();f.selected.give[1].id="vintage:11:checker-id"
 assert(f.permit()==nil)
end)
test("unknown accept must hold",function()
 local f=fixture();f.obs.theirAccepted=nil
 assert(f.permit()==nil)
end)
test("another trade session is not approved",function()
 local f=fixture();f.obs.session="session-2"
 assert(f.permit()==nil)
end)
test("market value mutation between issuance and dispatch blocks",function()
 local f=fixture();local p=f.permit()
 f.ctx.market.items[B].valueCents=f.ctx.market.items[B].valueCents+500
 assert(not Permit.validate(f.engine,p,f.obs,1.1))
end)
test("demand mutation between issuance and dispatch blocks",function()
 local f=fixture();local p=f.permit()
 f.ctx.market.items[B].demand=1
 assert(not Permit.validate(f.engine,p,f.obs,1.1))
end)
test("stock mutation between issuance and dispatch blocks",function()
 local f=fixture();local p=f.permit()
 f.ctx.opponentInventory[B]=2
 assert(not Permit.validate(f.engine,p,f.obs,1.1))
end)
test("opponent signature changes between issuance and dispatch",function()
 local f=fixture();local p=f.permit()
 f.obs.theirSig="changed"
 assert(not Permit.validate(f.engine,p,f.obs,1.1))
end)
test("old approval expires before the send",function()
 local f=fixture();local p=f.permit()
 assert(not Permit.validate(f.engine,p,f.obs,1.3))
end)
test("different proposal object cannot impersonate approved identity",function()
 local f=fixture();local p=f.permit()
 local forged={}
 for k,v in pairs(p) do forged[k]=v end
 assert(not Permit.validate(f.engine,forged,f.obs,1.1))
end)
test("failed no-approval does not invoke permit",function()
 local f=fixture();f.deny()
 assert(f.permit()==nil)
end)
test("approved proposal only once even before dispatch",function()
 local f=fixture();local p=f.permit()
 assert(p and f.permit()==nil)
end)
test("stopping the strategy invalidates approval",function()
 local f=fixture();local p=f.permit()
 Permit.stop(f.engine)
 assert(not Permit.validate(f.engine,p,f.obs,1.1))
end)
test("no approval when opponent has no offered weapon",function()
 local f=fixture();f.obs.theirSlots=0
 assert(f.permit()==nil)
end)
test("context clock mismatch blocks cached source",function()
 local f=fixture();f.ctx.now=wall-10
 assert(f.permit()==nil)
end)
print("PASS",passed,"Stage23 existing Stage17 review and independent single-use permits")
