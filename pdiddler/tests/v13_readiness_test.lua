local module=(arg and arg[1]) or 'pdiddler/pdiddler_readiness_v2_VISIBLE_SCAN.lua'
local R=dofile(module)
local F=dofile('pdiddler/tests/v13_readiness_fixture.lua')
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function fixture()
 local f=F.new();f.world=f:node('Workspace','Workspace');f.services={Workspace=f.world}
 f.char=f:node('Character','Model',f.world);f.lp.Character=f.char
 f:node('Humanoid','Humanoid',f.char,{Health=100});f:node('HumanoidRootPart','BasePart',f.char)
 return f
end
local function hiddenInventory(f,parent)
 local inventory=f:node('Inventory','Frame',parent or f.pg,{Visible=false})
 for i=1,10000 do f:node('Template'..i,'TextLabel',inventory,{Text='Loading World'}) end
 inventory.forbidChildren=true
 return inventory
end
test('large hidden inventory cannot block a fully ready lobby',function()
 local f=fixture();local inv=hiddenInventory(f)
 local s=R.read(f.game,f.lp)
 assert(s.ready,'ready lobby blocked: '..s.reason)
 assert(not inv.childrenReads and s.loadingInspection.visited<100 and s.loadingInspection.pruned>=1)
end)
test('visible loading survives large hidden inventory and records exact native path',function()
 for _,phase in ipairs({'Character','World'}) do
  local f=fixture();hiddenInventory(f)
  f:node('ZStatus','TextButton',f.pg,{Text='<b>Loading '..phase..'...</b>'})
  local s=R.read(f.game,f.lp)
  assert(not s.ready and s.reason=='loading-'..phase:lower() and s.loading.path:find('ZStatus',1,true))
 end
end)
test('disabled ScreenGui templates are never enumerated',function()
 local f=fixture();local gui=f:node('Templates','ScreenGui',f.pg,{Enabled=false})
 for i=1,10000 do f:node('Template'..i,'TextLabel',gui,{Text='Loading Character'}) end
 gui.forbidChildren=true
 assert(R.read(f.game,f.lp).ready and not gui.childrenReads)
end)
test('hidden branch becoming visible immediately restores loading protection',function()
 local f=fixture();local holder=f:node('Overlay','Frame',f.pg,{Visible=false})
 f:node('Status','TextLabel',holder,{Text='Loading World'})
 assert(R.read(f.game,f.lp).ready);holder.Visible=true
 assert(R.read(f.game,f.lp).reason=='loading-world')
end)
test('transparent frame backgrounds do not hide loading text or Folder descendants',function()
 local f=fixture();local frame=f:node('Overlay','Frame',f.pg,{BackgroundTransparency=1})
 local folder=f:node('Labels','Folder',frame)
 f:node('Status','TextLabel',folder,{Text='Loading Character'})
 assert(R.read(f.game,f.lp).reason=='loading-character')
end)
test('fully transparent text does not block readiness',function()
 local f=fixture();f:node('Status','TextLabel',f.pg,{Text='Loading Character',TextTransparency=1})
 assert(R.read(f.game,f.lp).ready)
end)
test('active traversal remains bounded and an incomplete scan never grants readiness',function()
 local f=fixture();for i=1,8300 do f:node('Label'..i,'TextLabel',f.pg,{Text='Inventory'}) end
 local s=R.read(f.game,f.lp)
 assert(not s.ready and s.reason=='loading-ui-inspection-limit')
 assert(s.loadingInspection.visited<=8192 and s.loadingInspection.complete==false)
end)
test('excessive active hierarchy depth remains a safe bounded hold',function()
 local f=fixture();local p=f.pg
 for i=1,140 do p=f:node('Folder'..i,'Folder',p) end
 f:node('Status','TextLabel',p,{Text='Loading World'})
 local s=R.read(f.game,f.lp)
 assert(not s.ready and s.reason=='loading-ui-inspection-depth' and not s.loadingInspection.complete)
end)
test('readiness does not materialize the entire PlayerGui descendant list',function()
 local f=fixture();hiddenInventory(f)
 function f.pg:GetDescendants() error('full descendant materialization forbidden') end
 assert(R.read(f.game,f.lp).ready)
end)
test('optional CoreGui scan uses the same hidden subtree protection',function()
 local f=fixture();local core=f:node('CoreGui','CoreGui');f.services.CoreGui=core
 hiddenInventory(f,core)
 local s=R.read(f.game,f.lp);assert(s.ready and s.coreGuiObserved)
 f:node('Status','TextLabel',core,{Text='Loading World'})
 assert(R.read(f.game,f.lp).reason=='loading-world')
end)
test('CoreGui access restrictions remain explicit without mutating UI',function()
 local f=fixture();local service=f.game.GetService
 function f.game:GetService(name) if name=='CoreGui' then error('restricted') end;return service(self,name) end
 local s=R.read(f.game,f.lp);assert(s.ready and s.coreGuiObserved==false and #f.events==0)
end)
test('structural request fallback still finds a hidden idle request widget',function()
 local f=fixture();f.pg.children.MainGUI.children.Lobby=nil
 local frame=f:node('TradeRequest','Frame',f.pg,{Visible=false})
 f:node('SendingRequest','Frame',frame,{Visible=false});f:node('ReceivingRequest','Frame',frame,{Visible=false})
 assert(R.read(f.game,f.lp).ready)
end)
print('TOTAL '..n..' visible-scan regression tests')
-- Run all ten previous readiness cases against the new implementation too.
local file=assert(io.open('pdiddler/tests/v11_readiness_test.lua'));local source=file:read('*a');file:close()
source=source:gsub('pdiddler_readiness_v1.lua',module:match('([^/]+)$'))
 :gsub('tests/integration_fixture.lua','tests/v13_readiness_fixture.lua')
assert(load(source,'preserved-readiness-contract','t',_G))()
