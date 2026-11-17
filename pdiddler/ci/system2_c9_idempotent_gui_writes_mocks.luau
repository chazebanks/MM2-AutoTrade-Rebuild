-- Actual Luau test for exact production Stage119 GUI setter source.
-- Measures simulated Roblox-property ASSIGNMENTS, not FPS or device latency.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local s=fs.readFile("pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua")
local start=s:find("local function setDisplayIfChanged(",1,true)
assert(start,"missing actual GUI writer")
local finish=s:find("\nfunction guide:show(r)",start,true)
assert(finish,"GUI helper must be defined ONCE before real protected show")
local snippet=s:sub(start,finish-1)
assert(snippet:find('if node[property]~=value then',1,true))
local writer=luau.load(snippet.."\nreturn setDisplayIfChanged")()
local count=0
local function eq(a,b,tag)
 count+=1
 assert(a==b,tostring(tag)..": "..tostring(a).." != "..tostring(b))
end
local function proxy(initial)
 local st=initial or {}
 local writes=0
 local reads=0
 local obj=setmetatable({},{
  __index=function(_,k)
   reads+=1
   return st[k]
  end,
  __newindex=function(_,k,v)
   writes+=1
   st[k]=v
  end
 })
 return obj,function()return writes,reads end,st
end
local display={
 {key="title",prop="Text",value="SUPREME MULTI | 3/5"},
 {key="body",prop="Text",value="ONE-SIDED: manually offer ONE cheap weapon"},
 {key="arm",prop="Visible",value=false},
 {key="arm",prop="Active",value=false},
 {key="preview",prop="Visible",value=true},
 {key="preview",prop="Active",value=true},
 {key="preview",prop="Text",value="TEST 3/5"},
 {key="stop",prop="Visible",value=true},
 {key="stop",prop="Active",value=true},
}
local nodes,monitors={},{}
for _,v in ipairs(display) do
 if not nodes[v.key] then
  local x,y=proxy()
  nodes[v.key]=x
  monitors[v.key]=y
 end
end
local function writes()
 local total=0
 for _,get in pairs(monitors) do
  total+=select(1,get())
 end
 return total
end
local function applyRepeated()
 for _,v in ipairs(display) do
  writer(nodes[v.key],v.prop,v.value)
 end
end
for i=1,100 do applyRepeated() end
eq(writes(),9,"100 identical status renders make only nine property assignments")
eq(#display*100,900,"baseline unconditional 100 renders would make 900 assignments")
local propertyWritesSaved=900-writes()
eq(propertyWritesSaved,891,"891 redundant UI property assignments suppressed in 100 stable renders")
eq(writes()>0,true,"initial render still writes expected values")
for _,v in ipairs(display) do
 eq(nodes[v.key][v.prop],v.value,"same exact visible UI value after 100 re-renders")
end
local pre=writes()
-- A human stage transition must reassert ONLY the changed properties.
writer(nodes.preview,"Text","TEST 4/5")
writer(nodes.title,"Text","SUPREME MULTI | 4/5")
writer(nodes.body,"Text","TWO-SIDED: manually add weapon")
eq(writes(),pre+3,"all three changed stage labels write")
writer(nodes.preview,"Visible",false)
writer(nodes.preview,"Active",false)
eq(writes(),pre+5,"protected preview invisibility and input disable both write")
eq(nodes.preview.Active,false,"unsafe preview button remains disabled")
writer(nodes.preview,"Visible",true)
writer(nodes.preview,"Active",true)
eq(writes(),pre+7,"allowed reactivation writes both properties")
local failRead=setmetatable({},{
 __index=function()error("INJECTED_UI_PROPERTY_READ_FAILURE")end
})
local readable,why=pcall(writer,failRead,"Text","should fail closed")
eq(readable,false,"property read failures cannot be swallowed")
eq(tostring(why):find("INJECTED_UI_PROPERTY_READ_FAILURE",1,true)~=nil,true,"read error propagates")
local failWrite=setmetatable({},{
 __index=function()return "wrong"end,
 __newindex=function()error("INJECTED_UI_PROPERTY_WRITE_FAILURE")end
})
local writable,whyWrite=pcall(writer,failWrite,"Text","changed")
eq(writable,false,"property write failures cannot be swallowed")
eq(tostring(whyWrite):find("INJECTED_UI_PROPERTY_WRITE_FAILURE",1,true)~=nil,true,"write error propagates")
-- Critical: genuine P3/P4 session/lease/geometry refresh is never cached
-- here. Guard the actual original native source for these live functions.
for _,must in ipairs({
 "local function visibleTrade()",
 "function guide:refresh()",
 "local camera=World.CurrentCamera",
 "local trade,err=visibleTrade()",
 "local pos,why=geometry.choose(",
 "ui.panel.Position=UDim2.fromOffset(pos.x,pos.y)",
 "ui.panel.Size=UDim2.fromOffset(pos.w,pos.h)",
 "local ok,why=self:refresh()",
 "watcherReady=watcher~=nil and watcher.isReady()",
 "previewUntil=supremePreviewUntil",
 "local function c9ReadOnlyLeaseStatus()",
 "supervisor.arm({",
 "noAutomaticWeaponOffers~=true",
 "neverFinalAcceptDuringTest~=true",
}) do
 eq(s:find(must,1,true)~=nil,true,"retain live original check: "..must)
end
for _,must in ipairs({
 'setDisplayIfChanged(ui.title,"Text",content.title)',
 'setDisplayIfChanged(ui.body,"Text",content.body)',
 'setDisplayIfChanged(ui.arm,"Visible",content.armVisible)',
 'setDisplayIfChanged(ui.arm,"Active",content.armVisible)',
 'setDisplayIfChanged(ui.preview,"Visible",content.previewVisible)',
 'setDisplayIfChanged(ui.preview,"Active",content.previewVisible)',
 'setDisplayIfChanged(ui.preview,"Text",content.previewButtonText)',
 'setDisplayIfChanged(ui.stop,"Visible",true)',
 'setDisplayIfChanged(ui.stop,"Active",true)',
}) do
 eq(s:find(must,1,true)~=nil,true,"all nine exact GUI setter sites: "..must)
end
print("GINGERSCOPE_C9_UI_WRITE_GATE_NATIVE_PASS assertions="..tostring(count)..
 " baseline_property_assignments=900 optimized_property_assignments=9"..
 " saved_property_assignments=891 steady_render_count=100 NOT_DEVICE_FPS")
