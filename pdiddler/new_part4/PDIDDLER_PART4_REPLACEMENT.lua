-- Project Gingerscope replacement Part 4 — OBSERVATION-ONLY CUTOVER CANDIDATE.
-- The V15.8 balancer is NOT loaded, called or imported by this module.
-- No legacy +15, opening-offer, concession, rebalance, Accept or Decline.
-- Uses existing Stage 9/15 native observation; only reads GUI and scanner cache.
-- FAIL CLOSED: cannot approve any trade or physical mutation.
local M={}
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PIN="1971b93d324f0275e6a9affb472ac3e804439ed8"
local PLACEMENT_PIN="8b51d5f631a92b3e376fb6cf94d8048bb8e777a1"
local STRATEGY_PIN="67be6413abc03efff1f1661b07d642881460f87b"
local REVIEW_PIN="b8618226a983088d00bc52afa8b666a87aba67b9"
local function readModule(name,dependency)
    local pin=(name=="p4_strategy_permit") and STRATEGY_PIN
        or (name=="p4_dual_perspective") and REVIEW_PIN
        or (name=="p4_offer_executor" or name=="p4_native_offer")
        and PLACEMENT_PIN or PIN
    local src=game:HttpGet(ROOT..pin.."/pdiddler/new_part4/"..name..".lua",true)
    assert(type(src)=="string" and #src>10,"replacement observer source unavailable")
    local fn,why=loadstring(src,"="..name)
    assert(fn,why)
    local module=fn(dependency)
    assert(type(module)=="table","replacement observer module invalid")
    return module
end
local function visible(node)
    while node do
        if node:IsA("ScreenGui") and node.Enabled~=true then return false end
        if node:IsA("GuiObject") and node.Visible~=true then return false end
        node=node.Parent
    end
    return true
end
local function rootOf(player)
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local gui=pg:FindFirstChild(name)
        local box=gui and gui:FindFirstChild("Container")
        local t=box and box:FindFirstChild("Trade")
        if t and visible(t) then return t end
    end
    return nil
end
local function partnerOf(root,players,localPlayer)
    local side=root and root:FindFirstChild("TheirOffer")
    local username=side and side:FindFirstChild("Username")
    local shown=username and tostring(username.Text or "") or ""
    shown=shown:match("^%s*%((.-)%)%s*$") or shown
    shown=shown:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
    if shown=="" then return nil end
    for _,p in ipairs(players:GetPlayers()) do
        if p~=localPlayer and tostring(p.Name):lower()==shown:lower() then return p end
    end
    return nil
end
function M.run(scanner,profile,placement)
    assert(type(scanner)=="table" and type(scanner.getRecord)=="function"
        and type(scanner.getOwnInventory)=="function"
        and type(scanner.claimStatusOwner)=="function"
        and type(scanner.releaseStatusOwner)=="function","Part3 scanner API unavailable")
    assert(type(profile)=="table" and type(profile.isFresh)=="function","profile required")
    local E=(getgenv and getgenv()) or _G
    -- Never supersede the old Part 4 or another replacement during a session.
    assert(E.PDIDDLER_PART4_SESSION==nil and E.PDIDDLER_PART4_CONTROLLER==nil,
        "Part4 already owned; fresh rejoin required")
    local players=game:GetService("Players")
    local lp=players.LocalPlayer
    assert(lp,"LocalPlayer unavailable")
    local contract=readModule("p4_observer_contract")
    local native=readModule("p4_native_observer")
    -- The normal bootstrap passes NO placement capability. This branch has
    -- no native economic authorization; only a separately injected, tested
    -- source-backed permit validator may enable a one-shot ADD in a lab.
    local placementEnabled=type(placement)=="table" and placement.enabled==true
    local offerCore,offerNative,strategyModule,strategyReview
    local recoveryModules
    if placementEnabled then
        assert(type(placement.validatePermit)=="function"
            and type(placement.nextProposal)=="function"
            and type(placement.sendOnce)=="function",
            "verified placement callbacks missing")
        offerCore=readModule("p4_offer_executor")
        offerNative=readModule("p4_native_offer")
        if type(placement.strategy)=="table" then
            local stage16=readModule("p4_risk_review")
            strategyReview=readModule("p4_dual_perspective",stage16)
            strategyModule=readModule("p4_strategy_permit")
        end
        if type(placement.recovery)=="table" and placement.recovery.enabled==true then
            assert(type(placement.recovery.clickOnce)=="function",
                "recovery removal requires independently verified native click")
            recoveryModules={
                coordinator=readModule("p4_coordinator"),
                safety=readModule("p4_safety_core"),
                executor=readModule("p4_removal_executor"),
                native=readModule("p4_native_removal"),
                stability=readModule("p4_stability_gate")}
        end
    end
    local session=1
    E.PDIDDLER_PART4_SESSION=session
    local S={active=false,mode=placementEnabled and "INJECTED_ONE_SHOT_TEST" or "READ_ONLY",
        tradesSeen=0,placementStatus="NOT_ENABLED",
        recoveryStatus="NOT_ENABLED",
        lastReason="initialized",lastObservation=nil,quoteSafe=false,
        authorizesTrade=false,authorizesAccept=false}
    local controller={kind="gingerscope-replacement-observer",session=session,
        jobId=game.JobId,state=S}
    local running=true
    local handle=nil
    local offerState,offerHandle=nil,nil
    local strategyState,recoveryState,recoveryLatched,verifiedOffer=nil,nil,false,nil
    local boundRoot=nil
    local function release()
        if strategyState and strategyModule then pcall(strategyModule.stop,strategyState) end
        strategyState=nil;recoveryState=nil;recoveryLatched=false;verifiedOffer=nil
        if offerHandle and offerNative then pcall(offerNative.close,offerHandle) end
        if offerState and offerCore then pcall(offerCore.stop,offerState) end
        offerState=nil;offerHandle=nil
        if handle then handle.closed=true end
        handle=nil
        if S.active then pcall(scanner.releaseStatusOwner,"P4") end
        S.active=false
        boundRoot=nil
        S.lastObservation=nil
    end
    local function alive()
        return running and game.JobId==controller.jobId
           and E.PDIDDLER_PART4_SESSION==session
           and E.PDIDDLER_PART4_CONTROLLER==controller
    end
    controller.isAlive=alive
    controller.stop=function()
        if not running then return end
        running=false
        release()
        if E.PDIDDLER_PART4_SESSION==session then
            E.PDIDDLER_PART4_SESSION=session+1
        end
    end
    E.PDIDDLER_PART4_CONTROLLER=controller
    task.spawn(function()
        while alive() do
            local root=rootOf(lp)
            if not root then
                if S.active then S.lastReason="trade-closed-not-completion" end
                release()
            else
                if root~=boundRoot then
                    release()
                    boundRoot=root
                    S.active=true
                    S.tradesSeen=S.tradesSeen+1
                    pcall(scanner.claimStatusOwner,"P4")
                    S.lastReason="new-trade;no-action-authorized"
                    local partner=partnerOf(root,players,lp)
                    local ownOK,own=pcall(scanner.getOwnInventory)
                    local record=partner and scanner.getRecord(partner.UserId)
                    local theirs=record and record.state=="whitelist" and record.inv
                    S.placementStatus="NOT_ENABLED"
                    S.recoveryStatus="NOT_ENABLED"
                    if partner and ownOK and type(own)=="table" and type(theirs)=="table" then
                        local okay,result=pcall(native.new,{
                            game=game,players=players,root=root,
                            session=tostring(session)..":"..tostring(S.tradesSeen),
                            jobId=game.JobId,partnerUserId=partner.UserId,
                            localUserId=lp.UserId,contract=contract,
                            ownInventory=own,opponentInventory=theirs,
                            marketFresh=function()
                                local ok,f=pcall(profile.isFresh)
                                return ok and f==true
                            end
                        })
                        if okay then
                            handle=result
                            if placementEnabled then
                                local strategyOK=true
                                if strategyModule then
                                    local config=placement.strategy
                                    local ok,instance=pcall(strategyModule.new,{
                                        session=result.config.session,
                                        reviewer=strategyReview,
                                        context=config.context,source=config.source,
                                        wall=config.wall,choose=config.choose,
                                        approve=config.approve})
                                    if ok then strategyState=instance
                                    else strategyOK=false end
                                end
                                local validator=placement.validatePermit
                                if strategyState then
                                    validator=function(p,o,t)
                                        return strategyModule.validate(strategyState,p,o,t)
                                    end
                                end
                                local okCore,core=pcall(offerCore.new,result.config.session,{
                                    validatePermit=validator})
                                local okNative,nativeHandle=pcall(offerNative.new,{
                                    observer=native,handle=result,
                                    session=result.config.session,
                                    ownInventory=own,sendOnce=placement.sendOnce})
                                if okCore and okNative and strategyOK then
                                    offerState=core;offerHandle=nativeHandle
                                    S.placementStatus="AWAIT_PERMITTED_PROPOSAL"
                                else
                                    S.placementStatus="PLACEMENT_BIND_FAILED"
                                end
                            end
                        else S.lastReason="observer-init-unverified" end
                    else
                        S.lastReason="scanner-or-partner-unverified"
                    end
                end
                if handle then
                    local ok,obs,diagnostics=pcall(native.capture,handle)
                    if ok and obs and obs.tradeOpen==true then
                        -- Never convert an observation into an action.
                        S.lastObservation={
                            session=obs.session,ourSig=obs.ourSig,
                            theirSig=obs.theirSig,contextOK=obs.contextOK,
                            ourSlots=obs.ourSlots,theirSlots=obs.theirSlots,
                            theirResolved=obs.theirResolved,
                            ourAccepted=obs.ourAccepted,
                            theirAccepted=obs.theirAccepted,
                            errors=diagnostics and diagnostics.errors or {}
                        }
                        S.lastReason=obs.contextOK and
                            "verified-layout;strategy-not-authorized" or
                            "trade-observation-unverified"
                        -- Latch recovery on unexpected offer/market/accepted
                        -- mutations after the first independently verified ADD.
                        if verifiedOffer and not recoveryLatched and
                            (obs.ourSig~=verifiedOffer.ourSig
                             or obs.theirSig~=verifiedOffer.theirSig
                             or obs.contextOK~=true or obs.marketFresh~=true
                             or obs.ourAccepted~=false
                             or obs.theirAccepted~=false) then
                            recoveryLatched=true
                            S.recoveryStatus="OFFER_CHANGED_AFTER_PROOF"
                        end
                        if offerState and offerHandle and not recoveryLatched
                           and (offerState.mode=="SENT" or offerState.mode=="IDLE") then
                            local now=os.clock()
                            if offerState.mode=="SENT" then
                                local result,why=offerCore.observe(offerState,obs,now)
                                S.placementStatus=tostring(result)..":"..tostring(why)
                                if result=="VERIFIED" then
                                    verifiedOffer={ourSig=obs.ourSig,theirSig=obs.theirSig}
                                elseif result=="ESCALATE" or result=="STOP" then
                                    recoveryLatched=true
                                    S.recoveryStatus="PLACEMENT_UNCERTAIN:"..tostring(why)
                                end
                            elseif obs.contextOK and obs.marketFresh
                                and obs.theirResolved and obs.ourAccepted==false
                                and obs.theirAccepted==false
                                and not verifiedOffer then
                                local okPlan,proposal
                                if strategyState then
                                    okPlan,proposal=pcall(strategyModule.next,
                                        strategyState,obs,diagnostics,now)
                                else
                                    okPlan,proposal=pcall(placement.nextProposal,
                                        obs,diagnostics)
                                end
                                if okPlan and type(proposal)=="table" then
                                    local kind,intent=offerCore.prepare(offerState,proposal,obs,now)
                                    if kind=="DISPATCH" then
                                        local receipt=offerNative.execute(offerHandle,intent)
                                        local status,why=offerCore.dispatched(
                                            offerState,intent,receipt,os.clock())
                                        S.placementStatus=tostring(status)..":"..tostring(why)
                                        if status=="ESCALATE" or status=="STOP" then
                                            recoveryLatched=true
                                            S.recoveryStatus="SEND_UNCERTAIN:"..tostring(why)
                                        end
                                    else
                                        S.placementStatus=tostring(kind)..":"..tostring(intent)
                                    end
                                elseif not okPlan then
                                    S.placementStatus="PROPOSAL_CALLBACK_FAILED"
                                end
                            end
                        end
                        if recoveryLatched then
                            if strategyState and strategyModule then
                                strategyModule.stop(strategyState)
                            end
                            if offerState then offerCore.stop(offerState) end
                            -- Reuse the existing Stages 8/10/11/14 safety
                            -- chain. No fallback native click is invented.
                            if not recoveryModules or not handle then
                                S.recoveryStatus="MANUAL_WITHDRAW_OR_DECLINE_REQUIRED"
                            else
                                if not recoveryState then
                                    local r=recoveryModules
                                    local okNew,session=pcall(function()
                                        local nativeHandle=r.native.new({
                                            observer=native,handle=handle,
                                            session=handle.config.session,
                                            clickOnce=placement.recovery.clickOnce})
                                        return r.coordinator.new({
                                            session=handle.config.session,
                                            clock=os.clock,observer=native,
                                            obsHandle=handle,safety=r.safety,
                                            executor=r.executor,native=r.native,
                                            stability=r.stability,
                                            nativeHandle=nativeHandle})
                                    end)
                                    if okNew then recoveryState=session
                                    else S.recoveryStatus="RECOVERY_BIND_FAILED" end
                                end
                                if recoveryState then
                                    local okTick,kind,reason=pcall(
                                        recoveryModules.coordinator.tick,recoveryState)
                                    if okTick then
                                        S.recoveryStatus=tostring(kind)..":"..tostring(reason)
                                    else
                                        S.recoveryStatus="RECOVERY_COORDINATOR_EXCEPTION"
                                        recoveryState=nil
                                    end
                                end
                            end
                        end
                    else
                        S.lastReason="native-trade-observation-unavailable"
                    end
                end
            end
            task.wait(0.12)
        end
        release()
    end)
    return controller
end
return M
