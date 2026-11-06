-- Stage27 native transport mocks: actual MM2 OfferItem and one input event.
local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage27_native_transport.lua"))()
local count=0
local function test(name,fn)
 local ok,e=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(e)) end
 count=count+1
end
local function fixture()
 local sent,events=0,{}
 local remote={IsA=function(_,kind)return kind=="RemoteEvent"end,
  FireServer=function(_,id,kind)
    assert(id=="TestGodly" and kind=="Weapons")
    sent=sent+1
  end}
 local trade={FindFirstChild=function(_,name)if name=="OfferItem" then return remote end end}
 local RS={FindFirstChild=function(_,name)if name=="Trade" then return trade end end}
 local GUI={GetGuiInset=function()return {X=0,Y=0}end}
 local VIM={SendMouseButtonEvent=function(_,x,y,num,down)
   assert(x==100 and y==60 and num==0)
   events[#events+1]=down
 end}
 local game={GetService=function(_,name)
   if name=="ReplicatedStorage" then return RS end
   if name=="VirtualInputManager" then return VIM end
   if name=="GuiService" then return GUI end
 end}
 task={wait=function()end}
 local permitted=true
 local h=M.new({game=game,confirm=function()return permitted end,
   targetObscured=function()return false end})
 local button={Visible=true,AbsolutePosition={X=80,Y=40},
   AbsoluteSize={X=40,Y=40},
   IsA=function(_,kind)return kind=="GuiButton" end}
 return {h=h,button=button,game=game,rs=RS,trade=trade,
  deny=function()permitted=false end,
  sender=function()return sent end,
  events=events}
end
test("exactly one native OfferItem request is emitted",function()
 local f=fixture();assert(M.add(f.h,"TestGodly","Weapons")==true)
 assert(f.sender()==1)
 assert(M.add(f.h,"TestGodly","Weapons")==false and f.sender()==1)
end)
test("missing operator approval blocks and consumes token",function()
 local f=fixture();f.deny()
 assert(M.add(f.h,"TestGodly","Weapons")==false)
 assert(f.sender()==0)
 assert(M.add(f.h,"TestGodly","Weapons")==false)
end)
test("wrong category does not send",function()
 local f=fixture()
 assert(M.add(f.h,"TestGodly","Pets")==false and f.sender()==0)
end)
test("absent remote fails closed and never retries",function()
 local f=fixture()
 f.trade.FindFirstChild=function()return nil end
 assert(M.add(f.h,"TestGodly","Weapons")==false)
 assert(f.sender()==0)
 assert(M.add(f.h,"TestGodly","Weapons")==false)
end)
test("removal uses only one down/up physical click sequence",function()
 local f=fixture()
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==true)
 assert(#f.events==2 and f.events[1]==true and f.events[2]==false)
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==false)
 assert(#f.events==2)
end)
test("missing click consent blocks and consumes token",function()
 local f=fixture();f.deny()
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==false)
 assert(#f.events==0)
end)
test("invisible or nonbutton UI blocks removal",function()
 local f=fixture();f.button.Visible=false
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==false)
 assert(#f.events==0)
 local g=fixture()
 g.button.IsA=function()return false end
 assert(M.remove(g.h,g.button,{kind="REMOVE_ONE",id="TestGodly"})==false)
 assert(#g.events==0)
end)
test("test panel obscuring offered-slot button blocks click",function()
 local f=fixture()
 f.h.targetObscured=function()return true end
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==false)
 assert(#f.events==0)
end)
test("unavailable native click API never switches to double fallback",function()
 local f=fixture()
 f.game.GetService=function(_,name)
   if name=="VirtualInputManager" then error("restricted") end
   return {}
 end
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==false)
 assert(#f.events==0)
end)
test("failed click down is not followed by a second attempt",function()
 local f=fixture()
 local hits=0
 f.game.GetService=function(_,name)
   if name=="VirtualInputManager" then
    return {SendMouseButtonEvent=function()hits=hits+1;error("blocked")end}
   elseif name=="GuiService" then return {GetGuiInset=function()return{X=0,Y=0}end} end
 end
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==false)
 assert(hits==1)
 assert(M.remove(f.h,f.button,{kind="REMOVE_ONE",id="TestGodly"})==false and hits==1)
end)
print("PASS",count,"Stage27 native OfferItem and physical single-click transport mock tests")
