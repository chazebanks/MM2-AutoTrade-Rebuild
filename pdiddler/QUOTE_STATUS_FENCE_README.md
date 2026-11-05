# V15.8 Quote Status Fence — Isolated regression

**Branch:** `fix/v15-8-quote-status-fence` from `fix/v15-8-value-first-insertion`.

## Observed symptom
A recording shows a trade with our Plasmabeam (18) + Boneblade (7) and
the other player's Frostsaber (10) + Sugar (32). The displayed +17 profit
continued to appear briefly after Sugar was removed, changing the quote
to a -15 loss. The trade closed without a verified completion. It is
**not established** whether the other player closed it or P4 declined.

## Narrow fix
- On a raw physical quote signature change, invalidate quote evidence
  **and the previous profit status**, before the normal safety decision.
- On an unsafe physical quote, explicitly show that the previous profit
  is invalid while the existing protective decline/withdraw logic runs.
- Immediately before showing any new "verified Supreme profit" message,
  re-read the **current physical** both-side signature and require
  equality with the safety-inspected signature and a noninvalidated quote.
- Any changed/unknown quote enters the normal next polling iteration;
  **no quote acceptance, price, concession, trade request, or inventory
  modification logic was changed**.

## Tests
```bash
python -m unittest discover -s pdiddler/tests -p 'test_quote_status_fence.py'
```
These are **source-contract and arithmetic tests**, not executable Luau
simulation or in-game evidence. After review, run a manual Delta test that
checks 1) add/remove/swap; 2) same value but different identity; 3) post
acceptance changes; 4) missing item/quantity; 5) early trade close.

## Deployment blocker
The current Delta entrypoint is pinned to an older V15.8 integrated
commit and that integrated file pins the older P4 commit. Merely merging
this branch cannot alter the already-pinned active loader. A separate
reviewed loader repin and native replay are required.

**Do not enable native final Accept from this patch.**
