-- Stage36: one read-only native slot image/Sync relationship observation.
-- No test transfer is needed. No trade/inventory RPC, listeners, hooks,
-- render helpers, script Source reads or image URL requests are performed.
-- Client image relationships cannot establish a weapon ID or trade outcome.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE36_IMAGE_RELATION"
if game.PlaceId~=142823291 then warn("[STAGE36] Wrong MM2 place");return end
local OWNERS={
 KEY,"PDIDDLER_STAGE36_ICON_CATALOG_AUDIT",
 "PDIDDLER_STAGE35_SLOT_METADATA_CENSUS",
 "PDIDDLER_STAGE34_OFFER_INVENTORY_PROBE",
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
 "PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
 "PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY"
}
for _,name in ipairs(OWNERS) do
 if E[name]~=nil then
  warn("[STAGE36] Competing owner detected; observation not started")
  return
 end
end
local players=game:GetService("Players")
local me=players.LocalPlayer
if not me then warn("[STAGE36] Local player missing");return end
local job=game.JobId
local S={state="LOAD_PURE_READ_ONLY",finished=false,
 authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayReportProfit=false}
E[KEY]=S
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
-- Replaced with the independently reviewed pure-module commit before release.
local PIN36="52d27bf00002267b54511881ca4852404c99ce6e"
local loaded,core=pcall(function()
 local txt=game:HttpGet(ROOT..PIN36..
  "/pdiddler/new_part4/p4_stage36_image_relation.lua",true)
 assert(type(txt)=="string" and #txt>100,"missing Stage36 pure module")
 local fun=assert(loadstring(txt,"=p4_stage36_image_relation"))
 local mod=fun()
 assert(type(mod)=="table" and type(mod.inspect)=="function")
 return mod
end)
if not loaded then
 S.state="MODULE_UNAVAILABLE"
 warn("[STAGE36] Pure read-only module unavailable; observation stopped")
 return S
end
local function finish(reason,input)
 if S.finished then return end
 S.finished=true
 local okay,res=pcall(core.inspect,input)
 if not okay or type(res)~="table" then
  okay,res=pcall(core.inspect,nil)
 end
 if not okay or type(res)~="table" then
  S.state="REPORT_UNAVAILABLE"
  warn("[STAGE36] Pure read-only report unavailable; observation stopped")
  return
 end
 -- Only the reviewed pure report and these fixed safety flags are exported.
 res.stopReason=reason
 res.anonymizedCountsOnly=true;res.readOnly=true
 res.tradeOutcome="UNKNOWN";res.rawItemIdConfirmed=false
 res.exactWeaponIdentityConfirmed=false;res.serverAttestation=false
 res.serverCompletionProven=false;res.causalAttributionProven=false
 res.authorizesTrade=false;res.authorizesAccept=false
 res.mayRecordCompletedTrade=false;res.mayReportProfit=false
 S.state="FINISHED_READ_ONLY";S.result=res
 local ok,data=pcall(function()
  return game:GetService("HttpService"):JSONEncode(res)
 end)
 if ok then
  if type(setclipboard)=="function" then pcall(setclipboard,data) end
  print("[GINGERSCOPE STAGE36 ANONYMIZED] "..data)
 else
  warn("[STAGE36] Anonymized report could not be encoded")
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
  local screen=pg:FindFirstChild(name)
  local container=screen and screen:FindFirstChild("Container")
  local root=container and container:FindFirstChild("Trade")
  if root and visible(root,pg) then return root end
 end
end
local function contentKind(icon)
 -- SourceType.Name is the sole ImageContent property inspected. Never
 -- inspect Object, resolve a URI, or call a render/thumbnail helper.
 local ok,name=pcall(function()return icon.ImageContent.SourceType.Name end)
 if ok then
  if name=="Uri" then return "URI" end
  if name=="Object" then return "OBJECT" end
  if name=="None" then return "NONE" end
 end
 return "UNREADABLE"
end
local function capture()
 local root=tradeRoot()
 if not root then return nil end
 for _,side in ipairs({"TheirOffer","YourOffer"}) do
  local offer=root:FindFirstChild(side)
  local container=offer and offer:FindFirstChild("Container")
  for index=1,4 do
   local slot=container and container:FindFirstChild("NewItem"..index)
   local itemName=slot and slot:FindFirstChild("ItemName")
   local label=itemName and itemName:FindFirstChild("Label")
   local imageContainer=slot and slot:FindFirstChild("Container")
   local icon=imageContainer and imageContainer:FindFirstChild("Icon")
   if slot and visible(slot,root) and label and
      (label:IsA("TextLabel") or label:IsA("TextButton")) and
      visible(label,root) and type(label.Text)=="string" and label.Text~="" and
      icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and
      visible(icon,root) and type(icon.Image)=="string" and icon.Image~="" then
    local rect=icon.ImageRectSize
    if type(rect.X)~="number" or type(rect.Y)~="number" then return nil end
    return {root=root,slot=slot,side=side,index=index,icon=icon,label=label,
     reference=icon.Image,name=label.Text,contentKind=contentKind(icon),
     -- Roblox displays the whole image if either size dimension is zero.
     sprite=rect.X~=0 and rect.Y~=0}
   end
  end
 end
end
local function safeCapture()
 local okay,snapshot=pcall(capture)
 if okay then return snapshot end
end
local function same(a,b)
 if not a or not b then return false end
 for _,key in ipairs({"root","slot","side","index","icon","label",
  "reference","name","contentKind","sprite"}) do
  if a[key]~=b[key] then return false end
 end
 return true
end
local function ownedContext()
 if E[KEY]~=S or game.JobId~=job or players.LocalPlayer~=me then return false end
 for _,name in ipairs(OWNERS) do
  if name~=KEY and E[name]~=nil then return false end
 end
 return true
end
local function readSync()
 local rs=game:GetService("ReplicatedStorage")
 local db=rs:FindFirstChild("Database")
 local module=db and db:FindFirstChild("Sync")
 if not module or not module:IsA("ModuleScript") then
  return nil,"SYNC_MODULE_ABSENT"
 end
 -- Existing native Database.Sync is the only game module required.
 -- Preserve its original table, source aliases and all metadata privately.
 local okay,sync=pcall(require,module)
 if not okay or type(sync)~="table" then
  return nil,"SYNC_CATALOGUE_UNAVAILABLE"
 end
 return sync
end
S.state="WAIT_FOR_POPULATED_VISIBLE_SLOT"
print("[GINGERSCOPE STAGE36] READ-ONLY: Observing one already populated visible offer slot. No testing transfer is needed.")
task.spawn(function()
 local started=os.clock()
 local last,frames=nil,0
 while not S.finished and ownedContext() and os.clock()-started<90 do
  local snapshot=safeCapture()
  if snapshot then
   if same(snapshot,last) then frames=frames+1
   else last=snapshot;frames=1 end
   if frames>=3 then
    local okay,sync,why=pcall(readSync)
    -- Require can yield or initialize native data. Recheck every captured
    -- object, exact icon and exact label before trusting this one snapshot.
    if not ownedContext() or not same(snapshot,safeCapture()) then
     finish("SLOT_CHANGED_DURING_SYNC_READ");return
    end
    if not okay then finish("SYNC_READ_EXCEPTION");return end
    if not sync then finish(why);return end
    finish("IMAGE_RELATION_OBSERVATION_FINISHED",{
     sync=sync,icon=snapshot.reference,name=snapshot.name,
     contentKind=snapshot.contentKind,sprite=snapshot.sprite,
     contextVerified=true})
    return
   end
  else last=nil;frames=0 end
  task.wait(.1)
 end
 finish("NO_STABLE_VISIBLE_SLOT_OR_CONTEXT_CHANGED")
end)
return S
