"""Independent Python C6 chat/item-name property checks on real 189-item feed.

Python is an oracle for input edge cases; native Luau Lune suite actually runs
the production passive classifier with simulated TextChatService packets.
"""
from __future__ import annotations

import json
import random
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "system2"
MARKET = ROOT / "research_market_crosswalk_current.json"
CORE = ROOT / "native_partner_intent_observer.lua"
ADAPTER = ROOT / "native_partner_textchat_receiver.lua"

def canonical(s):
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()

def aliases(rows):
    lookup = {}
    for row in rows:
        id_ = row["rawGameKeyCandidate"]
        name = canonical(row["marketName"])
        extra = canonical(row["expectedGameName"])
        if row["gameChroma"] and not extra.startswith("chroma "):
            extra = "chroma " + extra
        for p in (name, extra):
            if p:
                lookup.setdefault(p, set()).add(id_)
    return lookup

def reference_mentions(message, dictionary):
    sentence = " " + canonical(message) + " "
    positions = []
    for label, ids in dictionary.items():
        pos = 0
        while True:
            start = sentence.find(" " + label + " ", pos)
            if start < 0:
                break
            positions.append((start, start + len(label) + 2, -len(label), label, ids))
            pos = start + len(label) + 2
    positions.sort(key=lambda item: (item[0], item[2]))  # longest at same start first
    selected = []
    for a,b,_,label,ids in positions:
        if not any(a <= end and b >= start for start,end,_,_ in selected):
            selected.append((a,b,label,ids))
    return selected


class PartnerEvidenceOracle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.market = json.loads(MARKET.read_text())
        cls.records = cls.market["items"]
        cls.rows = {r["rawGameKeyCandidate"]: r for r in cls.records}
        cls.lookup = aliases(cls.records)
        cls.core = CORE.read_text()
        cls.adapter = ADAPTER.read_text()

    def test_catalog_is_verified_research_only(self):
        self.assertEqual(len(self.rows), 189)
        self.assertEqual(self.market["matchedHistoricalGameKeys"], 189)
        self.assertFalse(self.market["mayUseForLiveOffer"])
        self.assertFalse(self.market["authorizesTrade"])
        self.assertTrue(self.rows["Gingerscope"]["outgoingGingerscopeProtected"])

    def test_current_real_rare_variant_and_base_are_distinct(self):
        self.assertEqual(self.lookup["chroma fang"], {"FangChroma"})
        self.assertEqual(self.lookup["fang"], {"Fang"})
        self.assertEqual(self.rows["FangChroma"]["marketCategory"], "chroma")
        self.assertEqual(self.rows["Fang"]["marketCategory"], "godly")

    def test_longest_alias_wins_and_prefixes_not_substrings(self):
        for item, expected in [
            ("LF Chroma Fang", "FangChroma"),
            ("NLF Fang", "Fang"),
            ("LF Orange Seer", "OrangeSeer"),
            ("LF Flowerwood Gun", "FlowerwoodGun"),
            ("LF Flowerwood Knife", "FlowerwoodKnife"),
        ]:
            got = reference_mentions(item, self.lookup)
            self.assertEqual(len(got), 1, item)
            self.assertEqual(got[0][-1], {expected}, item)

    def test_fuzz_3500_chroma_base_name_cases(self):
        rnd = random.Random(20261114)
        chroma = [r for r in self.records if r["gameChroma"]]
        for _ in range(3500):
            row = rnd.choice(chroma)
            msg = rnd.choice(["LF ", "NLF ", "need "]) + row["marketName"]
            found = reference_mentions(msg, self.lookup)
            self.assertTrue(found, row)
            self.assertEqual(found[-1][-1], {row["rawGameKeyCandidate"]}, msg)

    def test_unrelated_natural_language_substrings_not_weapon_ids(self):
        # "fang" in "fangirl" cannot become an MM2 item mention.
        self.assertEqual(reference_mentions("i am a fangirl", self.lookup), [])
        self.assertEqual(reference_mentions("only my harvesters", self.lookup), [])

    def test_raw_speaker_only_never_prefixtext(self):
        self.assertIn("msg.TextSource.UserId", self.adapter)
        self.assertIn("msg.MessageId", self.adapter)
        self.assertIn('TextChannel={Name=', (ROOT.parent / "ci" / "system2_native_partner_intent_mocks.luau").read_text())
        self.assertNotIn("msg.PrefixText", self.adapter)

    def test_bound_active_session_and_whisper_pair_enforced(self):
        for required in (
            "ORIGINAL_MM2_JOB_CHANGED", "ORIGINAL_MAIN_ACCOUNT_CHANGED",
            "ORIGINAL_BOUND_PARTNER_LEFT", "ORIGINAL_TRADE_LEASE_INACTIVE",
            "mainDisplayNameUnique=equalNames==1",
            'name=="RBXGeneral"', "WHISPER_BETWEEN_BOUND_USERS",
        ):
            self.assertIn(required, self.adapter + self.core)

    def test_context_not_equivalent_to_verified_personal_reply(self):
        for required in (
            'local WINDOW=12', "lastOurOfferRevision==revision",
            "TENTATIVE_IN_CURRENT_TRADE_AFTER_OWN_OFFER",
            "PUBLIC_UNADDRESSED", "personalReplyProven=false",
            "CLIENT_CHAT_ONLY_NO_TRADE_COMMITMENT",
        ):
            self.assertIn(required, self.core)

    def test_full_revision_invalidation_and_dedup(self):
        for required in (
            "local TTL=120", "local MAX_EVENTS=48",
            "ctx.clientOfferRevision<lastRevision", "MESSAGE_ID_ALREADY_SEEN",
            "PARTNER_OFFER_LEASE_OR_SOURCE_CHANGED_MID_MESSAGE",
        ):
            self.assertIn(required, self.core)

    def test_explicit_preferences_have_short_cross_revision_ttl(self):
        code = self.core
        self.assertIn("e.revision<=ctx.clientOfferRevision", code)
        self.assertIn("e.revision==ctx.clientOfferRevision", code)
        self.assertIn("carriedAcrossOfferChange=", code)
        self.assertIn('return nil,nil,nil,"CLIENT_OFFER_REVISION_ROLLBACK"', code)
        self.assertIn('kind="MENTION_ONLY"', code)
        self.assertIn('segment:find(" but not "', code)

    def test_no_autochat_no_remotes_no_external_posting(self):
        for text in (self.adapter, self.core):
            for forbidden in (
                ":SendAsync(", ":FireServer(", ":InvokeServer(", "PostAsync(",
                "HttpGet(", "TeleportService", ":Chat(", "mouse1click(",
            ):
                self.assertNotIn(forbidden, text)
            self.assertIn("authorizesOffer=false", text)
            self.assertIn("authorizesAccept=false", text)

    def test_no_personality_or_probability_conflation(self):
        for required in (
            "estimatedAcceptProbability=nil", "verifiedPartnerPreference=false",
            "verifiedTradeAcceptance=false", "mayUseForStrategyLearning=false",
            "CHAT_REFUSAL_NOT_TRADE_DECLINE",
            "actualWillingnessToTrade=false",
        ):
            self.assertIn(required, self.core)

    def test_compatibility_evaluates_give_not_receive(self):
        core = self.core
        self.assertIn("for _,item in ipairs(o.give)", core)
        self.assertIn("preference[item.id]", core)
        self.assertIn("MATCHES_STATED_ITEM_INTEREST", core)
        self.assertIn("CONFLICTS_STATED_PREFERENCE", core)
        self.assertIn("canProposeLiveOffer=false", core)

    def test_no_raw_chat_export(self):
        self.assertIn("noRawChatRetained=true", self.core)
        self.assertIn("noRawChatExported=true", self.core)
        self.assertNotIn("eventText=p.text", self.core)
        self.assertNotIn("partnerName=", self.core)
        self.assertNotIn("sendEvent", self.adapter)


if __name__ == "__main__":
    unittest.main()
