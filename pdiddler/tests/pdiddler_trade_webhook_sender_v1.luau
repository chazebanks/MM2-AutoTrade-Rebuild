-- Discord webhook sender transport contract v1
-- Pure test through injected request/json/sleep functions.

local Sender=require("../pdiddler_trade_webhook_sender_v1")

assert(Sender.validDiscordWebhook("https://discord.com/api/webhooks/123/token")==true)
assert(Sender.validDiscordWebhook("https://discordapp.com/api/webhooks/123/token")==true)
assert(Sender.validDiscordWebhook("https://example.com/api/webhooks/123/token")==false)
assert(Sender.validDiscordWebhook("")==false)

local attempts={}
local sleeps={}
local responses={
    {StatusCode=429,Body="RATE"},
    {StatusCode=204,Body=""},
}

local sender=Sender.new({
    url="https://discord.com/api/webhooks/123/token",
    maxRetries=3,
    requestFn=function(req)
        attempts[#attempts+1]=req
        return responses[#attempts]
    end,
    jsonEncode=function(payload)
        assert(payload.marker=="ok")
        return "{encoded}"
    end,
    jsonDecode=function(body)
        assert(body=="RATE")
        return {retry_after=0.75}
    end,
    sleep=function(seconds)
        sleeps[#sleeps+1]=seconds
    end,
})

local ok,why,code=sender.sendBlocking({marker="ok"})
assert(ok==true and why=="sent" and code==204)
assert(#attempts==2)
assert(attempts[1].Url=="https://discord.com/api/webhooks/123/token?wait=true")
assert(attempts[1].Method=="POST")
assert(attempts[1].Headers["Content-Type"]=="application/json")
assert(attempts[1].Body=="{encoded}")
assert(#sleeps==1 and sleeps[1]==0.75)

local permanentAttempts=0
local permanent=Sender.new({
    url="https://discord.com/api/webhooks/123/token?x=1",
    maxRetries=4,
    requestFn=function()
        permanentAttempts+=1
        return {StatusCode=404,Body="no"}
    end,
    jsonEncode=function() return "{}" end,
    sleep=function() error("must not retry permanent 4xx") end,
})
ok,why,code=permanent.sendBlocking({})
assert(ok==false and why=="rejected" and code==404)
assert(permanentAttempts==1)

local invalid=Sender.new({
    url="not-a-webhook",
    requestFn=function() error("must not request invalid URL") end,
    jsonEncode=function() return "{}" end,
})
ok,why=invalid.sendBlocking({})
assert(ok==false and why=="invalid-url")

local noReq=Sender.new({
    url="https://discord.com/api/webhooks/123/token",
    requestFn=false,
    jsonEncode=function() return "{}" end,
})
ok,why=noReq.sendBlocking({})
assert(ok==false and why=="request-unavailable")

print("PASS Discord webhook sender transport contract")
