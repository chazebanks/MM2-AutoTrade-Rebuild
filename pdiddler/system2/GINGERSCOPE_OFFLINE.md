# Run Gingerscope offline

Use CPython 3.12 from the root of the reviewed public Git checkout. Persistent
state requires SQLite 3.38 or later with JSON support. The application accepts
local account holdings and hypothetical counterparty stock.

```sh
python3.12 -m venv .venv
. .venv/bin/activate
python -m pip install -r pdiddler/system2/requirements-gingerscope.txt
python -m pdiddler.gingerscope --help
```

## Full-system qualification

Use clean public and private draft checkouts in sibling directories on Linux.
Install Lune 0.11.1 and the pinned Python requirements above. Run from the
public checkout with an absolute private checkout path and a new receipt path.

```sh
python -m pdiddler.gingerscope qualify \
  --lune "$(command -v lune)" --private-root /path/to/private-checkout \
  --expect-public-revision "$(git rev-parse HEAD)" \
  --expect-private-revision "$(git -C /path/to/private-checkout rev-parse HEAD)" \
  --cycles 128 --copy-to /path/to/new-receipt.json
```

The test prints its current stage on stderr. The JSON receipt on stdout is
the copyable evidence. The optional receipt file is created with owner-only
permissions and refuses to overwrite a previous receipt. `PASS_FULL` means
all seven controlled stages completed. `--public-only` returns
`PASS_PUBLIC_SCOPE` and marks private evaluation as outstanding for that run.
A failure has an exit code of 2 and a stage reason. Ctrl-C stops the run,
cleans up the temporary synthetic database and returns exit code 130 with a
partial `STOPPED` receipt. Start a new qualification after correcting the
reported failure. Use the state recovery commands below for a separate
operator-owned database.

| Stage | Expected behavior |
| --- | --- |
| 1. Startup | Verify the clean source revisions, installed tools, fixed Supreme replay edition, Luau startup order and bounded Tablet/Play fixtures. |
| 2. Inventory | Preserve separate accounts, exact variants, explicit unknown prices and protected holdings. |
| 3. Strategy | Search competing bounded routes, compare both ledgers, and verify slot limits and protective arbitration. |
| 4. Lifecycle | Consume the Luau observations through the Python application. Offer changes retire prior advice, and declines, interruptions and unknown closure stay distinct. |
| 5. Accounting | Reconcile one controlled synthetic settlement, reopen and replay without a duplicate, exercise private eligibility, and recalculate the portfolio. |
| 6. Endurance | Exercise concurrent ownership defenses and abrupt process death, retry safely, cross the fixed cutoff and a fixture edition transition, and measure a large search. |
| 7. Adversarial | Reject malformed source, evidence, holdings, historical policy regressions and unsupported settlement or learning. |

The Lune host uses in-memory services and the checked-in health and readiness
code, P3 startup supervision, the P4 observer and protected lease handling.
Its observation envelope carries synthetic terms, sequence, revision, slots
and edition. Python validates the envelope and owns all local persistence.
The optional private evaluator consumes the same recovered synthetic ledger.
The pinned market input is evaluated at its fixed historical replay clock.
The receipt also displays whether current-clock pricing is available.

The default Supreme archive is a reviewed historical edition with an exact
expiry of 2026-11-25T12:09:59Z. Use the current UTC clock with a fresh reviewed
edition. Use an explicit replay clock for reproducible analysis of an archive.
The examples below use invented holdings. Put any personal data and SQLite
database outside the repository.

```sh
umask 077
state_dir="$(mktemp -d)"
db="$state_dir/scenario.sqlite"
clock=2026-11-25T07:52:05Z
python -m pdiddler.gingerscope --synthetic --database "$db" --replay-at "$clock" \
  review pdiddler/system2/examples/portfolio.json
python -m pdiddler.gingerscope --synthetic --database "$db" --replay-at "$clock" \
  simulate-session pdiddler/system2/examples/interrupted-session.json
python -m pdiddler.gingerscope --synthetic --database "$db" --replay-at "$clock" status
python -m pdiddler.gingerscope --synthetic --database "$db" --replay-at "$clock" recover
```

Inventory records have separate `main` and `alt` holdings. Enter exact
case-sensitive `category:publisher-ID` keys, with positive integer copy counts.
Unpriced holdings remain visible as counts and leave the total unknown. Main
account capacity is computed using its own unprotected holdings and four item
slots. The capped stack figure represents a paper scenario.

The optional `counterparties` array supplies one stock object per hypothetical
opportunity. The planner compares both sides, holds a hard four-slot limit, and
keeps the search within its reported work bounds. A truncated search can leave
viable routes unexplored. Published demand and stability are descriptive. The
reports carry no game, settlement, webhook or learning authority.

For a single entered offer, add an `offer` object with `give`, `receive`,
and `counterpartyStock` holdings. The default compares one copy per slot.
`copiesPerSlot` up to four is available as an explicit stack assumption.
`--text` shows the local inventory and offer summary. The default JSON report
includes the route search, uncertainty, and source provenance.

`scenario pdiddler/system2/examples/strategy-scenario.json` runs competing
rules across supplied stocks and market phases. Each phase names a local
archive, a clock, and the supplied counterparties. An empty counterparty list
models scarcity. An explicit `unavailable_indices` list models missed
opportunities. Use `expected_sha256` for independently reviewed archives.
The report keeps hypothetical trading growth, changes in listed prices,
changes in price coverage, and cumulative conditional downside separate.

`capture-market NEW_FILE` retrieves four official Supreme pages and reports
their archive SHA-256 for independent review. After reviewing a genuine newer
publisher edition, pass the saved archive and independently reviewed hash via
`--catalog` and `--expected-market-sha256`. Use `market-diff` with the prior
archive and a timestamp inside its original validity window to inspect changes.
The same publisher timestamp cannot extend the existing expiry.

## State and recovery

`review` without `--database` produces a stateless report. With a database, an
evaluation has an ID and is bound to the stored input revision, including the
Supreme archive and both accounts. For controlled offer evaluation it is also
bound to the session and offer revision. Read a stored evaluation using
`current EVALUATION_ID` with the same database and mode. A changed binding,
closed session, expired source, or newer manual review produces a null
evaluation. `history EVALUATION_ID` retrieves the archived report with its
original source and input revision.
`portfolio-diff PREVIOUS CURRENT` compares stored copy counts across the
two accounts. A conserved combined inventory is compatible with an internal
reallocation. The comparison carries no verified transfer or gain claim.

`configure LOCAL_JSON` stores bounded default search settings in the selected
database and retires advice based on earlier defaults. Individual review
requests may override those settings with a `search` object. Schema version
one upgrades atomically to version two and keeps existing revisions and
unresolved outcomes.

`simulate-session` runs a bounded, ordered observation sequence in a synthetic
database. Ctrl-C stops the command and releases its session when possible.
`recover` clears expired leases after application interruption. `status` and
`recover` print only sanitized operational counts suitable for copying. An
interruption preserves an unresolved outcome. The input, database, and
individual evaluation reports can contain holding or offer information.
An optional synthetic settlement requires an explicit transaction ID, an exact
offer revision and distinct corroborating witnesses for both sides. Its
valuation is recorded in synthetic accounting only.

Use a separate database for current manual analysis, omitting `--synthetic`
and `--replay-at`. For rollback, retain the previous public draft revision
`2622777c47c7913a2b9097efc9d8c6283e7ba04f` and a backup of any local database
from before a software or schema upgrade. Restore the database to a separate
path before verifying an older revision.

## Verification

```sh
python -m unittest -v pdiddler.ci.test_gingerscope_application \
  pdiddler.ci.test_gingerscope_application_state pdiddler.ci.test_portfolio_planner \
  pdiddler.ci.test_portfolio_simulation pdiddler.ci.test_supreme_market_editions \
  pdiddler.ci.test_manual_portfolio_review
lune run pdiddler/ci/gingerscope_part2_startup_mocks.luau
python -m pdiddler.continuity.manager verify
python -m pdiddler.continuity.manager recover
```

The whole-system GitHub workflow additionally checks source-pinned historical
replays, native Luau fixtures, Python regressions, and Luau syntax. The
[requirements matrix](gingerscope_requirements.json) records which results
apply to the supported app, historical client evidence, and release gates.

## Defects found during integration

- Opening a replayed session could advance portfolio inputs before the session
  was rejected. Session ownership and the starting inputs now commit together.
- A large valid planning report could exceed the old persistence cap after
  advancing inputs. The application validates the report against the same
  bounded storage limit before updating the inputs.
- Malformed event kinds and UTC edge offsets could exit with a traceback.
  Typed validation now handles these inputs before they reach state processing.
- A changed stored JSON report could still appear current. Report retrieval
  verifies the evaluation digest as well as the source and revision bindings.
- A revised manual offer could leave its previous offer marked current when
  holdings and the edition were unchanged. The latest manual review now
  supersedes earlier reports while keeping them available in history.
- A modified state row could extend the saved Supreme cutoff. Evaluation
  readback now checks the archive hash and clocks against the report.
- The separate C8 historical bridge workflow tried to refresh a superseded
  provider and stopped at `CARD_CATEGORY_MISMATCH`. It now verifies the
  existing immutable historical fixture and replays at the recorded clock.
  The parser unit tests and the original bridge assertions still run.
- Controlled settlement could apply a one-sided or unsupported stack offer
  which had abstained in bilateral review. Settlement now requires the
  current eligible bilateral review. The store also rejects empty sides.
- The state API could open a lease after its edition expired, even though
  the CLI already refused expired pricing. Lease creation now verifies the
  source window inside the same transaction.
- A backdated review could replace settled holdings before its evaluation
  was rejected. Snapshot admission checks the committed settlement clock in
  the transaction that updates the input revision.

## External validation

The [supervised validation handoff](GINGERSCOPE_SUPERVISED_VALIDATION.md)
records the environment, conditions, evidence and limits for each external gate.

- Current pricing after the fixed archive cutoff needs a genuinely newer
  Supreme edition and review of its capture and census.
- Current supervised gameplay needs a supported client interface and an
  authorized test with exact session, item, and offer-revision evidence.
- Verified accounting and empirical learning need independent settlement with
  exact two-sided holdings, legitimate offer-level outcomes, and a stable
  private participant identifier suitable for held-out evaluation.
- Runtime release requires separate operator approval and verified safeguards.
  Numerical loss budgets remain unapproved.
