-- pdiddler Discord WEBHOOK CONNECTION TEST v1
-- Network-only lab. Does not inspect or mutate MM2 trades.

local ENV=(getgenv and getgenv()) or _G
local URL=tostring(ENV.PDIDDLER_DISCORD_WEBHOOK_URL or "")

if URL=="" then
    warn("[PDIDDLER WEBHOOK LAB] FAIL | PDIDDLER_DISCORD_WEBHOOK_URL is not set")
    return false
end

local function loadModule(url,label)
    local ok,src=pcall(function()
        return game:HttpGet(url,true)
    end)

    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER WEBHOOK LAB] "..tostring(label).." HTTP failed")
    end

    local fn,err=loadstring(src)
    if not fn then
        error("[PDIDDLER WEBHOOK LAB] "..tostring(label).." compile failed: "..tostring(err))
    end

    local okRun,result=pcall(fn)
    if not okRun then
        error("[PDIDDLER WEBHOOK LAB] "..tostring(label).." init failed: "..tostring(result))
    end

    return result
end

local COMMIT="66b818e1d5142de0e0c1dd63585dcda62363123e"
local senderModule=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
        ..COMMIT
        .."/pdiddler/pdiddler_trade_webhook_sender_v1.lua",
    "webhook sender"
)

local sender=senderModule.new({
    url=URL,
    maxRetries=4,
})

local payload={
    username="MM2 Auto Trade",
    allowed_mentions={parse={}},
    embeds={{
        title="🧪 MM2 WEBHOOK CONNECTION TEST",
        description="Webhook transport connected successfully. No trade was completed or modified.",
        color=5763719,
        fields={{
            name="Status",
            value="Ready to log verified completed trades.",
            inline=false,
        }},
        footer={text="Pre-Part-5 connection test"},
    }},
}

print("[PDIDDLER WEBHOOK LAB] sending connection test...")

local ok,why,code=sender.sendBlocking(payload)

if ok then
    print(
        "[PDIDDLER WEBHOOK LAB] PASS | Discord webhook accepted test",
        "| status",tostring(code or "executor-success")
    )
    return true
end

warn(
    "[PDIDDLER WEBHOOK LAB] FAIL",
    "| reason",tostring(why),
    "| status",tostring(code or "none")
)
return false
