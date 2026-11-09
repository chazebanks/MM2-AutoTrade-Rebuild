-- Gingerscope Stage60: ONE-SHOT read-only MM2 Trade remote surface census.
-- Does NOT call any remote, place/accept/decline offers, scan inventories,
-- create event listeners or infer a completed transaction from a remote name.
-- Enumerates ONLY direct child class/name pairs in ReplicatedStorage.Trade.
-- The entire output is game API *names*, no player, server/job, item or token.
local MARK="[GINGERSCOPE STAGE60 REMOTE SURFACE]"
local R={
 schema="gingerscope-stage60-client-trade-remote-surface-v1",
 status="INCOMPLETE",
 scope="ReplicatedStorage.Trade.DIRECT_CHILDREN_ONLY",
 readOnly=true, serverAttestation=false, serverCompletionProven=false,
 serverTransactionIdAuthenticated=false, eventSessionAssociationProven=false,
 authorizesAccept=false,authorizesTrade=false,
 mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 mayReportProfit=false,mayUseForStrategyLearning=false,
 tradeOutcome="UNKNOWN",
 eventNames={},functionNames={},candidateEventNames={},
 candidateFunctionNames={},classCounts={},unsafeNames=0,
 duplicateNames=0,childCount=0
}
local function safeName(s)
 return type(s)=="string" and #s>0 and #s<=40
    and s:match("^[A-Za-z_][A-Za-z0-9_]*$")~=nil
end
local function hasResultHint(s)
 local n=s:lower()
 for _,word in ipairs({"complete","endtrade","history","result",
                       "receipt","transaction","settle","success","record"}) do
  if n:find(word,1,true) then return true end
 end
 return false
end
local function finish(status)
 R.status=status
 local encoded
 local ok,answer=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if ok and type(answer)=="string" then
  encoded=answer
 else
  encoded='{"schema":"gingerscope-stage60-client-trade-remote-surface-v1","status":"JSON_ENCODING_UNAVAILABLE","serverCompletionProven":false,"authorizesAccept":false,"tradeOutcome":"UNKNOWN"}'
 end
 local line=MARK.." "..encoded
 print(line)
 -- A optional small display does NOT control the scanner and never auto-copies.
 -- If GUI permissions fail, the Delta console line is the complete result.
 pcall(function()
  if type(Instance)~="table" or type(Instance.new)~="function" then return end
  local players=game:GetService("Players")
  local lp=players and players.LocalPlayer
  local pg=lp and lp:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old=pg:FindFirstChild("GINGERSCOPE_STAGE60_RESULT_ONLY")
  if old then old:Destroy() end
  local screen=Instance.new("ScreenGui")
  screen.Name="GINGERSCOPE_STAGE60_RESULT_ONLY"
  screen.ResetOnSpawn=false
  local frame=Instance.new("Frame")
  frame.Size=UDim2.fromOffset(315,127)
  frame.Position=UDim2.new(0,12,1,-162)
  frame.BackgroundColor3=Color3.fromRGB(55,26,91)
  frame.Parent=screen
  local label=Instance.new("TextLabel")
  label.Size=UDim2.new(1,-14,0,81)
  label.Position=UDim2.fromOffset(7,5)
  label.BackgroundTransparency=1
  label.TextColor3=Color3.fromRGB(255,255,255)
  label.TextWrapped=true
  label.TextSize=13
  label.Text="STAGE60 READ-ONLY | NO TRADE NEEDED\n"..status..
    "\nCheck Delta console, or tap COPY REPORT."
  label.Parent=frame
  local b=Instance.new("TextButton")
  b.Size=UDim2.new(1,-14,0,30)
  b.Position=UDim2.fromOffset(7,91)
  b.BackgroundColor3=Color3.fromRGB(120,71,184)
  b.TextColor3=Color3.fromRGB(255,255,255)
  b.Text="COPY REPORT"; b.TextSize=15; b.Parent=frame
  b.Activated:Connect(function()
   local copy=setclipboard
   if type(copy)~="function" then copy=toclipboard end
   if type(copy)~="function" then
    label.Text="COPY UNAVAILABLE. Copy the Delta console report instead."
    return
   end
   local copied=pcall(copy,line)
   label.Text=copied and "COPIED. Paste the one Stage60 report into ChatGPT."
                    or "COPY FAILED. Use Delta console report instead."
  end)
  screen.Parent=pg
 end)
 return R
end
if type(game)~="userdata" and type(game)~="table" then
 return finish("GAME_UNAVAILABLE")
end
if game.PlaceId~=142823291 then
 return finish("NOT_ORIGINAL_MM2")
end
local ok,rs=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not rs then return finish("REPLICATED_STORAGE_UNAVAILABLE") end
local okFolder,folder=pcall(function()return rs:FindFirstChild("Trade")end)
if not okFolder or not folder then return finish("TRADE_FOLDER_MISSING") end
local got,children=pcall(function()return folder:GetChildren()end)
if not got or type(children)~="table" then
 return finish("CHILDREN_UNREADABLE")
end
R.childCount=#children
if #children>64 then return finish("TOO_MANY_CHILDREN") end
local seen={}
local classAllow={
 RemoteEvent=true,UnreliableRemoteEvent=true,RemoteFunction=true,
 BindableEvent=true,BindableFunction=true,Folder=true
}
for _,node in ipairs(children) do
 local valid,klass,name=pcall(function()
  return tostring(node.ClassName),node.Name
 end)
 if not valid or not safeName(name) then
  R.unsafeNames=R.unsafeNames+1
 else
  if not classAllow[klass] then klass="OTHER" end
  R.classCounts[klass]=(R.classCounts[klass] or 0)+1
  local k=klass..":"..name
  if seen[k] then R.duplicateNames=R.duplicateNames+1 end
  seen[k]=true
  if klass=="RemoteEvent" or klass=="UnreliableRemoteEvent" then
   table.insert(R.eventNames,name)
   if hasResultHint(name) then
    table.insert(R.candidateEventNames,name)
   end
  elseif klass=="RemoteFunction" then
   table.insert(R.functionNames,name)
   if hasResultHint(name) then
    table.insert(R.candidateFunctionNames,name)
   end
  end
 end
end
if R.unsafeNames>0 then
 R.eventNames={};R.functionNames={}
 R.candidateEventNames={};R.candidateFunctionNames={}
 return finish("UNSAFE_CHILD_NAMES_REJECTED")
end
table.sort(R.eventNames);table.sort(R.functionNames)
table.sort(R.candidateEventNames);table.sort(R.candidateFunctionNames)
if R.duplicateNames>0 then
 return finish("AMBIGUOUS_DUPLICATE_REMOTE_NAMES")
end
-- Existence/class/labels alone NEVER prove invocation direction, server
-- implementation, session binding, unique weapon identity or settlement.
return finish("CLIENT_REMOTE_SURFACE_ENUMERATED_NO_CONTRACT")
