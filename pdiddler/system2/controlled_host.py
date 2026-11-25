"""Validate observations emitted by the repository's controlled Lune host."""

from __future__ import annotations

import json

from pdiddler.system2.manual_portfolio_review import (
    ITEM_ID, MAX_ACCOUNT_COPIES_PER_ITEM, MAX_REQUEST_BYTES, PHYSICAL_SLOTS, _unique_keys,
)
from pdiddler.system2.supreme_market_editions import load_edition
from pdiddler.system2.supreme_only_strategy_research import utc


SCHEMA = "gingerscope-controlled-host-v1"
REPLAY_AT = "2026-11-25T07:52:05Z"
SESSION_ID = "controlled-host-trade"
READINESS = (
    "HEALTH_READY", "PART2_READY", "P3_OBSERVER_READY", "P4_BOUND",
    "P3_RESUMED", "LEASE_REVOKED", "STOPPED",
)
EVENT_FIELDS = {"event_id", "session_id", "sequence", "revision", "kind"}


class ControlledHostError(ValueError):
    """Invalid local synthetic host receipt."""


def _check(condition, reason):
    if not condition:
        raise ControlledHostError(reason)


def _exact_fields(value, fields):
    return type(value) is dict and value.keys() == fields


def _check_holdings(holdings):
    _check(
        type(holdings) is dict and len(holdings) <= 400
        and all(ITEM_ID.fullmatch(key) and type(quantity) is int
                and 1 <= quantity <= MAX_ACCOUNT_COPIES_PER_ITEM
                for key, quantity in holdings.items()),
        "The controlled host supplied invalid inventory.",
    )


def _reject_constant(_):
    raise ControlledHostError("The controlled host must emit finite JSON.")


def load_controlled_host(raw: bytes, *, catalog: bytes, clock: str) -> dict:
    """Ingest only a synthetic, edition-bound and non-settlement observation trace."""
    _check(
        type(raw) is bytes and 0 < len(raw) <= MAX_REQUEST_BYTES,
        "The controlled host receipt exceeds its size limit or is empty.",
    )
    try:
        document = json.loads(raw, object_pairs_hook=_unique_keys, parse_constant=_reject_constant)
        edition = load_edition(catalog, evaluated_at_utc=clock)
        same_clock = utc(clock) == utc(REPLAY_AT)
    except (ValueError, RecursionError):
        raise ControlledHostError("The controlled host JSON, replay clock, or Supreme archive is invalid.") from None

    _check(
        _exact_fields(document, {"schema", "evidence_class", "catalog_sha256", "replay_at",
                                 "live_authority", "readiness", "session", "offer_evidence"})
        and document["schema"] == SCHEMA and document["evidence_class"] == "SYNTHETIC_LUNE_OBSERVATION"
        and document["live_authority"] is False and document["readiness"] == list(READINESS),
        "The controlled host provenance or readiness receipt is invalid.",
    )
    _check(
        same_clock and document["replay_at"] == REPLAY_AT and document["catalog_sha256"] == edition.identity,
        "The controlled host and strategy have different replay clocks or market editions.",
    )
    session = document["session"]
    _check(
        _exact_fields(session, {"sessionId", "accounts", "counterpartyStock", "events"})
        and session["sessionId"] == SESSION_ID
        and _exact_fields(session["accounts"], {"main", "alt"}),
        "The controlled session has unknown fields or an invalid identity.",
    )
    main_inventory = session["accounts"]["main"]
    counterparty = session["counterpartyStock"]
    for holdings in (main_inventory, session["accounts"]["alt"], counterparty):
        _check_holdings(holdings)

    events = session["events"]
    evidence = document["offer_evidence"]
    _check(
        type(events) is list and len(events) == 3 and type(evidence) is list and len(evidence) == 2,
        "The controlled host must emit a request, an offer, and one revised offer.",
    )
    rows = {f"{row['category']}:{row['officialItemId']}": row for row in edition.rows.values()}
    for position, (event, kind) in enumerate(zip(events, (
        "PARTNER_REQUEST_ACCEPTED", "OFFER_OBSERVED", "PARTNER_OFFER_REVISION",
    ))):
        fields = EVENT_FIELDS | {"give", "receive"} if position else EVENT_FIELDS
        _check(
            _exact_fields(event, fields) and event["kind"] == kind
            and event["session_id"] == SESSION_ID and event["event_id"] == f"controlled-host-{position + 1}"
            and type(event["sequence"]) is int and event["sequence"] == position + 1
            and type(event["revision"]) is int and event["revision"] == position,
            "The controlled host event order, session, or revision is invalid.",
        )
        if not position:
            continue
        give, receive = event["give"], event["receive"]
        for terms, holdings in ((give, main_inventory), (receive, counterparty)):
            _check_holdings(terms)
            _check(
                1 <= len(terms) <= PHYSICAL_SLOTS
                and all(quantity == 1 and holdings.get(key, 0) >= quantity and key in rows
                        for key, quantity in terms.items()),
                "A controlled offer does not match its stock, Supreme identities, or slot limits.",
            )
        _check(
            not give.keys() & receive.keys()
            and not any(rows[key]["outgoingGingerscopeProtected"] for key in give),
            "The controlled outgoing offer contains a protected item or overlapping positions.",
        )
        outgoing = sum(rows[key]["supremeListed"] * quantity for key, quantity in give.items())
        incoming = sum(rows[key]["supremeListed"] * quantity for key, quantity in receive.items())
        expected = {
            "revision": position, "physical_give_slots": len(give), "physical_receive_slots": len(receive),
            "outgoing_listed": outgoing, "incoming_listed": incoming, "listed_delta": incoming - outgoing,
        }
        observed = evidence[position - 1]
        _check(
            _exact_fields(observed, expected.keys()) and all(type(value) is int for value in observed.values())
            and observed == expected,
            "Controlled offer evidence disagrees with the verified Supreme edition.",
        )
    _check(
        events[1]["give"] == events[2]["give"] and events[1]["receive"] != events[2]["receive"],
        "The controlled partner offer revision did not change only the partner side.",
    )
    return document
