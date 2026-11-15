"""Integrity of the separate C9 native research START launcher.

The original frozen Stage119 loader/runner remain untouched. A pinned
source URL is an immutable GitHub revision, not actual iPad attestation.
"""
from __future__ import annotations
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
FORK = ROOT / "pdiddler/supervised/STAGE119_C9_READONLY_RESEARCH_NATIVE.lua"
START = ROOT / "pdiddler/supervised/STAGE119_C9_READONLY_RESEARCH_START.lua"
ORIGINAL = ROOT / "pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua"


def blob(path: Path) -> str:
    data = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(data)).encode() + b"\0" + data
    ).hexdigest()


class C9PinnedConsentStart(unittest.TestCase):
    def test_original_and_reviewed_variant_immutable(self):
        self.assertEqual(blob(ORIGINAL),
            "fc25514564e78d390b089742eb4e7da7508c12fa")
        self.assertEqual(blob(FORK),
            "89b1c1cb813cae20e0c52c2858359a2749267f1f")

    def test_immutable_uri_and_explicit_no_gift_manual_request_plan(self):
        script = START.read_text()
        for text in (
            "d054ae0519b6b9f46a6e2d6a631fcb553168adc7",
            "STAGE119_C9_READONLY_RESEARCH_NATIVE.lua",
            "cfg.c9ResearchOnly~=true",
            "c9ReadOnlyLeaseStatus=c9ReadOnlyLeaseStatus",
            "plan.explicitOperatorWantsC9Research~=true",
            "plan.understandsArmSendsP3TradeRequest~=true",
            "plan.consentVerifiedForNamedAlt~=true",
            "plan.noWeaponAddOrRemoveTests~=true",
            "plan.finalAcceptMustRemainManual~=true",
            "plan.automaticP3ArmForbidden~=true",
            "PDIDDLER_SUPERVISED_P3_NATIVE_OWNER",
            "PDIDDLER_OUTGOING_SESSION",
        ):
            self.assertIn(text,script)
        self.assertNotIn("/main/",script)
        self.assertNotIn("/master/",script)
        self.assertNotIn("STAGE119_P3_BOUND_READONLY_NATIVE.lua",script)
        self.assertEqual(script.count("game:HttpGet("),1)
        self.assertNotIn("venossgaming90190",script,
            "Consenting partner must be explicit, never assume historical ALT")

    def test_no_trade_actions_or_autorun_p3_arm(self):
        text = START.read_text()
        for action in (
            ":FireServer(", ":InvokeServer(", ":Teleport(",
            ":PostAsync(", ":SendAsync(", "OfferItem(",
            "AcceptTrade(", "DeclineTrade(", "supervisor.arm(",
            ".arm(", ".offer(", ".accept(", "setclipboard(",
        ):
            self.assertNotIn(action,text,action)
        self.assertIn("runtime.arm~=nil",text)
        self.assertIn("runtime.accept~=nil",text)
        self.assertIn("E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE=nil",text)


if __name__ == "__main__":
    unittest.main()
