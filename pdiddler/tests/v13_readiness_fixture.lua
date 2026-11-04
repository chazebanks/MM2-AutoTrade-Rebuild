-- Add native GetChildren to the preserved integration fixture without changing it.
local Base=dofile('pdiddler/tests/integration_fixture.lua')
local M={}
function M.new(options)
 local f=Base.new(options);local node=f.node
 local function attach(n)
  function n:GetChildren()
   self.childrenReads=(self.childrenReads or 0)+1
   assert(not self.forbidChildren,'hidden subtree enumerated: '..self.Name)
   local children={};for _,c in pairs(self.children) do children[#children+1]=c end
   table.sort(children,function(a,b) return a.Name<b.Name end)
   return children
  end
  local isa=n.IsA
  function n:IsA(c)
   return isa(self,c) or c=='GuiObject' and (self.ClassName=='TextButton' or self.ClassName=='ScrollingFrame')
  end
 end
 attach(f.lp);for _,n in ipairs(f.lp:GetDescendants()) do attach(n) end
 function f:node(...) local n=node(self,...);attach(n);return n end
 return f
end
return M
