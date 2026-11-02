-- pdiddler Discord webhook sender v1
-- Transport-only. Does not know about trades or mutate trader state.

local M={}

function M.validDiscordWebhook(url)
    url=tostring(url or "")
    return url:match("^https://discord%.com/api/webhooks/")~=nil
        or url:match("^https://discordapp%.com/api/webhooks/")~=nil
end

local function defaultRequestFn()
    if type(request)=="function" then return request end
    if type(http_request)=="function" then return http_request end
    if type(syn)=="table" and type(syn.request)=="function" then return syn.request end
    if type(http)=="table" and type(http.request)=="function" then return http.request end
    return nil
end

local function defaultHttpService()
    local ok,svc=pcall(function()
        return game:GetService("HttpService")
    end)
    return ok and svc or nil
end

function M.new(config)
    config=type(config)=="table" and config or {}

    local url=tostring(config.url or "")
    local maxRetries=math.max(1,math.floor(tonumber(config.maxRetries) or 3))

    local req
    if config.requestFn~=nil then
        req=type(config.requestFn)=="function" and config.requestFn or nil
    else
        req=defaultRequestFn()
    end

    local hs=nil
    if type(config.jsonEncode)~="function"
        or type(config.jsonDecode)~="function"
    then
        hs=defaultHttpService()
    end

    local jsonEncode=
        type(config.jsonEncode)=="function"
        and config.jsonEncode
        or (hs and function(v) return hs:JSONEncode(v) end)

    local jsonDecode=
        type(config.jsonDecode)=="function"
        and config.jsonDecode
        or (hs and function(v) return hs:JSONDecode(v) end)

    local sleep=
        type(config.sleep)=="function"
        and config.sleep
        or function(seconds) task.wait(seconds) end

    local A={}

    local function requestUrl()
        return url..(url:find("?",1,true) and "&wait=true" or "?wait=true")
    end

    function A.sendBlocking(payload)
        if not M.validDiscordWebhook(url) then
            return false,"invalid-url",nil
        end

        if type(req)~="function" then
            return false,"request-unavailable",nil
        end

        if type(jsonEncode)~="function" then
            return false,"json-encode-unavailable",nil
        end

        local encOk,body=pcall(jsonEncode,payload)
        if not encOk or type(body)~="string" then
            return false,"json-encode-failed",nil
        end

        local lastCode=nil
        local lastWhy="request-failed"

        for attempt=1,maxRetries do
            local ok,res=pcall(req,{
                Url=requestUrl(),
                Method="POST",
                Headers={["Content-Type"]="application/json"},
                Body=body,
            })

            local code=
                ok and type(res)=="table"
                and tonumber(res.StatusCode or res.Status or res.status_code)
                or nil

            lastCode=code

            if ok then
                if code and code>=200 and code<300 then
                    return true,"sent",code
                end

                if not code and type(res)=="table" and res.Success==true then
                    return true,"sent",nil
                end
            end

            if code and code>=400 and code<500 and code~=429 then
                return false,"rejected",code
            end

            lastWhy=ok and "retryable-status" or "request-error"

            if attempt<maxRetries then
                local pause=attempt

                if code==429
                    and type(res)=="table"
                    and type(res.Body)=="string"
                    and type(jsonDecode)=="function"
                then
                    local decOk,data=pcall(jsonDecode,res.Body)
                    if decOk and type(data)=="table" then
                        pause=math.max(
                            0.5,
                            tonumber(data.retry_after) or pause
                        )
                    end
                end

                sleep(pause)
            end
        end

        return false,lastWhy,lastCode
    end

    function A.send(payload,callback)
        if type(task)~="table" or type(task.spawn)~="function" then
            local ok,why,code=A.sendBlocking(payload)
            if type(callback)=="function" then
                pcall(callback,ok,why,code)
            end
            return ok,why,code
        end

        task.spawn(function()
            local ok,why,code=A.sendBlocking(payload)
            if type(callback)=="function" then
                pcall(callback,ok,why,code)
            end
        end)

        return true,"queued",nil
    end

    function A.configured()
        return M.validDiscordWebhook(url) and type(req)=="function"
    end

    return A
end

return M
