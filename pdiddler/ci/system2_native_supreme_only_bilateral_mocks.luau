-- Native Luau Supreme-only C4 replacement: real 189 Supreme-source fixture.
-- Synthetic inventory/options only; no source claiming settlement or live trades.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local source=serde.decode("json",fs.readFile("pdiddler/system2/supreme_only_189_research_catalog.json"))
local native=luau.load(fs.readFile("pdiddler/system2/native_supreme_only_bilateral_research.lua"))()
local SHA="0fefb1d82d6841a787974478447f5d9e1db922e7"
local TIME=1794803825.0
local n=0
local function eq(a,b,why)
 n+=1
 assert(a==b,why..": expected "..tostring(b)..", got "..tostring(a))
end
local function yes(a,why)
 n+=1
 assert(a,why)
end
local function copy(v)return serde.decode("json",serde.encode("json",v))end
local function slot(id,q)return {id=id,quantity=q or 1}end
local function alt(give,receive)
 return {kind="HYPOTHETICAL_RESEARCH_ONLY",valueSource="SUPREME_ONLY",
  give=give,receive=receive}
end
local own={Harvester=1,FlowerwoodKnife=2,EmberscytheChroma=1,Gingerscope=1}
local valid=alt({slot("Harvester")},{slot("FlowerwoodKnife",2)})
local function run(options,owned,t,cat,pin)
 return native.review(cat or source,pin or SHA,t or TIME,owned or own,options or {valid})
end
local ready=run()
eq(ready.status,"SUPREME_ONLY_NATIVE_RESEARCH_NOT_EXECUTABLE","new native source")
eq(ready.valueSource,"SUPREME_ONLY","one value publisher")
eq(ready.reviewedHistoricalGameKeyCandidates,189,"189 original raw keys")
eq(ready.gingerscopeTargetSupremeValue,16000,"one Supreme Gingerscope target")
local row=ready.hypotheticalAlternatives[1]
eq(row.outgoingSupremeListedValue,275,"Harvester Supreme value")
eq(row.incomingSupremeListedValue,470,"two Flowerwood Supreme")
eq(row.supremeListedGain,195,"Supreme only gain")
eq(row.partnerSupremeListedGain,-195,"partner symmetrical Supreme")
eq(row.hypotheticalAfterSupremePortfolio,
 ready.hypotheticalAlternatives[1].beforeSupremePortfolio+195,
 "portfolio conserves one source")
eq(row.demandIncoming,3,"Supreme demand only")
eq(ready.authorizesTrade,false,"no trade")
eq(ready.authorizesOffer,false,"no offer")
eq(ready.authorizesAccept,false,"no Accept")
eq(ready.mayUseForStrategyLearning,false,"no learning")
eq(ready.livePublisherAuthenticated,false,"unsigned source remains unsigned")
eq(ready.realInventoryVerified,false,"owned mock is not live")
eq(row.tradeActionable,false,"paper proposal not executable")
yes(type(ready.sourceCaptureAgeSeconds)=="number","source age is measured")
local chroma=run({alt({slot("EmberscytheChroma")},{slot("Gingerscope")})})
eq(chroma.hypotheticalAlternatives[1].supremeListedGain,4000,
 "Chroma and Gingerscope use only Supreme 12000 to 16000")
local loss=run({alt({slot("Harvester")},{slot("FlowerwoodKnife")})})
eq(loss.hypotheticalAlternatives[1].supremeListedGain,-40,
 "listed loss 275 for 235")
eq(loss.hypotheticalAlternatives[1].status,
 "BLOCKED_UNAPPROVED_SUPREME_LOSS","loss budget not approved")
local target=run({alt({slot("Gingerscope")},{slot("Harvester")})})
eq(target.status,"BLOCKED","owned Gingerscope outbound forbidden")
eq(target.reason,"SUPREME_ONLY_GINGERSCOPE_NEVER_OUTGOING","never outbound")
eq(run({valid},nil,1794803795.765+21601).status,
 "BLOCKED","6h expiry")
eq(run({valid},nil,1794803795.765-1).status,
 "BLOCKED","future source")
eq(run({valid},nil,nil,nil,"wrong-pin").status,
 "BLOCKED","catalog pin")
local forged=copy(source)
forged.sourceCapturedUtc="2026-11-16T18:00:00Z"
eq(run({valid},nil,TIME,forged).status,"BLOCKED","restamp denied")
forged=copy(source)
forged.rows[1].supremeListed=nil
eq(run({valid},nil,TIME,forged).status,"BLOCKED","missing Supreme price denied")
forged=copy(source)
forged.valueSource="HYBRID"
eq(run({valid},nil,TIME,forged).status,"BLOCKED","hybrid catalog denied")
forged=copy(source)
forged.rows[1].outgoingGingerscopeProtected=true
eq(run({valid},nil,TIME,forged).status,"BLOCKED","incorrect target protection")
forged=copy(source)
table.remove(forged.rows,1)
eq(run({valid},nil,TIME,forged).status,"BLOCKED","189 census incomplete")
local mixed=copy(valid)
mixed.valueSource="MM2VALUES"
eq(run({mixed}).status,"BLOCKED","alternate strategy list denied")
mixed=copy(valid)
mixed.backupValue=999999
eq(run({mixed}).status,"BLOCKED","mixed value injection denied")
mixed=copy(valid)
mixed.receive[1].backupPrice=99999
eq(run({mixed}).status,"BLOCKED","slot mixed source denied")
local five=alt({slot("Harvester")},{
 slot("FlowerwoodKnife"),slot("Gingerscope"),slot("TravelerAxe"),
 slot("EmberscytheChroma"),slot("Harvester")})
eq(run({five}).status,"BLOCKED","five physical trade slots forbidden")
local stacked=run({alt({slot("Harvester",5)},{slot("Gingerscope")})},
 {Harvester=5})
eq(stacked.hypotheticalAlternatives[1].status,
 "BLOCKED_UNVERIFIED_STACK_PRICE","five stacked copies uncertain")
eq(stacked.hypotheticalAlternatives[1].outgoingSupremeListedValue,
 1375,"five copies use Supreme only hypothetical total")
eq(run({alt({slot("UnknownCopy")},{slot("Harvester")})}).status,
 "BLOCKED","unknown weapon denied")
eq(run({alt({slot("Harvester")},{slot("Harvester")}),
         alt({slot("Harvester")},{slot("Harvester")})}).status,
 "BLOCKED","repeated alternatives blocked")
eq(run({alt({slot("Harvester",2)},{slot("FlowerwoodKnife")})}).status,
 "BLOCKED","insufficient ownership")
eq(run({valid},{Harvester=1},TIME).status,
 "SUPREME_ONLY_NATIVE_RESEARCH_NOT_EXECUTABLE","small owned census")
local s=fs.readFile("pdiddler/system2/native_supreme_only_bilateral_research.lua")
yes(string.find(s,"mm2Listed",1,true)==nil,"no dual-value source in native evaluator")
yes(string.find(s,"mm2Value",1,true)==nil,"no alternate publisher value in native evaluator")
yes(string.find(s,"FireServer",1,true)==nil,"no game remotes")
yes(string.find(s,"InvokeServer",1,true)==nil,"no game remote calls")
yes(string.find(s,"PostAsync",1,true)==nil,"no outbound webhook")
print("SUPREME_ONLY_NATIVE_LUA_MOCKS_PASS assertions="..tostring(n))
