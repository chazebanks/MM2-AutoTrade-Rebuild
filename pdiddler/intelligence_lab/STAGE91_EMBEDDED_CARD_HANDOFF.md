# Stage91 — embedded exact-username card, ONE request-only input (draft)

## Native evidence (2026-11-09)

Actual Stage90 MAIN iPad report: `CARD_LAYOUT_OBSERVED`, `ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME`, one visible board, one alternative Trade control, one Profile/Trade card, one embedded username match, one nearby header match, zero direct Popup/Trade controls. 13 samples over two seconds; zero physical requests, offers, Accept, Decline or hop. This resolves the Stage89 zero-tap card **layout** mismatch. The user also provided a 36.6-second screen recording showing the blue Profile/Trade panel beside the selected username. The recording is local to the conversation and not committed or redistributed.

## Narrow code change

This branch is based on draft PR159's exact Stage89 request-only diagnostic, not old v18 rotating sender. New `pdiddler/new_part4/STAGE91_ONE_EMBEDDED_CARD_REQUEST.lua` retains one-target, one request, no retries and the real Stage87 scanner/contact-eligibility permit. It changes only the selected-card locator, adding the **Stage90-proven alternative embedded layout** with one unique Trade button, one nearby exact username in the same bounded non-leaderboard card ancestor, paired Profile control, visible geometry, current matching Player/UserId and final same-object/same-layout revalidation. A visible direct popup with a different username never falls back to another control. Wrong, distant, hidden, duplicated or board-only labels cannot authorize a click. A Stage91 test references the exact same synthetic direct and alternative layouts plus invalid cases. Source four fixed Git blobs remain unchanged.

**Important:** Neither Stage90 nor this code proves a physical request was delivered. Stage91 has an intentionally active `VirtualInputManager` one-tap path **only if** the user explicitly arms it with the alt username; it never auto-offers/Accepts, Declines, hops, reports profit or sends Discord. Even `CLIENT_PENDING_OBSERVED` is client-side evidence only. A missing pending UI remains UNCERTAIN and must never retry in the same job. Prices, game-server attestation, completed trade and strategy learning remain unauthorized.

## Test and next gate

Run pinned-source Lua5.4 mocks + Luau/Lune/style/replay/Hypothesis CI at the exact Stage91 head; do **not** ask user for a native request test until all relevant checks finish successfully. Preserve PR159 and PR160 separate, unmerged. Then a **single deliberate** native Stage91 test on a fresh original MM2 server, main iPad/Delta, Tablet mode, consenting alt `venossgaming90190` present, no other pdiddler scripts, open alt selected card *after* execution during the 20-second wait. The operator must choose to initiate that one request; never send it unattended.
