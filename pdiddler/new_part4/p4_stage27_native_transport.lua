-- Stage27: diagnostic-only *transport* for manually authorized MM2 ADD
-- and ONE precise offered-slot click. This is NOT a trading policy.
-- Stage22/Stage10 native adapters must check exact observer/intent first.
-- No Accept, Decline, trading request, server hopping or retry fallback.
local M={}
local function result(reason) return false,reason end
function M.new(config)
 assert(type(config)=="table" and config.game and
        type(config.confirm)== "function","manual confirmation dependency missing")
 return {game=config.game,confirm=config.confirm,addConsumed=false,
   removeConsumed=false,sendEvents=0,clickEvents=0}
end
function M.add(h,id,category)
 if h.addConsumed then return result("add-already-attempted") end
 h.addConsumed=true -- even when native request errors: no automatic retry
 if h.confirm("ADD",id,category)~=true then return result("manual-consent-unverified") end
 if type(id)~="string" or id=="" or category~="Weapons" then
  return result("invalid-item-or-category") end
 local ok,why=pcall(function()
  local rs=h.game:GetService("ReplicatedStorage")
  local trade=rs:FindFirstChild("Trade")
  local remote=trade and trade:FindFirstChild("OfferItem")
  assert(remote and remote:IsA("RemoteEvent"),"OfferItem RemoteEvent not verified")
  h.sendEvents=h.sendEvents+1
  remote:FireServer(id,"Weapons")  -- one attempt, NOT placement proof
 end)
 if not ok then return result("native-add-uncertain:"..tostring(why)) end
 return true,"native-add-sent-not-verified"
end
function M.remove(h,button,intent)
 if h.removeConsumed then return result("remove-already-attempted") end
 h.removeConsumed=true -- one screen event only, no firesignal fallback
 if h.confirm("REMOVE",intent and intent.id,intent)~=true then
  return result("manual-consent-unverified") end
 if not button or not button:IsA("GuiButton") or
    button.Visible~=true or button.AbsoluteSize.X<10 or
    button.AbsoluteSize.Y<10 then return result("button-invalid") end
 local ok,why=pcall(function()
  local gui=h.game:GetService("GuiService")
  local vim=h.game:GetService("VirtualInputManager")
  assert(vim and type(vim.SendMouseButtonEvent)=="function",
      "single physical click API unavailable")
  local pos=button.AbsolutePosition
  local size=button.AbsoluteSize
  local inset=gui:GetGuiInset()
  local x=pos.X+size.X/2+inset.X
  local y=pos.Y+size.Y/2+inset.Y
  assert(x>0 and y>0 and x<10000 and y<10000,"invalid click position")
  h.clickEvents=h.clickEvents+1
  vim:SendMouseButtonEvent(x,y,0,true,h.game,0)
  task.wait(0.055)
  vim:SendMouseButtonEvent(x,y,0,false,h.game,0)
 end)
 if not ok then return result("native-click-uncertain:"..tostring(why)) end
 return true,"physical-click-sent-not-yet-removed"
end
return M
