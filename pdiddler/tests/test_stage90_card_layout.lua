-- Stage90 actual Lua5.4 PURE layout module + native wrapper mocked GUI tests.
-- 100% read-only; all player names are local synthetic test labels.
local CORE="pdiddler/intelligence_lab/stage90_card_layout_readonly.lua"
local WRAPPER="pdiddler/new_part4/STAGE90_READONLY_CARD_LAYOUT.lua"
local M=dofile(CORE)
local total=0
local function group(name,fn)
 local ok,reason=pcall(fn)
 if not ok then error("FAIL "..name.." => "..tostring(reason)) end
 total=total+1;print("PASS "..name)
end
local function node(kind,name,parent,txt,x,y,w,h)
 local o={ClassName=kind,Name=name,Parent=parent,Visible=true,
  Enabled=true,Text=txt,AbsolutePosition={X=x or 50,Y=y or 50},
  AbsoluteSize={X=w or 50,Y=h or 25},members={},array={}}
 function o:IsA(class)
  return class==self.ClassName or
   (class=="GuiObject" and (self.ClassName=="Frame" or
    self.ClassName=="TextLabel" or self.ClassName=="TextButton")) or
   (class=="GuiButton" and self.ClassName=="TextButton")
 end
 function o:FindFirstChild(key)return self.members[key] end
 function o:GetChildren()return self.array end
 function o:GetDescendants()
  local out={}
  local function walk(t)
   for _,child in ipairs(t.array) do
    out[#out+1]=child
    walk(child)
   end
  end
  walk(self)
  return out
 end
 if parent then
  parent.members[name]=o
  parent.array[#parent.array+1]=o
 end
 return o
end
local function gui(kind,username)
 local pg=node("PlayerGui","PlayerGui")
 local screen=node("ScreenGui","MM2Gui",pg)
 local branch=node("Frame","Game",screen)
 local board=node("Frame","Leaderboard",branch)
 node("Frame","Container",board)
 local popup,header,trade,sub=nil,nil,nil,nil
 if kind=="direct" or kind=="wrongheader" or kind=="hiddenpopup"
    or kind=="noheader" then
  popup=node("Frame","Popup",board)
  sub=node("Frame","Container",popup)
  if kind~="noheader" then
   header=node("TextLabel","Username",sub,
    kind=="wrongheader" and "other_player" or username,120,148,130,25)
  end
  local controls=node("Frame","Action",sub)
  node("TextButton","Profile",controls,"Profile",95,235,60,30)
  trade=node("TextButton","Trade",controls,"Trade",140,235,80,30)
  if kind=="hiddenpopup" then popup.Visible=false end
 elseif kind=="sibling" or kind=="embedded" or kind=="unrelated" then
  local card=node("Frame","Card",board)
  local controls=node("Frame","Action",card)
  node("TextButton","Profile",controls,"Profile",95,235,60,30)
  trade=node("TextButton","Trade",controls,"Trade",140,235,80,30)
  local labelParent=kind=="embedded" and controls or card
  local labelText=kind=="unrelated" and "wrong_person" or username
  header=node("TextLabel","Username",labelParent,labelText,135,156,110,25)
 end
 return pg,board,popup,header,trade
end
group("exact direct-popup header + Trade button recognized read-only",function()
 local p=gui("direct","test_partner")
 local r=M.inspect(p,"test_partner")
 assert(r.scanStatus=="OBSERVED" and r.layout=="DIRECT_POPUP_HEADER_MATCH")
 assert(r.directPopupVisible==1 and r.directHeaderMatches==1)
 assert(r.directTradeButtonVisible==1 and r.visibleBoardCount==1)
end)
group("username case and @ normalization do not leak a name",function()
 local p=gui("direct","@TEST_PARTNER")
 local r=M.inspect(p,"test_partner")
 assert(r.layout=="DIRECT_POPUP_HEADER_MATCH")
 for k,v in pairs(r) do
  assert(not tostring(k):find("partner",1,true))
  assert(not tostring(v):find("partner",1,true))
 end
end)
group("old v18 sibling-header card is detectable WITHOUT clicking",function()
 local p=gui("sibling","test_partner")
 local r=M.inspect(p,"test_partner")
 assert(r.layout=="SIBLING_USERNAME_NEAR_PROFILE_TRADE",r.layout)
 assert(r.directPopupVisible==0 and r.profileTradeCards>=1)
 assert(r.alternativeNearbyHeaderMatches>=1)
end)
group("fallback card with embedded username recognized structurally",function()
 local p=gui("embedded","test_partner")
 local r=M.inspect(p,"test_partner")
 assert(r.layout=="ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME")
 assert(r.alternativeExactCardTextMatches>=1)
end)
group("wrong username direct popup and unrelated card NOT verified",function()
 local p=gui("wrongheader","test_partner")
 local r=M.inspect(p,"test_partner")
 assert(r.directPopupVisible==1 and r.directHeaderMatches==0)
 assert(r.layout=="DIRECT_TRADE_VISIBLE_HEADER_MISMATCH")
 p=gui("unrelated","test_partner")
 r=M.inspect(p,"test_partner")
 assert(r.layout~="SIBLING_USERNAME_NEAR_PROFILE_TRADE")
 assert(r.layout~="ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME")
end)
group("closed popup and absent card NOT verified",function()
 local p=gui("hiddenpopup","test_partner")
 local r=M.inspect(p,"test_partner")
 assert(r.directPopupVisible==0 and r.directHeaderMatches==0)
 assert(r.layout=="NO_TARGET_CARD_CONFIRMED")
 p=gui("empty","test_partner")
 r=M.inspect(p,"test_partner")
 assert(r.layout=="NO_TARGET_CARD_CONFIRMED")
end)
group("direct Trade but no expected direct Username proves only layout mismatch",function()
 local p=gui("noheader","test_partner")
 local r=M.inspect(p,"test_partner")
 assert(r.directHeaderAbsent==1 and r.directHeaderMatches==0)
 assert(r.layout=="DIRECT_TRADE_VISIBLE_HEADER_MISMATCH")
end)
group("hidden leaderboard never returns named card match",function()
 local pg,b=gui("direct","test_partner")
 b.Visible=false
 local r=M.inspect(pg,"test_partner")
 assert(r.layout=="NO_VISIBLE_LEADERBOARD")
 assert(r.directHeaderMatches==0)
end)
group("invalid, nil and empty input fail closed",function()
 local p=gui("direct","test_partner")
 assert(M.inspect(nil,"test_partner").scanStatus=="INVALID_INPUT")
 assert(M.inspect(p,nil).scanStatus=="INVALID_INPUT")
 assert(M.inspect(p,"").scanStatus=="INVALID_INPUT")
end)
local function mockRun(mode)
 mode=mode or {}
 local tick=100
 local pg,board=gui(mode.card or "direct","test_partner")
 local players={Name="Players"}
 local lp={Name="test_main",UserId=1,Parent=players}
 local target={Name="test_partner",UserId=2,Parent=players}
 pg.Parent=lp
 function lp:FindFirstChildOfClass(s)
  assert(s=="PlayerGui")
  return pg
 end
 function players:GetPlayers()return mode.noTarget and {lp} or {lp,target} end
 function players:GetPlayerByUserId(uid)
  if uid==2 and not mode.noTarget then return target end
 end
 local env={PDIDDLER_STAGE90_TARGET_USERNAME=mode.targetName or "test_partner",
  PDIDDLER_STAGE90_READONLY_ARMED=mode.armed~=false}
 if mode.otherScript then env.GINGERSCOPE_STAGE89_SINGLE_REQUEST_DIAGNOSTIC={} end
 local stats={gets=0,clipboard=nil,remotes=0}
 _G.getgenv=function()return env end
 _G.warn=function()end
 _G.os.clock=function()return tick end
 _G.setclipboard=function(v)stats.clipboard=v end
 local gameObj={PlaceId=mode.wrongPlace and 42 or 142823291,JobId="test_job"}
 function gameObj:GetService(name)
  if name=="Players" then
   players.LocalPlayer=lp
   return players
  elseif name=="HttpService" then
   return {JSONEncode=function(_,result)
    assert(result.readOnly==true)
    assert(result.actualRequestTaps==0 and result.actualOffers==0)
    assert(result.actualAccepts==0 and result.actualDeclines==0)
    assert(result.authorizesTrade==false and result.authorizesAccept==false)
    for k,v in pairs(result) do
     assert(not tostring(k):find("test_partner",1,true))
     assert(not tostring(v):find("test_partner",1,true))
    end
    return '{"stage":"90","status":"'..result.status..'"}'
   end}
  end
  error("Unexpected service "..tostring(name))
 end
 function gameObj:HttpGet(uri,cache)
  stats.gets=stats.gets+1
  assert(cache==true)
  assert(uri:find("14fefa245f0e3b72303f72b93101dd9b773e5e7d",1,true))
  if mode.failFetch then error("offline mock no source") end
  local f=assert(io.open(CORE,"rb"))
  local s=f:read("*a");f:close()
  return s
 end
 _G.game=gameObj
 _G.loadstring=load
 _G.task={wait=function(step)
  tick=tick+(step or 0.2)
  if mode.changeJob and tick>100.6 then gameObj.JobId="changed_job" end
 end}
 local ok,result=pcall(dofile,WRAPPER)
 assert(ok,result)
 return result,stats,env
end
group("actual wrapper direct card yields read-only structural evidence",function()
 local r,s,e=mockRun()
 assert(r.report.status=="CARD_LAYOUT_OBSERVED",r.report.reason)
 assert(r.report.layout=="DIRECT_POPUP_HEADER_MATCH")
 assert(r.report.targetInServer and r.report.samples>=1)
 assert(s.gets==1 and s.clipboard:find("[GINGERSCOPE STAGE90 CARD LAYOUT]",1,true))
end)
group("actual wrapper recognizes sibling header without any physical request",function()
 local r,s=mockRun({card="sibling"})
 assert(r.report.status=="CARD_LAYOUT_OBSERVED")
 assert(r.report.layout=="SIBLING_USERNAME_NEAR_PROFILE_TRADE")
 assert(r.report.actualRequestTaps==0)
end)
group("actual wrapper fails inconclusive when player card never opens",function()
 local r,s=mockRun({card="empty"})
 assert(r.report.status=="CARD_LAYOUT_UNRESOLVED")
 assert(r.report.layout=="NO_TARGET_CARD_CONFIRMED")
 assert(r.report.samples>=30 and s.gets==1)
end)
group("wrong game, unarmed, already-active diagnostic do not download",function()
 for _,opts in ipairs({{wrongPlace=true},{armed=false},{otherScript=true}}) do
  local r,s=mockRun(opts)
  assert(r==nil and s.gets==0)
 end
end)
group("absent target blocks before any source fetch",function()
 local r,s=mockRun({noTarget=true})
 assert(r.report.status=="HELD")
 assert(s.gets==0)
end)
group("pinned source cannot be fetched means inconclusive",function()
 local r,s=mockRun({failFetch=true})
 assert(r.report.status=="INCONCLUSIVE")
 assert(s.gets==1)
end)
group("changed job aborts rather than report layout success",function()
 local r,s=mockRun({card="empty",changeJob=true})
 assert(r.report.status=="HELD")
 assert(r.report.reason=="SESSION_CHANGED_AFTER_INSPECTION")
end)
group("one-shot cannot silently repeat in same client session",function()
 local r,s,e=mockRun()
 local before=s.gets
 assert(dofile(WRAPPER)==nil)
 assert(s.gets==before)
end)
print("STAGE90_CARD_LAYOUT_LUA_PASS groups="..total)
