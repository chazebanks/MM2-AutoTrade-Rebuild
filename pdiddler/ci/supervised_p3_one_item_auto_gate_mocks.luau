-- Runs the actual pure one-shot ALT-only preauthorized trade gate.
-- No native Roblox remotes; exact trade root is a mock instance identity.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local gate=luau.load(fs.readFile(
 "pdiddler/supervised/supervised_p3_one_item_auto_gate.lua"),
 {injectGlobals=true})()
local n=0
local function eq(a,b,msg)
 n+=1
 assert(a==b,tostring(msg)..": "..tostring(a).." ~= "..tostring(b))
end
local function fixture(overrides)
 overrides=overrides or {}
 local st={job="JOB",time=12,live=true,armed=false,alt=2,
  root={},callback=0,preview="READY_FOR_HUMAN_TAP"}
 local pilot={
  preview=function()
   st.previews=(st.previews or 0)+1
   return {status=st.preview,authorizesAccept=false,
     serverCompletionProven=false}
  end,
  execute=function() error("Auto gate cannot call protected offer directly")end,
 }
 local authorization={
  origin="PICKER_HUMAN_APPROVED_AUTO_ONE",
  explicitOneAutomaticPlacement=true,
  singleConsentingAltOnly=true,
  finalAcceptMustRemainManual=true,
  job="JOB",altUserId=2,
  rawKey="Iceblaster",display="Iceblaster",chroma=false,issuedAt=10,
 }
 for k,v in pairs(overrides)do authorization[k]=v end
 local env={
  getJobId=function()return st.job end,
  now=function()return st.time end,
  isLive=function()return st.live end,
  isArmed=function()return st.armed end,
  isExactAlt=function(uid)return st.alt==uid end,
  getTradeRoot=function()return st.root end,
  onTrigger=function(raw,display,chroma,root)
   st.callback+=1
   st.last={raw,display,chroma,root}
   return st.launchOk~=false
  end,
 }
 local g,receipt=gate.new(pilot,authorization,env)
 return st,g,receipt
end
do
 local st,g,r=fixture()
 eq(type(g),"table","valid prior human consent prepared")
 eq(r.status,"PREAUTHORIZED","no offer on construction")
 eq(r.authorizesAccept,false,"no automatic Accept")
 eq(st.callback,0,"no offers before observed verified window")
 st.armed=true
 eq(g.observe("P3_ROTATING").status,"WAITING","no trigger in rotation")
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").reason,
  "VERIFYING_STABLE_TRADE_WINDOW","first GUI observation only")
 eq(st.callback,0,"first GUI tick cannot trigger")
 st.time+=0.10
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,
  "WAITING","sub-threshold GUI stable time blocks")
 st.time+=0.10
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,
  "AUTO_ONE_ITEM_TRIGGERED","second stable GUI tick triggers one callback")
 eq(st.callback,1,"only one launch after stable exact client trade")
 eq(st.last[1],"Iceblaster","approved exact key")
 eq(st.last[4],st.root,"same observed root")
 for i=1,8 do
  st.time+=0.2
  eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,
   "SPENT","rerender never launches another offer")
 end
 eq(st.callback,1,"one total even with repeated callbacks")
end
do
 local st,g=fixture()
 st.armed=true
 g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT")
 st.time+=0.4
 g.observe("P3_ROTATING")
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"SPENT",
  "first observed trade ended: new trade cannot inherit preapproval")
 eq(st.callback,0,"no stale open-time or later-trade item send")
end
do
 local st,g=fixture()
 st.armed=true
 g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT")
 st.root={}
 st.time+=0.3
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"BLOCKED",
  "first verified trade root replacement permanently revokes prior consent")
 eq(st.callback,0,"root replacement never launches item")
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"SPENT",
  "replacement cannot become the next auto-offer candidate")
end
do
 local st,g=fixture()
 st.armed=true
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"WAITING",
   "first exact trade was seen but not yet stable")
 st.root=nil
 st.time+=0.3
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"BLOCKED",
  "lost first GUI root voids preapproval permanently")
 st.root={}
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"SPENT",
  "later GUI cannot revive a closed first trade")
 eq(st.callback,0,"lost first trade no offer")
end
do
 local st,g=fixture()
 st.armed=true
 g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT")
 st.time+=0.2
 st.alt=99
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"BLOCKED",
  "ALT replacement permanently consumes gate")
 st.alt=2
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"SPENT",
  "restored ALT cannot revive old consent")
 eq(st.callback,0,"ALT change no offer")
end
do
 local st,g=fixture()
 st.armed=true
 g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT")
 st.time+=181
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"BLOCKED",
  "three minute current client approval expires")
 eq(st.callback,0,"expired approval no offer")
end
do
 local st,g=fixture()
 st.armed=true
 g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT")
 st.time+=0.4
 st.preview="BLOCKED"
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"BLOCKED",
  "actual protected P3 lease preview must pass")
 eq(st.callback,0,"unsafe preview no offer")
end
do
 local st,g=fixture()
 st.armed=true
 g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT")
 g.stop()
 st.time+=0.4
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,"SPENT",
  "STOP is final")
 eq(st.callback,0,"stopped gate has no offer callback")
end
do
 local st,g=fixture()
 st.armed=true
 st.launchOk=false
 g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT")
 st.time+=0.3
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,
  "INCONCLUSIVE","refused queued launch does not signal success")
 eq(g.observe("P4_TWO_SIDED_CLIENT_SNAPSHOT").status,
  "SPENT","refused trigger never retried")
 eq(st.callback,1,"one attempted launch")
end
for _,invalid in ipairs({
 {origin="UNTRUSTED"},
 {explicitOneAutomaticPlacement=false},
 {singleConsentingAltOnly=false},
 {finalAcceptMustRemainManual=false},
 {job="OTHER_JOB"},
 {altUserId=0},
 {rawKey="Gingerscope"},
 {display="Gingerscope"},
 {rawKey="not allowed spaces"},
 {chroma="false"},
 {issuedAt=9999},
 {issuedAt=-200},
})do
 local st,g,r=fixture(invalid)
 eq(g,nil,"invalid permission/identity fails closed")
 eq(r.status,"BLOCKED","bad consent blocked")
 eq(st.callback,0,"invalid preconsent cannot offer")
end
print("[PASS] single ALT one-shot preauthorized P3 GUI gate:",n)
