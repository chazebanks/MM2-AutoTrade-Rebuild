"""Pure research-only snapshot guard regressions; never trade or call Roblox."""
import copy
import importlib.util
import random
import shutil
import subprocess
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location('offer_guard',ROOT/'offer_snapshot_guard.py')
MOD=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
NOW=1794159000

def fixture():
    identity='INDEPENDENT_EXACT' # ONLY synthetic: no actual MM2 link proven
    entry=lambda v,d,s:{'value':v,'demand':d,'stability':s,'identityLinkEvidence':identity}
    catalog={'source':'SUPREME_DISPLAY_RESEARCH_ONLY','version':'SYNTHETIC-V1',
             'retrievedAtUnix':NOW-2,'publisherUpdatedAtUnix':NOW-200,
             'items':{'own':entry(100,5,'Stable'),'receive':entry(105,5,'Stable'),
                      'illiquid':entry(400,1,'Stable'),'falling':entry(250,10,'Declining'),
                      'stack':entry(60,8,'Stable')}}
    plan={'sessionId':'S-ABC','jobId':'J-123','partnerKey':'OPAQUE-EXACT','catalogVersion':'SYNTHETIC-V1',
          'offerRevision':17,'observedAtUnix':NOW-1,
          'ours':[{'index':1,'key':'own','quantity':1}],
          'theirs':[{'index':1,'key':'receive','quantity':1}]}
    seen={**copy.deepcopy(plan),'observedAtUnix':NOW,
          'tradeOpen':True,'exactPartnerBound':True,'ourAccepted':False,
          'theirAccepted':False,'offerMutationPending':False}
    return plan,seen,catalog

def must_never_authorize(out):
    for flag in ('exactItemIdentityAuthenticatedByGuard','serverCompletionProven',
                 'mayRecordCompletedTrade','mayReportProfit','mayUseForStrategyLearning',
                 'authorizesTrade','authorizesAccept'):
        assert out[flag] is False,(flag,out)
    assert out['tradeOutcome']=='UNKNOWN'

class OfferSnapshotGuardTests(unittest.TestCase):
    def test_small_plus_five_acceptable_no_legacy_plus_15(self):
        p,o,c=fixture();x=MOD.evaluate(p,o,c,now=NOW)
        self.assertEqual(x['status'],'RESEARCH_CANDIDATE_ONLY')
        self.assertEqual(x['projectedListedGain'],5)
        must_never_authorize(x)
    def test_stale_display_gain_invalidation_case(self):
        p,o,c=fixture();o['theirAccepted']=False
        o['theirs']=[];o['offerRevision']+=1
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'OFFER_REVISION_CHANGED')
        o['offerRevision']-=1
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'OFFER_SLOTS_UNREADABLE_OR_EMPTY')
        o['theirs']=[{'index':1,'key':'own','quantity':1}]
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'OFFER_SLOTS_CHANGED')
    def test_stacked_duplicate_quantity_and_four_slot_limit(self):
        p,o,c=fixture();p['ours']=[{'index':1,'key':'stack','quantity':2}]
        o['ours']=copy.deepcopy(p['ours'])
        p['theirs']=[{'index':1,'key':'receive','quantity':1},
                     {'index':2,'key':'stack','quantity':1}]
        o['theirs']=copy.deepcopy(p['theirs'])
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['projectedListedGain'],45)
        p['theirs']=[{'index':i,'key':'receive','quantity':1} for i in range(1,6)]
        o['theirs']=copy.deepcopy(p['theirs'])
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['status'],'REJECTED')
    def test_stability_and_liquidity_over_listed_gain(self):
        p,o,c=fixture();p['theirs'][0]['key']='illiquid';o['theirs'][0]['key']='illiquid'
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'RECEIVED_ITEM_LOW_DEMAND')
        p['theirs'][0]['key']='falling';o['theirs'][0]['key']='falling'
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'RECEIVED_ITEM_UNSTABLE')
    def test_catalog_freshness_source_identity(self):
        p,o,c=fixture();c['publisherUpdatedAtUnix']=None
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'PUBLISHER_TIMESTAMP_MISSING_OR_EXPIRED')
        p,o,c=fixture();c['items']['own']['identityLinkEvidence']='PROVISIONAL'
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'RAW_KEY_TO_DISPLAY_ID_UNVERIFIED')
        p,o,c=fixture();c['version']='SYNTHETIC-V2'
        self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['reason'],'MARKET_SOURCE_OR_VERSION_UNMATCHED')
    def test_accept_or_pending_offer_refused(self):
        for k,bad in (('ourAccepted',True),('theirAccepted',None),('offerMutationPending',True)):
            p,o,c=fixture();o[k]=bad
            self.assertEqual(MOD.evaluate(p,o,c,now=NOW)['status'],'REJECTED')
    def test_seeded_mutations_never_authorize_trade(self):
        rng=random.Random(6033)
        for i in range(2000):
            p,o,c=fixture()
            choice=i%16
            if choice==0:o['offerRevision']+=1
            elif choice==1:o['partnerKey']='OTHER'
            elif choice==2:o['jobId']='OTHER'
            elif choice==3:o['ours'][0]['key']='illiquid'
            elif choice==4:o['theirs'][0]['quantity']+=1
            elif choice==5:p['theirs'][0]['quantity']+=1
            elif choice==6:o['observedAtUnix']=NOW-9
            elif choice==7:c['publisherUpdatedAtUnix']=NOW-200000
            elif choice==8:c['items']['receive']['identityLinkEvidence']='UNPROVEN'
            elif choice==9:o['offerMutationPending']=True
            elif choice==10:o['ourAccepted']=True
            elif choice==11:o['exactPartnerBound']=False
            elif choice==12:o['tradeOpen']=False
            elif choice==13:p['ours'][0]['index']=2
            elif choice==14:c['items']['receive']['demand']=0
            elif choice==15:c['items']['receive']['value']=rng.randrange(1,95)
            x=MOD.evaluate(p,o,c,now=NOW)
            self.assertEqual(x['status'],'REJECTED',(i,x))
            must_never_authorize(x)
    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua 5.4")
    def test_actual_lua1600_mutations(self):
        proc=subprocess.run(["lua5.4",str(ROOT/"test_offer_snapshot_guard.lua"),
                             str(ROOT/"offer_snapshot_guard.lua")],
                            capture_output=True,text=True,timeout=60)
        self.assertEqual(proc.returncode,0,proc.stdout+proc.stderr)
        self.assertIn("MM2_OFFER_GUARD_LUA_1600_MUTATIONS_AND_NAMED_CASES_PASS",proc.stdout)

    def test_no_roblox_or_actions_authority_in_source(self):
        for path in (ROOT/'offer_snapshot_guard.py',ROOT/'offer_snapshot_guard.lua'):
            src=path.read_text()
            for forbidden in ('FireServer(',':InvokeServer(',':HttpGet(', 'setclipboard(',
                              'AcceptTrade', 'Webhook', 'requests.get(', 'TeleportToPlaceInstance('):
                self.assertNotIn(forbidden,src)
if __name__=='__main__':unittest.main()
