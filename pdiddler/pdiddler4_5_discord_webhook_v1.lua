-- pdiddler Part 4.5 Discord completed-trade webhook v1
-- FINAL ACCEPT remains disabled. This module only observes MM2 completion events.
-- It never fires AcceptTrade and never clicks Accept/Confirm.

local M={}

function M.run(scanner,part4Controller,marketProfile,marketLogic,tradeReport)
    assert(type(scanner)=="table" and type(scanner.getOwnInventory)=="function",
        "scanner.getOwnInventory required")
    assert(type(part4Controller)=="table"
        and type(part4Controller.state)=="table"
        and type(part4Controller.state.tradeAudit)=="table",
        "Part 4 tradeAudit bridge required")
    assert(type(marketProfile)=="table" and type(marketProfile.get)=="function",
        "market profile required")
    assert(type(marketLogic)=="table" and type(marketLogic.itemAssessment)=="function",
        "market logic required")
    assert(type(tradeReport)=="table"
        and type(tradeReport.build)=="function"
        and type(tradeReport.discordPayload)=="function",
        "trade report builder required")

    local RS=game:GetService("ReplicatedStorage")
    local HttpService=game:GetService("HttpService")
    local ENV=(getgenv and getgenv()) or _G

    local C={
        MaxAttempts=4,
        InventoryAttempts=7,
        InventoryRetryBase=0.18,
        SendRetryBase=0.60,
        CandidateMaxAge=8.0,
    }

    local SESSION=(tonumber(ENV.PDIDDLER_WEBHOOK_SESSION) or 0)+1
    ENV.PDIDDLER_WEBHOOK_SESSION=SESSION
    ENV.PDIDDLER_WEBHOOK_PENDING_COUNT=0

    local S={
        session=SESSION,
        pending=0,
        sentCount=0,
        failedCount=0,
        ignoredDuplicate=0,
        lastStatus="armed",
        lastTradeId=nil,
        deliveries={},
    }

    local function alive()
        return ENV.PDIDDLER_WEBHOOK_SESSION==SESSION
    end

    local function setPending(delta)
        S.pending=math.max(0,(tonumber(S.pending) or 0)+(tonumber(delta) or 0))
        ENV.PDIDDLER_WEBHOOK_PENDING_COUNT=S.pending
    end

    local function requestFunction()
        if type(request)=="function" then
            return request
        elseif type(http_request)=="function" then
            return http_request
        elseif type(syn)=="table" and type(syn.request)=="function" then
            return syn.request
        end
        return nil
    end

    local function webhookUrl()
        local url=tostring(ENV.PDIDDLER_DISCORD_WEBHOOK or "")
        if url=="" then return nil,"webhook-not-configured" end
        if not url:match("^https://") then return nil,"webhook-must-be-https" end

        local discordHost="discord"..".com"
        local legacyHost="discordapp"..".com"

        if not url:find(discordHost,1,true)
            and not url:find(legacyHost,1,true)
        then
            return nil,"webhook-host-not-discord"
        end

        if not url:find("/api/webhooks/",1,true) then
            return nil,"webhook-path-invalid"
        end

        return url,nil
    end

    local function responseCode(res)
        if type(res)~="table" then return nil end
        return tonumber(res.StatusCode or res.Status or res.status_code)
    end

    local function sendPayload(payload)
        local url,urlWhy=webhookUrl()
        if not url then return false,urlWhy end

        local req=requestFunction()
        if not req then return false,"http-request-function-unavailable" end

        local okJson,body=pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not okJson then return false,"json-encode-failed" end

        local lastWhy="no-response"

        for attempt=1,C.MaxAttempts do
            if not alive() then return false,"stale-webhook-session" end

            local ok,res=pcall(function()
                return req({
                    Url=url,
                    Method="POST",
                    Headers={
                        ["Content-Type"]="application/json",
                    },
                    Body=body,
                })
            end)

            if ok then
                local code=responseCode(res)
                if code and code>=200 and code<300 then
                    return true,"http-"..tostring(code)
                end
                lastWhy="http-"..tostring(code or "unknown")
            else
                lastWhy="request-error"
            end

            if attempt<C.MaxAttempts then
                task.wait(C.SendRetryBase*(2^(attempt-1)))
            end
        end

        return false,lastWhy
    end

    local function inventoryComplete(inv)
        return type(inv)=="table"
            and type(inv.items)=="table"
            and (tonumber(inv.unmapped) or 0)==0
            and (tonumber(inv.unpriced) or 0)==0
            and (tonumber(inv.badQty) or 0)==0
            and tonumber(inv.total)~=nil
    end

    local function refreshPostInventory(preInventory)
        local preFingerprint=tostring(
            type(preInventory)=="table" and preInventory.fingerprint or ""
        )
        local lastChanged=nil
        local lastFingerprint=nil
        local stableCount=0

        for attempt=1,C.InventoryAttempts do
            if not alive() then return nil,false,"stale-webhook-session" end

            local inv=scanner.getOwnInventory()

            if inventoryComplete(inv) then
                local fp=tostring(inv.fingerprint or "")

                if fp~=preFingerprint then
                    lastChanged=inv

                    if fp==lastFingerprint then
                        stableCount+=1
                    else
                        lastFingerprint=fp
                        stableCount=1
                    end

                    if stableCount>=2 then
                        return inv,true,"stable-post-inventory"
                    end
                end
            end

            if attempt<C.InventoryAttempts then
                task.wait(C.InventoryRetryBase*attempt)
            end
        end

        return lastChanged,false,
            lastChanged and "post-inventory-not-stable" or "post-inventory-not-observed"
    end

    local function cloneItems(items)
        local out={}
        for _,item in ipairs(type(items)=="table" and items or {}) do
            out[#out+1]={
                id=item.id,
                checkerId=item.checkerId,
                page=item.page,
                name=item.name,
                qty=item.qty,
                rawValue=item.rawValue,
                ineligible=item.ineligible==true,
            }
        end
        return out
    end

    local function cloneInventory(inv)
        if type(inv)~="table" then return nil end
        local out={
            total=inv.total,
            rawOwned=inv.rawOwned,
            unmapped=inv.unmapped,
            unpriced=inv.unpriced,
            badQty=inv.badQty,
            fingerprint=inv.fingerprint,
            items={},
        }
        for _,item in ipairs(inv.items or {}) do
            out.items[#out.items+1]={
                id=item.id,
                checkerId=item.checkerId,
                page=item.page,
                name=item.name,
                qty=item.qty,
                value=item.value,
            }
        end
        return out
    end

    local function currentCandidate()
        local audit=part4Controller.state.tradeAudit
        if type(audit)~="table" then return nil,"trade-audit-missing" end

        local c=audit.current or audit.lastCapture
        if type(c)~="table" then return nil,"trade-capture-missing" end

        local age=math.huge
        if tonumber(c.observedAt) then
            age=math.max(0,os.clock()-tonumber(c.observedAt))
        end
        if age>C.CandidateMaxAge then
            return nil,"trade-capture-stale"
        end

        return {
            part4Session=c.part4Session,
            tradeSerial=c.tradeSerial,
            targetUserId=c.targetUserId,
            partnerName=c.partnerName,
            observedAt=c.observedAt,
            ourSig=c.ourSig,
            theirSig=c.theirSig,
            gave=cloneItems(c.gave),
            received=cloneItems(c.received),
            preInventory=cloneInventory(c.preInventory),
            complete=c.complete==true,
        },nil
    end

    local function candidateKey(c)
        return table.concat({
            tostring(c and c.part4Session or ""),
            tostring(c and c.tradeSerial or ""),
            tostring(c and c.targetUserId or ""),
        },":")
    end

    local tradeFolder=RS:FindFirstChild("Trade")
    local acceptTrade=tradeFolder and tradeFolder:FindFirstChild("AcceptTrade")

    if not acceptTrade or not acceptTrade:IsA("RemoteEvent") then
        error("[PDIDDLER WEBHOOK] AcceptTrade completion event missing")
    end

    local function processCompletedTrade()
        local candidate,why=currentCandidate()
        if not candidate then
            S.failedCount+=1
            S.lastStatus="trade-completed-no-capture:"..tostring(why)
            warn("[PDIDDLER WEBHOOK] trade-completed but capture unavailable",tostring(why))
            return
        end

        local key=candidateKey(candidate)
        local prior=S.deliveries[key]

        if prior=="processing" or prior=="sent" then
            S.ignoredDuplicate+=1
            S.lastStatus="duplicate-completion-ignored"
            return
        end

        S.deliveries[key]="processing"
        setPending(1)

        candidate.tradeId=HttpService:GenerateGUID(false)
        candidate.completedAt=os.time()
        S.lastTradeId=candidate.tradeId
        S.lastStatus="trade-completed-processing"

        task.spawn(function()
            local postInventory,postStable,postWhy=
                refreshPostInventory(candidate.preInventory)

            if not postStable then
                postInventory=nil
            end

            local report=tradeReport.build(
                candidate,
                postInventory,
                marketProfile,
                marketLogic
            )

            local payload=tradeReport.discordPayload(report)
            local sent,sendWhy=sendPayload(payload)

            if sent then
                S.deliveries[key]="sent"
                S.sentCount+=1
                S.lastStatus="sent:"..tostring(sendWhy)
                print(
                    "[PDIDDLER WEBHOOK] SENT",
                    "| tradeId",candidate.tradeId,
                    "| partner",tostring(candidate.partnerName),
                    "| gain",tostring(report.gainMM2),
                    "| inventory",tostring(report.inventoryAfter and report.inventoryAfter.mm2Total),
                    "| post",tostring(postWhy)
                )
            else
                S.deliveries[key]="failed"
                S.failedCount+=1
                S.lastStatus="failed:"..tostring(sendWhy)
                warn(
                    "[PDIDDLER WEBHOOK] SEND FAILED",
                    "| tradeId",candidate.tradeId,
                    "| reason",tostring(sendWhy),
                    "| post",tostring(postWhy)
                )
            end

            setPending(-1)
        end)
    end

    local connection
    connection=acceptTrade.OnClientEvent:Connect(function(completed,items)
        if not alive() then return end

        if completed==false then
            S.lastStatus="opponent-accepted"
            return
        end

        if completed==true then
            processCompletedTrade()
            return
        end

        S.lastStatus="completion-event-unknown"
    end)

    print(
        "[PDIDDLER WEBHOOK] ARMED",
        "| completion event only",
        "| FINAL ACCEPT DISABLED",
        "| webhook configured",webhookUrl()~=nil
    )

    local function testWebhook()
        local payload={
            username="MM2 AutoTrade Audit",
            embeds={{
                title="MM2 Webhook Connection Test",
                description="Connection verified. This is a diagnostic only; no trade was completed.",
                fields={{
                    name="Status",
                    value="Discord sender path is reachable from this executor session.",
                    inline=false,
                }},
            }},
        }

        local ok,why=sendPayload(payload)

        if ok then
            S.lastStatus="test-sent:"..tostring(why)
            print("[PDIDDLER WEBHOOK] TEST SENT",tostring(why))
        else
            S.lastStatus="test-failed:"..tostring(why)
            warn("[PDIDDLER WEBHOOK] TEST FAILED",tostring(why))
        end

        return ok,why
    end

    return {
        session=SESSION,
        state=S,
        candidateKey=candidateKey,
        testWebhook=testWebhook,
        stop=function()
            if ENV.PDIDDLER_WEBHOOK_SESSION==SESSION then
                ENV.PDIDDLER_WEBHOOK_SESSION=SESSION+1
            end
            if connection then
                connection:Disconnect()
                connection=nil
            end
            S.pending=0
            ENV.PDIDDLER_WEBHOOK_PENDING_COUNT=0
            S.lastStatus="stopped"
        end,
    }
end

return M
