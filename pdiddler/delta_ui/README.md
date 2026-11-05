# Issue32 — native accessibility evidence still required

**Automatic Delta console/sidebar closure is not implemented or verified.** This is a read-only first-stage investigation for the user's2.743.1136.ipa build. The user confirms that build has no Hide GUI setting. Issue32 remains open.

The supplied recording establishes that the bottom-right door/arrow Exit action manually hides both Delta consoles and the right toolbar while the operational MM2 scanner remains visible. It does not identify a Luau Instance, control path, callback or supported native hide API. This workspace has no connection to the user's iPad process.

Repository inspection found generic gethui/CoreGui use for scanner/MM2 UI, but no verified Delta-specific Exit selector or UIKit bridge. Public research did not establish a supported close API for this build. A third-party [UIKit description](https://deltaios.us/how-it-works) has uncertain provenance and inaccurate/outdated technical details; it is not proof of this build's interface. A public [UI Remover](https://scriptblox.com/script/Universal-Script-UI-Remover-46168) guesses executor roots and destroys GUIs, with failure reports. It was inspected as text only, never executed or copied as a closer. Neither source supports safe automatic Exit.

## What this entry does

The new audit bootstrap embeds the exact tested audit module. Once per clean JobId, before the original V15.8 native probe and loader, it reads available gethui/CoreGui/PlayerGui roots. It records only exact Roblox Console/Delta Console headers, their nearest ScreenGui ownership, effective visibility and bounded candidate-button descriptors. Geometry describes observed Instances; it is never used to click.

The scan uses a2048-node/.10-second cooperative budget and bounded parent traversal. Native property/API calls themselves are not preemptible, so this is not a native latency guarantee. No additional wait, polling task or HTTP fetch is added. Duplicate roots are deduplicated without discarding owner ancestry. Active P3/P4 ownership suppresses inspection. Same-job duplicate Auto Execute retains the original single owner; each new job can produce one snapshot.

There are zero mouse/touch/key inputs, remote calls, signal firings or GUI mutations in the audit. It never destroys, disables or hides any GUI, and never reads TextBox contents or logs arbitrary console-body text. Source paths/names are bounded and URL/webhook-like names are redacted. The standard log line contains a JSON-safe report; the report is also cached under PDIDDLER_DELTA_UI_AUDIT_V1.

## How to collect the native evidence

1. Replace the previous Delta Auto Execute entry with the single immutable DELTA_AUDIT_ENTRY.lua. Fully restart Delta/Roblox before the clean join so a previously queued V15.8 bootstrap cannot claim ownership first. The code does not clear the executor's global teleport queue.
2. Leave Delta's console panels and sidebar visibly open when Auto Execute runs. Copy the line beginning `[PDIDDLER DELTA UI AUDIT]` and provide it with whether both panels/sidebar were visible at inspection time.
3. The unchanged V15.8 startup continues after the audit. This diagnostic adds no trade safety hold and does not cure the obstruction. Use the known bottom-right Exit manually after recording the trace, before trade handling begins. The settings workaround is unavailable in this reported build.
4. The original V15.8 queue re-entry behavior remains. Further clean server joins run one audit before the same loader. Missing output in a job already owned by an earlier entry is not evidence of UI inaccessibility; restart with only the new entry enabled.

`overlay-unavailable` means no exact headers were observed under the available scan budget and roots. It does not mean already closed, or prove native UIKit. `control-inaccessible` means header/candidate evidence was found but an actual native Exit contract remains unverified. Partial roots, truncation and visibility uncertainty are explicit. `closeSupported=false` and `actions=0` are always true for this stage. A candidate named Exit is not authorization to invoke it.

## What must happen before a closer can be enabled

The actual iPad trace must identify the interface and real Exit control, or establish that the interface is outside the accessible Luau tree. A subsequent closer needs a confirmed semantic target and fresh identity/visibility/geometry/ownership checks, bounded input only while that exact overlay is present, and verification that both panels plus sidebar hide while the launcher/scanner remain usable. A native trial must then show automatic hide and successful incoming-request decline. Offline fixtures cannot prove either.

Until that evidence exists, the supported workaround is the user's manual bottom-right Exit. No coordinate-only fallback, guessed internal API, random Activated signal or blanket CoreGui operation is included. If this interface is native and no supported bridge exists, Luau automatic closure must remain unsupported rather than be advertised as fixed.

## Preserved trader and limits

All455 files from PR31 head15bc3a29c3f1f0dc298b8171924082050c5e5f06 remain byte-identical. The original loader pin3daded63893a9165ad6b2a65fcbbf507f1afc571 and its20 dependencies remain unchanged, including value-first P4, strategy, scanner, P2, bot detection and server hopping. The audit wrapper preserves the original KEY/URL_KEY, ownership guards, queue logic and two source launches.

Prices retain the fixed November5,2026 21:55:32UTC /4:55:32PM EST expiry; no refresh or extension occurred. Automatic final Accept and completed-trade Discord remain disabled. This investigation does not establish automatic overlay closure, successful native declines, improved acceptance or completed inventory gains.
