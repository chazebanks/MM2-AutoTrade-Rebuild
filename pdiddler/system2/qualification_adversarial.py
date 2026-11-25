"""Challenge the controlled candidate using only disposable synthetic state."""

from contextlib import closing
from datetime import timedelta
from hashlib import sha256
from pathlib import Path
import sqlite3
from tempfile import TemporaryDirectory
from unittest.mock import patch

from pdiddler.system2 import manual_portfolio_review as manual
from pdiddler.system2.application_state import StateError, StateStore
from pdiddler.system2.discord_v2_event_intake import CLIENT_PROOF, SCHEMA, SOURCE
from pdiddler.system2.manual_portfolio_review import RequestError
from pdiddler.system2.portfolio_planner import evaluate_offer, plan
from pdiddler.system2.private_v2_response_learning_gate import compile_client_evidence
from pdiddler.system2.supreme_market_editions import load_edition
from pdiddler.system2.supreme_only_strategy_research import SupremeOnlyBlocked, utc


_FANG = "godly:Fang"
_GEMSTONE = "godly:Gemstone"
_PLASMABEAM = "godly:Plasmabeam"
_TARGET = "ancient:Gingerscope"
_UNKNOWN = "godly:QualificationUnknown"


class AdversarialError(ValueError):
    """A failed qualification invariant identified by a fixed, public code."""


def _check(checks, name, condition):
    if not condition:
        raise AdversarialError(name.upper())
    checks[name] = True


def _rejects(call, exception):
    try:
        call()
    except exception:
        return True
    return False


def _economy(catalog, edition, clock, checks):
    settings = {"evaluated_at_utc": clock, "edition": edition}
    main = {_FANG: 1, "ancient:Harvester": 1, _TARGET: 1, _UNKNOWN: 2}
    opponent = {_GEMSTONE: 1}

    def evaluate(give, receive):
        return evaluate_offer(catalog, main, opponent, give, receive, **settings)

    _check(checks, "invalid_quantities", all(
        _rejects(lambda: evaluate({_FANG: quantity}, opponent), RequestError)
        for quantity in (True, 0, -1, 1.0, "1", 2)
    ) and _rejects(lambda: evaluate({_FANG: 1}, {_GEMSTONE: 2}), RequestError))
    report = plan(catalog, main, [opponent, {"godly:Boneblade": 1}],
                  include_loss_research=True, **settings)
    alternatives = report["alternatives"]
    steps = alternatives + [step for route in report["routes"] for step in route["steps"]]
    _check(checks, "protected_outgoing", bool(alternatives)
           and _rejects(lambda: evaluate({_TARGET: 1}, opponent), RequestError)
           and all(_TARGET not in step["give"] for step in steps))
    opening = report["starting_account"]
    _check(checks, "unknown_valuation", opening["unpriced_copies"] == 2
           and opening["total_listed_value"] is None
           and all(_UNKNOWN not in step["give"] for step in steps)
           and _rejects(lambda: evaluate({_UNKNOWN: 1}, opponent), RequestError))
    _check(checks, "historical_rules_inactive", any(
        row["give"] == {_FANG: 1} and row["receive"] == opponent
        and row["main_listed_delta"] == 5 and row["counterparty_listed_delta"] == -5
        and 100 * row["main_given_listed_value"] < 90 * row["main_received_listed_value"]
        for row in alternatives
    ) and report["arbitration"]["preferred_alternative"] is None
       and report["acceptance_probability"] is None and report["measured_retrade_liquidity"] is None)
    _check(checks, "loss_authority_unapproved", bool(report["listed_loss_research"])
           and report["approved_loss_budget"] is None
           and all(step["main_listed_delta"] >= 0 and step["authorizes_trade"] is False for step in steps)
           and all(row["main_listed_delta"] < 0 and row["disposition"] == "LISTED_LOSS_RESEARCH_ONLY"
                   for row in report["listed_loss_research"]))


def _observe(state, session, owner, clock, sequence, revision, kind, **terms):
    return state.observe({
        "session_id": session, "event_id": f"{session}-{sequence}", "sequence": sequence,
        "revision": revision, "kind": kind, **terms,
    }, owner=owner, now=clock)


def _witnesses(account_before, account_after, partner_before, partner_after):
    return [
        {"side": "account", "source_id": "qualification-observer-one",
         "before": account_before, "after": account_after},
        {"side": "counterparty", "source_id": "qualification-observer-two",
         "before": partner_before, "after": partner_after},
    ]


def _state_checks(path, edition, clock, checks):
    captured = edition.provenance["capturedUtc"]
    expires = edition.provenance["expiresUtc"]
    expired = (utc(expires) + timedelta(seconds=1)).isoformat()
    later = (utc(clock) + timedelta(seconds=1)).isoformat()
    lease_end = (utc(clock) + timedelta(seconds=60)).isoformat()
    starting = {"main": {_FANG: 1}, "alt": {_TARGET: 1}}
    partner = {_GEMSTONE: 1, _PLASMABEAM: 1}
    initial = {
        "market_sha256": edition.identity, "publisher_updated_at": edition.provenance["publisherUpdatedAt"],
        "captured_at": captured, "expires_at": expires, "accounts": starting,
        "listed_values": {
            f"{row['category']}:{row['officialItemId']}": row["supremeListed"]
            for row in edition.rows.values()
        },
    }
    session = "adversarial-reference"
    with StateStore(path, scope="synthetic") as state:
        revision = state.sync_inputs(**initial)
        _check(checks, "untrusted_market", _rejects(lambda: state.start_session(
            "adversarial-expired", account="main", now=expired,
            lease_until=(utc(expired) + timedelta(seconds=1)).isoformat(),
        ), StateError) and state.summary()["activeSessions"] == 0)
        owner = state.start_session(session, account="main", now=clock,
                                    lease_until=lease_end, counterparty=partner)
        _check(checks, "conflicting_ownership", _rejects(lambda: state.start_session(
            "adversarial-contender", account="alt", now=clock, lease_until=lease_end,
        ), StateError) and state.summary()["activeSessions"] == 1)
        _observe(state, session, owner, clock, 1, 0, "PARTNER_REQUEST_ACCEPTED")
        _observe(state, session, owner, clock, 2, 1, "OFFER_OBSERVED",
                 give={_FANG: 1}, receive={_GEMSTONE: 1})
        state.record_evaluation("adversarial-evaluation", input_revision=revision, report={},
                                evaluated_at=clock, session_id=session, offer_revision=1)
        initial_active = state.current_evaluation("adversarial-evaluation", now=clock)
        _observe(state, session, owner, later, 3, 2, "PARTNER_OFFER_REVISION",
                 give={_FANG: 1}, receive={_PLASMABEAM: 1})
        _check(checks, "stale_offer_revision", initial_active is not None
               and state.current_evaluation("adversarial-evaluation", now=later) is None
               and state.evaluation_history("adversarial-evaluation")["offerRevision"] == 1
               and _rejects(lambda: _observe(state, session, owner, later, 4, 1,
                                             "PARTNER_ACCEPT_INDICATOR"), StateError))
        for sequence, kind in enumerate(("MAIN_ACCEPT_INDICATOR", "PARTNER_ACCEPT_INDICATOR",
                                         "CLIENT_INVENTORY_DELTA_OBSERVED", "CLIENT_WINDOW_CLOSED_UNKNOWN"), 4):
            _observe(state, session, owner, later, sequence, 2, kind)
        summary = state.summary()
        _check(checks, "unproved_completion", summary["unresolvedSessions"] == 1
               and summary["syntheticSettlements"] == 0 and summary["realizedGrowth"] is None
               and summary["authoritativeSettlementVerified"] is False
               and state.inputs()["accounts"] == starting)

        session = "adversarial-one-sided"
        owner = state.start_session(session, account="main", now=later,
                                    lease_until=lease_end, counterparty=partner)
        _observe(state, session, owner, later, 1, 0, "PARTNER_REQUEST_ACCEPTED")
        _observe(state, session, owner, later, 2, 1, "OFFER_OBSERVED",
                 give={}, receive={_GEMSTONE: 1})
        one_sided = _witnesses(starting["main"], {_FANG: 1, _GEMSTONE: 1}, partner, {_PLASMABEAM: 1})
        _check(checks, "one_sided_settlement", _rejects(lambda: state.settle_synthetic(
            session, owner=owner, now=later, transaction_id="adversarial-gift", revision=1,
            witnesses=one_sided,
        ), StateError) and state.synthetic_settlement_rows() == [] and state.inputs()["accounts"] == starting)
        state.stop_session(session, owner=owner, now=later)

        session = "adversarial-replay"
        owner = state.start_session(session, account="main", now=later,
                                    lease_until=lease_end, counterparty=partner)
        _observe(state, session, owner, later, 1, 0, "PARTNER_REQUEST_ACCEPTED")
        _observe(state, session, owner, later, 2, 1, "OFFER_OBSERVED",
                 give={_FANG: 1}, receive={_GEMSTONE: 1})
        settled_at = (utc(clock) + timedelta(seconds=2)).isoformat()
        receipt = {
            "owner": owner, "now": settled_at, "transaction_id": "qualification-transaction",
            "revision": 1,
            "witnesses": _witnesses(starting["main"], {_GEMSTONE: 1}, partner, {_FANG: 1, _PLASMABEAM: 1}),
        }
        newly_recorded = state.settle_synthetic(session, **receipt)
    with StateStore(path, scope="synthetic") as recovered:
        duplicate = recovered.settle_synthetic(session, **receipt)
        changed = [dict(witness, source_id="adversarial-forged-source") if index == 0 else witness
                   for index, witness in enumerate(receipt["witnesses"])]
        _check(checks, "replayed_gain", newly_recorded is True and duplicate is False
               and _rejects(lambda: recovered.settle_synthetic(session, **{**receipt, "witnesses": changed}),
                            StateError)
               and len(recovered.synthetic_settlement_rows()) == 1
               and recovered.summary()["syntheticListedDelta"] == 5
               and recovered.summary()["realizedGrowth"] is None
               and recovered.inputs()["accounts"] == {"main": {_GEMSTONE: 1}, "alt": {_TARGET: 1}}
               and _rejects(lambda: recovered.record_evaluation(
                   "adversarial-backdate", input_revision=recovered.inputs()["inputRevision"],
                   report={}, evaluated_at=clock,
               ), StateError))
        lease_session = "adversarial-leased"
        lease_owner = recovered.start_session(lease_session, account="main", now=settled_at, lease_until=lease_end)
        retired = recovered.recover(now=lease_end)
        _check(checks, "expired_ownership_recovery", retired == 1 and recovered.recover(now=lease_end) == 0
               and _rejects(lambda: _observe(recovered, lease_session, lease_owner, lease_end,
                                             1, 0, "PARTNER_REQUEST_ACCEPTED"), StateError)
               and recovered.summary()["activeSessions"] == 0)


def _learning_check(clock, checks):
    channel, webhook = "1523456789012345678", "1623456789012345678"
    shared = {
        "schema": SCHEMA, "source": SOURCE, "scope": "MAIN_ALT_TEST",
        "channel_id": channel, "webhook_id": webhook, "client_provenance": CLIENT_PROOF,
        "recorded_at_utc": utc(clock).isoformat(),
        **{key: sha256(key.encode()).hexdigest() for key in (
            "job_digest", "session_digest", "partner_digest", "lease_digest",
        )},
    }
    kinds = ("MAIN_REQUEST_PENDING", "PARTNER_REQUEST_ACCEPTED", "MAIN_OFFER_REVISION",
             "PARTNER_ACCEPT_INDICATOR", "CLIENT_INVENTORY_DELTA_OBSERVED", "CLIENT_WINDOW_CLOSED_UNKNOWN")
    rows = [{
        **shared, "message_id": str(1723456789000000000 + seq),
        "event_id": sha256(kind.encode()).hexdigest(), "event_seq": seq,
        "revision": int(seq >= 3), "kind": kind,
    } for seq, kind in enumerate(kinds, 1)]

    def analyze(evidence):
        return compile_client_evidence(evidence, expected_channel_id=channel,
                                       expected_webhook_id=webhook, private_collector_origin=True)

    response = analyze(rows)
    forged = analyze([{**rows[0], "completed": True}])
    _check(checks, "unsupported_learning_evidence",
           response["excludedMainAltTestSessionClaims"] == 1 and response["knownTradeSettlements"] == 0
           and response["realResponseRewardLabelsForModel"] == 0
           and response["mayUseForStrategyLearning"] is False
           and response["measuredTradeAcceptanceProbability"] is None
           and forged["status"] == "BLOCKED" and forged["mayUseForStrategyLearning"] is False)


def _failure_checks(directory, catalog, clock, checks):
    # Change only the path to a required pinned artifact. The production loader
    # still parses the real archived publication and handles the absent file.
    with patch.object(manual, "PARITY_RECEIPT", directory / "absent-supreme-parity.json"):
        _check(checks, "unavailable_dependency", _rejects(
            lambda: load_edition(catalog, evaluated_at_utc=clock), FileNotFoundError,
        ))
    path = directory / "unsupported-state.sqlite"
    path.touch(mode=0o600, exist_ok=False)
    with closing(sqlite3.connect(path)) as connection:
        connection.execute("PRAGMA user_version = 65535")
    original = path.read_bytes()
    try:
        with StateStore(path, scope="synthetic"):
            rejected = False
    except StateError as error:
        rejected = "no supported migration" in str(error)
    _check(checks, "invalid_state_recovery", rejected and path.read_bytes() == original)


def run_adversarial(workdir: Path, *, clock: str, catalog: bytes) -> dict:
    """Return only check names and aggregate results from the synthetic run."""
    try:
        edition = load_edition(catalog, evaluated_at_utc=clock)
    except SupremeOnlyBlocked:
        raise AdversarialError("UNTRUSTED_MARKET") from None
    expired = (utc(edition.provenance["expiresUtc"]) + timedelta(seconds=1)).isoformat()
    checks = {}
    if not (_rejects(lambda: load_edition(catalog, evaluated_at_utc=expired), SupremeOnlyBlocked)
            and _rejects(lambda: load_edition(catalog + b" ", evaluated_at_utc=clock,
                                             expected_sha256=edition.identity), SupremeOnlyBlocked)):
        raise AdversarialError("UNTRUSTED_MARKET")
    _economy(catalog, edition, clock, checks)
    with TemporaryDirectory(prefix="adversarial-", dir=workdir) as directory:
        directory = Path(directory)
        _state_checks(directory / "state.sqlite", edition, clock, checks)
        _failure_checks(directory, catalog, clock, checks)
    _learning_check(clock, checks)
    return {"status": "PASS", "checks": checks, "checksPassed": len(checks)}
