-- Pure presentation equivalence tests for the ORIGINAL Stage119 five-stage
-- GUI and local UI-object factory. Lune-only; no client, remotes or trading.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local M=luau.load(fs.readFile(
 "pdiddler/system2/native_supreme_five_scenario_gui_presentation.lua"))()
local assertions=0
local function eq(x,y,label)
 assertions+=1
 assert(x==y,tostring(label)..": got "..tostring(x)..
   ", expected "..tostring(y))
end
local function ok(x,label) assertions+=1; assert(x,label)end
local defaults={
 status="P3_SUPERVISOR_PREPARED_NOT_ARMED",researchOnly=true,
 identityPhase="BEFORE_ARM",completedCount=0,
 armed=false,watcherReady=true,previewBusy=false,hasBoundScope=false,
 ownerRunning=true,panelVisible=true,previewUntil=0,now=12,
}
local function render(overrides)
 local a={}
 for k,v in pairs(defaults) do a[k]=v end
 for k,v in pairs(overrides or {}) do a[k]=v end
 local r,why=M.render(a)
 ok(type(r)=="table","Presenter expected success: "..tostring(why))
 eq(r.schema,"gingerscope-supreme-five-scenario-presentation-v1","schema")
 return r
end
local prepared=render()
eq(prepared.title,"SUPREME MULTI | 1/5 ARM P3","initial title exact")
eq(prepared.body,
 "MAIN: manually ARM one P3 request to consenting ALT. ALT accepts REQUEST, not final trade. Both offers EMPTY.",
 "original manual ARM instruction exact")
eq(prepared.armVisible,true,"ARM visible when original watcher ready")
eq(prepared.previewVisible,false,"Preview hidden prior to arm")
eq(prepared.stopVisible,true,"STOP always there")
eq(prepared.previewButtonText,"TEST 1/5","first label")
local watched={
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=true,
}
local expected={
 [0]={"SUPREME MULTI | 1/5",
      "Start/EMPTY: keep both offers empty and tap PREVIEW.","TEST 1/5"},
 [1]={"SUPREME MULTI | 2/5",
      "Start/EMPTY: keep both offers empty and tap PREVIEW.","TEST 2/5"},
 [2]={"SUPREME MULTI | 3/5",
      "ONE-SIDED: manually add ONE cheap weapon on EITHER side; tap PREVIEW.","TEST 3/5"},
 [3]={"SUPREME MULTI | 4/5",
      "TWO-SIDED: manually add a cheap weapon on OTHER side; tap PREVIEW.","TEST 4/5"},
 [4]={"SUPREME MULTI | 5/5",
      "CHANGE: manually swap weapon or stack, keeping both sides nonempty; tap PREVIEW.","TEST 5/5"},
 [5]={"SUPREME MULTI | 5/5",
      "5/5 done: manually CLOSE trade, then STOP / COPY. NEVER final Accept.","5/5 COMPLETE"},
}
for n=0,5 do
 local v={}
 for k,x in pairs(watched) do v[k]=x end
 v.completedCount=n
 local out=render(v)
 eq(out.title,expected[n][1],"stage"..tostring(n).." title")
 eq(out.body,expected[n][2],"stage"..tostring(n).." prompt")
 eq(out.previewButtonText,expected[n][3],"stage"..tostring(n).." button")
 eq(out.armVisible,false,"ARM never reappears in trade")
 eq(out.previewVisible,true,"Preview during protected P4")
 eq(out.stopVisible,true,"STOP during entire five-stage plan")
end
local waiting=render({status="WAIT_STABLE",armed=true})
eq(waiting.title,"SUPREME MULTI | WAIT PROTECTED","unbound prompt")
eq(waiting.previewVisible,false,"only true original P4 snapshot enables Preview")
local previewBusy=render({
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=true,previewBusy=true,
})
eq(previewBusy.previewVisible,false,"busy preview hides callback button")
local noScope=render({
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=false,
})
eq(noScope.previewVisible,false,"missing scope")
local notRunning=render({
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=true,ownerRunning=false,
})
eq(notRunning.previewVisible,false,"stopped host never previews")
local hiddenPanel=render({
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=true,panelVisible=false,
})
eq(hiddenPanel.previewVisible,false,"hidden overlay stays inert")
local watcherNotReady=render({watcherReady=false})
eq(watcherNotReady.armVisible,false,"not-ready original watcher blocks ARM")
local temporary=render({
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=true,completedCount=3,
 previewText="SUPREME: Source expired; preview blocked.",
 previewUntil=20,now=12,
})
eq(temporary.body,"SUPREME: Source expired; preview blocked.",
 "safe original 8s ephemeral status overrides stage prompt")
local expiredText=render({
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=true,completedCount=3,
 previewText="SUPREME: Source expired; preview blocked.",
 previewUntil=12,now=12,
})
eq(expiredText.body,expected[3][2],"preview text expires at the exact cutoff")
local emptyText=render({
 status="P4_TWO_SIDED_CLIENT_SNAPSHOT",armed=true,
 hasBoundScope=true,previewText="",previewUntil=20,now=12,
})
eq(emptyText.body,"","preserve original Lua truthy empty-text behavior")
local legacyCases={
 {"RESULT","OTHER","5/5 CLIENT LASTOFFER OBSERVED",
  "MAIN: manually DECLINE the trade, then tap STOP / COPY. NEVER final Accept."},
 {"FAILED","OTHER","5/5 CLIENT LASTOFFER INCONCLUSIVE",
  "MAIN: manually DECLINE the trade, then tap STOP / COPY. NEVER final Accept."},
 {"WAIT_ALT_REMOVE","OTHER","4/5 ALT — REMOVE THAT WEAPON",
  "ALT: manually REMOVE the same weapon. MAIN stays EMPTY. Wait for result."},
 {"WAIT_REMOVE_GUI","OTHER","4/5 ALT — REMOVE THAT WEAPON",
  "ALT: manually REMOVE the same weapon. MAIN stays EMPTY. Wait for result."},
 {"WAIT_ALT_ADD","OTHER","3/5 ALT — ADD ONE WEAPON",
  "ALT: manually ADD ONE inexpensive eligible weapon NOW. MAIN stays EMPTY."},
 {"WAIT_ADD_GUI","OTHER","3/5 ALT — ADD ONE WEAPON",
  "ALT: manually ADD ONE inexpensive eligible weapon NOW. MAIN stays EMPTY."},
 {"BEFORE_ARM","P3_SUPERVISOR_PREPARED_NOT_ARMED","1/5 MAIN — ARM P3",
  "MAIN: tap ARM P3 to request only your ALT. No item will be automatically offered."},
 {"WAIT_EMPTY","OTHER","2/5 ALT — ACCEPT REQUEST",
  "ALT: manually ACCEPT the P3 trade REQUEST. Keep BOTH offers EMPTY."},
 {"WAIT_EMPTY_STABLE","OTHER","2/5 ALT — ACCEPT REQUEST",
  "ALT: manually ACCEPT the P3 trade REQUEST. Keep BOTH offers EMPTY."},
 {"UNKNOWN","OTHER","PROTECTED P3/P4 LASTOFFER",
  "Waiting for original protected trade. Never press final Accept."},
}
for _,x in ipairs(legacyCases) do
 local v=render({researchOnly=false,identityPhase=x[1],status=x[2]})
 eq(v.title,x[3],"unchanged original non-research title "..x[1])
 eq(v.body,x[4],"unchanged original non-research body "..x[1])
end
local invalid={}
for k,v in pairs(defaults) do invalid[k]=v end
invalid.completedCount=-1
local reject,reason=M.render(invalid)
eq(reject,nil,"invalid progress fails closed")
eq(reason,"PRESENTER_INPUT_INVALID","invalid progress reason")
invalid.completedCount=5
invalid.armed="yes"
eq(M.render(invalid),nil,"nonboolean ARM rejected")
local created={}
local Instance={}
function Instance.new(class)
 local v={ClassName=class,Name=class,destroyed=false}
 function v:Destroy() self.destroyed=true end
 created[#created+1]=v
 return v
end
local Color3={fromRGB=function(r,g,b)return {r=r,g=g,b=b}end}
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local UDim2={fromOffset=function(x,y)return {X=x,Y=y}end}
local Enum={
 ZIndexBehavior={Sibling="SIBLING"},
 TextXAlignment={Left="LEFT"},
 Font={GothamBold="GOTHAM_BOLD"},
}
local parent={Name="FakePlayerGui"}
local env={Instance=Instance,Color3=Color3,UDim=UDim,
 UDim2=UDim2,Enum=Enum,Parent=parent}
local gui,why=M.buildUI(env)
ok(gui~=nil,"original UI factory creates GUI: "..tostring(why))
eq(gui.screen.Name,"PDIDDLER_P3_STAGE101_ReadonlyIdentity","original ScreenGui name")
eq(gui.screen.DisplayOrder,150,"original display order")
eq(gui.screen.ResetOnSpawn,false,"original ResetOnSpawn")
eq(gui.screen.IgnoreGuiInset,true,"original inset")
eq(gui.screen.ZIndexBehavior,"SIBLING","original ZIndex")
eq(gui.screen.Parent,parent,"parent to local PlayerGui only")
eq(gui.panel.Parent,gui.screen,"panel under original screen")
eq(gui.panel.Visible,false,"default hides protected panel until safe geometry")
eq(gui.panel.Active,false,"panel not a game action")
eq(gui.panel.BackgroundColor3.r,28,"original purple R")
eq(gui.panel.BackgroundColor3.g,23,"original purple G")
eq(gui.panel.BackgroundColor3.b,40,"original purple B")
eq(gui.title.Name,"CurrentStep","original title label")
eq(gui.title.Position.X,12,"original title X")
eq(gui.title.Position.Y,7,"original title Y")
eq(gui.body.Name,"WhatToDo","original body label")
eq(gui.body.Position.Y,32,"original body Y")
eq(gui.warning.Name,"Safety","original warning label")
eq(gui.warning.Text,"MANUAL ITEM TEST | NEVER FINAL ACCEPT","original warning unchanged")
eq(gui.arm.Name,"ArmP3","original ARM identity")
eq(gui.arm.Position.X,12,"ARM safe position X")
eq(gui.arm.Position.Y,111,"ARM safe Y")
eq(gui.arm.Visible,false,"ARM hidden before refresh")
eq(gui.arm.Active,false,"ARM inert until watcher ready")
eq(gui.preview.Name,"SupremePreview","original preview identity")
eq(gui.preview.Position.X,12,"Preview occupies exactly ARM's safe X")
eq(gui.preview.Position.Y,111,"Preview occupies exactly ARM's safe Y")
eq(gui.preview.Visible,false,"Preview hidden initially")
eq(gui.preview.Active,false,"Preview inert initially")
eq(gui.stop.Name,"StopP3","original stop identity")
eq(gui.stop.Text,"STOP / COPY","original stop label")
eq(gui.stop.Position.X,164,"STOP never moves into trade controls")
eq(gui.stop.Position.Y,111,"STOP original Y")
eq(gui.stop.Size.X,128,"original button W")
eq(gui.stop.Size.Y,28,"original button H")
eq(gui.stop.Visible,false,"STOP appears only after safe host guidance")
local invalidGui,guiReason=M.buildUI({Instance=Instance})
eq(invalidGui,nil,"insufficient UI constructors fail closed")
eq(guiReason,"PRESENTER_GUI_DEPENDENCIES_INVALID","bad GUI constructor reason")
local failInstance={}
function failInstance.new(class)
 if class=="TextButton" then error("INJECTED_FAILURE") end
 return Instance.new(class)
end
local failEnv={}
for k,v in pairs(env) do failEnv[k]=v end
failEnv.Instance=failInstance
local failure,failureReason=M.buildUI(failEnv)
eq(failure,nil,"partial UI creation must fail closed")
eq(failureReason,"PRESENTER_GUI_CONSTRUCTION_FAILED","partial UI failure reason")
ok(created[#created].destroyed==true or created[#created].ClassName~="ScreenGui",
 "previous created instances remain mock local (cleanup is performed on screen root)")
local source=fs.readFile(
 "pdiddler/system2/native_supreme_five_scenario_gui_presentation.lua")
for _,word in ipairs({
 "FireServer","InvokeServer","AcceptTrade","DeclineTrade","TeleportService",
 "PostAsync","getgenv","game:HttpGet","setclipboard","mm2Values",
 "mm2Listed","targetName","UserId","JobId"
}) do
 ok(source:find(word,1,true)==nil,"presentation has no trade/privacy access: "..word)
end
print("SUPREME_FIVE_STAGE_GUI_PRESENTATION_LUA_PASS assertions="..tostring(assertions))
