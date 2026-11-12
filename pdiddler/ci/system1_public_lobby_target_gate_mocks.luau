-- Deterministic offline Lune coverage of actual public-lobby target gate.
-- No Roblox network or P3 request. Adversarial identity/eligibility checks.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local text=fs.readFile("pdiddler/system1/system1_public_lobby_target_gate.lua")
local mod=luau.load(text)()
local tests=0
local function eq(a,b,why)
 tests+=1; assert(a==b,why..": "..tostring(a).." != "..tostring(b))
end
local function fixture()
 local players={}
 local main={Name="ME",UserId=10,Parent=players}
 local a={Name="PUBLIC_A",UserId=20,Parent=players}
 local b={Name="PUBLIC_B",UserId=30,Parent=players}
 local c={Name="PUBLIC_C",UserId=40,Parent=players}
 local d={Name="PUBLIC_D",UserId=50,Parent=players}
 local all={a,b,c,d}
 local records={}
 for _,p in ipairs(all) do records[p.UserId]={player=p,state="whitelist"} end
 function players:GetPlayerByUserId(id)
  for _,p in ipairs(all) do if p.UserId==id and p.Parent==players then return p end end
  return nil
 end
 local scanner={}
 function scanner.getWhitelist() return all end
 function scanner.isWhitelisted(id)
  return records[id]~=nil and records[id].state=="whitelist"
 end
 function scanner.getRecord(id) return records[id] end
 function scanner.getOwnInventory()return {items={}}end
 function scanner.hasPendingWork()return false end
 function scanner.setStatus()end
 function scanner.setRequestState()end
 local opts={
  publicLobbyTest=true,noFinalAccept=true,noItemOffers=true,
  noServerHop=true,explicitOperatorArm=true,maxTargets=3,
 }
 local gate,why=mod.new(scanner,players,main,opts)
 eq(type(gate),"table","test gate constructed")
 eq(why,nil,"constructor no error")
 return {gate=gate,scanner=scanner,records=records,all=all,players=players,
         a=a,b=b,c=c,d=d,opts=opts,main=main}
end
do
 local x=fixture()
 eq(#x.gate.scanner.getWhitelist(),0,"no eligible contacts before explicit arm")
 eq(x.gate.arm(),true,"explicit public test arm with verified two-plus")
 local list=x.gate.scanner.getWhitelist()
 eq(#list,3,"three-contact bounded max enforced")
 eq(list[1],x.a,"deterministic first valid UserId")
 eq(list[2],x.b,"deterministic second valid UserId")
 eq(list[3],x.c,"deterministic third valid UserId")
 eq(x.gate.scanner.isWhitelisted(x.d.UserId),false,
    "unfrozen fourth player cannot be contacted")
 eq(x.gate.scanner.getRecord(x.d.UserId),nil,
    "no unapproved fourth record")
 eq(x.gate.status({[20]="ignored",[30]="declined",[40]="accepted"}).status,
    "EXHAUSTED","three distinct clients processed once")
 eq(x.gate.status({[20]="ignored"}).processedTargets,1,
    "partial processed ledger is precise")
 eq(x.gate.status().authorizesAccept,false,"no economic authority")
 eq(x.gate.arm(),false,"cannot rearm same snapshot to resend players")
end
do
 local x=fixture()
 x.records[x.b.UserId].state="blacklist"
 eq(x.gate.arm(),true,"remaining three eligible players can arm")
 eq(#x.gate.scanner.getWhitelist(),3,"blacklist excluded")
 eq(x.gate.scanner.getWhitelist()[1],x.a,"sorted eligible")
 eq(x.gate.scanner.getWhitelist()[2],x.c,"skip ineligible B")
end
do
 local x=fixture()
 x.records[x.b.UserId].state="unknown"
 x.records[x.c.UserId].state="blacklist"
 x.records[x.d.UserId].state="unknown"
 local yes,why=x.gate.arm()
 eq(yes,false,"do not arm without two eligible verified players")
 eq(why,"NEED_TWO_DISTINCT_VERIFIED_ELIGIBLE_PLAYERS",
    "unknown is not whitelisted")
end
do
 local x=fixture()
 x.all[4]=x.a -- duplicate scanner id
 local yes,why=x.gate.arm()
 eq(yes,false,"duplicate identity fails before request")
 eq(why,"DUPLICATE_SCANNER_USER_ID","precise duplicate refusal")
 eq(#x.gate.scanner.getWhitelist(),0,"faulted gate empty")
end
do
 local x=fixture()
 eq(x.gate.arm(),true,"arm identity-replacement test")
 local fake={Name="PUBLIC_A",UserId=x.a.UserId,Parent=x.players}
 x.all[1]=fake -- same UserId, new Player object
 eq(#x.gate.scanner.getWhitelist(),0,
    "stale identity replacement invalidates entire snapshot")
 eq(x.gate.status().status,"STOPPED","replacement stops forever")
end
do
 local x=fixture()
 eq(x.gate.arm(),true,"arm departure test")
 x.a.Parent=nil
 eq(#x.gate.scanner.getWhitelist(),2,
    "left player excluded and other two retained")
 eq(x.gate.status().status,"ARMED",
    "legitimate departure does not become identity takeover")
end
do
 local x=fixture()
 eq(x.gate.arm(),true,"arm eligibility revocation")
 x.records[x.b.UserId].state="unknown"
 eq(#x.gate.scanner.getWhitelist(),2,
    "revoked or UNKNOWN player no longer contacted")
 eq(x.gate.scanner.isWhitelisted(x.b.UserId),false,
    "revoked snapshot never overrides scanner")
end
do
 local x=fixture()
 eq(x.gate.arm(),true,"arm stop test")
 eq(x.gate.stop(),true,"manual stop")
 eq(x.gate.status().status,"STOPPED","manual stop final")
 eq(#x.gate.scanner.getWhitelist(),0,"no requests after STOP")
end
do
 local x=fixture()
 x.opts.explicitOperatorArm=false
 local gate,why=mod.new(x.scanner,x.players,x.main,x.opts)
 eq(gate,nil,"no operator approval => no gate")
 eq(why,"PUBLIC_TEST_CONSENT_OR_DEPENDENCY_MISSING",
    "correct consent refused")
end
print("SYSTEM1_PUBLIC_LOBBY_TARGET_GATE_PASS",tests)
