-- Stage29 actual post-close client inventory-only outcome tests.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local L=require("p4_stage29_postclose_ledger")
local cases=0
local function test(title,fn)
 local ok,why=pcall(fn)
 if not ok then error("FAILED "..title..": "..tostring(why)) end
 cases=cases+1
end
local A="godly:11:checker-id"
local B="chroma:12:checker-id"
local function inventory(a,b)
 local rows={}
 if a>0 then rows[#rows+1]={id="Mortal",page="godly",checkerId="11",name="Mortal",
   cat="Weapons",type="Knife",qty=a} end
 if b>0 then rows[#rows+1]={id="ChromaOther",page="chroma",checkerId="12",name="Chroma Other",
   cat="Weapons",type="Gun",qty=b} end
 return {fingerprint="Mortal:"..a.."|Other:"..b,
  rawOwned=a+b,items=rows,unmapped=0,badQty=0,unpriced=0}
end
local function fixture()
 local scope={session="S1",jobId="job-X",accountId=4,partnerId=5}
 local s=L.new(scope,10,{maxBeforeToClose=30,minPostGap=.75,maxPostAge=30})
 return s,scope
end
local function before(s,scope,inv,t)return L.before(s,inv,t or 10.1,scope)end
local function close(s,scope,t)return L.close(s,"CLOSED_UNKNOWN",t or 15,scope)end
local function after(s,scope,inv,t,serial)return L.after(s,inv,t,scope,serial)end

test("no actions or completion fields minted before scanner readings",function()
 local s,scope=fixture()
 local r=L.summary(s)
 assert(r.readbackCalls==0 and r.status=="AWAIT_BEFORE")
 assert(not r.authorizesTrade and not r.authorizesAccept)
 assert(not r.serverCompletionProven and not r.mayReportProfit)
end)
test("closed window + unchanged inventory does NOT prove decline",function()
 local s,scope=fixture()
 assert(before(s,scope,inventory(2,1))=="OBSERVED")
 assert(close(s,scope)=="OBSERVED")
 assert(after(s,scope,inventory(2,1),16,2)=="OBSERVED")
 assert(after(s,scope,inventory(2,1),17,3)=="NO_ELIGIBLE_DELTA_OBSERVED")
 local r=L.summary(s)
 assert(r.postReadbacksObserved==2 and r.changedEligibleTypes==0)
 assert(r.tradeOutcome=="UNKNOWN")
 assert(r.clientWindowClosureDoesNotProveDecline)
 assert(not r.mayRecordCompletedTrade)
end)
test("stable eligible delta cannot prove source of change",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 after(s,scope,inventory(1,2),16,2)
 assert(after(s,scope,inventory(1,2),17,3)=="ELIGIBLE_DELTA_UNATTRIBUTED")
 local r=L.summary(s)
 assert(r.changedEligibleTypes==2 and r.gainedEligibleCopies==1
  and r.lostEligibleCopies==1 and r.tradeOutcome=="UNKNOWN")
 assert(not r.mayReportProfit and not r.serverCompletionProven)
end)
test("distinct post reads disagree and cannot classify outcome",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 after(s,scope,inventory(1,2),16,2)
 assert(after(s,scope,inventory(2,1),17,3)=="POST_READS_DISAGREE")
 assert(L.summary(s).changedEligibleTypes==nil)
end)
test("raw weapon fingerprint change without eligible delta is distinct",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 local x=inventory(2,1);x.fingerprint="raw-added-classic-weapon";x.rawOwned=4
 after(s,scope,x,16,2)
 assert(after(s,scope,x,17,3)=="RAW_WEAPON_CHANGE_UNATTRIBUTED")
 assert(L.summary(s).changedEligibleTypes==0)
end)
test("one post read cannot establish even a client-level delta",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 after(s,scope,inventory(2,1),16,2)
 local r=L.summary(s)
 assert(r.status=="AWAIT_AFTER2" and r.changedEligibleTypes==nil)
end)
test("same-account and same-job required for each observation",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1))
 local bad={session="S1",jobId="job-Y",accountId=4,partnerId=5}
 assert(L.close(s,"CLOSED_UNKNOWN",15,bad)=="INCOMPLETE")
 assert(not L.summary(s).serverCompletionProven)
end)
test("different partner after closure invalidates inventory chain",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 local bad={session="S1",jobId="job-X",accountId=4,partnerId=6}
 assert(after(s,bad,inventory(2,1),16,2)=="INCOMPLETE")
end)
test("invalid GUI or job change is not a normal closure",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1))
 assert(L.close(s,"INVALID",15,scope)=="INCOMPLETE")
 assert(L.summary(s).postReadbacksObserved==0)
end)
test("before-to-close older than 30sec blocks",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1))
 assert(close(s,scope,45.2)=="INCOMPLETE")
end)
test("after read too late to attribute to same window",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 assert(after(s,scope,inventory(2,1),45.1,2)=="INCOMPLETE")
end)
test("two post reads must have a delay and strictly ascending sequence",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 after(s,scope,inventory(2,1),16,2)
 assert(after(s,scope,inventory(2,1),16.2,3)=="INCOMPLETE")
 local b,bs=fixture()
 before(b,bs,inventory(2,1));close(b,bs)
 assert(after(b,bs,inventory(2,1),16,3)=="INCOMPLETE")
end)
test("missing mapped weapons or invalid quantity fails closed",function()
 local s,scope=fixture()
 local inv=inventory(2,1);inv.unmapped=1
 assert(before(s,scope,inv)=="INCOMPLETE")
 local b,bs=fixture()
 local a=inventory(2,1);a.items[1].qty=true
 assert(before(b,bs,a)=="INCOMPLETE")
end)
test("duplicate identity or checker ID blocks delta proof",function()
 local s,scope=fixture()
 local inv=inventory(2,1)
 inv.items[2].page="godly";inv.items[2].checkerId="11"
 assert(before(s,scope,inv)=="INCOMPLETE")
end)
test("zero or empty raw weapon profile cannot masquerade as full scan",function()
 local s,scope=fixture()
 local inv={items={},fingerprint="",rawOwned=0,unmapped=0,badQty=0,unpriced=0}
 assert(before(s,scope,inv)=="INCOMPLETE")
end)
test("replaying before, close or post read cannot fabricate additional scans",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1))
 assert(before(s,scope,inventory(2,1))=="HOLD")
 close(s,scope)
 assert(close(s,scope)=="HOLD")
 after(s,scope,inventory(2,1),16,2)
 after(s,scope,inventory(2,1),17,3)
 assert(after(s,scope,inventory(2,1),18,4)=="HOLD")
 assert(L.summary(s).readbackCalls==3)
end)
test("all summaries contain no raw account, player, job, IDs, or fingerprints",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 after(s,scope,inventory(2,1),16,2)
 after(s,scope,inventory(2,1),17,3)
 local r=L.summary(s)
 assert(r.accountId==nil and r.partnerId==nil and r.jobId==nil)
 assert(r.session==nil and r.fingerprint==nil and r.items==nil)
 assert(r.authorizesAccept==false)
end)
test("source pricing independent: inventory evidence not a quote",function()
 local s,scope=fixture()
 before(s,scope,inventory(2,1));close(s,scope)
 after(s,scope,inventory(2,1),16,2)
 after(s,scope,inventory(2,1),17,3)
 local r=L.summary(s)
 assert(r.mayReportProfit==false and r.reviewOnly)
end)
test("eligible gain plus untracked weapon loss reports zero eligible losses",function()
 -- Hypothetical successful exchange: give one noneligible/common weapon,
 -- receive one eligible weapon. Stage29 only counts the eligible rows.
 local s,scope=fixture()
 local original=inventory(2,1)
 original.rawOwned=4 -- three eligible copies plus one excluded weapon
 original.fingerprint="eligible:2,1|excluded:1"
 local exchanged=inventory(2,2)
 exchanged.rawOwned=4 -- four eligible copies, excluded weapon gone
 exchanged.fingerprint="eligible:2,2|excluded:0"
 assert(before(s,scope,original)==="OBSERVED")
 assert(close(s,scope)==="OBSERVED")
 assert(after(s,scope,exchanged,16,2)==="OBSERVED")
 assert(after(s,scope,exchanged,17,3)==="ELIGIBLE_DELTA_UNATTRIBUTED")
 local r=L.summary(s)
 assert(r.gainedEligibleCopies==1 and r.lostEligibleCopies==0)
 assert(r.changedEligibleTypes==1 and r.rawWeaponInventoryChanged==true)
 -- Zero *eligible* losses must not be misread as zero total weapons given.
 assert(r.tradeOutcome=="UNKNOWN" and r.mayRecordCompletedTrade==false)
 assert(r.serverCompletionProven==false and r.authorizesAccept==false)
end)
print("PASS",cases,"Stage29 pure post-close own inventory ledger evidence")
