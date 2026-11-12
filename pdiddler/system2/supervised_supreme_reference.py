"""Offline, read-only Supreme trade reference packet. No market data is ingested.

This intentionally has NO HTTP, file writes, Discord, Roblox, offers, or accept.
Items are operator-observed labels, NOT authenticated Roblox raw identifiers.
"""
from __future__ import annotations

import re

SCHEMA = "gingerscope-system2-supervised-reference-v1"
CALCULATOR = "https://supremevalues.com/mm2/calculator"
CATEGORIES = {
    "Ancient": "https://supremevalues.com/mm2/ancients",
    "Godly": "https://supremevalues.com/mm2/godlies",
    "Chroma": "https://supremevalues.com/mm2/chromas",
}
ITEM_FIELDS = {"label", "quantity", "category"}
SIDES = {"ownOffer", "theirOffer"}
MAX_PHYSICAL_SLOTS = 4
MAX_QUANTITY = 1_000_000

# All authority remains FALSE, including after a user has inspected the website.
DENIED = {
    "copiedSupremeMarketData": False,
    "marketSourceUsableForLiveOffer": False,
    "verifiedMarketQuote": False,
    "verifiedGameItemIdentity": False,
    "serverCompletionProven": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False,
}


def _item(item: object, side: str) -> dict:
    if type(item) is not dict or set(item) != ITEM_FIELDS:
        raise ValueError("INVALID_ITEM_SHAPE_OR_MARKET_FIELD")
    label, quantity, category = item["label"], item["quantity"], item["category"]
    if type(label) is not str or not 1 <= len(label) <= 100:
        raise ValueError("INVALID_ITEM_LABEL")
    if label != label.strip() or any(ord(c) < 32 for c in label) or "://" in label:
        raise ValueError("INVALID_ITEM_LABEL")
    if type(quantity) is not int or not 1 <= quantity <= MAX_QUANTITY:
        raise ValueError("INVALID_STACK_QUANTITY")
    if category not in CATEGORIES or type(category) is not str:
        raise ValueError("INVALID_CATEGORY")
    if side == "ownOffer" and re.sub(r"\s+", "", label.casefold()) == "gingerscope":
        raise ValueError("PROTECTED_GINGERSCOPE_OUTBOUND")
    return {"label": label, "quantity": quantity, "category": category}


def make_review_packet(observed: object) -> dict:
    """Make a human lookup aid, not a trading recommendation or Supreme database."""
    if type(observed) is not dict or set(observed) != SIDES:
        raise ValueError("INVALID_REVIEW_FIELDS")
    sides = {}
    for side in ("ownOffer", "theirOffer"):
        items = observed[side]
        if type(items) is not list or len(items) > MAX_PHYSICAL_SLOTS:
            raise ValueError("MORE_THAN_FOUR_PHYSICAL_SLOTS_OR_INVALID_SIDE")
        sides[side] = [_item(item, side) for item in items]
    return {
        "schema": SCHEMA,
        "status": "HUMAN_SUPREME_REVIEW_REQUIRED",
        "source": "FIRST_PARTY_WEBSITE_HUMAN_ONLY",
        "calculatorUrl": CALCULATOR,
        "categoryReferenceUrls": dict(CATEGORIES),
        "observedUnverifiedOffer": sides,
        "physicalSlotCount": {side: len(sides[side]) for side in sides},
        "humanInstructions": [
            "Open Supreme's official calculator yourself. Select each exact item, variant, and stack.",
            "Compare your offered items against their items; inspect ranges, demand, volatility and whether the items are wanted.",
            "Make your own decision inside MM2; do not copy Supreme's value-table fields back into this software.",
            "Any offer revision, new partner, ambiguous variant, or unverified item requires a new review.",
        ],
        "tradeOutcome": "UNKNOWN",
        **DENIED,
    }
