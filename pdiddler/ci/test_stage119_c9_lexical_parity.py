"""Stage119 C9 research fork must be a minimal, separately reviewed
delta over the immutable original Stage119. Does not change frozen runner.
"""
from __future__ import annotations

import difflib
import hashlib
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = ROOT / "pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua"
FORK = ROOT / "pdiddler/supervised/STAGE119_C9_READONLY_RESEARCH_NATIVE.lua"
ADAPTER = ROOT / "pdiddler/system2/native_c9_original_p3_protected_host_adapter.lua"


def blob(path: Path) -> str:
    content = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(content)).encode() + b"\0" + content
    ).hexdigest()


class Stage119C9OriginalResearchParity(unittest.TestCase):
    def test_immutable_original_exact_blob(self):
        self.assertEqual(
            blob(ORIGINAL),
            "fc25514564e78d390b089742eb4e7da7508c12fa",
        )
        self.assertEqual(
            blob(ADAPTER),
            "11f8e4794bed009fb8cf910750e6d3d72a4ba805",
        )

    def test_exact_surgical_categories(self):
        original = ORIGINAL.read_text().splitlines(keepends=True)
        fork = FORK.read_text().splitlines(keepends=True)
        diff = list(difflib.SequenceMatcher(
            None, original, fork, autojunk=False
        ).get_opcodes())
        mutated = [
            ("".join(original[i:j]), "".join(fork[k:l]))
            for tag, i, j, k, l in diff if tag != "equal"
        ]
        self.assertEqual(len(mutated), 12, [
            (a[:100], b[:100]) for a, b in mutated
        ])
        changes = []
        for before, after in mutated:
            if ("-- Stage119 V2 ORIGINAL MM2" in before
                    and "-- C9 RESEARCH VARIANT" in after):
                changes.append("header")
            elif (before.strip() == ""
                  and after.strip() == "or cfg.c9ResearchOnly~=true"):
                changes.append("explicit_research_flag")
            elif ("local c9HostModule=loadFrozen" in after
                  and before.strip() == ""):
                changes.append("pinned_host_source")
            elif ("stage118.new" in before
                  and "c9HostModule.new" in after):
                changes.append("source_module_contract")
            elif ("local c9HostHandle=nil" in after
                  and before.strip() == ""):
                changes.append("private_lexical_handle")
            elif ('if identityPhase=="RESULT" or identityPhase=="FAILED"' in before
                  and 'if cfg.c9ResearchOnly==true' in after
                  and "NO weapon add/remove" in after):
                changes.append("c9_screen_no_gift_lane")
            elif (before.strip() == ""
                  and "local function c9BindObservedProtected" in after
                  and "supervisor.currentBoundReadOnly" in after):
                changes.append("original_p3_p4_observer_without_gift")
            elif ("local okIdentity=pcall(witnessTick,r)" in before
                  and "pcall(c9BindObservedProtected,r)" in after
                  and "else" in after):
                changes.append("skip_old_lastoffer_witness_in_c9")
            elif ('identityPhase="WAIT_EMPTY"' in before
                  and 'identityPhase=cfg.c9ResearchOnly and' in after):
                changes.append("c9_manual_arm_phase")
            elif (before.strip() == ""
                  and after.strip() == "c9HostHandle=nil"):
                changes.append("terminal_handle_drop")
            elif (before.strip() == ""
                  and "local function c9ReadOnlyLeaseStatus()" in after):
                changes.append("sanitized_readonly_function")
            elif (before.strip() == ""
                  and after.strip() == "c9ReadOnlyLeaseStatus=c9ReadOnlyLeaseStatus,"):
                changes.append("sanitized_readonly_entry")
            else:
                self.fail(
                    "Unreviewed original Stage119 production change: "
                    + repr((before[:220], after[:220]))
                )
        self.assertEqual(set(changes), {
            "header", "explicit_research_flag", "pinned_host_source",
            "source_module_contract", "private_lexical_handle",
            "terminal_handle_drop", "sanitized_readonly_function",
            "sanitized_readonly_entry", "c9_screen_no_gift_lane",
            "original_p3_p4_observer_without_gift",
            "skip_old_lastoffer_witness_in_c9", "c9_manual_arm_phase",
        })

    def test_no_new_trade_or_network_side_effects(self):
        original = ORIGINAL.read_text()
        fork = FORK.read_text()
        extra = "".join(line for line in
            difflib.ndiff(original.splitlines(True), fork.splitlines(True))
            if line.startswith("+ ")
        )
        for token in (
            ":FireServer(", ":InvokeServer(", ":PostAsync(",
            ":Teleport(", ":SendAsync(", "supervisor.arm({",
            "outgoing.arm(", "OfferItem:FireServer(",
            "AcceptTrade:FireServer(", "loadstring(",
            "getgenv()[", "request({", "setclipboard(",
        ):
            self.assertNotIn(token, extra, token)
        self.assertIn("cfg.c9ResearchOnly~=true", fork)
        self.assertIn(
            'loadFrozen("cc445e5afce631e0545cd7e0ef79b2dc63651b20",',
            fork,
        )
        self.assertIn(
            '"system2/native_c9_original_p3_protected_host_adapter.lua"',
            fork,
        )
        self.assertIn("c9ReadOnlyLeaseStatus=c9ReadOnlyLeaseStatus", fork)
        self.assertNotIn("c9HostHandle.scope", fork)
        self.assertNotIn("return c9HostHandle", fork)
        for old_commit in (
            "5b8ee35d7f281c23d9c2181abd97a063e59a0660",
            "a599c31c53d25e6799b9d631f45f282b445dcda0",
            "9138751b5a57415939ffa1618ac57811d7c8ec7b",
            "af84b23173620b03e919187b08cd352c101ba4ea",
            "2036ae5bd937620f21d46600f99550a1b233a654",
        ):
            self.assertIn(old_commit, fork)
        self.assertNotIn("native_c9_device_readonly_preflight.lua", fork,
                         "First bound-lease milestone must not pretend a "
                         "market model is verified or device-ready")


if __name__ == "__main__":
    unittest.main()
