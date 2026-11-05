# V15.8 — value-first physical insertion only

Base: current V15.7 PR30 head9b4d78572cec606885e8f1d72f13cf277bc226f3. Its immutable P4v10 blob3dd839c62cafe85043c5040ca75596dbabcf58dd and strategy policy10 remain the references. All431 predecessor files stay byte-identical.

Root cause: policy10 intentionally sorts owned rows by ascending value for deterministic combination generation. Its selected picks inherit that order. P4's applyPlan iterates the original picks directly. This couples physical presentation to planner traversal, even though final identities/quantities and reservation ownership are independent of pick order. The normal quote signature sorts resolved identities; planMatches verifies identity/quantity counts, not physical positions.

The real snapshot gives Ocean245 + Mortal135 =380. The unchanged policy selects Boneblade7 + Iceblaster33 + Immortal135×2 =310, profit70. Its preferred profit is57 base +13.5 source-condition premium =70.5. This task must not reinterpret the intermediate40-value display as the selected economic offer.

- [x] Reproduce the original sequence in the complete production controller, using actual snapshot prices and the unchanged policy. Freeze selected picks; record the same plan object, key, quantities, reservation and final commit.
- [x] Add a versioned P4 successor that validates finite positive selected value and integer quantity before clearing, sorts a private wrapper list by value×quantity descending and original index on ties, then runs the existing per-copy insertion code. Never sort or replace the reserved plan itself.
- [x] Verify delayed/failed native insertion, duplicates, acceptance/identity/opponent changes, partial offers and final proof; inherit all immediate-safety, strategy and concession tests.
- [x] Verify later clear of a descending-built offer still reacts urgently when the opponent removes value. Leave the established removeOne path unchanged.
- [x] Check exact preservation of all431 predecessors,19 unrelated loader dependencies, valuation and strategy, and all inherited suites.
- [ ] Publish one isolated draft PR with immutable P4/loader/bootstrap pins and one Delta entry. Do not merge.

For unchanged verified380, old prefixes7→40→175→310 and new prefixes135→270→303→310 all preserve at least+70. An empty side during clearing is an incomplete offer, never an acceptable completed trade. Opponent changes fence subsequent actions and invoke existing immediate safety protection. No client-side change can guarantee atomic safety against an in-flight native remote and concurrent partner removal; test action ordering and honest uncertain outcomes, and require native timing evidence.

Trade-offs: earlier high value is also earlier exposure if they remove items. Existing highest-index removal may withdraw cheap fillers first on a later replacement; immediate safety must still stop an unsafe remaining quote. The change does not reduce four OfferItem calls, their0.15-second pauses, or native cooldown resets. It requests a more credible early presentation; native rendering order and any effect on opponent declines remain unproved until live testing. No scanner, bot, hopping, strategy, Common-item or Discord behavior changes are authorized.
