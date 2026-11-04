-- Boundary fixture; FULL production gate is wrapped as NEW_GATE below.
local function gateFixture(options)
 local o=options or {};local f={now=0,queue={},env={},players={},reads=0}
 f.task={}
 function f.task.spawn(fn) local c=coroutine.create(fn);f.queue[#f.queue+1]={c=c,at=f.now};return c end
 function f.task.wait(dt) return coroutine.yield(dt or .01) end
 function f:advance(untilTime)
  local cycles=0
  while true do
   local i,at=nil,math.huge;for j,q in ipairs(self.queue) do if q.at<at then i=j;at=q.at end end
   if not i or at>untilTime then break end
   local q=table.remove(self.queue,i);self.now=q.at
   local ok,dt=coroutine.resume(q.c);assert(ok,dt)
   if coroutine.status(q.c)~="dead" then self.queue[#self.queue+1]={c=q.c,at=self.now+(dt or .01)} end
   cycles=cycles+1;assert(cycles<20000,"scheduler runaway")
  end
  self.now=untilTime
 end
 local lp={UserId=1};function lp:FindFirstChildOfClass() return nil end;function lp:WaitForChild() return nil end
 local service={LocalPlayer=lp};function service:GetPlayers() local p={lp};for _,v in ipairs(f.players) do p[#p+1]=v end;return p end
 f.game={JobId="test-job",GetService=function(_,name) return name=="Players" and service or {} end}
 for i=1,(o.count or 8) do
  local index=i;local p={UserId=i+1,Name="Player"..i,AccountAge=300}
  local h={Health=100}
  function h:GetAppliedDescription()
   f.reads=f.reads+1
   if o.hung then f.task.wait(100) end
   return setmetatable({}, {__index=function(_,field)
    if o.badDescription and field=="Shirt" then error("unreadable Shirt") end
    if field:find("Accessory") then return "" end
    if field:find("Scale") then return 1 end
    if o.diverse and field=="Shirt" then return index*100 end
    return 0
   end})
  end
  function h:FindFirstChildOfClass() return nil end
  local char={};function char:FindFirstChildOfClass(name) return name=="Humanoid" and h end
  function char:FindFirstChild() return nil end
  p.Character=char;f.players[#f.players+1]=p
 end
 function f:start() self.task.spawn(function() NEW_GATE(self) end);return self end
 function f:result() return self.env.PDIDDLER_FAST_GATE_RESULT end
 return f
end
