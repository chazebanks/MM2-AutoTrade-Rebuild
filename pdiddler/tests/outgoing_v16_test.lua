-- Runs actual extracted outgoing helpers; only Roblox/executor boundaries are fixtures.
-- Baseline: texlua pdiddler/tests/outgoing_v16_test.lua pdiddler/pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua
local path=arg[1] or "pdiddler/pdiddler3_outgoing_ROTATING_v16_EXACT_IDENTITY.lua"
local file=assert(io.open(path)); local source=file:read("*a"); file:close()
local passed,failed=0,0
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function extract(name,optional)
    local first=source:find("    local function "..name.."(",1,true)
    if not first and optional then return "" end
    assert(first,"missing production helper "..name)
    local last=assert(source:find("\n    end",first,true))
    local text=source:sub(first,last+7)
    -- Arithmetic shorthand only; helper control flow is otherwise unchanged.
    text=text:gsub("([%w_%.]+)%+=", "%1=%1+"):gsub("([%w_%.]+)%-=", "%1=%1-")
    return text.."\n"
end
local function node(name,class,parent,props)
    local n={Name=name,ClassName=class,Parent=parent,Visible=true,Enabled=true,children={},AbsolutePosition={X=0,Y=0},AbsoluteSize={X=100,Y=20}}
    for k,v in pairs(props or {}) do n[k]=v end
    function n:IsA(c)
        return c==self.ClassName or c=="GuiButton" and (self.ClassName=="TextButton" or self.ClassName=="ImageButton")
            or c=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel" or self.ClassName=="TextButton" or self.ClassName=="ImageButton")
    end
    function n:FindFirstChild(name) return self.children[name] end
    function n:FindFirstChildOfClass(c) for _,v in pairs(self.children) do if v:IsA(c) then return v end end end
    n.FindFirstChildWhichIsA=n.FindFirstChildOfClass
    function n:WaitForChild(name) return self:FindFirstChild(name) end
    function n:GetChildren() local out={}; for _,v in pairs(self.children) do out[#out+1]=v end; return out end
    function n:GetDescendants()
        local out={}; local function walk(p) for _,v in pairs(p.children) do out[#out+1]=v; walk(v) end end
        walk(self); return out
    end
    if parent then parent.children[name]=n end
    return n
end
local function fixture()
    local f={env={},roster={},white={},records={},events={},now=100}
    local players=node("Players","Players"); f.players=players
    local lp=node("LocalUser","Player",players,{UserId=1,DisplayName="Local Display"}); f.lp=lp; players.LocalPlayer=lp; f.roster={lp}
    function players:GetPlayers() return f.roster end
    function players:GetPlayerByUserId(uid) for _,p in ipairs(f.roster) do if p.UserId==uid then return p end end end
    local signal={Connect=function() return {Disconnect=function() end} end}; players.PlayerAdded=signal; players.PlayerRemoving=signal
    function f:add(name,display)
        local p=node(name,"Player",players,{UserId=#self.roster+1,DisplayName=display or name})
        self.roster[#self.roster+1]=p; self.white[#self.white+1]=p; self.records[p.UserId]={state="whitelist",player=p}; return p
    end
    f.pg=node("PlayerGui","PlayerGui",lp)
    f.main=node("MainGUI","ScreenGui",f.pg)
    function f:layout(kind)
        local branch=node(kind,"Frame",self.main)
        local board=node("Leaderboard","Frame",branch)
        local container=node("Container","Frame",board)
        local holder=container
        if kind=="Lobby" then holder=node("OverlayMenu","Frame",container) end
        local request=node("TradeRequest","Frame",holder)
        local sending=node("SendingRequest","Frame",request,{Visible=false})
        node("Username","TextLabel",sending,{Text=""}); node("Cancel","TextButton",sending,{Text="Cancel"})
        node("ReceivingRequest","Frame",request,{Visible=false})
        return {branch=branch,board=board,container=container,holder=holder,request=request,sending=sending}
    end
    f.phone=f:layout("Lobby")
    f.game={JobId="server-A",GetService=function(_,name) if name=="Players" then return players end; return node(name,name) end}
    f.scanner={getWhitelist=function() return f.white end,getRecord=function(uid) return f.records[uid] end,
        isWhitelisted=function(uid) return f.records[uid] and f.records[uid].state=="whitelist" end,
        hasPendingWork=function() return false end,setStatus=function() end,setRequestState=function() end}
    f.scope={game=f.game,getgenv=function() return f.env end,Players=players,LP=lp,PG=f.pg,task={spawn=function() end,wait=function() end},
        os={clock=function() return f.now end},print=function() end,warn=function() end}
    setmetatable(f.scope,{__index=_G})
    return f
end
local helpers={"key","usernameKey","textOf","visible","currentPlayerGui","activeLeaderboardLayout","leaderboardRoot","findPlayerLabel",
    "cardTextList","cardMatchesPlayer","rawCenter","findIdentityNearTradeButton","exactLeaderboardPopup","clickableAncestor","cardContainerForTradeButton",
    "findOpenCardFor","roots","exactRequestFrame","playerByExactName","findPendingCancelFallback","findPendingCancel","pendingOwner","pendingBelongsTo","pendingVisible","tradePartner","tradeBelongsTo","cancelPending"}
local function compileHelpers(f,realTrade)
    local chunks={"local RequestFrameCache=nil\nlocal tradeOpen=function() return testTrade end\n"}
    for _,name in ipairs(helpers) do chunks[#chunks+1]=extract(name,true) end
    if realTrade then
        local first=assert(source:find("    tradeOpen=function()",1,true))
        local last=assert(source:find("\n    end",first,true))
        chunks[#chunks+1]=source:sub(first,last+7)
    end
    local exported={}
    for _,name in ipairs(helpers) do exported[#exported+1]=name.."="..name end
    exported[#exported+1]="tradeOpen=tradeOpen"
    chunks[#chunks+1]="return {"..table.concat(exported,",").."}"
    return assert(load(table.concat(chunks,"\n"),"@"..path..":helpers","t",f.scope))()
end
local function popup(f,text)
    local p=node("Popup","Frame",f.phone.board); local c=node("Container","Frame",p)
    node("Username","TextLabel",c,{Text=text}); local a=node("Action","Frame",c); local t=node("Trade","TextButton",a,{Text="Trade"})
    return p,t
end

test("card proof rejects Alice123 for Alice",function()
    local f=fixture(); local alice=f:add("Alice"); local h=compileHelpers(f)
    local card=node("Card","Frame"); node("Username","TextLabel",card,{Text="Alice123"})
    eq(h.cardMatchesPlayer(card,alice),false)
end)
test("card proof preserves underscore distinctions",function()
    local f=fixture(); local alice=f:add("Alice_1"); local h=compileHelpers(f)
    local card=node("Card","Frame"); node("Username","TextLabel",card,{Text="Alice1"})
    eq(h.cardMatchesPlayer(card,alice),false)
end)
test("card proof rejects DisplayName identity",function()
    local f=fixture(); local alice=f:add("Alice","QueenAlice"); local h=compileHelpers(f)
    local card=node("Card","Frame"); node("Username","TextLabel",card,{Text="QueenAlice"})
    eq(h.cardMatchesPlayer(card,alice),false)
end)
test("player resolver rejects DisplayName and underscore collision",function()
    local f=fixture(); local alice=f:add("Alice_1","QueenAlice"); local h=compileHelpers(f)
    eq(h.playerByExactName("QueenAlice"),nil); eq(h.playerByExactName("Alice1"),nil); eq(h.playerByExactName("alice_1"),alice)
end)
test("leaderboard fallback rejects longer usernames",function()
    local f=fixture(); local alice=f:add("Alice"); local label=node("PlayerLabel","TextLabel",f.phone.container,{Text="Alice123"})
    local h=compileHelpers(f); eq(h.findPlayerLabel(alice),nil)
    label.Text="Alice"; eq(h.findPlayerLabel(alice),label)
end)
test("nearby card header requires an exact username",function()
    local f=fixture(); local alice=f:add("Alice","QueenAlice"); local h=compileHelpers(f)
    local button=node("Trade","TextButton",f.phone.container)
    local label=node("Username","TextLabel",f.phone.container,{Text="Alice123"})
    eq(h.findIdentityNearTradeButton(button,alice),nil)
    label.Text="QueenAlice"; eq(h.findIdentityNearTradeButton(button,alice),nil)
    label.Text="Alice"; eq(h.findIdentityNearTradeButton(button,alice),label)
end)
test("exact popup refuses DisplayName identity",function()
    local f=fixture(); local alice=f:add("Alice","QueenAlice"); popup(f,"QueenAlice"); local h=compileHelpers(f)
    local _,_,matched=h.findOpenCardFor(alice); eq(matched,false)
end)
test("pending identity rejects underscore collision",function()
    local f=fixture(); local alice=f:add("Alice_1"); f.phone.sending.Visible=true; f.phone.sending.children.Username.Text="Alice1"
    local h=compileHelpers(f); eq(h.pendingBelongsTo(alice),false)
end)
test("trade identity rejects DisplayName ownership",function()
    local f=fixture(); local alice=f:add("Alice","QueenAlice")
    local trade=node("Trade","Frame"); local side=node("TheirOffer","Frame",trade); node("Username","TextLabel",side,{Text="(QueenAlice)"})
    f.scope.testTrade=trade; local h=compileHelpers(f); eq(h.tradeBelongsTo(alice),false)
end)
test("valid case-insensitive exact username proves ownership",function()
    local f=fixture(); local alice=f:add("Alice_1"); popup(f,"aLiCe_1"); f.phone.sending.Visible=true
    f.phone.sending.children.Username.Text="Alice_1"; local h=compileHelpers(f)
    local _,_,matched=h.findOpenCardFor(alice); eq(matched,true); eq(h.pendingBelongsTo(alice),true)
end)
test("hidden phone cannot mask active tablet leaderboard or pending owner",function()
    local f=fixture(); local alice=f:add("Alice"); f.phone.branch.Visible=false; local tablet=f:layout("Game")
    tablet.sending.Visible=true; tablet.sending.children.Username.Text="Alice"
    local h=compileHelpers(f); eq(h.leaderboardRoot(),tablet.board); eq(h.exactRequestFrame(),tablet.request); eq(h.pendingBelongsTo(alice),true)
end)
test("request cache revalidates full ancestry after container replacement",function()
    local f=fixture(); local h=compileHelpers(f); eq(h.exactRequestFrame(),f.phone.request)
    local old=f.phone; local fresh=f:layout("Lobby"); assert(old.request.Parent~=nil)
    eq(h.exactRequestFrame(),fresh.request)
end)
test("request cache rejects retained old PlayerGui after replacement",function()
    local f=fixture(); local h=compileHelpers(f); eq(h.exactRequestFrame(),f.phone.request)
    node("PlayerGui","PlayerGui",f.lp); eq(h.exactRequestFrame(),nil)
end)
test("request lookup follows current GUI ancestry and active layout changes",function()
    local f=fixture(); local h=compileHelpers(f); eq(h.exactRequestFrame(),f.phone.request)
    f.phone.branch.Visible=false; local tablet=f:layout("Game"); eq(h.exactRequestFrame(),tablet.request)
    f.main.Name="TabletUI"; f.pg.children.MainGUI=nil; f.pg.children.TabletUI=f.main
    eq(h.exactRequestFrame(),tablet.request)
end)

-- Execute the real run preamble, queue consumer and controller stop/return.
-- Worker/input/response loops are excluded because they require Roblox scheduling.
local function executableLoop(text,opening,ending,label)
    local first=assert(text:find(opening,1,true)); local last=assert(text:find(ending,first+#opening,true))
    local body=text:sub(first+#opening,last-1):gsub("%f[%a]continue%f[%A]","goto "..label)
    -- Lua's do scope permits forward goto past declarations; only the loop's
    -- Luau continue changes syntax. The original body executes unmodified.
    return text:sub(1,first+#opening-1).."\n            do"..body.."\n            end\n            ::"..label.."::"..text:sub(last)
end
local function compileConsumer(f,withSend)
    local start=assert(source:find("function M.run(scanner)",1,true))
    local finish=assert(source:find("    local function key(",start,true))
    local prefix=source:sub(start,finish-1)
    local footer=source:match("\n(    return {\n        session=SESSION,.-)\nend\n\nreturn M")
        or source:match("\n(    return Controller)\nend\n\nreturn M")
    assert(footer,"controller footer extraction")
    local operations=""
    if withSend then
        local watch=executableLoop(extract("watchOutgoingResponse"),"        do","\n        end\n\n        if not alive()", "continue_watch")
        local send=executableLoop(extract("sendAndWatch"),"        for attempt=1,C.SendAttempts do","\n        end\n\n        return \"failed\"", "continue_send")
        operations="local function incomingVisible() return false end\nlocal function pendingVisible() return false end\n"
            .."local function pendingBelongsTo() return false,'no-pending' end\nlocal function tradeOpen() return nil end\n"
            .."local function openTargetCard() return true,testButton end\nlocal function findOpenCardFor() return testCard,testButton,true end\n"
            .."local function physicalTap(...) return testTap(...) end\n"..extract("targetCurrent")..watch..send
    end
    local body="local M={}\n"..prefix.."\nlocal function readinessRemaining() return 0 end\n"..extract("nextTarget")..extract("markProcessed")..operations
        .."local result=(function()\n"..footer.."\nend)()\nresult.testNext=nextTarget\nresult.testMark=markProcessed\nresult.testSend=sendAndWatch\nreturn result\nend\nreturn M"
    return assert(load(body,"@"..path..":consumer","t",f.scope))()
end
test("duplicate run retains current controller without invalidating its session",function()
    local f=fixture(); local m=compileConsumer(f); local first=m.run(f.scanner); local session=f.env.PDIDDLER_OUTGOING_SESSION
    local second=m.run(f.scanner); eq(second,first); eq(f.env.PDIDDLER_OUTGOING_SESSION,session)
end)
test("incompatible legacy owner is preserved and rejected",function()
    local f=fixture(); f.env.PDIDDLER_OUTGOING_SESSION=17; f.env.PDIDDLER_OUTGOING_BUSY_SESSION=17
    local ok=pcall(compileConsumer(f).run,f.scanner); eq(ok,false)
    eq(f.env.PDIDDLER_OUTGOING_SESSION,17); eq(f.env.PDIDDLER_OUTGOING_BUSY_SESSION,17)
end)
test("processed queue ledger survives safe restart in the same JobId",function()
    local f=fixture(); local alice=f:add("Alice"); local m=compileConsumer(f); local first=m.run(f.scanner)
    eq(first.testNext(),alice); first.testMark(alice,"uncertain-timeout"); first.stop()
    local restarted=m.run(f.scanner); eq(restarted.testNext(),nil); eq(restarted.state.processed[alice.UserId],"uncertain-timeout")
end)
test("processed queue ledger is separate per JobId",function()
    local f=fixture(); local alice=f:add("Alice"); local m=compileConsumer(f); local first=m.run(f.scanner)
    first.testMark(alice,"ignored"); first.stop(); f.game.JobId="server-B"
    local second=m.run(f.scanner); eq(second.testNext(),alice); second.stop(); f.game.JobId="server-A"
    eq(m.run(f.scanner).testNext(),nil)
end)
test("stopped controller cannot relinquish unresolved outgoing ownership",function()
    local f=fixture(); local alice=f:add("Alice"); local m=compileConsumer(f); local c=m.run(f.scanner)
    c.state.uncertainOutgoing={target=alice,userId=alice.UserId}; c.stop()
    local session=f.env.PDIDDLER_OUTGOING_SESSION
    local ok=pcall(m.run,f.scanner); eq(ok,false); eq(f.env.PDIDDLER_OUTGOING_SESSION,session)
end)
test("one successful physical Trade tap owns the full no-proof response window",function()
    local f=fixture(); local alice=f:add("Alice"); local taps=0; local started=f.now; local c
    f.scope.testButton=node("Trade","TextButton"); f.scope.testCard=node("Card","Frame")
    f.scope.testTap=function(button) eq(button,f.scope.testButton); taps=taps+1; return true end
    f.scope.visible=function() return true end
    f.scope.task.wait=function(seconds)
        f.now=f.now+seconds
        assert(c.state.uncertainOutgoing and c.state.uncertainOutgoing.target==alice,"uncertain target ownership lost")
    end
    c=compileConsumer(f,true).run(f.scanner)
    eq(c.testSend(alice),"uncertain-timeout"); eq(taps,1); assert(f.now-started>=15)
end)
test("successful Trade tap protects the queue before yielding for response proof",function()
    local f=fixture(); local alice=f:add("Alice"); local c
    f.scope.testButton=node("Trade","TextButton"); f.scope.testCard=node("Card","Frame")
    f.scope.testTap=function() return true end; f.scope.visible=function() return true end
    f.scope.task.wait=function()
        eq(c.testNext(),nil)
        error("fixture-response-boundary")
    end
    c=compileConsumer(f,true).run(f.scanner)
    local ok,why=pcall(c.testSend,alice); eq(ok,false)
    assert(tostring(why):find("fixture-response-boundary",1,true),tostring(why))
    eq(c.testNext(),nil)
end)

local function tradeGui(f,name,shown)
    local gui=node(name,"ScreenGui",f.pg); local container=node("Container","Frame",gui)
    return node("Trade","Frame",container,{Visible=shown})
end
test("hidden enabled phone trade cannot mask active tablet trade",function()
    local f=fixture(); tradeGui(f,"TradeGUI_Phone",false); local desktop=tradeGui(f,"TradeGUI",true)
    local h=compileHelpers(f,true); eq(h.tradeOpen(),desktop)
end)
test("enabled trade GUI with hidden Trade frame is not an active trade",function()
    local f=fixture(); tradeGui(f,"TradeGUI_Phone",false); tradeGui(f,"TradeGUI",false)
    local h=compileHelpers(f,true); eq(h.tradeOpen(),nil)
end)

local function cancellationFixture(options)
    local o=options or {}; local f=fixture(); local alice=f:add("Alice"); f:add("Bob")
    local c=compileConsumer(f).run(f.scanner)
    f.scope.S=c.state; f.scope.alive=c.isAlive or function() return f.env.PDIDDLER_OUTGOING_SESSION==c.session end
    f.phone.sending.Visible=true; f.phone.sending.children.Username.Text="Alice"
    node("PendingMarker","TextLabel",f.phone.sending,{Text="TRADE REQUEST PENDING"})
    if not o.button then f.phone.sending.children.Cancel=nil end
    f.taps,f.remoteCalls,f.waits=0,0,0
    f.scope.physicalTap=function() f.taps=f.taps+1; return true end
    local remote=node("DeclineRequest","RemoteEvent")
    function remote:FireServer()
        f.remoteCalls=f.remoteCalls+1
        if o.remoteError then error("uncertain-remote-delivery") end
        if o.remoteClears then f.phone.sending.Visible=false end
    end
    f.scope.DeclineRequest=remote
    f.scope.task.wait=function(seconds)
        f.now=f.now+seconds; f.waits=f.waits+1
        if f.waits==1 and o.afterYield then o.afterYield(f,c,alice) end
    end
    f.h=compileHelpers(f,true); f.controller=c
    return f
end
for _,change in ipairs({
    {"stop",function(_,c) c.stop() end},
    {"PlayerGui replacement",function(f) node("PlayerGui","PlayerGui",f.lp) end},
    {"new active trade",function(f) tradeGui(f,"TradeGUI",true) end},
    {"changed pending owner",function(f) f.phone.sending.children.Username.Text="Bob" end},
    {"replacement request ancestry",function(f) local layout=f:layout("Lobby"); layout.sending.Visible=true; layout.sending.children.Username.Text="Alice" end},
}) do
    test("delayed cancellation revalidates "..change[1],function()
        local f=cancellationFixture({afterYield=change[2]})
        eq(f.h.cancelPending("fixture"),false); eq(f.remoteCalls,0); eq(f.taps,0)
    end)
end
test("successful Cancel tap with uncertain acknowledgement is never duplicated",function()
    local f=cancellationFixture({button=true})
    eq(f.h.cancelPending("fixture"),false); eq(f.taps,1); eq(f.remoteCalls,0)
    eq(f.h.cancelPending("fixture again"),false); eq(f.taps,1); eq(f.remoteCalls,0)
end)
test("uncertain cancellation remote delivery cannot cause another action",function()
    local f=cancellationFixture({remoteError=true})
    eq(f.h.cancelPending("fixture"),false); eq(f.remoteCalls,1); eq(f.taps,0)
    eq(f.h.cancelPending("fixture again"),false); eq(f.remoteCalls,1); eq(f.taps,0)
end)
test("changed pending owner cannot steal uncertain cancellation ownership",function()
    local f=cancellationFixture({button=true})
    eq(f.h.cancelPending("fixture"),false); f.phone.sending.children.Username.Text="Bob"
    eq(f.h.cancelPending("changed owner"),false); eq(f.taps,1); eq(f.remoteCalls,0)
end)
test("observed cleared pending UI releases cancellation ownership for a new request",function()
    local f=cancellationFixture({button=true})
    eq(f.h.cancelPending("fixture"),false); f.phone.sending.Visible=false
    eq(f.h.pendingVisible(),false); f.phone.sending.Visible=true; f.phone.sending.children.Username.Text="Bob"
    eq(f.h.cancelPending("new request"),false); eq(f.taps,2); eq(f.remoteCalls,0)
end)
test("uncertain cancellation ownership cannot be abandoned by a safe restart",function()
    local f=cancellationFixture({button=true})
    eq(f.h.cancelPending("fixture"),false); f.controller.stop()
    local ok=pcall(compileConsumer(f).run,f.scanner); eq(ok,false); eq(f.taps,1); eq(f.remoteCalls,0)
end)
test("unchanged exact pending owner permits one cancellation remote",function()
    local f=cancellationFixture({remoteClears=true})
    eq(f.h.cancelPending("fixture"),true); eq(f.remoteCalls,1); eq(f.taps,0)
    f.controller.stop(); assert(compileConsumer(f).run(f.scanner))
end)

print(string.format("%d passed, %d failed (%s)",passed,failed,path)); os.exit(failed==0 and 0 or 1)
