-- Stage90 PURE GUI layout census. Never clicks and never exports usernames.
-- Read-only inspection of original MM2 leaderboard and nearby card headers.
local M={}
local function trim(s)
 if type(s)~="string" then return "" end
 return s:gsub("^%s+",""):gsub("%s+$",""):gsub("^@",""):lower()
end
local function safeIs(o,kind)
 local ok,result=pcall(function()return o:IsA(kind)end)
 return ok and result==true
end
local function child(o,name)
 if not o then return nil end
 local ok,result=pcall(function()return o:FindFirstChild(name)end)
 return ok and result or nil
end
local function descendants(o)
 local ok,items=pcall(function()return o:GetDescendants()end)
 if ok and type(items)=="table" and #items<=12000 then return items end
 return {}
end
local function visible(o)
 if not o then return false end
 local current,depth=o,0
 while current and depth<40 do
  if safeIs(current,"ScreenGui") and current.Enabled==false then return false end
  if safeIs(current,"GuiObject") and current.Visible==false then return false end
  current=current.Parent
  depth=depth+1
 end
 return current==nil
end
local function text(o)
 if not o or not (safeIs(o,"TextLabel") or safeIs(o,"TextButton")) then return "" end
 local ok,t=pcall(function()return o.Text end)
 return ok and type(t)=="string" and t or ""
end
local function center(o)
 local ok,x,y,w,h=pcall(function()
  local p,s=o.AbsolutePosition,o.AbsoluteSize
  return p.X+s.X/2,p.Y+s.Y/2,s.X,s.Y
 end)
 if not ok or type(x)~="number" or type(y)~="number"
    or type(w)~="number" or type(h)~="number"
    or w<=0 or h<=0 or w>1500 or h>900 then return nil end
 return x,y,w,h
end
local function belongs(o,ancestor)
 local cur=o
 for _=1,30 do
  if cur==ancestor then return true end
  if not cur then break end
  cur=cur.Parent
 end
 return false
end
local function cardContainer(button)
 local p=button
 for _=1,8 do
  if not p then break end
  local profile,trade=false,false
  for _,d in ipairs(descendants(p)) do
   if visible(d) then
    local t=trim(text(d))
    if t=="profile" then profile=true end
    if t=="trade" then trade=true end
   end
  end
  if profile and trade then return p end
  p=p.Parent
 end
end
local function clickable(o)
 if safeIs(o,"GuiButton") then return o end
 local p=o.Parent
 for _=1,5 do
  if not p then return nil end
  if safeIs(p,"GuiButton") then return p end
  p=p.Parent
 end
end
function M.inspect(pg,username)
 local r={
  scanStatus="OBSERVED",boardCount=0,visibleBoardCount=0,
  directPopupVisible=0,directTradeButtonVisible=0,
  directHeaderMatches=0,directHeaderAbsent=0,
  alternateTradeControlCount=0,profileTradeCards=0,
  alternativeExactCardTextMatches=0,alternativeNearbyHeaderMatches=0,
  visibleTextNodesInspected=0,layout="NO_TARGET_CARD_CONFIRMED"
 }
 if type(username)~="string" or trim(username)=="" or not pg then
  r.scanStatus="INVALID_INPUT";return r
 end
 local guis={}
 local ok,children=pcall(function()return pg:GetChildren()end)
 if not ok or type(children)~="table" then
  r.scanStatus="GUI_UNAVAILABLE";return r
 end
 for _,gui in ipairs(children) do
  if safeIs(gui,"ScreenGui") and visible(gui) then
   for _,kind in ipairs({"Game","Lobby"}) do
    local branch=child(gui,kind)
    local board=child(branch,"Leaderboard")
    local container=child(board,"Container")
    if board and container then
     r.boardCount=r.boardCount+1
     if visible(board) then
      r.visibleBoardCount=r.visibleBoardCount+1
      guis[#guis+1]=board
      local popup=child(board,"Popup")
      if popup and visible(popup) then
       r.directPopupVisible=r.directPopupVisible+1
       local inner=child(popup,"Container")
       local header=child(inner,"Username")
       local action=child(inner,"Action")
       local trade=child(action,"Trade")
       if not header then r.directHeaderAbsent=r.directHeaderAbsent+1 end
       if trade and safeIs(trade,"GuiButton") and visible(trade) then
        r.directTradeButtonVisible=r.directTradeButtonVisible+1
        if header and visible(header) and trim(text(header))==trim(username) then
         r.directHeaderMatches=r.directHeaderMatches+1
        end
       end
      end
     end
    end
   end
  end
 end
 -- Audit old-v18 compatibility layout only as READ-ONLY structural evidence.
 -- No fallback shown by this module authorizes a button click.
 local seen={}
 for _,board in ipairs(guis) do
  local nodes=descendants(board)
  for _,d in ipairs(nodes) do
   if visible(d) and (safeIs(d,"TextLabel") or safeIs(d,"TextButton")) then
    r.visibleTextNodesInspected=r.visibleTextNodesInspected+1
    if trim(text(d))=="trade" then
     local button=clickable(d)
     if button and not seen[button] and visible(button) then
      seen[button]=true
      r.alternateTradeControlCount=r.alternateTradeControlCount+1
      local card=cardContainer(button)
      if card then
       r.profileTradeCards=r.profileTradeCards+1
       for _,node in ipairs(descendants(card)) do
        if visible(node) and trim(text(node))==trim(username) then
         r.alternativeExactCardTextMatches=r.alternativeExactCardTextMatches+1
         break
        end
       end
       local tx,ty,tw=center(button)
       if tx then
        for _,node in ipairs(nodes) do
         if visible(node) and trim(text(node))==trim(username) then
          local cx,cy=center(node)
          if cx and math.abs(cx-tx)<=math.max(170,tw*2.2)
             and ty-cy>=-25 and ty-cy<=185 then
           r.alternativeNearbyHeaderMatches=r.alternativeNearbyHeaderMatches+1
           break
          end
         end
        end
       end
      end
     end
    end
   end
  end
 end
 if r.directHeaderMatches>0 then r.layout="DIRECT_POPUP_HEADER_MATCH"
 elseif r.alternativeExactCardTextMatches>0 then r.layout="ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME"
 elseif r.alternativeNearbyHeaderMatches>0 then r.layout="SIBLING_USERNAME_NEAR_PROFILE_TRADE"
 elseif r.directTradeButtonVisible>0 then r.layout="DIRECT_TRADE_VISIBLE_HEADER_MISMATCH"
 elseif r.profileTradeCards>0 then r.layout="PROFILE_TRADE_VISIBLE_WITHOUT_TARGET_ID"
 elseif r.visibleBoardCount==0 then r.layout="NO_VISIBLE_LEADERBOARD"
 else r.layout="NO_TARGET_CARD_CONFIRMED" end
 return r
end
return M
