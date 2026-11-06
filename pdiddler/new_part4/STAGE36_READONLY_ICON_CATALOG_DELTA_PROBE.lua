-- Stage36: read-only client ICON REFERENCE vs ALL-TIER native Sync
-- catalogue art collision census. No item transfer, no trade RPC, no auto
-- Accept/Decline/Claim, no inventory scan and no exported ID or image URL.
-- A unique UI icon match is only a CLIENT catalogue association.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE36_ICON_CATALOG_AUDIT"
if game.PlaceId~=142823291 then warn("[STAGE36] Wrong MM2 place");return end
for _,name in ipairs({
 KEY,"PDIDDLER_STAGE35_SLOT_METADATA_CENSUS",
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
 "PDIDDLER_STAGE27_NATIVE_LAB"
}) do
 if E[name]~=nil then
  warn("[STAGE36] Competing owner detected; rejoin to test in isolation")
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
local PIN36="30eb8498f82fd6a79f2f0fbbfc282e59b97c7bdd"
local loaded,core=pcall(function()
 local txt=game:HttpGet(ROOT..PIN36..
  "/pdiddler/new_part4/p4_stage36_icon_catalog_audit.lua",true)
 assert(type(txt)=="string" and #txt>100,"missing Stage36 pure module")
 local fun,msg=loadstring(txt,"=p4_stage36_icon_catalog_audit")
 assert(fun,msg)
 local mod=fun()
 assert(type(mod)=="table" and type(mod.assess)=="function")
 return mod
end)
if not loaded then
 S.state="MODULE_UNAVAILABLE"
 warn("[STAGE36] Pure read-only module unavailable; no game actions")
 return S
end
local function finish(reason,input)
 if S.finished then return end
 S.finished=true
 local okay,res=pcall(core.assess,input)
 local r=okay and res or core.assess(nil)
 r.stopReason=reason
 r.anonymizedCountsOnly=true
 r.tradeOutcome="UNKNOWN";r.rawItemIdConfirmed=false
 r.exactWeaponIdentityConfirmed=false;r.serverAttestation=false
 r.serverCompletionProven=false;r.causalAttributionProven=false
 r.authorizesTrade=false;r.authorizesAccept=false
 r.mayRecordCompletedTrade=false;r.mayReportProfit=false
 S.state="FINISHED_READ_ONLY";S.result=r
 local ok,data=pcall(function()
  return game:GetService("HttpService"):JSONEncode(r)
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
local function filledSlot(root)
 for _,sideName in ipairs({"TheirOffer","YourOffer"}) do
  local side=root:FindFirstChild(sideName)
  local container=side and side:FindFirstChild("Container")
  for i=1,4 do
   local slot=container and container:FindFirstChild("NewItem"..i)
   local itemName=slot and slot:FindFirstChild("ItemName")
   local label=itemName and itemName:FindFirstChild("Label")
   local iconContainer=slot and slot:FindFirstChild("Container")
   local icon=iconContainer and iconContainer:FindFirstChild("Icon")
   if slot and visible(slot,root) and
      label and (label:IsA("TextLabel") or label:IsA("TextButton"))
      and type(label.Text)=="string" and label.Text~="" and
      icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
    return slot,sideName,i,icon
   end
  end
 end
end
local function readFullSyncCatalog()
 local rs=game:GetService("ReplicatedStorage")
 local db=rs:FindFirstChild("Database")
 local syncModule=db and db:FindFirstChild("Sync")
 if not syncModule or not syncModule:IsA("ModuleScript") then
  return nil,"SYNC_MODULE_ABSENT"
 end
 -- This game's own scanner already requires Database.Sync. We only read
 -- the returned table and do not invoke inventory or trade remotes.
 local got,sync=pcall(require,syncModule)
 if not got or type(sync)~="table" or
    type(sync.Weapons)~="table" or next(sync.Weapons)==nil then
  return nil,"SYNC_CATALOGUE_UNAVAILABLE"
 end
 local byKey,count={},0
 local function gather(t)
  if type(t)~="table" then return true end
  for key,d in pairs(t) do
   if type(d)=="table" then
    local id=tostring(key)
    if id=="" or #id>150 then return false end
    local row=byKey[id]
    if not row then
     count=count+1
     if count>5000 then return false end
     row={key=id,refs={}}
     byKey[id]=row
    end
    for _,field in ipairs({"Image","Icon","Texture"}) do
     local v=d[field]
     if type(v)=="string" and v~="" then
      if #v>512 or #row.refs>=6 then return false end
      row.refs[#row.refs+1]=v
     end
    end
   end
  end
  return true
 end
 if not gather(sync.Weapons) then return nil,"SYNC_TOO_LARGE_OR_INVALID" end
 if sync.Item~=sync.Weapons and
   not gather(sync.Item) then return nil,"SYNC_TOO_LARGE_OR_INVALID" end
 local arr={}
 for _,row in pairs(byKey) do arr[#arr+1]=row end
 if #arr==0 then return nil,"SYNC_CATALOGUE_EMPTY" end
 return arr,"SYNC_READ_ONLY"
end
S.state="WAIT_FOR_POPULATED_MANUAL_SLOT"
print("[GINGERSCOPE STAGE36] READ-ONLY: Open a manual trade; place ONE weapon in either visible offer. No Accept needed. Report compares icon references to every available Sync weapon tier; then manually DECLINE.")
task.spawn(function()
 local started=os.clock()
 local lastRoot,lastSlot,lastSide,lastIndex,lastIcon,lastRef=nil,nil,nil,nil,nil,nil
 local frames=0
 while not S.finished and E[KEY]==S and
   game.JobId==job and players.LocalPlayer==me and
   os.clock()-started<90 do
  local root=tradeRoot()
  local slot,side,index,icon
  if root then slot,side,index,icon=filledSlot(root) end
  local reference=icon and icon.Image
  if slot and side and index and icon and
     type(reference)=="string" and reference~="" and
     visible(icon,root) then
   if root==lastRoot and slot==lastSlot and
      side==lastSide and index==lastIndex and
      icon==lastIcon and reference==lastRef then
    frames=frames+1
   else
    lastRoot,lastSlot,lastSide,lastIndex,lastIcon,lastRef=
      root,slot,side,index,icon,reference
    frames=1
   end
   if frames>=3 then
    local readOK,entries,why=pcall(readFullSyncCatalog)
    if not readOK then finish("SYNC_READ_EXCEPTION") return end
    if E[KEY]~=S or game.JobId~=job or
       players.LocalPlayer~=me or tradeRoot()~=root or
       not visible(icon,root) or icon.Image~=reference then
      finish("SLOT_CHANGED_DURING_CATALOGUE_READ")
      return
    end
    if not entries then
      finish(why)
      return
    end
    local rect=icon.ImageRectSize
    local data={side=side,index=index,slotVisible=true,
      imageVisible=true,icon=reference,
      usesSpriteSheet=rect.X~=0 or rect.Y~=0,
      catalogueVerified=true,entries=entries}
    finish("ICON_REFERENCE_CATALOGUE_AUDIT_FINISHED",data)
    return
   end
  else
   lastRoot,lastSlot,lastSide,lastIndex,lastIcon,lastRef=nil,nil,nil,nil,nil,nil
   frames=0
  end
  task.wait(.1)
 end
 finish("NO_STABLE_VISIBLE_ICON_OR_JOB_CHANGED")
end)
return S
