local R=dofile('pdiddler/pdiddler_readiness_v1.lua')
local F=dofile('pdiddler/tests/integration_fixture.lua')
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function fixture()
 local f=F.new();f.world=f:node('Workspace','Workspace');f.services={Workspace=f.world}
 f.char=f:node('Character','Model',f.world);f.lp.Character=f.char
 f:node('Humanoid','Humanoid',f.char,{Health=100});f:node('HumanoidRootPart','BasePart',f.char)
 return f
end
test('loaded game and PlayerGui are insufficient without character',function()
 local f=fixture();f.lp.Character=nil;local s=R.read(f.game,f.lp);assert(not s.ready and s.reason=='character-missing')
end)
test('unparented or dead character is not ready',function()
 local f=fixture();f.char.Parent=nil;assert(not R.read(f.game,f.lp).ready)
 f.char.Parent=f.world;f.char.children.Humanoid.Health=0;assert(not R.read(f.game,f.lp).ready)
end)
test('native visible loading text blocks ready UI and records its exact path',function()
 local f=fixture();local label=f:node('Status','TextLabel',f.pg,{Text='Loading World...'})
 local s=R.read(f.game,f.lp);assert(not s.ready and s.reason=='loading-world' and s.loading.path:find('Status',1,true))
 label.Visible=false;assert(R.read(f.game,f.lp).ready)
end)
test('hidden ancestor loading label does not stall startup',function()
 local f=fixture();local holder=f:node('Overlay','Frame',f.pg,{Visible=false})
 f:node('Status','TextLabel',holder,{Text='Loading Character'});assert(R.read(f.game,f.lp).ready)
end)
test('missing request UI cannot be mistaken for world readiness',function()
 local f=fixture();f.nodes.TradeRequest.children.SendingRequest=nil
 assert(R.read(f.game,f.lp).reason=='trade-request-ui-missing')
end)
test('post-selector readiness may wait for real progress and returns after stable state',function()
 local f=fixture();f.lp.Character=nil;local result,last
 f.task.spawn(function() result,last=R.wait(f.game,f.lp,{now=function() return f.now end,wait=f.task.wait,live=function() return true end,timeout=5}) end)
 f:advance(1);assert(result==nil);f.lp.Character=f.char;f:advance(2)
 assert(result==true and last.ready)
end)
test('permanent loading exits its deadline without UI clicks or re-running P2',function()
 local f=fixture();f:node('Status','TextLabel',f.pg,{Text='Loading Character'})
 local result,last;f.task.spawn(function() result,last=R.wait(f.game,f.lp,{now=function() return f.now end,wait=f.task.wait,live=function() return true end,timeout=2}) end)
 f:advance(2.3);assert(result==false and last.reason=='loading-character' and last.timedOut)
 assert(#f.events==0)
end)
test('job change cancels an old readiness wait',function()
 local f=fixture();f.lp.Character=nil;local result,last
 f.task.spawn(function() result,last=R.wait(f.game,f.lp,{now=function() return f.now end,wait=f.task.wait,live=function() return true end,timeout=5}) end)
 f:advance(.3);f.game.JobId='other';f:advance(.6);assert(result==false and last.reason=='job-changed')
end)
print('TOTAL '..n..' readiness tests')
