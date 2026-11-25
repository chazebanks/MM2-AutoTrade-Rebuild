"""Offline Gingerscope advisory, controlled session replay, and recovery."""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
from hashlib import sha256
import json
from pathlib import Path
import sqlite3
import sys

from pdiddler.system2.application_state import StateError, StateStore, encode_evaluation_report
from pdiddler.system2.manual_portfolio_review import (
    DEFAULT_CATALOG, MAX_REQUEST_BYTES, RequestError, _unique_keys, summarize_accounts,
)
from pdiddler.system2.portfolio_planner import evaluate_offer, plan
from pdiddler.system2.supreme_market_editions import (
    MAX_ARCHIVE_BYTES, capture_official, compare_editions, load_edition,
)
from pdiddler.system2.supreme_only_strategy_research import SupremeOnlyBlocked, utc


AUTHORITY = dict.fromkeys(
    ("authorizesTrade", "authorizesOffer", "authorizesAccept", "mayReportProfit",
     "maySendDiscordWebhook", "mayUseForStrategyLearning"), False,
)
OFFER_EVENTS = {"OFFER_OBSERVED", "MAIN_OFFER_REVISION", "PARTNER_OFFER_REVISION"}
MAX_SESSION_EVENTS = 128


def _read(path, limit):
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise RequestError("An input exceeds its size limit.")
    return raw


def _invalid_constant(_):
    raise RequestError("JSON values must be finite.")


def _read_request(path, *, required, optional=()):
    value = json.loads(_read(path, MAX_REQUEST_BYTES), object_pairs_hook=_unique_keys,
                       parse_constant=_invalid_constant)
    if type(value) is not dict or required - value.keys() or value.keys() - required - set(optional):
        raise RequestError("The input fields do not match this command.")
    return value


def _input_fields(state, edition, accounts):
    source = edition.provenance
    return {
        "market_sha256": edition.identity, "publisher_updated_at": source["publisherUpdatedAt"],
        "captured_at": source["capturedUtc"], "expires_at": source["expiresUtc"], "accounts": accounts,
        "listed_values": {
            f"{row['category']}:{row['officialItemId']}": row["supremeListed"]
            for row in edition.rows.values()
        } if state.scope == "synthetic" else None,
    }


def _record(state, revision, report, clock, *, session_id=None, offer_revision=None):
    if state is None:
        return None
    evaluation_id = _evaluation_key(revision, clock, session_id, offer_revision, report)
    state.record_evaluation(evaluation_id, input_revision=revision, report=report, evaluated_at=clock,
                            session_id=session_id, offer_revision=offer_revision)
    return evaluation_id


def _evaluation_key(revision, clock, session_id, offer_revision, report):
    fields = [revision, utc(clock).isoformat(), session_id, offer_revision, report]
    return sha256(json.dumps(fields, sort_keys=True, allow_nan=False).encode()).hexdigest()


def _current_report(state, evaluation_id, clock):
    record = state.current_evaluation(evaluation_id, now=clock)
    if record is not None:
        report = record["report"]
        expected_id = _evaluation_key(
            record["inputRevision"], record["evaluatedAt"], record["sessionId"],
            record["offerRevision"], report,
        )
        if (type(report) is not dict or expected_id != evaluation_id
                or report.get("authority") != AUTHORITY
                or any(flag is not False for flag in report["authority"].values())):
            raise StateError("The stored evaluation report failed integrity verification.")
    return record


def _portfolio_view(accounts, edition):
    portfolio = summarize_accounts(accounts, edition.rows)
    priced = {f"{row['category']}:{row['officialItemId']}": row for row in edition.rows.values()}
    for name, holdings in accounts.items():
        positions = []
        for key, quantity in sorted(holdings.items()):
            row = priced.get(key)
            protected = key.split(":", 1)[1].casefold() == "gingerscope"
            positions.append({
                "publisher_id": key,
                "reported_copies": quantity,
                "listed_value_per_copy": row["supremeListed"] if row else None,
                "valuation": "SUPREME_LISTED" if row else "UNPRICED",
                "market_identity_status": edition.identity_status(key),
                "outgoing_protected": protected or bool(row and row["outgoingGingerscopeProtected"]),
            })
        portfolio["accounts"][name]["positions"] = positions
        portfolio["accounts"][name]["reported_protected_copies"] = sum(
            item["reported_copies"] for item in positions if item["outgoing_protected"]
        )
    return portfolio


def _review(args, state, catalog, edition, clock, clock_kind):
    request = _read_request(args.input, required={"accounts"},
                            optional={"counterparties", "search", "offer"})
    portfolio = _portfolio_view(request["accounts"], edition)
    search = request.get("search", {})
    if type(search) is not dict or search.keys() - {
        "max_steps", "max_pairs", "max_bundles_per_side", "copies_per_slot", "include_loss_research",
    }:
        raise RequestError("Search settings contain unsupported fields.")
    planning = None
    if "counterparties" in request:
        planning = plan(catalog, request["accounts"]["main"], request["counterparties"],
                        evaluated_at_utc=clock, edition=edition, **search)
    elif search:
        raise RequestError("Search settings require explicit hypothetical counterparties.")

    offer = None
    if "offer" in request:
        supplied = request["offer"]
        required = {"give", "receive", "counterpartyStock"}
        if type(supplied) is not dict or required - supplied.keys() or (
            supplied.keys() - required - {"copiesPerSlot"}
        ):
            raise RequestError("Enter both sides of the offer and supplied counterparty stock.")
        offer = evaluate_offer(
            catalog, request["accounts"]["main"], supplied["counterpartyStock"],
            supplied["give"], supplied["receive"], copies_per_slot=supplied.get("copiesPerSlot", 1),
            evaluated_at_utc=clock, edition=edition,
        )

    report = {"mode": "OFFLINE_ADVISORY", "clock": clock_kind, "market": edition.summary(),
              "portfolio": portfolio, "planning": planning, "offer": offer, "authority": AUTHORITY}
    if state is not None:
        encode_evaluation_report(report)
    revision = state.sync_inputs(**_input_fields(state, edition, request["accounts"])) if state else None
    evaluation = _record(state, revision, report, clock)
    return {"inputRevision": revision, "evaluationId": evaluation, "clock": clock_kind, "report": report}


def _simulate(args, state, catalog, edition, clock, clock_kind):
    if state is None or not args.synthetic:
        raise RequestError("Session simulation requires a synthetic state database.")
    request = _read_request(args.input,
                            required={"accounts", "sessionId", "counterpartyStock", "events"},
                            optional={"settlement"})
    portfolio = _portfolio_view(request["accounts"], edition)
    session_id = request["sessionId"]
    events = request["events"]
    if (type(events) is not list or not 1 <= len(events) <= MAX_SESSION_EVENTS
            or any(type(event) is not dict or type(event.get("kind")) is not str
                   or event.get("session_id") != session_id for event in events)):
        raise RequestError("Provide bounded observations for one controlled session.")
    settlement = request.get("settlement")
    if "settlement" in request and (
        type(settlement) is not dict
        or set(settlement) != {"transaction_id", "revision", "witnesses", "at"}
        or utc(settlement["at"]) <= utc(clock)
    ):
        raise RequestError("Synthetic corroboration needs a transaction ID, revision, both witnesses "
                           "and a timestamp after the offer observations.")

    # Compute the economic views before taking ownership. State validation still
    # checks sequence, offer revision and phase before recording each view.
    views = {}
    for index, event in enumerate(events):
        if event.get("kind") in OFFER_EVENTS:
            try:
                views[index] = evaluate_offer(
                    catalog, request["accounts"]["main"], request["counterpartyStock"],
                    event.get("give"), event.get("receive"), evaluated_at_utc=clock,
                    edition=edition,
                )
            except RequestError as error:
                # Preserve a validly shaped observation even when its economic
                # inputs cannot justify a recommendation.
                views[index] = {"status": "ABSTAIN", "reason": str(error)}

    lease_until = (utc(clock) + timedelta(minutes=2)).isoformat()
    owner = state.start_session(session_id, account="main", now=clock, lease_until=lease_until,
                                counterparty=request["counterpartyStock"],
                                inputs=_input_fields(state, edition, request["accounts"]))
    evaluations = []
    try:
        revision = state.inputs()["inputRevision"]
        for index, event in enumerate(events):
            is_new = state.observe(event, owner=owner, now=clock)
            if is_new and index in views:
                report = {"mode": "CONTROLLED_OBSERVATION", "clock": clock_kind,
                          "market": edition.summary(), "portfolio": portfolio,
                          "offer": views[index], "authority": AUTHORITY}
                offer_revision = event["revision"]
                evaluation = _record(state, revision, report, clock, session_id=session_id,
                                     offer_revision=offer_revision)
                evaluations.append({"evaluationId": evaluation, "offerRevision": offer_revision,
                                    "offer": views[index]})
        if settlement is not None:
            state.settle_synthetic(
                session_id, owner=owner, now=settlement["at"],
                transaction_id=settlement["transaction_id"], revision=settlement["revision"],
                witnesses=settlement["witnesses"],
            )
    finally:
        # A finished batch releases ownership even if evaluation failed midway.
        state.stop_session(session_id, owner=owner, now=clock)

    return {"mode": "CONTROLLED_REPLAY", "clock": clock_kind, "inputRevision": revision,
            "offerEvaluations": evaluations, "status": state.summary(), "authority": AUTHORITY}


def _parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, help="Local private SQLite state file")
    parser.add_argument("--synthetic", action="store_true", help="Use isolated synthetic fixtures")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--expected-market-sha256", help="Independently reviewed new archive hash")
    parser.add_argument("--replay-at", help="Historical evaluation clock with UTC offset")
    parser.add_argument("--text", action="store_true", help="Show a concise portfolio view for review")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("review", help="Analyze two accounts and optional hypothetical route inputs").add_argument(
        "input", type=Path,
    )
    commands.add_parser("simulate-session", help="Replay manual observations and release ownership").add_argument(
        "input", type=Path,
    )
    commands.add_parser("current", help="Read an evaluation only if its bindings remain current").add_argument(
        "evaluation_id",
    )
    commands.add_parser("status", help="Export a sanitized operational summary")
    commands.add_parser("recover", help="Release expired ownership and export sanitized status")
    commands.add_parser("capture-market", help="Capture current Supreme pages for review").add_argument(
        "output", type=Path,
    )
    transition = commands.add_parser("market-diff", help="Compare immutable Supreme capture contents")
    transition.add_argument("previous", type=Path)
    transition.add_argument("--previous-at", required=True, help="Previous archive's historical clock")
    transition.add_argument("--previous-sha256", help="Independently reviewed previous archive hash")
    return parser


def _execute(args, state, clock, clock_kind):
    command = args.command
    if command == "capture-market":
        return {"status": "PENDING_INDEPENDENT_REVIEW", "sha256": capture_official(args.output)}
    if command == "status":
        return state.summary()
    if command == "recover":
        retired = state.recover(now=clock)
        return {**state.summary(), "expiredSessionsRecovered": retired}
    if command == "current":
        return {"clock": clock_kind, "evaluation": _current_report(state, args.evaluation_id, clock)}

    catalog = _read(args.catalog, MAX_ARCHIVE_BYTES)
    edition = load_edition(catalog, evaluated_at_utc=clock, expected_sha256=args.expected_market_sha256)
    if command == "market-diff":
        previous = load_edition(_read(args.previous, MAX_ARCHIVE_BYTES), evaluated_at_utc=args.previous_at,
                                expected_sha256=args.previous_sha256)
        return {"clock": clock_kind, **compare_editions(previous, edition)}
    if command == "review":
        return _review(args, state, catalog, edition, clock, clock_kind)
    return _simulate(args, state, catalog, edition, clock, clock_kind)


def _text_review(review, *, color=False):
    report = review["report"]
    market = report["market"]
    heading = "\033[1;35m{}\033[0m" if color else "{}"
    account_heading = "\033[1;97;40m {} \033[0m" if color else "{}"
    lines = [
        heading.format("Gingerscope advisory"),
        f"Supreme edition {market['publisherUpdatedAt']}  |  Expires {market['expiresUtc']}",
        f"Clock {review['clock']}  |  Evaluation {review['evaluationId'] or 'unsaved'}",
    ]
    for name, account in report["portfolio"]["accounts"].items():
        lines.append(account_heading.format(name.upper()))
        for item in account["positions"]:
            price = item["listed_value_per_copy"]
            label = f"{price} each" if price is not None else item["market_identity_status"].lower()
            protection = "  protected" if item["outgoing_protected"] else ""
            lines.append(f"  {item['publisher_id']} × {item['reported_copies']}  {label}{protection}")
        lines.append(f"  Known listed wealth {account['known_listed_value']}  |  "
                     f"Four-slot single-copy ceiling {account['four_slot_single_copy_listed_ceiling']}")
    if report["planning"] is not None:
        lines.append("Hypothetical routes and tradeoffs are available in the JSON report.")
    if report["offer"] is not None:
        offer = report["offer"]
        lines.append(f"Paper offer change  Main {offer['main_listed_delta']:+d}  |  "
                     f"Counterparty {offer['counterparty_listed_delta']:+d}  |  {offer['disposition']}")
    return "\n".join(lines)


def main(argv=None):
    args = _parser().parse_args(argv)
    try:
        if args.database is None and args.command in {"status", "recover", "current", "simulate-session"}:
            raise RequestError("This command requires a state database.")
        if args.database is not None and args.replay_at is not None and not args.synthetic:
            raise RequestError("Historical runs use a separate synthetic database or no database.")
        if args.command == "capture-market" and (args.database is not None or args.replay_at is not None):
            raise RequestError("Capture uses the current clock and creates an archive for review.")
        if args.text and args.command != "review":
            raise RequestError("The text view is available for review reports.")
        clock = args.replay_at or datetime.now(timezone.utc).isoformat()
        clock = utc(clock).isoformat()
        clock_kind = "HISTORICAL_REPLAY" if args.replay_at is not None else "CURRENT_UTC"
        if args.database is None:
            result = _execute(args, None, clock, clock_kind)
        else:
            with StateStore(args.database, scope="synthetic" if args.synthetic else "manual") as state:
                result = _execute(args, state, clock, clock_kind)
        print(_text_review(result, color=sys.stdout.isatty()) if args.text
              else json.dumps(result, indent=2, allow_nan=False))
    except (RequestError, StateError, SupremeOnlyBlocked) as error:
        print(error, file=sys.stderr)
        return 2
    except (ValueError, OSError, sqlite3.Error, RecursionError):
        print("Gingerscope could not complete the command. Check the input schema, market integrity "
              "and expiry, or the local state database.", file=sys.stderr)
        return 2
    except ModuleNotFoundError as error:
        if error.name != "bs4":
            raise
        print("Install the pinned Gingerscope requirements to parse a reviewed Supreme capture.",
              file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("Gingerscope stopped.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
