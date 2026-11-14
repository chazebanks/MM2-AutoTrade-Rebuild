-- System 2 / Gingerscope: read-only structural Accept-control discovery.
-- This module NEVER clicks, fires remotes, selects items, or grants authority.
-- "candidate" means a UI SHAPE, not proof that clicking settles a trade.
local M={}
local function stringSafe(s)
 return type(s)=="string" and #s>=1 and #s<=40 and
   s:match("^[A-Za-z0-9_]+$")~=nil
end
local function capText(s)
 if type(s)~="string" then return "NONE" end
 local v=s:upper():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
 if v=="ACCEPT" then return "ACCEPT"
 elseif v=="ACCEPT TRADE" then return "ACCEPT_TRADE"
 else return "NONE" end
end
local function visible(n,root)
 local step=0
 while n do
  step+=1
  if step>24 then return false end
  local ok,kind=pcall(function()return n:IsA("GuiObject")end)
  if not ok then return false end
  if kind and n.Visible~=true then return false end
  local screen=n:IsA("ScreenGui")
  if screen and n.Enabled~=true then return false end
  if n==root then return true end
  n=n.Parent
 end
 return false
end
local function partOfOffer(n,root)
 local count=0
 while n and n~=root do
  count+=1
  if count>24 then return true end
  -- MAIN-side Accept may legitimately live under YourOffer.
  -- Exclude ALT side and the *item slot* containers, not every MAIN child.
  if n.Name=="TheirOffer" or n.Name=="Accepted" or
      n.Name=="Decline" or n.Name=="Cancel" or
      n.Name=="Close" or n.Name=="Inventory" or
      n.Name:match("^NewItem%d+$") then return true end
  n=n.Parent
 end
 return n~=root
end
local function candidatePath(n,root)
 local parts,depth={},0
 local safeNodes={
  YourOffer=true,Buttons=true,Button=true,ActionButtons=true,
  Actions=true,Accept=true,AcceptButton=true,ActionButton=true,
  Confirm=true,ConfirmButton=true,Container=true,Frame=true,
  Main=true,MainActions=true,TradeButtons=true,TradeControls=true,
 }
 while n and n~=root do
  depth+=1
  if depth>8 or not stringSafe(n.Name) or not safeNodes[n.Name] then
   -- Do NOT export dynamic names (which may be player usernames).
   return nil
  end
  table.insert(parts,1,n.Name)
  n=n.Parent
 end
 if n~=root or #parts<1 then return nil end
 return table.concat(parts,"/")
end
local function boundedRect(n,viewport)
 if type(viewport)~="table" or type(viewport.x)~="number" or
    type(viewport.y)~="number" or viewport.x~=viewport.x or
    viewport.y~=viewport.y or viewport.x<300 or viewport.y<260 then return nil end
 local ok,pos,dim=pcall(function()return n.AbsolutePosition,n.AbsoluteSize end)
 if not ok or not pos or not dim then return nil end
 local x,y,w,h=pos.X,pos.Y,dim.X,dim.Y
 for _,v in ipairs({x,y,w,h}) do
  if type(v)~="number" or v~=v or
      v==math.huge or v==-math.huge then return nil end
 end
 if w<14 or h<10 or x<0 or y<0 or
     x+w>viewport.x+2 or y+h>viewport.y+2 then return nil end
 return {x=math.floor(x),y=math.floor(y),w=math.floor(w),h=math.floor(h)}
end
function M.inspect(root,viewport)
 local r={schema="gingerscope-alt-accept-control-shape-v1",
  status="UNAVAILABLE",reason="TRADE_ROOT_MISSING",
  candidateCount=0,visibleButtonCount=0,labelOnlyCount=0,
  possibleRemoteStatus="NOT_INSPECTED",
  candidatePath="NOT_MAPPED",candidateClass="NONE",candidateLabel="NONE",
  candidateActive=false,candidateBoundsVerified=false,
  clientOnly=true,readOnly=true,authorizesAccept=false,
  authorizesOffer=false,actualAccepts=0}
 if not root then return r end
 local ok,desc=pcall(function()return root:GetDescendants()end)
 if not ok or type(desc)~="table" then
  r.reason="TRADE_DESCENDANTS_UNAVAILABLE";return r
 end
 if #desc>1000 then
  r.status="BLOCKED";r.reason="TRADE_GUI_DESCENDANT_CAP";return r
 end
 local names={}
 for _,node in ipairs(desc) do
  local valid=type(node)=="table" or typeof and typeof(node)=="Instance"
  if valid and visible(node,root) and not partOfOffer(node,root) then
   local okText,t=pcall(function()return node:IsA("TextButton")end)
   local okImage,img=pcall(function()return node:IsA("ImageButton")end)
   if okText and okImage then
    local isButton=t or img
    if isButton then r.visibleButtonCount+=1 end
    local isLabel=node:IsA("TextLabel")
    local label=capText(((t or isLabel) and node.Text) or "")
    local isAcceptName=node.Name=="Accept" or node.Name=="AcceptButton"
    local parentName=node.Parent and node.Parent.Name or ""
    local namedAncestor=parentName=="Accept" or parentName=="AcceptButton"
    if (isAcceptName or namedAncestor or label~="NONE") and
        not (node.Name=="Accepted" or node.Name=="TheirAccepted") then
     if isButton then
      local path=candidatePath(node,root)
      local rect=boundedRect(node,viewport)
      r.candidateCount+=1
      if r.candidateCount==1 then
       r.candidatePath=path or "UNSAFE_PATH"
       r.candidateClass=t and "TextButton" or "ImageButton"
       r.candidateLabel=label
       r.candidateActive=node.Active==true
       r.candidateBoundsVerified=rect~=nil
      end
      if path then names[path]=true end
     else
      r.labelOnlyCount+=1
     end
    elseif not isButton and label~="NONE" then
     r.labelOnlyCount+=1
    end
   end
  end
 end
 if r.candidateCount==1 and r.candidatePath~="UNSAFE_PATH" and
   r.candidateBoundsVerified then
  r.status="ONE_VISIBLE_CANDIDATE_SHAPE"
  r.reason="UI_SHAPE_ONLY_NO_NATIVE_ACTION_PROOF"
 elseif r.candidateCount>1 then
  r.status="AMBIGUOUS"
  r.reason="MULTIPLE_POTENTIAL_ACCEPT_BUTTONS"
 elseif r.candidateCount==0 then
  r.status="INCONCLUSIVE"
  r.reason="NO_MATCHED_ACCEPT_BUTTON"
 else
  r.status="INCONCLUSIVE"
  r.reason="CANDIDATE_SHAPE_OR_BOUNDS_UNVERIFIED"
 end
 return r
end
function M.remotePresence(rs)
 local r="ABSENT_OR_UNVERIFIED"
 local success,folder=pcall(function()
  return rs and rs:FindFirstChild("Trade")
 end)
 if not success or not folder then return r end
 local ok,remote=pcall(function()return folder:FindFirstChild("AcceptTrade")end)
 if not ok or not remote then return r end
 local good,isEvent=pcall(function()return remote:IsA("RemoteEvent")end)
 if good and isEvent then return "NAMED_REMOTE_EVENT_EXISTS_UNAUTHENTICATED" end
 return "NAMED_NODE_IS_NOT_REMOTE_EVENT"
end
return M
