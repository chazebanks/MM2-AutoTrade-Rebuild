-- pdiddler Part 4 active-trade controller v1
-- Implements:
--   * opening offer = exactly 1 highest-valued known eligible own item
--   * accepted-empty = immediate decline
--   * empty/no-action = decline after 15 seconds
--   * non-empty offer = stabilized balanced-aggressive planner
--   * hold profitable overpays; rebalance only when our current side is not valid
--   * unresolved data = WAIT, never guess
--   * trade close/decline returns control to Part 3
--
-- SAFETY: FINAL ITEM-TRADE ACCEPT IS NOT IMPLEMENTED.

local M={}

function M.run(scanner,outgoing,io,market,planner)
    for _,pair in ipairs({
        {"scanner",scanner},
        {"outgoing",outgoing},
        {"io",io},
        {"market",market},
        {"planner",planner},
    }) do
        if type(pair[2])~="table" then
            error("[PDIDDLER P4] "..pair[1].." module missing")
        end
    end

    for _,name in ipairs({
        "getRecord",
        "getOwnInventory",
        "setStatus",
        "setRequestState",
    }) do
        if type(scanner[name])~="function" then
            error("[PDIDDLER P4] scanner missing "..name)
        end
    end

    if type(outgoing.resume)~="function" then
        error("[PDIDDLER P4] resumable Part 3 bridge missing")
    end

    local Players=game:GetService("Players")
    local LP=Players.LocalPlayer
    local ENV=(getgenv and getgenv()) or _G

    ENV.PDIDDLER_PART4_SESSION=
        (tonumber(ENV.PDIDDLER_PART4_SESSION) or 0)+1

    local SESSION=ENV.PDIDDLER_PART4_SESSION

    local C={
        TradeOpenSettle=0.30,
        OpeningVerifyTimeout=3.0,
        EmptyTimeout=15.0,
        OfferStabilize=0.65,
        RemoveVerifyTimeout=0.85,
        PlanVerifyTimeout=2.5,
        LoopDelay=0.08,
        RetryDataDelay=0.45,
    }

    local S={
        active=false,
        tradeSerial=0,
        partner=nil,
        phase="ARMED",
        result=nil,
        stopped=false,
    }

    local function alive()
        return not S.stopped
            and ENV.PDIDDLER_PART4_SESSION==SESSION
    end

    local function fmt(v)
        v=tonumber(v) or 0

        if math.abs(v-math.floor(v))<0.0001 then
            return tostring(math.floor(v))
        end

        return string.format("%.2f",v)
    end

    local function highestOwn(inv)
        local best=nil

        for _,it in ipairs((inv and inv.items) or {}) do
            local qty=tonumber(it.qty) or 0
            local value=tonumber(it.value)

            if qty>0
                and value
                and value>0
                and it.id
                and tostring(it.id)~=""
            then
                if not best
                    or value>(tonumber(best.value) or 0)
                    or (
                        value==(tonumber(best.value) or 0)
                        and tostring(it.id)<tostring(best.id)
                    )
                then
                    best=it
                end
            end
        end

        return best
    end

    local function targetInventory(target)
        local rec=target and scanner.getRecord(target.UserId)

        if rec
            and rec.state=="whitelist"
            and rec.inv
        then
            return rec.inv
        end

        return nil
    end

    local function state(target,stateName,detail)
        if target and target.Parent==Players then
            scanner.setRequestState(
                target,
                stateName,
                "P4 | "..tostring(detail or "")
            )
        end

        scanner.setStatus(
            "P4 — "..tostring(detail or "")
        )
    end

    local function counts(items)
        local out={}
        local units=0

        for _,it in ipairs(items or {}) do
            local id=tostring(it.id)
            local qty=math.max(1,tonumber(it.qty) or 1)

            out[id]=(out[id] or 0)+qty
            units+=qty
        end

        return out,units
    end

    local function planMatches(plan,resolved)
        if not plan
            or not resolved
            or #((resolved and resolved.unresolved) or {})>0
        then
            return false
        end

        local a,au=counts(plan.items)
        local b,bu=counts(resolved.items)

        if au~=bu then
            return false
        end

        for id,qty in pairs(a) do
            if (b[id] or 0)~=qty then
                return false
            end
        end

        for id,qty in pairs(b) do
            if (a[id] or 0)~=qty then
                return false
            end
        end

        return true
    end

    local function ensureSamePartner(t,target)
        if not t or not target or target.Parent~=Players then
            return false
        end

        local p=io.partnerPlayer(t)

        return p==target
    end

    local function resumePart3(reason)
        local deadline=os.clock()+2.5

        while alive()
            and io.trade()
            and os.clock()<deadline
        do
            task.wait(0.08)
        end

        if not alive() then
            return false
        end

        local ok,why=outgoing.resume(reason)

        print(
            "[PDIDDLER P4] RETURN TO P3",
            tostring(reason or ""),
            tostring(ok),
            tostring(why)
        )

        return ok
    end

    local function declineAndReturn(target,reason,detail)
        if not alive() then return false end

        S.phase="DECLINING"

        state(
            target,
            "declined",
            detail or ("Declining | "..tostring(reason))
        )

        local closed=io.decline(reason)

        if closed then
            S.result=reason
            resumePart3(reason)
        else
            state(
                target,
                "sendfailed",
                "Decline attempted but trade remained open | final Accept still locked"
            )
        end

        return closed
    end

    local function clearOurOffer(target,expectedTheirSig)
        for _=1,8 do
            if not alive() then
                return false,"stale-session"
            end

            local t=io.trade()

            if not t then
                return false,"trade-closed"
            end

            if not ensureSamePartner(t,target) then
                return false,"partner-changed"
            end

            local their=io.readSide(t,"TheirOffer")

            if io.sideSignature(their)~=expectedTheirSig then
                return false,"their-offer-changed"
            end

            local ours=io.readSide(t,"YourOffer")

            if ours.slots==0 then
                return true,"cleared"
            end

            local before=io.sideSignature(ours)
            local beforeSlots=ours.slots
            local clicked,why=io.removeOne(t)

            if not clicked then
                return false,"remove-failed:"..tostring(why)
            end

            local deadline=os.clock()+C.RemoveVerifyTimeout
            local changed=false

            while alive() and os.clock()<deadline do
                local now=io.trade()

                if not now then
                    return false,"trade-closed"
                end

                if not ensureSamePartner(now,target) then
                    return false,"partner-changed"
                end

                local nowTheir=io.readSide(now,"TheirOffer")

                if io.sideSignature(nowTheir)~=expectedTheirSig then
                    return false,"their-offer-changed"
                end

                local nowOurs=io.readSide(now,"YourOffer")

                if nowOurs.slots<beforeSlots
                    or io.sideSignature(nowOurs)~=before
                then
                    changed=true
                    break
                end

                task.wait(0.06)
            end

            if not changed then
                return false,"remove-verify-timeout"
            end

            task.wait(0.06)
        end

        local t=io.trade()
        local ours=t and io.readSide(t,"YourOffer")

        return ours and ours.slots==0 or false,"clear-timeout"
    end

    local function addPlan(target,plan,expectedTheirSig)
        for _,it in ipairs(plan.items or {}) do
            for _=1,math.max(1,tonumber(it.qty) or 1) do
                if not alive() then
                    return false,"stale-session"
                end

                local t=io.trade()

                if not t then
                    return false,"trade-closed"
                end

                if not ensureSamePartner(t,target) then
                    return false,"partner-changed"
                end

                local their=io.readSide(t,"TheirOffer")

                if io.sideSignature(their)~=expectedTheirSig then
                    return false,"their-offer-changed"
                end

                local ok,why=io.offerItem(it)

                if not ok then
                    return false,"offer-failed:"..tostring(why)
                end

                task.wait(0.15)
            end
        end

        return true,"added"
    end

    local function applyPlan(target,plan,expectedTheirSig,ownInv)
        local cleared,why=clearOurOffer(
            target,
            expectedTheirSig
        )

        if not cleared then
            return false,why
        end

        local t=io.trade()

        if not t then
            return false,"trade-closed"
        end

        local their=io.readSide(t,"TheirOffer")

        if io.sideSignature(their)~=expectedTheirSig then
            return false,"their-offer-changed"
        end

        local added,addWhy=addPlan(
            target,
            plan,
            expectedTheirSig
        )

        if not added then
            return false,addWhy
        end

        local deadline=os.clock()+C.PlanVerifyTimeout

        while alive() and os.clock()<deadline do
            local now=io.trade()

            if not now then
                return false,"trade-closed"
            end

            if not ensureSamePartner(now,target) then
                return false,"partner-changed"
            end

            local nowTheir=io.readSide(now,"TheirOffer")

            if io.sideSignature(nowTheir)~=expectedTheirSig then
                return false,"their-offer-changed"
            end

            local oursSide=io.readSide(now,"YourOffer")
            local oursResolved=io.resolveSide(
                oursSide,
                ownInv
            )

            if planMatches(plan,oursResolved) then
                return true,oursResolved
            end

            task.wait(0.08)
        end

        return false,"plan-verify-timeout"
    end

    local function offerOpening(target)
        local ownInv,why=scanner.getOwnInventory()

        if not ownInv then
            return false,"own-inventory:"..tostring(why)
        end

        local highest=highestOwn(ownInv)

        if not highest then
            return false,"no-valued-eligible-own-item"
        end

        local t=io.trade()

        if not t or not ensureSamePartner(t,target) then
            return false,"trade/partner-lost"
        end

        local ours=io.readSide(t,"YourOffer")

        if ours.slots>0 then
            return false,"our-offer-not-empty-at-start"
        end

        state(
            target,
            "sending",
            string.format(
                "Opening with highest item: %s (%s) | exactly 1 copy | final Accept locked",
                tostring(highest.name),
                fmt(highest.value)
            )
        )

        local ok,fireWhy=io.offerItem(highest)

        if not ok then
            return false,"opening-offer:"..tostring(fireWhy)
        end

        local deadline=os.clock()+C.OpeningVerifyTimeout

        while alive() and os.clock()<deadline do
            local now=io.trade()

            if not now then
                return false,"trade-closed-during-opening"
            end

            if not ensureSamePartner(now,target) then
                return false,"partner-changed"
            end

            local found,proof=io.ourOfferContains(
                now,
                highest
            )

            if found then
                print(
                    "[PDIDDLER P4] OPENING VERIFIED",
                    target.Name,
                    tostring(highest.name),
                    tostring(highest.value),
                    tostring(proof),
                    "| FINAL ACCEPT LOCKED"
                )

                return true,{
                    item=highest,
                    ownInv=ownInv,
                    proof=proof,
                }
            end

            task.wait(0.08)
        end

        -- Never blindly retry OfferItem here. A delayed first call could
        -- otherwise create a duplicate stack.
        return false,"opening-not-visible"
    end

    local function runTrade(target,serial)
        S.active=true
        S.partner=target
        S.phase="OPENING"

        local openingOk,opening=offerOpening(target)

        if not openingOk then
            state(
                target,
                "sendfailed",
                "P4 opening failed: "..tostring(opening)
                .." | declining safely"
            )

            declineAndReturn(
                target,
                "p4-opening-failed",
                "Opening offer could not be verified | declining safely"
            )

            S.active=false
            return
        end

        local emptySince=nil
        local lastTheirSig=nil
        local lastTheirChangeAt=0
        local lastEvaluatedComposite=nil
        local lastStatusSecond=nil

        S.phase="WAITING"

        while alive()
            and S.tradeSerial==serial
        do
            local t=io.trade()

            if not t then
                S.result="trade-closed"
                S.active=false
                resumePart3("trade-closed")
                return
            end

            if not ensureSamePartner(t,target) then
                declineAndReturn(
                    target,
                    "partner-changed",
                    "Partner verification changed | declining stale trade"
                )

                S.active=false
                return
            end

            local theirSide=io.readSide(t,"TheirOffer")
            local theirSig=io.sideSignature(theirSide)
            local theirAccepted,acceptedVia=io.acceptedTheir(t)

            if theirSide.slots==0 then
                lastTheirSig=nil
                lastTheirChangeAt=0
                lastEvaluatedComposite=nil

                if theirAccepted then
                    print(
                        "[PDIDDLER P4] ACCEPTED EMPTY",
                        target.Name,
                        tostring(acceptedVia)
                    )

                    declineAndReturn(
                        target,
                        "accepted-empty",
                        "They accepted with ZERO offered items | immediate decline"
                    )

                    S.active=false
                    return
                end

                if not emptySince then
                    emptySince=os.clock()
                end

                local elapsed=os.clock()-emptySince
                local sec=math.floor(elapsed)

                if sec~=lastStatusSecond then
                    lastStatusSecond=sec

                    state(
                        target,
                        "ignored",
                        string.format(
                            "Their offer empty | %.1fs / 15s | waiting before decline",
                            math.min(C.EmptyTimeout,elapsed)
                        )
                    )
                end

                if elapsed>=C.EmptyTimeout then
                    -- Exact final recheck prevents a last-moment item from
                    -- being declined by an expired timer.
                    task.wait(0.08)

                    local finalTrade=io.trade()
                    local finalSide=finalTrade
                        and io.readSide(finalTrade,"TheirOffer")
                    local finalAccepted=finalTrade
                        and select(1,io.acceptedTheir(finalTrade))

                    if finalTrade
                        and finalSide
                        and finalSide.slots==0
                        and not finalAccepted
                    then
                        declineAndReturn(
                            target,
                            "empty-15s",
                            "No item offered for 15s | declining trade"
                        )

                        S.active=false
                        return
                    end

                    emptySince=nil
                end

                task.wait(C.LoopDelay)
                continue
            end

            emptySince=nil
            lastStatusSecond=nil

            if theirSig~=lastTheirSig then
                lastTheirSig=theirSig
                lastTheirChangeAt=os.clock()
                lastEvaluatedComposite=nil

                state(
                    target,
                    "sending",
                    "Their offer changed | waiting "
                    ..tostring(C.OfferStabilize)
                    .."s to stabilize"
                )

                task.wait(C.LoopDelay)
                continue
            end

            if os.clock()-lastTheirChangeAt<C.OfferStabilize then
                task.wait(C.LoopDelay)
                continue
            end

            local oursSide=io.readSide(t,"YourOffer")
            local composite=
                theirSig
                .."||"
                ..io.sideSignature(oursSide)

            if composite==lastEvaluatedComposite then
                if theirAccepted then
                    scanner.setStatus(
                        "P4 — they accepted current non-empty offer | FINAL ACCEPT LOCKED"
                    )
                end

                task.wait(C.LoopDelay)
                continue
            end

            local partnerInv=targetInventory(target)

            if not partnerInv then
                state(
                    target,
                    "ignored",
                    "Partner inventory unavailable/stale | waiting; no guessing"
                )

                task.wait(C.RetryDataDelay)
                continue
            end

            local theirResolved=io.resolveSide(
                theirSide,
                partnerInv
            )

            if #theirResolved.unresolved>0
                or theirResolved.units<=0
            then
                state(
                    target,
                    "ignored",
                    "Their offered item identity/value unresolved | waiting; no rebalance"
                )

                -- Do not cache this as evaluated. A scanner refresh can make
                -- the exact same visible offer resolvable later.
                task.wait(C.RetryDataDelay)
                continue
            end

            local ownInv,ownWhy=scanner.getOwnInventory()

            if not ownInv then
                state(
                    target,
                    "ignored",
                    "Own inventory refresh failed: "
                    ..tostring(ownWhy)
                    .." | retrying"
                )

                task.wait(C.RetryDataDelay)
                continue
            end

            local ourResolved=io.resolveSide(
                oursSide,
                ownInv
            )

            if #ourResolved.unresolved>0 then
                state(
                    target,
                    "ignored",
                    "Our live offer could not be resolved exactly | waiting; no blind edits"
                )

                task.wait(C.RetryDataDelay)
                continue
            end

            -- Zero units is allowed here. It can legitimately happen if the
            -- opponent changes their offer while we are clearing ours. The
            -- planner must be allowed to rebuild from an empty side instead
            -- of leaving the trade permanently stuck.

            local decision=planner.choose(
                market,
                ownInv,
                theirResolved.items,
                ourResolved.items
            )

            local ev=decision.evaluation

            if decision.action=="hold" then
                S.phase="PROFITABLE"
                lastEvaluatedComposite=composite

                state(
                    target,
                    "accepted",
                    string.format(
                        "PROFITABLE HOLD | %s | OUR %s / THEIR %s | raw %+s | effective %+s | required raw %s | final Accept LOCKED%s",
                        tostring(ev.kind),
                        fmt(ev.ours.raw),
                        fmt(ev.theirs.raw),
                        fmt(ev.rawProfit),
                        fmt(ev.effectiveProfit),
                        fmt(ev.rawRequired),
                        theirAccepted and " | THEY ACCEPTED" or ""
                    )
                )

                print(
                    "[PDIDDLER P4] HOLD",
                    target.Name,
                    ev.kind,
                    "ours",fmt(ev.ours.raw),
                    "theirs",fmt(ev.theirs.raw),
                    "profit",fmt(ev.rawProfit),
                    "effective",fmt(ev.effectiveProfit),
                    "| ACCEPT LOCKED"
                )

                task.wait(C.LoopDelay)
                continue
            end

            if decision.action=="wait" then
                S.phase="UNDERPAY"
                lastEvaluatedComposite=composite

                state(
                    target,
                    "ignored",
                    string.format(
                        "UNDERPAY / NO SAFE PLAN | OUR %s / THEIR %s | raw %+s | need >=%s | waiting for them to improve",
                        fmt(ev.ours.raw),
                        fmt(ev.theirs.raw),
                        fmt(ev.rawProfit),
                        fmt(ev.rawRequired)
                    )
                )

                print(
                    "[PDIDDLER P4] WAIT",
                    target.Name,
                    tostring(decision.reason),
                    "ours",fmt(ev.ours.raw),
                    "theirs",fmt(ev.theirs.raw)
                )

                task.wait(C.LoopDelay)
                continue
            end

            if decision.action=="replace"
                and decision.plan
            then
                S.phase="BALANCING"

                state(
                    target,
                    "sending",
                    string.format(
                        "BALANCING | plan: %s | projected OUR %s / THEIR %s | projected raw %+s",
                        planner.planText(decision.plan),
                        fmt(decision.plan.evaluation.ours.raw),
                        fmt(decision.plan.evaluation.theirs.raw),
                        fmt(decision.plan.evaluation.rawProfit)
                    )
                )

                local applied,applyWhy=applyPlan(
                    target,
                    decision.plan,
                    theirSig,
                    ownInv
                )

                if not applied then
                    print(
                        "[PDIDDLER P4] REBALANCE INTERRUPTED",
                        target.Name,
                        tostring(applyWhy)
                    )

                    lastEvaluatedComposite=nil

                    if applyWhy=="trade-closed" then
                        S.active=false
                        resumePart3("trade-closed-during-balance")
                        return
                    end

                    task.wait(C.LoopDelay)
                    continue
                end

                local now=io.trade()

                if not now then
                    S.active=false
                    resumePart3("trade-closed-after-balance")
                    return
                end

                local finalTheir=io.readSide(
                    now,
                    "TheirOffer"
                )

                if io.sideSignature(finalTheir)~=theirSig then
                    lastEvaluatedComposite=nil
                    task.wait(C.LoopDelay)
                    continue
                end

                local finalOurs=io.readSide(
                    now,
                    "YourOffer"
                )

                local finalOurResolved=io.resolveSide(
                    finalOurs,
                    ownInv
                )

                local finalDecision=planner.evaluate(
                    market,
                    finalOurResolved.items,
                    theirResolved.items
                )

                if not finalDecision.valid then
                    state(
                        target,
                        "sendfailed",
                        "Rebalance verification did not satisfy threshold | ACCEPT locked | re-evaluating"
                    )

                    lastEvaluatedComposite=nil
                    task.wait(C.LoopDelay)
                    continue
                end

                lastEvaluatedComposite=
                    theirSig
                    .."||"
                    ..io.sideSignature(finalOurs)

                state(
                    target,
                    "accepted",
                    string.format(
                        "REBALANCED PROFITABLE | %s | OUR %s / THEIR %s | raw %+s | effective %+s | final Accept LOCKED",
                        tostring(finalDecision.kind),
                        fmt(finalDecision.ours.raw),
                        fmt(finalDecision.theirs.raw),
                        fmt(finalDecision.rawProfit),
                        fmt(finalDecision.effectiveProfit)
                    )
                )

                print(
                    "[PDIDDLER P4] REBALANCE VERIFIED",
                    target.Name,
                    planner.planText(decision.plan),
                    "profit",fmt(finalDecision.rawProfit),
                    "| ACCEPT LOCKED"
                )

                task.wait(C.LoopDelay)
                continue
            end

            lastEvaluatedComposite=composite
            task.wait(C.LoopDelay)
        end

        S.active=false
    end

    task.spawn(function()
        print(
            "[PDIDDLER P4] ARMED",
            "session",SESSION,
            "| final Accept disabled"
        )

        local seenAt=nil
        local hadTrade=false

        while alive() do
            local t=io.trade()

            if t then
                hadTrade=true

                if not seenAt then
                    seenAt=os.clock()
                end

                if not S.active
                    and os.clock()-seenAt>=C.TradeOpenSettle
                then
                    local target=io.partnerPlayer(t)

                    if not target then
                        scanner.setStatus(
                            "P4 — trade open but partner unresolved | no item action"
                        )
                    else
                        local rec=scanner.getRecord(target.UserId)

                        if not rec
                            or rec.state~="whitelist"
                            or not rec.inv
                        then
                            -- Lock the controller while the safety decline is
                            -- running so the watcher cannot send duplicates.
                            S.active=true

                            declineAndReturn(
                                target,
                                "partner-not-whitelisted",
                                "Active trade partner lacks verified whitelist inventory | declining"
                            )

                            S.active=false
                        else
                            S.tradeSerial+=1
                            local serial=S.tradeSerial

                            -- Claim the trade BEFORE spawning runTrade. Without
                            -- this guard, two watcher iterations could create
                            -- duplicate opening-offer workers.
                            S.active=true

                            task.spawn(function()
                                runTrade(target,serial)
                            end)
                        end
                    end
                end
            else
                seenAt=nil

                if hadTrade and S.active then
                    S.active=false
                    resumePart3("trade-closed")
                end

                hadTrade=false
            end

            task.wait(C.LoopDelay)
        end
    end)

    return {
        session=SESSION,
        state=S,
        stop=function()
            S.stopped=true

            if ENV.PDIDDLER_PART4_SESSION==SESSION then
                ENV.PDIDDLER_PART4_SESSION=SESSION+1
            end
        end,
    }
end

return M
