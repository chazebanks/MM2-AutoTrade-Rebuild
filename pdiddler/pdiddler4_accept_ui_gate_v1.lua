-- V8: observe MM2's *visible* Accept cooldown/readiness without pressing it.
-- Read-only. The underlying UI was seen in the Nov 3 iPad recording:
-- "Please wait (6) before accepting." ... "Please wait (1)" then green "ACCEPT".
-- No remote calls or UI mutations occur here. Unknown state fails closed.
local G={ReadyBufferSeconds=2.5}
local function normal(s)
    return tostring(s or ""):upper():gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
end
local function textNode(node)
    return node and (node:IsA("TextLabel") or node:IsA("TextButton"))
end
local function textIs(node,wanted,shown)
    return textNode(node) and shown(node) and normal(node.Text)==wanted
end
function G.read(t,shown)
    if not t or type(shown)~="function" then return "unknown","trade-or-visibility-missing" end
    local actions=t:FindFirstChild("Actions")
    if not actions or not shown(actions) then return "unknown","actions-unavailable" end
    -- IMPORTANT: check the cooldown overlay BEFORE ever classifying green
    -- Accept as ready; the button may be visibly green under the black overlay.
    for _,node in ipairs(t:GetDescendants()) do
        if textNode(node) and shown(node) then
            local s=normal(node.Text)
            if s:find("PLEASE WAIT",1,true) and s:find("BEFORE ACCEPTING",1,true) then
                return "cooldown","visible-native-countdown"
            end
        end
    end
    -- Sister DECLINE control uses Actions.Decline.ActionButton in MM2 code.
    -- Treat Actions.Accept as a candidate, NOT proof of its live path.
    local accept=actions:FindFirstChild("Accept")
    local button=accept and accept:FindFirstChild("ActionButton")
    if button and button:IsA("GuiButton") and shown(button) then
        if textIs(button,"ACCEPT",shown) then return "ready","visible-native-accept" end
        for _,n in ipairs(accept:GetDescendants()) do
            if textIs(n,"ACCEPT",shown) then return "ready","visible-native-accept-label" end
        end
    end
    -- Layout fallback: a unique visible GuiButton *inside Actions* must itself
    -- display exactly ACCEPT. Never accept names or invisible labels as proof.
    local found=0
    for _,n in ipairs(actions:GetDescendants()) do
        if n:IsA("GuiButton") and textIs(n,"ACCEPT",shown) then found=found+1 end
    end
    if found==1 then return "ready","unique-visible-actions-accept" end
    return "unknown","accept-control-not-proven"
end
function G.step(state,signature,now,uiState,accepted)
    assert(type(state)=="table","gate state required")
    if type(now)~="number" or now~=now or not signature or signature=="" then
        state.signature=nil; state.readySince=nil
        return false,"invalid-input"
    end
    if state.signature~=signature then
        state.signature=signature; state.readySince=nil; state.lastUI="unknown"
    end
    if accepted or uiState~="ready" then
        state.readySince=nil; state.lastUI=uiState
        return false,accepted and "accepted-freeze" or (uiState=="cooldown" and "native-cooldown" or "accept-unknown")
    end
    if state.lastUI~="ready" or not state.readySince then state.readySince=now end
    state.lastUI="ready"
    if now-state.readySince<G.ReadyBufferSeconds then return false,"ready-buffer" end
    return true,"accept-ready-buffer-complete"
end
return G
