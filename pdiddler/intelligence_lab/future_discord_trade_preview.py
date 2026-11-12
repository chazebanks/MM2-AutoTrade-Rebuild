"""Pure non-sending Discord-style PREVIEW for hypothetical Gingerscope trades.

Never accepts webhook credentials, never formats a completed-trade claim, and
never reports realized profit or server settlement. Future notifier can reuse
presentation only after an independently established receipt contract exists.
"""
from __future__ import annotations

import re
from typing import Any

SCHEMA="gingerscope-future-trade-notification-preview-v1"
MAX_COPIES_PER_SIDE=4
SAFE_NAME=re.compile(r"^[A-Za-z0-9 .'_-]{1,70}$")
DANGEROUS_INPUT={"username","userId","trader","webhook","webhookUrl",
                 "webhookToken","discordToken","authToken","serverTransactionId"}


def _base(status,reason):
    return {
        "schema":SCHEMA,"status":status,"reason":reason,
        "maySendWebhook":False,"authorizesTrade":False,"authorizesAccept":False,
        "mayReportProfit":False,"mayRecordCompletedTrade":False,
        "mayUseForStrategyLearning":False,"serverCompletionProven":False,
        "tradeOutcome":"UNKNOWN","embedPreview":None,
    }


def _items(rows):
    if not isinstance(rows,list) or len(rows)>MAX_COPIES_PER_SIDE:
        return None
    items=[]
    for x in rows:
        if not isinstance(x,dict):
            return None
        if set(x)!= {"name","quantity","listedValue","demand","liquidity","stability"}:
            return None
        name=x["name"]
        if not isinstance(name,str) or not SAFE_NAME.fullmatch(name):
            return None
        q=x["quantity"]
        value=x["listedValue"]
        demand=x["demand"]
        liquidity=x["liquidity"]
        stability=x["stability"]
        if (type(q) is not int or not 1<=q<=20 or
            type(value) is not int or not 1<=value<=1_000_000 or
            type(demand) is not int or not 1<=demand<=10 or
            type(liquidity) is not int or not 1<=liquidity<=10 or
            not isinstance(stability,str) or stability not in
               ("Stable","Rising","Declining","Unstable","Overpaid For")):
            return None
        items.append(dict(x))
    return items


def build_preview(payload: object) -> dict[str, Any]:
    if not isinstance(payload,dict):
        return _base("BLOCKED","PAYLOAD_NOT_OBJECT")
    if any(k in payload for k in DANGEROUS_INPUT):
        return _base("BLOCKED","ACTION_OR_ACCOUNT_FIELDS_FORBIDDEN")
    if set(payload)!={"gave","received","startingInventoryListedValue","catalogVersion"}:
        return _base("BLOCKED","UNKNOWN_OR_MISSING_FIELDS")
    a=_items(payload["gave"])
    b=_items(payload["received"])
    if a is None or b is None or not (a or b):
        return _base("BLOCKED","ITEMS_OR_QUANTITIES_MALFORMED")
    if any(sum(row["quantity"] for row in items)>MAX_COPIES_PER_SIDE
           for items in (a,b)):
        return _base("BLOCKED","OFFER_COPY_LIMIT_EXCEEDED")
    start=payload["startingInventoryListedValue"]
    version=payload["catalogVersion"]
    if (type(start) is not int or not 0<=start<=1_000_000_000 or
            not isinstance(version,str) or not 1<=len(version)<=60 or
            not re.fullmatch(r"[A-Za-z0-9_.-]+",version)):
        return _base("BLOCKED","INVENTORY_OR_CATALOG_METADATA_INVALID")
    out=sum(row["listedValue"]*row["quantity"] for row in a)
    received=sum(row["listedValue"]*row["quantity"] for row in b)
    after=start-out+received
    if after<0 or after>1_000_000_000:
        return _base("BLOCKED","PROJECTED_INVENTORY_TOTAL_OUT_OF_BOUNDS")
    def describe(items):
        if not items:
            return "None (hypothetical gift)"
        return "\n".join(
            f'{r["quantity"]}x {r["name"]} — {r["listedValue"]} pts each | '
            f'Demand {r["demand"]}/10 | Liquidity {r["liquidity"]}/10 | '
            f'{r["stability"]}' for r in items
        )
    # Item caps are four but string output still must fit Discord constraints.
    left,right=describe(a),describe(b)
    if len(left)>1024 or len(right)>1024:
        return _base("BLOCKED","DISCORD_EMBED_FIELD_TOO_LONG")
    fields=[
        {"name":"You give — listed research only","value":left,"inline":False},
        {"name":"You receive — listed research only","value":right,"inline":False},
        {"name":"Hypothetical listed values",
         "value":f"Given: {out} pts | Received: {received} pts | "
                 f"Projected listed difference: {received-out:+d} pts (NOT realized profit)",
         "inline":False},
        {"name":"Hypothetical inventory value",
         "value":f"Before: {start} pts | After if recorded: {after} pts "
                 "(NOT a verified inventory readback)","inline":False},
    ]
    assert len(fields)<=25 and all(len(x["name"])<=256 and len(x["value"])<=1024
                                      for x in fields)
    preview={"title":"MM2 hypothetical trade preview — NOT VERIFIED",
             "description":f"Research-only layout using catalog {version}. "
                           "No completed transaction, server result or permission to post.",
             "fields":fields}
    result=_base("PREVIEW_ONLY","UNVERIFIED_SYNTHETIC_LAYOUT_NEVER_SEND")
    result["embedPreview"]=preview
    return result
