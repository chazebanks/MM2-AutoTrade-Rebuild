-- Stage 9: READ-ONLY MM2 trade-window capture adapter.
-- No trade remotes, simulated input, mutable Roblox state, or polling loops.
-- Pass dependencies explicitly; capture() makes no inventory RemoteFunction calls.
local M = {}
-- Inject the pure contract explicitly when loaded by the remote Luau module
-- loader. Do not depend on filesystem package.path/require in Delta.

local function find(node,name,recursive)
    if not node or type(name)~="string" then return nil end
    return node:FindFirstChild(name,recursive)
end
local function is(node,kind)
    return node and node:IsA(kind) or false
end
local function text(node)
    if is(node,"TextLabel") or is(node,"TextButton") then
        return tostring(node.Text or "")
    end
    return nil
end
local function visible(node,ancestor)
    if not node then return false end
    local curr=node
    while curr do
        if is(curr,"GuiObject") and curr.Visible~=true then return false end
        if is(curr,"ScreenGui") and curr.Enabled~=true then return false end
        if ancestor and curr==ancestor then return true end
        curr=curr.Parent
    end
    return ancestor==nil
end

local function currentTrade(pg)
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local gui=find(pg,name)
        local root=find(find(gui,"Container"),"Trade")
        if root and visible(root,pg) then return root end
    end
    return nil
end

local function partnerName(root)
    local txt=text(find(find(root,"TheirOffer"),"Username"))
    if not txt then return nil end
    local s=txt:match("^%s*%((.-)%)%s*$") or txt
    s=s:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
    if s=="" then return nil end
    return s
end

local function slotId(slot)
    for _,key in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local v=slot:GetAttribute(key)
        if v~=nil and tostring(v)~="" then return tostring(v) end
    end
    for _,key in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local node=find(slot,key,true)
        if is(node,"StringValue") or is(node,"IntValue") or is(node,"NumberValue") then
            if node.Value~=nil and tostring(node.Value)~="" then return tostring(node.Value) end
        end
    end
    return nil
end

local function readSide(root,name)
    local side=find(root,name)
    local container=find(side,"Container")
    local accepted=find(side,"Accepted")
    if not side or not container then
        return {complete=false,accepted=nil,slots={}}
    end
    local rows={}
    for i=1,4 do
        local slot=find(container,"NewItem"..tostring(i))
        if slot and visible(slot,root) then
            local label=text(find(find(slot,"ItemName"),"Label"))
            local amount=text(find(find(slot,"Container"),"Amount"))
            local chroma=find(find(slot,"Tags"),"Chroma")
            rows[#rows+1]={slot=i,rawId=slotId(slot),label=label,
                amountText=amount,chroma=chroma~=nil and visible(chroma,slot) or false}
        end
    end
    local acceptedValue=nil
    if accepted then acceptedValue=visible(accepted,root) end
    return {complete=true,accepted=acceptedValue,slots=rows}
end

function M.new(config)
    assert(type(config)=="table","observer config required")
    for _,name in ipairs({"game","players","root","session","jobId","partnerUserId","localUserId"}) do
        assert(config[name]~=nil,"missing observer "..name)
    end
    assert(type(config.session)=="string" and config.session~="","nonempty session required")
    assert(type(config.contract)=="table" and type(config.contract.normalize)=="function",
        "pure observation contract required")
    return {config=config,closed=false}
end

local function closed(h,reason)
    h.closed=true -- one captured close prevents accidentally reusing this session
    local o,diag=h.config.contract.normalize({tradeOpen=false,session=h.config.session},{marketFresh=false})
    diag.errors[#diag.errors+1]=reason
    return o,diag
end

function M.capture(h)
    assert(type(h)=="table" and type(h.config)=="table","observer handle required")
    if h.closed then return closed(h,"already-closed") end
    local c=h.config
    local ok,out,diag=pcall(function()
        if c.game.PlaceId~=142823291 or tostring(c.game.JobId)~=tostring(c.jobId) then
            return closed(h,"place-or-job-changed")
        end
        local lp=c.players.LocalPlayer
        if not lp or tostring(lp.UserId)~=tostring(c.localUserId) then
            return closed(h,"local-player-changed")
        end
        local pg=lp:FindFirstChildOfClass("PlayerGui")
        if not pg then return closed(h,"player-gui-missing") end
        local root=currentTrade(pg)
        if not root then return closed(h,"trade-window-closed") end
        if root~=c.root then return closed(h,"trade-root-changed") end
        local partner=c.players:GetPlayerByUserId(tonumber(c.partnerUserId))
        local name=partnerName(root)
        local partnerOK=partner and partner.Parent==c.players
            and tostring(partner.UserId)==tostring(c.partnerUserId)
            and name and name:lower()==tostring(partner.Name):lower()
        -- A current snapshot never inherits the previous snapshot's acceptance
        -- or price proof, even if the GUI root is reused.
        local capture={session=c.session,tradeOpen=true,contextOK=partnerOK==true,
            our=readSide(root,"YourOffer"),their=readSide(root,"TheirOffer")}
        local fresh=false
        if type(c.marketFresh)=="function" then
            local success,result=pcall(c.marketFresh)
            fresh=success and result==true
        end
        return c.contract.normalize(capture,{ownInventory=c.ownInventory,
            opponentInventory=c.opponentInventory,marketFresh=fresh})
    end)
    if not ok then
        -- Unknown UI shape is not a valid observation. No action is taken.
        local o={tradeOpen=true,session=c.session,contextOK=false,marketFresh=false,
            ourSig="capture-error",theirSig="capture-error",ourSlots=0,theirSlots=0,
            ownItems={},theirResolved=false,quoteSafe=false,
            ourAccepted=nil,theirAccepted=nil}
        return o,{authorizesTrade=false,authorizesAccept=false,
            errors={"native-capture-error:"..tostring(out)}}
    end
    return out,diag
end

return M