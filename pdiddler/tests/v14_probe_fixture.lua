-- Offline Roblox boundary double; production probe source runs unmodified.
local function probeFixture()
    local f={now=0,queue={},env={},printed={},reads=0,readDelay=0,counts={KnifeA=2,KnifeB=0}}
    local function signal()
        local s={listeners={}}
        function s:Connect(fn)
            local c={Connected=true};function c:Disconnect() self.Connected=false end
            self.listeners[#self.listeners+1]={fn=fn,c=c};return c
        end
        function s:Fire(...)
            local copy=table.clone(self.listeners)
            for _,entry in ipairs(copy) do if entry.c.Connected then entry.fn(...) end end
        end
        return s
    end
    local function node(name,class,parent)
        local n={Name=name,ClassName=class,Parent=nil,Visible=true,Enabled=true,Text="",children={},properties={}}
        for _,key in ipairs({"DescendantAdded","DescendantRemoving","ChildAdded","ChildRemoved","AncestryChanged","Destroying","Activated","OnClientEvent"}) do n[key]=signal() end
        function n:IsA(kind)
            return kind==self.ClassName or kind=="Instance" or kind=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel" or self.ClassName=="TextButton")
                or kind=="GuiButton" and self.ClassName=="TextButton"
        end
        function n:FindFirstChild(key) for _,v in ipairs(self.children) do if v.Name==key then return v end end end
        function n:FindFirstChildOfClass(kind) for _,v in ipairs(self.children) do if v:IsA(kind) then return v end end end
        function n:GetDescendants()
            local out={};for _,v in ipairs(self.children) do out[#out+1]=v;for _,x in ipairs(v:GetDescendants()) do out[#out+1]=x end end;return out
        end
        function n:GetPropertyChangedSignal(key) if not self.properties[key] then self.properties[key]=signal() end;return self.properties[key] end
        function n:Set(key,value) self[key]=value;self:GetPropertyChangedSignal(key):Fire() end
        function n:SetParent(nextParent)
            local old=self.Parent
            if old then
                local a=old;while a do a.DescendantRemoving:Fire(self);a=a.Parent end
                for i,v in ipairs(old.children) do if v==self then table.remove(old.children,i);break end end
                old.ChildRemoved:Fire(self)
            end
            self.Parent=nextParent
            if nextParent then
                nextParent.children[#nextParent.children+1]=self
                nextParent.ChildAdded:Fire(self)
                local a=nextParent;while a do a.DescendantAdded:Fire(self);a=a.Parent end
            end
            self.AncestryChanged:Fire(self,nextParent);self:GetPropertyChangedSignal("Parent"):Fire()
        end
        if parent then n:SetParent(parent) end
        return n
    end
    f.node=node;f.task={}
    function f.task.spawn(fn) local c=coroutine.create(fn);f.queue[#f.queue+1]={c=c,at=f.now};return c end
    function f.task.wait(dt) return coroutine.yield(dt or .01) end
    function f.task.delay(dt,fn) local c=coroutine.create(fn);f.queue[#f.queue+1]={c=c,at=f.now+dt};return c end
    function f:advance(untilTime)
        local cycles=0
        while true do
            local index,at=nil,math.huge
            for i,v in ipairs(self.queue) do if v.at<at then index=i;at=v.at end end
            if not index or at>untilTime then break end
            local q=table.remove(self.queue,index);self.now=q.at
            local ok,dt=coroutine.resume(q.c);assert(ok,dt)
            if coroutine.status(q.c)~="dead" then self.queue[#self.queue+1]={c=q.c,at=self.now+(dt or .01)} end
            cycles=cycles+1;assert(cycles<20000,"scheduler runaway")
        end
        self.now=untilTime
    end
    f.player=node("LocalUser","Player");f.player.UserId=11
    f.pg=node("PlayerGui","PlayerGui",f.player)
    f.gui=node("TradeGUI_Phone","ScreenGui",f.pg)
    local container=node("Container","Frame",f.gui)
    f.root=node("Trade","Frame",container)
    for _,sideName in ipairs({"YourOffer","TheirOffer"}) do
        local side=node(sideName,"Frame",f.root)
        local accepted=node("Accepted","Frame",side);accepted.Visible=false
        node("Container","Frame",side)
        if sideName=="TheirOffer" then f.partner=node("Username","TextLabel",side);f.partner.Text="FixturePartner" end
    end
    f.button=node("Accept","TextButton",f.root);f.button.Text="Accept"
    f.rs=node("ReplicatedStorage","ReplicatedStorage")
    local remotes=node("Remotes","Folder",f.rs)
    local inv=node("Inventory","Folder",remotes)
    f.remote=node("GetProfileData","RemoteFunction",inv)
    function f.remote:InvokeServer(...)
        assert(select("#",...)==0,"GetProfileData must have no arguments")
        f.reads=f.reads+1
        if f.readDelay>0 then f.task.wait(f.readDelay) end
        if f.readError then error("fixture read failed") end
        return f.profile or {Weapons={Owned=table.clone(f.counts)}}
    end
    local trade=node("Trade","Folder",f.rs)
    f.acceptRemote=node("AcceptTrade","RemoteEvent",trade)
    f.declineRemote=node("DeclineTrade","RemoteEvent",trade)
    f.players={LocalPlayer=f.player}
    f.game={JobId="fixture-job"}
    function f.game:GetService(name) if name=="Players" then return f.players elseif name=="ReplicatedStorage" then return f.rs end;error("unexpected service "..name) end
    function f:start() self.probe=NEW_PROBE(self);self:advance(self.now);return self end
    function f:capture(stage) local ok,why=self.probe.capture(stage);self:advance(self.now);return ok,why end
    function f:reopen() self.root:Set("Visible",false);self.root:Set("Visible",true) end
    return f
end
