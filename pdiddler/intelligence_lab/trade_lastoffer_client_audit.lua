-- Research-only equality audit of the client's UpdateTrade.LastOffer field.
-- A historical MM2 client forwards this field to AcceptTrade, but no server
-- nonce, authenticated revision, event causality or settlement is established.
-- NO game, remote, GUI, network, offer, accept or Discord operation here.
local M = {}

local function finite(x)
    return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
local function text(x)
    return type(x)=="string" and #x>=1 and #x<=128 and not x:find("[%c]")
end
local function dense(t,max)
    if type(t)~="table" or getmetatable(t)~=nil then return false end
    local n=#t
    if n>max then return false end
    local count=0
    for k in pairs(t) do
        if type(k)~="number" or k~=math.floor(k) or k<1 or k>n then return false end
        count=count+1
    end
    return count==n
end
local function exact(t,names,count)
    if type(t)~="table" or getmetatable(t)~=nil then return false end
    local n=0
    for k in pairs(t) do
        if names[k]~=true then return false end
        n=n+1
    end
    return n==count
end
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local PLAYER={Player=true,Accepted=true,Offer=true}
local ROW={[1]=true,[2]=true,[3]=true}
local function offers(t)
    if not dense(t,4) then return nil end
    local copy={}
    for i,row in ipairs(t) do
        if not exact(row,ROW,3) or not text(row[1]) or
           not finite(row[2]) or row[2]~=math.floor(row[2]) or
           row[2]<1 or row[2]>1000000 or row[3]~="Weapons" then
            return nil
        end
        copy[i]={row[1],row[2],row[3]}
    end
    return copy
end
local function sameOffers(a,b)
    for side=1,2 do
        if #a[side]~=#b[side] then return false end
        for i=1,#a[side] do
            for k=1,3 do
                if a[side][i][k]~=b[side][i][k] then return false end
            end
        end
    end
    return true
end
local function validScope(c)
    return type(c)=="table" and text(c.session) and text(c.jobId)
       and c.root~=nil and c.localPlayer~=nil and c.partnerPlayer~=nil
       and not rawequal(c.localPlayer,c.partnerPlayer)
end
local function scopeSame(c,f)
    return validScope(c) and c.session==f.session and c.jobId==f.jobId
       and rawequal(c.root,f.root) and rawequal(c.localPlayer,f.localPlayer)
       and rawequal(c.partnerPlayer,f.partnerPlayer)
end
local function inspect(p,scope)
    if not exact(p,ROOT,4) or p.Locked~=false then return nil end
    local p1,p2=p.Player1,p.Player2
    if not exact(p1,PLAYER,3) or not exact(p2,PLAYER,3) or
       p1.Accepted~=false or p2.Accepted~=false then return nil end
    local correct=(rawequal(p1.Player,scope.localPlayer) and
                    rawequal(p2.Player,scope.partnerPlayer)) or
                  (rawequal(p2.Player,scope.localPlayer) and
                    rawequal(p1.Player,scope.partnerPlayer))
    if not correct then return nil end
    local o1,o2=offers(p1.Offer),offers(p2.Offer)
    if not o1 or not o2 then return nil end
    local token,kind=p.LastOffer,type(p.LastOffer)
    if kind=="number" then
        if not finite(token) or token<0 then return nil end
    elseif kind=="string" then
        if not text(token) then return nil end
    else
        return nil -- unknown tokens cannot be safely compared
    end
    -- Always orient private offers MAIN first, regardless of Player1/2 order.
    local oriented=rawequal(p1.Player,scope.localPlayer) and {o1,o2} or {o2,o1}
    return {kind=kind,token=token,offer=oriented}
end
local function result(status,reason,counts)
    return {
        schema="gingerscope-lastoffer-client-audit-v1",
        status=status,reason=reason,clientOnly=true,readOnly=true,
        observedClientCallbacks=counts.events,
        changedTokenAndOffer=counts.both,
        unchangedTokenChangedOffer=counts.reused,
        changedTokenUnchangedOffer=counts.tokenOnly,
        unchangedTokenUnchangedOffer=counts.same,
        lastOfferValueExposed=false,
        clientGuiCrossChecked=false,
        serverTradeRevisionProven=false,eventSessionAssociationProven=false,
        callbackCausalityProven=false,rawItemIdConfirmed=false,
        uniqueWeaponInstanceProven=false,serverCompletionProven=false,
        authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
        mayRecordCompletedTrade=false,mayReportProfit=false,
        maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
        tradeOutcome="UNKNOWN"
    }
end
function M.new(scope)
    if not validScope(scope) then return nil end
    local frozen={session=scope.session,jobId=scope.jobId,root=scope.root,
                  localPlayer=scope.localPlayer,partnerPlayer=scope.partnerPlayer}
    local counts={events=0,both=0,reused=0,tokenOnly=0,same=0}
    local last,lastAt,started,dead=nil,nil,nil,false
    local obj={}
    local function deny(why)
        dead=true;last=nil
        return result("INCONCLUSIVE",why,counts)
    end
    function obj.observe(current,p,at)
        if dead then return result("INCONCLUSIVE","AUDIT_TERMINATED",counts) end
        if not scopeSame(current,frozen) then return deny("CLIENT_LOCAL_SCOPE_CHANGED") end
        if not finite(at) or at<0 or (lastAt~=nil and at<=lastAt) then
            return deny("NONMONOTONIC_CLIENT_CLOCK")
        end
        if started~=nil and at-started>120 then return deny("CLIENT_WINDOW_EXPIRED") end
        if counts.events>=12 then return deny("CLIENT_EVENT_LIMIT_EXCEEDED") end
        local candidate=inspect(p,frozen)
        if not candidate then return deny("LASTOFFER_OR_TRADE_PACKET_UNVERIFIED") end
        started=started or at
        counts.events=counts.events+1
        lastAt=at
        if last==nil then
            last=candidate
            return result("CLIENT_LASTOFFER_FIRST_EVENT_UNATTRIBUTED",
                          "ARCHIVED_ACCEPT_ARGUMENT_NO_SERVER_NONCE_PROOF",counts)
        end
        local tok=(last.kind==candidate.kind and last.token==candidate.token)
        local off=sameOffers(last.offer,candidate.offer)
        local status
        if not tok and not off then
            counts.both=counts.both+1
            status="CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER"
        elseif tok and not off then
            counts.reused=counts.reused+1
            status="CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER"
        elseif not tok and off then
            counts.tokenOnly=counts.tokenOnly+1
            status="CLIENT_LASTOFFER_CHANGED_WITH_SAME_OFFER"
        else
            counts.same=counts.same+1
            status="CLIENT_LASTOFFER_UNCHANGED_WITH_SAME_OFFER"
        end
        last=candidate
        return result(status,"CLIENT_SEQUENCE_UNATTRIBUTED_NO_SERVER_REVISION",counts)
    end
    function obj.stop()
        dead=true;last=nil
        return result("STOPPED","OPERATOR_OR_CLIENT_SCOPE_STOPPED",counts)
    end
    return obj
end
return M
