# Startup GUI and headless detector

User-authorized scope: fix pdiddler's missing startup GUI and remove the Fast Gate GUI. Keep the existing scanner panel, Tablet/friend selectors, detector evidence and trading controllers.

Root cause from the screenshot and loader: the main GUI is constructed by the scanner only after readiness, detector and price validation. Expired prices abort before the scanner is loaded, leaving no user-facing status. The screenshot is V14, not the refreshed V15.1 entry. Native Halloween EyeLeft errors originate in MM2 workspace scripts and are unrelated to this panel's construction.

Implementation:
1. Add runtime regressions for a visible early status panel, retained startup errors and holds, clean scanner handoff, no blocking input and no duplicate panel on repeat execution.
2. Reuse PR #22's headless derivative of V6 byte-for-byte. Run all existing full detector cases and prove it never needs PlayerGui or creates Instances; keep evidence version 6 because measurements are unchanged.
3. Add a V15.3 successor loader using the fresh November 4 profile and pinned headless detector. Create a compact passive startup panel as soon as PlayerGui exists. Keep status updates independent of readiness/trading. Hide it for scanner execution and destroy it after the scanner returns. On a pre-handoff failure restore the panel with the actual error. Route terminal holds after handoff through the existing scanner status API without stealing P4's status ownership.
4. Add a separately pinned V15.3 teleport bootstrap with old-owner exclusions, tests and exact fresh-session iPad instructions. Preserve all existing files, run the complete suite, publish a draft PR stacked on #22, and do not merge.

Alternative rejected: starting the scanner before price/readiness validation would run its scanning RPCs before prerequisites pass. Removing the detector would change bot/server-hopping behavior. Editing old pinned loaders would invalidate tested baselines. A small startup-only panel with a one-way handoff avoids these changes.

Limits: local fixtures verify lifecycle and Roblox API calls, not visual rendering or native iPad click-through. The dated profile still expires November 5, 2026 at 21:55:32 UTC; automatic price refresh is a separate task. Native Accept and Discord remain disabled under the existing evidence requirements.

Reconciliation: GitHub had a parallel PR #22 for headless V15.2. Its five files are preserved byte-for-byte; this branch incorporates that checkpoint as a merge parent and uses a unique V15.3 namespace/bootstrap. The earlier overlapping V15.2 GUI draft is superseded by the V15.3 entry. All 330 PR #22 files are protected by hashes.
