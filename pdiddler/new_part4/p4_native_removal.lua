-- New Part 4 / Stage 10: single-shot MM2 offered-item REMOVE actuator.
-- Not auto-executable. No global singleton or default click service.
-- A reviewed integration must supply a bound Stage-9 observer and a *single*
-- executor-specific click function. Never inserts items or accepts a trade.
local M={}
local function visible(node,root)
    if not node then return false end
    local at=node
    while at do
        if at:IsA("GuiObject") and at.Visible~=true then return false end
        if at:IsA("ScreenGui") and at.Enabled~=true then return false end
        if at==root then return true end
        at=at.Parent
    end
    return false
end
local function find(parent,name)
    return parent and parent:FindFirstChild(name) or nil
end
local function blocked(why)
    return {status="BLOCKED",attempted=false,reason=why}
end
function M.new(config)
    assert(type(config)=="table","native removal config required")
    assert(type(config.observer)=="table" and type(config.observer.capture)=="function",
        "bound Stage-9 observer required")
    assert(type(config.handle)=="table" and type(config.handle.config)=="table",
        "bound Stage-9 handle required")
    assert(type(config.session)=="string" and config.session~="","session required")
    assert(config.handle.config.session==config.session,"observer session differs")
    assert(type(config.clickOnce)=="function","injected clickOnce required")
    return {config=config,used={},closed=false}
end
function M.execute(h,intent)
    assert(type(h)=="table" and type(h.config)=="table","native removal handle required")
    if h.closed then return blocked("actuator-session-closed") end
    local c=h.config
    if type(intent)~="table" or intent.kind~="REMOVE_ONE"
        or intent.session~=c.session or type(intent.token)~="number"
        or intent.token~=math.floor(intent.token) or intent.token<1
        or type(intent.ourSig)~="string" or intent.ourSig==""
        or type(intent.id)~="string" or intent.id==""
        or type(intent.slot)~="number" or intent.slot~=math.floor(intent.slot)
        or intent.slot<1 or intent.slot>4
        or type(intent.qty)~="number" or intent.qty~=math.floor(intent.qty)
        or intent.qty<1 then return blocked("intent-invalid") end
    -- Consume the token before ANY attempt. A throwing/slow callback must not
    -- cause a repeated click when the orchestrator retries the same intent.
    if h.used[intent.token] then return blocked("token-already-consumed") end
    h.used[intent.token]=true
    local ok,observation,report=pcall(c.observer.capture,c.handle)
    if not ok or type(observation)~="table" then return blocked("observer-capture-failed") end
    if observation.tradeOpen==false then h.closed=true;return blocked("trade-closed") end
    if observation.session~=c.session or observation.contextOK~=true
        or observation.ourAccepted~=false or observation.theirAccepted~=false
        or observation.ourSig~=intent.ourSig then
        return blocked("trade-or-quote-context-changed") end
    local matched=false
    for _,r in ipairs(observation.ownItems or {}) do
        if r.slot==intent.slot and r.id==intent.id and r.qty==intent.qty then
            matched=true;break
        end
    end
    if not matched then return blocked("requested-slot-not-observed") end
    local root=c.handle.config.root
    if not root or not visible(root,root) then return blocked("trade-root-unavailable") end
    local side=find(root,"YourOffer")
    local container=find(side,"Container")
    local slot=find(container,"NewItem"..tostring(intent.slot))
    local button=find(find(slot,"Container"),"ActionButton")
    if not button or not visible(button,root) then return blocked("remove-button-not-visible") end
    -- No yield between the final root/quote proof and the caller's clickOnce.
    -- A native UI race remains possible; subsequent observations, not this
    -- return value, are authoritative for actual item removal.
    local succeeded,result=pcall(c.clickOnce,button,intent)
    if not succeeded or result~=true then
        return {status="ATTEMPT_UNCERTAIN",attempted=true,reason="click-not-confirmed"}
    end
    return {status="SENT_ONCE",attempted=true,reason="one-removal-attempt-dispatched"}
end
function M.close(h)
    if type(h)=="table" then h.closed=true end
end
return M
