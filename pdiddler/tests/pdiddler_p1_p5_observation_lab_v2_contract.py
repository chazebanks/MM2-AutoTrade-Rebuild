from pathlib import Path

p=Path("pdiddler/tests/pdiddler_P1_P5_OBSERVATION_LIVE_LAB_v2.lua")
assert p.exists(), "observation lab v2 missing"
s=p.read_text()

required=[
    "P1 + P5 OBSERVATION LIVE LAB v2",
    'P5_COMMIT="fa288984552e95fc13be01ec9c9b58bf7c9fb914"',
    'OBS_COMMIT="070301b2255c74d2de0f737b389d602cc0249476"',
    "pdiddler1_KNOWN_GOOD.lua",
    "pdiddler5_server_hopper_policy_v1.lua",
    "pdiddler5_server_hopper_v1.lua",
    "pdiddler_p1_p5_observation_policy_v1.lua",
    "pdiddler5_server_candidate_observer_v1.lua",
    "pdiddler_p1_p5_observation_gui_v1.lua",
    "part5.bootstrap(hopperPolicy)",
    "candidateObserverModule.new(hopperPolicy)",
    "pcall(p1.run)",
    "guiController:setBotRehop()",
    'hopper:handleBotRejected("part1-bot-rejected")',
    "observationPolicy.ObservationSeconds",
    'hopper:hopNow("p1-p5-observation-30s")',
    "onManualBotted=function(snapshot)",
]
for token in required:
    assert token in s, f"lab v2 missing {token}"

bootstrap=s.index("part5.bootstrap(hopperPolicy)")
part1=s.index("pcall(p1.run)")
assert bootstrap < part1, "P5 must bootstrap before Part 1 so bot rejection can re-hop"

assert s.count('hopper:hopNow("p1-p5-observation-30s")') == 1
manual_start=s.index("onManualBotted=function(snapshot)")
manual_end=s.index("end,", manual_start)
manual_block=s[manual_start:manual_end]
assert "hopNow" not in manual_block
assert "handleBotRejected" not in manual_block

for forbidden in [
    "pdiddler3_",
    "pdiddler4_",
    "AcceptTrade",
    "DeclineTrade",
    "OfferItem",
    "PDIDDLER_DISCORD_WEBHOOK",
    "45 seconds",
]:
    assert forbidden not in s, f"lab v2 must remain isolated: {forbidden}"

print("PASS P1 P5 observation lab v2 contract")
