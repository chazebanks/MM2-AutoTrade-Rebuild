# Delta audit reporting repair — automatic Exit still pending

The native screenshot contains exactly `[PDIDDLER DELTA UI AUDIT] control-inaccessible | native-exit-contract-unverified`. In the preserved V1 bootstrap this line is emitted only when either the HttpService lookup or JSONEncode throws. It is not evidence that Delta is inaccessible to Luau: the underlying report already found an exact console header and was cached before encoding. The screenshot does not expose the native exception or prove its precise cause.

The actual V1 module reproducibly produces invalid UTF-8 by cutting a multibyte GUI name at byte64. Arbitrary non-UTF8 Instance names are another possible input. This is a demonstrated encoder failure mechanism, not a claim that the exact device exception is known.

V2 renders names as printable ASCII with explicit byte escapes and uses a bounded, deterministic pure JSON formatter, removing the HttpService/JSONEncode dependency. Only known descriptor fields are projected; private editor/console bodies and unknown report fields are not copied. Literal backslash names remain distinguishable from byte escapes. The complete output is capped at16KiB; a compact explicit trace-size-budget report replaces an oversized descriptor set. Never interpret escaped paths as verified selectors.

The bootstrap can also recover the original same-JobId V1 cache when a running V15.8 bootstrap already owns this server. It verifies both the outer cache JobId and report JobId, prints once after a successful sink call, then returns the original owner. It performs no new GUI scan, controller launch, network fetch or teleport-queue operation in this recovery path. Cached evidence is explicitly historical: currentVisibilityVerified, captureTimeKnown and selectorsVerified are false. No timestamp was captured by V1, so its capture time is unknown.

## Use on the current server

Replace the old Auto Execute entry with the single DELTA_AUDIT_ENTRY.lua in this directory. Execute it once in the same server where V1 printed the fallback. If its cache survives, it should print a structured `[PDIDDLER DELTA UI AUDIT]` JSON line marked `cached-v1` without restarting or interrupting a trade. Copy the full line for analysis of the actual owner/control descriptors.

A same-server replay does not replace an already queued immutable V1 bootstrap. For a clean new-join V2 assessment, restart Delta/Roblox with only the updated Auto Execute entry configured. That produces `fresh-v2` before the original two pinned launches. The wrapper queues its own same immutable URL for subsequent hops. No active trader is restarted; if the old bootstrap has no matching V1 cache, it safely returns without a new audit. Do not repeatedly run competing entries.

## Limits

Automatic Exit has not been implemented. The screenshot identifies a bottom-right door/right-arrow icon below the console tab. A visual match does not establish a Luau Instance or supported native bridge. No tap, signal firing, destruction or GUI visibility mutation is attempted, and the MM2 eligibility scanner is preserved. Use that Exit manually until the actual control is verified. No improved trade acceptance rate or end-to-end native closure is claimed.

All474 PR33 predecessor files are byte-identical, including P3, P4, P5, bot detection, startup, value-first insertion, strategy and all original runtime pins. Native final Accept and completed-trade Discord remain disabled. The unchanged V15.8 loader is pinned at3daded63893a9165ad6b2a65fcbbf507f1afc571. The Supreme snapshot still expires2026-11-05 21:55:32UTC /4:55:32PM EST; this reporting patch does not refresh or extend prices.
