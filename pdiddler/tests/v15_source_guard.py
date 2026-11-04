"""Source-level regression fences for the isolated V15 negotiation policy.

Does not substitute for native MM2 tests. Run from repository root.
"""
from pathlib import Path

R=Path("pdiddler")
early=(R/"pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua").read_text()
p4=(R/"pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua").read_text()
loader=(R/"pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_OPPONENT_ADDED.lua").read_text()
wrapper=(R/"pdiddler_V15_TELEPORT_AUTOBOOT_v1.lua").read_text()

checks={
    "threshold floor": "MinNetAddition=10" in early,
    "threshold fraction": "MinAddedShare=0.05" in early,
    "half-new-value cap": "MaxShareOfAdded=0.50" in early,
    "cautious quarter target": "TargetShareOfAdded=0.25" in early,
    "verified opponent anchor": "cents(options.anchorTotal)" in early,
    "positive actual concession": "if concessionCents>0" in early,
    "early market and amount validation": "verifiedRisk(plan,theirs.rawTotal)" in early,
    "no same-value reward": "net-addition-below-threshold" in early,
    "P4 anchor from committed actual quote": "additionAnchor=theirFinal.rawTotal" in p4,
    "P4 opponent anchor supplied": "anchorTotal=additionAnchor" in p4,
    "P4 early plan only": 'planStage="early"' in p4,
    "P4 no time-driven plan stage": 'planStage="late"' not in p4,
    "P4 fail-closed unexpected late": 'return "time-concession-disallowed"' in p4,
    "P4 passes empty late candidates": 'negotiation,theirEval.signature,ourEval.rawTotal,{},os.clock(),' in p4,
    "P4 retains accepted safeguard": 'if localAccepted~=false then' in p4,
    "P4 retains +15 verification": 'finalDecision.ok' in p4 and 'tradeDecision(ourEval,theirEval)' in p4,
    "P4 retains exact actual offer check": 'planMatches(plan,ourFinal)' in p4,
    "P4 retains transaction reservation": 'MARKET_LOGIC.reserveOffer(' in p4,
    "P4 retains verified concession commit": 'MARKET_LOGIC.confirmConcession(' in p4,
    "P4 retains no-plan safety": 'if #plans==0 then' in p4,
    "P4 retains accepted-empty": 'timeAction=="accepted-empty"' in p4,
    "P4 retains bounded no-response timeout": 'MARKET_LOGIC.observe(timing' in p4,
    "loader pins versioned P4": 'pdiddler4_balancer_SUPREME_v9_OPPONENT_ADDED.lua' in loader,
    "loader pins versioned early": 'pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua' in loader,
    "loader preserves fixed V14 strict": 'pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua' in loader,
    "loader disables unverified auto accept": 'local approvedNativeContract=nil' in loader,
    "loader preserves webhook gate": 'local deliveryEnabled=I.lifecycle.capabilities.completion' in loader,
    "wrapper pins V15 integration": 'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_OPPONENT_ADDED.lua' in wrapper,
    "wrapper rejects running V14": 'PDIDDLER_INTEGRATION_V14_VERIFIED_WORKFLOW' in wrapper,
}
bad=[k for k,v in checks.items() if not v]
for key,result in checks.items():
    print(("PASS " if result else "FAIL ")+key)
if bad:
    raise SystemExit("V15 source regression FAILED: "+", ".join(bad))
print(f"PASS all {len(checks)} V15 source fences")
