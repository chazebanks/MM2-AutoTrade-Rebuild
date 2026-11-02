-- MM2 DUPLICATE REMOVE LAB v3
-- Purpose: live-test OUR stacked eligible quantity x3 -> x2 -> x1.
-- Target: Iceblaster (Godly id 481, MM2 value 35).
-- Standalone diagnostic only. Do NOT run with the main trader.
-- FINAL ITEM-TRADE ACCEPT IS NOT IMPLEMENTED HERE.

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local GuiService=game:GetService("GuiService")
local VIM=game:GetService("VirtualInputManager")

local LP=Players.LocalPlayer
local PG=LP:WaitForChild("PlayerGui")

local ICEBLASTER_CHECKER_ID="481"
local ICEBLASTER_NAME="Iceblaster"

local function norm(s)
    return tostring(s or ""):lower():gsub("%s+",""):gsub("[^%w]","")
end


local function req(mod)
    if not mod then return nil end

    local ok,x=pcall(require,mod)
    if ok then return x end

    if setthreadidentity then
        local old=nil
        if getthreadidentity then
            pcall(function() old=getthreadidentity() end)
        end

        pcall(setthreadidentity,2)
        ok,x=pcall(require,mod)
        pcall(setthreadidentity,old or 8)

        if ok then return x end
    end

    return nil
end

local function unwrapProfile(x,depth)
    depth=depth or 0
    if type(x)~="table" or depth>4 then return nil end

    if type(x.Weapons)=="table"
        and type(x.Weapons.Owned)=="table"
    then
        return x
    end

    for _,name in ipairs({
        "ProfileData",
        "Profile",
        "PlayerData",
        "Data",
        "Inventory",
        "FullInventory",
    }) do
        local found=unwrapProfile(x[name],depth+1)
        if found then return found end
    end

    return nil
end

local function ownProfile(timeout)
    local remotes=RS:FindFirstChild("Remotes")
    local inv=remotes and remotes:FindFirstChild("Inventory")
    local rf=inv and inv:FindFirstChild("GetProfileData")

    if not rf or not rf:IsA("RemoteFunction") then
        return nil,"GetProfileData-missing"
    end

    local done=false
    local ok=false
    local raw=nil

    task.spawn(function()
        ok,raw=pcall(function()
            return rf:InvokeServer()
        end)
        done=true
    end)

    local deadline=os.clock()+(tonumber(timeout) or 4.0)
    while not done and os.clock()<deadline do
        task.wait(0.03)
    end

    if not done then
        return nil,"GetProfileData-timeout"
    end

    if not ok or type(raw)~="table" then
        return nil,"GetProfileData-failed"
    end

    local prof=unwrapProfile(raw)
    if not prof then
        return nil,"profile-invalid"
    end

    return prof,nil
end

local function resolveOwnedIceblasterKey()
    local prof,profileWhy=ownProfile(4.0)
    if not prof then
        return nil,0,profileWhy
    end

    local db=RS:FindFirstChild("Database")
    local sync=req(db and db:FindFirstChild("Sync"))

    if type(sync)~="table" then
        return nil,0,"Sync-unavailable"
    end

    local owned=prof.Weapons and prof.Weapons.Owned
    if type(owned)~="table" then
        return nil,0,"Weapons.Owned-missing"
    end

    local candidates={}

    for rawId,rawQty in pairs(owned) do
        local qty=tonumber(rawQty)
        if qty and qty>=1 and qty==math.floor(qty) then
            local id=tostring(rawId)
            local meta=nil

            if type(sync.Weapons)=="table" then
                meta=sync.Weapons[rawId] or sync.Weapons[id]
            end
            if not meta and type(sync.Item)=="table" then
                meta=sync.Item[rawId] or sync.Item[id]
            end

            if type(meta)=="table" then
                local name=tostring(meta.ItemName or meta.Name or id)
                local chroma=meta.Chroma==true

                if not chroma and norm(name)==norm(ICEBLASTER_NAME) then
                    candidates[#candidates+1]={
                        id=id,
                        qty=qty,
                        name=name,
                    }
                end
            elseif norm(id)==norm(ICEBLASTER_NAME) then
                candidates[#candidates+1]={
                    id=id,
                    qty=qty,
                    name=id,
                }
            end
        end
    end

    if #candidates~=1 then
        return nil,0,"Iceblaster-owned-key-candidates-"..tostring(#candidates)
    end

    local found=candidates[1]
    if found.qty<3 then
        return nil,found.qty,"need-3-Iceblasters"
    end

    return found.id,found.qty,nil
end

local function visible(o,stopAt)
    if not o then return false end
    local ok,res=pcall(function()
        local p=o
        while p do
            if p:IsA("GuiObject") and not p.Visible then
                return false
            end
            if p:IsA("ScreenGui") and not p.Enabled then
                return false
            end
            if stopAt and p==stopAt then
                return true
            end
            p=p.Parent
        end
        return stopAt==nil
    end)
    return ok and res
end

local function tradeRoot()
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local g=PG:FindFirstChild(name)
        local c=g and g:FindFirstChild("Container")
        local t=c and c:FindFirstChild("Trade")

        if t then
            local enabled=true
            if g:IsA("ScreenGui") then
                local ok,v=pcall(function() return g.Enabled end)
                if ok then enabled=v end
            end
            if enabled then return t end
        end
    end
    return nil
end

local function slotName(slot)
    if not slot or not visible(slot) then return nil end

    local itemName=slot:FindFirstChild("ItemName")
    local label=itemName and itemName:FindFirstChild("Label")

    if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
        local s=tostring(label.Text or ""):gsub("^%s+",""):gsub("%s+$","")
        if s~="" then return s end
    end

    for _,d in ipairs(slot:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and visible(d,slot) then
            local s=tostring(d.Text or ""):gsub("^%s+",""):gsub("%s+$","")
            if s~="" and not s:match("^[xX]%s*%d+$") then
                return s
            end
        end
    end

    return nil
end

local function slotInternalId(slot)
    if not slot then return nil end

    for _,attr in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local ok,v=pcall(function() return slot:GetAttribute(attr) end)
        if ok and v~=nil and tostring(v)~="" then
            return tostring(v)
        end
    end

    for _,name in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local v=slot:FindFirstChild(name,true)
        if v and (
            v:IsA("StringValue")
            or v:IsA("IntValue")
            or v:IsA("NumberValue")
        ) then
            return tostring(v.Value)
        end
    end

    return nil
end

local function slotQty(slot)
    local box=slot and slot:FindFirstChild("Container")
    local amount=box and box:FindFirstChild("Amount")

    if amount and (amount:IsA("TextLabel") or amount:IsA("TextButton")) then
        local n=tonumber(tostring(amount.Text or ""):match("^[xX]%s*(%d+)$"))
        if n and n>=1 then return math.floor(n) end
    end

    return 1
end

local function visibleOurSlots(t)
    local side=t and t:FindFirstChild("YourOffer")
    local container=side and side:FindFirstChild("Container")
    local out={}
    if not container then return out end

    for i=1,4 do
        local slot=container:FindFirstChild("NewItem"..i)
        if slot and slot.Visible then
            out[#out+1]=slot
        end
    end

    return out
end

local function soleOurSlot(t)
    local slots=visibleOurSlots(t)
    if #slots~=1 then
        return nil,"visible-slots-"..tostring(#slots)
    end
    return slots[1],nil
end

local function slotDiagnostic(slot)
    if not slot then return "slot=nil" end
    return "name="..tostring(slotName(slot))
        .." | internalId="..tostring(slotInternalId(slot))
        .." | qty="..tostring(slotQty(slot))
end

local function physicalClick(button,label)
    if not button or not visible(button) then
        return false,"button-not-visible"
    end

    local ok,err=pcall(function()
        local p=button.AbsolutePosition
        local s=button.AbsoluteSize
        local inset=GuiService:GetGuiInset()
        local x=p.X+s.X/2+inset.X
        local y=p.Y+s.Y/2+inset.Y

        VIM:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(x,y,0,false,game,0)
    end)

    if not ok then
        return false,tostring(err)
    end

    print("[DUP LAB] CLICK",tostring(label or "button"))
    return true,nil
end

local function waitForIceQty(expected,timeout)
    local deadline=os.clock()+(tonumber(timeout) or 2.5)
    local lastWhy="not-read-yet"
    local lastSlot=nil

    while os.clock()<deadline do
        local t=tradeRoot()
        if not t then
            return false,"trade-closed",nil
        end

        local slot,slotWhy=soleOurSlot(t)
        lastSlot=slot

        if slot then
            local qty=slotQty(slot)
            if qty==expected then
                print(
                    "[DUP LAB] SLOT DIAGNOSTIC | "
                    ..slotDiagnostic(slot)
                )
                return true,"verified",slot
            end
            lastWhy="saw-x"..tostring(qty).." | "..slotDiagnostic(slot)
        else
            lastWhy=tostring(slotWhy)
        end

        task.wait(0.05)
    end

    return false,lastWhy,lastSlot
end

local function declineAndClose()
    local t=tradeRoot()
    if not t then return true,"already-closed" end

    local tradeFolder=RS:FindFirstChild("Trade")
    local remote=tradeFolder and tradeFolder:FindFirstChild("DeclineTrade")
    if remote and remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer() end)
    end

    local deadline=os.clock()+1.2
    while tradeRoot() and os.clock()<deadline do
        task.wait(0.08)
    end

    if tradeRoot() then
        local now=tradeRoot()
        local actions=now and now:FindFirstChild("Actions")
        local decline=actions and actions:FindFirstChild("Decline")
        local button=decline and decline:FindFirstChild("ActionButton")
        if button then
            physicalClick(button,"Decline trade")
        end
    end

    local closeDeadline=os.clock()+2.5
    while tradeRoot() and os.clock()<closeDeadline do
        task.wait(0.08)
    end

    return tradeRoot()==nil,
        tradeRoot()==nil and "closed" or "close-timeout"
end

local function fail(reason)
    warn("[DUP LAB] FAIL | "..tostring(reason))
    local closed,why=declineAndClose()
    print("[DUP LAB] CLEANUP | closed="..tostring(closed).." | "..tostring(why))
    return false
end

print("[DUP LAB] START v3 | Iceblaster checker id 481 | resolving raw owned key | expected x3 -> x2 -> x1")
print("[DUP LAB] FINAL ACCEPT DISABLED / NOT IMPLEMENTED")

local ownedIceblasterKey,ownedIceblasterQty,resolveWhy=
    resolveOwnedIceblasterKey()

if not ownedIceblasterKey then
    return fail(
        "could not resolve owned Iceblaster key | qty="
        ..tostring(ownedIceblasterQty)
        .." | "
        ..tostring(resolveWhy)
    )
end

print(
    "[DUP LAB] OWNED KEY RESOLVED | checker=481 | raw="
    ..tostring(ownedIceblasterKey)
    .." | inventory qty="
    ..tostring(ownedIceblasterQty)
)

print("[DUP LAB] Open a normal trade manually; lab waits up to 45s.")

local tradeDeadline=os.clock()+45
while not tradeRoot() and os.clock()<tradeDeadline do
    task.wait(0.10)
end

local t=tradeRoot()
if not t then
    return fail("no active trade appeared within 45s")
end

if #visibleOurSlots(t)~=0 then
    return fail("YOUR OFFER must be empty before the test starts")
end

local tradeFolder=RS:FindFirstChild("Trade")
local offer=tradeFolder and tradeFolder:FindFirstChild("OfferItem")
if not offer or not offer:IsA("RemoteEvent") then
    return fail("OfferItem RemoteEvent missing")
end

for expected=1,3 do
    local fired=pcall(function()
        offer:FireServer(ownedIceblasterKey,"Weapons")
    end)

    if not fired then
        return fail("OfferItem FireServer failed at expected x"..expected)
    end

    local ok,why=waitForIceQty(expected,2.5)
    if not ok then
        return fail("offer verify expected x"..expected.." | "..tostring(why))
    end

    print("[DUP LAB] OFFER VERIFIED | Iceblaster x"..expected)
    task.wait(0.20)
end

local function removeAndRequire(expected)
    local now=tradeRoot()
    if not now then return false,"trade-closed-before-remove" end

    local slot,slotWhy=soleOurSlot(now)
    if not slot then
        return false,"sole-slot-missing-before-remove:"..tostring(slotWhy)
    end

    local box=slot:FindFirstChild("Container")
    local button=box and box:FindFirstChild("ActionButton")
    if not button then return false,"ActionButton-missing" end

    local before=slotQty(slot)
    local clicked,clickWhy=physicalClick(
        button,
        "Iceblaster x"..tostring(before).." -> x"..tostring(expected)
    )
    if not clicked then
        return false,"click-failed:"..tostring(clickWhy)
    end

    local ok,why=waitForIceQty(expected,2.5)
    if not ok then
        return false,
            "expected x"..tostring(expected).." after one click | "..tostring(why)
    end

    print(
        "[DUP LAB] REMOVE VERIFIED | Iceblaster x"
        ..tostring(before)
        .." -> x"
        ..tostring(expected)
        .." with one physical click"
    )
    return true,nil
end

local ok,why=removeAndRequire(2)
if not ok then
    return fail(why)
end

task.wait(0.30)

ok,why=removeAndRequire(1)
if not ok then
    return fail(why)
end

print("[DUP LAB] PASS v3 | OUR duplicate removal x3 -> x2 -> x1 verified")
print("[DUP LAB] No third removal attempted.")

local closed,closeWhy=declineAndClose()
print("[DUP LAB] END | trade cleanup closed="..tostring(closed).." | "..tostring(closeWhy))

return true
