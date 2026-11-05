-- Read-only capability audit. No close contract exists for the user's Delta build.
local M={}
local CACHE="PDIDDLER_DELTA_UI_AUDIT_V2"
local function read(node,key)
    local ok,value=pcall(function() return node[key] end)
    if ok then return value,true end
    return nil,false
end
local function isa(node,class)
    local ok,value=pcall(function() return node:IsA(class) end)
    return ok and value==true
end
local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function name(value)
    if type(value)~="string" then return "<unavailable>" end
    if value:find("://",1,true) or value:lower():find("webhook",1,true) then return "<redacted>" end
    -- GUI names can contain binary bytes; byte truncation can also split valid
    -- UTF-8. Keep display descriptors ASCII without changing any native name.
    local parts={}
    for index=1,math.min(#value,64) do
        local byte=value:byte(index)
        if byte==92 then parts[#parts+1]="\\\\"
        else parts[#parts+1]=(byte>=32 and byte<=126) and value:sub(index,index) or string.format("\\x%02X",byte) end
    end
    return table.concat(parts)
end
local function path(node)
    local parts={}
    for _=1,12 do
        if not node then break end
        table.insert(parts,1,name(read(node,"Name")))
        local parent,known=read(node,"Parent")
        if not known then break end
        node=parent
    end
    return table.concat(parts,"/")
end
local function visibility(node)
    local visible,known=true,true
    for _=1,64 do
        if not node then return visible,known end
        if isa(node,"GuiObject") then
            local value,ok=read(node,"Visible")
            if not ok or type(value)~="boolean" then known=false
            elseif not value then visible=false end
        end
        if isa(node,"LayerCollector") then
            local value,ok=read(node,"Enabled")
            if not ok or type(value)~="boolean" then known=false
            elseif not value then visible=false end
        end
        local parent,ok=read(node,"Parent")
        if not ok then return false,false end
        node=parent
    end
    return false,false
end
function M.inspect(options)
    local o=type(options)=="table" and options or {}
    local game,env=o.game,o.env
    local job=game and read(game,"JobId") or nil
    local report={status="overlay-unavailable",reason="not-inspected",jobId=type(job)=="string" and job or "",
        roots={},labels={},owners={},controls={},visited=0,truncated=false,
        userReportedBuild=name(o.userReportedBuild or "unknown"),actions=0,closeSupported=false}
    local function guard()
        if not game or type(env)~="table" then return "environment-unavailable" end
        if read(game,"PlaceId")~=142823291 then return "non-MM2" end
        local ok,loaded=pcall(function() return game:IsLoaded() end)
        if not ok or loaded~=true then return "game-not-loaded" end
        if type(job)~="string" or job=="" then return "job-unavailable" end
        if read(game,"JobId")~=job then return "job-changed" end
        if env.PDIDDLER_OUTGOING_SESSION~=nil or env.PDIDDLER_PART4_SESSION~=nil
            or env.PDIDDLER_OUTGOING_CONTROLLER~=nil or env.PDIDDLER_PART4_CONTROLLER~=nil then
            return "active-trader-owner"
        end
    end
    local blocked=guard()
    if blocked then report.status="skipped";report.reason=blocked;return report end
    local cached=env[CACHE]
    if type(cached)=="table" and cached.jobId==job and type(cached.report)=="table" then return cached.report end
    local state={jobId=job,report=report};env[CACHE]=state
    local now=type(o.now)=="function" and o.now or os.clock
    local started=now()
    local maxNodes=finite(o.maxNodes) and math.max(1,math.min(2048,math.floor(o.maxNodes))) or 2048
    local maxSeconds=finite(o.maxSeconds) and math.max(.001,math.min(.10,o.maxSeconds)) or .10
    local queue,queued,owners,ownerOrder,buttons={},{},{},{},{}
    local accessIncomplete=false
    local function registerOwner(owner)
        if owner and not owners[owner] then
            local descriptor={id="gui"..tostring(#ownerOrder+1),className="ScreenGui",
                name=name(read(owner,"Name")),path=path(owner)}
            owners[owner]={descriptor=descriptor,matched=false}
            ownerOrder[#ownerOrder+1]=owner
        end
        return owner
    end
    local function ancestorOwner(node)
        -- gethui may return a descendant also reached via CoreGui. Resolve its
        -- actual owner before deduplicated traversal can discard that context.
        local parent,known=read(node,"Parent")
        if not known then accessIncomplete=true;return nil end
        for _=1,64 do
            if not parent or guard() then return nil end
            if now()-started>=maxSeconds then report.truncated=true;return nil end
            if isa(parent,"ScreenGui") then return registerOwner(parent) end
            parent,known=read(parent,"Parent")
            if not known then accessIncomplete=true;return nil end
        end
        accessIncomplete=true
    end
    local function enqueue(node,owner)
        if not node or queued[node] then return end
        if #queue>=maxNodes then report.truncated=true;return end
        queued[node]=true;queue[#queue+1]={node=node,owner=owner}
    end
    local function root(source,fn)
        if guard() then return end
        local ok,node=pcall(fn)
        local accessible=ok and node~=nil and isa(node,"Instance")
        report.roots[#report.roots+1]={source=source,accessible=accessible==true}
        if accessible then enqueue(node) else accessIncomplete=true end
    end
    root("gethui",function() return type(o.gethui)=="function" and o.gethui() or nil end)
    root("CoreGui",function() return game:GetService("CoreGui") end)
    root("PlayerGui",function()
        local players=game:GetService("Players")
        local player=players and players.LocalPlayer
        return player and player:FindFirstChildOfClass("PlayerGui")
    end)
    local index=1
    while index<=#queue do
        if guard() then break end
        if now()-started>=maxSeconds then report.truncated=true;break end
        local entry=queue[index];index=index+1
        local node,owner=entry.node,entry.owner
        report.visited=report.visited+1
        if isa(node,"ScreenGui") then
            owner=node
        elseif not owner then
            owner=ancestorOwner(node)
        end
        registerOwner(owner)
        if isa(node,"TextLabel") or isa(node,"TextButton") then
            -- Read only these classes, retain only exact header text. Never read editor TextBoxes.
            local text=read(node,"Text")
            if text=="Roblox Console" or text=="Delta Console" then
                local shown,known=visibility(node)
                local row={text=text,visible=shown,visibilityKnown=known}
                if owner and owners[owner] then
                    row.ownerId=owners[owner].descriptor.id;owners[owner].matched=true
                end
                if #report.labels<16 then report.labels[#report.labels+1]=row else report.truncated=true end
            end
        end
        if isa(node,"GuiButton") then buttons[#buttons+1]={node=node,owner=owner} end
        local ok,children=pcall(function() return node:GetChildren() end)
        if ok and type(children)=="table" then
            for _,child in ipairs(children) do
                if guard() then break end
                if #queue>=maxNodes or now()-started>=maxSeconds then
                    report.truncated=true;break
                end
                enqueue(child,owner)
            end
        else accessIncomplete=true end
    end
    for _,owner in ipairs(ownerOrder) do
        if owners[owner].matched then report.owners[#report.owners+1]=owners[owner].descriptor end
    end
    for _,entry in ipairs(buttons) do
        if guard() then break end
        if now()-started>=maxSeconds then report.truncated=true;break end
        if entry.owner and owners[entry.owner] and owners[entry.owner].matched then
            if #report.controls>=32 then report.controlsTruncated=true;break end
            local button=entry.node
            local shown,known=visibility(button)
            local row={ownerId=owners[entry.owner].descriptor.id,name=name(read(button,"Name")),
                className=name(read(button,"ClassName")),path=path(button),visible=shown,visibilityKnown=known}
            local position,size=read(button,"AbsolutePosition"),read(button,"AbsoluteSize")
            for _,pair in ipairs({{"x",position,"X"},{"y",position,"Y"},{"width",size,"X"},{"height",size,"Y"}}) do
                local value=pair[2] and read(pair[2],pair[3])
                if finite(value) then row[pair[1]]=value end
            end
            local image=read(button,"Image")
            if type(image)=="string" and image:match("^rbxassetid://%d+$") then row.image=image end
            report.controls[#report.controls+1]=row
        end
    end
    report.accessIncomplete=accessIncomplete
    blocked=guard()
    if blocked then report.status="skipped";report.reason=blocked
    elseif #report.labels>0 then report.status="control-inaccessible";report.reason="native-exit-contract-unverified"
    else report.status="overlay-unavailable";report.reason=report.truncated and "scan-truncated" or "no-exact-console-headers" end
    if type(o.emit)=="function" then pcall(o.emit,report) end
    return report
end
-- BEGIN PDIDDLER DELTA UI ASCII FORMATTER
local function plain(value)
    return type(value)=="table" and getmetatable(value)==nil
end
local function displayBytes(value,limit)
    local parts={}
    for index=1,math.min(#value,limit) do
        local byte=value:byte(index)
        if byte==92 then parts[#parts+1]="\\\\"
        elseif byte<32 or byte>126 then parts[#parts+1]=string.format("\\x%02X",byte)
        else parts[#parts+1]=value:sub(index,index) end
    end
    return table.concat(parts)
end
local function jsonString(value)
    local parts={'"'}
    for index=1,#value do
        local byte=value:byte(index)
        if byte==34 then parts[#parts+1]='\\"'
        elseif byte==92 then parts[#parts+1]='\\\\'
        elseif byte<32 or byte>126 then parts[#parts+1]=string.format("\\\\x%02X",byte)
        else parts[#parts+1]=value:sub(index,index) end
    end
    parts[#parts+1]='"';return table.concat(parts)
end
local function encodeProjected(value)
    local kind=type(value)
    if kind=="string" then return jsonString(value) end
    if kind=="number" or kind=="boolean" then return tostring(value) end
    local parts={}
    if #value>0 or next(value)==nil then
        for index=1,#value do parts[#parts+1]=encodeProjected(value[index]) end
        return "["..table.concat(parts,",").."]"
    end
    local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do parts[#parts+1]=jsonString(key)..":"..encodeProjected(value[key]) end
    return "{"..table.concat(parts,",").."}"
end
function M.format(report,source)
    local r=plain(report) and report or {}
    local cached=source=="cached-v1"
    local out={traceVersion=2,traceSource=cached and "cached-v1" or "fresh-v2",traceEncoding="ascii-byte-escaped",
        inspectionPerformed=false,currentVisibilityVerified=false,captureTimeKnown=false,selectorsVerified=false,
        actions=0,closeSupported=false,roots={},labels={},owners={},controls={}}
    local status=rawget(r,"status")
    out.status=(status=="control-inaccessible" or status=="overlay-unavailable" or status=="skipped") and status or "unverified-report"
    local allowedReasons={['not-inspected']=true,['environment-unavailable']=true,['non-MM2']=true,
        ['game-not-loaded']=true,['job-unavailable']=true,['job-changed']=true,['active-trader-owner']=true,
        ['native-exit-contract-unverified']=true,['scan-truncated']=true,['no-exact-console-headers']=true,['audit-unavailable']=true}
    local reason=rawget(r,"reason");out.reason=allowedReasons[reason] and reason or "report-reason-unverified"
    out.inspectionPerformed=not cached and (out.status=="control-inaccessible" or out.status=="overlay-unavailable")
        and (reason=="native-exit-contract-unverified" or reason=="scan-truncated" or reason=="no-exact-console-headers")
    local function text(value,limit)
        if type(value)~="string" then return nil end
        if value:find("://",1,true) or value:lower():find("webhook",1,true) then return "<redacted>" end
        if #value>limit then out.traceTruncated=true end
        return value:sub(1,limit)
    end
    out.jobId=text(rawget(r,"jobId"),128)
    out.userReportedBuild=text(rawget(r,"userReportedBuild"),64)
    for _,key in ipairs({'truncated','accessIncomplete','controlsTruncated'}) do
        local value=rawget(r,key);if type(value)=="boolean" then out[key]=value end
    end
    local visited=rawget(r,"visited")
    if finite(visited) and visited>=0 and visited<=2048 then out.visited=visited end
    local strings={source=true,text=true,ownerId=true,id=true,className=true,name=true,path=true,image=true}
    local booleans={accessible=true,visible=true,visibilityKnown=true}
    local numbers={x=true,y=true,width=true,height=true}
    local schemas={
        {'roots',3,{'source','accessible'}},
        {'labels',16,{'text','ownerId','visible','visibilityKnown'}},
        {'owners',16,{'id','className','name','path'}},
        {'controls',32,{'ownerId','name','className','path','visible','visibilityKnown','x','y','width','height','image'}},
    }
    for _,schema in ipairs(schemas) do
        local rows=rawget(r,schema[1])
        if plain(rows) then
            for index=1,schema[2] do
                local row=rawget(rows,index)
                if row==nil then break end
                if plain(row) then
                    local projected={}
                    for _,key in ipairs(schema[3]) do
                        local value=rawget(row,key)
                        if strings[key] and type(value)=="string" then
                            if key=="image" then
                                if #value<=128 and value:match('^rbxassetid://%d+$') then projected[key]=value end
                            elseif key=="text" then
                                if value=="Roblox Console" or value=="Delta Console" then projected[key]=value end
                            elseif key=="source" then
                                if value=="gethui" or value=="CoreGui" or value=="PlayerGui" then projected[key]=value end
                            else
                                value=text(value,key=="path" and 1024 or 256)
                                if cached and (key=="name" or key=="path" or key=="className") then value=displayBytes(value,1024) end
                                projected[key]=value
                            end
                        elseif booleans[key] and type(value)=="boolean" then projected[key]=value
                        elseif numbers[key] and finite(value) then projected[key]=value end
                    end
                    if next(projected)~=nil then out[schema[1]][#out[schema[1]]+1]=projected end
                end
            end
            if rawget(rows,schema[2]+1)~=nil then out.traceTruncated=true end
        end
    end
    local encoded=encodeProjected(out)
    if #encoded>12288 then
        out.pathsOmitted=true
        for _,rows in ipairs({out.owners,out.controls}) do for _,row in ipairs(rows) do row.path=nil end end
        encoded=encodeProjected(out)
    end
    while #encoded>16384 and #out.controls>0 do
        table.remove(out.controls);out.traceTruncated=true;out.controlsTruncated=true;encoded=encodeProjected(out)
    end
    if #encoded>16384 then
        -- Keep a valid, explicit result even when owner descriptors alone exceed
        -- the output budget. Do not emit an unparseable partial JSON document.
        encoded=encodeProjected({traceVersion=2,traceSource=out.traceSource,traceEncoding=out.traceEncoding,
            status="unverified-report",reason="trace-size-budget",traceTruncated=true,
            inspectionPerformed=false,currentVisibilityVerified=false,captureTimeKnown=false,selectorsVerified=false,
            actions=0,closeSupported=false,roots={},labels={},owners={},controls={}})
    end
    return encoded
end
-- END PDIDDLER DELTA UI ASCII FORMATTER
return M
