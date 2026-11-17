-- Actual Lune Luau module test: no invented raw IDs or second Delta Execute.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local path="pdiddler/system2/native_supreme_only_current_offer_button.lua"
local native=luau.load(fs.readFile(path))()
local n=0
local function eq(a,b,label)
 n+=1
 assert(a==b,tostring(label).." : "..tostring(a).." ~= "..tostring(b))
end
local function yes(a,label)n+=1;assert(a,label)end
local function copy(x)return serde.decode("json",serde.encode("json",x))end
local base={
 clientOnly=true,contextOK=true,tradeOpen=true,rootBound=true,
 doubleReadStable=true,clientRawCaptureSignature="O:Harvesterx1|T:Flowerwoodx2",
 jobId="ORIGINAL_JOB_NOT_FOR_OUTPUT",tradeLeaseId="PROTECTED_LEASE_NOT_FOR_OUTPUT",
 partnerUserId=777888991,ourAccepted=false,theirAccepted=false,
 ourSlots={{slot=1,rawId="Harvester",rawIdObserved=true,label="Harvester",amountText="",chromaTag=false}},
 theirSlots={{slot=1,rawId="FlowerwoodKnife",rawIdObserved=true,label="Flowerwood",amountText="x2",chromaTag=false}},
}
local guard=true
local calls={}
local offer=copy(base)
local evaluateResult={
 schema="gingerscope-system2-original-p3p4-supreme-only-adapter-v1",
 status="SUPREME_ONLY_PROTECTED_C3_P4_SHADOW_OBSERVED",
 valueSource="SUPREME_ONLY",authorizesTrade=false,
 authorizesOffer=false,authorizesAccept=false,
 mayReportProfit=false,mayUseForStrategyLearning=false,
 hypotheticalAlternatives={{status="SUPREME_ONLY_PAPER_RESEARCH_NOT_EXECUTABLE",
  outgoingSupremeListedValue=275,incomingSupremeListedValue=470,
  supremeListedGain=195,tradeActionable=false}},
}
local afterEvaluation=nil
local function configure()
 calls={reads=0,evaluations=0,options=nil}
 return native.new({
  isBound=function()return guard end,
  readFrame=function()
   calls.reads+=1
   return copy(offer)
  end,
  evaluate=function(options)
   calls.evaluations+=1
   calls.options=copy(options)
   if afterEvaluation then afterEvaluation() end
   return copy(evaluateResult)
  end,
 })
end
local widget,err=configure()
yes(widget~=nil,"module ready "..tostring(err))
local out=widget.preview()
eq(out.status,"SUPREME_ONLY_CURRENT_OFFER_CLIENT_PREVIEW","valid exact GUI")
eq(out.valueSource,"SUPREME_ONLY","only publisher")
eq(out.listedDelta,195,"listed gain label no profit")
yes(string.find(out.display,"275 -> 470 (+195)",1,true)~=nil,"value visible")
eq(out.authorizesTrade,false,"no trade")
eq(out.authorizesOffer,false,"no offer")
eq(out.authorizesAccept,false,"no Accept")
eq(out.mayReportProfit,false,"no Discord profit")
eq(out.mayUseForStrategyLearning,false,"no learning")
eq(calls.reads,2,"read bound GUI before and after valuation")
eq(calls.evaluations,1,"single evaluation")
eq(calls.options[1].kind,"HYPOTHETICAL_RESEARCH_ONLY","read only route")
eq(calls.options[1].give[1].id,"Harvester","real outbound P4 raw id")
eq(calls.options[1].receive[1].id,"FlowerwoodKnife","real incoming P4 raw id")
eq(calls.options[1].receive[1].quantity,2,"physical stack x2")
local public=serde.encode("json",out)
for _,private in ipairs({"ORIGINAL_JOB_NOT_FOR_OUTPUT","PROTECTED_LEASE_NOT_FOR_OUTPUT",
 "Harvester","FlowerwoodKnife","777888991"}) do
 yes(not string.find(public,private,1,true),"does not export identity")
end
guard=false
widget=configure()
eq(widget.preview().reason,"ORIGINAL_P3_P4_LEASE_UNAVAILABLE","closed lease")
eq(calls.reads,0,"do not capture if unbound")
eq(calls.evaluations,0,"do not value if unbound")
guard=true
offer=copy(base);offer.ourSlots={}
widget=configure()
eq(widget.preview().reason,"BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY","our empty blocks")
eq(calls.evaluations,0,"no phantom own offered item")
offer=copy(base);offer.theirSlots={}
widget=configure()
eq(widget.preview().reason,"BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY","their empty blocks")
offer=copy(base);offer.theirSlots[1].rawId=nil
offer.theirSlots[1].rawIdObserved=false
widget=configure()
eq(widget.preview().reason,"GUI_RAW_WEAPON_ID_OR_SLOT_NOT_PROVEN","missing raw id blocks")
offer=copy(base);offer.ourSlots[1].amountText="x0"
widget=configure()
eq(widget.preview().reason,"GUI_STACK_QUANTITY_UNVERIFIED","invalid stack zero")
offer=copy(base);offer.ourSlots[1].amountText="many"
widget=configure()
eq(widget.preview().reason,"GUI_STACK_QUANTITY_UNVERIFIED","invalid stack lexical")
offer=copy(base);offer.ourSlots[1].rawId="Gingerscope"
widget=configure()
eq(widget.preview().reason,"GINGERSCOPE_NEVER_OUTGOING","target never outgoing")
offer=copy(base);offer.theirAccepted=true
widget=configure()
eq(widget.preview().reason,"ACCEPT_INDICATOR_ALREADY_ACTIVE","accepted GUI cannot run")
offer=copy(base);offer.doubleReadStable=false
widget=configure()
eq(widget.preview().reason,"ORIGINAL_P4_FRAME_NOT_BOUND","double read mismatch")
offer=copy(base);offer.theirSlots[2]=copy(offer.theirSlots[1])
offer.theirSlots[2].slot=2
widget=configure()
eq(widget.preview().reason,"GUI_RAW_WEAPON_ID_OR_SLOT_NOT_PROVEN","duplicate raw same partner")
offer=copy(base)
afterEvaluation=function()offer.theirSlots[1].amountText="x3";offer.clientRawCaptureSignature="CHANGED" end
widget=configure()
eq(widget.preview().reason,"ORIGINAL_P4_GUI_CHANGED_DURING_PREVIEW","offer edited mid-evaluation")
afterEvaluation=nil
offer=copy(base)
afterEvaluation=function()guard=false end
widget=configure()
eq(widget.preview().reason,"ORIGINAL_P3_P4_LEASE_CHANGED_AFTER_EVALUATION","lease revoked after pricing")
afterEvaluation=nil;guard=true
evaluateResult.hypotheticalAlternatives[1].supremeListedGain=999999
widget=configure()
eq(widget.preview().reason,"SUPREME_QUOTE_ECONOMICS_OR_AUTHORITY_INVALID","forged valuation delta blocked")
evaluateResult.hypotheticalAlternatives[1].supremeListedGain=195
evaluateResult.authorizesAccept=true
widget=configure()
eq(widget.preview().reason,"SUPREME_CURRENT_OFFER_SOURCE_OR_EVALUATION_BLOCKED","evaluator must not authorize Accept")
evaluateResult.authorizesAccept=false
evaluateResult.hypotheticalAlternatives[1].status="BLOCKED_UNAPPROVED_SUPREME_LOSS"
widget=configure()
eq(widget.preview().status,"SUPREME_ONLY_CURRENT_OFFER_CLIENT_PREVIEW","negative risk still visible as blocked")
yes(string.find(widget.preview().display,"Listed loss NOT APPROVED",1,true)~=nil,"no false positive when loss")
evaluateResult.hypotheticalAlternatives[1].status="SUPREME_ONLY_PAPER_RESEARCH_NOT_EXECUTABLE"
local source=fs.readFile(path)
for _,word in ipairs({"FireServer","InvokeServer","PostAsync","TeleportService",
 "AcceptTrade","DeclineTrade","mm2Listed","mm2Values","getgenv"}) do
 yes(not string.find(source,word,1,true),"no gameplay or alternate valuation: "..word)
end
print("SUPREME_ONLY_INTRAGAME_PREVIEW_BUTTON_LUA_PASS assertions="..tostring(n))
