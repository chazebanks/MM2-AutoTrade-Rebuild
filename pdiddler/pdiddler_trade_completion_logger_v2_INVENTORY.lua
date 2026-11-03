-- pdiddler completed-trade logger v2 | post-trade canonical inventory audit
-- Passive observer: never accepts, confirms, declines, offers, removes, or mutates a trade.
-- Primary proof: MM2 AcceptTrade.OnClientEvent complete==true.
-- Fallback proof: trade closed + exact raw Weapons.Owned delta.\n-- After either proof, scanner.getOwnInventory supplies the canonical tracked total.

local M={}

function M.run(part4Controller,senderModule,payloadModule,completionLogic,scanner)
    assert(type(part4Controller)=="table","Part 4 controller required")
    assert(type(part4Controller.state)=="table","Part 4 state required")
    assert(type(senderModule)=="table" and type(senderModule.new)=="function",
        "webhook sender module required")
    assert(type(payloadModule)=="table" and type(payloadModule.build)=="function",
        "webhook payload module required")
    assert(type(completionLogic)=="table"
        and type(completionLogic.expectedDelta)=="function"
        and type(completionLogic.deltaMatches)=="function",
        "completion logic required")
    assert(type(scanner)=="table" and type(scanner.getOwnInventory)=="function",
        "scanner.getOwnInventory required")

    local RS=game:GetService("ReplicatedStorage")
    local ENV=(getgenv and getgenv()) or _G

    local SESSION=(tonumber(ENV.PDIDDLER_WEBHOOK_SESSION) or 0)+1
    ENV.PDIDDLER_WEBHOOK_SESSION=SESSION

    local function alive()
        return ENV.PDIDDLER_WEBHOOK_SESSION==SESSION
    end

    local sender=senderModule.new({
        url=tostring(ENV.PDIDDLER_DISCORD_WEBHOOK_URL or ""),
        maxRetries=4,
    })

    local S={
        session=SESSION,
        armed=nil,
        armSerial=0,
        logged={},
        completedSeen={},
        fallbackStarted={},
        postBatches={},
        failed={},
        sent=0,
        pending=0,
        lastStatus="starting",
    }

    local function cloneSnapshot(src)
        local out={}
        for k,v in pairs(type(src)=="table" and src or {}) do
            out[k]=v
        end
        return out
    end

    local function unwrapProfile(x,depth)
        depth=depth or 0
        if type(x)~="table" or depth>4 then return nil end

        if type(x.Weapons)=="table"
            and type(x.Weapons.Owned)=="table"
        then
            return x
        end

        for _,name in ipairs({
            "ProfileData",
            "Profile",
            "PlayerData",
            "Data",
            "Inventory",
            "FullInventory",
        }) do
            local found=unwrapProfile(x[name],depth+1)
            if found then return found end
        end

        return nil
    end

    local function ownCounts(timeout)
        local remotes=RS:FindFirstChild("Remotes")
        local inventory=remotes and remotes:FindFirstChild("Inventory")
        local getProfile=inventory and inventory:FindFirstChild("GetProfileData")

        if not getProfile or not getProfile:IsA("RemoteFunction") then
            return nil,"GetProfileData-missing"
        end

        local done=false
        local ok=false
        local raw=nil

        task.spawn(function()
            ok,raw=pcall(function()
                return getProfile:InvokeServer()
            end)
            done=true
        end)

        local deadline=os.clock()+(tonumber(timeout) or 4.0)
        while alive() and not done and os.clock()<deadline do
            task.wait(0.03)
        end

        if not alive() then return nil,"stale-session" end
        if not done then return nil,"GetProfileData-timeout" end
        if not ok or type(raw)~="table" then
            return nil,"GetProfileData-failed"
        end

        local profile=unwrapProfile(raw)
        local owned=profile and profile.Weapons and profile.Weapons.Owned
        if type(owned)~="table" then
            return nil,"Weapons.Owned-missing"
        end

        local counts={}
        for rawId,rawQty in pairs(owned) do
            local q=tonumber(rawQty)
            if q and q>=0 and q==math.floor(q) then
                counts[tostring(rawId)]=q
            end
        end

        return counts,nil
    end

    local function candidateKey(snap)
        if type(snap)~="table" then return nil end
        local id=tostring(snap.id or "")
        local ours=tostring(snap.ourSignature or "")
        local theirs=tostring(snap.theirSignature or "")
        if id=="" or ours=="" or theirs=="" then return nil end
        return table.concat({id,ours,theirs},"|")
    end


    local function countsFromParsedInventory(inv)
        local counts={}
        for _,entry in ipairs(type(inv)=="table" and type(inv.seen)=="table" and inv.seen or {}) do
            local raw=tostring(entry or "")
            local id,qty=raw:match("^(.*)x(%d+)$")
            local q=tonumber(qty)
            if id and id~="" and q and q>=0 and q==math.floor(q) then
                counts[id]=q
            end
        end
        return counts
    end

    local function postTradeInventory(final,armed)
        local deadline=os.clock()+12.0
        local lastFingerprint=nil
        local stableCount=0
        local latest=nil
        local latestWhy="no-read"

        local expectedDelta,useful=completionLogic.expectedDelta(final)
        local before=type(armed)=="table" and armed.before or nil

        -- Give MM2 a short replication window before the first canonical read.
        task.wait(0.35)

        while alive() and os.clock()<deadline do
            local inv,why=scanner.getOwnInventory()

            if type(inv)=="table" then
                latest=inv
                latestWhy=nil

                local fp=tostring(inv.fingerprint or "")
                if lastFingerprint~=nil and fp==lastFingerprint then
                    stableCount+=1
                else
                    lastFingerprint=fp
                    stableCount=1
                end

                local deltaOk=true
                local deltaStatus="server-complete"

                if before and type(expectedDelta)=="table" and useful==true then
                    local afterCounts=countsFromParsedInventory(inv)
                    deltaOk=completionLogic.deltaMatches(before,afterCounts,expectedDelta)==true
                    deltaStatus=deltaOk and "delta-verified" or "delta-pending"
                end

                if stableCount>=2 and deltaOk then
                    return {
                        total=tonumber(inv.total),
                        fingerprint=fp,
                        verification="verified-stable-"..deltaStatus,
                        unmapped=tonumber(inv.unmapped) or 0,
                        unpriced=tonumber(inv.unpriced) or 0,
                        badQty=tonumber(inv.badQty) or 0,
                    }
                end
            else
                latestWhy=tostring(why or "read-failed")
            end

            task.wait(0.35)
        end

        if type(latest)=="table" then
            local fp=tostring(latest.fingerprint or "")
            local status="latest-read-unverified"

            if before and type(expectedDelta)=="table" and useful==true then
                local afterCounts=countsFromParsedInventory(latest)
                if completionLogic.deltaMatches(before,afterCounts,expectedDelta)==true then
                    status="delta-verified-single-or-unstable-read"
                end
            end

            return {
                total=tonumber(latest.total),
                fingerprint=fp,
                verification=status,
                unmapped=tonumber(latest.unmapped) or 0,
                unpriced=tonumber(latest.unpriced) or 0,
                badQty=tonumber(latest.badQty) or 0,
            }
        end

        return {
            total=nil,
            verification="unavailable:"..tostring(latestWhy or "timeout"),
            unmapped=0,
            unpriced=0,
            badQty=0,
        }
    end

    local function queuePost(snapshot,source)
        if type(snapshot)~="table" or tostring(snapshot.id or "")=="" then
            return false,"invalid-snapshot"
        end

        local id=tostring(snapshot.id)
        if S.logged[id] then return false,"already-sent" end

        local batch=(S.postBatches[id] or 0)+1
        S.postBatches[id]=batch

        local payload=payloadModule.build(snapshot,source)

        if not sender.configured() then
            S.failed[id]="webhook-not-configured"
            S.lastStatus="webhook-not-configured"
            warn("[PDIDDLER WEBHOOK] completion verified but webhook URL/HTTP transport is not configured")
            return false,"webhook-not-configured"
        end

        sender.send(payload,function(ok,why,code)
            if not alive() or S.logged[id] then return end

            if ok then
                S.logged[id]=true
                S.failed[id]=nil
                S.sent+=1
                S.lastStatus="sent"
                print(
                    "[PDIDDLER WEBHOOK] SENT",
                    tostring(snapshot.traderName or "Unknown"),
                    "| raw gain",tostring(snapshot.rawGain),
                    "| protected gain",tostring(snapshot.protectedGain),
                    "| source",tostring(source)
                )
                return
            end

            S.failed[id]=tostring(why or "send-failed")
            S.lastStatus="send-failed:"..tostring(why or "unknown")

            local retryable=
                why=="retryable-status"
                or why=="request-error"

            if retryable and batch<4 then
                local delays={5,15,30}
                local delay=delays[batch] or 30

                task.delay(delay,function()
                    if alive() and not S.logged[id] then
                        queuePost(snapshot,source)
                    end
                end)
            else
                warn(
                    "[PDIDDLER WEBHOOK] SEND FAILED",
                    tostring(why),
                    tostring(code or "")
                )
            end
        end)

        return true,"queued"
    end

    local function completeTrade(snapshot,source,armedProof)
        if type(snapshot)~="table" then return false,"no-snapshot" end

        local id=tostring(snapshot.id or "")
        if id=="" then return false,"missing-id" end
        if S.completedSeen[id] then return false,"duplicate-completion" end

        -- Claim completion immediately so duplicate server/fallback evidence
        -- cannot start a second finalization/webhook path.
        S.completedSeen[id]=true

        local final=cloneSnapshot(snapshot)
        final.completionSource=tostring(source or "verified")
        final.completedAt=os.clock()

        S.pending+=1
        S.lastStatus="completion-verified:inventory-pending"

        task.spawn(function()
            local post=postTradeInventory(final,armedProof)

            if not alive() then
                S.pending=math.max(0,S.pending-1)
                return
            end

            final.trackedInventoryTotal=post.total
            final.trackedInventoryVerification=post.verification
            final.trackedInventoryUnmapped=post.unmapped
            final.trackedInventoryUnpriced=post.unpriced
            final.trackedInventoryBadQty=post.badQty
            final.trackedInventoryFingerprint=post.fingerprint

            S.pending=math.max(0,S.pending-1)
            S.lastStatus="completion-verified:"..final.completionSource
            queuePost(final,final.completionSource)
        end)

        return true,"completion-verified-inventory-pending"
    end

    local function armCandidate(candidate)
        local key=candidateKey(candidate)
        if not key then return end

        if S.armed and S.armed.key==key then
            S.armed.snapshot=cloneSnapshot(candidate)
            S.armed.seenAt=os.clock()
            return
        end

        S.armSerial+=1
        local serial=S.armSerial

        local armed={
            key=key,
            snapshot=cloneSnapshot(candidate),
            before=nil,
            beforeError=nil,
            seenAt=os.clock(),
            serial=serial,
        }
        S.armed=armed
        S.lastStatus="candidate-armed"

        task.spawn(function()
            local counts,why=ownCounts(4.0)

            if not alive()
                or serial~=S.armSerial
                or S.armed~=armed
            then
                return
            end

            armed.before=counts
            armed.beforeError=why
        end)
    end

    local function clearArmed(reason)
        S.armSerial+=1
        S.armed=nil
        S.lastStatus=tostring(reason or "candidate-cleared")
    end

    local function startFallback(armed)
        if type(armed)~="table"
            or type(armed.snapshot)~="table"
            or not armed.before
        then
            return false
        end

        local snap=armed.snapshot
        local id=tostring(snap.id or "")
        if id=="" or S.completedSeen[id] or S.fallbackStarted[id] then
            return false
        end

        local delta,useful=completionLogic.expectedDelta(snap)
        if type(delta)~="table" or useful~=true then
            S.lastStatus="fallback-unavailable"
            return false
        end

        S.fallbackStarted[id]=true

        task.spawn(function()
            local deadline=os.clock()+15

            while alive()
                and not S.completedSeen[id]
                and os.clock()<deadline
            do
                task.wait(0.25)

                local after=ownCounts(4.0)
                if after then
                    local matched=completionLogic.deltaMatches(
                        armed.before,
                        after,
                        delta
                    )

                    if matched then
                        completeTrade(
                            snap,
                            "inventory-verified-fallback",
                            armed
                        )
                        return
                    end
                end
            end

            if alive() and not S.completedSeen[id] then
                S.lastStatus="fallback-unverified"
                warn(
                    "[PDIDDLER WEBHOOK] trade closed but completion could not be verified; no webhook sent"
                )
            end
        end)

        return true
    end

    local tradeFolder=RS:FindFirstChild("Trade")
    local AcceptTrade=tradeFolder and tradeFolder:FindFirstChild("AcceptTrade")
    local DeclineTrade=tradeFolder and tradeFolder:FindFirstChild("DeclineTrade")

    local conns={}

    if AcceptTrade and AcceptTrade:IsA("RemoteEvent") then
        conns[#conns+1]=AcceptTrade.OnClientEvent:Connect(function(complete)
            if not alive() or complete~=true then return end

            local armed=S.armed
            if not armed or type(armed.snapshot)~="table" then
                S.lastStatus="server-complete-without-snapshot"
                warn("[PDIDDLER WEBHOOK] server completion arrived without a verified trade snapshot")
                return
            end

            local age=os.clock()-(tonumber(armed.seenAt) or 0)
            if age>3.0 then
                S.lastStatus="server-complete-stale-snapshot"
                warn("[PDIDDLER WEBHOOK] server completion snapshot was stale; no webhook sent")
                return
            end

            completeTrade(armed.snapshot,"server-complete",armed)
        end)
    else
        warn("[PDIDDLER WEBHOOK] AcceptTrade completion event unavailable; inventory fallback only")
    end

    if DeclineTrade and DeclineTrade:IsA("RemoteEvent") then
        conns[#conns+1]=DeclineTrade.OnClientEvent:Connect(function()
            if not alive() then return end
            clearArmed("declined")
        end)
    end

    task.spawn(function()
        print("[PDIDDLER WEBHOOK] ARMED | completion observer active | URL kept external")

        local wasActive=false

        while alive() do
            local active=part4Controller.state.active==true
            local candidate=part4Controller.state.webhookCandidate
            local reason=tostring(part4Controller.state.webhookReason or "")

            if type(candidate)=="table" and candidate.verified==true then
                armCandidate(candidate)
            elseif active then
                if reason~="trade-closed" and reason~="part4-stopped" then
                    clearArmed(reason~="" and reason or "candidate-invalid")
                end
            end

            if wasActive and not active then
                local closedArmed=S.armed
                if closedArmed then
                    startFallback(closedArmed)
                end
            end

            wasActive=active
            task.wait(0.12)
        end
    end)

    return {
        session=SESSION,
        state=S,
        stop=function()
            if ENV.PDIDDLER_WEBHOOK_SESSION==SESSION then
                ENV.PDIDDLER_WEBHOOK_SESSION=SESSION+1
            end

            for _,c in ipairs(conns) do
                pcall(function() c:Disconnect() end)
            end
        end,
    }
end

return M
