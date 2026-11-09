-- Stage79 actual wrapper executed under mocked Lua5.4 Roblox APIs.
-- The mocked read-only endpoint is a stub: never real MM2 network traffic.
local src="pdiddler/new_part4/STAGE79_READONLY_OWNED_TYPED_CENSUS.lua"
local helper="pdiddler/intelligence_lab/stage79_typed_owned_census.lua"
local KEY="GINGERSCOPE_STAGE79_SINGLE_OWNED_TYPE_PROBE"
local count=0
local function case(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL "..name.." "..tostring(err)) end
 count=count+1
 print("PASS "..name)
end
local function build(profile,option)
 option=option or {}
 local env=option.env or {}
 local calls=0
 local copied=nil
 _G.getgenv=function()return env end
 _G.loadstring=load
 _G.Instance=nil
 _G.setclipboard=nil
 _G.toclipboard=function(s) copied=s;return true end
 _G.task={
  spawn=function(fn) fn() end,
  wait=function(_) end
 }
 local marker={}
 local rf={}
 function rf:IsA(name) return name=="RemoteFunction" end
 function rf:InvokeServer(...)
  calls=calls+1
  assert(select("#",...)==0,"own profile remote called with unexpected arguments")
  if option.rpcFailure then error("synthetic server failure") end
  return profile
 end
 local inv={}
 function inv:FindFirstChild(name)
  if name=="GetProfileData" and not option.noRemote then return rf end
 end
 local remotes={}
 function remotes:FindFirstChild(name)
  if name=="Inventory" then return inv end
 end
 local db={}
 function db:FindFirstChild(name)
  if name=="Sync" and not option.noSync then return marker end
 end
 local rs={}
 function rs:FindFirstChild(name)
  if name=="Database" then return db end
  if name=="Remotes" then return remotes end
 end
 local lp={}
 function lp:FindFirstChildOfClass(_) return nil end
 local services={
  Players={LocalPlayer=lp},ReplicatedStorage=rs,
  HttpService={JSONEncode=function(_,r)
   for k,v in pairs(r) do
    assert(tostring(k):find("PRIVATE_RAW_WEAPON",1,true)==nil)
    assert(tostring(v):find("PRIVATE_RAW_WEAPON",1,true)==nil)
   end
   assert(r.authorizesTrade==false and r.authorizesAccept==false)
   assert(r.maySendDiscordWebhook==false and r.mayUseForStrategyLearning==false)
   return '{"schema":"stage79-mocked-aggregate-only"}'
  end}
 }
 local gameObj={PlaceId=option.wrongGame and 555 or 142823291,JobId="mockjob-opaque"}
 function gameObj:GetService(name)
  return assert(services[name],"unexpected service: "..tostring(name))
 end
 function gameObj:HttpGet(url,...)
  assert(url:find("a2da4d53b7ee92b289b9c58a34ac08e7ded6731a",1,true)~=nil)
  assert(select("#",...)==1)
  local f=assert(io.open(helper,"rb"))
  local c=f:read("*a");f:close();return c
 end
 _G.game=gameObj
 _G.require=function(module)
  assert(module==marker,"unexpected require")
  return {Weapons=option.catalog or {
    PRIVATE_RAW_WEAPON_A={ItemName="ItemA",ItemType="Gun",Rarity="Ancient"},
    PRIVATE_RAW_WEAPON_B={ItemName="ItemB",ItemType="Knife",Rarity="Ancient",Chroma=true},
    ["42"]={ItemName="Item42",ItemType="Gun",Rarity="Godly"}
  }}
 end
 local function run()
  local ok,res=pcall(dofile,src)
  assert(ok,res)
  assert(type(res)=="table" and res==env[KEY])
  return res
 end
 return run,function()return calls end,function()return copied end
end
local function owned()
 return {Weapons={Owned={PRIVATE_RAW_WEAPON_A=1,PRIVATE_RAW_WEAPON_B=2}}}
end
local function safe(r)
 assert(r.readOnly==true and r.clientOnly==true)
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.serverAttestation==false and r.authenticatedOwnedInventory==false)
 assert(r.mayReportProfit==false and r.maySendDiscordWebhook==false)
 assert(r.mayUseForStrategyLearning==false and r.tradeOutcome=="UNKNOWN")
end
case("real wrapper one own RPC exact client keys",function()
 local run,calls,clipboard=build(owned())
 local r=run()
 assert(calls()==1)
 assert(r.status=="CLIENT_TYPED_OWNED_DIRECT_CATALOGUE_MATCH_ONLY")
 assert(r.stringKeyCount==2 and r.numericKeyCount==0 and r.directCatalogueKeyCount==2)
 assert(r.eligibleCopies==3 and r.chromaEligibleCopies==2)
 assert(clipboard():find("[GINGERSCOPE STAGE79 OWNED TYPE]",1,true)~=nil)
 safe(r)
 assert(run()==r and calls()==1,"same-session rerun must never repeat RPC")
end)
case("original numeric and string key collision stays inconclusive",function()
 local run,calls=build({ProfileData={Weapons={Owned={[42]=1,["42"]=1}}}})
 local r=run()
 assert(calls()==1 and r.status=="INCONCLUSIVE")
 assert(r.numericKeyCount==1 and r.coercionCollisionPairs==1)
 safe(r)
end)
case("wrong game makes no profile remote request",function()
 local run,calls=build(owned(),{wrongGame=true})
 local r=run()
 assert(r.status=="WRONG_GAME" and calls()==0)
 safe(r)
end)
case("another pdiddler session makes no profile request",function()
 local run,calls=build(owned(),{env={PDIDDLER_PART4_SESSION={}}})
 local r=run()
 assert(r.status=="OTHER_SESSION_ACTIVE_REJOIN_REQUIRED" and calls()==0)
 safe(r)
end)
case("missing sync module makes no request",function()
 local run,calls=build(owned(),{noSync=true})
 local r=run()
 assert(r.status=="SYNC_MISSING" and calls()==0)
 safe(r)
end)
case("missing Own remote makes no request",function()
 local run,calls=build(owned(),{noRemote=true})
 local r=run()
 assert(r.status=="OWN_PROFILE_REMOTE_MISSING" and calls()==0)
 safe(r)
end)
case("synthetic RPC failure returns bounded unknown",function()
 local run,calls=build(owned(),{rpcFailure=true})
 local r=run()
 assert(r.status=="PROFILE_UNREADABLE" and calls()==1)
 safe(r)
end)
case("missing private owned source not mistaken for empty success",function()
 local run,calls=build({Inventory={Other={}}})
 local r=run()
 assert(r.status=="PROFILE_SHAPE_UNAVAILABLE" and calls()==1)
 safe(r)
end)
print("STAGE79_NATIVE_LUA54_MOCK_PASS cases="..count)
