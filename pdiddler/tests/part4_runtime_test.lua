-- Bundled with the unmodified production source by run_trading_tests.py.
local passed=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function node(name,class,parent,props)
    local n={Name=name,ClassName=class,Parent=parent,Visible=true,Enabled=true,children={},AbsolutePosition={X=0,Y=0},AbsoluteSize={X=20,Y=20}}
    for k,v in pairs(props or {}) do n[k]=v end
    function n:IsA(c) return c==self.ClassName or c=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel" or self.ClassName=="TextButton") end
    function n:FindFirstChild(k) return self.children[k] end
    function n:FindFirstChildOfClass(c) for _,v in pairs(self.children) do if v:IsA(c) then return v end end end
    function n:GetAttribute(k) return self.attributes and self.attributes[k] end
    function n:GetFullName() return self.Name end
    local signals={}
    function n:GetPropertyChangedSignal(k)
        if not signals[k] then
            local handlers={}
            signals[k]={Connect=function(_,fn) handlers[#handlers+1]=fn; return {Disconnect=function() for i,h in ipairs(handlers) do if h==fn then table.remove(handlers,i); break end end end} end,
                Fire=function() for _,fn in ipairs(handlers) do fn() end end}
        end
        return signals[k]
    end
    function n:GetDescendants() local out={}; local function walk(p) for _,v in pairs(p.children) do out[#out+1]=v; walk(v) end end; walk(self); return out end
    if parent then parent.children[name]=n end; return n
end
local function fixture()
    local f={now=0,queue={},env={},offers=0,declines=0,accepts=0,ourPicks={},theirPicks={},rows={},ownDelay=0}
    f.task={}
    function f.task.spawn(fn) local co=coroutine.create(fn); f.queue[#f.queue+1]={co=co,at=f.now}; return co end
    function f.task.wait(dt) return coroutine.yield(dt or .01) end
    function f:advance(untilTime)
        local count=0
        while true do
            local at,index=math.huge,nil
            for i,q in ipairs(self.queue) do if q.at<at then at=q.at; index=i end end
            if not index or at>untilTime then break end
            local q=table.remove(self.queue,index); self.now=q.at
            local ok,dt=coroutine.resume(q.co); assert(ok,dt)
            if coroutine.status(q.co)~="dead" then self.queue[#self.queue+1]={co=q.co,at=self.now+(dt or .01)} end
            count=count+1; assert(count<100000,"scheduler runaway")
        end
        self.now=untilTime
    end
    local players=node("Players","Players")
    local lp=node("Local","Player",players,{UserId=1}); local target=node("Exact_User","Player",players,{UserId=2,DisplayName="Nice"})
    players.LocalPlayer=lp; function players:GetPlayers() return {lp,target} end
    function players:GetPlayerByUserId(id) if id==2 then return target elseif id==1 then return lp end end
    f.pg=node("PlayerGui","PlayerGui",lp)
    local gui=node("TradeGUI","ScreenGui",f.pg); local container=node("Container","Frame",gui)
    f.root=node("Trade","Frame",container)
    local ours=node("YourOffer","Frame",f.root); local theirs=node("TheirOffer","Frame",f.root)
    node("Username","TextLabel",theirs,{Text="@Exact_User"}); node("Container","Frame",ours); node("Container","Frame",theirs)
    f.accepted=node("Accepted","Frame",theirs,{Visible=false})
    f.lp=lp; f.target=target
    local rs=node("ReplicatedStorage","ReplicatedStorage"); local folder=node("Trade","Folder",rs)
    local offer=node("OfferItem","RemoteEvent",folder); local decline=node("DeclineTrade","RemoteEvent",folder)
    local accept=node("AcceptTrade","RemoteEvent",folder); function accept:FireServer() f.accepts=f.accepts+1 end
    function f:item(id,value,qty)
        local row={page="godly",cat="Weapons",id=id,checkerId=id,name=id,qty=qty or 1,value=value,type="Knife"}
        self.rows["godly:"..id]={page="godly",id=id,name=id,supremeValue=value,demand=3,stability="Stable",verified=true}
        return row
    end
    f.own={items={f:item("A",100),f:item("B",70),f:item("C",30),f:item("D",10)},unmapped=0,unpriced=0,badQty=0}
    f.partnerInv={items={f:item("T",150),f:item("U",100),f:item("V",115)},unmapped=0,unpriced=0,badQty=0}
    function f:render(side,picks)
        local c=self.root.children[side].children.Container; c.children={}
        for i,it in ipairs(picks) do
            local slot=node("NewItem"..i,"Frame",c,{attributes={ItemId=it.id}})
            local label=node("ItemName","Frame",slot); node("Label","TextLabel",label,{Text=it.name})
            local box=node("Container","Frame",slot); node("Amount","TextLabel",box,{Text="x"..(it.qty or 1)})
            node("ActionButton","TextButton",box)
        end
    end
    function f:setTheir(items) self.theirPicks=items; self:render("TheirOffer",items) end
    function f:total() local n=0; for _,it in ipairs(self.ourPicks) do n=n+it.value*(it.qty or 1) end; return n end
    function offer:FireServer(id)
        f.offers=f.offers+1
        local found
        for _,it in ipairs(f.own.items) do if it.id==id then found=it end end
        assert(found,"unknown raw offer id")
        local exists
        for _,it in ipairs(f.ourPicks) do if it.id==id then it.qty=it.qty+1; exists=true end end
        if not exists then f.ourPicks[#f.ourPicks+1]={id=found.id,name=found.name,value=found.value,qty=1} end
        f:render("YourOffer",f.ourPicks)
        if f.onOffer then f.onOffer() end
    end
    function decline:FireServer() f.declines=f.declines+1; f.root.Visible=false end
    local vim={SendMouseButtonEvent=function(_,x,y,button,pressed)
        if not pressed then
            local last=f.ourPicks[#f.ourPicks]
            if last then last.qty=last.qty-1; if last.qty==0 then table.remove(f.ourPicks) end end
            f:render("YourOffer",f.ourPicks)
            if f.onRemove then f.onRemove() end
        end
    end}
    f.game={JobId="test-job",GetService=function(_,name)
        return ({Players=players,ReplicatedStorage=rs,VirtualInputManager=vim,GuiService={GetGuiInset=function() return {X=0,Y=0} end}})[name]
    end}
    f.profile={liveReady=true,get=function(page,id) return f.rows[page..":"..id] end,coverage=function() return {total=190} end,isFresh=function() return true end}
    f.scanner={getRecord=function(id) if id==2 then return {state="whitelist",inv=f.partnerInv} end end,
        getOwnInventory=function() if f.ownDelay>0 then f.task.wait(f.ownDelay) end; if f.onInventory then f.onInventory() end; return f.own end,
        setStatus=function() end,claimStatusOwner=function() end,releaseStatusOwner=function() end,setRequestState=function() end}
    f.telemetry={build=function(args) return {ourSignature=args.ourEval.signature,theirSignature=args.theirEval.signature} end}
    function f:start() self.module=NEW_PART4(self); self.controller=self.module.run(self.scanner,self.profile,POLICY,POLICY,self.telemetry); return self.controller end
    return f
end
local function test(name,fn) fn(); passed=passed+1; print("PASS "..name) end
test("actual Part 4 offers highest item before their offer",function() local f=fixture(); f:start(); f:advance(.5); eq(f.offers,1); eq(f:total(),100); eq(f.accepts,0) end)
test("stop during inventory yield cannot offer",function() local f=fixture(); f.ownDelay=1; local c=f:start(); f:advance(.5); c.stop(); f:advance(2); eq(f.offers,0) end)
test("partner change during inventory yield cannot offer",function() local f=fixture(); f.ownDelay=1; f.onInventory=function() f.root.children.TheirOffer.children.Username.Text="Other" end; f:start(); f:advance(2); eq(f.offers,0) end)
test("PlayerGui replacement during inventory yield cannot offer",function() local f=fixture(); f.ownDelay=1; f.onInventory=function() node("PlayerGui","PlayerGui",f.lp) end; f:start(); f:advance(2); eq(f.offers,0) end)
test("actual empty offer declines after twelve seconds",function() local f=fixture(); f:start(); f:advance(12); eq(f.declines,0); f:advance(12.6); eq(f.declines,1); eq(f.accepts,0) end)
test("removing their complete offer starts a new empty timeout",function() local f=fixture(); f:start(); f:advance(.5); f:setTheir({f.partnerInv.items[1]}); f:advance(1); f:setTheir({}); f:advance(12.8); eq(f.declines,0); f:advance(13.4); eq(f.declines,1) end)
test("actual accepted empty declines immediately",function() local f=fixture(); f:start(); f:advance(.5); f.accepted.Visible=true; f:advance(.8); eq(f.declines,1) end)
test("actual negotiation waits then improves to nearest safe total",function() local f=fixture(); f:start(); f:advance(.5); f:setTheir({f.partnerInv.items[1]}); f:advance(5.9); eq(f:total(),100); f:advance(8); eq(f:total(),110); eq(f.accepts,0) end)
test("offer change triggers full rebalance",function() local f=fixture(); f:start(); f:advance(.5); f:setTheir({f.partnerInv.items[1]}); f:advance(1.5); f:setTheir({f.partnerInv.items[2]}); f:advance(4.5); eq(f:total(),80); eq(f.declines,0) end)
test("best safe unchanged offer declines after final five seconds",function() local f=fixture(); f:start(); f:advance(.5); f:setTheir({f.partnerInv.items[3]}); f:advance(5.9); eq(f.declines,0); f:advance(7); eq(f.declines,1) end)
test("second run returns existing compatible controller",function() local f=fixture(); local c=f:start(); eq(f.module.run(f.scanner,f.profile,POLICY,POLICY,f.telemetry),c); f:advance(.6); eq(f.offers,1) end)
test("manual acceptance indication pauses negotiation without automatic accept",function() local f=fixture(); f:start(); f:advance(.5); f:setTheir({f.partnerInv.items[3]}); f.accepted.Visible=true; f:advance(9); eq(f.declines,0); eq(f.accepts,0) end)
test("same GUI close-reopen while inventory yields cannot inherit old session",function() local f=fixture(); f.ownDelay=1; f.onInventory=function() f.root.Visible=false; f.root:GetPropertyChangedSignal("Visible"):Fire(); f.root.Visible=true end; f:start(); f:advance(2); eq(f.offers,0) end)
test("missing partner snapshot cannot suppress accepted-empty decline",function() local f=fixture(); f:start(); f:advance(.5); f.scanner.getRecord=function() return nil end; f.accepted.Visible=true; f:advance(.8); eq(f.declines,1) end)
test("expired snapshot permits a safe decline but no new offers",function() local f=fixture(); f:start(); f:advance(.5); f.profile.isFresh=function() return false end; f:advance(.9); eq(f.declines,1); eq(f.offers,1) end)
test("preexisting own offer is declined with a bound identity",function() local f=fixture(); f.ourPicks={{id="A",name="A",value=100,qty=1}}; f:render("YourOffer",f.ourPicks); f:start(); f:advance(.7); eq(f.declines,1); eq(f.offers,0) end)
test("duplicate invocation cannot replace active controller policy",function() local f=fixture(); f:start(); f:advance(.5); local bad={}; for k,v in pairs(POLICY) do bad[k]=v end; bad.observe=function() error("replacement policy must not execute") end; f.module.run(f.scanner,f.profile,bad,bad,f.telemetry); f:advance(1); eq(f.offers,1) end)
test("partner accepting during a remove wait blocks subsequent offer actions",function() local f=fixture(); f:start(); f:advance(.5); f:setTheir({f.partnerInv.items[2]}); f.onRemove=function() f.accepted.Visible=true end; f:advance(4); eq(f.offers,1); eq(f.accepts,0) end)
test("expiry during inventory yield declines before opening item",function() local f=fixture(); f.ownDelay=1; f.onInventory=function() f.profile.isFresh=function() return false end end; f:start(); f:advance(2); eq(f.offers,0); eq(f.declines,1) end)
test("expiry after opening action declines instead of waiting forever",function() local f=fixture(); f.onOffer=function() f.profile.isFresh=function() return false end end; f:start(); f:advance(1); eq(f.offers,1); eq(f.declines,1) end)
test("transaction crossing sixty-second backstop stops offering and declines",function() local f=fixture(); f:start(); f:advance(.5); f:setTheir({f.partnerInv.items[2]}); f.onRemove=function() f.clockOffset=61 end; f:advance(4); eq(f.offers,1); eq(f.declines,1) end)
print("PASS "..passed.." full Part 4 Luau runtime tests")
