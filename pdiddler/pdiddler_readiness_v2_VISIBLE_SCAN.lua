-- Read-only readiness for automation. No clicks, native RPCs, GUI mutation or teleports.
-- This detects unresolved prerequisites; it cannot repair MM2's native loaders.
local M={}
local function path(node)
    local parts={};local depth=0
    while node and depth<128 do table.insert(parts,1,node.Name);node=node.Parent;depth=depth+1 end
    return table.concat(parts,'.')
end
function M.requestFrames(pg)
    local frames,seen={},{}
    local function add(frame)
        if frame and frame:IsA('GuiObject') and not seen[frame] then
            seen[frame]=true;frames[#frames+1]=frame
        end
    end
    local main=pg:FindFirstChild('MainGUI')
    for _,scope in ipairs({'Lobby','Game'}) do
        local root=main and main:FindFirstChild(scope)
        local board=root and root:FindFirstChild('Leaderboard')
        local container=board and board:FindFirstChild('Container')
        local overlay=container and container:FindFirstChild('OverlayMenu')
        add(container and container:FindFirstChild('TradeRequest'))
        add(overlay and overlay:FindFirstChild('TradeRequest'))
    end
    if #frames==0 then
        local ok,nodes=pcall(function() return pg:GetDescendants() end)
        if not ok then return nil,'request-ui-inspection-failed' end
        if #nodes>8192 then return nil,'request-ui-inspection-limit' end
        for _,node in ipairs(nodes) do if node.Name=='TradeRequest' then add(node) end end
    end
    return frames
end
-- Inspect only branches whose visibility permits loading text to be displayed.
-- GetChildren avoids materializing hidden inventory/template descendants. Folder
-- and other containers are conservative: they are traversed unless visibility
-- proves the whole branch hidden. A budget/depth failure never grants readiness.
local function loading(root)
    local stats={visited=0,pruned=0,complete=false}
    local stack={{nodes={root},index=1,depth=0}}
    while #stack>0 do
        local frame=stack[#stack]
        local node=frame.nodes[frame.index]
        if not node then
            stack[#stack]=nil
        else
            if stats.visited>=8192 then
                stats.limitPath=path(node)
                return nil,'loading-ui-inspection-limit',stats
            end
            frame.index=frame.index+1;stats.visited=stats.visited+1
            if (node:IsA('GuiObject') and not node.Visible)
                or (node:IsA('ScreenGui') and not node.Enabled) then
                stats.pruned=stats.pruned+1
            else
                if (node:IsA('TextLabel') or node:IsA('TextButton'))
                    and (node.TextTransparency==nil or node.TextTransparency<1) then
                    local text=tostring(node.Text or ''):gsub('<[^>]->',''):lower():gsub('[%s%p]','')
                    if text=='loadingcharacter' or text=='loadingworld' then
                        return {phase=text=='loadingcharacter' and 'loading-character' or 'loading-world',
                            path=path(node),text=tostring(node.Text)},nil,stats
                    end
                end
                local children=node:GetChildren()
                if #children>0 then
                    if frame.depth>=128 then
                        stats.limitPath=path(node)
                        return nil,'loading-ui-inspection-depth',stats
                    end
                    stack[#stack+1]={nodes=children,index=1,depth=frame.depth+1}
                end
            end
        end
    end
    stats.complete=true
    return nil,nil,stats
end
local function inspect(game,player)
    local s={ready=false,jobId=game.JobId,player=player}
    local function no(why) s.reason=why;return s end
    if not game:IsLoaded() then return no('initial-replication') end
    if not player then return no('local-player-missing') end
    s.playerGui=player:FindFirstChildOfClass('PlayerGui')
    if not s.playerGui then return no('player-gui-missing') end
    local found,why,scan=loading(s.playerGui)
    s.loadingInspection=scan
    if why then return no(why) end
    if found then s.loading=found;return no(found.phase) end
    -- CoreGui can be restricted by the executor. Preserve that limitation in
    -- diagnostics; never alter CoreGui or substitute a guessed loading path.
    local ok,core=pcall(function() return game:GetService('CoreGui') end)
    if ok and core then
        local read,candidate,err,scan=pcall(loading,core)
        s.coreGuiInspection=scan
        s.coreGuiObserved=read and not err
        if read and candidate then s.loading=candidate;return no(candidate.phase) end
    else s.coreGuiObserved=false end
    s.character=player.Character
    if not s.character then return no('character-missing') end
    local world=game:GetService('Workspace')
    local ancestor=s.character;local depth=0
    while ancestor and ancestor~=world and depth<128 do ancestor=ancestor.Parent;depth=depth+1 end
    if ancestor~=world then return no('character-not-in-world') end
    s.humanoid=s.character:FindFirstChildOfClass('Humanoid')
    s.root=s.character:FindFirstChild('HumanoidRootPart')
    if not s.humanoid or not s.root or not s.root:IsA('BasePart') then return no('character-parts-missing') end
    if type(s.humanoid.Health)~='number' or s.humanoid.Health<=0 then return no('character-not-alive') end
    local frames,err=M.requestFrames(s.playerGui)
    if not frames then return no(err) end
    s.requestPaths={};local complete=false
    for _,frame in ipairs(frames) do
        s.requestPaths[#s.requestPaths+1]=path(frame)
        local sending=frame:FindFirstChild('SendingRequest')
        local receiving=frame:FindFirstChild('ReceivingRequest')
        if sending and receiving and sending:IsA('GuiObject') and receiving:IsA('GuiObject') then complete=true end
    end
    if not complete then return no('trade-request-ui-missing') end
    local tradeReady=false
    for _,name in ipairs({'TradeGUI_Phone','TradeGUI'}) do
        local gui=s.playerGui:FindFirstChild(name)
        local container=gui and gui:FindFirstChild('Container')
        if container and container:FindFirstChild('Trade') then tradeReady=true end
    end
    if not tradeReady then return no('trade-window-ui-missing') end
    s.ready=true;s.reason='ready';return s
end
function M.read(game,player)
    local ok,value=pcall(inspect,game,player)
    if ok then return value end
    return {ready=false,reason='readiness-read-failed',detail=tostring(value),jobId=game.JobId}
end
function M.wait(game,player,options)
    local o=options or {};local now=o.now or os.clock
    local pause=o.wait or task.wait;local live=o.live or function() return true end
    local start=now();local job=game.JobId;local last,stable,since
    local deadline=start+(o.timeout or 60)
    repeat
        if not live() then return false,{ready=false,reason='cancelled'} end
        if game.JobId~=job then return false,{ready=false,reason='job-changed'} end
        last=M.read(game,player)
        if o.onSample then o.onSample(last) end
        if last.ready then
            if not stable or stable.playerGui~=last.playerGui or stable.character~=last.character
                or stable.root~=last.root or stable.humanoid~=last.humanoid then stable=last;since=now() end
            if now()-since>=(o.stableSeconds or .35) then return true,last end
        else stable=nil;since=nil end
        if now()>=deadline then break end
        pause(math.min(.1,deadline-now()))
    until false
    last.timedOut=true;last.waited=now()-start
    return false,last
end
return M
