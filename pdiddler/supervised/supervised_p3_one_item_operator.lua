-- One physical, explicit MAIN-screen approval after REAL P3->P4 binding.
-- Reuses exact original supervised four-slot plan and protected OfferItem.
-- NO automatic offer on P3 ARM, price authority, final Accept, Discord or hop.
-- Ownership is a CURRENT CLIENT GetProfileData read, NOT server settlement proof.
local M={}
local function out(status,reason,attempts,visible)
 return {
  schema="pdiddler-p3-one-item-human-operator-v1",
  status=status,reason=reason,
  offerAttempts=attempts or 0,
  clientVisibleAddedSlots=visible or 0,
  authorizesOffer=false,authorizesAccept=false,
  rawItemIdsAuthenticated=false,pricesAuthenticated=false,
  serverCompletionProven=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN",
 }
end
local function key(s)
 return type(s)=="string" and #s>=1 and #s<=90
   and s:match("^[A-Za-z0-9_]+$")~=nil
end
local function display(s)
 return type(s)=="string" and #s>=1 and #s<=50
   and s:match("^[^%c]+$")~=nil
   and not s:match("^%s") and not s:match("%s$")
end
local function norm(s)
 if type(s)~="string" then return "" end
 return s:lower():gsub("[^%w]","")
end
local function protected(s)
 return norm(s):find("gingerscope",1,true)~=nil
end
local function verifiedClientSide(snapshot)
 return type(snapshot)=="table" and
    snapshot.status=="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" and
    snapshot.authorizesOffer==false and
    snapshot.authorizesAccept==false and
    snapshot.rawItemIdsAuthenticated==false and
    snapshot.pricesAuthenticated==false and
    snapshot.offerRevisionAuthenticated==false and
    snapshot.serverCompletionProven==false and
    snapshot.mayReportProfit==false and
    snapshot.maySendDiscordWebhook==false and
    snapshot.partnerExactClientBound==true and
    snapshot.part3Paused==true and
    snapshot.part4TradeVisible==true and
    snapshot.requestOriginBound==false and
    snapshot.tradeOutcome=="UNKNOWN" and
    type(snapshot.ours)=="table" and #snapshot.ours==0 and
    type(snapshot.theirs)=="table" and #snapshot.theirs<=4
end
local function ownedExactlyOne(inv,cfg)
 if type(inv)~="table" or
    type(inv.items)~="table" or
    type(inv.rawOwned)~="number" or inv.rawOwned<1 or
    inv.unmapped~=0 or inv.badQty~=0 then
  return false
 end
 local count=0
 for _,item in ipairs(inv.items) do
  if type(item)~="table" then return false end
  if item.id==cfg.approvedRawKey then
   count+=1
   if count>1 or item.cat~="Weapons" or
      type(item.qty)~="number" or
      item.qty~=math.floor(item.qty) or item.qty<1 or
      (item.page~="ancient" and item.page~="godly" and item.page~="chroma") or
      (item.type~="Knife" and item.type~="Gun" and
       item.type~="knife" and item.type~="gun") or
      (item.page=="chroma")~=cfg.approvedChromaFlag then
    return false
   end
   local name=item.name
   if type(name)~="string" then return false end
   -- The original scanner prefixes "Chroma " to its catalogue name;
   -- the physical offer slot displays the base name with a Chroma tag.
   if cfg.approvedChromaFlag then
    name=name:gsub("^[Cc][Hh][Rr][Oo][Mm][Aa]%s+","")
   end
   if name:lower()~=cfg.approvedDisplayName:lower() or
      protected(name) or protected(item.id) then
    return false
   end
  end
 end
 return count==1
end
function M.new(supervisor,io,gate,plan,scanner,cfg,ctx)
 if type(supervisor)~="table" or
    type(supervisor.currentBoundReadOnly)~="function" or
    type(io)~="table" or type(io.trade)~="function" or
    type(io.offerItem)~="function" or type(gate)~="table" or
    type(plan)~="table" or type(plan.run)~="function" or
    type(scanner)~="table" or type(scanner.getOwnInventory)~="function" or
    type(cfg)~="table" or type(ctx)~="table" or
    type(ctx.isSafe)~="function" or
    type(ctx.altStillExact)~="function" or
    type(ctx.showItemStep)~="function" or
    type(ctx.wait)~="function" then
  return nil,out("BLOCKED","OPERATOR_DEPENDENCIES_INVALID")
 end
 if cfg.allowOneItemPilot~=true or
    cfg.noAutomaticAcceptAcknowledged~=true or
    cfg.manualOfferOnly~=true or
    not key(cfg.approvedRawKey) or
    not display(cfg.approvedDisplayName) or
    type(cfg.approvedChromaFlag)~="boolean" or
    protected(cfg.approvedRawKey) or
    protected(cfg.approvedDisplayName) then
  return nil,out("BLOCKED","OPERATOR_SELECTION_INVALID_OR_PROTECTED")
 end
 -- Freeze the exact user-visible selection at construction. A mutable
 -- getgenv configuration must NEVER retarget an already approved GUI tap.
 local selection={
  approvedRawKey=cfg.approvedRawKey,
  approvedDisplayName=cfg.approvedDisplayName,
  approvedChromaFlag=cfg.approvedChromaFlag,
 }
 local spent=false
 local busy=false
 local last=out("WAITING","HUMAN_ITEM_APPROVAL_NOT_RECEIVED")
 local pilot={}
 local function safe()
  local ok,a=pcall(ctx.isSafe)
  local ob,b=pcall(ctx.altStillExact)
  return ok and ob and a==true and b==true and
    cfg.approvedRawKey==selection.approvedRawKey and
    cfg.approvedDisplayName==selection.approvedDisplayName and
    cfg.approvedChromaFlag==selection.approvedChromaFlag and
    cfg.allowOneItemPilot==true and
    cfg.manualOfferOnly==true and
    cfg.noAutomaticAcceptAcknowledged==true
 end
 local function lease()
  if not safe() then return nil end
  local ok,bound,info=pcall(supervisor.currentBoundReadOnly)
  if not ok or type(bound)~="table" or
     type(bound.capture)~="function" or
     type(info)~="table" or
     info.status~="P3_BOUND_CANDIDATE_READ_ONLY" or
     info.authorizesOffer~=false or
     info.authorizesAccept~=false then return nil end
  local okSnap,snap=pcall(bound.capture)
  if not okSnap or not verifiedClientSide(snap) then return nil end
  return bound
 end
 function pilot.preview()
  if spent or busy then return out("BLOCKED","ONE_ITEM_APPROVAL_ALREADY_SPENT") end
  if not lease() then return out("WAITING","NO_SAFE_EXACT_P3_P4_CLIENT_TRADE") end
  return out("READY_FOR_HUMAN_TAP","NO_ITEM_HAS_BEEN_OFFERED")
 end
 function pilot.execute(physicalTap)
  if spent or busy then return out("BLOCKED","ONE_ITEM_APPROVAL_ALREADY_SPENT") end
  if physicalTap~=true then return out("BLOCKED","PHYSICAL_APPROVAL_TAP_REQUIRED") end
  -- Spend FIRST, before any yielding inventory RPC or possible OfferItem.
  busy=true
  spent=true
  local bound=lease()
  if not bound then
   last=out("BLOCKED","NO_SAFE_EXACT_P3_P4_CLIENT_TRADE")
   busy=false
   return last
  end
  local ownOK,owned=pcall(scanner.getOwnInventory)
  if not ownOK or not ownedExactlyOne(owned,selection) or not safe() then
   last=out("BLOCKED","CURRENT_OWN_WEAPON_IDENTITY_NOT_PROVEN")
   busy=false
   return last
  end
  -- Recheck the same revocable lease AFTER the potentially yielding
  -- GetProfileData read: no closing/reopening same-named partner.
  local okSnap,snap=pcall(bound.capture)
  if not okSnap or not verifiedClientSide(snap) then
   last=out("BLOCKED","P3_BOUND_TRADE_CHANGED_AFTER_OWN_READ")
   busy=false
   return last
  end
  local root=io.trade()
  if not root or not safe() then
   last=out("BLOCKED","TRADE_ROOT_OR_SCREEN_UNSAFE")
   busy=false
   return last
  end
  local approval={
   armed=true,manualOfferOnly=true,noAutomaticAcceptAcknowledged=true,
   weaponKeys={selection.approvedRawKey},
   expectedDisplayNames={selection.approvedDisplayName},
   expectedChromaFlags={selection.approvedChromaFlag},
  }
  local called,result=pcall(plan.run,bound,io,gate,approval,{
   wait=function(seconds)
    if not safe() or io.trade()~=root then
     error("one-item session invalidated before GUI wait")
    end
    ctx.wait(seconds)
    if not safe() or io.trade()~=root then
     error("one-item session invalidated after GUI wait")
    end
   end,
   onBeforeItem=function(index,total,previous)
    if index~=1 or total~=1 or previous~=0 or
       not safe() or io.trade()~=root then return false end
    local good,shown=pcall(ctx.showItemStep,
       selection.approvedRawKey,selection.approvedDisplayName,
       selection.approvedChromaFlag)
    return good and shown==true and safe() and io.trade()==root
   end,
  })
  -- The original physical controller removes its own one-shot gate.
  -- NEVER retain authorization beyond this one physical operator tap.
  gate.checkOutbound=nil
  if not called or type(result)~="table" then
   last=out("INCONCLUSIVE","OPERATOR_CONTROLLER_THROWN_AFTER_POSSIBLE_SEND")
   last.offerAttempts=nil
   last.clientVisibleAddedSlots=nil
  else
   local attempts=result.offerAttempts
   local confirmed=result.clientVisibleAddedSlots
   last=out(result.status,result.reason,attempts,confirmed)
   if type(result.snapshotRejectReason)=="string" and
      result.snapshotRejectReason:match("^[A-Z_]+$") and
      #result.snapshotRejectReason<=72 then
    last.snapshotRejectReason=result.snapshotRejectReason
   end
  end
  busy=false
  return last
 end
 function pilot.result()
  return last
 end
 function pilot.hasSpent()
  return spent
 end
 return pilot,nil
end
return M
