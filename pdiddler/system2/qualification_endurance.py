"""Controlled endurance qualification for the existing Gingerscope application."""

from collections import Counter
from contextlib import closing
from datetime import timedelta
from hashlib import sha256
import json
import os
from pathlib import Path
import platform
import sqlite3
import subprocess
import sys
from tempfile import TemporaryDirectory
from time import perf_counter, process_time

from pdiddler.system2.application_state import MAX_REPORT_BYTES, StateError, StateStore
from pdiddler.system2.manual_portfolio_review import summarize_accounts
from pdiddler.system2.portfolio_planner import evaluate_offer, plan
from pdiddler.system2.portfolio_simulation import compare_strategies
from pdiddler.system2.supreme_market_editions import compare_editions, load_edition
from pdiddler.system2.supreme_only_strategy_research import SupremeOnlyBlocked, utc


MAX_CYCLES = 128
PAIR_BUDGET = 20_000
PROTECTED = "ancient:Gingerscope"
GIVE = {"godly:Fang": 1}
INITIAL_RECEIVE = {"godly:Gemstone": 1}
REVISED_RECEIVE = {"godly:Plasmabeam": 1}
COUNTERPARTY = INITIAL_RECEIVE | REVISED_RECEIVE
ACCOUNTS = {"main": GIVE | {PROTECTED: 1, "godly:UnrecognizedItem": 2}, "alt": {"godly:Heat": 2}}
OUTCOMES = ("PARTNER_DECLINED", "CLIENT_WINDOW_CLOSED_UNKNOWN", "SESSION_INTERRUPTED",
            "CORROBORATED_SYNTHETIC_SETTLEMENT")
MEASUREMENTS = {"listed_wealth", "purchasing_power", "market_quality", "target_progress",
                "bilateral_attractiveness", "reliability"}


class EnduranceError(ValueError):
    """An endurance checkpoint failed. The code is safe for evidence export."""


def _require(condition, code):
    if not condition:
        raise EnduranceError(code)


def _reject(operation, error_class, reason, code):
    try:
        operation()
    except error_class as error:
        _require(reason in str(error), code)
    else:
        raise EnduranceError(code)


def _later(clock, *, seconds):
    return (utc(clock) + timedelta(seconds=seconds)).isoformat()


def _input(edition, accounts):
    prices = {f"{row['category']}:{row['officialItemId']}": row["supremeListed"]
              for row in edition.rows.values()}
    source = edition.provenance
    return {
        "market_sha256": edition.identity, "publisher_updated_at": source["publisherUpdatedAt"],
        "captured_at": source["capturedUtc"], "expires_at": source["expiresUtc"],
        "accounts": accounts, "listed_values": prices,
    }


def _event(session, sequence, revision, kind, **offer):
    return {"event_id": f"{session}-{sequence}", "session_id": session,
            "sequence": sequence, "revision": revision, "kind": kind, **offer}


def _record_offer(state, session, owner, *, clock, catalog, edition, revision, kind, receive):
    event = _event(session, revision + 1, revision, kind, give=GIVE, receive=receive)
    _require(state.observe(event, owner=owner, now=clock), "fresh_offer_not_recorded")
    comparison = evaluate_offer(catalog, ACCOUNTS["main"], COUNTERPARTY, GIVE, receive,
                                evaluated_at_utc=clock, edition=edition)
    _require(comparison["authorizes_trade"] is False, "paper_authority_promoted")
    evaluation = f"{session}-revision-{revision}"
    state.record_evaluation(evaluation, input_revision=state.inputs()["inputRevision"],
                            evaluated_at=clock, session_id=session, offer_revision=revision,
                            report=comparison)
    current = state.current_evaluation(evaluation, now=clock)
    _require(current and current["report"] == comparison, "fresh_evaluation_not_current")
    return event, evaluation


def _settlement(session, owner, clock, revision, receive):
    return {
        "session_id": session, "owner": owner, "now": clock,
        "transaction_id": f"{session}-transaction", "revision": revision,
        "witnesses": [
            {"side": "account", "source_id": "controlled-account", "before": ACCOUNTS["main"],
             "after": {key: count for key, count in ACCOUNTS["main"].items() if key not in GIVE} | receive},
            {"side": "counterparty", "source_id": "controlled-counterparty", "before": COUNTERPARTY,
             "after": {key: count for key, count in COUNTERPARTY.items() if key not in receive} | GIVE},
        ],
    }


def _run_cycles(path, *, clock, catalog, edition, cycles):
    lease = _later(clock, seconds=60)
    expected = Counter()
    for index in range(cycles):
        session = f"endurance-{index}"
        outcome = OUTCOMES[index % len(OUTCOMES)]
        expected[outcome] += 1
        with StateStore(path, scope="synthetic") as initial:
            token = initial.start_session(session, account="main", now=clock, lease_until=lease,
                                          counterparty=COUNTERPARTY, inputs=_input(edition, ACCOUNTS))
            accepted = _event(session, 1, 0, outcome if outcome == "PARTNER_DECLINED" else "PARTNER_REQUEST_ACCEPTED")
            _require(initial.observe(accepted, owner=token, now=clock), "fresh_outcome_not_recorded")
            if outcome != "PARTNER_DECLINED":
                first, first_evaluation = _record_offer(
                    initial, session, token, clock=clock, catalog=catalog, edition=edition,
                    revision=1, kind="OFFER_OBSERVED", receive=INITIAL_RECEIVE,
                )

        with StateStore(path, scope="synthetic") as resumed:
            _require(not resumed.observe(accepted, owner=token, now=clock), "duplicate_event_mutated_state")
            altered = accepted | {"revision": 1}
            _reject(lambda: resumed.observe(altered, owner=token, now=clock),
                    StateError, "conflicting evidence", "conflicting_duplicate_accepted")
            if outcome == "PARTNER_DECLINED":
                _require(resumed.inputs()["accounts"] == ACCOUNTS, "decline_changed_holdings")
                continue
            _require(not resumed.observe(first, owner=token, now=clock), "duplicate_offer_mutated_state")
            _, evaluation = _record_offer(
                resumed, session, token, clock=clock, catalog=catalog, edition=edition,
                revision=2, kind="PARTNER_OFFER_REVISION", receive=REVISED_RECEIVE,
            )
            _require(resumed.current_evaluation(first_evaluation, now=clock) is None
                     and resumed.evaluation_history(first_evaluation) is not None, "revised_offer_left_advice_current")
            stale = _event(session, 4, 1, "PARTNER_ACCEPT_INDICATOR")
            _reject(lambda: resumed.observe(stale, owner=token, now=clock),
                    StateError, "stale or incomplete", "stale_observation_accepted")
            if outcome == "CORROBORATED_SYNTHETIC_SETTLEMENT":
                claim = _settlement(session, token, clock, 2, REVISED_RECEIVE)
                _require(resumed.settle_synthetic(**claim), "fresh_synthetic_settlement_rejected")
                _require(resumed.inputs()["accounts"] == {"main": claim["witnesses"][0]["after"],
                                                          "alt": ACCOUNTS["alt"]}, "settlement_not_reconciled")
                _require(not resumed.settle_synthetic(**claim), "duplicate_settlement_mutated_state")
            elif outcome == "SESSION_INTERRUPTED":
                _require(resumed.stop_session(session, owner=token, now=clock), "stop_did_not_release_session")
            else:
                closed = _event(session, 4, 2, outcome)
                _require(resumed.observe(closed, owner=token, now=clock), "unknown_outcome_not_recorded")
            if outcome != "CORROBORATED_SYNTHETIC_SETTLEMENT":
                _require(resumed.inputs()["accounts"] == ACCOUNTS, "unconfirmed_outcome_changed_holdings")
            _require(resumed.current_evaluation(evaluation, now=clock) is None, "closed_session_advice_current")

    with StateStore(path, scope="synthetic") as state:
        totals = state.summary()
        _require(totals["outcomeCounts"] == expected and totals["activeSessions"] == 0
                 and totals["syntheticSettlements"] == expected["CORROBORATED_SYNTHETIC_SETTLEMENT"]
                 and totals["realizedGrowth"] is None and not totals["authoritativeSettlementVerified"],
                 "repeated_outcome_totals_inconsistent")
    return dict(expected)


_INTERRUPT_BEFORE_COMMIT = """
import json, os, sys
from pdiddler.system2.application_state import StateStore

def interrupt(statement):
    if statement == 'COMMIT':
        os._exit(92)

with StateStore(sys.argv[1], scope='synthetic') as state:
    state._db.set_trace_callback(interrupt)
    state.settle_synthetic(**json.load(sys.stdin))
"""


def _test_interrupted_write(path, *, clock, catalog, edition):
    session = "interrupted-write"
    lease = _later(clock, seconds=60)
    with StateStore(path, scope="synthetic") as state:
        token = state.start_session(session, account="main", now=clock, lease_until=lease,
                                    counterparty=COUNTERPARTY, inputs=_input(edition, ACCOUNTS))
        state.observe(_event(session, 1, 0, "PARTNER_REQUEST_ACCEPTED"), owner=token, now=clock)
        _, evaluation = _record_offer(state, session, token, clock=clock, catalog=catalog, edition=edition,
                                      revision=1, kind="OFFER_OBSERVED", receive=INITIAL_RECEIVE)
        before = state.inputs()
        settlements = state.summary()["syntheticSettlements"]
    claim = _settlement(session, token, clock, 1, INITIAL_RECEIVE)
    try:
        child = subprocess.run(
            [sys.executable, "-c", _INTERRUPT_BEFORE_COMMIT, str(path)],
            input=json.dumps(claim), text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            check=False, timeout=20, cwd=Path(__file__).resolve().parents[2],
        )
    except (OSError, subprocess.TimeoutExpired):
        raise EnduranceError("interrupted_writer_failed_to_start_or_exit") from None
    _require(child.returncode == 92, "writer_did_not_interrupt_before_commit")
    with StateStore(path, scope="synthetic") as state:
        _require(state.inputs() == before and state.summary()["syntheticSettlements"] == settlements
                 and state.current_evaluation(evaluation, now=clock) is not None, "partial_settlement_committed")
        _require(state.recover(now=clock) == 0, "unexpired_lease_removed")
        _reject(lambda: state.start_session("competing-lease", account="main", now=clock, lease_until=lease),
                StateError, "already owns", "conflicting_lease_acquired")
        _require(state.settle_synthetic(**claim), "recovered_writer_could_not_retry")
    with StateStore(path, scope="synthetic") as state:
        _require(not state.settle_synthetic(**claim) and state.summary()["syntheticSettlements"] == settlements + 1,
                 "recovered_settlement_not_idempotent")


def _test_lease_recovery(path, *, clock):
    session = "stale-lease"
    expiry = _later(clock, seconds=60)
    with StateStore(path, scope="synthetic") as state:
        token = state.start_session(session, account="main", now=clock, lease_until=expiry)
    with StateStore(path, scope="synthetic") as state:
        retired = state.recover(now=expiry)
        repeated = state.recover(now=expiry)
        _require(retired == 1 and repeated == 0 and state.summary()["activeSessions"] == 0,
                 "expired_lease_recovery_not_idempotent")
        _reject(lambda: state.observe(_event(session, 1, 0, "PARTNER_DECLINED"), owner=token, now=expiry),
                StateError, "closed, expired", "expired_controller_mutated_state")
    return {"expired_leases_retired": retired, "repeated_recovery_mutations": repeated}


def _test_corruption(path):
    mutations = (
        ("UPDATE inputs SET accounts='invalid-json'", "integrity verification"),
        ("DELETE FROM markets", "stored dependency"),
        ("PRAGMA user_version=31337", "schema version"),
    )
    for index, (mutation, reason) in enumerate(mutations):
        broken = path.with_name(f"corruption-{index}.sqlite3")
        broken.touch(mode=0o600, exist_ok=False)
        with closing(sqlite3.connect(path)) as source, closing(sqlite3.connect(broken)) as target:
            source.backup(target)
            target.execute("PRAGMA ignore_check_constraints=ON")
            target.execute(mutation)
            target.commit()

        def open_corrupt_store():
            with StateStore(broken, scope="synthetic"):
                pass

        _reject(open_corrupt_store, StateError, reason, "corrupt_state_opened")
    return len(mutations)


def _test_market_transition(path, *, clock, catalog, edition):
    # Reuse the actual publisher parser tests' controlled pages. These pages
    # represent tomorrow's publication only inside qualification.
    from pdiddler.ci.test_supreme_market_editions import NEXT_CAPTURE, archive

    cutoff = edition.provenance["expiresUtc"]
    expired_at = _later(cutoff, seconds=1)
    _reject(lambda: load_edition(catalog, evaluated_at_utc=expired_at),
            SupremeOnlyBlocked, "EXPIRED", "expired_market_admitted")
    pages = archive(changed=True)
    next_edition = load_edition(pages, evaluated_at_utc=NEXT_CAPTURE,
                                expected_sha256=sha256(pages).hexdigest())
    delta = compare_editions(edition, next_edition)
    holdings = {"main": GIVE | {"godly:Bioblade": 1}, "alt": {PROTECTED: 1}}
    before = summarize_accounts(holdings, edition.rows)
    after = summarize_accounts(holdings, next_edition.rows)
    with StateStore(path, scope="synthetic") as state:
        revision = state.sync_inputs(**_input(edition, holdings))
        state.record_evaluation("old-market", input_revision=revision, evaluated_at=clock, report=before)
        _require(state.current_evaluation("old-market", now=clock) is not None
                 and state.current_evaluation("old-market", now=expired_at) is None, "expired_advice_current")
        updated = state.sync_inputs(**_input(next_edition, holdings))
        state.record_evaluation("new-market", input_revision=updated, evaluated_at=NEXT_CAPTURE, report=after)
        _require(delta["invalidates_prior_evaluations"] and updated > revision
                 and state.inputs()["accounts"] == holdings
                 and state.current_evaluation("old-market", now=NEXT_CAPTURE) is None
                 and state.evaluation_history("old-market")["report"] == before
                 and state.current_evaluation("new-market", now=NEXT_CAPTURE)["report"] == after,
                 "edition_transition_did_not_recalculate")
        _require(before["accounts"]["main"]["total_listed_value"] is not None
                 and after["accounts"]["main"]["total_listed_value"] is None, "new_unpriced_holding_lost")
        _reject(lambda: state.sync_inputs(**_input(edition, holdings)), StateError,
                "newer publisher version", "old_edition_replaced_new")
    return {"historical_cutoff_utc": cutoff, "expired_input_rejected": True,
            "synthetic_edition_changed": True, "retired_price_count": len(delta["removed"])}


def _test_resource_limits(path, *, clock, catalog, edition):
    items = sorted(f"{row['category']}:{row['officialItemId']}" for row in edition.rows.values())
    main = dict.fromkeys(items[:90], 4) | {PROTECTED: 1, "godly:UnrecognizedItem": 2}
    partners = [dict.fromkeys(items[90 + index:155 + index], 4) for index in range(6)]
    started = perf_counter()
    output = plan(catalog, main, partners, evaluated_at_utc=clock, edition=edition, max_pairs=PAIR_BUDGET,
                  max_bundles_per_side=256, copies_per_slot=4)
    planner_seconds = perf_counter() - started
    search = output["search"]
    _require(search["pairs_examined"] == PAIR_BUDGET and search["pair_budget_truncated"]
             and search["bundle_budget_truncated"], "large_planner_work_not_bounded")
    comparisons = output["alternatives"] + [step for route in output["routes"] for step in route["steps"]]
    _require(comparisons and all(PROTECTED not in view["give"] and len(view["give"]) <= 4
                                and len(view["receive"]) <= 4 for view in comparisons),
             "large_planner_protection_failed")
    pressure_path = path.with_name("pressure.sqlite3")
    with StateStore(pressure_path, scope="synthetic") as state:
        revision = state.sync_inputs(**_input(edition, {"main": main, "alt": {}}))
        _reject(lambda: state.record_evaluation("oversized", input_revision=revision, evaluated_at=clock,
                                                report={"x": "x" * MAX_REPORT_BYTES}),
                StateError, "report size limit", "oversized_report_accepted")
        _require(state.inputs()["inputRevision"] == revision and state.evaluation_history("oversized") is None,
                 "resource_rejection_mutated_state")
    return {"portfolio_item_count": len(main), "opportunity_count": len(partners),
            "planner_pairs_examined": search["pairs_examined"], "planner_pair_budget": PAIR_BUDGET,
            "planner_bounds_reached": True, "planner_wall_seconds": round(planner_seconds, 6),
            "oversized_report_rejected": True}


def _test_progression(catalog, clock):
    phases = [
        {"catalog": catalog, "evaluated_at_utc": clock, "counterparties": [stock] if stock else [],
         "unavailable_indices": [0] if index == 1 else []}
        for index, stock in enumerate((INITIAL_RECEIVE, REVISED_RECEIVE, REVISED_RECEIVE,
                                       {"godly:Green_Luger": 1}, {PROTECTED: 1}, {"chroma:CGB": 1}))
    ]
    holdings = {"main": GIVE | {"godly:Boneblade": 1}, "alt": ACCOUNTS["alt"]}
    result = compare_strategies(holdings, phases, strategy_names=("hold", "listed_growth", "purchasing_power"))
    growth = result["strategies"]["listed_growth"]
    outcomes = Counter(row["opportunity_status"] for row in growth["phases"])
    _require(len(growth["phases"]) == len(phases) and all(row["axes"].keys() == MEASUREMENTS
                                                         for row in growth["phases"])
             and growth["ending_accounts"]["main"].get(PROTECTED) == 1
             and growth["ending_accounts"]["alt"] == holdings["alt"]
             and growth["phases"][-1]["opportunity_status"] == "APPLIED_HYPOTHETICAL_EXCHANGE"
             and growth["phases"][-1]["trade_growth"] > 0
             and outcomes["SUPPLIED_OUTCOME_UNAVAILABLE"] == 1
             and result["strategies"]["hold"]["hypothetical_trade_growth"] == 0
             and result["acceptance_probability"] is None and result["measured_retrade_liquidity"] is None
             and result["realized_growth"] is None, "long_term_progression_not_reconciled")
    return {"phase_count": len(phases), "strategies_compared": len(result["strategies"]),
            "separate_measurements": len(MEASUREMENTS), "protected_target_acquired_hypothetically": True,
            "failed_hypothetical_outcomes": outcomes["SUPPLIED_OUTCOME_UNAVAILABLE"],
            "successful_hypothetical_steps": growth["applied_hypothetical_steps"]}


def _peak_rss_kib():
    if platform.system() not in ("Linux", "Darwin"):
        return None
    import resource
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return peak // 1024 if platform.system() == "Darwin" else peak


def run_endurance(workdir: Path, *, clock: str, catalog: bytes, cycles: int) -> dict:
    """Run isolated process-death recovery, archival change and measured planning."""
    _require(type(cycles) is int and 1 <= cycles <= MAX_CYCLES, "cycle_count_invalid")
    started, cpu = perf_counter(), process_time()
    edition = load_edition(catalog, evaluated_at_utc=clock)
    with TemporaryDirectory(prefix="endurance-", dir=workdir) as temporary:
        path = Path(temporary) / "replay.sqlite3"
        outcomes = _run_cycles(path, clock=clock, catalog=catalog, edition=edition, cycles=cycles)
        _test_interrupted_write(path, clock=clock, catalog=catalog, edition=edition)
        recovery = _test_lease_recovery(path, clock=clock)
        corruption_rejections = _test_corruption(path)
        market = _test_market_transition(path, clock=clock, catalog=catalog, edition=edition)
        performance = _test_resource_limits(path, clock=clock, catalog=catalog, edition=edition)
        strategy = _test_progression(catalog, clock)
        database_bytes = path.stat().st_size
    return {
        "status": "PASS", "evidence_scope": "CONTROLLED_OFFLINE", "session_cycles": cycles,
        "repeated_outcomes": outcomes, "realized_growth": None, "authoritative_settlement_verified": False,
        "recovery": {**recovery, "interrupted_write_rollbacks": 1, "corrupt_database_rejections": corruption_rejections},
        "market": market, "strategy": strategy,
        "performance": {
            **performance, "wall_seconds": round(perf_counter() - started, 6),
            "python_process_cpu_seconds": round(process_time() - cpu, 6),
            "python_process_peak_rss_kib": _peak_rss_kib(), "database_bytes": database_bytes,
            "platform": platform.system(), "architecture": platform.machine(),
            "python": platform.python_version(), "sqlite": sqlite3.sqlite_version,
            "available_logical_cpus": len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else os.cpu_count(),
        },
    }
