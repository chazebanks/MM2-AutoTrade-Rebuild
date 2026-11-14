-- System2 S2.3: actual Roblox client P4-style trade GUI read-only capture.
-- Based on reviewed Stage9 p4_native_observer shape; no GUI mutation/remotes.
-- Requires original P3/P4 caller-bound root, lease, partner and local UserId.
local M={}
local function find(obj,name,recursive)
 if not obj or type(name)~="string" then return nil end
 return obj:FindFirstChild(name,recursive)
end
local function is(obj,name) return obj and obj:IsA(name)==true end
local function visible(node,ancestor)
 if not node then return false end
 local v=node
 while v do
  if is(v,"GuiObject") and v.Visible~=true then return false end
  if is(v,"ScreenGui") and v.Enabled~=true then return false end
  if v==ancestor then return true end
  v=v.Parent
 end
 return ancestor==nil
end
local function readText(node)
 if is(node,"TextLabel") or is(node,"TextButton") then
  return type(node.Text)=="string" and node.Text or nil
 end
 return nil
end
local function tradeRoot(pg)
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local gui=find(pg,name)
  local root=find(find(gui,"Container"),"Trade")
  if root and visible(root,pg) then return root end
 end
 return nil
end
local function rawItemId(node)
 local result=nil
 for _,key in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
  local value=node:GetAttribute(key)
  if value==nil then
   local leaf=find(node,key,true)
   if is(leaf,"StringValue") or is(leaf,"IntValue") or is(leaf,"NumberValue") then
    value=leaf.Value
   end
  end
  if value~=nil and tostring(value)~="" then
   local id=tostring(value)
   if not id:match("^[A-Za-z0-9_]+$") or #id>90 then
    return nil,"OFFER_RAW_ID_FORMAT_INVALID" end
   if result and result~=id then return nil,"CONFLICTING_RAW_ID_ATTRIBUTES" end
   result=id
  end
 end
 -- Missing raw attributes are common in the original GUI. Preserve UNKNOWN,
 -- not a fabricated ID; the strategy may attempt a *candidate-only* lookup.
 return result,nil
end
local function side(root,name)
 local node=find(root,name)
 local container=find(node,"Container")
 local accept=find(node,"Accepted")
 if not node or not container or not accept then
  return nil,nil,"OFFER_SIDE_OR_ACCEPT_MISSING" end
 local acceptance=visible(accept,root)
 local slots={}
 for i=1,4 do
  local slot=find(container,"NewItem"..tostring(i))
  if slot and visible(slot,root) then
   local raw,err=rawItemId(slot)
   if not raw then return nil,nil,err end
   local label=readText(find(find(slot,"ItemName"),"Label"))
   local amount=readText(find(find(slot,"Container"),"Amount"))
   local chromaTag=find(find(slot,"Tags"),"Chroma")
   if label==nil or amount==nil then
    return nil,nil,"GUI_SLOT_LABEL_OR_AMOUNT_MISSING" end
   slots[#slots+1]={slot=i,rawId=raw,rawIdObserved=raw~=nil,label=label,
     amountText=amount,chromaTag=chromaTag~=nil and visible(chromaTag,slot)}
  end
 end
 return slots,acceptance,nil
end
local function packet(g,players,scope)
 if g.PlaceId~=142823291 or tostring(g.JobId)~=scope.jobId then
  return nil,"ORIGINAL_MM2_JOB_CHANGED" end
 local lp=players.LocalPlayer
 if not lp or lp.UserId~=scope.localUserId then
  return nil,"CURRENT_ACCOUNT_CHANGED" end
 local pg=lp:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil,"GAME_PLAYER_GUI_UNAVAILABLE" end
 local root=tradeRoot(pg)
 if not root or root~=scope.root then
  return nil,"ACTIVE_TRADE_ROOT_DIFFERENT" end
 local opponent=players:GetPlayerByUserId(scope.partnerUserId)
 if not opponent or opponent.Parent~=players or opponent.UserId~=scope.partnerUserId then
  return nil,"ACTIVE_PARTNER_NOT_PRESENT" end
 local nickname=readText(find(find(root,"TheirOffer"),"Username"))
 if not nickname then return nil,"GUI_PARTNER_USERNAME_ABSENT" end
 nickname=(nickname:match("^%s*%((.-)%)%s*$") or nickname)
    :gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
 if nickname:lower()~=opponent.Name:lower() then
  return nil,"GUI_PARTNER_DIFFERENT_FROM_BOUND_ACCOUNT" end
 local our,oa,err=side(root,"YourOffer")
 if not our then return nil,err end
 local their,ta,errOther=side(root,"TheirOffer")
 if not their then return nil,errOther end
 return {clientOnly=true,contextOK=true,tradeOpen=true,rootBound=true,
  jobId=scope.jobId,tradeLeaseId=scope.leaseId,
  partnerUserId=scope.partnerUserId,ourSlots=our,theirSlots=their,
  ourAccepted=oa,theirAccepted=ta},nil
end
local function sig(frame)
 if type(frame)~="table" then return nil end
 local parts={}
 for _,key in ipairs({"ourSlots","theirSlots"}) do
  local t=frame[key]
  if type(t)~="table" then return nil end
  for _,x in ipairs(t) do
   parts[#parts+1]=tostring(x.slot)..":"..tostring(x.rawId)..":"..x.label..
    ":"..x.amountText..":"..tostring(x.chromaTag)
  end
  parts[#parts+1]="|"
 end
 parts[#parts+1]="accept:"..tostring(frame.ourAccepted)..":"..tostring(frame.theirAccepted)
 return table.concat(parts,";")
end
function M.new(config)
 if type(config)~="table" or config.game==nil or
  config.players==nil or type(config.scope)~="table" or
  type(config.isBoundSession)~="function" then
  return nil,"GUI_CAPTURE_DEPENDENCY_INVALID" end
 local scope=config.scope
 if type(scope.jobId)~="string" or #scope.jobId<8 or
   type(scope.leaseId)~="string" or #scope.leaseId<8 or
   type(scope.localUserId)~="number" or type(scope.partnerUserId)~="number"
   or not scope.root then return nil,"GUI_CAPTURE_SCOPE_INVALID" end
 local adapter={}
 function adapter.capture()
  local ok,active=pcall(config.isBoundSession)
  if not ok or active~=true then
   return {status="BLOCKED",reason="REVIEWED_P3_P4_LEASE_NOT_ACTIVE"}
  end
  local first,err=packet(config.game,config.players,scope)
  if not first then return {status="BLOCKED",reason=err} end
  local second,err2=packet(config.game,config.players,scope)
  if not second then return {status="BLOCKED",reason=err2} end
  if sig(first)~=sig(second) then
   return {status="BLOCKED",reason="GUI_CHANGED_DURING_CAPTURE"} end
  local ok2,active2=pcall(config.isBoundSession)
  if not ok2 or active2~=true then
   return {status="BLOCKED",reason="REVIEWED_P3_P4_LEASE_CHANGED"} end
  first.doubleReadStable=true
  return first
 end
 return adapter,nil
end
return M
