"""Stage31: strictly offline contrast of TWO Stage30 native client signal traces.

The test actor (local/partner) is a human-declared experimental condition;
an OnClientEvent callback does NOT report the actual initiator. Even matching
DeclineTrade receipts cannot establish a server-authoritative decline.

No network, Roblox, trade API, webhook, or execution of a local trade.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping
import math

REQUIRED_SCHEMA = "gingerscope-stage30-client-trade-signal-census-v1"
CLOSE = "CLOSED_UNKNOWN"
MAX_CATALOG = 32
MAX_SAMPLES = 24


@dataclass(frozen=True)
class Contrast:
    status: str
    reason: str
    local_receipts: tuple[str, ...]
    partner_receipts: tuple[str, ...]
    shared_client_signals: tuple[str, ...]
    difference_local_only: tuple[str, ...]
    difference_partner_only: tuple[str, ...]
    declared_actions_not_authenticated: bool = True
    initiator_proven: bool = False
    decline_proven: bool = False
    server_completion_proven: bool = False
    may_record_completed_trade: bool = False
    may_report_profit: bool = False
    authorizes_accept: bool = False
    review_only: bool = True


class InvalidEvidence(ValueError):
    pass


def _native(report: Mapping, label: str) -> tuple[str, ...]:
    if not isinstance(report, Mapping):
        raise InvalidEvidence(f"{label}:not-a-record")
    if report.get("schema") != REQUIRED_SCHEMA:
        raise InvalidEvidence(f"{label}:wrong-native-schema")
    if report.get("status") != "CLOSED_WITH_CLIENT_SIGNAL_CENSUS":
        raise InvalidEvidence(f"{label}:not-complete-census")
    if report.get("closureStatus") != CLOSE or report.get("observerClosureStatus") != "closed_unknown":
        raise InvalidEvidence(f"{label}:closure-not-observed")
    if report.get("probeStopReason") != "CLOSE_AND_SIGNAL_GRACE_FINISHED":
        raise InvalidEvidence(f"{label}:signal-grace-incomplete")
    for key in (
        "serverCompletionProven", "authorizesTrade", "authorizesAccept",
        "mayRecordCompletedTrade", "mayReportProfit", "serverAttestation",
        "observedOurAccept", "observedTheirAccept", "partnerDepartureObserved",
    ):
        if report.get(key) is not False:
            raise InvalidEvidence(f"{label}:unsupported-{key}")
    names=report.get("catalogNames")
    if not isinstance(names, list) or len(names)>MAX_CATALOG or len(set(names)) != len(names):
        raise InvalidEvidence(f"{label}:invalid-catalog")
    if not all(isinstance(n,str) and n.isascii() and 1<=len(n)<=48 and
               all(c.isalnum() or c in "_-" for c in n) for n in names):
        raise InvalidEvidence(f"{label}:unsafe-catalog-name")
    if report.get("catalogRemoteEvents") != len(names):
        raise InvalidEvidence(f"{label}:catalog-count-mismatch")
    signals=report.get("signals")
    if not isinstance(signals,list) or len(signals)>MAX_SAMPLES:
        raise InvalidEvidence(f"{label}:invalid-samples")
    if type(report.get("signalReceipts")) is not int or report["signalReceipts"]<len(signals):
        raise InvalidEvidence(f"{label}:incorrect-receipt-count")
    if report.get("retainedReceipts") != len(signals):
        raise InvalidEvidence(f"{label}:retained-count-mismatch")
    observed=[]
    for x in signals:
        if not isinstance(x,dict) or set(x)!={"name","phase","elapsed"}:
            raise InvalidEvidence(f"{label}:unexpected-raw-payload-or-field")
        if x["name"] not in names or x["phase"] not in ("WHILE_OPEN","AFTER_CLOSE"):
            raise InvalidEvidence(f"{label}:unbound-or-unknown-event")
        t=x["elapsed"]
        if type(t) not in (int,float) or not math.isfinite(t) or t<0 or t>3600:
            raise InvalidEvidence(f"{label}:invalid-clock")
        observed.append(x["name"])
    # Deliberately compare PRESENCE, not event-count or close latency, as these
    # may change between servers and are not actor or outcome evidence.
    return tuple(sorted(set(observed)))


def compare_local_and_partner(local: Mapping, partner: Mapping) -> Contrast:
    """Compare Stage30 *human-labeled* local-close and partner-close trials."""
    first=_native(local,"local")
    second=_native(partner,"partner")
    a=set(first);b=set(second)
    common=tuple(sorted(a & b))
    if "DeclineTrade" in common:
        status="SHARED_DECLINE_NAMED_RECEIPT_NO_ACTOR_PROOF"
        reason="same-client-signal-observed-for-different-declared-initiators"
    else:
        status="INCONCLUSIVE_DIFFERENT_CLIENT_RECEIPTS"
        reason="event-delivery-pattern-does-not-establish-initiator-or-outcome"
    return Contrast(
        status=status,reason=reason,
        local_receipts=first,partner_receipts=second,
        shared_client_signals=common,
        difference_local_only=tuple(sorted(a-b)),
        difference_partner_only=tuple(sorted(b-a)),
    )
