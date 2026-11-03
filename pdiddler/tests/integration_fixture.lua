-- Deterministic cooperative scheduler; substitutes Roblox/executor boundaries only.
local F={}
function F.new(options)
    local o=options or {}
    local f={now=0,queue={},errors={},events={},fetches={},env={},nodes={},options=o}
    local function schedule(co,at)
        f.queue[#f.queue+1]={co=co,at=at}
        return co
    end
    local task={}
    function task.spawn(fn,...) local args={...}; return schedule(coroutine.create(function() fn(table.unpack(args)) end),f.now) end
    function task.delay(t,fn) return schedule(coroutine.create(fn),f.now+t) end
    function task.wait(t) return coroutine.yield(math.max(t or .03,.001)) end
    function task.cancel(co) for _,q in ipairs(f.queue) do if q.co==co then q.cancelled=true end end end
    f.task=task
    function f:advance(untilTime)
        local count=0
        while true do
            table.sort(self.queue,function(a,b) return a.at<b.at end)
            local q=self.queue[1]
            if not q or q.at>untilTime then break end
            table.remove(self.queue,1)
            self.now=q.at
            if not q.cancelled then
                local ok,delay=coroutine.resume(q.co)
                if not ok then self.errors[#self.errors+1]=delay
                elseif coroutine.status(q.co)~="dead" then schedule(q.co,self.now+(delay or .03)) end
            end
            count=count+1; assert(count<200000,"scheduler runaway")
        end
        self.now=untilTime
    end
    function f:node(name,class,parent,props)
        local n={Name=name,ClassName=class,Parent=parent,Visible=true,Enabled=true,children={}}
        for k,v in pairs(props or {}) do n[k]=v end
        function n:IsA(c) return c==self.ClassName or c=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel") end
        function n:FindFirstChild(k) return self.children[k] end
        function n:FindFirstChildOfClass(c) for _,v in pairs(self.children) do if v:IsA(c) then return v end end end
        function n:WaitForChild(k) return self:FindFirstChild(k) end
        if parent then parent.children[name]=n end
        self.nodes[name]=n
        return n
    end
    local players={}
    local lp=f:node("local","Player",nil,{UserId=1})
    players.LocalPlayer=lp
    f.players=players; f.lp=lp; f.roster={lp}
    function players:GetPlayers() return f.roster end
    function f:addPlayer(id,state)
        local p=self:node("p"..id,"Player",nil,{UserId=id}); p.Parent=players
        self.roster[#self.roster+1]=p; self.records[id]=state and {state=state} or nil
        return p
    end
    function f:ui()
        local pg=self:node("PlayerGui","PlayerGui",lp)
        local main=self:node("MainGUI","ScreenGui",pg)
        local lobby=self:node("Lobby","Frame",main)
        local board=self:node("Leaderboard","Frame",lobby)
        local container=self:node("Container","Frame",board)
        local overlay=self:node("OverlayMenu","Frame",container)
        local req=self:node("TradeRequest","Frame",overlay)
        self:node("SendingRequest","Frame",req,{Visible=false})
        self:node("ReceivingRequest","Frame",req,{Visible=false})
        local tg=self:node("TradeGUI_Phone","ScreenGui",pg)
        local tc=self:node("Container","Frame",tg)
        self:node("Trade","Frame",tc,{Visible=false})
        self.pg=pg
    end
    f:ui()
    f.records={}; f.white={}; f.pending=false
    f.scanner={getWhitelist=function() return f.white end,
        getRecord=function(uid) return f.records[tonumber(uid)] end,
        hasPendingWork=function() return f.pending end}
    f.out={session=1,state={processed={},paused=false},stop=function() f.outStopped=true end}
    f.p4={session=1,state={active=false},stop=function() f.p4Stopped=true end}
    local function event(s) f.events[#f.events+1]={name=s,at=f.now} end
    f.hopper={state={hopping=false},jobId="job",isAlive=function() return true end,
        stop=function() f.hopperStopped=true end}
    function f.hopper:hopNow(reason)
        if f.canTeleport then
            local safe,why=f.canTeleport()
            if not safe then return false,why end
        end
        event("hop"); f.hopReason=reason
        if o.hopRefused then return false,"denied" end
        self.state.hopping=true; return true
    end
    function f.hopper:handleBotRejected(reason) return self:hopNow(reason) end
    local sources={}
    sources["pdiddler2_KNOWN_GOOD.lua"]=function() return {run=function()
        event("p2"); task.wait(o.p2Delay or 0.01)
        if o.p2Error then error("tablet-error") end
        return o.p2Result~=false
    end} end
    sources["pdiddler1_fast_gate_TEST_v5.lua"]=function()
        event("gate"); f.env.PDIDDLER_FAST_GATE_GEN=(f.env.PDIDDLER_FAST_GATE_GEN or 0)+1
        if o.gateInitDelay then task.wait(o.gateInitDelay) end
        local gen=f.env.PDIDDLER_FAST_GATE_GEN
        f.env.PDIDDLER_FAST_GATE_STOP=function() f.gateStopped=true end
        if not o.gateTimeout then task.delay(10,function()
            if o.supersede then f.env.PDIDDLER_FAST_GATE_GEN=gen+1 end
            f.env.PDIDDLER_FAST_GATE_RESULT={state=o.gateState or "PROCEED_UNVERIFIED",
                evidenceVersion=5,jobId=o.wrongJob and "old" or "job",elapsed=10,
                automaticHopAllowed=false,appearanceScans=2,appearanceScore=o.score or 70,total=9}
        end) end
        return nil -- actual standalone gate contract
    end
    sources["pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua"]=function()
        event("scanner"); task.wait(o.scannerDelay or .01); f.scannerLoads=(f.scannerLoads or 0)+1; return f.scanner
    end
    sources["pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua"]=function() return {run=function()
        event("outgoing"); if o.outError then error("outgoing-error") end
        f.env.PDIDDLER_OUTGOING_SESSION=1; return f.out
    end} end
    sources["pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua"]=function() return {run=function()
        event("p4"); f.env.PDIDDLER_PART4_SESSION=1
        if o.p4RunDelay then task.wait(o.p4RunDelay) end
        return f.p4
    end} end
    sources["pdiddler5_server_hopper_policy_v1.lua"]=function() return {} end
    for _,name in ipairs({"pdiddler5_server_hopper_v1.lua","pdiddler5_server_hopper_v2.lua"}) do
        sources[name]=function() return {bootstrap=function(_,guard)
            f.canTeleport=guard
            event("p5"); f.env.PDIDDLER_PART5_CONTROLLER=f.hopper; return f.hopper
        end} end
    end
    f.sources=sources
    local game={JobId="job",PlaceId=142823291}
    function game:IsLoaded() return o.loaded~=false end
    function game:GetService(name) if name=="Players" then return players end; return f.services and f.services[name] end
    function game:HttpGet(url)
        f.fetches[#f.fetches+1]=url
        local name=url:match("([^/]+)$")
        if o.fetchDelay then task.wait(o.fetchDelay) end
        if name==o.fetchFail then error("http-denied") end
        return name
    end
    f.game=game
    local scope={game=game,task=task,getgenv=function() return f.env end,
        os={clock=function() return f.now end},warn=function() end,print=function() end}
    scope.loadstring=function(source)
        if o.compileFail==source then return nil,"syntax-error" end
        return sources[source] or load(source,"fixture","t",scope)
    end
    setmetatable(scope,{__index=_G}); f.scope=scope
    function f:run(path)
        local file=assert(io.open(path)); local source=file:read("*a"); file:close()
        source=source:gsub("n%+=1","n=n+1") -- only Luau shorthand in original V1
        local fn=assert(load(source,"@"..path,"t",self.scope))
        self.task.spawn(function() self.controller=fn() end)
        self:advance(self.now+.001)
        return self.controller
    end
    function f:count(name) local n=0; for _,e in ipairs(self.events) do if e.name==name then n=n+1 end end; return n end
    return f
end
return F
