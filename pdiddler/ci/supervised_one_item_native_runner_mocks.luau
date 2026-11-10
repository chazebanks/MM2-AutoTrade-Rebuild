-- Execute the EXACT supervised iPad loader with fake Roblox GUI, RenderStepped,
-- ORIGINAL protected TradeIO and real pure policy/Stage100 geometry modules.
-- Tests both physical offer safety and mandatory MAIN/ALT on-screen guidance.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runnerSource=fs.readFile("pdiddler/supervised/SUPERVISED_ONE_ITEM_MANUAL_PILOT.lua")
local tradeIOSource=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local policySource=fs.readFile("pdiddler/supervised/supervised_one_item_policy.lua")
local overlaySource=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local tests=0
local function check(value,expected,label)
 tests+=1
 assert(value==expected,tostring(label)..": "..tostring(value).." ~= "..tostring(expected))
end
local function event()
 local handlers={}
 local ev={}
 function ev:Connect(fn)
  local h={fn=fn,connected=true}
  table.insert(handlers,h)
  return {Disconnect=function()
    h.connected=false
  end}
 end
 function ev:Fire()
  for _,h in ipairs(handlers) do if h.connected then h.fn() end end
 end
 return ev
end
local function vec(x,y)return {X=x,Y=y}end
local function node(class,name)
 local o={ClassName=class,Name=name or class,Visible=true,Enabled=true,
          Active=false,children={},AbsolutePosition=vec(0,0),
          AbsoluteSize=vec(0,0),Activated=event()}
 function o:IsA(kind)
   return kind==self.ClassName or (kind=="GuiObject" and
       (class=="Frame" or class=="TextLabel" or class=="TextButton"))
 end
 function o:FindFirstChild(k)return self.children[k] end
 function o:GetDescendants()return {} end
 function o:GetAttribute(k)return nil end
 function o:GetFullName()return self.Name end
 function o:put(n)
    n.Parent=self
    self.children[n.Name]=n
    return n
 end
 function o:Destroy()self.Parent=nil;self.Visible=false end
 return o
end
local function fakeEnv(options)
 options=options or {}
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 local layout=screen:put(node("Frame","Container"))
 local t=layout:put(node("Frame","Trade"))
 t.AbsolutePosition=vec(options.x or 370,options.y or 150)
 t.AbsoluteSize=vec(options.w or 440,options.h or 410)
 if options.startClosed then screen.Enabled=false end
 local ours=t:put(node("Frame","YourOffer"))
 ours:put(node("Frame","Container"))
 local accepted=ours:put(node("Frame","Accepted"))
 accepted.Visible=false
 local theirs=t:put(node("Frame","TheirOffer"))
 theirs:put(node("Frame","Container"))
 local theirAccepted=theirs:put(node("Frame","Accepted"))
 theirAccepted.Visible=false
 local username=theirs:put(node("TextLabel","Username"))
 username.Text="TrustedAlt"
 local players={}
 local lp={Name="MainAccount",UserId=1,Parent=players}
 players.LocalPlayer=lp
 local partner={Name="TrustedAlt",DisplayName="TrustedAlt",UserId=2,Parent=players}
 function players:FindFirstChild(name)
   if name=="TrustedAlt" then return partner end
 end
 function players:GetPlayers()return {lp,partner} end
 function lp:FindFirstChildOfClass(kind)
   if kind=="PlayerGui" then return pg end
 end
 local remote=node("RemoteEvent","OfferItem")
 local calls={}
 function remote:FireServer(raw,category)
   table.insert(calls,{raw=raw,category=category})
 end
 local tradeFolder=node("Folder","Trade")
 tradeFolder:put(remote)
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 RS:put(tradeFolder)
 local runService={RenderStepped=event()}
 local world={CurrentCamera={ViewportSize=vec(options.vw or 1024,options.vh or 768)}}
 if options.noCamera then world.CurrentCamera=nil end
 local service={Players=players,ReplicatedStorage=RS,
       VirtualInputManager={},GuiService={},Workspace=world,
       RunService=runService,
       HttpService={JSONEncode=function(_,value)
          if options.jsonFailure then error("mock JSON unavailable") end
          return serde.encode("json",value)
       end}}
 if options.noRender then service.RunService=nil end
 local sourceReads={}
 local game={
   PlaceId=142823291,JobId="MOCK_JOB_123",
   GetService=function(_,name)return service[name] end,
   HttpGet=function(_,url)
     table.insert(sourceReads,url)
     if url:find("a599c31c53d25e6799b9d631f45f282b445dcda0",1,true)
        and url:find("pdiddler4_tradeio_supervised_v2.lua",1,true)
     then return tradeIOSource end
     if url:find("9540fc5fc3576729f9dd308d8d8222d848e27063",1,true)
        and url:find("supervised_one_item_policy.lua",1,true)
     then return policySource end
     if url:find("5b8ee35d7f281c23d9c2181abd97a063e59a0660",1,true)
        and url:find("stage100_screen_prompt_overlay.lua",1,true)
     then return overlaySource end
     error("not immutable audited source: "..url)
   end
 }
 local E={PDIDDLER_SUPERVISED_ONE_ITEM_PILOT={
   armed=true,manualOfferOnly=true,targetName="TrustedAlt",weaponKey="Iceblaster"
 }}
 local created={}
 local createIndex=0
 local instance={}
 function instance.new(class)
    createIndex+=1
    if options.failUI and class=="ScreenGui" then error("cannot create UI") end
    local n=node(class)
    table.insert(created,n)
    return n
 end
 local enums={
   ZIndexBehavior={Sibling="Sibling"},
   TextXAlignment={Left="Left"},
   Font={GothamBold="GothamBold"}
 }
 local copied={}
 local stepTexts={}
 local waitCount=0
 local env={
    game=game,getgenv=function()return E end,
    Instance=instance,Enum=enums,
    setclipboard=function(txt)
        if options.clipboardFailure then error("clipboard permission denied") end
        table.insert(copied,txt)
    end,
    UDim={new=function(...)return {...}end},
    UDim2={fromOffset=function(...)return {...}end},
    Color3={fromRGB=function(...)return {...}end},
    warn=function()end,
    print=function(...)
       local first=tostring(select(1,...))
       if first:find("MAIN",1,true) then table.insert(stepTexts,first) end
    end,
    task={wait=function()
       waitCount+=1
       if options.startClosed and options.openAfter==waitCount then
         screen.Enabled=true
       end
       if options.moveDuringOffer and waitCount==1 then
         t.AbsolutePosition=vec(0,0)
         t.AbsoluteSize=vec(1024,768)
       end
       if options.shrinkDuringOffer and waitCount==1 then
         world.CurrentCamera.ViewportSize=vec(240,250)
       end
       if options.hideDuringOffer and waitCount==1 then screen.Enabled=false end
       runService.RenderStepped:Fire()
    end}
 }
 if options.clipboardUnavailable then env.setclipboard=nil end
 if options.toclipboardOnly then
    env.toclipboard=env.setclipboard
    env.setclipboard=nil
 end
 env.loadstring=function(source)
   return luau.load(source,{environment=env,injectGlobals=true})
 end
 local function execute()
   return luau.load(runnerSource,{environment=env,injectGlobals=true})()
 end
 return {run=execute,E=E,t=t,screen=screen,partner=partner,
         username=username,calls=calls,reads=sourceReads,created=created,
         accepted=accepted,theirAccepted=theirAccepted,world=world,
         stepTexts=stepTexts,runService=runService,pg=pg,
         copied=copied}
end
local success=fakeEnv()
local report=success.run()
check(type(report),"table","runner returns sanitized status")
check(report.status,"OFFER_REMOTE_FIRED_GUI_UNCONFIRMED","no invented proof")
check(report.tradeOutcome,"UNKNOWN","outcome remains unknown")
check(report.clipboardCopied,true,"clipboard written automatically")
check(#success.copied,1,"one sanitized report copy")
check(success.copied[1]:find("UNKNOWN",1,true)~=nil,true,"client unknown copied")
for _,secret in ipairs({"Iceblaster","TrustedAlt","MainAccount","MOCK_JOB_123"}) do
  check(success.copied[1]:find(secret,1,true),nil,"no sensitive "..secret)
end
check(report.authorizesAccept,false,"never automatic final Accept")
check(report.mayReportProfit,false,"no profit")
check(report.onScreenGuideShown,true,"on-screen guide shown before offer")
check(report.onScreenGuideFinalShown,true,"terminal text persists")
check(report.onScreenGuidePlacementFailures,0,"safe geometry")
check(#success.calls,1,"exactly one physical OfferItem")
check(success.calls[1].raw,"Iceblaster","correct item")
check(success.calls[1].category,"Weapons","correct weapons category")
check(#success.reads,3,"three immutable code reads incl original geometry")
check(success.E.PDIDDLER_SUPERVISED_ONE_ITEM_SPENT_JOB,"MOCK_JOB_123","single job spent")
check(success.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.armed,false,"arm consumed")
check(success.run(),nil,"no retry after first offer")
check(#success.calls,1,"no repeated remote")
local panel
for _,n in ipairs(success.created) do
    if n.ClassName=="Frame" and n.Name=="CurrentStep" then panel=n end
end
check(panel~=nil,true,"actual frame exists")
check(panel.Visible,true,"final panel remains visible")
local action=panel.children.Action
-- GUI elements are parented by Instance assignment, not through :put in this
-- mock; verify final textual state through owned created nodes.
local finalHasUnknown=false
local steps=0
for _,n in ipairs(success.created) do
    if n.Name=="Action" and tostring(n.Text):find("UNKNOWN",1,true) then
        finalHasUnknown=true
    end
    if n.Name=="Step" and tostring(n.Text):find("PASS",1,true) then steps+=1 end
end
check(finalHasUnknown,true,"on-screen UNKNOWN in final")
check(steps,0,"unconfirmed status does not say PASS")
-- Newly open trade: no automatic trade request, display step 1 before opening.
local delayed=fakeEnv({startClosed=true,openAfter=3})
check(delayed.run().status,"OFFER_REMOTE_FIRED_GUI_UNCONFIRMED","wait for manual trade")
check(#delayed.calls,1,"one attempt after manual open")
-- Every layout is tested against the exact existing Stage100 geometry module.
for _,shape in ipairs({
    {vw=1024,vh=768,x=370,y=150,w=440,h=410},
    {vw=1024,vh=768,x=32,y=100,w=400,h=530},
    {vw=1024,vh=768,x=600,y=100,w=400,h=530},
    {vw=844,vh=390,x=400,y=85,w=350,h=240},
    {vw=1180,vh=820,x=420,y=180,w=350,h=480},
}) do
    local x=fakeEnv(shape)
    local r=x.run()
    check(r.offerCount,1,"safe distinct viewport & trade root")
    check(r.onScreenGuideFinalShown,true,"visible final panel")
end
local invalid={
 {options={vw=240,vh=250},reason="ONSCREEN_GUIDE_SCREEN_TOO_SMALL"},
 {options={w=1024,h=768,x=0,y=0},reason="ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE"},
 {options={w=0,h=0},reason="ONSCREEN_GUIDE_TRADE_BOUNDS_UNAVAILABLE"},
 {options={noCamera=true},reason="ONSCREEN_GUIDE_VIEWPORT_OR_RENDER_UNAVAILABLE"},
 {options={noRender=true},reason="ONSCREEN_GUIDE_VIEWPORT_OR_RENDER_UNAVAILABLE"},
 {options={failUI=true},reason="ONSCREEN_GUIDE_CREATION_FAILED"},
 {options={moveDuringOffer=true},reason="ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE"},
 {options={shrinkDuringOffer=true},reason="ONSCREEN_GUIDE_SCREEN_TOO_SMALL"},
}
for i,c in ipairs(invalid) do
    local x=fakeEnv(c.options)
    local r=x.run()
    check(type(r),"table","guard failure report "..i)
    check(r.status,"BLOCKED","no offer on geometry failure "..i)
    check(r.reason,c.reason,"precise geometry reason "..i)
    check(#x.calls,0,"NO remote on geometry failure "..i)
end
local silent=fakeEnv({startClosed=true})
local timeout=silent.run()
check(timeout.status,"BLOCKED","timeout missing manually opened trade")
check(timeout.reason,"MANUAL_TRADE_OPEN_TIMED_OUT","bounded wait")
check(#silent.calls,0,"no offer if trade never opened")
check(#silent.copied,1,"timeout result copied too")
local unavail=fakeEnv({clipboardUnavailable=true})
local unavailReport=unavail.run()
check(unavailReport.clipboardCopied,false,"missing clipboard detected without fatal error")
check(unavailReport.offerCount,1,"missing clipboard does not alter OfferItem behavior")
local failed=fakeEnv({clipboardFailure=true})
check(failed.run().clipboardCopied,false,"clipboard permission error handled")
local badJson=fakeEnv({jsonFailure=true})
check(badJson.run().clipboardCopied,false,"JSON encoding failure handled")
local cases={
 function(x)x.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.armed=false end,
 function(x)x.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.weaponKey="Gingerscope" end,
 function(x)x.E.PDIDDLER_SUPERVISED_ONE_ITEM_PILOT.targetName="AnotherPerson" end,
 function(x)x.partner.Parent=nil end,
 function(x)x.username.Text="AnotherPerson" end,
 function(x)x.accepted.Visible=true end,
 function(x)x.theirAccepted.Visible=true end,
 function(x)x.t:FindFirstChild("TheirOffer").children.Accepted=nil end,
 function(x)x.t:FindFirstChild("YourOffer").children.Container=nil end,
 function(x)x.E.PDIDDLER_OUTGOING_SESSION=1 end,
 function(x)x.E.PDIDDLER_PART4_SESSION=1 end,
 function(x)x.E.GINGERSCOPE_STAGE106_READONLY_WITNESS={running=true} end,
}
for i,alter in ipairs(cases) do
 local x=fakeEnv()
 alter(x)
 local r=x.run()
 if r then
   check(r.tradeOutcome,"UNKNOWN","invalid remains unknown "..i)
   check(r.authorizesAccept,false,"invalid never final Accept "..i)
 end
 check(#x.calls,0,"no unapproved item offer "..i)
end
print("[PASS] actual supervised iPad loader + on-screen guide mocks:",tests)
print("[PASS] live rendering geometry, MAIN steps, negative screens, 1 offer max, no Accept")
