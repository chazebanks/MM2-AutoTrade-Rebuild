-- Execute ACTUAL iPad one-shot runner with MOCKED original MM2 services.
-- No Roblox account, real remotes, inventory, executor, item trade, or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local runnerSource=fs.readFile("pdiddler/supervised/SUPERVISED_ONE_ITEM_MANUAL_PILOT.lua")
local tradeIOSource=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local policySource=fs.readFile("pdiddler/supervised/supervised_one_item_policy.lua")
local tests=0
local function check(value,expected,label)
 tests+=1
 assert(value==expected,tostring(label)..": "..tostring(value).." ~= "..tostring(expected))
end
local function node(class,name)
 local o={ClassName=class,Name=name,Visible=true,Enabled=true,children={}}
 function o:IsA(kind)
   return kind==self.ClassName or (kind=="GuiObject" and
       (class=="Frame" or class=="TextLabel" or class=="TextButton"))
 end
 function o:FindFirstChild(k) return self.children[k] end
 function o:GetDescendants() return {} end
 function o:GetAttribute(k) return nil end
 function o:GetFullName() return self.Name end
 function o:put(n)
    n.Parent=self
    self.children[n.Name]=n
    return n
 end
 return o
end
local function create()
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 local layout=screen:put(node("Frame","Container"))
 local t=layout:put(node("Frame","Trade"))
 local ours=t:put(node("Frame","YourOffer"))
 ours:put(node("Frame","Container"))
 local accepted=ours:put(node("Frame","Accepted"))
 accepted.Visible=false
 local theirs=t:put(node("Frame","TheirOffer"))
 theirs:put(node("Frame","Container"))
 local label=theirs:put(node("TextLabel","Username"))
 label.Text="TrustedAlt"
 local players={}
 local lp={Name="MainAccount",UserId=1,Parent=players}
 local partner={Name="TrustedAlt",DisplayName="TrustedAlt",UserId=2,Parent=players}
 function players:FindFirstChild(name)
  if name=="TrustedAlt" then return partner end
 end
 function players:GetPlayers()return {lp,partner} end
 function lp:FindFirstChildOfClass(kind)
  if kind=="PlayerGui" then return pg end
 end
 local calls={}
 local remote=node("RemoteEvent","OfferItem")
 function remote:FireServer(raw,category)
  table.insert(calls,{raw=raw,category=category})
 end
 local tradeFolder=node("Folder","Trade")
 tradeFolder:put(remote)
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 RS:put(tradeFolder)
 local notify={}
 local starter={}
 function starter:SetCore(name,params)
  table.insert(notify,params)
 end
 local service={Players=players,ReplicatedStorage=RS,
       VirtualInputManager={},GuiService={},StarterGui=starter}
 local sourceReads={}
 local game={
   PlaceId=142823291,JobId="MOCK_JOB_123",
   GetService=function(_,name)return service[name] end,
   HttpGet=function(_,url)
     table.insert(sourceReads,url)
     if url:find("a599c31c53d25e6799b9d631f45f282b445dcda0",1,true)
       and url:find("pdiddler4_tradeio_supervised_v2.lua",1,true)
     then return tradeIOSource end
     if url:find("ee1bb98264963bbfaa9e760f21a613ba4ffe7d77",1,true)
       and url:find("supervised_one_item_policy.lua",1,true)
     then return policySource end
     error("not pinned public source")
   end
 }
 local E={PDIDDLER_SUPERVISED_ONE_ITEM_PILOT={
   armed=true,manualOfferOnly=true,targetName="TrustedAlt",
   weaponKey="Iceblaster"
 }}
 local env={
    game=game,getgenv=function()return E end,
    warn=function()end,print=function()end,
    task={wait=function()end},
 }
 env.loadstring=function(source)
  return luau.load(source,{environment=env,injectGlobals=true})
 end
 local function run()
    return luau.load(runnerSource,{environment=env,injectGlobals=true})()
 end
 return {run=run,E=E,t=t,screen=screen,partner=partner,
         username=label,calls=calls,notify=notify,reads=sourceReads,
         accepted=accepted,game=game}
end
local a=create()
local result=a.run()
check(type(result),"table","returns status")
check(result.tradeOutcome,"UNKNOWN","unknown")
check(result.mayReportProfit,false,"no profit")
check(result.authorizesAccept,false,"never final Accept")
check(result.mayRecordCompletedTrade,false,"not settlement")
check(result.status,"OFFER_REMOTE_FIRED_GUI_UNCONFIRMED","no invented GUI proof")
check(#a.calls,1,"exactly ONE OfferItem call")
check(a.calls[1].raw,"Iceblaster","exact operator-selected raw key")
check(a.calls[1].category,"Weapons","game weapon category")
check(#a.reads,2,"only two pinned PUBLIC SOURCE code GETs")
check(#a.notify,1,"status notification")
check(a.E.PDIDDLER_SUPERVISED_ONE_ITEM_SPENT_JOB,"MOCK_JOB_123","single job spent")
check(a.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.armed,false,"consume arm")
check(a.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT._consumed,true,"consumed")
check(a.run(),nil,"same job cannot send again")
check(#a.calls,1,"no resending")
local cases={
 function(x)x.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.armed=false end,
 function(x)x.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.weaponKey="Gingerscope" end,
 function(x)x.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.targetName="AnotherPerson" end,
 function(x)x.partner.Parent=nil end,
 function(x)x.username.Text="AnotherPerson" end,
 function(x)x.screen.Enabled=false end,
 function(x)x.accepted.Visible=true end,
 function(x)x.t:FindFirstChild("YourOffer").children.Container=nil end,
}
for i,alter in ipairs(cases) do
 local x=create()
 alter(x)
 local r=x.run()
 if r then
   check(r.tradeOutcome,"UNKNOWN","always unknown case"..i)
   check(r.authorizesAccept,false,"never final Accept case"..i)
 end
 check(#x.calls,0,"no unapproved offer on invalid case "..i)
end
print("[PASS] original iPad supervised 1-item runner mocked TradeGUI and protected remote:",tests)
print("[PASS] exactly 1 client offer attempt, zero retries, no Accept, completed trade, profit or Discord")
