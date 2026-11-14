# Gingerscope System 3 — MM2 trader chat language: evidence-led research (Nov 13, 2026)

**Status: research inventory and test specification, NOT a trained/verified chat parser or permission to send messages.**
**User correction:** traders don't communicate through a small fixed command grammar. Research actual public exchanges and source provenance before designing an automated negotiator. The previous earlier explicit user request to cancel chat auto-responses is superseded by the NEW request to **consider** a negotiator, not live deployment authorization.

## Source quality and how to read this
- **Category A: user-generated MM2 negotiation examples** — actual Reddit MM2 trading post/reply conversations, dated. These show people negotiating *in comments/DM-planning*, **not exact in-game text chat transcripts** and not representative frequencies. No access to private MM2 player messages or real iPad chat in this study. URLs listed below.
- **Category B: MM2 community glossary** — useful candidate abbreviations only; some terms conflict and some sites mirror identical texts. Treat as **hypotheses**, not authoritative universal meanings.
- **Category C: Roblox primary official docs** — platform chat API, filtering, translation, privacy restrictions; these document capabilities, not how often any trader uses a phrase.
- **Category D: intentionally invented tests** — variants we should test for robustness. Marked SYNTHETIC, not claimed seen in MM2.
Do not infer the prevalence of any style or label a specific player 'greedy/stingy' from a message.

## Real public MM2 language patterns with sources

| Pattern | Public source/example (brief extracts/accurate paraphrases) | Interpretation / what not to assume |
|---|---|---|
| Minimal phrases and contractions | Oct 27 2026 exchanges: 'Nty', 'If you add', 'Sorry I don't want to add' | `nty` is a rejection *of some earlier proposed offer*, not global future rejection. `add` requires identifying **which side**. |
| Incomplete proposed bundles | Oct 27: 'Xenoset plus batwing for snowcannon and harvester' followed by refusal; Oct 23: 'immortal gun for treat and iceflake' then 'can u add' | Require explicit normalized offer direction and exact item keys, quantities, side. `for` can be from **writer's perspective**, not ours; chat alone doesn't prove ownership. |
| Bidirectional, sequential counteroffers | Oct 27: request 'if you add', reply conditioned on 'you also add red luger', then another alternative. | Track message sequence, offer **revision**, speaker; don't treat acceptance of past proposal as approval of revised one. |
| Public 'what for?' without response | June 2022 / Dec 2024 threads describe trade requests with no response, replies like 'idk offer', 'add', or silence. | Silence is not consent, unknown intent is normal, and timeouts must not turn into spam or forced value concessions. |
| Decline while praising offer | Aug 27: 'I'm sorry I'll pass good offer tho'; Mar 2026 'Good offer but I have harv and bat, so I'll have to pass' | Value isn't the only objection. Already owning the proposed item can explain a refusal; avoid permanently tagging user as price-stingy. |
| Correction after misnaming item | Aug 29: 'got snowcannon and snowstorm mixed up'; another offer amended 'I said it wrong the first time'. | Parse self-corrections; invalidate old named item until new exact ID confirmed. |
| Item shorthand ambiguity | Mar 2026 'hw?' → 'heartwand'; Feb 2025 'What is db?' → 'Darkbringer'; Apr 2025 'd cb' self-corrected to 'c db' (Chroma Darkbringer) | `hw` or `db` mappings need source and inventory context; `c db` is NOT plain Darkbringer; ask to clarify when multiple exact keys possible. |
| Excited, informal expressions | Real posts contain 'bet', 'mb', 'sry', 'np', 'lmk', emoji, informal capitalization | Negation and commitment can't be read from enthusiasm, emoji or single-word 'bet'; inspect explicit target offer and state. |
| Reference-site disagreements | Aug 2026 posts compare Supreme, MM2Values and Traderie; other posts say a proposed trade is an underpay and different value-list numbers. | 'fair' is a claim tied to a value source, source timestamp and side. Don't assume the other player's preferred list or fake current quotes. |
| Explicit lack of knowledge | July/Aug 2026 replies include 'idk values' / 'sorry don't know values'; some say 'I can add' | Under-knowledge does NOT mean someone is consenting to being exploited. Trade must still meet inventory-quality policy; respectful clarification first. |
| Collection/completion desires | Aug 2026: offers to complete a set; alternative swaps with multiple smalls | Distinguish request for set completion from listed-value preference, but only mark *candidate* preference with supporting repeated evidence. |
| Only some inventory is available | Sept 2026 trader corrects 'only godlies and harv/icewing are for trade'; old 2020 listing shows LF/NLF and 'insta-accept'. | A visible item is not proof willingness to offer it. `NFT`, `not trading`, `only X` are binding user declarations; do not assume every owned item is for sale. |
| Inadequate current chat permissions | Mar 2026 MM2 public exchange: user explicitly says they cannot chat because of Roblox update | Text-unavailable fallback must be normal, NOT treated as malicious silence or a bad negotiation style. |

### Representative firsthand links
- Multi-turn adding/values discussion (Oct 2026): https://www.reddit.com/r/MurderMystery2/comments/1xgepbj/lf_offers/
- Negotiation with unavailable preference/item correction (Mar 2026): https://www.reddit.com/r/MurderMystery2/comments/1s4tosi/trading_my_inventory_for_offers/
- Silent trades (June 2022): https://www.reddit.com/r/MurderMystery2/comments/vkaf8m
- Silent/bare 'add' (Dec 2024): https://www.reddit.com/r/MurderMystery2/comments/1h5zohq
- Offers and Nty/no-inventory-upgrades (Aug 2026): https://www.reddit.com/r/MurderMystery2/comments/1vzxlko/trading_my_whole_inventory_lf_offers/
- Name corrections / requests for value (Aug 2026): https://www.reddit.com/r/MurderMystery2/comments/1vyo12l/looking_for_decent_offers/
- HW question (Mar 2026): https://www.reddit.com/r/MurderMystery2/comments/1s32xaa/will_anyone_take_this/
- DB and forced 'NLF' requests (Feb 2025): https://www.reddit.com/r/MurderMystery2/comments/1is4lkc/
- Chroma abbreviation correction (Apr 2025): https://www.reddit.com/r/MurderMystery2/comments/1jw8d6e
- Cross-list value confusion (Aug 2026): https://www.reddit.com/r/MurderMystery2/comments/1vshcun/wl_im_new/
- Preference 'only certain items trading' (Sep 2026): https://www.reddit.com/r/MurderMystery2/comments/1wbxnxl/trading/
- Self-declared no chat (Mar 2026): https://www.reddit.com/r/MurderMystery2/comments/1s32xaa/will_anyone_take_this/

### Lower confidence community glossary
- https://mm2tradehub.com/guides/mm2-trading-glossary — LF, NLF, NFT, OP, UP, WFL, adds, downgrade, upgrade, 1:1/2:1, plus `IA` glossed as 'I added'. This is *one third-party glossary*, not immutable canonical MM2 slang.
- https://www.reddit.com/r/MurderMystery2/comments/gukeb4 — firsthand MM2 post labels 'Insta-accept' as a particular desired trade. In other Roblox trade contexts `IA` can mean 'instant accept'. **Do not preassign single unambiguous expansion of `ia`.** In offer window, 'I added' may mean review current slots; in a listing 'IA:' may describe a target offer. Neither means Roblox accept was clicked.
- Multiple third-party mirrors use identical glossary text; do not count as independent sources.

## Robust interpretation design: message meaning is contextual
A message interpretation must be a **structured uncertain hypothesis**, not a yes/no keyword result:
`{sourceProvenance, languageOrTranslationStatus, speakerBoundToActivePartner, channel, tradeJobLease, offerRevision, utteranceTime, literalTextAvailability, candidateIntents[], normalizedMentionedItems[], offerDirection, requestedChange, negationScope, uncertainty, proposedClarification, mayChangeTrade:false, mayAccept:false}`.

Pipeline:
1. **Capability**: text legitimately accessible? If no => `TEXT_UNAVAILABLE`; no scraping/reading private chat, no guessing the message, and no automatic reply.
2. **Bind** speaker and context to current trade partner plus job lease and client offer revision; ignore public comments from other players, duplicate/out-of-order messages, prior sessions and stale offer changes.
3. **Conservative normalization**: case, whitespace, common spelling noise, emojis and abbreviations; preserve **negation**, item-code distinctions and direction. Keep original text when permitted, no autonomous archiving of complete player chat logs. Romanized slang, code-switching and translation require separate evidence/language state.
4. **Extract all candidate intents**: ask what they want, propose a side-specific trade, request additions or removal, deny, "NFT", clarify value source, point out set preference, express uncertainty, delay, accept *in text*, and unknown/off-topic. Mixed intentions can coexist.
5. **Ground** all mentioned weapon candidates to exact immutable 189 historical candidate IDs, compare against active client observer; similarity is NOT exact identity proof. Reject `c db`→plain `db` and snowstorm→snowcannon conflation.
6. **Resolve referents**: 'it', 'that', 'your', 'my', 'those 2', 'add', 'same' require preceding messages, current both-side offer slots and sender perspective. If missing => request one targeted clarification, not guess.
7. **Decision separations**: 'nty' means no to a particular offer; 'sure' or 'bet' in chat is NOT an executable server Accept; 'added' is not a current item revision proof; 'good offer' is NOT agreement.
8. **Response**: only permitted, short, respectful, non-spam, no automatic loss/overpay ceiling, no false claim of value knowledge or ownership; don't change offer unless separate strategy and independent safety authorize. No chat initiated to manipulate, mislead or extract account identifiers.
9. **Learning**: observed language signals are weak evidence of current stated preferences, not psychological/personality diagnoses; keep actual slot changes/declines/client accept/server completion as separate evidence classes. No resell-probability from screenshots/public advertisements.

## Test matrix — all examples below SYNTHETIC (NOT observed in MM2 logs)
A. `nty`, `n ty`, `no tysm`, `pass sry`, `good offer tho nty`: reject only current revision, no repeated messages.
B. `add`, `can u add`, `i can add`, `i did add`, `u add i add`: distinguish demanded counterparty action, own commitment, claimed past action, conditional reciprocity; no value addition without verifying offer slots.
C. `my bat for ur db`, `ur db for my bat`, `bat db?`, `2 x harv for 1 bat`: prove sender perspective and exact keys; ambiguous => ask.
D. `hw`, `heart wand`, `c db`, `chromadb`, `db`, `snow storm`, `snow cannon`: weapon alias mapping with no silent false positives.
E. `LF X NLF Y`, `only godlies ft`, `NFT`, `idk offer`, `not trading X`, `if you add Y`: scope and negation.
F. `sure`, `ok`, `bet`, `yes but add`, `no no i said X`: accept-in-text vs conditional accept vs correction; never auto final accept.
G. `its 600 on mm2v`, `supreme says 400`, `what list u use?`: cite named list/date only when independently verifiable.
H. `###`, translation error, incomplete/mixed-language strings, pure emoji or periods: no guessed trade decision.
I. Same message repeated from a different player, other channel, old job or old trade revision: reject attribution and intent leakage.
J. Silent trade, no text API, muted/age-limited, platform-integrated chat: do not infer player greed or send.
K. Claims of off-platform payment, trust trade, 'you go first', password/personal data: no off-platform negotiation, do not bypass game escrow.
L. Multiple active offers: prioritize the **verified active trade partner** and revision, not whoever sent newest public message.

## Roblox first-party constraints and language variability
- https://create.roblox.com/docs/chat/platform-integrated-chat: enabling platform-integrated chat causes `TextChatMessage.Text` and `Translation` to return `""`; `Player.Chatted`, `OnIncomingMessage` and direct `TextChannel:SendAsync()` are unsupported for the purpose of custom raw message parsing/sending. Required across games **May 2027**. We have NO proof current MM2/Delta supports an official text stream.
- https://devforum.roblox.com/t/important-textchatservice-updates-how-to-test-and-what%E2%80%99s-next/4948433: published Oct 21 2026 Roblox rollout details.
- https://en.help.roblox.com/hc/en-us/articles/23328085173140-Automatic-Chat-Translation: Roblox may translate messages; user can view original optionally. Translators can alter names or syntax; avoid assuming original message language or direct word-for-word agreement.
- https://about.roblox.com/newsroom/2026/03/rethinking-chat-for-fun-gameplay-civility: official real-time filtering and profanity rephrasing alters visible text; `###` denotes filtered content, not a valid offer.
- https://create.roblox.com/docs/chat/guidelines: no bypass of filtering, privacy, age checks or chat restrictions. Keep optional chat negotiator separate from main System 3 decision/safety engine. **May 2027 platform-integrated chat will prevent scripted message-text reading in normal experiences.**

## Conclusions and follow-up
1. Never use a fixed list of five chat commands as the model of real MM2 interaction. Pair evidence-based intent interpretation with active-session context and abstentions.
2. Prior public trading comments are **good examples** but not native MM2 in-game messages. A real representative, permission-compliant, privacy-safe *live test corpus* remains unavailable; do NOT call the natural-language model proven.
3. Before parser coding, test whether current MM2 chat message content is legitimately accessible through supported APIs at all. If not, focus on manual suggested-reply mode and offer-window behavior learning; do not circumvent Roblox platform integrated chat.
4. Required separate tests: provenance, intent, spelling, alias collisions, pronouns, cross-language/translation, multi-turn revisions, false acceptance, privacy, moderation and source availability; then controlled supervised tests.
5. No production code, training model, live chat sender, auto Accept, or changes to P3/P4/Delta have been implemented in this research artifact.
