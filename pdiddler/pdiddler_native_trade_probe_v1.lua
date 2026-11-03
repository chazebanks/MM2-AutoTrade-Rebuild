-- PDIDDLER native evidence probe v1: observational only, iPad/Delta.
-- Does NOT offer, Accept, Confirm, Decline, teleport, or send webhooks.
-- Its output is evidence, NOT a declaration that a trade completed.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_NATIVE_EVIDENCE_V1"
if type(ENV[KEY])=="table" and ENV[KEY].active then
    warn("[PDIDDLER PROBE] Already active; use getgenv().PDIDDLER_NATIVE_EVIDENCE_V1.stop()")
    return ENV[KEY]
end
local P={active=true,job=game.JobId,rootGeneration=0,events={},snapshots={},captureBusy=false}
ENV[KEY]=P
local root=nil
local rootConnections={}
local remoteBindings={}
local lastSignature=nil
local lines=0
local function live()
    return P.active and ENV[KEY]==P and P.job==game.JobId
end
local function emit(s)
    if not live() then return end
    if lines>=110 then return end
    lines+=1
    local message="[PDIDDLER PROBE] "..tostring(s)
    print(message)
    P.events[#P.events+1]={time=os.clock(),message=message}
    if #P.events>110 then table.remove(P.events,1) end
end
local function disconnectAll(conns)
    for _,conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
    table.clear(conns)
end
local function visible(node,stop)
    if not node then return false end
    local current=node
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if stop and current==stop then return true end
        current=current.Parent
    end
    return stop==nil
end
local function findTrade()
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local g=pg:FindFirstChild(name)
        local c=g and g:FindFirstChild("Container")
        local t=c and c:FindFirstChild("Trade")
        if t and visible(t,pg) then return t end
    end
    return nil
end
local function short(s,limit)
    return tostring(s or ""):gsub("[%c]"," "):sub(1,limit or 60)
end
local function pathTo(button,stop)
    local parts={}
    local n=button
    for _=1,12 do
        if not n then break end
        table.insert(parts,1,n.Name)
        if n==stop then break end
        n=n.Parent
    end
    return table.concat(parts,"/")
end
local function buttonText(button)
    if button:IsA("TextButton") then return short(button.Text,35) end
    return ""
end
local function buttonCandidate(button,stop)
    local n=button
    for _=1,10 do
        if not n then break end
        local text=n.Name:lower()
        if n:IsA("TextButton") then text=text.." "..tostring(n.Text):lower() end
        if text:find("accept",1,true) or text:find("confirm",1,true)
            or text:find("decline",1,true) or text:find("cancel",1,true) then return true end
        if n==stop then break end
        n=n.Parent
    end
    return false
end
local function sideInfo(t,name)
    local s=t:FindFirstChild(name)
    local accepted=s and s:FindFirstChild("Accepted")
    local acceptState=accepted and tostring(visible(accepted,t)) or "MISSING"
    local slots={}
    local c=s and s:FindFirstChild("Container")
    for i=1,4 do
        local cell=c and c:FindFirstChild("NewItem"..i)
        if cell and visible(cell,t) then
            local itemName=cell:FindFirstChild("ItemName")
            local label=itemName and itemName:FindFirstChild("Label")
            local amount=cell:FindFirstChild("Container")
            amount=amount and amount:FindFirstChild("Amount")
            slots[#slots+1]=tostring(i)..":"..short(label and label.Text or "?",28)
                .."@"..short(amount and amount.Text or "1",10)
        end
    end
    return "accepted="..acceptState..";slots="..table.concat(slots,",")
end
local function signature(t)
    if not t then return "CLOSED" end
    local their=t:FindFirstChild("TheirOffer")
    local partner=their and their:FindFirstChild("Username")
    return "partner="..short(partner and partner.Text or "?",48)
        .." | ours["..sideInfo(t,"YourOffer").."]"
        .." | theirs["..sideInfo(t,"TheirOffer").."]"
end
local function bindRoot(t)
    disconnectAll(rootConnections)
    root=t
    lastSignature=nil
    if not t then
        emit("TRADE ROOT CLOSED | NOT proof of completion; gen="..P.rootGeneration)
        return
    end
    P.rootGeneration+=1
    emit("TRADE ROOT OPEN | gen="..P.rootGeneration.." | "..pathTo(t,nil))
    local connected={}
    local function track(node)
        if not node:IsA("GuiButton") or connected[node] then return end
        connected[node]=true
        if not buttonCandidate(node,t) then return end
        local button=node
        rootConnections[#rootConnections+1]=button.Activated:Connect(function()
            if not live() or root~=t then return end
            emit("MANUAL BUTTON ACTIVATED | gen="..P.rootGeneration.." | "
                ..pathTo(button,t).." | text="..buttonText(button)
                .." | "..signature(t))
        end)
    end
    for _,node in ipairs(t:GetDescendants()) do track(node) end
    rootConnections[#rootConnections+1]=t.DescendantAdded:Connect(track)
end
local function remoteSummary(...)
    local n=select("#",...)
    local args={...}
    local parts={}
    for i=1,math.min(n,6) do
        local v=args[i]
        local kind=typeof(v)
        if kind=="boolean" then parts[#parts+1]=tostring(i)..":boolean="..tostring(v)
        elseif kind=="nil" then parts[#parts+1]=tostring(i)..":nil"
        else parts[#parts+1]=tostring(i)..":"..kind end
    end
    return tostring(n).." args ["..table.concat(parts,",").."]"
end
local function watchRemote(name)
    local folder=RS:FindFirstChild("Trade")
    local remote=folder and folder:FindFirstChild(name)
    local held=remoteBindings[name]
    if held and held.remote==remote then return end
    if held then pcall(function() held.conn:Disconnect() end) end
    remoteBindings[name]=nil
    if remote and remote:IsA("RemoteEvent") then
        local conn=remote.OnClientEvent:Connect(function(...)
            if not live() then return end
            emit("SERVER EVENT "..name.." | "..remoteSummary(...)
                .." | gen="..P.rootGeneration.." | "..signature(root))
        end)
        remoteBindings[name]={remote=remote,conn=conn}
        emit("WATCHING "..name..".OnClientEvent (read-only)")
    end
end
function P.inspectButtons()
    local t=findTrade()
    if not t then emit("NO VISIBLE TRADE: cannot inspect buttons"); return end
    local count=0
    for _,node in ipairs(t:GetDescendants()) do
        if node:IsA("GuiButton") then
            count+=1
            if count<=40 then
                emit("BUTTON "..tostring(count).." "..pathTo(node,t)
                    .." | text="..buttonText(node).." | visible="..tostring(visible(node,t)))
            end
        end
    end
    emit("BUTTON INSPECTION | total="..count.."; listing capped at 40")
end
local function profileOwned(value,depth)
    if type(value)~="table" or depth>4 then return nil end
    if type(value.Weapons)=="table" and type(value.Weapons.Owned)=="table" then
        return value.Weapons.Owned
    end
    for _,key in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
        local found=profileOwned(value[key],depth+1)
        if found then return found end
    end
    return nil
end
local function parsedCounts(raw)
    if type(raw)~="table" then return nil,"Weapons.Owned unavailable" end
    local out={}
    for id,quantity in pairs(raw) do
        local q=tonumber(quantity)
        if type(id)~="string" or id=="" or not q or q<0
            or q~=math.floor(q) or q==math.huge then
            return nil,"unresolved inventory raw ID or quantity"
        end
        out[id]=q
    end
    return out
end
-- Optional bounded read-only RemoteFunction request, initiated by the user.
-- A timed-out InvokeServer is not retried while outstanding.
function P.capture(stage)
    if not live() then return false,"probe-stopped" end
    if stage~="before" and stage~="after" then return false,"stage-must-be-before-or-after" end
    if P.captureBusy then return false,"prior-inventory-read-pending" end
    local remotes=RS:FindFirstChild("Remotes")
    local inventory=remotes and remotes:FindFirstChild("Inventory")
    local remote=inventory and inventory:FindFirstChild("GetProfileData")
    if not remote or not remote:IsA("RemoteFunction") then
        emit("INVENTORY READ UNAVAILABLE | GetProfileData not a RemoteFunction")
        return false,"remote-unavailable"
    end
    P.captureBusy=true
    P.readSerial=(P.readSerial or 0)+1
    local serial=P.readSerial
    local timedOut=false
    emit("INVENTORY READ START | stage="..stage.." | token="..serial)
    task.delay(4,function()
        if live() and P.captureBusy and P.readSerial==serial then
            timedOut=true
            emit("INVENTORY READ TIMEOUT | token="..serial
                .." | no retry until underlying call returns")
        end
    end)
    task.spawn(function()
        local ok,data=pcall(function() return remote:InvokeServer() end)
        if not live() or P.readSerial~=serial then return end
        P.captureBusy=false
        if timedOut then
            emit("INVENTORY LATE RESPONSE DISCARDED | token="..serial)
            return
        end
        if not ok then emit("INVENTORY READ FAILED | no data stored"); return end
        local counts,reason=parsedCounts(profileOwned(data,0))
        if not counts then emit("INVENTORY UNRESOLVED | "..tostring(reason)); return end
        local list={}
        for id,q in pairs(counts) do list[#list+1]=id..":"..q end
        table.sort(list)
        local key=table.concat(list,"|")
        local snap={counts=counts,key=key,time=os.clock(),rootGeneration=P.rootGeneration,job=game.JobId}
        if stage=="before" then
            P.snapshots.before=snap
            P.snapshots.after1=nil; P.snapshots.after2=nil
        elseif not P.snapshots.after1 then P.snapshots.after1=snap
        else P.snapshots.after2=snap end
        emit("INVENTORY READ OK | stage="..stage.." | token="..serial
            .." | types="..#list.."; raw data withheld from console")
    end)
    return true,serial
end
function P.report()
    if not live() then return false,"probe-stopped" end
    local before=P.snapshots.before
    local a=P.snapshots.after1
    local b=P.snapshots.after2
    emit("REPORT | root="..(root and "open" or "closed")
        .." | gen="..P.rootGeneration.." | no automatic completion inference")
    if not before or not a or not b then
        emit("REPORT UNVERIFIED | need capture('before') once and capture('after') twice")
        return false,"missing-inventory-snapshots"
    end
    if a.key~=b.key or a.job~=b.job or before.job~=a.job then
        emit("REPORT UNVERIFIED | after reads differ or JobId changed")
        return false,"inventory-not-stable"
    end
    local changed={}
    for id,q in pairs(before.counts) do
        local after=a.counts[id] or 0
        if after~=q then changed[#changed+1]=id..":"..tostring(after-q) end
    end
    for id,q in pairs(a.counts) do
        if before.counts[id]==nil and q~=0 then changed[#changed+1]=id..":+"..q end
    end
    table.sort(changed)
    if #changed==0 then
        emit("REPORT | no observed raw inventory delta; outcome UNCONFIRMED")
    else
        emit("REPORT | stable observed raw delta: "..table.concat(changed,",")
            .." | requires exact trade correlation before completion claim")
    end
    return true,changed
end
function P.stop()
    if not P.active then return end
    P.active=false
    disconnectAll(rootConnections)
    for _,binding in pairs(remoteBindings) do pcall(function() binding.conn:Disconnect() end) end
    remoteBindings={}
    print("[PDIDDLER PROBE] STOPPED; no trade state was modified")
end
task.spawn(function()
    emit("READ-ONLY START | no offers, accepts, declines, teleports or webhooks")
    while live() do
        local nextRoot=findTrade()
        if nextRoot~=root then bindRoot(nextRoot) end
        if nextRoot then
            local now=signature(nextRoot)
            if now~=lastSignature then
                lastSignature=now
                emit("UI CHANGE | gen="..P.rootGeneration.." | "..now)
            end
        end
        watchRemote("AcceptTrade")
        watchRemote("DeclineTrade")
        task.wait(0.18)
    end
    disconnectAll(rootConnections)
    for _,binding in pairs(remoteBindings) do pcall(function() binding.conn:Disconnect() end) end
end)
return P
