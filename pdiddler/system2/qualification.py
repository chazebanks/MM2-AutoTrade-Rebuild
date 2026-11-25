"""Run the supported Gingerscope application through a controlled full-system exercise."""

from datetime import datetime, timedelta, timezone
from hashlib import sha256
from importlib.metadata import PackageNotFoundError, version
import json
import os
from pathlib import Path
import platform
import re
import selectors
import sqlite3
import subprocess
import sys
import tempfile
from time import perf_counter
from types import SimpleNamespace

from pdiddler.continuity.manager import verify
from pdiddler.system2.application_state import StateError, StateStore
from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG, RequestError, _unique_keys
from pdiddler.system2.supreme_market_editions import load_edition
from pdiddler.system2.supreme_only_strategy_research import SupremeOnlyBlocked, utc


ROOT = Path(__file__).resolve().parents[2]
CLOCK = "2026-11-25T07:52:05Z"
LUNE_VERSION = "lune 0.11.1"
COMMAND_TIMEOUT_SECONDS = 45
MAX_ENVELOPE_BYTES = 262_144
REVISION = re.compile(r"[0-9a-f]{40}\Z")
STAGES = (
    "Startup and dependencies",
    "Inventory and opportunity inputs",
    "Strategy, arbitration and protection",
    "Controlled transaction lifecycle",
    "Accounting, evidence and learning",
    "Recovery, endurance and capacity",
    "Adversarial validation",
)


class QualificationError(ValueError):
    """An operator-safe stage failure code."""


def require(condition, reason):
    if not condition:
        raise QualificationError(reason)


def denied(operation, errors=(ValueError,)):
    try:
        operation()
    except errors:
        return True
    return False


def _child(command, *, cwd=ROOT, environment=None, error="DEPENDENCY_PROCESS_FAILED"):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    if environment is not None:
        env.update(environment)
    deadline = perf_counter() + COMMAND_TIMEOUT_SECONDS
    raw = bytearray()
    try:
        with subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL) as child, selectors.DefaultSelector() as selector:
            try:
                selector.register(child.stdout, selectors.EVENT_READ)
                while True:
                    remaining = deadline - perf_counter()
                    require(remaining > 0 and selector.select(remaining), error)
                    chunk = os.read(child.stdout.fileno(), min(65536, MAX_ENVELOPE_BYTES + 1 - len(raw)))
                    if not chunk:
                        break
                    raw.extend(chunk)
                    require(len(raw) <= MAX_ENVELOPE_BYTES, "DEPENDENCY_OUTPUT_LIMIT")
                require(child.wait(timeout=max(0, deadline - perf_counter())) == 0, error)
            finally:
                if child.poll() is None:
                    child.kill()
    except (OSError, subprocess.TimeoutExpired):
        raise QualificationError(error) from None
    return bytes(raw)


def _source(root, expected):
    checkout = _child(["git", "rev-parse", "--show-toplevel"], cwd=root,
                      error="SOURCE_CHECKOUT_UNAVAILABLE").decode().strip()
    require(Path(checkout).resolve() == root.resolve(), "SOURCE_CHECKOUT_UNAVAILABLE")
    revision = _child(["git", "rev-parse", "HEAD"], cwd=root, error="SOURCE_CHECKOUT_UNAVAILABLE").strip()
    revision = revision.decode("ascii")
    require(REVISION.fullmatch(revision), "SOURCE_REVISION_INVALID")
    status = _child(
        ["git", "status", "--porcelain", "--untracked-files=normal", "--", ".",
         ":(exclude,glob)**/__pycache__/**", ":(exclude).venv", ":(exclude).hypothesis"],
        cwd=root, error="SOURCE_STATUS_UNAVAILABLE",
    )
    require(not status and (expected is None or revision == expected), "SOURCE_REVISION_MISMATCH_OR_DIRTY")
    return {"revision": revision, "clean": True}


def _wire_json(raw):
    return json.loads(raw, object_pairs_hook=_unique_keys,
                      parse_constant=lambda _: require(False, "NON_FINITE_DEPENDENCY_OUTPUT"))


def _verify_packages():
    lock = ROOT / "pdiddler/system2/requirements-gingerscope.txt"
    for line in lock.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        package, pin = line.split("==", 1)
        try:
            actual = version(package)
        except PackageNotFoundError:
            raise QualificationError("PINNED_REQUIREMENTS_UNAVAILABLE") from None
        require(actual == pin, "DEPENDENCY_VERSION_MISMATCH")


def _startup(args, report, work):
    app = _application()
    require(1 <= args.cycles <= 128, "CONFIGURATION_INVALID")
    require((args.public_only or args.private_root is not None)
            and not (args.public_only and args.expect_private_revision is not None)
            and args.database is None and not args.synthetic and args.replay_at is None and not args.text
            and args.catalog == DEFAULT_CATALOG and args.expected_market_sha256 is None,
            "CONFIGURATION_INVALID")
    for value in (args.expect_public_revision, args.expect_private_revision):
        require(value is None or REVISION.fullmatch(value), "CONFIGURATION_INVALID")
    if args.copy_to is not None:
        require(not os.path.lexists(args.copy_to), "COPY_PATH_UNAVAILABLE")
    require(os.name == "posix", "QUALIFICATION_PLATFORM_UNSUPPORTED")
    actual_lune = _child([args.lune, "--version"], error="LUNE_UNAVAILABLE").decode().strip()
    require(actual_lune == LUNE_VERSION, "LUNE_VERSION_UNSUPPORTED")
    require(sys.version_info[:2] == (3, 12), "PYTHON_VERSION_UNSUPPORTED")
    require(sqlite3.sqlite_version_info >= (3, 38, 0), "SQLITE_VERSION_UNSUPPORTED")
    _verify_packages()
    with sqlite3.connect(":memory:") as database:
        require(database.execute("SELECT json_valid('{}')").fetchone() == (1,), "SQLITE_JSON_UNAVAILABLE")
    report["source"]["public"] = _source(ROOT, args.expect_public_revision)
    private = args.private_root.resolve() if args.private_root is not None else None
    if private is not None:
        report["source"]["private"] = _source(private, args.expect_private_revision)
        require((private / "scripts/qualification_evidence.py").is_file(), "PRIVATE_ADAPTER_UNAVAILABLE")
    report["runtime"] = {"python": platform.python_version(), "sqlite": sqlite3.sqlite_version,
                         "lune": actual_lune, "os": platform.system(), "architecture": platform.machine(),
                         "logical_cpus_available": _cpu_count()}
    anchors = verify(ROOT)["verifiedSourceBlobs"]
    raw = DEFAULT_CATALOG.read_bytes()
    edition = load_edition(raw, evaluated_at_utc=CLOCK)
    require(denied(lambda: app._search_settings({"max_steps": 0}), (RequestError,)),
            "INVALID_CONFIGURATION_ACCEPTED")
    with StateStore(work / "startup.sqlite", scope="synthetic") as empty:
        require(denied(lambda: empty.start_session("fixture", account="main", now=CLOCK,
                                                   lease_until=_instant(60)), (StateError,)),
                "UNINITIALIZED_OWNER_ACCEPTED")
    actual_now = datetime.now(timezone.utc).isoformat()
    current_status = "PINNED_EDITION_INSIDE_VALIDITY_WINDOW"
    try:
        edition.require_current(actual_now)
    except SupremeOnlyBlocked:
        current_status = "PINNED_EDITION_OUTSIDE_VALIDITY_WINDOW"
    summary = edition.summary()
    report["market"] = {"source": "SUPREME_ONLY", "archive_sha256": edition.identity,
                        "publisher_edition": summary["publisherUpdatedAt"],
                        "expires_utc": summary["expiresUtc"], "replay_utc": CLOCK,
                        "current_clock_status": current_status, "current_clock_checked_at": actual_now}
    from pdiddler.system2.controlled_host import load_controlled_host

    document = _child([args.lune, "run", "pdiddler/ci/gingerscope_controlled_host.luau"],
                      error="CONTROLLED_LUAU_HOST_FAILED")
    host = load_controlled_host(document, catalog=raw, clock=CLOCK)
    part2 = _child([args.lune, "run", "pdiddler/ci/gingerscope_part2_startup_mocks.luau"],
                   error="PART2_STARTUP_SCENARIOS_FAILED")
    require(part2.strip() == b"PASS: 9 offline Part 2/startup scenarios", "PART2_STARTUP_EVIDENCE_MISSING")
    return raw, edition, private, host, {
        "verified_source_blobs": anchors,
        "checked_dependency_initialization": True, "ruled_out_uninitialized_ownership": True,
        "invalid_configuration_denied": True, "controlled_host_validated": True,
        "controlled_readiness": host["readiness"], "part2_startup_scenarios": 9,
    }


def _cpu_count():
    return len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else os.cpu_count()


def _application():
    # The normal CLI lazily imports this runner after its own initialization.
    from pdiddler import gingerscope
    return gingerscope


def _instant(seconds=0, days=0):
    return (utc(CLOCK) + timedelta(seconds=seconds, days=days)).isoformat().replace("+00:00", "Z")


def _write_request(path, payload):
    path.write_text(json.dumps(payload, allow_nan=False), encoding="utf-8")
    return SimpleNamespace(input=path)


def _review(work, database, raw, edition, request, *, clock=CLOCK):
    with StateStore(database, scope="synthetic") as state:
        return _application()._review(_write_request(work / "controlled-input.json", request), state,
                                      raw, edition, clock, "HISTORICAL_REPLAY")


def _inventory(work, database, raw, edition, session):
    accounts = session["accounts"]
    altered = {"main": {**accounts["main"], "godly:FixtureUnknown": 2}, "alt": accounts["alt"]}
    result = _review(work, database, raw, edition, {"accounts": altered})
    portfolio = result["report"]["portfolio"]
    main, alt = portfolio["accounts"]["main"], portfolio["accounts"]["alt"]
    require(main["unpriced_copies"] == 2 and portfolio["combined"]["total_listed_value"] is None
            and alt["unpriced_copies"] == 0, "UNPRICED_OR_ACCOUNT_SEPARATION_LOST")
    require(any(p["publisher_id"] == "chroma:CFang" and p["valuation"] == "SUPREME_LISTED"
                for p in main["positions"]), "VARIANT_IDENTITY_LOST")
    require(main["reported_protected_copies"] >= 1, "TARGET_PROTECTION_MISSING")
    original = _review(work, database, raw, edition, {"accounts": accounts})
    require(original["inputRevision"] > result["inputRevision"]
            and original["report"]["portfolio"]["combined"]["total_listed_value"] is not None,
            "CONTROLLED_INVENTORY_REVISION_MISSING")
    return {"account_snapshots": len(portfolio["accounts"]), "unpriced_copies": main["unpriced_copies"],
            "inventory_compositions": 2, "variant_identity_confirmed": True, "protected_holding_confirmed": True}


def _strategy(work, database, raw, edition, session):
    request = {"accounts": session["accounts"], "counterparties": [
        session["counterpartyStock"], {"godly:Boneblade": 1, "godly:Orange_Seer": 1, "godly:Gemstone": 1},
        {"godly:Green_Luger": 1, "ancient:Harvester": 1},
    ], "search": {"max_steps": 3, "include_loss_research": True}}
    result = _review(work, database, raw, edition, request)
    report = result["report"]
    plan = report["planning"]
    choices = plan["alternatives"]
    require(plan["source"]["archiveSha256"] == edition.identity and choices and plan["routes"],
            "STRATEGY_NOT_BOUND_TO_MARKET")
    shapes = {offer["shape_by_physical_slots"] for offer in choices}
    require(shapes >= {"upgrade", "downgrade", "sidegrade"}, "STRATEGY_SHAPES_MISSING")
    require(all(offer["main_slots"] <= 4 and offer["partner_slots"] <= 4
                and offer["main_listed_delta"] == -offer["counterparty_listed_delta"]
                and offer["main_listed_delta"] >= 0 and "ancient:Gingerscope" not in offer["give"]
                for offer in choices), "UNSAFE_CANDIDATE_GENERATED")
    require(plan["arbitration"]["nondominated_alternative_indices"]
            and plan["arbitration"]["preferred_alternative"] is None
            and plan["approved_loss_budget"] is None
            and plan["acceptance_probability"] is None and plan["measured_retrade_liquidity"] is None
            and all(value is False for value in report["authority"].values()), "INFERRED_AUTHORITY_OR_EVIDENCE")
    return result, {"alternatives": len(choices), "routes": len(plan["routes"]), "shapes": sorted(shapes),
                    "both_ledgers_agree": True, "protected_risk_arbitration": True}


def _event(session, sequence, revision, kind):
    return {"session_id": session, "event_id": f"{session}-{sequence}", "sequence": sequence,
            "revision": revision, "kind": kind}


def _independent_outcome(state, name, kind, offer, now, *, terminal_in_trade=True):
    owner = state.start_session(name, account="main", now=now, lease_until=_instant(120))
    if terminal_in_trade:
        state.observe(_event(name, 1, 0, "PARTNER_REQUEST_ACCEPTED"), owner=owner, now=now)
        offered = dict(_event(name, 2, 1, "OFFER_OBSERVED"), give=offer["give"], receive=offer["receive"])
        state.observe(offered, owner=owner, now=now)
        terminal = _event(name, 3, 1, kind)
    else:
        terminal = _event(name, 1, 0, kind)
    require(state.observe(terminal, owner=owner, now=now), "TERMINAL_OBSERVATION_REJECTED")
    require(state.observe(terminal, owner=owner, now=now) is False, "TERMINAL_DUPLICATE_APPLIED")


def _strategy_session(work, database, raw, edition, session):
    name, stock = session["sessionId"], session["counterpartyStock"]
    with StateStore(database, scope="synthetic") as state:
        owner = state.start_session(name, account="main", now=CLOCK, lease_until=_instant(120),
                                    counterparty=stock)
        try:
            starting = state.inputs()["inputRevision"]
            result, checks = _strategy(work, database, raw, edition, session)
            require(result["inputRevision"] == starting and state.summary()["activeSessions"] == 1,
                    "STRATEGY_INPUTS_DIFFER_FROM_SESSION_LEASE")
        except BaseException:
            state.stop_session(name, owner=owner, now=CLOCK)
            raise
    return owner, result, {**checks, "session_lease_matches_strategy_inputs": True}


def _lifecycle(work, database, raw, edition, host, owner):
    app = _application()
    session = host["session"]
    name, accounts, stock = session["sessionId"], session["accounts"], session["counterpartyStock"]
    events = session["events"]
    require([event["kind"] for event in events] == [
        "PARTNER_REQUEST_ACCEPTED", "OFFER_OBSERVED", "PARTNER_OFFER_REVISION",
    ], "HOST_EVENT_SEQUENCE_UNSUPPORTED")
    portfolio = app._portfolio_view(accounts, edition)
    with StateStore(work / "controlled-unsettled.sqlite", scope="synthetic") as state:
        state.sync_inputs(**app._input_fields(state, edition, accounts))
        for label, kind, in_trade in (
            ("controlled-decline", "PARTNER_DECLINED", False),
            ("controlled-interrupt", "SESSION_INTERRUPTED", True),
            ("controlled-unknown", "CLIENT_WINDOW_CLOSED_UNKNOWN", True),
        ):
            _independent_outcome(state, label, kind, events[1], CLOCK, terminal_in_trade=in_trade)
        require(state.summary()["activeSessions"] == 0 and state.summary()["unresolvedSessions"] == 2
                and state.summary()["syntheticSettlements"] == 0 and state.summary()["realizedGrowth"] is None,
                "NON_SETTLEMENT_CHANGED_ACCOUNTING")
    with StateStore(database, scope="synthetic") as state:
        try:
            starting = state.inputs()["inputRevision"]
            require(state.observe(events[0], owner=owner, now=CLOCK), "REQUEST_ACCEPTANCE_NOT_RECORDED")
            evaluations = []
            for event, lua_evidence in zip(events[1:], host["offer_evidence"], strict=True):
                require(state.observe(event, owner=owner, now=CLOCK), "HOST_OFFER_NOT_RECORDED")
                evaluated = app._controlled_offer_view(raw, edition, CLOCK, accounts, stock, event)
                require(evaluated.get("disposition") == "NON_LOSS_PAPER_COMPARISON", "HOST_OFFER_NOT_ELIGIBLE")
                require({
                    "revision": event["revision"],
                    "physical_give_slots": evaluated["main_slots"],
                    "physical_receive_slots": evaluated["partner_slots"],
                    "outgoing_listed": evaluated["main_given_listed_value"],
                    "incoming_listed": evaluated["main_received_listed_value"],
                    "listed_delta": evaluated["main_listed_delta"],
                } == lua_evidence, "CROSS_LANGUAGE_OFFER_ECONOMICS_MISMATCH")
                evaluations.append(app._record_controlled_offer(
                    state, starting, event, evaluated, portfolio, edition, CLOCK, "HISTORICAL_REPLAY",
                ))
                require(state.current_evaluation(evaluations[-1]["evaluationId"], now=CLOCK) is not None,
                        "CURRENT_HOST_EVALUATION_MISSING")
            first, final = evaluations
            require(first["offer"]["main_listed_delta"] == 5
                    and final["offer"]["main_listed_delta"] == 8, "SUPREME_BILATERAL_DELTA_MISMATCH")
            old = first["evaluationId"]
            require(state.current_evaluation(old, now=CLOCK) is None and state.evaluation_history(old),
                    "STALE_OFFER_STILL_CURRENT")
            require(state.observe(events[-1], owner=owner, now=CLOCK) is False, "OFFER_DUPLICATE_APPLIED")
        except BaseException:
            state.stop_session(name, owner=owner, now=CLOCK)
            raise
    return evaluations, {"controlled_offer_revisions": len(evaluations), "small_gain_supported": True,
                         "historical_offer_retained": True, "stale_offer_invalidated": True,
                         "distinct_unsettled_outcomes": 3, "cross_language_economics_agree": True}


def _stock_after(before, give, receive):
    after = before.copy()
    for item, count in give.items():
        remaining = after[item] - count
        require(remaining >= 0, "IMPOSSIBLE_FIXTURE_BALANCE")
        if remaining:
            after[item] = remaining
        else:
            del after[item]
    for item, count in receive.items():
        after[item] = after.get(item, 0) + count
    return after


def _learning_fixture(session, edition, evaluations, transaction):
    context = {"schema": "gingerscope-synthetic-learning-event-v1", "scope": "synthetic",
               "partner_group": "synthetic:525",
               "session_digest": sha256(session.encode("ascii")).hexdigest()}
    events = [
        {**context, "seq": 1, "revision": 0, "at_utc": CLOCK, "kind": "REQUEST_OBSERVED"},
        {**context, "seq": 2, "revision": 0, "at_utc": CLOCK, "kind": "REQUEST_ACCEPTED"},
    ]
    feature_names = {"main_listed_delta": "listed_delta", "main_slots": "give_slots",
                     "partner_slots": "receive_slots", "main_copies": "give_copies",
                     "partner_copies": "receive_copies"}
    for evaluation in evaluations:
        revision = evaluation["offerRevision"]
        events.append({**context, "seq": len(events) + 1, "revision": revision, "at_utc": CLOCK,
                       "kind": "OFFER_OBSERVED" if revision == 1 else "OFFER_REVISED",
                       "market_edition": edition.identity,
                       "market_published_at_utc": utc(edition.provenance["publisherUpdatedAt"]).isoformat().replace("+00:00", "Z"),
                       "features_at_utc": CLOCK,
                       **{dest: evaluation["offer"][source] for source, dest in feature_names.items()}})
    horizon = _instant(seconds=1, days=7)
    events.append({**context, "seq": len(events) + 1, "revision": evaluations[-1]["offerRevision"],
                   "at_utc": horizon, "kind": "PORTFOLIO_FOLLOWUP", "portfolio_through_utc": horizon,
                   "realized_listed_delta": evaluations[-1]["offer"]["main_listed_delta"],
                   "transaction_digest": sha256(transaction.encode("ascii")).hexdigest()})
    return {"schema": "gingerscope-qualification-evidence-v1", "events": events,
            "train_before_utc": _instant(days=8), "observed_through_utc": _instant(days=9)}


def _private_evidence(private, source, database, fixture):
    command = [sys.executable, "-m", "scripts.qualification_evidence", "--public-root", str(ROOT),
               "--public-revision", source["public"]["revision"], "--private-revision", source["private"]["revision"],
               "--database", str(database), "--fixture", str(fixture)]
    received = _wire_json(_child(command, cwd=private, error="PRIVATE_EVIDENCE_PROCESS_FAILED",
                                 environment={"PYTHONPATH": "", "PYTHONNOUSERSITE": "1"}))
    expected = {"schema": "gingerscope-qualification-private-result-v1", "status": "PASS",
                "public_revision": source["public"]["revision"], "private_revision": source["private"]["revision"],
                "synthetic_settlements": 1, "growth_labels": 1, "immediate_labels": 0,
                "v2_rejected_synthetic": True, "learner_abstained": True, "real_training_rows": 0,
                "realized_growth": None, "authoritative_settlement_verified": False,
                "deployment_authorized": False}
    require(type(received) is dict and _canonical(received) == _canonical(expected), "PRIVATE_EVIDENCE_CONTRACT_FAILED")
    return {"status": "PASS", "synthetic_growth_labels": 1, "immediate_labels": 0,
            "real_training_rows": 0, "learner_abstained": True}


def _canonical(value):
    return json.dumps(value, sort_keys=True, allow_nan=False)


def _accounting(work, database, raw, edition, session, owner, evaluations, private, report, original):
    app = _application()
    name, accounts, stock = session["sessionId"], session["accounts"], session["counterpartyStock"]
    final = evaluations[-1]
    give, receive = final["offer"]["give"], final["offer"]["receive"]
    after = {"main": _stock_after(accounts["main"], give, receive), "alt": accounts["alt"]}
    transaction = "controlled-synthetic-settlement"
    settlement = {"owner": owner, "now": _instant(1), "transaction_id": transaction,
                  "revision": final["offerRevision"], "witnesses": [
                      {"side": "account", "source_id": "fixture-account", "before": accounts["main"],
                       "after": after["main"]},
                      {"side": "counterparty", "source_id": "fixture-counterparty", "before": stock,
                       "after": _stock_after(stock, receive, give)},
                  ]}
    with StateStore(database, scope="synthetic") as state:
        app._require_settlement_review(state, final, settlement["revision"], settlement["now"])
        require(state.settle_synthetic(name, **settlement), "SYNTHETIC_SETTLEMENT_FAILED")
    with StateStore(database, scope="synthetic") as recovered:
        require(recovered.settle_synthetic(name, **settlement) is False, "DUPLICATE_GAIN_APPLIED")
        status = recovered.summary()
        require(status["activeSessions"] == 0 and status["unresolvedSessions"] == 0
                and status["syntheticSettlements"] == 1 and status["syntheticListedDelta"] == 8
                and status["realizedGrowth"] is None and not status["authoritativeSettlementVerified"],
                "ACCOUNTING_SCOPE_BREACHED")
        require(recovered.inputs()["accounts"] == after
                and recovered.current_evaluation(final["evaluationId"], now=_instant(1)) is None,
                "SETTLED_PORTFOLIO_REVISION_MISMATCH")
    eligibility = {"status": "PRIVATE_EVIDENCE_REQUIRED"}
    if private is not None:
        fixture = work / "controlled-learning.json"
        fixture.write_text(_canonical(_learning_fixture(name, edition, evaluations, transaction)), encoding="utf-8")
        eligibility = _private_evidence(private, report["source"], database, fixture)

    # Recompute after reconciliation using the same application review path.
    refreshed = _review(work, database, raw, edition, {
        "accounts": after, "counterparties": [{"godly:Green_Luger": 1}], "search": {"max_steps": 1},
    }, clock=settlement["now"])
    require(refreshed["inputRevision"] > original["inputRevision"]
            and refreshed["report"]["portfolio"]["accounts"]["main"]["known_listed_value"]
            - original["report"]["portfolio"]["accounts"]["main"]["known_listed_value"] == 8
            and refreshed["report"]["portfolio"]["accounts"]["alt"] == original["report"]["portfolio"]["accounts"]["alt"]
            and refreshed["report"]["planning"]["routes"] == []
            and refreshed["report"]["planning"]["alternatives"], "POST_SETTLEMENT_RECALCULATION_FAILED")
    return {"synthetic_settlements": 1, "synthetic_listed_delta": 8, "settled_session_owner_released": True,
            "duplicate_ignored_after_restart": True, "portfolio_recalculated": True,
            "private_evidence": eligibility}


def _execute(args, work, report):
    database = work / "integrated.sqlite"

    def stage(number, operation):
        name = STAGES[number - 1]
        print(f"[{number}/7] {name}", file=sys.stderr, flush=True)
        started = perf_counter()
        row = {"stage": number, "name": name}
        report["stages"].append(row)
        try:
            details = operation()
        except KeyboardInterrupt:
            row.update(status="STOPPED", reason="OPERATOR_STOPPED")
            raise
        except QualificationError as error:
            row.update(status="FAILED", reason=str(error))
            raise
        except (OSError, ValueError, TypeError, KeyError, sqlite3.Error, ImportError, RuntimeError) as error:
            code = str(error)
            reason = code if re.fullmatch(r"[A-Z][A-Z0-9_]{5,75}", code) else f"STAGE_{number}_CONTRACT_FAILED"
            row.update(status="FAILED", reason=reason)
            raise QualificationError(row["reason"]) from None
        finally:
            row["duration_seconds"] = round(perf_counter() - started, 6)
        row.update(status="PASS")
        return row, details

    row, (raw, edition, private, host, checks) = stage(1, lambda: _startup(args, report, work))
    row["checks"] = checks
    session = host["session"]
    row, checks = stage(2, lambda: _inventory(work, database, raw, edition, session))
    row["checks"] = checks
    row, (owner, original, checks) = stage(3, lambda: _strategy_session(work, database, raw, edition, session))
    row["checks"] = checks
    row, (evaluations, checks) = stage(4, lambda: _lifecycle(work, database, raw, edition, host, owner))
    row["checks"] = checks
    row, checks = stage(5, lambda: _accounting(work, database, raw, edition, session, owner,
                                               evaluations, private, report, original))
    row["checks"] = checks
    if args.public_only:
        row["status"] = "PASS_PUBLIC_CHECKS_PRIVATE_EVIDENCE_REQUIRED"

    def endurance():
        from pdiddler.system2.qualification_endurance import run_endurance

        return run_endurance(work, clock=CLOCK, catalog=raw, cycles=args.cycles)

    def adversarial():
        from pdiddler.system2.qualification_adversarial import run_adversarial

        return run_adversarial(work, clock=CLOCK, catalog=raw)

    row, checks = stage(6, endurance)
    row["checks"] = checks
    row, checks = stage(7, adversarial)
    row["checks"] = checks


def _copy_receipt(path, report):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                         prefix=".gingerscope-", delete=False) as output:
            temporary = Path(output.name)
            output.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
            output.flush()
            os.fsync(output.fileno())
        os.link(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def qualify(args):
    """Produce one sanitized qualification receipt and an operator exit status."""
    report = {"schema": "gingerscope-full-system-qualification-v1", "status": "FAILED",
              "evidence_tier": "CONTROLLED_HISTORICAL_REPLAY", "source": {}, "stages": [],
              "authoritative_settlement_verified": False, "realized_growth": None,
              "real_training_rows": 0, "deployment_authorized": False, "live_mm2_verified": False}
    exit_status = 2
    try:
        with tempfile.TemporaryDirectory(prefix="gingerscope-qualification-") as directory:
            _execute(args, Path(directory), report)
        report["status"] = "PASS_PUBLIC_SCOPE" if args.public_only else "PASS_FULL"
        exit_status = 0
    except QualificationError:
        pass
    except OSError:
        if report["stages"]:
            report["cleanup_status"] = "SCRATCH_CLEANUP_FAILED"
        else:
            report["stages"].append(
                {"stage": 1, "name": STAGES[0], "status": "FAILED", "reason": "SCRATCH_UNAVAILABLE"}
            )
    except KeyboardInterrupt:
        report["status"] = "STOPPED"
        exit_status = 130
    if args.copy_to is not None and not (
        report["stages"] and report["stages"][0].get("reason") == "COPY_PATH_UNAVAILABLE"
    ):
        try:
            _copy_receipt(args.copy_to, report)
        except OSError:
            report["copy_status"] = "COPY_PATH_UNAVAILABLE"
            if exit_status == 0:
                exit_status = 2
        except KeyboardInterrupt:
            report["status"] = "STOPPED"
            report["copy_status"] = "COPY_INTERRUPTED"
            exit_status = 130
    return report, exit_status
