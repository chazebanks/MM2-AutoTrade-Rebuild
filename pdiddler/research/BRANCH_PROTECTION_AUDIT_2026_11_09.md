# Branch protection / required CI gate — read-only audit (2026-11-09)

## Observed current configuration

- GET /repos/chazebanks/MM2-AutoTrade-Rebuild/branches/main:
  protected=false, protection.enabled=false, required_status_checks.contexts=[]
  and required_status_checks.checks=[].
- GET /repos/chazebanks/MM2-AutoTrade-Rebuild/rulesets: [].
- Direct branch-protection endpoint returned HTTP 403
  "Resource not accessible by integration"; this GitHub connector cannot
  independently read or change that privileged setting. This review
  made NO administrative change.
- The default branch retains seven baseline workflow files; the new
  Luau, Lune, Selene/StyLua, replay and Hypothesis workflows exist ONLY
  in separate, unmerged DRAFT PR131–PR135. None should be marked as
  a required main-branch check before their own CI definition lands.
- Multiple older stacked branches have known failing legacy jobs; requiring
  "all workflows" now would indefinitely block unrelated safety fixes.

## Recommended staged, manually approved adoption

1. Inspect GitHub repository Settings > Rules > Rulesets / Branches with
   an authorized administrator and inventory all inherited policies.
2. Independently review PR131, PR132 and PR133 (all branch CI green) and
   decide if/when their scoped jobs should be merged to main. Do not
   blindly merge outdated Stage69/73 trading source stacks.
3. After main has the selected workflows, run fresh branch and PR checks
   and verify exact stable job names and target-branch compatibility.
4. Only then propose required PR + status check restrictions, ideally on
   the small, consistently green gates, not the 19 known-legacy failing
   workflows or a path-filtered job that might not run for every PR.
5. Explicitly confirm effect on user direct commits, bot-generated market
   observation commits (research-only refresh), Copilot branches, draft PRs,
   and emergency safety fixes. Do not enable rules that silently stop
   scheduled source observations or block owner recovery.
6. Require user's separate authorization before mutating the repository
   protection/rulesets. The connected GitHub integration's 403 confirms
   that permission is also a technical blocker here.

## Current result

READ-ONLY AUDIT COMPLETE. No rule, status check requirement, branch,
workflow, merge strategy, price, auto trade/Accept or Discord learning
was changed. The absence of protection on main is observed from the
standard branch metadata and ruleset list, not from the forbidden detailed
protection endpoint. This is a proposed change-control process,
not a claim that branch protection is enabled.
