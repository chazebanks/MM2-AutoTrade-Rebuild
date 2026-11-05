"""Stage 18: read-only integration of EXISTING Stage 7 and Stage 5 research
with the unchanged Stage 16/17 Lua evaluator.

This is an offline evidence bridge. It cannot authorize a quote, click, Accept,
infer a player's wishes, or attest that cached inventory was recently scanned.
A source's 'verified' flag is data supplied by the caller, not proof of origin.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from pathlib import Path
import re
import subprocess
from typing import Mapping

from evaluator import AssessmentError, Catalog, evaluate
from growth_planner import plan_growth
from negotiation_research import study_counteroffers

GOAL = "ancient:771:checker-id"
IDENTITY = re.compile(r"^(godly|ancient|chroma):[0-9]{1,8}:checker-id$")
LUA_DIR = Path(__file__).resolve().parents[1] / "new_part4"


@dataclass(frozen=True)
class Candidate:
    give: tuple[tuple[str, int], ...]
    receive: tuple[tuple[str, int], ...]
    stage7_lanes: tuple[str, ...]
    stage5_lanes: tuple[str, ...]
    our_listed_gain: Decimal
    four_copy_delta: Decimal
    gingerscope_gap_after: Decimal | None
    warnings: tuple[str, ...]


@dataclass(frozen=True)
class OfflineBridge:
    candidates: tuple[Candidate, ...]
    lua_context: dict
    lua_candidates: tuple[dict, ...]
    market_source: str
    source_valid_until: datetime
    original_own: Mapping[str, int]
    original_opponent: Mapping[str, int]
    quote_safe: bool = False
    native_ready: bool = False
    authorizes_trade: bool = False
    authorizes_accept: bool = False
    scan_age_proven: bool = False


def _cents(amount: Decimal) -> int:
    cents = amount * Decimal(100)
    if not cents.is_finite() or cents != cents.to_integral_value():
        raise AssessmentError("stage18-value-precision-unverified")
    n = int(cents)
    if n < 1 or n > 1_000_000_000:
        raise AssessmentError("stage18-value-outside-stage16-contract")
    return n


def _epoch(timestamp: datetime) -> int:
    if timestamp.tzinfo is None or timestamp.utcoffset() is None:
        raise AssessmentError("stage18-unzoned-time")
    raw = timestamp.timestamp()
    if not raw.is_integer() or raw < 1 or raw > 9_999_999_999:
        raise AssessmentError("stage18-time-not-exact-epoch")
    return int(raw)


def _validate_stock(stock: Mapping[str, int], catalogue: Catalog) -> dict[str, int]:
    if not isinstance(stock, Mapping) or not stock:
        raise AssessmentError("stage18-inventory-missing")
    out = {}
    for key, qty in stock.items():
        if not isinstance(key, str) or not IDENTITY.fullmatch(key):
            raise AssessmentError("stage18-noncanonical-identity")
        if type(qty) is not int or not 1 <= qty <= 1_000_000:
            raise AssessmentError("stage18-quantity-invalid")
        item = catalogue.items.get(key)
        if item is None or not item.verified or not item.tradable:
            raise AssessmentError("stage18-unverified-inventory-identity")
        _cents(item.value)
        out[key] = qty
    return out


def _rows(rows: tuple[tuple[str, int], ...]) -> list[dict]:
    if not 1 <= len(rows) <= 4 or sum(q for _, q in rows) > 4:
        raise AssessmentError("stage18-conservative-four-copy-contract")
    return [{"id": k, "qty": q} for k, q in rows]


def integrate(
    own: Mapping[str, int], opponent: Mapping[str, int],
    target: Mapping[str, int], catalogue: Catalog, now: datetime,
    *, goal_id: str = GOAL, limit_per_lane: int = 10,
    search_budget: int = 50_000,
) -> OfflineBridge:
    """Wire Stage 7, Stage 5 and the Stage 16/17 input schema.

    No live authority. Stage 7's coverage/concession defaults are preserved
    as *research filters*, not approved trading rules. A candidate omitted
    from a bounded Stage 5 shortlist is not asserted to be a bad trade.
    """
    catalogue.validate(now)
    if not isinstance(catalogue.source, str) or not catalogue.source.strip():
        raise AssessmentError("stage18-source-id-missing")
    if type(limit_per_lane) is not int or not 1 <= limit_per_lane <= 32:
        raise AssessmentError("stage18-review-budget-invalid")
    own_fixed = _validate_stock(own, catalogue)
    opp_fixed = _validate_stock(opponent, catalogue)
    target_fixed = _validate_stock(target, catalogue)
    if any(opp_fixed.get(k, 0) < qty for k, qty in target_fixed.items()):
        raise AssessmentError("stage18-target-not-owned-by-opponent")
    if goal_id not in catalogue.items or not catalogue.items[goal_id].verified:
        raise AssessmentError("stage18-goal-unverified")
    _cents(catalogue.items[goal_id].value)
    now_epoch, start, expiry = (_epoch(now), _epoch(catalogue.observed_at),
                                _epoch(catalogue.valid_until))
    if now_epoch < start or now_epoch >= expiry:
        raise AssessmentError("stage18-source-expired")

    # Stage 7 enumerates seller-conscious packages; Stage 5 independently
    # reviews portfolio progression. Neither has any live trade authority.
    seller = study_counteroffers(
        own_fixed, opp_fixed, target_fixed, catalogue, now,
        goal_id=goal_id, limit=limit_per_lane,
        search_budget=search_budget)
    growth = plan_growth(
        own_fixed, opp_fixed, catalogue, now, goals=[target_fixed],
        goal_id=goal_id, limit=limit_per_lane,
        quote_limit_each=limit_per_lane,
        search_budget_each=search_budget)

    lanes7 = (
        ("value_matched", seller.value_matched),
        ("bounded_concessions", seller.bounded_concessions),
        ("four_copy_growth", seller.four_copy_growth),
        ("accumulating", seller.accumulating),
    )
    lanes5 = (
        ("wealth", growth.wealth_candidates),
        ("four_copy", growth.four_copy_candidates),
        ("quality", growth.quality_candidates),
        ("caution", growth.caution_candidates),
    )
    selected: dict[tuple, set[str]] = {}
    for label, quotes in lanes7:
        for quote in quotes:
            key = (quote.give, quote.receive)
            selected.setdefault(key, set()).add(label)

    growth_lanes: dict[tuple, set[str]] = {}
    for label, quotes in lanes5:
        for quote in quotes:
            key = (quote.give, quote.receive)
            growth_lanes.setdefault(key, set()).add(label)

    if len(selected) > 128:
        raise AssessmentError("stage18-stage17-candidate-cap-exceeded")

    out = []
    lua_candidates = []
    for key in sorted(selected):
        give, receive = key
        our = evaluate(own_fixed, opp_fixed, dict(give), dict(receive),
                       catalogue, now, goal_identity=goal_id)
        warnings = list(our.warnings)
        if key not in growth_lanes:
            warnings.append("not-in-bounded-stage5-shortlist")
        if our.net_listed_value < 0:
            warnings.append("experimental-nominal-loss-not-approved")
        out.append(Candidate(
            give, receive, tuple(sorted(selected[key])),
            tuple(sorted(growth_lanes.get(key, ()))),
            our.net_listed_value, our.four_copy_delta,
            our.goal_four_copy_gap_after, tuple(warnings),
        ))
        lua_candidates.append({"give": _rows(give), "receive": _rows(receive)})

    # Stage 16/17's own source/identity/value/quantity guards run again in Lua.
    used = sorted({r["id"] for proposal in lua_candidates
                   for side in ("give", "receive") for r in proposal[side]})
    market_items = {}
    for key in used:
        item = catalogue.items[key]
        if item.stability not in {
            "stable", "rising", "overpaid", "doing_well", "improving",
            "fluctuating", "receding", "underpaid", "decreasing", "unsafe"
        }:
            raise AssessmentError("stage18-unsupported-stage16-stability")
        market_items[key] = {
            "valueCents": _cents(item.value),
            "demand": item.demand,
            "stability": item.stability,
            "tradable": True, "verified": True,
            # Stage 1 has NO verified price ranges or flippability. Missing
            # values remain absent; neither is invented from base prices.
        }
    lua_context = {
        "now": now_epoch,
        "market": {
            "sourceId": catalogue.source, "verified": True,
            "observedAt": start, "validUntil": expiry, "items": market_items,
        },
        "ownInventory": own_fixed, "opponentInventory": opp_fixed,
    }
    return OfflineBridge(
        candidates=tuple(out), lua_context=lua_context,
        lua_candidates=tuple(lua_candidates), market_source=catalogue.source,
        source_valid_until=catalogue.valid_until,
        original_own=dict(own_fixed), original_opponent=dict(opp_fixed))


def _lua_literal(value: object) -> str:
    """Constrained data literal: no executable source enters from records."""
    if value is None:
        return "nil"
    if type(value) is bool:
        return "true" if value else "false"
    if type(value) is int:
        return str(value)
    if type(value) is str:
        # Encode UTF-8 bytes as Lua decimal escapes, avoiding interpolation,
        # line breaks, locale and Lua/JSON escape mismatches.
        return '"' + "".join(f"\\{b:03d}" for b in value.encode("utf-8")) + '"'
    if type(value) in (list, tuple):
        return "{" + ",".join(_lua_literal(x) for x in value) + "}"
    if type(value) is dict:
        return "{" + ",".join(
            "[" + _lua_literal(k) + "]=" + _lua_literal(value[k])
            for k in sorted(value)
        ) + "}"
    raise AssessmentError("stage18-lua-serializer-type-rejected")


def review_in_lua(
    bridge: OfflineBridge, *, lua_executable: str = "lua5.4"
) -> tuple[dict, ...]:
    """Run ACTUAL Stage 17 Lua module in an offline subprocess (for CI/replay).

    No Roblox APIs, game network, user accounts or live authority. Not called
    automatically from inside Roblox, and does not ship a native trader.
    """
    if not bridge.candidates:
        return ()
    if len(bridge.candidates) != len(bridge.lua_candidates):
        raise AssessmentError("stage18-candidate-payload-mismatch")
    script = (
        "package.path='?.lua;'..package.path\n"
        "local D=require('p4_dual_perspective')\n"
        "local ctx=" + _lua_literal(bridge.lua_context) + "\n"
        "local rows=" + _lua_literal(bridge.lua_candidates) + "\n"
        "local out,err=D.reviewCandidates(ctx,rows,128)\n"
        "assert(out and not err and out.authorizesTrade==false)\n"
        "for i,r in ipairs(rows) do\n"
        "  local x=D.assess(ctx,r)\n"
        "  assert(x.reviewOnly and not x.quoteSafe and not x.nativeReady "
        "and not x.authorizesAccept and not x.authorizesTrade)\n"
        "  print(i..'\\t'..x.case..'\\t'.."
        "tostring(x.ourGainCents or 'NA')..'\\t'.."
        "tostring(x.sellerSurplusCents or 'NA'))\n"
        "end\n"
    )
    finished = subprocess.run(
        [lua_executable, "-"], input=script, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        cwd=str(LUA_DIR), timeout=15, check=False)
    if finished.returncode:
        raise AssessmentError("stage18-lua-review-failed: " +
                              finished.stderr.strip()[:250])
    parsed = []
    for line in finished.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) != 4:
            raise AssessmentError("stage18-lua-output-invalid")
        i, lane, gain, seller = fields
        if not i.isdigit() or lane not in {
            "VALUE_CASE", "QUALITY_TRADEOFF", "UNPROVEN_SELLER_CASE", "BLOCKED"
        }:
            raise AssessmentError("stage18-lua-output-invalid")
        parsed.append({
            "index": int(i) - 1,
            "sellerCase": lane,
            "ourGainCents": None if gain == "NA" else int(gain),
            "sellerSurplusCents": None if seller == "NA" else int(seller),
            "reviewOnly": True, "authorizesTrade": False,
            "authorizesAccept": False,
        })
    if len(parsed) != len(bridge.candidates) or [x["index"] for x in parsed] != list(range(len(parsed))):
        raise AssessmentError("stage18-lua-output-size-or-order-invalid")
    return tuple(parsed)
