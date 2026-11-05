-- Pdiddler / Stage 12 — read-only on-device MM2 trade GUI diagnostic.
-- Intentionally no trading remotes, physical click injection, server hopping,
-- auto-accept, market prices, inventory fetch, clipboard upload, or webhooks.
-- Export as a module; the one-line Delta loader calls Probe.start().
local M = {}
M.VERSION = "stage12b-quantity-audit-1"

local function cleaned(s)
    if type(s) ~= "string" then return "?" end
    return s:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.parseQuantity(raw)
    if type(raw) ~= "string" then return nil end
    local s = raw:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("^[xX]%s*", "")
    if s:sub(1, #"×") == "×" then
        s = s:sub(#"×" + 1):gsub("^%s+", "")
    end
    if #s == 0 or #s > 7 or not s:match("^%d+$") then return nil end
    local n = tonumber(s)
    if not n or n < 1 or n > 1000000 then return nil end
    return n
end

local function addField(out, v)
    local s = tostring(v == nil and "?" or v)
    out[#out + 1] = tostring(#s)..":"..s
end

function M.sideSignature(side)
    if not side or side.present ~= true or type(side.slots) ~= "table" then
        return "side-missing"
    end
    local out = {"side"}
    for _, row in ipairs(side.slots) do
        addField(out, row.slot)
        addField(out, row.rawId)
        addField(out, row.label)
        addField(out, row.amountText)
        addField(out, row.chroma)
        addField(out, row.chromaTag)
        addField(out, row.quantityAudit)
    end
    return table.concat(out, "|")
end

function M.snapshotSignature(snap)
    if not snap or snap.tradeOpen ~= true then return "NO_TRADE" end
    return table.concat({tostring(snap.session), tostring(snap.rootVariant),
        tostring(snap.partnerMatched), M.sideSignature(snap.ours),
        M.sideSignature(snap.theirs), tostring(snap.ours and snap.ours.accepted),
        tostring(snap.theirs and snap.theirs.accepted),
        tostring(snap.actionAccept), tostring(snap.actionDecline),
        tostring(snap.activeRoots)}, "/")
end

function M.lineForSide(tag, side)
    if not side or not side.present then return tag.."=SIDE_MISSING" end
    local bits={}
    for _, row in ipairs(side.slots) do
        bits[#bits+1] = tostring(row.slot)..":"..cleaned(row.label)..
            "#"..cleaned(row.rawId or "NO_ID").."["..cleaned(row.amountText or "NO_QTY").."]"..
            (row.chroma and " C" or "")..
            (row.quantityAudit and " {AUDIT:"..row.quantityAudit.."}" or "")
    end
    if #bits == 0 then bits[1] = "EMPTY" end
    return tag.."="..table.concat(bits, ",")
end

function M.describe(snap)
    if not snap or not snap.tradeOpen then return "NO TRADE WINDOW" end
    local theirs = snap.theirs
    local ours = snap.ours
    return table.concat({
        "session="..tostring(snap.session).." layout="..tostring(snap.rootVariant)..
            " roots="..tostring(snap.activeRoots),
        "partnerMatched="..tostring(snap.partnerMatched)..
            " accepted(ours/theirs)="..tostring(ours and ours.accepted).."/"..tostring(theirs and theirs.accepted),
        M.lineForSide("OURS", ours),
        M.lineForSide("THEIRS", theirs),
        "buttons(accept/decline)="..tostring(snap.actionAccept).."/"..tostring(snap.actionDecline),
    }, "\n")
end

local function find(parent, name, recursive)
    if not parent then return nil end
    return parent:FindFirstChild(name, recursive)
end
local function textOf(node)
    if node and (node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox")) then
        return tostring(node.Text or "")
    end
    return nil
end
local function visible(node, ancestor)
    if not node then return false end
    local n=node
    while n do
        if n:IsA("GuiObject") and not n.Visible then return false end
        if n:IsA("ScreenGui") and not n.Enabled then return false end
        if n == ancestor then return true end
        n=n.Parent
    end
    return ancestor==nil
end
local function internalId(slot)
    for _, k in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local ok, v = pcall(function() return slot:GetAttribute(k) end)
        if ok and v~=nil and tostring(v)~="" then return tostring(v) end
    end
    for _, k in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local v=find(slot,k,true)
        if v and (v:IsA("StringValue") or v:IsA("IntValue") or v:IsA("NumberValue")) then
            return tostring(v.Value)
        end
    end
    return nil
end
-- Stage 12b: bounded amount evidence from the occupied item slot ONLY.
-- Never infer quantity from an empty Amount label or report player identity.
function M.amountAudit(slot)
    if not slot then return "NO_SLOT" end
    local box=find(slot,"Container")
    local amount=find(box,"Amount")
    local textValue=textOf(amount)
    local state=not amount and "MISSING" or textValue==nil and "NON_TEXT" or
        (textValue=="" and "EMPTY" or cleaned(textValue))
    local out={"Amount="..state.."/"..(not amount and "MISSING" or visible(amount,slot) and "VISIBLE" or "HIDDEN")}
    local keys={"Quantity","Qty","Count","Amount","Stack","StackCount","ItemCount"}
    for _,pair in ipairs({{node=slot,tag="slot"},{node=box,tag="box"},{node=amount,tag="amount"}}) do
        if pair.node then
            for _,key in ipairs(keys) do
                local ok,v=pcall(function() return pair.node:GetAttribute(key) end)
                if ok and type(v)=="number" and v==v and v==math.floor(v) and v>=0 and v<=1000000 then
                    out[#out+1]=pair.tag.."."..key.."="..tostring(v)
                end
            end
        end
    end
    local ok,desc=pcall(function()return slot:GetDescendants()end)
    if ok and type(desc)=="table" then
        local n=0
        for _,node in ipairs(desc) do
            local t=textOf(node)
            if t~=nil then
                n=n+1
                if n>12 then out[#out+1]="TEXT_LIMIT";break end
                local names={};local p=node
                while p and p~=slot and #names<6 do
                    table.insert(names,1,tostring(p.Name or "?"));p=p.Parent
                end
                if p==slot then
                    local q=t=="" and "EMPTY" or cleaned(t):sub(1,32)
                    out[#out+1]=table.concat(names,"/").."="..q.."/"..(visible(node,slot) and "V" or "H")
                end
            end
        end
    end
    local result=table.concat(out,";")
    return result:sub(1,620)
end

local function nativeSide(root, name)
    local side=find(root,name)
    local container=find(side,"Container")
    if not side or not container then return {present=false,accepted=nil,slots={}} end
    local acceptedNode=find(side,"Accepted")
    local acceptedValue=nil
    if acceptedNode then acceptedValue=visible(acceptedNode,root) end
    local out={present=true,accepted=acceptedValue,slots={}}
    for i=1,4 do
        local slot=find(container,"NewItem"..i)
        if slot and visible(slot,root) then
            local label=textOf(find(find(slot,"ItemName"),"Label"))
            local amount=textOf(find(find(slot,"Container"),"Amount"))
            local chroma=find(find(slot,"Tags"),"Chroma")
            out.slots[#out.slots+1]={
                slot=i,label=label,rawId=internalId(slot),amountText=amount,
                qty=M.parseQuantity(amount),chroma=chroma~=nil and visible(chroma,slot) or false,
                chromaTag=chroma~=nil,quantityAudit=M.amountAudit(slot),
            }
        end
    end
    return out
end
local function partnerMatch(root,players,lp)
    local raw=textOf(find(find(root,"TheirOffer"),"Username"))
    if not raw or raw=="" then return "UNKNOWN" end
    local name=raw:match("^%s*%((.-)%)%s*$") or raw
    name=cleaned(name:gsub("^@", ""))
    local hits=0
    local playerList=players:GetPlayers()
    for _,player in ipairs(playerList) do
        if player~=lp and tostring(player.Name):lower()==name:lower() then hits=hits+1 end
    end
    if hits==1 then return "YES" end
    return hits==0 and "NO" or "AMBIGUOUS"
end
local function buttonState(root, name)
    local actions=find(root,"Actions")
    local parent=find(actions,name)
    local btn=find(parent,"ActionButton")
    if not btn then return "MISSING" end
    return visible(btn,root) and "VISIBLE" or "HIDDEN"
end

function M.inspect(pg,players,lp,session)
    local roots={}
    for _, variant in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local gui=find(pg,variant)
        local root=find(find(gui,"Container"),"Trade")
        if root and visible(root,pg) then
            roots[#roots+1]={root=root,variant=variant}
        end
    end
    if #roots==0 then return {tradeOpen=false,activeRoots=0} end
    if #roots~=1 then
        return {tradeOpen=false,activeRoots=#roots,ambiguous=true}
    end
    local r=roots[1]
    return {tradeOpen=true,root=r.root,rootVariant=r.variant,activeRoots=#roots,
        session=session,partnerMatched=partnerMatch(r.root,players,lp),
        ours=nativeSide(r.root,"YourOffer"),theirs=nativeSide(r.root,"TheirOffer"),
        actionAccept=buttonState(r.root,"Accept"),
        actionDecline=buttonState(r.root,"Decline")}
end

local function makeLabel(parent,name,position,size,text,sizeText)
    local l=Instance.new("TextLabel")
    l.Name=name;l.BackgroundTransparency=1;l.TextColor3=Color3.fromRGB(230,234,238)
    l.Font=Enum.Font.Code;l.TextSize=sizeText or 13
    l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Top
    l.TextWrapped=true;l.Position=position;l.Size=size;l.Text=text
    l.Parent=parent
    return l
end
local function makeButton(parent,name,position,width)
    local b=Instance.new("TextButton")
    b.Name=name;b.Size=UDim2.fromOffset(width,30);b.Position=position
    b.BackgroundColor3=Color3.fromRGB(47,56,68)
    b.TextColor3=Color3.fromRGB(245,245,245);b.Font=Enum.Font.SourceSansBold
    b.TextSize=14;b.Text=name;b.Parent=parent
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    return b
end

function M.start()
    local okServices,services=pcall(function()
        return {Players=game:GetService("Players"),UIS=game:GetService("UserInputService")}
    end)
    if not okServices or not services then return false,"services-unavailable" end
    if game.PlaceId~=142823291 then return false,"not-mm2-place" end
    local lp=services.Players.LocalPlayer
    local pg=lp and lp:FindFirstChildOfClass("PlayerGui")
    if not pg then return false,"player-gui-not-ready" end
    local env=(getgenv and getgenv()) or _G
    local prior=env.PDIDDLER_STAGE12_PROBE
    if type(prior)=="table" and type(prior.stop)=="function" then pcall(prior.stop) end
    local ui=Instance.new("ScreenGui")
    ui.Name="Pdiddler_Stage12_READ_ONLY"
    ui.ResetOnSpawn=false;ui.IgnoreGuiInset=true;ui.DisplayOrder=1250
    ui.Parent=pg
    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(385,242)
    frame.Position=UDim2.new(1,-394,0,80)
    frame.BackgroundColor3=Color3.fromRGB(26,30,38)
    frame.BackgroundTransparency=0.1
    frame.Active=true;frame.Parent=ui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local title=makeLabel(frame,"Title",UDim2.fromOffset(10,7),UDim2.fromOffset(194,30),"STAGE 12b · QTY READ ONLY",16)
    title.TextColor3=Color3.fromRGB(138,220,255)
    local copyButton=makeButton(frame,"COPY",UDim2.fromOffset(195,5),54)
    local mini=makeButton(frame,"MIN",UDim2.fromOffset(252,5),52)
    local stopButton=makeButton(frame,"STOP",UDim2.fromOffset(307,5),67)
    local separator=Instance.new("Frame")
    separator.Size=UDim2.new(1,-16,0,1);separator.Position=UDim2.fromOffset(8,39)
    separator.BorderSizePixel=0;separator.BackgroundColor3=Color3.fromRGB(75,86,99)
    separator.Parent=frame
    local body=makeLabel(frame,"Report",UDim2.fromOffset(10,47),UDim2.new(1,-20,1,-53),"Monitoring trade UI. Open a trade manually.",13)
    local drag,dragStart,frameStart
    local uis=services.UIS
    local inputBegan=frame.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true;dragStart=input.Position;frameStart=frame.Position
        end
    end)
    local inputEnded=frame.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    local inputChanged=uis.InputChanged:Connect(function(input)
        if drag and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
            local delta=input.Position-dragStart
            frame.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+delta.X,
                frameStart.Y.Scale,frameStart.Y.Offset+delta.Y)
        end
    end)
    local log,events={},0
    local session=0
    local lastRoot=nil
    local lastSig=nil
    local lastState=nil
    local isStopped=false
    local started=os.clock()
    local currentJob=tostring(game.JobId)
    local currentPlayer=tostring(lp.UserId)
    local minimized=false
    local function push(reason,snap)
        events=events+1
        local elapsed=os.clock()-started
        local info=string.format("%06.2fs | %s",elapsed,reason)
        if snap and snap.tradeOpen then info=info.."\n"..M.describe(snap) end
        log[#log+1]=info
        if #log>100 then table.remove(log,1) end
    end
    local function export()
        local head={"PDIDDLER STAGE12 "..M.VERSION,
            "READ-ONLY diagnostic; no completion or price authority",
            "sessions="..session.." events="..events,
            "accept-indicators may be UNKNOWN when missing; samples poll ~80ms",
            "no names, user IDs, job IDs, or webhook tokens in output"}
        for _,x in ipairs(log) do head[#head+1]=x end
        return table.concat(head,"\n\n")
    end
    local connections={inputBegan,inputEnded,inputChanged}
    local function stop()
        if isStopped then return end
        isStopped=true
        for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
        if ui then ui:Destroy() end
        if env.PDIDDLER_STAGE12_PROBE and env.PDIDDLER_STAGE12_PROBE.stop==stop then
            env.PDIDDLER_STAGE12_PROBE=nil
        end
    end
    env.PDIDDLER_STAGE12_PROBE={stop=stop,report=export}
    connections[#connections+1]=stopButton.MouseButton1Click:Connect(stop)
    connections[#connections+1]=mini.MouseButton1Click:Connect(function()
        minimized=not minimized
        frame.Size=UDim2.fromOffset(385,minimized and 41 or 242)
        separator.Visible=not minimized;body.Visible=not minimized
        mini.Text=minimized and "OPEN" or "MIN"
    end)
    connections[#connections+1]=copyButton.MouseButton1Click:Connect(function()
        local clipboard=setclipboard or toclipboard
        local ok=type(clipboard)=="function" and pcall(clipboard,export())
        title.Text=ok and "STAGE 12b · COPIED" or "STAGE 12b · RECORD VIDEO"
    end)
    push("PROBE_START",nil)
    task.spawn(function()
        while not isStopped do
            if tostring(game.JobId)~=currentJob or tostring(lp.UserId)~=currentPlayer then
                push("SESSION_CONTEXT_CHANGED — stopping",nil)
                stop()
                break
            end
            local success,shot=pcall(M.inspect,pg,services.Players,lp,session)
            if not success then
                if lastState~="ERROR" then push("READ_ERROR (no native action)",nil) end
                lastState="ERROR"
                if not minimized then body.Text="READ ERROR. No trade action was taken." end
            else
                local root=shot.tradeOpen and shot.root or nil
                if root and (lastRoot~=root or lastState~="OPEN") then
                    session=session+1
                    shot.session=session
                    push("TRADE_OPEN",shot)
                    lastSig=nil
                elseif not root and lastState=="OPEN" then
                    push("TRADE_CLOSED_OR_HIDDEN",nil)
                elseif shot.ambiguous and lastState~="AMBIGUOUS" then
                    push("MULTIPLE_ACTIVE_TRADE_ROOTS — cannot bind",nil)
                end
                if shot.tradeOpen then
                    local sig=M.snapshotSignature(shot)
                    if sig~=lastSig then
                        -- After open, a changed slot/acceptance/partner state is an event.
                        if lastSig~=nil then push("OFFER_OR_INDICATOR_CHANGED",shot) end
                        lastSig=sig
                    end
                    lastState="OPEN"
                    if not minimized then
                        local lines={"Read-only | trade #"..session.." | changes "..events,
                            "ROOT "..tostring(shot.rootVariant).." | partner="..tostring(shot.partnerMatched),
                            "ACCEPT (ours/theirs): "..tostring(shot.ours.accepted).." / "..tostring(shot.theirs.accepted),
                            M.lineForSide("OURS",shot.ours),
                            M.lineForSide("THEIRS",shot.theirs),
                            "Accept button: "..shot.actionAccept,
                            "Show a 1-copy item, then a known 2-copy stack."}
                        body.Text=table.concat(lines,"\n")
                    end
                else
                    lastState=shot.ambiguous and "AMBIGUOUS" or "CLOSED"
                    lastSig=nil
                    if not minimized then
                        body.Text=shot.ambiguous and "MULTIPLE TRADE ROOTS; capture blocked" or
                            "No active trade. Manually open a trade; probe will record changes.\n\nEvents: "..events
                    end
                end
                lastRoot=root
            end
            task.wait(0.08)
        end
    end)
    return true,"read-only-observer-started"
end

return M
