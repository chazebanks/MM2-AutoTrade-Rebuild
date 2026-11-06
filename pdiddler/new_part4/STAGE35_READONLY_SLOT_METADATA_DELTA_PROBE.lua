-- Stage35: READ-ONLY structural census of a populated native MM2
-- trade offer slot. Does not read/print any weapon ID value, image asset,
-- player username, screen text or server payload. NO Accept or trade RPC.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE35_SLOT_METADATA_CENSUS"
if game.PlaceId~=142823291 then warn("[STAGE35] wrong place") return end
for _,name in ipairs({
 KEY,"PDIDDLER_STAGE34_OFFER_INVENTORY_PROBE",
 "PDIDDLER_STAGE33_TRANSPORT_CENSUS",
 "PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_STAGE29_POSTCLOSE_PROBE",
 "PDIDDLER_STAGE25_SCANNER_ONLY",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART4_CONTROLLER","PDIDDLER_PART5_CONTROLLER",
 "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST",
 "PDIDDLER_STAGE30_PASSIVE_SIGNALS",
 "PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE",
 "PDIDDLER_STAGE27_NATIVE_LAB"
}) do
 if E[name]~=nil then
  warn("[STAGE35] another owner detected; rejoin to test alone") return
 end
end
local S={state="LOADING_READ_ONLY",finished=false,
 authorizesAccept=false,authorizesTrade=false,
 mayRecordCompletedTrade=false,mayReportProfit=false}
E[KEY]=S
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PIN35="cee7b0605a6822d1dbb0b1592fc2d84b53f0e238"
local players=game:GetService("Players")
local me=players.LocalPlayer
local job=game.JobId
if not me then S.state="PLAYER_NOT_READY";return S end
local ok,normalizer=pcall(function()
 local src=game:HttpGet(ROOT..PIN35..
   "/pdiddler/new_part4/p4_stage35_slot_identity_metadata.lua",true)
 assert(type(src)=="string" and #src>100,"module unavailable")
 local fn,why=loadstring(src,"=p4_stage35_slot_identity_metadata")
 assert(fn,why)
 local mod=fn()
 assert(type(mod)=="table" and type(mod.report)=="function")
 return mod
end)
if not ok then
 S.state="MODULE_UNAVAILABLE"
 warn("[STAGE35] pure metadata module not ready; no trade action")
 return S
end
local function finish(reason,raw)
 if S.finished then return end
 S.finished=true
 local r=normalizer.report(raw)
 r.stopReason=reason
 r.anonymizedStructuralOnly=true
 r.tradeOutcome="UNKNOWN"
 r.rawIdAuthenticated=false;r.exactItemIdentityConfirmed=false
 r.serverCompletionProven=false;r.causalAttributionProven=false
 r.authorizesTrade=false;r.authorizesAccept=false
 r.mayRecordCompletedTrade=false;r.mayReportProfit=false
 S.state="FINISHED_READ_ONLY";S.result=r
 local encoded,data=pcall(function()
  return game:GetService("HttpService"):JSONEncode(r)
 end)
 if encoded then
  if type(setclipboard)=="function" then pcall(setclipboard,data) end
  print("[GINGERSCOPE STAGE35 ANONYMIZED] "..data)
 else
  warn("[STAGE35] JSON unavailable; no action taken")
 end
end
local function visible(node,stop)
 while node do
  if node:IsA("ScreenGui") and not node.Enabled then return false end
  if node:IsA("GuiObject") and not node.Visible then return false end
  if node==stop then return true end
  node=node.Parent
 end
 return false
end
local function tradeRoot()
 local pg=me:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil end
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local gui=pg:FindFirstChild(name)
  local cont=gui and gui:FindFirstChild("Container")
  local root=cont and cont:FindFirstChild("Trade")
  if root and visible(root,pg) then return root end
 end
end
local function filledSlot(root)
 for _,sideName in ipairs({"TheirOffer","YourOffer"}) do
  local side=root:FindFirstChild(sideName)
  local container=side and side:FindFirstChild("Container")
  for i=1,4 do
   local slot=container and container:FindFirstChild("NewItem"..i)
   local itemName=slot and slot:FindFirstChild("ItemName")
   local label=itemName and itemName:FindFirstChild("Label")
   local labelPresent=label and
    (label:IsA("TextLabel") or label:IsA("TextButton")) and
    type(label.Text)=="string" and label.Text~=""
   if slot and visible(slot,root) and labelPresent then
    return slot,sideName,i
   end
  end
 end
end
local function safeName(v)
 return type(v)=="string" and #v>0 and #v<=50 and
   v:match("^[%a_][%w_]*$")~=nil
end
local function nodePath(slot,node)
 if node==slot then return nil end
 local parts={}
 while node and node~=slot and #parts<=5 do
  if not safeName(node.Name) then return nil end
  table.insert(parts,1,node.Name)
  node=node.Parent
 end
 if node~=slot or #parts==0 or #parts>5 then return nil end
 return table.concat(parts,".")
end
local function shape(slot,side,index)
 local raw={side=side,index=index,slotVisible=true,
  itemNameLabelPresent=true,metadataTruncated=false,
  attributes={},valueNodes={},imageNodes={}}
 local nodes={slot}
 local others=slot:GetDescendants()
 if #others>180 then raw.metadataTruncated=true;return raw end
 for _,node in ipairs(others) do nodes[#nodes+1]=node end
 for _,node in ipairs(nodes) do
  local parentPath=node==slot and nil or nodePath(slot,node)
  if node==slot or parentPath then
   local got,attrs=pcall(function()return node:GetAttributes()end)
   if not got or type(attrs)~="table" then
    raw.metadataTruncated=true;return raw
   end
   for k,v in pairs(attrs) do
    local typ=type(v)
    if safeName(k) and (typ=="number" or typ=="string" or
      typ=="boolean") then
     local path=parentPath and (parentPath.."."..k) or k
     raw.attributes[#raw.attributes+1]={path=path,valueType=typ,
      nonempty=v~=nil and tostring(v)~=""}
    end
   end
   if node:IsA("StringValue") or node:IsA("IntValue") or
      node:IsA("NumberValue") or node:IsA("BoolValue") then
    local typ=type(node.Value)
    raw.valueNodes[#raw.valueNodes+1]={path=parentPath,
     valueType=typ,nonempty=node.Value~=nil and
      tostring(node.Value)~=""}
   end
   if node:IsA("ImageLabel") or node:IsA("ImageButton") then
    local art=node.Image
    local rect=node.ImageRectSize
    raw.imageNodes[#raw.imageNodes+1]={path=parentPath,
      kind=node.ClassName,nonempty=type(art)=="string" and art~="",
      spriteRect=rect.X~=0 or rect.Y~=0}
   end
  end
 end
 return raw
end
S.state="WAIT_FOR_POPULATED_MANUAL_SLOT"
print("[GINGERSCOPE STAGE35] READ-ONLY: open a manual trade and have either account OFFER one weapon; do NOT press Accept. Script only inspects slot metadata shape. Close or decline after report.")
task.spawn(function()
 local start=os.clock()
 local lastRoot,lastSlot,consecutive=nil,nil,0
 while not S.finished and E[KEY]==S and game.JobId==job and
   players.LocalPlayer==me and os.clock()-start<90 do
  local root=tradeRoot()
  local slot,side,index
  if root then slot,side,index=filledSlot(root) end
  if slot and side and index then
   if root==lastRoot and slot==lastSlot then
    consecutive=consecutive+1
   else
    lastRoot,lastSlot,consecutive=root,slot,1
   end
   if consecutive>=3 then
    local good,raw=pcall(shape,slot,side,index)
    if not good then
     finish("SLOT_METADATA_CAPTURE_ERROR")
    elseif game.JobId~=job or E[KEY]~=S or
      tradeRoot()~=root or not visible(slot,root) then
     finish("SLOT_SCOPE_CHANGED_DURING_CAPTURE")
    else
     finish("SLOT_METADATA_CAPTURED",raw)
    end
    return
   end
  else
   lastRoot,lastSlot,consecutive=nil,nil,0
  end
  task.wait(.1)
 end
 finish("NO_STABLE_POPULATED_SLOT_OR_SESSION_CHANGED")
end)
return S
