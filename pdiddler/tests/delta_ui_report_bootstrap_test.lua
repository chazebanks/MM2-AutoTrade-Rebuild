-- Execute the actual bootstrap; observe real print output, never JSONEncode calls.
local path=arg[1] or 'pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v2.lua'
local file=assert(io.open(path));local script=file:read('*a');file:close()
local pin=assert(script:match('local V15_8_SHA="([0-9a-f]+)"'))
local bootName=assert(path:match('([^/]+)$'))
local V1=dofile('pdiddler/delta_ui/pdiddler_delta_ui_audit_v1.lua')
local passed,failed=0,0
local artifact='/tmp/pdiddler-delta-ui-bootstrap-v2.jsonl'
local out=assert(io.open(artifact,'w'));out:close()
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function mock(opts)
 opts=opts or {};local f={env={},queue={},fetches={},prints={},warnings={},traces={},events={},uiReads=0,jsonCalls=0,httpServiceReads=0}
 local function node(name,class,parent,text)
  local n={Name=name,ClassName=class,Parent=parent,Visible=true,Enabled=true,children={},Text=text,
   AbsolutePosition={X=900,Y=700},AbsoluteSize={X=32,Y=32}}
  if parent then parent.children[#parent.children+1]=n end
  function n:IsA(c) return c==self.ClassName or c=='Instance' or c=='GuiObject' and (self.ClassName=='TextLabel' or self.ClassName=='TextButton' or self.ClassName=='ImageButton') or c=='GuiButton' and (self.ClassName=='TextButton' or self.ClassName=='ImageButton') or c=='LayerCollector' and self.ClassName=='ScreenGui' end
  function n:GetChildren() f.uiReads=f.uiReads+1;return self.children end
  function n:FindFirstChildOfClass(c) for _,v in ipairs(self.children) do if v:IsA(c) then return v end end end
  function n:GetAttribute() return nil end
  return n
 end
 f.core=node('CoreGui','CoreGui');f.hui=node('HiddenUI','Folder');f.pg=node('PlayerGui','PlayerGui')
 f.owner=node(opts.binaryName or 'DeltaOwner','ScreenGui',f.hui)
 node('RobloxHeader','TextLabel',f.owner,'Roblox Console');node('DeltaHeader','TextLabel',f.owner,'Delta Console')
 f.exit=node('Exit','ImageButton',f.owner);f.exit.Image='rbxassetid://12345'
 node('Editor','TextBox',f.owner,'PRIVATE-EDITOR-BODY')
 f.scanner=node('MM2EligibilityScannerT41','ScreenGui',f.pg)
 local player={FindFirstChildOfClass=function(_,c) if c=='PlayerGui' then return f.pg end end}
 f.game={JobId=opts.job or 'job-1',PlaceId=opts.placeId or 142823291,IsLoaded=function() return true end}
 function f.game:GetService(service)
  if service=='CoreGui' then return f.core end
  if service=='Players' then return {LocalPlayer=player} end
  if service=='HttpService' then
   f.httpServiceReads=f.httpServiceReads+1
   if opts.httpUnavailable then error('fixture HttpService unavailable') end
   return {JSONEncode=function()
    f.jsonCalls=f.jsonCalls+1
    if opts.encodeFails then error('fixture JSONEncode failure') end
    return '{}'
   end}
  end
  error('fixture unavailable service')
 end
 local root='https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/'
 f.url=root..string.rep('a',40)..'/pdiddler/'..bootName
 f.env.PDIDDLER_V15_8_AUTOBOOT_URL=f.url
 function f.game:HttpGet(url)
  f.events[#f.events+1]='fetch';f.fetches[#f.fetches+1]=url
  if url==f.url then return script end
  assert(url:find(pin,1,true),'unpinned trader source');return 'return true'
 end
 f.scope={game=f.game,task={wait=function() end},getgenv=function() return f.env end,gethui=function() return f.hui end}
 f.scope.print=function(...)
  local pieces={};for i=1,select('#',...) do pieces[i]=tostring(select(i,...)) end
  local line=table.concat(pieces,' ')
  if line:sub(1,26)=='[PDIDDLER DELTA UI AUDIT] ' then
   if f.printFails then error('fixture trace sink failure') end
   local payload=line:sub(27)
   if payload:sub(1,1)=='{' then
    f.traces[#f.traces+1]=payload;f.events[#f.events+1]='audit'
    local output=assert(io.open(artifact,'a'));output:write(payload,'\n');output:close()
   end
  end
  f.prints[#f.prints+1]=line
 end
 f.scope.warn=function(...) local p={};for i=1,select('#',...) do p[i]=tostring(select(i,...)) end;f.warnings[#f.warnings+1]=table.concat(p,' ') end
 f.scope.queue_on_teleport=function(code) f.queue[#f.queue+1]=code end
 setmetatable(f.scope,{__index=_G})
 f.scope.loadstring=function(code) return load(code,'pinned-executor-source','t',f.scope) end
 function f:run(code) return assert(load(code or script,'actual-report-bootstrap','t',self.scope))() end
 function f:cachedV1()
  local report=V1.inspect({game=self.game,env=self.env,gethui=self.scope.gethui,now=function() return 0 end})
  self.uiReads=0
  self.oldState={jobId=self.game.JobId,started=true,loaderStatus='launched'}
  self.env.PDIDDLER_V15_8_TELEPORT_AUTOBOOT_v1=self.oldState
  self.env.PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST={jobId=self.game.JobId,running=true}
  self.env.PDIDDLER_OUTGOING_SESSION=1;self.env.PDIDDLER_PART4_SESSION=1
  return report
 end
 return f
end
local function trace(f,source)
 eq(#f.traces,1);local text=f.traces[1]
 for i=1,#text do local b=text:byte(i);assert(b>=32 and b<=126,'trace contains non-ASCII/control byte') end
 assert(text:find('"traceVersion":2',1,true),'version metadata missing')
 assert(text:find('"traceSource":"'..source..'"',1,true),'trace source missing')
 assert(text:find('"traceEncoding":"ascii-byte-escaped"',1,true),'encoding metadata missing')
 for _,field in ipairs({'"owners":','"controls":','DeltaOwner','Exit','Delta Console','Roblox Console'}) do assert(text:find(field,1,true),'structured evidence omitted '..field) end
 assert(not text:find('PRIVATE-EDITOR-BODY',1,true),'private text leaked')
 return text
end

for _,mode in ipairs({'encoder throws','HttpService unavailable'}) do
 test(mode..' still prints full fresh owner and Exit evidence before trader starts',function()
  local f=mock({encodeFails=mode=='encoder throws',httpUnavailable=mode=='HttpService unavailable'})
  local state=f:run();trace(f,'fresh-v2')
  eq(f.httpServiceReads,0);eq(f.jsonCalls,0);eq(#f.fetches,2);eq(#f.queue,1);eq(state.loaderStatus,'launched')
  eq(f.events[1],'audit');eq(f.events[2],'fetch');eq(f.events[3],'fetch')
  eq(f.owner.Enabled,true);eq(f.exit.Visible,true);eq(f.scanner.Enabled,true)
 end)
end

test('same-JobId fresh execution emits once without another scan queue or controller',function()
 local f=mock({encodeFails=true});local first=f:run();local reads=f.uiReads;local second=f:run()
 eq(first,second);trace(f,'fresh-v2');eq(f.uiReads,reads);eq(#f.queue,1);eq(#f.fetches,2)
end)

test('cached-v1 report is replayed before the existing active trader early return',function()
 local f=mock({encodeFails=true});local cached=f:cachedV1();local state=f:run()
 eq(state,f.oldState);trace(f,'cached-v1');eq(f.uiReads,0);eq(#f.fetches,0);eq(#f.queue,0)
 eq(f.env.PDIDDLER_PART4_SESSION,1);eq(f.env.PDIDDLER_OUTGOING_SESSION,1)
 eq(f.env.PDIDDLER_DELTA_UI_AUDIT_V1.report,cached)
 eq(f.env.PDIDDLER_DELTA_UI_TRACE_V2,f.game.JobId)
 f:run();eq(#f.traces,1);eq(f.uiReads,0);eq(#f.fetches,0);eq(#f.queue,0)
end)

test('cached-v1 binary owner data can be recovered without modifying the cache',function()
 local f=mock({encodeFails=true,binaryName='DeltaOwner'..string.char(255,195)})
 local cached=f:cachedV1();local before=cached.owners[1].name
 f:run();local text=trace(f,'cached-v1');eq(cached.owners[1].name,before)
 assert(text:find('\\\\xFF',1,true),'cached binary name lost ASCII evidence')
 eq(f.uiReads,0);eq(#f.fetches,0);eq(#f.queue,0)
end)

for _,mismatch in ipairs({'cache job','report job'}) do
 test(mismatch..' cannot replay stale native evidence into another JobId',function()
  local f=mock();local cached=f:cachedV1()
  if mismatch=='cache job' then f.env.PDIDDLER_DELTA_UI_AUDIT_V1.jobId='other-job' else cached.jobId='other-job' end
  eq(f:run(),f.oldState);eq(#f.traces,0);eq(f.uiReads,0);eq(#f.fetches,0);eq(#f.queue,0)
 end)
end

test('failed print leaves cached replay retryable instead of setting the once tag',function()
 local f=mock();f:cachedV1();f.printFails=true
 local ok=pcall(function() f:run() end)
 assert(ok,'report sink failure escaped startup guard')
 eq(#f.traces,0);assert(f.env.PDIDDLER_DELTA_UI_TRACE_V2~=f.game.JobId,'failed print claimed report delivery')
 f.printFails=false;eq(f:run(),f.oldState);trace(f,'cached-v1')
 eq(f.uiReads,0);eq(#f.fetches,0);eq(#f.queue,0)
end)

test('existing trader without a cached report causes no scan fetch or queued restart',function()
 local f=mock();f:cachedV1();f.env.PDIDDLER_DELTA_UI_AUDIT_V1=nil
 eq(f:run(),f.oldState);eq(#f.traces,0);eq(f.uiReads,0);eq(#f.fetches,0);eq(#f.queue,0)
end)

test('queued new JobId prints one fresh report and preserves original pinned transport',function()
 local first=mock({encodeFails=true});first:run()
 local nextJob=mock({job='job-2',httpUnavailable=true});nextJob.env.PDIDDLER_V15_8_AUTOBOOT_URL=nil
 nextJob:run(first.queue[1]);trace(nextJob,'fresh-v2')
 eq(#nextJob.fetches,3);eq(#nextJob.queue,1)
 local reads=nextJob.uiReads;nextJob:run(first.queue[1]);eq(nextJob.uiReads,reads);eq(#nextJob.traces,1)
end)

print('RESULT '..passed..' bootstrap report tests passed; '..failed..' failed')
assert(failed==0,'Delta UI structured report bootstrap tests failed')
