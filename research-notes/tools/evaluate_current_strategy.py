"""Offline research: reproduce PR14 policy counterexamples, never run Roblox actions."""
import argparse,hashlib,json,shutil,subprocess
from pathlib import Path
NOTES=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--runtime-root',required=True,type=Path,help='Exact PR14 b923481 checkout')
 parser.add_argument('--check',action='store_true',help='Compare derived files instead of writing')
 args=parser.parse_args()
 manifest=json.loads((NOTES/'CURRENT_STRATEGY_RUNTIME_SOURCES_2026-11-04.json').read_text())
 for row in manifest['sources']:
  data=(args.runtime_root/row['path']).read_bytes()
  actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
  assert actual==row['blob'],'Not the reviewed PR14 source: '+row['path']
 lua=next((shutil.which(x) for x in ('lua5.4','lua5.3','texlua','lua') if shutil.which(x)),None)
 assert lua,'Lua5.3/5.4 required for pure policy experiments'
 result=subprocess.run([lua,str(NOTES/'tools/compare_current_trader_v11.lua'),str(args.runtime_root.resolve())],capture_output=True,text=True,check=True)
 assert 'All six deterministic strategy experiments passed.' in result.stdout
 comparisons=[('early56_to85',94,65),('quote23_vs145',212,90),('old_quality60_vs10',90,40),('late_profit30_to20',30,20)]
 thresholds=[{'case':key,'old_conditional_profit':old,'new_conditional_profit':new,
 'required_completion_probability_ratio_equal_duration':old/new,
 'required_ratio_if_new_cycle_20pct_longer':old/new*1.2,
 'completion_probabilities_measured':False} for key,old,new in comparisons]
 data={'kind':'Offline source-level counterexamples and analytic break-even bounds; NOT a backtest',
 'runtime_commit':manifest['runtime_commit'],'market_input_date':'2026-11-03','research_date':'2026-11-04',
 'verified_completed_trade_sample_size':0,'acceptance_probability_estimates':None,
 'native_actions_executed':False,'fixture_type_and_raw_ids_are_synthetic':True,
 'cases':{
 'quote_gap':{'opponent_total':235,'inventory':[145,23],'with_add_given':23,'with_add_profit':212,
 'without_add_given':145,'without_add_profit':90,'late_reachable_from23':False},
 'equivalent_offer_edits':{'opponent_total_each':101,'start_given':7,'verified_policy_choices':[38,54,65],
 'conditional_profits':[63,47,36],'concession_total':58,'individual_early_cap':40,
 'meaning':'Per-signature limits hold; they do not impose a trade-wide40 budget'},
 'published_range':{'given':75,'received_base':90,'base_profit':15,'received_published_lower':85,
 'lower_scenario_profit':10,'published_lower_is_executable_bid':False},
 'quality_anchor':{'given':160,'received':195,'base_profit':35,'demand_before':3,'demand_received':1,
 'held_value_at_demand_ge3_before':160,'held_value_at_demand_ge3_after':0,
 'lower_demand_is_proven_slower':False},
 'equal_stats_pruning':{'given_each':33,'received':65,'profit_each':32,'candidate_count':1,
 'post_total':164,'selected_hhi':(99**2+65**2)/164**2,
 'discarded_alternative_hhi':(33**2+66**2+65**2)/164**2,'hhi_is_return_forecast':False},
 'absolute_floor':{'given':2,'received':7,'positive_gain':5,'safe_plans':0,'approved_floor_changed':False},
 'risk_metric':{'given_each':100,'profit_each':100,'selected_unstable_value_share':.9,
 'alternative_unstable_value_share':.1,'selected_copy_risk':1/3,'alternative_copy_risk':1/2,
 'market_offer':False}},
 'analytic_break_even':thresholds,
 'absolute_floor_friction':[{'our_offer_value':value,'minimum_their_value':value+15,
 'minimum_counterparty_overpay_relative_to_ours':15/value} for value in (2,5,10,15,20,50,100,250,500,1000,5000)]}
 outputs={NOTES/'CURRENT_STRATEGY_EXPERIMENTS_2026-11-04.json':json.dumps(data,indent=2)+'\n',
 NOTES/'CURRENT_STRATEGY_EXPERIMENT_RESULTS_2026-11-04.txt':result.stdout}
 for path,text in outputs.items():
  if args.check: assert path.read_text()==text,'Derived artifact differs: '+str(path)
  else: path.write_text(text)
 print('PASS three exact runtime blobs; six actual-policy experiments; seven recorded observations')
 print('PASS analytic thresholds, dated-input flags and no invented acceptance/completion statistics')
if __name__=='__main__':main()
