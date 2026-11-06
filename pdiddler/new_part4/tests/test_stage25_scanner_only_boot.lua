-- Stage25 scanner-only bootstrap: simulated, NO real Roblox remotes.
local dir=arg[1] or "pdiddler/new_part4"
local run=assert(loadfile(dir.."/STAGE25_SCANNER_ONLY_BOOT.lua"))
local capture=assert(loadfile(dir.."/STAGE25_READONLY_DIAGNOSTIC.lua"))
local count=0
local function check(name,fn)
 local ok,reason=pcall(fn)
 if not ok then error(name..": "..tostring(reason)) end
 count=count+1
end
local function fixture()
 local env={}
 local calls={}
 local warnings={}
 local tasks={}
 local mono=100
 os.clock=function()return mono end
 task={spawn=function(fn)tasks[#tasks+1]=fn end,
   wait=function(dt)mono=mono+(dt or 0.3) end}
 getgenv=function()return env end
 warn=function(m) warnings[#warnings+1]=tostring(m) end
 loadstring=load
 local Players={Name="Players"}
 local me={UserId=12,Parent=Players}
 local p={UserId=345,Parent=Players}
 Players.LocalPlayer=me
 function Players:GetPlayers()return{me,p}end
 local inv={fingerprint="alpha-fp",unmapped=0,unpriced=0,badQty=0,
    items={{id="Mortal",page="godly",checkerId="101",qty=1,
      cat="Weapons",type="Knife"}}}
 local rec={player=p,state="whitelist",inv=inv,scanProof={
    kind="local-stable-scan-publication-v1",jobId="mock-job",
    playerUserId=345,fingerprint="alpha-fp",
    completedAtMono=95,sequence=4}}
 local stub={
   profile='return {isFresh=function()return false end,'
     ..'coverage=function()return{total=190}end,'
     ..'liveReady=true,expiresAtEpoch=123}',
   strict='return {reprice=function(inv) return inv end}',
   scannerView='return {inventory=function()return{}end}',
   scanner='return {getRecord=function(uid) return _G.__record end,'
      ..'getVerificationState=function(uid) return'
      ..'{player=_G.__player,record=_G.__record,'
      ..'scanning=false,retryScheduled=false}end}',
 }
 _G.__record=rec
 _G.__player=p
 local HTTP={JSONEncode=function(_,x)return "{}"end}
 game={PlaceId=142823291,JobId="mock-job",
  GetService=function(_,name)
    if name=="Players" then return Players end
    if name=="HttpService" then return HTTP end
    error("unknown service")
  end,
  HttpGet=function(_,url)
    local part=url:match("([^/]+)%.lua$")
    if part=="pdiddler_supreme_snapshot_2026_11_04" then part="profile"
    elseif part=="P4_REPRICE_ONLY" then part="strict"
    elseif part=="pdiddler3_scanner_view_v1" then part="scannerView"
    elseif part=="pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION" then part="scanner"
    elseif part=="STAGE25_READONLY_DIAGNOSTIC" then part="probe"
    end
    assert(stub[part] or part=="probe",
      "bootstrap fetched unauthorized module: "..tostring(part))
    calls[#calls+1]=part
    if part=="probe" then
      local file=assert(io.open(dir.."/STAGE25_READONLY_DIAGNOSTIC.lua","r"))
      local source=file:read("*a");file:close()
      return source
    end
    return stub[part]..string.rep(" ",60)
  end}
 return {env=env,Players=Players,rec=rec,player=p,calls=calls,
   warnings=warnings,run=run,capture=capture,tasks=tasks}
end

check("opt-in off means no code downloaded",function()
 local f=fixture()
 assert(f.run()==nil)
 assert(#f.calls==0)
end)
check("wrong MM2 place means no scanner boot",function()
 local f=fixture();f.env.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 game.PlaceId=1
 assert(f.run()==nil and #f.calls==0)
end)
check("do not attach to old or parallel trading stack",function()
 local f=fixture();f.env.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 f.env.PDIDDLER_OUTGOING_SESSION=10
 assert(f.run()==nil and #f.calls==0)
end)
check("existing scanner only loads profile+reprice+view+scanner",function()
 local f=fixture();f.env.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local owner=f.run()
 assert(owner and owner.status=="SCANNER_ONLY_NO_TRADE_AUTHORITY")
 assert(owner.marketFresh==false)
 assert(owner.authorizesTrade==false and owner.authorizesAccept==false)
 assert(owner.noOutgoing==true and owner.noHopping==true)
 assert(#f.calls==4)
 assert(f.calls[1]=="profile" and f.calls[2]=="strict"
   and f.calls[3]=="scannerView" and f.calls[4]=="scanner")
 local second=f.run()
 assert(second==owner and #f.calls==4)
 assert(#f.tasks==1)
end)
check("probe can inspect scanner-only cache, never treat it as trading authority",function()
 local f=fixture();f.env.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local owner=f.run()
 assert(owner and #f.tasks==1)
 -- The launcher must call the existing read-only diagnostic ONCE itself;
 -- no second user-pasted script or gameplay action.
 f.tasks[1]()
 assert(owner.probeStatus=="ONE_REPORT_CAPTURED")
 assert(#f.calls==5 and f.calls[5]=="probe")
 local probe=f.capture()
 local x=probe.fromActive()
 assert(x.sourceFresh==false)
 assert(x.records[1].label=="P1" and x.recent==1)
 assert(x.serverAttestation==false
   and x.authorizesTrade==false and x.authorizesAccept==false)
end)
print("PASS",count,"Stage25 isolated scanner-only Delta bootstrap mock tests")
