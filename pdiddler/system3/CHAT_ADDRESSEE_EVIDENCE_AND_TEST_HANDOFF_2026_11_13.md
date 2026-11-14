# System 3 chat-negotiator addressee and active-partner verification (Nov 13 2026)
**Research-only, synthetic implementation. NO real chat read/send, auto-negotiation or final Accept permission.**

## New requirement
The user's in-game username has been provided privately, but do **not** hardcode any username into source or public tests. In a permitted client integration, obtain `Players.LocalPlayer.Name` and immutable `Players.LocalPlayer.UserId` from the Roblox engine. Similarly resolve current trade partner `Player.UserId` from the **already trusted active trade/session binding**; chat contents/display names alone cannot verify user identity.

**A speaker is not a recipient.** Messages from the currently trading counterpart in `RBXGeneral` may be aimed at someone else. The word "add" or "nty", the existence of a trade window, spatial proximity, or a recent item click do not prove addressee.

## Official Roblox source research
- [TextChatService](https://create.roblox.com/docs/reference/engine/classes/TextChatService): normal default whisper channel `RBXWhisper:UserId1_UserId2`, two participant `TextSource` objects; default `RBXGeneral` is a shared channel. Whisper can be initiated by `/w Username` in supported configurations.
- [TextSource](https://create.roblox.com/docs/reference/engine/classes/TextSource): read-only `UserId` identifies **sender**, while `Name` may be display name, which is not a unique account identifier.
- [Direct-chat permissions](https://devforum.roblox.com/t/integrate-textchatservicecanusersdirectchatasync-or-textchannelsetdirectchatrequester-api-to-comply-with-settings/3255672): whisper is direct, General and Team are **not direct**; user permissions must permit channels.
- [Platform-integrated chat](https://create.roblox.com/docs/chat/platform-integrated-chat) scheduled required May 2027: message content isn't available to scripts in that mode, rendering custom reader/autoreplier unavailable without an official permitted path. **Never bypass filtered or age-limited chat.**
- [TextChannel](https://create.roblox.com/docs/reference/engine/classes/TextChannel): `MessageReceived` and channel metadata are features of permitted chat environments; doesn't prove availability in MM2 / iPad Delta.
- [Chat guidelines](https://create.roblox.com/docs/chat/guidelines): respect platform filtering/privacy and user chat restrictions.

## Three-way recipient decision
1. **DIRECTED_RESEARCH_ONLY** for exact whisper channel whose **TWO UserIds** are local player and current active trade partner (in either order), or explicit validated username vocative / @mention **from current partner** in General with no conflicting addressee. Even this status is a **synthetic determination only**, not permission to send messages or change/accept offers; @mentions in visible text are weak because plain text can refer to someone rather than ask them to respond.
2. **LIKELY_TRADE_CONTEXT_UNPROVEN** for messages **from the active trade partner, in same job/lease/offer revision**, with recent verified offer change or prior specific message linkage, a trade-context phrase, **and no competing conversation**. They need not type our username. A public `add`, `nty` or `what for` without direct recipient channel is **never certain**. Can prepare a one-line *manual-review suggestion*, but `maySendChatAutomatically=false`.
3. **NOT_FOR_ACTIVE_TRADE / AMBIGUOUS_RECIPIENT / BLOCKED** for other players, other name mentions, multiple possible addressees, no plausible offer context, stale cross-session messages, wrong whisper pair, no chat permissions, filtered/empty text, duplicate IDs, or missing sender information. No auto reply or negotiation intent learning.

## Implementation and test contract
- `pdiddler/system3/message_addressee_gate.py` is a **pure offline Python gate**, strict `SYNTHETIC_` structured caller supplied objects and denied live action flags.
- Requires active trade partner `UserId`, local verified username **in future live wrapper**, job ID, trade lease, offer revision, recent event timing, message ID, source channel, sender `UserId`, competing chat signal, and channel/text eligibility; no hardcoded real username, no raw conversation logging to public repo.
- A proper **whisper pair** is the strongest technical directedness signal. `@name` with validated source sender in General can be a candidate but will require additional context before any future automatic reply implementation. For general chat **without the username**, current session and context may only reach `LIKELY_TRADE_CONTEXT_UNPROVEN`.
- `pdiddler/ci/test_system3_message_addressee_gate.py`: 39 adversarial cases: username and @mention, whisper channel participants, reversed whisper order, private whisper to third party, multiaddressee, name cited in third person, forged display names, chat from another player, unaddressed `add`, `nty`, offer item references, competing conversations, stale job/lease/revision, duplicate event, message before trade, chat API unavailable, unsupported team/system channel and runtime identity config.
- GitHub workflow `gingerscope-system3-addressee-gate.yml` runs **39 new synthetic tests + 275 inherited source-bound tests = 314 expected**; original frozen Stage83, PR106 planner and corrected PR182 guard must still SHA-match. Verify actual exact-head result before claiming success.

## Hard blockers before any native chat negotiator
1. Determine whether game currently exposes **permitted raw message content**, source UserId and channel identity. In platform-integrated mode raw text isn't available to scripts and must not be read by UI scraping or other bypasses.
2. Bind actual partner identity/lease, channel sender, message ID and offer revision through a trusted live path, not caller-supplied strings. In-game open trade alone isn't proof public chat message is addressed to local account.
3. Separate recipient attribution from **language interpretation**, market proposal, player preference learning, and **real completion**. Mere `yes`/chat text is never final Accept; private chats and other players should not be archived as learning data.
4. For public chat without explicit addressee, a 100% guarantee is not available. Continue to abstain from automatic chat, and use manual-suggestion mode or permitted direct whispers as a more reliable channel.
5. Do not revive obsolete fixed +15 rule, maximum observed overpay ceiling, highest-valued mandatory opener, uncontrolled loss, or outbound Gingerscope. System2 source authenticates only archived research source; no native offer/Accept authority.

**Separation:** System 3 handles chat interpretation/offer intent; System 1 handles session identity and execution; System 4 handles bounded learning only from correctly attributed observations; System 5 orchestrates. Current draft PR work is additive research-only.
