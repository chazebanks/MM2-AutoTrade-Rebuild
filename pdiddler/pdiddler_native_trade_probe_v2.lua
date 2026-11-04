-- PDIDDLER native evidence probe v2: bounded, observational only.
-- No Offer/Accept/Confirm/Decline calls, teleport, webhook, or completion claim.
-- Only user-initiated inventory reads use the known native GetProfileData path.
-- Inspect sanitized observations in .events/.serverEvents/.terminalEvents.
-- Local transaction tokens identify probe observations; they are NOT native IDs.
-- Capture before the manual trade, then after twice; report() stays UNCONFIRMED.
-- .snapshots keeps private raw counts locally for exact comparison, never a dump.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_NATIVE_EVIDENCE_V2"
local READ_KEY="PDIDDLER_NATIVE_EVIDENCE_READ_V2"
if type(ENV[KEY])=="table" and ENV[KEY].active then
    warn("[PDIDDLER PROBE V2] Already active; use getgenv().PDIDDLER_NATIVE_EVIDENCE_V2.stop()")
    return ENV[KEY]
end
local P={active=true,job=game.JobId,rootGeneration=0,rootOpen=false,events={},serverEvents={},terminalEvents={},snapshots={},captureBusy=false}
ENV[KEY]=P
local root,candidate,partnerNode=nil,nil,nil
local observedPartner=nil
local lifetimeConnections,buttonConnections,globalConnections={},{},{}
local remoteBindings={}
local destroyed=setmetatable({},{__mode="k"})
local lastSignature=nil
local transactionSerial,readSerial=0,0
local syncing=false
local pending=nil
local pollOutput={at=-math.huge,count=0,last=-math.huge}
local terminalOutput={at=-math.huge,count=0}
local function live()
    return P.active and ENV[KEY]==P and P.job==game.JobId and Players.LocalPlayer==LP
end
local function short(value,limit)
    return tostring(value or ""):gsub("[%c]"," "):sub(1,limit or 160)
end
local function boundedPush(ring,value,limit)
    ring[#ring+1]=value
    if #ring>limit then table.remove(ring,1) end
end
local function publicContext()
    return {job=short(P.job,100),playerUserId=LP and LP.UserId,rootGeneration=P.rootGeneration,
        rootOpen=root~=nil,partner=observedPartner or (pending and pending.partner or nil),observationToken=pending and pending.token or nil}
end
local function emit(kind,message,terminal,payload)
    if not live() then return end
    local now=os.clock()
    local e={time=now,kind=kind,message=short(message,400),context=publicContext(),payload=payload}
    boundedPush(P.events,e,160)
    if terminal then boundedPush(P.terminalEvents,e,64) end
    if kind=="server-event" then boundedPush(P.serverEvents,e,64) end
    -- Console quotas reset. Polling never consumes the independent terminal quota.
    local output=terminal and terminalOutput or pollOutput
    local window=terminal and 1 or 10
    if now-output.at>=window then output.at=now;output.count=0 end
    if output.count>=(terminal and 12 or 20) then return end
    if not terminal and now-output.last<.3 then return end
    output.count+=1
    if not terminal then output.last=now end
    print("[PDIDDLER PROBE V2] "..e.message)
end
local function disconnectAll(connections)
    for _,conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    table.clear(connections)
end
local function connect(connections,signal,fn)
    if signal then connections[#connections+1]=signal:Connect(fn) end
end
local function visible(node,stop)
    if not node then return false end
    local current=node
    for _=1,24 do
        if not current then return stop==nil end
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if stop and current==stop then return true end
        current=current.Parent
    end
    return false
end
local function findCandidate()
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil,pg end
    local fallback=nil
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local gui=pg:FindFirstChild(name)
        local container=gui and gui:FindFirstChild("Container")
        local trade=container and container:FindFirstChild("Trade")
        if trade and not destroyed[trade] then
            if visible(trade,pg) then return trade,pg end
            fallback=fallback or trade
        end
    end
    return fallback,pg
end
local function partnerOf(trade)
    local side=trade and trade:FindFirstChild("TheirOffer")
    local label=side and side:FindFirstChild("Username")
    local name=label and type(label.Text)=="string" and label.Text or nil
    if not name or name:match("^%s*$") or #name>100 then return nil,label end
    return name,label
end
local function pathTo(node,stop)
    local parts={}
    for _=1,12 do
        if not node then break end
        table.insert(parts,1,short(node.Name,50))
        if node==stop then break end
        node=node.Parent
    end
    return table.concat(parts,"/")
end
local function buttonText(button)
    return button:IsA("TextButton") and short(button.Text,35) or ""
end
local function buttonCandidate(button,stop)
    local n=button
    for _=1,10 do
        if not n then break end
        local text=tostring(n.Name):lower()
        if n:IsA("TextButton") then text=text.." "..tostring(n.Text):lower() end
        if text:find("accept",1,true) or text:find("confirm",1,true)
            or text:find("decline",1,true) or text:find("cancel",1,true) then return true end
        if n==stop then break end
        n=n.Parent
    end
    return false
end
local function sideInfo(trade,name)
    local side=trade:FindFirstChild(name)
    local accepted=side and side:FindFirstChild("Accepted")
    local slots={}
    local container=side and side:FindFirstChild("Container")
    for i=1,4 do
        local cell=container and container:FindFirstChild("NewItem"..i)
        if cell and visible(cell,trade) then
            local itemName=cell:FindFirstChild("ItemName")
            local label=itemName and itemName:FindFirstChild("Label")
            local amount=cell:FindFirstChild("Container")
            amount=amount and amount:FindFirstChild("Amount")
            slots[#slots+1]={slot=i,name=short(label and label.Text or "?",40),amount=short(amount and amount.Text or "1",16)}
        end
    end
    return {accepted=accepted and visible(accepted,trade) or false,acceptedKnown=accepted~=nil,slots=slots}
end
local function uiInfo(trade)
    if not trade then return {open=false} end
    return {open=true,partner=short(partnerOf(trade) or "?",100),ours=sideInfo(trade,"YourOffer"),theirs=sideInfo(trade,"TheirOffer")}
end
local function signature(info)
    if not info.open then return "CLOSED" end
    local parts={info.partner}
    for _,side in ipairs({info.ours,info.theirs}) do
        parts[#parts+1]=tostring(side.acceptedKnown)..":"..tostring(side.accepted)
        for _,slot in ipairs(side.slots) do parts[#parts+1]=slot.slot..":"..slot.name.."@"..slot.amount end
    end
    return table.concat(parts,"|")
end
local function invalidate(reason)
    if pending and not pending.invalidReason then
        pending.invalidReason=reason
        emit("transaction-invalidated","PENDING OBSERVATION INVALIDATED | "..reason,true)
    end
end
local function closeRoot(reason)
    if not root then return end
    root=nil;P.rootOpen=false;lastSignature=nil;observedPartner=nil
    disconnectAll(buttonConnections)
    if pending then pending.closed=true end
    emit("root-closed","TRADE ROOT CLOSED | "..reason.." | outcome UNCONFIRMED",true)
end
local syncRoot
local function bindButtons(trade)
    local connected={}
    local count=0
    local function track(node)
        if not node:IsA("GuiButton") or connected[node] then return end
        if not buttonCandidate(node,trade) then return end
        if count>=80 then return end
        connected[node]=true;count+=1
        connect(buttonConnections,node.Activated,function()
            if live() and root==trade then
                syncRoot()
                emit("manual-button","MANUAL BUTTON ACTIVATED | "..pathTo(node,trade).." | text="..buttonText(node),true,uiInfo(root))
            end
        end)
    end
    for _,node in ipairs(trade:GetDescendants()) do track(node) end
    connect(buttonConnections,trade.DescendantAdded,track)
end
local function bindCandidate(nextCandidate)
    disconnectAll(lifetimeConnections)
    candidate=nextCandidate;partnerNode=nil
    if not candidate then return end
    local observed=candidate
    local n=candidate
    for _=1,20 do
        if not n then break end
        if n:IsA("GuiObject") then connect(lifetimeConnections,n:GetPropertyChangedSignal("Visible"),function() syncRoot() end) end
        if n:IsA("ScreenGui") then connect(lifetimeConnections,n:GetPropertyChangedSignal("Enabled"),function() syncRoot() end) end
        connect(lifetimeConnections,n.AncestryChanged,function() syncRoot() end)
        n=n.Parent
    end
    connect(lifetimeConnections,observed.Destroying,function()
        destroyed[observed]=true
        if root==observed then closeRoot("destroyed") end
        syncRoot()
    end)
    connect(lifetimeConnections,observed.DescendantAdded,function() syncRoot() end)
    connect(lifetimeConnections,observed.DescendantRemoving,function(node)
        if node==partnerNode then invalidate("partner-label-removed") end
    end)
    local _,label=partnerOf(observed);partnerNode=label
    if label then connect(lifetimeConnections,label:GetPropertyChangedSignal("Text"),function() syncRoot() end) end
end
syncRoot=function()
    if syncing or not live() then return end
    syncing=true
    local nextCandidate,pg=findCandidate()
    local _,label=partnerOf(nextCandidate)
    if nextCandidate~=candidate or label~=partnerNode then bindCandidate(nextCandidate) end
    local nextRoot=nextCandidate and visible(nextCandidate,pg) and nextCandidate or nil
    if root~=nextRoot then
        if root then closeRoot("visibility-or-ancestry") end
        if nextRoot then
            root=nextRoot;P.rootOpen=true;P.rootGeneration+=1;lastSignature=nil
            observedPartner=partnerOf(root)
            if pending and pending.rootGeneration~=P.rootGeneration then invalidate("root-lifetime-changed") end
            bindButtons(root)
            emit("root-open","TRADE ROOT OPEN | observed lifetime="..P.rootGeneration,true)
        end
    end
    observedPartner=root and partnerOf(root) or nil
    if root and pending and partnerOf(root)~=pending.partner then invalidate("partner-changed") end
    syncing=false
end

-- Preserve scalar native values. Structured tables use a small field allowlist;
-- unknown keys, inventories, Instances, functions and userdata are never dumped.
local fields={id=true,transactionid=true,nativetransactionid=true,tradeid=true,nativetradeid=true,requestid=true,
    status=true,success=true,completed=true,result=true,reason=true,code=true,message=true,
    partner=true,partneruserid=true,userid=true,senderuserid=true,recipientuserid=true,epoch=true,
    transaction=true,trade=true,data=true,payload=true,details=true}
local function sanitized(value,depth,budget)
    local kind=typeof(value)
    local out={kind=kind}
    budget.left-=1
    if budget.left<0 then out.truncated=true;return out end
    if kind=="string" then out.value=short(value,160);out.truncated=#value>160
    elseif kind=="boolean" then out.value=value
    elseif kind=="number" then
        if value==value and value~=math.huge and value~=-math.huge then out.value=value else out.invalid=true end
    elseif kind=="table" then
        out.fields={};out.omitted=0
        if depth>=3 then out.truncated=true;return out end
        local used=0
        for key,child in pairs(value) do
            local allowed=type(key)=="string" and fields[key:lower():gsub("[_%-]","")]
            if type(key)=="number" and key>=1 and key<=8 and key==math.floor(key) then allowed=true end
            if allowed and used<16 and budget.left>0 then
                out.fields[key]=sanitized(child,depth+1,budget);used+=1
            else out.omitted+=1 end
            if used+out.omitted>=64 then out.truncated=true;break end
        end
    end
    return out
end
local function remotePayload(...)
    local out={count=select("#",...),truncated=select("#",...)>8}
    local budget={left=64}
    for i=1,math.min(out.count,8) do out[i]=sanitized(select(i,...),0,budget) end
    return out
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
            syncRoot()
            emit("server-event","SERVER EVENT "..name.." | sanitized payload retained; outcome UNCONFIRMED",true,remotePayload(...))
        end)
        remoteBindings[name]={remote=remote,conn=conn}
        emit("watching","WATCHING "..name..".OnClientEvent (read-only)",false)
    end
end
function P.inspectButtons()
    if not live() then return false,"probe-stopped" end
    syncRoot()
    if not root then emit("inspection","NO VISIBLE TRADE: cannot inspect buttons",true);return false,"trade-closed" end
    local buttons,total={},0
    for _,node in ipairs(root:GetDescendants()) do
        if node:IsA("GuiButton") then
            total+=1
            if #buttons<40 then buttons[#buttons+1]={path=pathTo(node,root),text=buttonText(node),visible=visible(node,root)} end
        end
    end
    emit("inspection","BUTTON INSPECTION | total="..total.."; listing capped at 40",true,{buttons=buttons,total=total})
    return true,buttons
end
local function profileOwned(value,depth)
    if type(value)~="table" or depth>4 then return nil end
    if type(value.Weapons)=="table" and type(value.Weapons.Owned)=="table" then return value.Weapons.Owned end
    for _,key in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
        local found=profileOwned(value[key],depth+1)
        if found then return found end
    end
    return nil
end
local function parsedCounts(raw)
    if type(raw)~="table" then return nil,"Weapons.Owned unavailable" end
    local out,n={},0
    for id,quantity in pairs(raw) do
        local q=tonumber(quantity)
        if type(id)~="string" or id=="" or #id>256 or not q or q~=q or q<0
            or q~=math.floor(q) or q>9007199254740991 then return nil,"invalid raw ID or quantity" end
        n+=1
        if n>4096 then return nil,"inventory type bound exceeded" end
        out[id]=q
    end
    return out,nil,n
end
local function requestContext()
    return {job=P.job,player=LP,playerUserId=LP.UserId,rootRef=pending.rootRef,
        rootGeneration=pending.rootGeneration,partner=pending.partner,transaction=pending.token,
        requestedAt=os.clock(),rootOpen=root~=nil}
end
local function sameContext(a,b)
    for _,key in ipairs({"job","player","playerUserId","rootRef","rootGeneration","partner","transaction"}) do
        if a[key]~=b[key] then return false end
    end
    return true
end
local function contextCurrent(context,stage)
    if not live() or not pending or pending.invalidReason then return false end
    if not sameContext(context,requestContext()) then return false end
    if context.rootGeneration~=P.rootGeneration then return false end
    if root and (root~=context.rootRef or partnerOf(root)~=context.partner) then return false end
    if stage=="before" and not root then return false end
    return true
end
-- InvokeServer cannot be cancelled. The shared lease stays busy after timeout or
-- stop until its underlying call returns; late responses never become snapshots.
function P.capture(stage)
    if not live() then return false,"probe-stopped" end
    if stage~="before" and stage~="after" then return false,"stage-must-be-before-or-after" end
    if P.captureBusy or ENV[READ_KEY] then
        emit("capture-error","INVENTORY READ REJECTED | prior inventory read pending",true)
        return false,"prior-inventory-read-pending"
    end
    syncRoot()
    if stage=="before" then
        local partner=partnerOf(root)
        if not root or not partner then
            emit("capture-error","BEFORE READ REJECTED | visible root and resolved partner required",true)
            return false,"visible-root-and-partner-required"
        end
    elseif not pending or pending.invalidReason or not P.snapshots.before then
        emit("capture-error","AFTER READ REJECTED | same pending before observation required",true)
        return false,"pending-transaction-mismatch"
    end
    local remotes=RS:FindFirstChild("Remotes")
    local inventory=remotes and remotes:FindFirstChild("Inventory")
    local remote=inventory and inventory:FindFirstChild("GetProfileData")
    if not remote or not remote:IsA("RemoteFunction") then
        emit("capture-error","INVENTORY READ UNAVAILABLE | GetProfileData not a RemoteFunction",true)
        return false,"remote-unavailable"
    end
    if stage=="before" then
        transactionSerial+=1
        pending={token=transactionSerial,job=P.job,player=LP,playerUserId=LP.UserId,rootRef=root,
            rootGeneration=P.rootGeneration,partner=partnerOf(root),transaction=transactionSerial,closed=false}
        P.pending=pending;P.snapshots={}
    elseif P.snapshots.after2 then
        P.snapshots.after1=P.snapshots.after2;P.snapshots.after2=nil
    end
    local context=requestContext()
    readSerial+=1
    local lease={serial=readSerial,requestedAt=context.requestedAt,timedOut=false}
    ENV[READ_KEY]=lease;P.captureBusy=true
    emit("capture-start","INVENTORY READ START | "..stage.." | local read="..readSerial,true)
    task.delay(4,function()
        if ENV[READ_KEY]~=lease then return end
        lease.timedOut=true
        emit("capture-error","INVENTORY READ TIMEOUT | no retry until underlying call returns",true)
    end)
    task.spawn(function()
        local ok,data=pcall(function() return remote:InvokeServer() end)
        if ENV[READ_KEY]==lease then ENV[READ_KEY]=nil end
        P.captureBusy=false
        if not live() then return end
        if lease.timedOut or os.clock()-lease.requestedAt>=4 then
            emit("capture-error","INVENTORY LATE RESPONSE DISCARDED",true);return
        end
        syncRoot()
        if not contextCurrent(context,stage) then
            emit("capture-error","INVENTORY RESPONSE DISCARDED | request context changed",true);return
        end
        if not ok then emit("capture-error","INVENTORY READ FAILED | no data stored",true);return end
        local counts,reason,n=parsedCounts(profileOwned(data,0))
        if not counts then emit("capture-error","INVENTORY UNRESOLVED | "..reason,true);return end
        local snap={counts=counts,stage=stage,time=os.clock(),requestedAt=context.requestedAt,readSerial=lease.serial}
        for key,value in pairs(context) do snap[key]=value end
        if stage=="before" then P.snapshots.before=snap
        elseif not P.snapshots.after1 then P.snapshots.after1=snap else P.snapshots.after2=snap end
        emit("capture-ok","INVENTORY READ OK | "..stage.." | types="..n.."; private counts withheld from console",true)
    end)
    return true,lease.serial
end
local function equalCounts(a,b)
    for id,q in pairs(a) do if b[id]~=q then return false end end
    for id,q in pairs(b) do if a[id]~=q then return false end end
    return true
end
function P.report()
    if not live() then return false,"probe-stopped" end
    syncRoot()
    local before,a,b=P.snapshots.before,P.snapshots.after1,P.snapshots.after2
    local reason=nil
    if not before or not a or not b then reason="missing-inventory-snapshots"
    elseif P.captureBusy then reason="inventory-read-pending"
    elseif not pending or pending.invalidReason or not contextCurrent(a,"after")
        or not sameContext(before,a) or not sameContext(a,b) then reason="transaction-context-mismatch"
    elseif not equalCounts(a.counts,b.counts) then reason="inventory-not-stable" end
    if reason then
        emit("report","REPORT UNCONFIRMED | "..reason,true,{status="UNCONFIRMED",reason=reason})
        return false,reason
    end
    local ids={}
    for id,q in pairs(before.counts) do if (a.counts[id] or 0)~=q then ids[#ids+1]=id end end
    for id,q in pairs(a.counts) do if before.counts[id]==nil and q~=0 then ids[#ids+1]=id end end
    table.sort(ids)
    local delta={}
    for i=1,math.min(#ids,40) do
        local id=ids[i]
        delta[#delta+1]={id=short(id,128),before=before.counts[id] or 0,after=a.counts[id] or 0,delta=(a.counts[id] or 0)-(before.counts[id] or 0)}
    end
    local result={status="UNCONFIRMED",changedTypes=#ids,delta=delta,truncated=#ids>40,context=publicContext(),
        stableRawReads=2,provenance="observed-raw-inventory-delta",nativeTransactionId=nil}
    emit("report","REPORT UNCONFIRMED | stable observed raw delta types="..#ids.."; no completion inference",true,result)
    return true,result
end
local function cleanup()
    disconnectAll(lifetimeConnections);disconnectAll(buttonConnections);disconnectAll(globalConnections)
    for _,binding in pairs(remoteBindings) do pcall(function() binding.conn:Disconnect() end) end
    remoteBindings={}
end
function P.stop()
    if not P.active then return end
    emit("stopped","STOPPED | no trade state was modified",true)
    P.active=false
    cleanup()
end
-- Signals observe close/reopen even when the same root is reused between polls.
local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
if pg then
    connect(globalConnections,pg.DescendantAdded,function() syncRoot() end)
    connect(globalConnections,pg.DescendantRemoving,function(node)
        local n=root
        while n do
            if n==node then closeRoot("ancestry-removal");break end
            n=n.Parent
        end
    end)
end
syncRoot()
task.spawn(function()
    emit("started","READ-ONLY START | all output is UNCONFIRMED evidence",true)
    while live() do
        syncRoot()
        if root then
            local info=uiInfo(root)
            local now=signature(info)
            if now~=lastSignature then
                lastSignature=now
                emit("ui-change","UI CHANGE | observed lifetime="..P.rootGeneration,false,info)
            end
        end
        watchRemote("AcceptTrade");watchRemote("DeclineTrade")
        task.wait(.18)
    end
    cleanup()
end)
return P
