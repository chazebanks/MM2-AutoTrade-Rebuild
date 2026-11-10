-- SUPERVISED SAFE FORK (not the frozen/original trade IO).
-- The original historical Part4 launcher is NOT authorized to call this.
-- Physical OfferItem dispatch is default-DENY without an explicit local
-- operator/partner/offer-revision/fresh-price gate; Gingerscope outgoing is
-- prohibited independently of that gate. No final Accept is implemented.
-- Original source Git blob: 0c12285438ee66166aa89086c891f697a33338fc
-- pdiddler Part 4 trade I/O v1
-- Low-level active-trade reader/executor.
-- Deliberately contains NO final AcceptTrade lookup and NO Accept-button action.

local M={}

function M.new(scanner,supervisedGate)
    if type(scanner)~="table"
        or type(scanner.resolveOfferEntry)~="function"
    then
        error("[PDIDDLER P4 IO] scanner Part4 bridge missing")
    end

    local Players=game:GetService("Players")
    local RS=game:GetService("ReplicatedStorage")
    local VIM=game:GetService("VirtualInputManager")
    local GuiService=game:GetService("GuiService")

    local LP=Players.LocalPlayer
    local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

    local TradeFolder=RS:FindFirstChild("Trade")
    local OfferItem=TradeFolder and TradeFolder:FindFirstChild("OfferItem")
    local DeclineTrade=TradeFolder and TradeFolder:FindFirstChild("DeclineTrade")

    local A={}

    local function norm(x)
        return tostring(x or "")
            :gsub("’","'")
            :lower()
            :gsub("[^%w]","")
    end

    local function visible(o,stopAt)
        if not o then return false end

        local ok,result=pcall(function()
            local c=o

            while c do
                if c:IsA("ScreenGui") and not c.Enabled then
                    return false
                end

                if c:IsA("GuiObject") and not c.Visible then
                    return false
                end

                if stopAt and c==stopAt then
                    return true
                end

                c=c.Parent
            end

            return stopAt==nil
        end)

        return ok and result
    end

    local function trade()
        for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
            local g=PG:FindFirstChild(name)
            local c=g and g:FindFirstChild("Container")
            local t=c and c:FindFirstChild("Trade")

            if t then
                local enabled=true

                if g:IsA("ScreenGui") then
                    local ok,v=pcall(function()
                        return g.Enabled
                    end)

                    if ok then
                        enabled=v
                    end
                end

                if enabled then
                    return t
                end
            end
        end

        return nil
    end

    local function textOf(o)
        if not o then return "" end

        if o:IsA("TextLabel")
            or o:IsA("TextButton")
            or o:IsA("TextBox")
        then
            local ok,v=pcall(function()
                return tostring(o.Text or "")
            end)

            if ok then return v end
        end

        return ""
    end

    local function slotName(slot)
        if not slot or not slot.Visible then
            return nil
        end

        local itemName=slot:FindFirstChild("ItemName")
        local label=itemName and itemName:FindFirstChild("Label")

        if label
            and (
                label:IsA("TextLabel")
                or label:IsA("TextButton")
            )
        then
            local s=tostring(label.Text or "")

            if s~="" then
                return s
            end
        end

        for _,d in ipairs(slot:GetDescendants()) do
            if (
                d:IsA("TextLabel")
                or d:IsA("TextButton")
            )
                and visible(d,slot)
            then
                local s=tostring(d.Text or "")
                    :gsub("^%s+","")
                    :gsub("%s+$","")

                if s~=""
                    and not s:match("^[xX]%s*%d+$")
                then
                    return s
                end
            end
        end

        return nil
    end

    local function slotInternalId(slot)
        if not slot then return nil end

        for _,attr in ipairs({
            "ItemId","ItemID","ID","WeaponId","WeaponID",
        }) do
            local ok,v=pcall(function()
                return slot:GetAttribute(attr)
            end)

            if ok and v~=nil and tostring(v)~="" then
                return tostring(v)
            end
        end

        for _,name in ipairs({
            "ItemId","ItemID","ID","WeaponId","WeaponID",
        }) do
            local v=slot:FindFirstChild(name,true)

            if v and (
                v:IsA("StringValue")
                or v:IsA("IntValue")
                or v:IsA("NumberValue")
            ) then
                return tostring(v.Value)
            end
        end

        return nil
    end

    local function slotIsChroma(slot)
        if not slot then return false end

        local tags=slot:FindFirstChild("Tags")
        local chroma=tags and tags:FindFirstChild("Chroma")

        return chroma~=nil and visible(chroma,slot)
    end

    local function slotQty(slot)
        if not slot then return 1 end

        local box=slot:FindFirstChild("Container")
        local amount=box and box:FindFirstChild("Amount")

        if amount
            and (
                amount:IsA("TextLabel")
                or amount:IsA("TextButton")
            )
        then
            local n=tonumber(
                tostring(amount.Text or ""):match("^[xX]%s*(%d+)$")
            )

            if n and n>=1 then
                return math.floor(n)
            end
        end

        return 1
    end

    local function readSide(t,sideName)
        local side=t and t:FindFirstChild(sideName)
        local container=side and side:FindFirstChild("Container")

        local out={
            slots=0,
            entries={},
        }

        if not container then
            return out
        end

        for i=1,4 do
            local slot=container:FindFirstChild("NewItem"..i)

            if slot and slot.Visible then
                local shown=slotName(slot)

                if shown and shown~="" then
                    out.slots+=1

                    out.entries[#out.entries+1]={
                        index=i,
                        node=slot,
                        shown=shown,
                        isChroma=slotIsChroma(slot),
                        internalId=slotInternalId(slot),
                        qty=slotQty(slot),
                    }
                end
            end
        end

        return out
    end

    local function entryFullName(entry)
        local shown=tostring(entry and entry.shown or "")

        if entry
            and entry.isChroma
            and not shown:lower():match("^%s*chroma%s+")
        then
            return "Chroma "..shown
        end

        return shown
    end

    local function sideSignature(side)
        local parts={}

        for _,e in ipairs((side and side.entries) or {}) do
            parts[#parts+1]=table.concat({
                tostring(e.index or 0),
                norm(e.internalId),
                norm(entryFullName(e)),
                e.isChroma and "c" or "n",
                tostring(math.max(1,tonumber(e.qty) or 1)),
            },":")
        end

        return table.concat(parts,"|")
    end

    local function resolveSide(side,inventory)
        local out={
            slots=side and side.slots or 0,
            units=0,
            total=0,
            items={},
            unresolved={},
        }

        for _,entry in ipairs((side and side.entries) or {}) do
            local item,why=scanner.resolveOfferEntry(entry,inventory)

            if item then
                local qty=math.max(1,tonumber(item.qty) or 1)
                local copy={
                    id=item.id,
                    name=item.name,
                    value=item.value,
                    page=item.page,
                    type=item.type,
                    qty=qty,
                    checkerId=item.checkerId,
                    identity=item.identity,
                    valueSource=item.valueSource,
                }

                out.items[#out.items+1]=copy
                out.units+=qty
                out.total+=(tonumber(copy.value) or 0)*qty
            else
                out.unresolved[#out.unresolved+1]={
                    name=entryFullName(entry),
                    qty=math.max(1,tonumber(entry.qty) or 1),
                    reason=tostring(why or "unresolved"),
                }
            end
        end

        return out
    end

    local function partnerName(t)
        local their=t and t:FindFirstChild("TheirOffer")
        local u=their and their:FindFirstChild("Username")
        local s=u and textOf(u) or ""

        s=s:match("^%s*%((.-)%)%s*$") or s

        return s
            :gsub("^@","")
            :gsub("^%s+","")
            :gsub("%s+$","")
    end

    local function partnerPlayer(t)
        local wanted=norm(partnerName(t))

        if wanted=="" then
            return nil
        end

        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP
                and (
                    norm(p.Name)==wanted
                    or norm(p.DisplayName)==wanted
                )
            then
                return p
            end
        end

        return nil
    end

    local function safeClick(button)
        if not button or not visible(button) then
            return false
        end

        local attempted=false

        if firesignal then
            local ok1=pcall(function()
                firesignal(button.Activated)
            end)

            local ok2=pcall(function()
                firesignal(button.MouseButton1Click)
            end)

            attempted=ok1 or ok2 or attempted
        end

        local okActivate=pcall(function()
            button:Activate()
        end)

        attempted=okActivate or attempted

        local okPhysical=pcall(function()
            local p=button.AbsolutePosition
            local s=button.AbsoluteSize
            local inset=GuiService:GetGuiInset()
            local x=p.X+s.X/2+inset.X
            local y=p.Y+s.Y/2+inset.Y

            VIM:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(x,y,0,false,game,0)
        end)

        return attempted or okPhysical
    end

    local function acceptedTheir(t)
        if not t then
            return false,"no-trade"
        end

        for _,child in ipairs(t:GetDescendants()) do
            if (
                child:IsA("TextLabel")
                or child:IsA("TextButton")
            )
                and visible(child,t)
            then
                local raw=textOf(child)
                local q=raw
                    :upper()
                    :gsub("%s+"," ")
                    :gsub("^%s+","")
                    :gsub("%s+$","")

                if q:find(
                    "OTHER PLAYER HAS ACCEPTED",
                    1,
                    true
                ) then
                    return true,child:GetFullName()
                end
            end
        end

        local side=t:FindFirstChild("TheirOffer")
        local direct=side and side:FindFirstChild("Accepted")

        if direct and visible(direct,t) then
            return true,direct:GetFullName()
        end

        return false,"none"
    end

    function A.trade()
        return trade()
    end

    function A.partnerName(t)
        return partnerName(t or trade())
    end

    function A.partnerPlayer(t)
        return partnerPlayer(t or trade())
    end

    function A.readSide(t,sideName)
        return readSide(t or trade(),sideName)
    end

    function A.sideSignature(side)
        return sideSignature(side)
    end

    function A.resolveSide(side,inventory)
        return resolveSide(side,inventory)
    end

    function A.acceptedTheir(t)
        return acceptedTheir(t or trade())
    end

    -- Opt-in SUPERVISED execution boundary. NO caller (including the
    -- historical Part4 launcher) gets permission to offer by default.
    -- This is local fail-closed policy; a future vetted controller must
    -- validate freshness, exact partner, offer revision, and operator intent.
    local function protectedOutbound(item)
        if type(item)~="table" then return false end
        for _,field in ipairs({"id","rawKey","key","itemId","name","identity"}) do
            local value=rawget(item,field)
            if type(value)=="string" then
                local compact=norm(value)
                if compact:find("gingerscope",1,true) then return true end
            end
        end
        return false
    end

    function A.offerItem(item)
        -- No remote call is allowed until ALL checks are successful.
        if type(item)~="table" then
            return false,"OFFER_ITEM_INVALID"
        end
        if protectedOutbound(item) then
            return false,"PROTECTED_GINGERSCOPE_OUTGOING"
        end
        if type(item.id)~="string" or item.id=="" or #item.id>90
            or item.id:find("[%c]")
            or (item.rawKey~=nil and type(item.rawKey)~="string")
            or (item.key~=nil and type(item.key)~="string")
            or (item.name~=nil and type(item.name)~="string") then
            return false,"OFFER_ITEM_ID_INVALID"
        end
        if not OfferItem or not OfferItem:IsA("RemoteEvent") then
            return false,"OFFER_REMOTE_UNAVAILABLE"
        end
        local tradeBefore=trade()
        if not tradeBefore or not visible(tradeBefore,PG) then
            return false,"TRADE_NOT_VISIBLE"
        end
        if type(supervisedGate)~="table"
            or type(supervisedGate.checkOutbound)~="function" then
            return false,"SUPERVISED_OFFER_GATE_MISSING"
        end
        -- Capture the exact pending raw weapon key. A caller-supplied
        -- client snapshot or displayed value is NOT a trusted price source.
        local rawId=item.id
        local okPolicy,authorized=pcall(supervisedGate.checkOutbound,item,tradeBefore)
        if not okPolicy or authorized~=true then
            return false,"SUPERVISED_OFFER_NOT_APPROVED"
        end
        -- Guard against a callback modifying the offer item or trade UI
        -- between admission and sending the actual OfferItem RemoteEvent.
        if item.id~=rawId or protectedOutbound(item) then
            return false,"OFFER_ITEM_CHANGED_DURING_AUTHORIZATION"
        end
        local tradeAfter=trade()
        if tradeAfter~=tradeBefore or not visible(tradeAfter,PG) then
            return false,"TRADE_CHANGED_DURING_AUTHORIZATION"
        end
        local ok,err=pcall(function()
            OfferItem:FireServer(rawId,"Weapons")
        end)
        if not ok then
            return false,"OFFER_REMOTE_SEND_FAILED"
        end
        return true,"fired"
    end

    function A.ourOfferContains(t,wanted)
        t=t or trade()

        if not t or not wanted then
            return false,"bad-input"
        end

        local side=readSide(t,"YourOffer")
        local wantedId=norm(wanted.id)
        local wantedName=norm(wanted.name)
        local wantedBase=norm(
            tostring(wanted.name or "")
                :gsub("^[Cc][Hh][Rr][Oo][Mm][Aa]%s+","")
        )
        local wantedChroma=
            tostring(wanted.name or ""):lower():match("^%s*chroma%s+")
            ~=nil
            or wantedId:find("chroma",1,true)~=nil

        for _,entry in ipairs(side.entries) do
            local entryId=norm(entry.internalId)
            local entryName=norm(entry.shown)

            if wantedId~=""
                and entryId~=""
                and entryId==wantedId
            then
                return true,"internal-id"
            end

            if wantedChroma then
                if entry.isChroma
                    and entryName==wantedBase
                then
                    return true,"base-name+chroma"
                end
            elseif not entry.isChroma
                and entryName==wantedName
            then
                return true,"display-name"
            end
        end

        return false,"no-match"
    end

    function A.removeOne(t)
        t=t or trade()

        local side=t and t:FindFirstChild("YourOffer")
        local container=side and side:FindFirstChild("Container")

        if not container then
            return false,"your-offer-container-missing"
        end

        for i=4,1,-1 do
            local slot=container:FindFirstChild("NewItem"..i)
            local box=slot and slot.Visible and slot:FindFirstChild("Container")
            local button=box and box:FindFirstChild("ActionButton")

            if button then
                return safeClick(button),"clicked-slot-"..i
            end
        end

        return false,"no-removable-slot"
    end

    function A.decline(reason)
        local fired=false

        if DeclineTrade
            and DeclineTrade:IsA("RemoteEvent")
        then
            fired=pcall(function()
                DeclineTrade:FireServer()
            end)
        end

        local deadline=os.clock()+1.2

        while trade() and os.clock()<deadline do
            task.wait(0.08)
        end

        local clicked=false

        if trade() then
            local t=trade()
            local actions=t and t:FindFirstChild("Actions")
            local decline=actions and actions:FindFirstChild("Decline")
            local button=decline and decline:FindFirstChild("ActionButton")

            if button then
                clicked=safeClick(button)
            end
        end

        local closeDeadline=os.clock()+2.5

        while trade() and os.clock()<closeDeadline do
            task.wait(0.08)
        end

        print(
            "[PDIDDLER P4 IO] DECLINE",
            tostring(reason or ""),
            "remote",fired,
            "ui",clicked,
            "closed",trade()==nil
        )

        return trade()==nil
    end

    return A
end

return M
