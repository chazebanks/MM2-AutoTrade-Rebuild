-- Execute ACTUAL Stage83 native wrapper with fake Roblox services and local public files.
-- Never connect to MM2 or expose a real user's inventory.
local MODULE="pdiddler/new_part4/STAGE83_READONLY_PUBLIC_SLUG_COVERAGE.lua"
local HELPER="pdiddler/intelligence_lab/stage83_private_aggregate_coverage.lua"
local PUBLIC="pdiddler/intelligence_lab/stage83_public_slug_registry.lua"
local KEY="GINGERSCOPE_STAGE83_READONLY_AGGREGATE_COVERAGE"
local count=0
local function group(label,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL "..label.." "..tostring(err)) end
 count=count+1;print("PASS "..label)
end
local function read(path)
 local f=assert(io.open(path,"rb"))
 local s=f:read("*a");f:close();return s
end
local function meta(name)
 local r=dofile(PUBLIC).entries[name]
 assert(r,"fixture item missing")
 return {ItemName=r[1],ItemType=r[2],Rarity=r[3],Chroma=r[4]}
end
local function owned()
 return {Weapons={Owned={
  Gingerscope=1,EmberscytheChroma=2,CommonExample=3,
  MiscExample=1,NewUnmapped=2
 }}}
end
local function build(profile,opts)
 opts=opts or {}
 local env=opts.env or {}
 local remoteCalls,httpGets=0,0
 local copied=nil
 _G.getgenv=function()return env end
 _G.loadstring=load
 _G.Instance=nil
 _G.setclipboard=nil
 _G.toclipboard=function(s)copied=s;return true end
 _G.task={spawn=function(fn)fn()end,wait=function()end}
 local syncMarker={}
 local ownRemote={}
 function ownRemote:IsA(s) return s=="RemoteFunction" end
 function ownRemote:InvokeServer(...)
  remoteCalls=remoteCalls+1
  assert(select("#",...)==0,"unexpected remote arguments")
  if opts.readError then error("synthetic own-read error") end
  return profile
 end
 local inv={}
 function inv:FindFirstChild(n)
  if n=="GetProfileData" and not opts.noRemote then return ownRemote end
 end
 local remotes={}
 function remotes:FindFirstChild(n)
  if n=="Inventory" then return inv end
 end
 local database={}
 function database:FindFirstChild(n)
  if n=="Sync" and not opts.noSync then return syncMarker end
 end
 local repl={}
 function repl:FindFirstChild(n)
  if n=="Database" then return database end
  if n=="Remotes" then return remotes end
 end
 local HttpService={}
 function HttpService:JSONEncode(r)
  assert(r.readOnly==true and r.clientOnly==true)
  assert(r.currentPricesVerified==false)
  assert(r.authorizesAccept==false and r.authorizesTrade==false)
  assert(r.mayUseForStrategyLearning==false and r.maySendDiscordWebhook==false)
  for k,v in pairs(r) do
   for _,private in ipairs({"Gingerscope","EmberscytheChroma","NewUnmapped"}) do
    assert(not tostring(k):find(private,1,true))
    assert(not tostring(v):find(private,1,true))
   end
  end
  return '{"schema":"gingerscope-stage83-mocked-counts"}'
 end
 local services={ReplicatedStorage=repl,HttpService=HttpService,
  Players={LocalPlayer={FindFirstChildOfClass=function()return nil end}}}
 local gameObj={
  PlaceId=opts.wrongGame and 12345 or 142823291,
  JobId="STAGE83_FAKE_JOB_NOT_EXPORTED"
 }
 function gameObj:GetService(name)
  return assert(services[name],"unexpected service "..tostring(name))
 end
 function gameObj:HttpGet(url,...)
  httpGets=httpGets+1
  assert(url:find("42ab03b81fe1ab69613ec8b5797dad95252ee4d8",1,true))
  assert(select("#",...)==1)
  if opts.httpError then error("offline source not available") end
  if url:find("stage83_private_aggregate_coverage.lua",1,true) then
   return read(HELPER)
  elseif url:find("stage83_public_slug_registry.lua",1,true) then
   return read(PUBLIC)
  end
  error("unknown script fetched")
 end
 _G.game=gameObj
 _G.require=function(target)
  assert(target==syncMarker)
  return {Weapons=opts.catalog or {
    Gingerscope=meta("Gingerscope"),
    EmberscytheChroma=meta("EmberscytheChroma"),
    CommonExample={ItemName="Common synthetic",ItemType="Knife",Rarity="Common"},
    MiscExample={ItemName="Misc synthetic",ItemType="Misc",Rarity="Common"},
    NewUnmapped={ItemName="Unmapped synthetic",ItemType="Gun",Rarity="Godly"},
  }}
 end
 local function run()
  local ok,r=pcall(dofile,MODULE)
  assert(ok,r)
  assert(type(r)=="table" and r==env[KEY])
  return r
 end
 return run,function()return remoteCalls end,
  function()return httpGets end,function()return copied end
end
local function safely(r)
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.currentPricesVerified==false and r.sourcePublisherFresh==false)
 assert(r.authenticatedOwnedInventory==false and r.serverAttestation==false)
 assert(r.currentOwnedRawToMarketSlugVerified==false)
 assert(r.mayReportProfit==false and r.mayUseForStrategyLearning==false)
 assert(r.maySendDiscordWebhook==false and r.tradeOutcome=="UNKNOWN")
end
group("actual wrapper does two pinned public fetches and ONE own RemoteFunction read",function()
 local run,calls,fetches,clip=build(owned())
 local r=run()
 assert(calls()==1 and fetches()==2)
 assert(r.status=="CLIENT_HISTORICAL_PUBLIC_REFERENCE_COVERAGE_ONLY",r.reason)
 assert(r.ownedKeys==5 and r.ownedCopies==9)
 assert(r.clientWeaponKeys==4 and r.clientWeaponCopies==8)
 assert(r.miscKeys==1 and r.eligibleKeys==3)
 assert(r.historicalReferenceEligibleKeys==2)
 assert(r.historicalUnmappedEligibleKeys==1)
 assert(r.historicalVariantDriftEligibleKeys==0)
 assert(clip():find("[GINGERSCOPE STAGE83 PUBLIC COVERAGE]",1,true))
 safely(r)
 local second=run()
 assert(second==r and calls()==1 and fetches()==2)
end)
group("old Stage80 one-shot session explicitly blocks Stage83",function()
 local run,calls,fetches=build(owned(),{env={GINGERSCOPE_STAGE80_ONE_METADATA_REASON_PROBE={}}})
 local r=run()
 assert(r.status=="OTHER_SESSION_ACTIVE_REJOIN_REQUIRED")
 assert(calls()==0 and fetches()==0)
 safely(r)
end)
group("wrong game cannot read inventory",function()
 local run,calls,fetches=build(owned(),{wrongGame=true})
 assert(run().status=="WRONG_GAME" and calls()==0 and fetches()==0)
end)
group("missing Sync cannot read inventory or fetch source",function()
 local run,calls,fetches=build(owned(),{noSync=true})
 assert(run().status=="SYNC_UNAVAILABLE" and calls()==0 and fetches()==0)
end)
group("missing source cannot fall back to mutable or unknown registry",function()
 local run,calls,fetches=build(owned(),{httpError=true})
 assert(run().status=="PINNED_PUBLIC_HELPER_UNAVAILABLE")
 assert(calls()==0 and fetches()==1)
end)
group("missing own read RemoteFunction blocks result",function()
 local run,calls,fetches=build(owned(),{noRemote=true})
 assert(run().status=="OWN_PROFILE_REMOTE_MISSING")
 assert(calls()==0 and fetches()==2)
end)
group("one own profile read failure is NOT retried",function()
 local run,calls,fetches=build(owned(),{readError=true})
 local r=run()
 assert(r.status=="PROFILE_UNREADABLE")
 assert(calls()==1 and fetches()==2)
 safely(r)
end)
group("malformed profile shape is not a false green",function()
 local run,calls=build({Inventory={Missing={}}})
 local r=run()
 assert(r.status=="PROFILE_SHAPE_UNAVAILABLE" and calls()==1)
 safely(r)
end)
group("reported numeric raw key stays inconclusive",function()
 local p=owned();p.Weapons.Owned[42]=1
 local run,calls=build(p,{catalog={}})
 local r=run()
 assert(r.status=="INCONCLUSIVE")
 assert(r.numericOwnedKeys==1 and calls()==1)
 safely(r)
end)
print("STAGE83_NATIVE_MOCK_LUA_PASS groups="..count)
