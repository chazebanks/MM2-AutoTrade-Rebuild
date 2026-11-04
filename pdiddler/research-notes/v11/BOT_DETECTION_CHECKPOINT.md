# V11 detector checkpoint — 2026-11-04

The frozen V5 scoring and thresholds remain the baseline. V6_VALID_EVIDENCE changes evidence validity and lifetime, not the scoring weights. No new behavioral signal or faster premature verdict is introduced. Normal/insufficient evidence remains PROCEED_UNVERIFIED, never a claim that a server is human.

## Root causes

- avatarData wrapped each description field read in pcall but ignored failure. With six older accounts and unreadable description fields, the original production scorer reports loaded6, identical cluster6, simple6, score95, bot=true. Partial/inaccessible fields must not become positive evidence. V6 requires readable core appearance fields, accessory fields and finite scale values. The singular/plural shoulder compatibility alias requires only one readable form. A character replaced during the description yield is rejected. This protects against a source-level false-positive mechanism; it does not prove the frequency of that condition in live MM2.
- Two positive snapshots could agree with each other but belong to a roster different from the final roster. Corroboration now also checks the current roster. The integration additionally requires the startup roster, exact generation and JobId, so results are never reused across server changes.
- The watchdog returned at ten seconds, but a blocked description worker could subsequently continue through the rest of the player list. Its scan loop now stops before and after each yielded avatar read once its generation has ended. A single native call already in progress cannot be cancelled by this check; its return is ignored.
- The animation diagnostic called absence sustained in two windows when only movement occurred in both. It now requires actual missing-track samples in both halves. Animation-only and partial evidence still cannot authorize a hop.

## Existing evidence and limits

The repository's FAST_GATE_V5_PART5_INTEGRATION_CHECKPOINT.md records only one labelled positive and one labelled negative success, not a confusion matrix. The Issue1 screenshot showing BOT_PATTERN_FOR_REVIEW followed by BOT_HOLD/request-ui-loading was a request-layout resolution bug, not evidence that classification missed the bot server; the working outgoing/request resolver is preserved. Account age, generated names, exact avatar clusters and simplified avatars can correlate with farms but cannot establish that each player is a bot. Missing animations can reflect replication or custom movement. No speculative extra signals or claims about false-positive/negative rates are added.

## Verification and release boundary

Eight tests run the entire new production gate in official Luau0.745 with mocked Roblox/scheduler boundaries: retained two-positive classification at10s; diverse avatars unverified; unreadable required fields rejected; hung calls cannot delay watchdog; stopped generations cannot publish; old-roster positives rejected; post-deadline workers cease further reads; two-window animation measurement corrected. A failing production-V5 test reproduced incomplete reads becoming bot evidence before the change.

Live iPad validation remains required: repeat known bot and real-player servers, note elapsed time/state/coverage, and record independent labels rather than trusting the detector to label itself. Verify no P3/P4 starts before the gate ends; only corroborated appearance positives use the existing P5 hop owner; unknown and animation-only outcomes proceed without claiming human classification. Loading readiness is a separate phase, not charged to or hidden inside the ten-second observation window.
