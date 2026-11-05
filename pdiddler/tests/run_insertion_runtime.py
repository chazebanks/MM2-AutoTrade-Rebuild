"""Exercise complete baseline P4v10 or value-first P4v11 with the same policy10.

--safety/--strategy/--inherited run unchanged Issue27/Issue28/Issue19 cases.
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
baseline = '--baseline' in sys.argv
p4 = ('pdiddler4_balancer_SUPREME_v10_IMMEDIATE_SAFETY.lua' if baseline
      else 'pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua')
policy = 'pdiddler4_supreme_policy_v10_INVENTORY_GROWTH.lua'
original = (ROOT/'pdiddler/tests/part4_runtime_test.lua').read_text()
fixture = original[:original.index('local function test(name,fn)')]

def patch(old, new):
    global fixture
    assert fixture.count(old) == 1, old
    fixture = fixture.replace(old, new)

patch('node("Container","Frame",ours); node("Container","Frame",theirs)',
      'node("Container","Frame",ours); node("Container","Frame",theirs); node("Accepted","Frame",ours,{Visible=false})')
patch('f.task={}', 'f.removeEvents={}; f.declineEvents={}; f.offerEvents={}; f.plannerEvents={}; f.waitEvents={}; f.mouseDownEvents={}; f.statusEvents={}; f.requestEvents={}\n    f.task={}')
patch('function f.task.wait(dt) return coroutine.yield(dt or .01) end', '''function f.task.wait(dt)
        f.waitEvents[#f.waitEvents+1]={at=f.now,dt=dt or .01,total=f:total()}
        if f.onWait then f.onWait(dt or .01) end
        return coroutine.yield(dt or .01)
    end''')
patch('f.offers=f.offers+1', '''f.offerEvents[#f.offerEvents+1]={at=f.now,id=id}; f.offers=f.offers+1
        if f.beforeOffer then f.beforeOffer(id) end
        if f.failOffer and f.failOffer(id) then error("fixture-native-offer-failed") end
        if f.ignoreOffer and f.ignoreOffer(id) then return end''')
patch('function f:render(side,picks)', '''function f:render(side,picks)
        if side=="YourOffer" and self.delayOwnRender then return end''')
patch('function decline:FireServer() f.declines=f.declines+1; f.root.Visible=false end',
      'function decline:FireServer() f.declineEvents[#f.declineEvents+1]={at=f.now,total=f:total()}; f.declines=f.declines+1; if not f.ignoreDecline then f.root.Visible=false end end')
patch('''        if not pressed then
            local last=f.ourPicks[#f.ourPicks]
            if last then last.qty=last.qty-1; if last.qty==0 then table.remove(f.ourPicks) end end''', '''        if pressed then
            f.mouseDownEvents[#f.mouseDownEvents+1]={at=f.now,total=f:total()}
            if f.onMouseDown then f.onMouseDown() end
        else
            f.removeEvents[#f.removeEvents+1]={at=f.now,total=f:total()}
            local last=f.ourPicks[#f.ourPicks]
            if last and not f.ignoreRemove then last.qty=last.qty-1; if last.qty==0 then table.remove(f.ourPicks) end end''')
patch('setStatus=function() end,claimStatusOwner=function() end,releaseStatusOwner=function() end,setRequestState=function() end',
      'setStatus=function(text) f.statusEvents[#f.statusEvents+1]={at=f.now,text=text} end,claimStatusOwner=function() end,releaseStatusOwner=function() end,setRequestState=function(player,state,extra) f.requestEvents[#f.requestEvents+1]={at=f.now,state=state,extra=extra} end')
patch('function f:start() self.module=NEW_PART4(self); self.controller=self.module.run(self.scanner,self.profile,POLICY,POLICY,self.telemetry); return self.controller end', '''function f:start()
 self.profile.version=self.profile.version or "fixture-prices"
 self.lifecycle=LIFE.new({native=self.native,verifier=self.verifier,policy=self.policy or POLICY,outbox=self.outbox,jobId=self.game.JobId,profile=self.profile,now=function() return self.now end,
  onHold=function(reason) if self.telemetry.holdOutcome then self.telemetry.holdOutcome(reason) end end})
 self.telemetry.lifecycle=self.lifecycle
 self.module,self.boundRead=NEW_PART4(self)
 local gate=self.gate or {read=function() return "unknown" end,step=function() return false end}
 self.controller=self.module.run(self.scanner,self.profile,self.policy or POLICY,self.policy or POLICY,self.telemetry,gate,self.early or EARLY)
 return self.controller
end''')
def read(name): return (ROOT/'pdiddler'/name).read_text()
# Read-only access to the real closure for assertions; no production branch is changed.
p4_source = read(p4)
head, marker, tail = p4_source.rpartition('return M')
assert marker and not tail.strip(), 'expected final module return'
p4_source = head+'return M,function() return BOUND end'+tail
bundle = ''
for var, name in [('POLICY',policy),
                  ('EARLY','pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua'),
                  ('VERIFICATION','pdiddler_trade_verification_v2.lua'),
                  ('OUTBOX','pdiddler_webhook_outbox_v3.lua'),
                  ('LIFE','pdiddler_trade_lifecycle_v1.lua'),
                  ('SOURCE','snapshots/pdiddler_supreme_snapshot_2026_11_04.lua')]:
    bundle += 'local '+var+'=(function()\n'+read(name)+'\nend)()\n'
bundle += '''local function NEW_PART4(f)
local game,task=f.game,f.task
local os={clock=function() return f.now end}
local function getgenv() return f.env end
local function print() end
local function warn() end
'''+p4_source+'\nend\n'+fixture
assert sum(flag in sys.argv for flag in ('--safety','--strategy','--inherited')) <= 1, 'choose one inherited suite'
suite = ('issue19_runtime_test.lua' if '--inherited' in sys.argv else
         'issue27_runtime_test.lua' if '--safety' in sys.argv else
         'issue28_runtime_test.lua' if '--strategy' in sys.argv else 'insertion_runtime_test.lua')
assert not ('--jobid-investigation' in sys.argv and suite!='insertion_runtime_test.lua'), 'JobId investigation is separate from inherited suites'
bundle += 'local JOBID_INVESTIGATION='+('true' if '--jobid-investigation' in sys.argv else 'false')+'\n'
bundle += (ROOT/'pdiddler/tests'/suite).read_text()
compiler = os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile') or '/tmp/pdiddler-luau/luau-compile'
luau = os.environ.get('LUAU_BIN') or shutil.which('luau') or '/tmp/pdiddler-luau/luau'
with tempfile.TemporaryDirectory(prefix='pdiddler-insertion-runtime-') as td:
    path=Path(td)/'runtime.luau'; path.write_text(bundle)
    subprocess.run([compiler,str(path)],check=True,stdout=subprocess.DEVNULL)
    subprocess.run([luau,str(path)],check=True,cwd=ROOT)
