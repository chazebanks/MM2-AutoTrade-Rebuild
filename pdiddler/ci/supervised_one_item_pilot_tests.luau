-- Actual pure one-item manual pilot controller tests; no Roblox network.
local policy=require("../supervised/supervised_one_item_policy")
local checks=0
local function eq(a,b,reason)
 checks+=1
 assert(a==b,tostring(reason)..": expected "..tostring(b).." got "..tostring(a))
end
local function standard()
 local players={}
 local me={Name="MainAccount",UserId=1,Parent=players}
 local target={Name="TrustedAlt",UserId=2,Parent=players}
 function players:FindFirstChild(name)
  if name=="TrustedAlt" then return target end
 end
 local ownAccepted={Visible=false}
 local yourContainer={}
 local ourSide={Accepted=ownAccepted,Container=yourContainer}
 function ourSide:FindFirstChild(name) return self[name] end
 local theirs={Container={},Username={Text="TrustedAlt"},Accepted={Visible=false}}
 function theirs:FindFirstChild(name) return self[name] end
 local t={YourOffer=ourSide,TheirOffer=theirs}
 function t:FindFirstChild(name) return self[name] end
 local io={trade=function()return t end,
  partnerName=function()return target.Name end,
  acceptedTheir=function()return false end,
  readSide=function(_,side)
   if side=="YourOffer" then return {slots=0,entries={}} end
   return {slots=0,entries={}}
  end,
 }
 local gate={}
 local sends=0
 function io.offerItem(item)
  if type(gate.checkOutbound)~="function" or
    gate.checkOutbound(item,t)~=true then
   return false,"LOCAL_GATE_DENIED"
  end
  sends+=1
  return true,"fired"
 end
 local cfg={armed=true,manualOfferOnly=true,targetName="TrustedAlt",
            weaponKey="Iceblaster"}
 return {players=players,me=me,target=target,t=t,io=io,
         gate=gate,cfg=cfg,sends=function()return sends end,
         ourSide=ourSide,theirs=theirs}
end
local function denied(r,reason)
 eq(r.status,"BLOCKED","status")
 eq(r.reason,reason,"reason")
 eq(r.tradeOutcome,"UNKNOWN","outcome")
 eq(r.authorizesAccept,false,"Accept denied")
 eq(r.mayReportProfit,false,"profit denied")
 eq(r.mayRecordCompletedTrade,false,"settlement denied")
end
local a=standard()
local r=policy.run(a.io,a.gate,a.players,a.me,a.cfg)
eq(r.status,"OFFER_REMOTE_FIRED_CLIENT_ONLY","one manual item sent")
eq(a.sends(),1,"one send")
eq(r.offerCount,1,"count")
eq(r.authorizesAccept,false,"never Accept")
eq(r.authorizesTrade,false,"no autonomous trade permission")
eq(r.mayRecordCompletedTrade,false,"never completed-trade evidence")
eq(r.mayReportProfit,false,"never profit")
eq(r.tradeOutcome,"UNKNOWN","unknown settlement")
eq(a.cfg.armed,false,"user arm consumed")
eq(a.cfg._consumed,true,"one-shot consumed")
eq(a.gate.checkOutbound,nil,"gate disarmed immediately")
denied(policy.run(a.io,a.gate,a.players,a.me,a.cfg),"ONE_SHOT_ALREADY_USED")
eq(a.sends(),1,"no duplicate remote")
local cases={
 {edit=function(x)x.cfg.armed=false end,reason="EXPLICIT_MANUAL_ARM_MISSING"},
 {edit=function(x)x.cfg.manualOfferOnly=false end,reason="MANUAL_OFFER_ONLY_ACK_MISSING"},
 {edit=function(x)x.cfg.weaponKey="Gingerscope" end,reason="PROTECTED_GINGERSCOPE_OUTGOING"},
 {edit=function(x)x.cfg.weaponKey="Chroma Gingerscope" end,reason="PROTECTED_GINGERSCOPE_OUTGOING"},
 {edit=function(x)x.cfg.targetName="UnknownPlayer" end,reason="EXACT_TARGET_NOT_FOUND"},
 {edit=function(x)x.target.Parent=nil end,reason="EXACT_TARGET_NOT_PRESENT"},
 {edit=function(x)x.io.partnerName=function()return "AnotherPlayer" end end,
     reason="VISIBLE_PARTNER_NOT_EXACT_TARGET"},
 {edit=function(x)x.io.trade=function()return nil end end,reason="VISIBLE_TRADE_UNAVAILABLE"},
 {edit=function(x)x.ourSide.Container=nil end,reason="OFFER_UI_INCOMPLETE"},
 {edit=function(x)x.theirs.Container=nil end,reason="OFFER_UI_INCOMPLETE"},
 {edit=function(x)x.ourSide.Accepted=nil end,reason="OWN_ACCEPT_STATE_UNKNOWN"},
 {edit=function(x)x.ourSide.Accepted.Visible=true end,reason="ACCEPT_ALREADY_SET"},
 {edit=function(x)x.io.acceptedTheir=function()return true end end,
     reason="ACCEPT_ALREADY_SET"},
 -- Missing/invalid TheirOffer.Accepted must not be interpreted as
 -- "the opponent definitely has not accepted" just because a fallback
 -- UI reader returns false. This was the original fail-open gap.
 {edit=function(x)x.theirs.Accepted=nil end,
     reason="THEIR_ACCEPT_STATE_UNKNOWN"},
 {edit=function(x)x.theirs.Accepted.Visible="false" end,
     reason="THEIR_ACCEPT_STATE_UNKNOWN"},
 {edit=function(x)x.theirs.Accepted.Visible=true end,
     reason="ACCEPT_ALREADY_SET"},
 {edit=function(x)x.io.readSide=function()return {slots=1,entries={{}}} end end,
     reason="OWN_OFFER_ALREADY_NONEMPTY"},
 {edit=function(x)x.io.readSide=function()return {slots=nil,entries={}} end end,
     reason="OWN_OFFER_STATE_UNKNOWN"},
 {edit=function(x)x.cfg.weaponKey=1234 end,reason="WEAPON_KEY_INVALID"},
 {edit=function(x)x.cfg.weaponKey="" end,reason="WEAPON_KEY_INVALID"},
 {edit=function(x)x.cfg.targetName={value="TrustedAlt"} end,
     reason="TARGET_NAME_INVALID"},
}
for i,case in ipairs(cases) do
 local x=standard()
 case.edit(x)
 local rr=policy.run(x.io,x.gate,x.players,x.me,x.cfg)
 denied(rr,case.reason)
 -- Normalize any intentional detail-free reasons while always proving
 -- that invalid preconditions result in ZERO remote sends.
 eq(x.sends(),0,"invalid case #"..i)
 eq(x.gate.checkOutbound,nil,"no armed gate after invalid case")
end
-- A correct-looking user approval must not bypass late changed GUI conditions.
local x=standard()
x.io.offerItem=function(item)
  x.ourSide.Accepted.Visible=true
  eq(x.gate.checkOutbound(item,x.t),false,"late accepted blocks")
  return false,"LOCAL_GATE_DENIED"
end
denied(policy.run(x.io,x.gate,x.players,x.me,x.cfg),"OFFER_DISPATCH_DENIED")
print("[PASS] supervised one-item manual pilot guard:",checks)
