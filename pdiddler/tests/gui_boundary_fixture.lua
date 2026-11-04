-- Roblox Instance/value boundaries only; the real loader owns UI lifecycle.
local M={}
function M.attach(f)
 f.guiCreated={}
 local function instance(class)
  local props={ClassName=class,Name=class,Visible=true,Enabled=true,Active=false}
  local children={};local methods={}
  local n
  function methods:IsA(c) return c==class or c=='GuiObject' and (class=='TextLabel' or class=='Frame') end
  function methods:GetChildren() local out={};for _,v in pairs(children) do out[#out+1]=v end;return out end
  function methods:FindFirstChild(name) return children[name] end
  function methods:Destroy()
   props.destroyed=true
   self.Parent=nil
   for _,child in ipairs(self:GetChildren()) do child:Destroy() end
  end
  n=setmetatable({}, {__index=function(_,k) return methods[k] or (k=='children' and children) or props[k] end,
   __newindex=function(_,k,v)
    if k=='Parent' or k=='Name' then
     if props.Parent then props.Parent.children[props.Name]=nil end
     props[k]=v
     if props.Parent then props.Parent.children[props.Name]=n end
    else props[k]=v end
   end})
  f.guiCreated[#f.guiCreated+1]=n
  return n
 end
 f.scope.Instance={new=function(class) if f.options.guiThrows then error('UI unavailable') end;return instance(class) end}
 local function dim(...) return {...} end
 f.scope.UDim2={new=dim,fromOffset=dim};f.scope.UDim={new=dim}
 f.scope.Color3={fromRGB=dim}
 f.scope.Enum={Font={Gotham='Gotham',GothamBold='GothamBold'},TextXAlignment={Left='Left'},TextYAlignment={Top='Top'},ZIndexBehavior={Sibling='Sibling'}}
 f.statuses={};f.scanner.setStatus=function(text,owner)
  if f.env.PDIDDLER_STATUS_OWNER and f.env.PDIDDLER_STATUS_OWNER~=owner then return false end
  f.statuses[#f.statuses+1]=text;return true
 end
 function f:startupPanel()
  for _,n in ipairs(self.guiCreated) do if n:IsA('ScreenGui') and not n.destroyed then return n end end
 end
 function f:startupText()
  for _,n in ipairs(self.guiCreated) do if n:IsA('TextLabel') and not n.destroyed and n.Name=='Status' then return n.Text end end
 end
 return f
end
return M
