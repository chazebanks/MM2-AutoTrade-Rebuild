-- Execute the actual read-only audit module; Roblox and executor UI are boundaries.
local Audit=dofile(arg[1] or 'pdiddler/delta_ui/pdiddler_delta_ui_audit_v1.lua')
assert(type(Audit)=='table' and type(Audit.inspect)=='function','actual audit inspect API required')
local passed,failed=0,0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function count(list,predicate)
 local n=0;for _,v in ipairs(list or {}) do if not predicate or predicate(v) then n=n+1 end end;return n
end
local function find(list,predicate)
 for _,v in ipairs(list or {}) do if predicate(v) then return v end end
end
local function jsonSafe(value,seen)
 local kind=type(value)
 if kind=='nil' or kind=='string' or kind=='boolean' then return end
 if kind=='number' then assert(value==value and value~=math.huge and value~=-math.huge,'nonfinite report number');return end
 eq(kind,'table');assert(getmetatable(value)==nil,'report retained a live native/metatable reference')
 seen=seen or {};assert(not seen[value],'cyclic report');seen[value]=true
 for k,v in pairs(value) do
  assert(type(k)=='string' or (type(k)=='number' and k>=1 and k==math.floor(k)),'non-JSON report key')
  jsonSafe(v,seen)
 end
 seen[value]=nil
end
local function strings(value,out)
 out=out or {};if type(value)=='string' then out[#out+1]=value
 elseif type(value)=='table' then for k,v in pairs(value) do strings(k,out);strings(v,out) end end
 return table.concat(out,'\n')
end
local function fixture()
 local f={env={},time=0,emitted={},mutations=0,inputs=0,childReads={},totalReads=0,childIterations=0,textBoxReads=0,yields=0,children={},states={}}
 local classes={Frame=true,TextLabel=true,TextBox=true,TextButton=true,ImageButton=true,ImageLabel=true}
 function f:node(name,class,parent,properties)
  local state={Name=name,ClassName=class,Parent=parent,Visible=true,Enabled=true,Active=true,
   AbsolutePosition={X=20,Y=30},AbsoluteSize={X=40,Y=50},children={},properties=properties or {}}
  for k,v in pairs(properties or {}) do state[k]=v end
  local n
  local methods={}
  function methods:IsA(wanted)
   return wanted==state.ClassName or wanted=='Instance' or wanted=='GuiObject' and classes[state.ClassName]
    or wanted=='GuiButton' and (state.ClassName=='ImageButton' or state.ClassName=='TextButton')
    or wanted=='LayerCollector' and state.ClassName=='ScreenGui'
  end
  function methods:GetChildren()
   f.totalReads=f.totalReads+1;f.childReads[n]=(f.childReads[n] or 0)+1
   if state.childrenError then error('fixture-child-read-unavailable') end
   if state.countChildIterations then
    return setmetatable({}, {__index=function(_,index)
     if type(index)=='number' then
      f.childIterations=f.childIterations+1
      f.time=f.time+(state.iterationStep or 0)
      if state.onChildIteration then state.onChildIteration(f.childIterations) end
      return state.children[index]
     end
    end})
   end
   local result={};for i,v in ipairs(state.children) do result[i]=v end;return result
  end
  function methods:GetDescendants()
   error('fixture-unbounded-descendant-scan-forbidden')
  end
  function methods:FindFirstChild(name)
   for _,child in ipairs(state.children) do if child.Name==name then return child end end
  end
  function methods:FindFirstChildOfClass(class)
   for _,child in ipairs(state.children) do if child:IsA(class) then return child end end
  end
  function methods:GetFullName()
   local parts={state.Name};local p=state.Parent;local limit=0
   while p and limit<64 do table.insert(parts,1,p.Name);p=p.Parent;limit=limit+1 end
   return table.concat(parts,'.')
  end
  function methods:GetAttribute() return nil end
  for _,method in ipairs({'Destroy','Activate','SetAttribute','ClearAllChildren'}) do
   methods[method]=function() f.mutations=f.mutations+1;error('audit attempted native mutation '..method) end
  end
  state.Activated={Fire=function() f.inputs=f.inputs+1;error('audit fired Activated') end}
  state.MouseButton1Click={Fire=function() f.inputs=f.inputs+1;error('audit fired mouse click') end}
  n=setmetatable({}, {__index=function(_,k)
   if k=='Text' and state.ClassName=='TextBox' then f.textBoxReads=f.textBoxReads+1 end
   if state.unreadable and state.unreadable[k] then error('fixture-property-unavailable') end
   if methods[k] then return methods[k] end
   return state[k]
  end,__newindex=function(_,k) f.mutations=f.mutations+1;error('audit changed native property '..tostring(k)) end})
  self.states[n]=state
  if parent then table.insert(assert(self.states[parent]).children,n) end
  return n
 end
 f.core=f:node('CoreGui','CoreGui')
 f.pg=f:node('PlayerGui','PlayerGui')
 f.lp=f:node('LocalPlayer','Player');f.states[f.lp].children={f.pg};f.states[f.pg].Parent=f.lp
 f.players={LocalPlayer=f.lp}
 local vim={SendMouseButtonEvent=function() f.inputs=f.inputs+1;error('audit sent native input') end,
  SendTouchEvent=function() f.inputs=f.inputs+1;error('audit sent native touch') end}
 f.workspace={CurrentCamera={ViewportSize={X=1024,Y=768}}}
 f.game={PlaceId=142823291,JobId='audit-job-1',IsLoaded=function() return f.loaded~=false end,
  GetService=function(_,name)
   if f.serviceErrors and f.serviceErrors[name] then error('fixture-service-unavailable') end
   return ({Players=f.players,CoreGui=f.core,Workspace=f.workspace,VirtualInputManager=vim,
    GuiService={GetGuiInset=function() return {X=0,Y=0} end}})[name]
  end}
 f.game.Workspace=f.workspace
 f.options={game=f.game,env=f.env,gethui=function() return f.hui end,
  now=function() f.time=f.time+(f.clockStep or 0);return f.time end,
  emit=function(...) f.emitted[#f.emitted+1]={...} end}
 function f:inspect(overrides)
  local options={};for k,v in pairs(self.options) do options[k]=v end
  for k,v in pairs(overrides or {}) do options[k]=v end
  local previous={};local names={'firesignal','mouse1click','mouse1press','mouse1release','fireclickdetector','fireproximityprompt'}
  for _,name in ipairs(names) do
   previous[name]=rawget(_G,name)
   rawset(_G,name,function() self.inputs=self.inputs+1;error('read-only audit attempted executor input') end)
  end
  local previousTask=rawget(_G,'task')
  local function taskTrap() self.yields=self.yields+1;error('audit yielded or started a background task') end
  rawset(_G,'task',{wait=taskTrap,spawn=taskTrap,defer=taskTrap,delay=taskTrap,cancel=taskTrap})
  local ok,report=pcall(Audit.inspect,options)
  for _,name in ipairs(names) do rawset(_G,name,previous[name]) end
  rawset(_G,'task',previousTask)
  assert(ok,report);jsonSafe(report)
  eq(self.mutations,0);eq(self.inputs,0);eq(self.yields,0)
  assert(type(report.status)=='string' and type(report.reason)=='string' and report.reason~='','missing explicit audit result')
  assert(report.status~='closed' and report.status~='already-closed' and report.status~='UIKit-proven','unsupported closure/native claim')
  return report
 end
 function f:overlay(parent,name)
  local owner=self:node(name or 'CandidateExecutorGui','ScreenGui',parent or self.core)
  local body=self:node('ConsolePanels','Frame',owner)
  local roblox=self:node('RobloxHeader','TextLabel',body,{Text='Roblox Console'})
  local delta=self:node('DeltaHeader','TextLabel',body,{Text='Delta Console'})
  local exit=self:node('Exit','ImageButton',owner,{Image='rbxassetid://12345'})
  return owner,roblox,delta,exit,body
 end
 return f
end
local function label(report,text)
 return assert(find(report.labels,function(row) return row.text==text end),'missing exact header '..text)
end
local function inspected(report)
 assert(report.status=='overlay-unavailable' or report.status=='control-inaccessible','unsupported inspected status '..tostring(report.status))
 assert(type(report.roots)=='table' and type(report.labels)=='table' and type(report.owners)=='table' and type(report.controls)=='table')
end

test('dual exact headers and candidate Exit remain read-only and unverified',function()
 local f=fixture();local owner,_,_,exit=f:overlay()
 local report=f:inspect();inspected(report);eq(report.status,'control-inaccessible');eq(report.jobId,f.game.JobId)
 eq(#report.labels,2)
 local a,b=label(report,'Roblox Console'),label(report,'Delta Console')
 assert(a.ownerId and a.ownerId==b.ownerId,'same ScreenGui ownership not associated')
 eq(a.visible,true);eq(a.visibilityKnown,true);eq(b.visible,true);eq(b.visibilityKnown,true)
 local screen=assert(find(report.owners,function(row) return row.id==a.ownerId end))
 eq(screen.className,'ScreenGui');eq(screen.name,owner.Name);assert(type(screen.path)=='string')
 local control=assert(find(report.controls,function(row) return row.name==exit.Name and row.ownerId==a.ownerId end))
 eq(control.className,'ImageButton');eq(control.visible,true);eq(control.visibilityKnown,true)
 eq(control.x,20);eq(control.y,30);eq(control.width,40);eq(control.height,50)
 eq(f.mutations,0);eq(f.inputs,0)
end)

test('absent overlay reports unavailable and never already closed',function()
 local f=fixture();local r=f:inspect();inspected(r);eq(r.status,'overlay-unavailable');eq(#r.labels,0)
end)

test('hidden known headers never imply already closed or a successful hide',function()
 local f=fixture();local owner=f:overlay();f.states[owner].Enabled=false
 local r=f:inspect();inspected(r);eq(r.status,'control-inaccessible')
 eq(label(r,'Delta Console').visible,false);eq(label(r,'Delta Console').visibilityKnown,true)
 eq(f.states[owner].Enabled,false)
end)

test('one exact header remains an incomplete inaccessible overlay',function()
 local f=fixture();local owner=f:node('PartialGui','ScreenGui',f.pg)
 f:node('Header','TextLabel',owner,{Text='Delta Console'})
 local r=f:inspect();inspected(r);eq(r.status,'control-inaccessible');eq(#r.labels,1)
end)

test('headers split between different ScreenGuis cannot prove one Delta owner',function()
 local f=fixture();local a=f:node('First','ScreenGui',f.core);local b=f:node('Second','ScreenGui',f.core)
 f:node('Header','TextLabel',a,{Text='Roblox Console'});f:node('Header','TextLabel',b,{Text='Delta Console'})
 f:node('Exit','ImageButton',a)
 local r=f:inspect();inspected(r);eq(r.status,'control-inaccessible')
 assert(label(r,'Roblox Console').ownerId~=label(r,'Delta Console').ownerId)
end)

test('nonexact strings and private TextBoxes are not console headers',function()
 local f=fixture();local owner=f:node('Unrelated','ScreenGui',f.pg)
 f:node('A','TextLabel',owner,{Text='Roblox Console output'})
 f:node('B','TextLabel',owner,{Text='<b>Delta Console</b>'})
 f:node('Editor','TextBox',owner,{Text='Delta Console'})
 local r=f:inspect();eq(r.status,'overlay-unavailable');eq(#r.labels,0);eq(f.textBoxReads,0)
end)

test('partial root access preserves accessible findings without native UI claims',function()
 local f=fixture();f.serviceErrors={CoreGui=true};f.options.gethui=function() error('unavailable hidden UI') end
 f:overlay(f.pg)
 local r=f:inspect();inspected(r);eq(r.status,'control-inaccessible');eq(#r.labels,2)
end)

test('inaccessible roots produce a bounded unavailable report',function()
 local f=fixture();f.serviceErrors={CoreGui=true,Players=true};f.options.gethui=function() error('unavailable') end
 local r=f:inspect();inspected(r);eq(r.status,'overlay-unavailable');eq(#r.labels,0)
end)

test('unreadable descendant branch fails harmlessly',function()
 local f=fixture();local broken=f:node('Unreadable','ScreenGui',f.core)
 f.states[broken].childrenError=true
 local r=f:inspect();inspected(r);eq(r.status,'overlay-unavailable')
end)

test('gethui and CoreGui aliases are scanned only once',function()
 local f=fixture();f.hui=f.core;f:overlay()
 local r=f:inspect();eq(#r.labels,2)
 eq(f.childReads[f.core],1)
end)

test('gethui console Frame preserves common ScreenGui owner and Exit across overlapping roots',function()
 local f=fixture();local _,_,_,_,body=f:overlay();f.hui=body
 local r=f:inspect();eq(#r.labels,2);eq(#r.owners,1)
 local owner=r.owners[1];eq(owner.name,'CandidateExecutorGui');eq(owner.className,'ScreenGui')
 eq(label(r,'Roblox Console').ownerId,owner.id);eq(label(r,'Delta Console').ownerId,owner.id)
 local exit=assert(find(r.controls,function(row) return row.name=='Exit' end),'overlapping Frame root lost Exit descriptor')
 eq(exit.ownerId,owner.id);eq(exit.className,'ImageButton');eq(exit.image,'rbxassetid://12345')
end)

test('gethui child Folder preserves common ScreenGui owner and Exit across overlapping roots',function()
 local f=fixture();local screen=f:node('CandidateExecutorGui','ScreenGui',f.core)
 local folder=f:node('HiddenRoot','Folder',screen);f.hui=folder
 local body=f:node('ConsolePanels','Frame',folder)
 f:node('RobloxHeader','TextLabel',body,{Text='Roblox Console'})
 f:node('DeltaHeader','TextLabel',body,{Text='Delta Console'})
 f:node('Exit','ImageButton',folder,{Image='rbxassetid://12345'})
 local r=f:inspect();eq(#r.labels,2);eq(#r.owners,1)
 local owner=r.owners[1];eq(owner.name,'CandidateExecutorGui');eq(owner.className,'ScreenGui')
 eq(label(r,'Roblox Console').ownerId,owner.id);eq(label(r,'Delta Console').ownerId,owner.id)
 local exit=assert(find(r.controls,function(row) return row.name=='Exit' end),'overlapping Folder root lost Exit descriptor')
 eq(exit.ownerId,owner.id);eq(exit.className,'ImageButton');eq(exit.image,'rbxassetid://12345')
end)

test('own scanner and ordinary MM2 controls remain untouched and outside candidate owners',function()
 local f=fixture();f:overlay()
 local scanner=f:node('MM2EligibilityScannerT41','ScreenGui',f.pg)
 f:node('Title','TextLabel',scanner,{Text='MM2 T4.4 Live Eligibility Scanner'})
 local request=f:node('ReceivingRequest','Frame',f.pg)
 f:node('Decline','TextButton',request,{Text='Decline'})
 f:node('Accept','TextButton',request,{Text='Accept'})
 local r=f:inspect();eq(f.states[scanner].Enabled,true)
 assert(not find(r.controls,function(row) return row.name=='Decline' or row.name=='Accept' end),'unrelated MM2 controls became audit candidates')
 eq(f.inputs,0);eq(f.mutations,0)
end)

test('private editor and console body content never enter report or emitted trace',function()
 local f=fixture();local owner=f:overlay();local secret='https://private.invalid/token-DO-NOT-LOG'
 f:node('Editor','TextBox',owner,{Text=secret})
 f:node('ConsoleBody','TextLabel',owner,{Text=secret})
 local r=f:inspect();assert(not strings(r):find(secret,1,true),'private body leaked into report')
 assert(not strings(f.emitted):find(secret,1,true),'private body leaked into emit')
 eq(f.textBoxReads,0)
end)

test('untrusted image URLs never enter the safe button descriptor',function()
 local f=fixture();local _,_,_,button=f:overlay()
 local secret='https://private.invalid/executor-secret-image'
 f.states[button].Image=secret
 local r=f:inspect();local control=assert(find(r.controls,function(row) return row.name=='Exit' end))
 eq(control.image,nil);assert(not strings(r):find(secret,1,true));assert(not strings(f.emitted):find(secret,1,true))
end)

test('only finite geometry is exposed at different viewport sizes',function()
 for _,viewport in ipairs({{768,1024},{1366,1024}}) do
  local f=fixture();f.workspace.CurrentCamera.ViewportSize={X=viewport[1],Y=viewport[2]}
  local _,_,_,button=f:overlay();f.states[button].AbsolutePosition={X=viewport[1]-50,Y=viewport[2]-60}
  local r=f:inspect();local control=assert(find(r.controls,function(row) return row.name=='Exit' end))
  eq(control.x,viewport[1]-50);eq(control.y,viewport[2]-60);eq(control.width,40);eq(control.height,50)
  eq(f.inputs,0)
 end
end)

test('unavailable or nonfinite geometry is omitted instead of invented zeros',function()
 local f=fixture();local _,_,_,button=f:overlay()
 f.states[button].AbsolutePosition={X=0/0,Y=math.huge};f.states[button].AbsoluteSize={X=40,Y=50}
 local r=f:inspect();local c=assert(find(r.controls,function(row) return row.name=='Exit' end))
 eq(c.x,nil);eq(c.y,nil)
end)

test('unknown visibility stays explicitly unknown',function()
 local f=fixture();local _,_,_,button,body=f:overlay();f.states[body].unreadable={Visible=true}
 local r=f:inspect();eq(label(r,'Delta Console').visibilityKnown,false)
 local c=assert(find(r.controls,function(row) return row.name==button.Name end));eq(c.visibilityKnown,true)
end)

test('same JobId cache never rescans or emits twice',function()
 local f=fixture();f:overlay();local first=f:inspect();local reads,emits=f.totalReads,#f.emitted
 local second=f:inspect();eq(f.totalReads,reads);eq(#f.emitted,emits);eq(second.jobId,first.jobId)
 eq(second.status,first.status)
end)

test('new JobId receives a fresh one-shot assessment',function()
 local f=fixture();f:overlay();f:inspect();local reads=f.totalReads
 f.game.JobId='audit-job-2';local second=f:inspect()
 assert(f.totalReads>reads,'new JobId reused stale audit');eq(second.jobId,'audit-job-2')
end)

test('lower node budget truncates explicitly without guessed closure',function()
 local f=fixture();for i=1,30 do f:node('Node'..i,'Frame',f.core) end;f:overlay()
 local r=f:inspect({maxNodes=5});inspected(r);eq(r.truncated,true)
 assert(r.visited<=5,'lower node budget ignored');assert(r.reason~='','truncation reason absent')
end)

test('requested large budgets cannot raise the 2048-node hard cap',function()
 local f=fixture();for i=1,3000 do f:node('Node'..i,'Frame',f.core) end
 local r=f:inspect({maxNodes=999999,maxSeconds=999999});eq(r.truncated,true)
 assert(r.visited<=2048,'node hard cap exceeded')
end)

test('lower elapsed-time budget truncates a scan safely',function()
 local f=fixture();f.clockStep=.004;for i=1,30 do f:node('Node'..i,'Frame',f.core) end
 local r=f:inspect({maxSeconds=.01});eq(r.truncated,true);assert(r.visited<30,'elapsed-time budget ignored')
end)

test('requested long duration cannot raise the .10-second hard cap',function()
 local f=fixture();f.clockStep=.03;for i=1,30 do f:node('Node'..i,'Frame',f.core) end
 local r=f:inspect({maxSeconds=999999});eq(r.truncated,true);assert(r.visited<10,'time hard cap exceeded')
end)

test('full child arrays stop expanding as soon as the queue budget is exhausted',function()
 local f=fixture();for i=1,300 do f:node('Child'..i,'Frame',f.core) end
 f.states[f.core].countChildIterations=true;f.states[f.core].iterationStep=.001
 local r=f:inspect({maxNodes=5,maxSeconds=.10})
 eq(r.truncated,true);assert(r.visited<=5)
 assert(f.childIterations<=6,'queue cap discarded nodes but still iterated '..f.childIterations..' child entries')
end)

test('elapsed budget is checked inside wide child-array expansion',function()
 local f=fixture();for i=1,300 do f:node('Child'..i,'Frame',f.core) end
 f.states[f.core].countChildIterations=true;f.states[f.core].iterationStep=.002
 local r=f:inspect({maxNodes=2048,maxSeconds=.01})
 eq(r.truncated,true)
 assert(f.childIterations<=7,'wide child iteration ignored elapsed budget: '..f.childIterations)
 assert(f.time<=.014,'child expansion ran beyond its cooperative time budget')
end)

test('new trader ownership interrupts child-array expansion immediately',function()
 local f=fixture();for i=1,300 do f:node('Child'..i,'Frame',f.core) end
 f.states[f.core].countChildIterations=true
 f.states[f.core].onChildIteration=function(n) if n==2 then f.env.PDIDDLER_PART4_SESSION=1 end end
 local r=f:inspect();assert(r.reason~='')
 assert(f.childIterations<=3,'child expansion continued after trader ownership changed: '..f.childIterations)
 eq(f.inputs,0);eq(f.mutations,0)
end)

for _,guard in ipairs({'non-MM2','unloaded','empty JobId','outgoing session','P4 session','outgoing controller','P4 controller'}) do
 test(guard..' prevents root inspection and every UI action',function()
  local f=fixture();f:overlay()
  if guard=='non-MM2' then f.game.PlaceId=1
  elseif guard=='unloaded' then f.loaded=false
  elseif guard=='empty JobId' then f.game.JobId=''
  elseif guard=='outgoing session' then f.env.PDIDDLER_OUTGOING_SESSION=1
  elseif guard=='P4 session' then f.env.PDIDDLER_PART4_SESSION=1
  elseif guard=='outgoing controller' then f.env.PDIDDLER_OUTGOING_CONTROLLER={isAlive=function() return true end}
  else f.env.PDIDDLER_PART4_CONTROLLER={isAlive=function() return true end} end
  local r=f:inspect();eq(f.totalReads,0);eq(f.inputs,0);eq(f.mutations,0)
  assert(r.reason~='','guard reason missing')
 end)
end

print('RESULT '..passed..' passed; '..failed..' failed');assert(failed==0,'Delta UI audit tests failed')
