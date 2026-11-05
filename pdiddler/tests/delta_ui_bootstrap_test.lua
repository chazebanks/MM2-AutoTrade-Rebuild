-- Actual bootstrap plus the inherited queue/ownership fixture. Only Roblox,
-- executor, JSON and HTTP boundaries are simulated; no native Delta UI exists here.
local path=arg[1] or 'pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v1.lua'
local input=assert(io.open(path));local code=input:read('*a');input:close()
local pin=assert(code:match('local V15_8_SHA="([0-9a-f]+)"'))
local name=assert(path:match('([^/]+)$'))
local file=assert(io.open('pdiddler/tests/gui_bootstrap_test.lua'));local text=file:read('*a');file:close()
text=text:gsub('V15_3','V15_8'):gsub('5f95a76571795cc3c3fd551d2cfe11e8b4700694',pin)
local needle='source=source..[['
local start=assert(text:find(needle,1,true))
local setup=[=[
source=source:gsub('pdiddler_V15_8_TELEPORT_AUTOBOOT_v1.lua',BOOT_NAME)
local function patch(old,new)
 local at=assert(source:find(old,1,true),'fixture boundary missing: '..old)
 assert(not source:find(old,at+#old,true),'ambiguous fixture boundary: '..old)
 source=source:sub(1,at-1)..new..source:sub(at+#old)
end
patch('local o={env={},queue={},fetches={},warnings={},prints={},job=opts.job or "job-1"}',
 'local o={env={},queue={},fetches={},warnings={},prints={},events={},reports={},uiReads=0,job=opts.job or "job-1"}')
patch('local g={}', [[
    local function node(name,class,parent)
        local n={Name=name,ClassName=class,Parent=parent,Visible=true,Enabled=true,Text=name,children={}}
        if parent then parent.children[#parent.children+1]=n end
        function n:IsA(want)
            return want==self.ClassName or want=='Instance'
                or (want=='GuiObject' and (self.ClassName=='TextButton' or self.ClassName=='TextLabel'))
                or (want=='GuiButton' and self.ClassName=='TextButton')
                or (want=='LayerCollector' and self.ClassName=='ScreenGui')
        end
        function n:GetChildren() o.uiReads=o.uiReads+1;return self.children end
        function n:GetDescendants()
            error('unbounded descendant enumeration is not part of the read-only audit contract')
        end
        function n:FindFirstChild(name) for _,c in ipairs(self.children) do if c.Name==name then return c end end end
        function n:FindFirstChildOfClass(class) for _,c in ipairs(self.children) do if c:IsA(class) then return c end end end
        function n:GetFullName() return self.Parent and self.Parent:GetFullName()..'.'..self.Name or self.Name end
        function n:GetAttribute() return nil end
        return n
    end
    o.core=node('CoreGui','CoreGui')
    o.hui=node('ExecutorRoot','Folder')
    o.playerGui=node('PlayerGui','PlayerGui')
    o.delta=node('Delta','ScreenGui',o.hui)
    o.header=node('Delta Console','TextLabel',o.delta)
    o.exit=node('Exit','TextButton',o.delta)
    o.scanner=node('MM2LiveEligibilityScanner','ScreenGui',o.playerGui)
    o.scannerExit=node('Exit','TextButton',o.scanner)
    local g={}
    function g:GetService(service)
        if service=='CoreGui' then if opts.noUi then error('CoreGui unavailable') end;return o.core end
        if service=='Players' then
            return {LocalPlayer={FindFirstChildOfClass=function(_,class) if not opts.noUi and class=='PlayerGui' then return o.playerGui end end}}
        end
        if service=='HttpService' then return {JSONEncode=function(_,report)
            o.events[#o.events+1]='audit';o.reports[#o.reports+1]=report
            if opts.encodeFails then error('fixture JSON unavailable') end
            return '{"fixture":"read-only-audit"}'
        end} end
        error('service unavailable: '..service)
    end
]])
patch('o.fetches[#o.fetches+1]=url', "o.events[#o.events+1]='fetch';o.fetches[#o.fetches+1]=url")
patch('o.sandbox=env', [[
    env.gethui=function() if not opts.noUi then return o.hui end end
    env.typeof=function(v) return type(v)=='table' and v.ClassName and 'Instance' or type(v) end
    o.sandbox=env
]])
patch('env.queue_on_teleport=function(code) o.queue[#o.queue+1]=code end', [[
        env.queue_on_teleport=function(code)
            o.queue[#o.queue+1]=code
            if opts.lateOwner then o.env[opts.lateOwner]=1 end
        end
]])
source=source..[[
]=]
setup=setup:gsub('BOOT_NAME',string.format('%q',name))
text=text:sub(1,start-1)..setup..text:sub(start+#needle)
local extra=[=[
source=source..[[
for _,key in ipairs({'PDIDDLER_V15_3_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_3_GUI_STATUS',
 'PDIDDLER_V15_4_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_4_REACHABLE',
 'PDIDDLER_V15_5_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE',
 'PDIDDLER_V15_6_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY',
 'PDIDDLER_V15_7_TELEPORT_AUTOBOOT_v1','PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH'}) do
 test('predecessor prevents audit enumeration '..key,function()
  local m=mock({queueMode='direct'});local old={jobId='job-1',started=true,running=true};m.env[key]=old
  assert(m:run()==old and #m.queue==0 and #m.fetches==0 and m.uiReads==0)
 end)
end
test('one read-only snapshot is emitted before the original two pinned HTTP fetches',function()
 local m=mock({queueMode='direct'});local state=m:run()
 assert(#m.reports==1,'actual bootstrap did not emit exactly one audit snapshot')
 assert(m.uiReads>0,'actual audit did not inspect readable UI roots')
 assert(m.events[1]=='audit' and m.events[2]=='fetch' and m.events[3]=='fetch','audit did not precede native probe and loader')
 assert(#m.fetches==2 and state.loaderStatus=='launched','audit changed original loader transport')
 assert(m.delta.Enabled and m.exit.Visible and m.scanner.Enabled and m.scannerExit.Visible,'read-only audit modified UI visibility')
end)
test('same JobId retains one bootstrap and performs no repeated UI audit',function()
 local m=mock({queueMode='direct'});local a=m:run();local reads=m.uiReads;local b=m:run()
 assert(#m.reports==1,'same JobId repeated or omitted the audit')
 assert(a==b and m.uiReads==reads and #m.queue==1 and #m.fetches==2)
end)
test('queued entry in a new JobId gets one audit before unchanged native probe and loader',function()
 local first=mock({queueMode='direct'});first:run()
 local nextJob=mock({queueMode='direct',job='job-2'});nextJob.env.PDIDDLER_V15_8_AUTOBOOT_URL=nil
 nextJob:run(first.queue[1])
 assert(#first.reports==1 and #nextJob.reports==1,'new JobId audit was omitted or duplicated')
 assert(nextJob.uiReads>0 and #nextJob.fetches==3 and #nextJob.queue==1)
 assert(nextJob.events[1]=='fetch' and nextJob.events[2]=='audit' and nextJob.events[3]=='fetch' and nextJob.events[4]=='fetch')
 local reads=nextJob.uiReads;nextJob:run(first.queue[1])
 assert(#nextJob.reports==1 and nextJob.uiReads==reads and #nextJob.fetches==3)
end)
for _,owner in ipairs({'PDIDDLER_OUTGOING_SESSION','PDIDDLER_PART4_SESSION'}) do
 test('late active owner suppresses UI enumeration '..owner,function()
  local m=mock({queueMode='direct',lateOwner=owner});local state=m:run()
  assert(m.uiReads==0,'active transaction owner did not suppress UI inspection')
  assert(m.env[owner]==1 and #m.fetches==2 and state.loaderStatus=='launched','audit changed original transport or ownership')
 end)
end
test('unavailable UI capabilities still allow original startup without invented accessibility',function()
 local m=mock({queueMode='direct',noUi=true});local state=m:run()
 assert(#m.reports==1,'missing UI capabilities did not produce a bounded audit result')
 assert(m.uiReads==0 and #m.fetches==2 and state.loaderStatus=='launched')
end)
test('JSON encoder failure falls back without blocking original startup or mutating UI',function()
 local m=mock({queueMode='direct',encodeFails=true});local state=m:run()
 assert(#m.reports==1,'audit emitter was not called exactly once')
 assert(#m.fetches==2 and state.loaderStatus=='launched')
 local fallback=false
 for _,line in ipairs(m.warnings) do
  if line:find('control-inaccessible',1,true) and line:find('native-exit-contract-unverified',1,true) then fallback=true end
 end
 assert(fallback,'JSON failure omitted the status/reason fallback')
 assert(m.delta.Enabled and m.exit.Visible and m.scanner.Enabled and m.scannerExit.Visible)
end)
print('TOTAL '..tests..' actual Delta audit bootstrap tests')
]]
]=]
local ending="assert(load(source,'v13-bootstrap-contract','t',_G))()"
local point=assert(text:find(ending,1,true));text=text:sub(1,point-1)..extra..text:sub(point)
assert(load(text,'delta-audit-bootstrap-contract','t',_G))()
