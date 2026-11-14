-- Optional read-only Roblox TextChatService.MessageReceived adapter for S2.C6.
-- This subscribes ONLY to messages actually delivered to this client.
-- Requires current protected P3/P4 scope, original C3 researchContext(), and
-- TextSource.UserId; never infers speaker from display-name/PrefixText.
-- Does not SendAsync, Chat, FireServer, HttpGet, webhook or store message text.
local M={}
local PLACE=142823291
local function validId(n)
 return type(n)=="number" and n==math.floor(n) and n>0
end
local function denied(reason)
 return {status="BLOCKED",reason=reason,
   clientOnly=true,readOnly=true,authorizesChat=false,
   authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
   maySendDiscordWebhook=false,mayUseForStrategyLearning=false}
end
function M.new(config)
 if type(config)~="table" or type(config.core)~="table" or
    type(config.core.new)~="function" or config.game==nil or
    config.players==nil or config.textChatService==nil or
    type(config.bound)~="table" or
    type(config.marketBridge)~="table" or
    type(config.marketBridge.researchContext)~="function" or
    type(config.isOriginalTradeLeaseActive)~="function" or
    type(config.monotonicSeconds)~="function" or
    type(config.crosswalk)~="table" then
  return nil,"PASSIVE_ORIGINAL_CHAT_ADAPTER_DEPENDENCIES_MISSING" end
 local bound=config.bound
 if type(bound.jobId)~="string" or #bound.jobId<8 or
   type(bound.leaseId)~="string" or #bound.leaseId<8 or
   not validId(bound.localUserId) or not validId(bound.partnerUserId) or
   type(bound.mainUsername)~="string" or
   bound.mainUsername:match("^[%w_]+$")==nil then
  return nil,"ORIGINAL_TRADE_SCOPE_NOT_BOUND" end
 local last=nil
 local function validateActive()
  if config.game.PlaceId~=PLACE or tostring(config.game.JobId)~=bound.jobId then
   return nil,"ORIGINAL_MM2_JOB_CHANGED" end
  local own=config.players.LocalPlayer
  if not own or own.UserId~=bound.localUserId or
    own.Name~=bound.mainUsername then
   return nil,"ORIGINAL_MAIN_ACCOUNT_CHANGED" end
  local partner=config.players:GetPlayerByUserId(bound.partnerUserId)
  if not partner or partner.Parent~=config.players then
   return nil,"ORIGINAL_BOUND_PARTNER_LEFT" end
  local success,active=pcall(config.isOriginalTradeLeaseActive)
  if not success or active~=true then
   return nil,"ORIGINAL_TRADE_LEASE_INACTIVE" end
  local scoped={
    jobId=bound.jobId,leaseId=bound.leaseId,
    localUserId=bound.localUserId,partnerUserId=bound.partnerUserId,
    mainUsername=bound.mainUsername,
    mainDisplayName=own.DisplayName,
    tradeOpen=true,leaseActive=true,
    mainDisplayNameUnique=false,
  }
  -- Display names can be duplicated. Exact username remains authoritative.
  if type(own.DisplayName)=="string" and own.DisplayName~="" then
   local equalNames=0
   for _,player in ipairs(config.players:GetPlayers()) do
    if type(player.DisplayName)=="string" and
       player.DisplayName:lower()==own.DisplayName:lower() then
     equalNames+=1 end
    if player~=own and type(player.Name)=="string" and
       player.Name:lower()==own.DisplayName:lower() then
     equalNames+=1 end
   end
   scoped.mainDisplayNameUnique=equalNames==1
  end
  local ok,ctx=pcall(config.marketBridge.researchContext)
  if not ok or type(ctx)~="table" or
    ctx.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" then
   return nil,"C3_LOCAL_RESEARCH_CONTEXT_UNAVAILABLE" end
  scoped.clientOfferRevision=ctx.clientOfferRevision
  scoped.lastOurOfferChanged=false
  if type(config.getReviewedOwnOfferWitness)=="function" then
   local yes,w=pcall(config.getReviewedOwnOfferWitness)
   if yes and type(w)=="table" and
      w.kind=="REVIEWED_CLIENT_OUR_OFFER_REVISION" and
      w.jobId==bound.jobId and w.leaseId==bound.leaseId and
      w.clientOfferRevision==ctx.clientOfferRevision and
      type(w.monotonicTime)=="number" then
    scoped.lastOurOfferChanged=true
    scoped.lastOurOfferRevision=w.clientOfferRevision
    scoped.lastOurOfferAt=w.monotonicTime
   end
  end
  return scoped,nil
 end
 local scope,why=validateActive()
 if not scope then return nil,why end
 local engine,err=config.core.new({
  crosswalk=config.crosswalk,bound=bound,
  readContext=function()return config.marketBridge.researchContext()end,
  readScope=function()return validateActive()end,
  now=config.monotonicSeconds,
 })
 if not engine then return nil,err end
 local adapter={readOnly=true,authorizesChat=false,authorizesOffer=false,
   authorizesAccept=false}
 local connection=nil
 local function receive(msg)
  local scopeNow,whyNow=validateActive()
  if not scopeNow then last=denied(whyNow);return last end
  if msg==nil or msg.TextSource==nil then
   last=denied("TEXTSOURCE_USERID_MISSING_OR_SYSTEM_MESSAGE");return last
  end
  -- TextChatMessage.Text is client-filtered; PrefixText/display name is never
  -- identity. The platform can withhold text, in which case refuse parsing.
  local speaker=msg.TextSource.UserId
  if not validId(speaker) then
   last=denied("TEXTSOURCE_USERID_MALFORMED");return last end
  if type(msg.Text)~="string" then
   last=denied("TEXTCHAT_MESSAGE_TEXT_UNAVAILABLE");return last end
  local channel=msg.TextChannel
  local channelName=channel and channel.Name or nil
  local stamp=config.monotonicSeconds()
  local ok,result=pcall(engine.ingest,{
   speakerUserId=speaker,messageId=msg.MessageId,
   text=msg.Text,channelName=channelName,observedAt=stamp,
  })
  last=ok and result or denied("PASSIVE_PARSER_EXCEPTION_BLOCKED")
  return last
 end
 function adapter.start()
  if connection then return denied("ALREADY_SUBSCRIBED") end
  local service=config.textChatService
  if service.MessageReceived==nil or
      type(service.MessageReceived.Connect)~="function" then
   return denied("TEXTCHATSERVICE_MESSAGE_RECEIVED_UNAVAILABLE")
  end
  local ok,c=pcall(function()
   return service.MessageReceived:Connect(function(msg)receive(msg)end)
  end)
  if not ok or not c then
   return denied("PASSIVE_MESSAGE_RECEIVED_CONNECT_FAILED") end
  connection=c
  return {status="PASSIVE_CLIENT_CHAT_LISTENER_ATTACHED",
    readOnly=true,authorizesChat=false,authorizesOffer=false,
    authorizesTrade=false,authorizesAccept=false}
 end
 function adapter.stop()
  if connection then
   pcall(function() connection:Disconnect()end)
   connection=nil
  end
  return {status="PASSIVE_CHAT_LISTENER_DETACHED",readOnly=true,
    authorizesChat=false,authorizesAccept=false}
 end
 function adapter.lastResult()return last end
 function adapter.snapshot()return engine.snapshot()end
 function adapter.compareResearchOptions(options)
  return engine.compareResearchOptions(options)
 end
 -- Test-only explicit replay of the same message shape. No invented message
 -- event source or automatic installation in the active game.
 function adapter.readonlyProcessDeliveredTextChatMessage(msg)
  return receive(msg)
 end
 return adapter,nil
end
return M
