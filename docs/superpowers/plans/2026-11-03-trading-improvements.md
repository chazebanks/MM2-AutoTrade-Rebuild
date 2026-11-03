# Pdiddler trading improvements implementation plan

Goal: deliver a separate reviewed build that addresses the audited correctness
defects and implements the user's Supreme/+15/timing requirements within the
requested resource budget. Preserve every frozen source and the V3 loader.
Spec: [archived complete trading proposal](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/blob/docs/pdiddler-trading-research-2026-11-03/docs/superpowers/specs/2026-11-03-pdiddler-supreme-auto-trading-design.md)

Architecture: extend the identity-corrected nonadaptive P4 in a new version,
use one Supreme pricing/profile adapter and one strict decision engine; retain
one outgoing owner and P5 transport. Acceptance remains a separately verified
native-control path. Code is tested headlessly; Delta behavior is not presumed.

Constraints: strict Supreme profit >=15; no loss upgrades; 12s resetting empty
timer; 5s negotiation/final wait; nonresetting60s backstop; exact identities and
quantities; no guessed prices, repeated requests or competing controllers.

1. Tests first for outgoing tablet layout/identity and per-server ownership;
   create v16 without altering v15. Delegate this independent component once.
2. Retrieve exact later baseline dependencies using GitHub; create a dated
   validated Supreme snapshot with exact canonical mappings and source metadata.
   Tests first for finite prices, unknown/Priceless rejection and +14/+15 boundary.
3. Extend P4 in new files: exact partner/item/quantity guards and post-yield
   revalidation; strict pricing/planner; timers and bounded negotiation.
4. Add/test acceptance and completion controls only when verified by isolated
   native-UI fixtures. Reuse completion correlation, fix unverified totals and
   ambiguous webhook retry. Any functionality not safely completed must remain
   explicitly disabled and documented rather than claimed done.
5. Add a new immutable loader, run existing58 regressions plus new suites,
   independent whole-change review, document remaining Delta uncertainties, and
   open a PR without merging. Save implementation notes on GitHub.

Review focus: a stale session after inventory yield; inactive phone UI masking
tablet UI; raw/checker identity contradiction; unknown quantities; native accept
changes during extra1s; late completion events; lost webhook acknowledgments.

Execution choice: primarily inline, one independent component implementer and
one whole-change reviewer to limit context/credit overhead. No new paid search.
The user authorized improvements; no additional design/permission loop is needed.
