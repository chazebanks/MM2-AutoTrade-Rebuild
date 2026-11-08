-- Stage59 passive LOCAL FILE STORAGE selftest. NO MM2 trade observation.
-- One run writes a harmless marker inside this device's executor workspace.
-- After a real game rejoin, rerun on SAME device and compare previousNonce
-- with the original newNonce. The two roles use SEPARATE files.
-- Does NOT claim successful MM2 trade, inventory changes or server settlement.
local function run(role,device)
 if role~="RECEIVER" and role~="SENDER" then
  warn("[STAGE59 STORAGE] Invalid role, no action") return
 end
 local who=role=="RECEIVER" and "MAIN" or "ALT"
 local phone=who=="ALT" and device=="PHONE"
 local path="GINGERSCOPE_STAGE59_"..who.."_STORAGE_CHECK.txt"
 local function fn(kind)
  if kind=="write" and type(writefile)=="function" then return writefile end
  if kind=="read" and type(readfile)=="function" then return readfile end
  if type(getgenv)=="function" then
   local ok,e=pcall(getgenv)
   if ok and type(e)=="table" and
    type(e[kind=="write" and "writefile" or "readfile"])=="function" then
    return e[kind=="write" and "writefile" or "readfile"]
   end
  end
 end
 local wr,rd=fn("write"),fn("read")
 local prior="NONE"
 local status="UNAVAILABLE"
 local nonce="NONE"
 local function valid(v)
  if type(v)~="string" or #v>180 then return nil end
  local label,id=v:match("^STAGE59%-STORAGE%-CHECK%|([A-Z]+)%|([%da-fA-F%-]+)%|%d+$")
  if label==who and type(id)=="string" and #id>=16 and #id<=64 then
   return id
  end
 end
 if rd then
  local ok,data=pcall(rd,path)
  if ok then prior=valid(data) or "INVALID_PRIOR_FILE" end
 end
 local http=game:GetService("HttpService")
 if not wr then status="NO_WRITEFILE"
 elseif not rd then status="NO_READFILE"
 else
  local ok,guid=pcall(function()return http:GenerateGUID(false)end)
  if not ok or type(guid)~="string" or
    not guid:match("^[%da-fA-F%-]+$") or #guid<16 or #guid>64 then
   status="NO_GUID"
  else
   nonce=guid
   local line="STAGE59-STORAGE-CHECK|"..who.."|"..guid.."|"..tostring(os.time())
   local wrote=pcall(wr,path,line)
   if not wrote then status="WRITE_FAILED"
   else
    local readOK,readback=pcall(rd,path)
    status=(readOK and readback==line) and "LOCAL_READBACK_OK"
      or "READBACK_FAILED"
   end
  end
 end
 local result={schema="gingerscope-stage59-storage-selftest-v1",role=who,
  storageStatus=status,previousNonce=prior,currentNonce=nonce,
  tradeOutcome="UNKNOWN",readOnlyGame=true,serverCompletionProven=false,
  authorizesAccept=false,mayReportProfit=false}
 local ok,encoded=pcall(function()return http:JSONEncode(result)end)
 if ok then print("[GINGERSCOPE STAGE59 STORAGE CHECK] "..encoded)
 else warn("[STAGE59 STORAGE] Encoding failed") end
 -- Optional UI; no executor/clipboard or game writes are needed for this.
 pcall(function()
  if type(Instance)~="table" or type(Instance.new)~="function" then return end
  local players=game:GetService("Players")
  local pg=players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old=pg:FindFirstChild("GINGERSCOPE_STAGE59_STORAGE_TEST")
  if old then old:Destroy() end
  local screen=Instance.new("ScreenGui")
  screen.Name="GINGERSCOPE_STAGE59_STORAGE_TEST"
  screen.ResetOnSpawn=false;screen.DisplayOrder=180
  local frame=Instance.new("Frame")
  frame.Size=UDim2.fromOffset(phone and 260 or 316,phone and 128 or 146)
  frame.Position=phone and UDim2.fromOffset(12,82) or UDim2.new(0,12,1,-165)
  frame.BackgroundColor3=Color3.fromRGB(36,25,58)
  frame.Parent=screen
  local title=Instance.new("TextLabel")
  title.Size=UDim2.new(1,-12,0,26)
  title.Position=UDim2.fromOffset(6,4)
  title.BackgroundTransparency=1
  title.TextColor3=Color3.fromRGB(255,255,255)
  title.Font=Enum.Font.GothamBold;title.TextSize=phone and 13 or 16
  title.Text=who.." | STAGE 59 STORAGE TEST"
  title.Parent=frame
  local content=Instance.new("TextLabel")
  content.Size=UDim2.new(1,-12,1,-35)
  content.Position=UDim2.fromOffset(6,32)
  content.BackgroundTransparency=1
  content.TextWrapped=true
  content.TextXAlignment=Enum.TextXAlignment.Left
  content.TextYAlignment=Enum.TextYAlignment.Top
  content.TextColor3=Color3.fromRGB(255,255,255)
  content.Font=Enum.Font.Gotham
  content.TextSize=phone and 12 or 14
  content.Text="Status: "..status..
   "\nPREVIOUS ID: "..prior:sub(1,8)..
   "\nCURRENT ID: "..nonce:sub(1,8)..
   "\nRejoin then run SAME test. Send both IDs; no trade."
  content.Parent=frame
  screen.Parent=pg
 end)
 return result
end
return run
