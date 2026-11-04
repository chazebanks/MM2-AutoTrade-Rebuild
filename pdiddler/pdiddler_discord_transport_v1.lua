-- One bounded Discord execute-webhook request. Credentials live only in this
-- runtime closure/request; responses and failures never echo raw inputs/errors.
local T={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function delay(value)
    local n=tonumber(value)
    if finite(n) and n>0 then return n end
    return nil
end
local function messageId(value)
    return type(value)=='string' and #value<=20 and value:match('^[1-9]%d*$')~=nil
end
local function canonicalURL(value)
    if type(value)~='string' or #value>512 then return false end
    local id,token=value:match('^https://discord%.com/api/webhooks/([1-9]%d*)/([%w_%-]+)$')
    return id~=nil and #id<=20 and token~=nil
end
function T.new(options)
    if type(options)~='table' or not canonicalURL(options.webhookUrl) then return nil,'discord-invalid-webhook-url' end
    for _,key in ipairs({'http','encode','decode','bounded'}) do
        if type(options[key])~='function' then return nil,'discord-transport-unavailable' end
    end
    local url=options.webhookUrl..'?wait=true'
    local http,encode,decode,bounded=options.http,options.encode,options.decode,options.bounded
    return function(payload)
        local encoded,body=pcall(encode,payload)
        if not encoded or type(body)~='string' then return {} end
        local attempted=false
        local completed,httpOK,response=pcall(bounded,'discord-webhook',10,function()
            if attempted then return nil end
            attempted=true
            return http({Url=url,Method='POST',Headers={['Content-Type']='application/json'},Body=body})
        end)
        if not completed or httpOK~=true or type(response)~='table' then return {} end
        local code=tonumber(response.StatusCode or response.status)
        if not finite(code) or code~=math.floor(code) or code<100 or code>599 then return {} end
        local normalized={status=code}
        local parsed
        if type(response.Body)=='string' and (code==200 or code==429) then
            local ok,value=pcall(decode,response.Body)
            if ok and type(value)=='table' then parsed=value end
        end
        if code==200 and parsed and messageId(parsed.id) then
            normalized.receipt={acknowledged=true,messageId=parsed.id}
        elseif code==429 then
            local retry=parsed and delay(parsed.retry_after) or nil
            if type(response.Headers)=='table' then
                for key,value in pairs(response.Headers) do
                    if type(key)=='string' and key:lower()=='retry-after' then
                        local header=delay(value)
                        if header then retry=retry and math.max(retry,header) or header end
                    end
                end
            end
            normalized.retryAfter=retry
        end
        return normalized
    end
end
return T
