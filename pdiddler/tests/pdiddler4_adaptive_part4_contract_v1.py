from pathlib import Path

p=Path("pdiddler/pdiddler4_balancer_ROTATING_v2_5_ADAPTIVE_ACCEPTANCE.lua")
assert p.exists(), "adaptive Part 4 build missing"
src=p.read_text()

required=[
    "function M.run(scanner,marketProfile,marketLogic,marketPlanner,acceptancePolicy,tradeTelemetry)",
    "acceptancePolicy.OpenerObserveSeconds",
    "ADAPTIVE OPENER OBSERVE",
    "ADAPTIVE OPENER SKIP",
    "acceptancePolicy.selectOpener",
    "ADAPTIVE OPENER NONE",
    "acceptancePolicy.sweetenStep",
    "acceptancePolicy.rankSafePlans",
    "SWEETEN STEP",
    "APPEAL HOLD",
    "ourAcceptedShown",
    "MANUAL ACCEPT HOLD",
    "NoPlanNegotiationGrace=5.0",
    "EmptyTimeout=15.0",
    "ActiveOfferWindow=60.0",
    "RecoveryMaxAttemptsPerOffer=2",
    "expectedTheirSig=theirEval.signature",
    "offerGeneration+=1",
]
for token in required:
    assert token in src, f"missing adaptive Part 4 token: {token}"

assert "highestOwn(ownInv)" not in src, "highest-value-first opener must be removed"
assert "placing highest own item" not in src, "legacy opener status must be removed"
assert "task.delay(" not in src, "sweetening/opener must not use detached stale callbacks"

# Opener must observe THEM before selecting/mutating an opener.
observe=src.index("ADAPTIVE OPENER OBSERVE")
skip=src.index("ADAPTIVE OPENER SKIP")
select=src.index("acceptancePolicy.selectOpener")
fire=src.index('offer:FireServer(opener.id,"Weapons")')
assert observe < select < fire
assert skip < fire
assert "openerBoundaryTheir" in src[select:fire], "THEIR OFFER must be re-read immediately before opener fire"

# Accepted-empty remains an earlier explicit safety path than no-plan handling.
accepted_empty=src.index("THEY ACCEPTED WITH ZERO ITEMS")
no_plan=src.index("NO PLAN HOLD START")
assert accepted_empty < no_plan

# Sweetening must be signature/generation bound and reset on THEIR mutation.
sig_change=src.index("if theirEval.signature~=lastTheirSig then")
sweet_reset=src.index("sweetenSince=os.clock()",sig_change)
rank=src.index("acceptancePolicy.rankSafePlans")
assert sig_change < sweet_reset < rank
assert "sweetenGeneration=offerGeneration" in src
assert "sweetenGeneration~=offerGeneration" in src

# Manual local Accept must freeze voluntary mutation before planner execution.
manual=src.index("MANUAL ACCEPT HOLD")
assert manual < rank

for forbidden in [
    "AcceptTrade:FireServer",
    'physicalClick(button,"Accept',
    'physicalClick(button,"Confirm',
    "firesignal(",
    "getconnections(",
]:
    assert forbidden not in src, f"forbidden final-Accept mutation: {forbidden}"

print("PASS adaptive Part 4 contract")
