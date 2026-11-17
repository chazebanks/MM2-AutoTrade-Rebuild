"""Adversarial source registry tests; NO Roblox/Delta call, source stays stale."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta
from pathlib import Path
import json
import re
import subprocess
import sys
import unittest

from pdiddler.ci import supreme_c9_pin_audit as audit

class SupremeC9Pins(unittest.TestCase):
    def setUp(self):
        self.m=audit.load_manifest()
        self.host=audit.checked_bytes(audit.HOST_PATH).decode()
        self.start=audit.checked_bytes(audit.START_PATH).decode()

    def reject(self,m=None,files=None,expected=None):
        with self.assertRaises(audit.PinAuditError) as err:
            audit.verify(m or self.m,files=files)
        if expected:
            self.assertIn(expected,str(err.exception))

    def test_canonical_registry_is_structurally_sound_but_not_deployed(self):
        result=audit.verify(self.m)
        self.assertEqual(result["status"],"PIN_REGISTRY_STRUCTURAL_PASS")
        self.assertEqual(result["directModules"],14)
        self.assertEqual(result["dynamicRoles"],8)
        self.assertEqual(result["uniqueDynamicFiles"],7)
        self.assertEqual(result["source"],"SUPREME_ONLY")
        self.assertFalse(result["mayTrade"])
        self.assertFalse(result["deviceTestVerified"])
        self.assertEqual(result["marketSnapshotExpiresUtc"],"2026-11-17T20:06:51Z")
        self.assertEqual(self.m["policy"]["neverOutgoing"],"Gingerscope")

    def test_full_pin_used_for_historical_original_bridge_not_39_prefix(self):
        full="2f556afac5e5fd9cfdbf9e081eeea01a542d293d"
        short=full[:-1]
        self.assertEqual(len(full),40)
        self.assertEqual(len(short),39)
        self.assertIn('local bridge=loadFrozen("'+full+'"',self.host)
        self.assertNotIn('local bridge=loadFrozen("'+short+'",',self.host)
        self.assertEqual(
            self.m["directFrozenModules"][3],
            {"symbol":"bridge","commit":full,
             "path":"pdiddler/supervised/supervised_p3_p4_handoff.lua"}
        )
        m=deepcopy(self.m)
        m["directFrozenModules"][3]["commit"]=short
        self.reject(m,expected="DIRECT_MODULE_COMMIT_ABBREVIATED_OR_INVALID")
        spoof=self.host.replace(full,short,1)
        self.reject(files={audit.HOST_PATH:spoof},
                    expected="RUNTIME_DIRECT_COMMIT_ABBREVIATED_OR_INVALID")

    def test_launcher_cannot_silently_fetch_another_host_commit(self):
        old=self.m["protectedHost"]["revision"]
        new="f"*40 if old!="f"*40 else "0"*40
        m=deepcopy(self.m)
        m["protectedHost"]["revision"]=new
        self.reject(m,expected="LAUNCHER_HOST_SOURCE_PIN_MISMATCH")
        spoof=self.start.replace(old,new,1)
        self.reject(files={audit.START_PATH:spoof},
                    expected="LAUNCHER_HOST_SOURCE_PIN_MISMATCH")

    def test_file_content_blob_drift_detected_before_permission_claim(self):
        m=deepcopy(self.m)
        m["protectedHost"]["blob"]="f"*40
        self.reject(m,expected="HOST_LOCAL_SOURCE_BLOB_DRIFT")
        m=deepcopy(self.m)
        m["launcher"]["blob"]="0"*40
        self.reject(m,expected="LOADER_LOCAL_SOURCE_BLOB_DRIFT")
        m=deepcopy(self.m)
        key="pdiddler/system2/native_supreme_five_scenario_gui_presentation.lua"
        m["immutableBlobs"][key]="f"*40
        self.reject(m,expected="IMMUTABLE_BLOB_DRIFT:")

    def test_every_single_static_dependency_must_be_exact_consented_commit(self):
        self.assertEqual(len(self.m["directFrozenModules"]),14)
        for i in range(14):
            m=deepcopy(self.m)
            m["directFrozenModules"][i]["commit"]="e"*40
            self.reject(m,expected="RUNTIME_DIRECT_SOURCE_PIN_MISMATCH")
        m=deepcopy(self.m)
        m["directFrozenModules"][0]["symbol"]="bridge"
        self.reject(m,expected="DUPLICATE_MANIFEST_MODULE_SYMBOL")
        m=deepcopy(self.m)
        m["directFrozenModules"].pop()
        self.reject(m,expected="DIRECT_FROZEN_DEPENDENCY_COUNT_DRIFT")

    def test_runtime_dynamic_groups_cannot_mix_source_publishers(self):
        m=deepcopy(self.m)
        m["dynamicFrozenGroups"][0]["commit"]="f"*40
        self.reject(m,expected="DYNAMIC_RUNTIME_PIN_MISMATCH")
        m=deepcopy(self.m)
        m["dynamicFrozenGroups"][1]["commit"]="f"*40
        self.reject(m,expected="DYNAMIC_RUNTIME_PIN_MISMATCH")
        m=deepcopy(self.m)
        m["dynamicFrozenGroups"][0]["files"][1]["path"]="pdiddler/system2/fake_publisher.lua"
        self.reject(m,expected="DYNAMIC_SUPREME_ROLE_REPOINTED")
        m=deepcopy(self.m)
        m["policy"]["source"]="MM2VALUES"
        self.reject(m,expected="STRATEGY_PERMISSION_OR_PUBLISHER_DRIFT")

    def test_no_new_fallback_to_mutable_branches_or_auto_trade(self):
        self.reject(files={audit.HOST_PATH:self.host.replace(
            'local bridge=loadFrozen("','local unknown=loadFrozen("main","pwned.lua")\n'
            'local bridge=loadFrozen("',1)},
            expected="DIRECT_FROZEN_DEPENDENCY_COUNT_DRIFT")
        self.reject(files={audit.HOST_PATH:self.host+"\nOfferItem:FireServer(1)\n"},
                    expected="AUTOMATED_TRADE_CONTROL_INTRODUCED")
        self.reject(files={audit.START_PATH:self.start+"\nMM2VALUES\n"},
                    expected="SECOND_PUBLISHER_IMPORTED")
        m=deepcopy(self.m)
        m["policy"]["finalAccept"]=True
        self.reject(m,expected="STRATEGY_PERMISSION_OR_PUBLISHER_DRIFT")
        m=deepcopy(self.m)
        m["purpose"]="RUNTIME_FETCH_DYNAMIC_MANIFEST"
        self.reject(m,expected="REGISTRY_MUST_NEVER_BE_RUNTIME_AUTHORITY")

    def test_catalog_source_sha_and_capture_clock_must_not_be_restamped(self):
        m=deepcopy(self.m)
        m["supremeCatalog"]["sha256"]="0"*64
        self.reject(m,expected="SUPREME_CATALOG_CONTENT_SHA256_DRIFT")
        m=deepcopy(self.m)
        m["supremeCatalog"]["capturedUtc"]="2026-11-19T14:06:51Z"
        self.reject(m,expected="CATALOG_SOURCE_OR_PERMISSION_MISMATCH")
        m=deepcopy(self.m)
        m["supremeCatalog"]["absoluteExpiresUtc"]="2026-12-01T20:06:51Z"
        self.reject(m,expected="SUPREME_SOURCE_CAPTURE_EXPIRY_INVALID")
        m=deepcopy(self.m)
        m["supremeCatalog"]["eligibleCounts"]["chroma"]=45
        self.reject(m,expected="SUPREME_SOURCE_METADATA_OR_AUTHORITY_DRIFT")
        fake_start=self.start.replace("local captureUtc=1794924411",
                         "local captureUtc=1794924412")
        self.reject(files={audit.START_PATH:fake_start},
                    expected="LAUNCHER_CLOCK_NOT_LINKED_TO_CATALOG")

    def test_unsafe_paths_and_implicit_references_blocked(self):
        m=deepcopy(self.m)
        m["directFrozenModules"][0]["path"]="pdiddler/../../private.txt"
        self.reject(m,expected="SOURCE_PATH_INVALID")
        m=deepcopy(self.m)
        m["directFrozenModules"][0]["commit"]="main"
        self.reject(m,expected="DIRECT_MODULE_COMMIT_ABBREVIATED_OR_INVALID")
        m=deepcopy(self.m)
        m["repository"]="attacker/MM2-AutoTrade-Rebuild"
        self.reject(m,expected="WRONG_IMMUTABLE_REPOSITORY")

    def test_registry_audit_does_not_claim_freshness_from_clean_code(self):
        end=datetime.fromisoformat(
            self.m["supremeCatalog"]["absoluteExpiresUtc"].replace("Z","+00:00"))
        captured=datetime.fromisoformat(
            self.m["supremeCatalog"]["capturedUtc"].replace("Z","+00:00"))
        self.assertEqual(end-captured,timedelta(hours=6))
        self.assertNotIn("game:HttpGet",Path(audit.__file__).read_text())
        self.assertNotIn("getgenv()",Path(audit.__file__).read_text())
        self.assertFalse(self.m["supremeCatalog"]["liveTradePricingAuthorized"])
        self.assertFalse(self.m["supremeCatalog"]["rawInstanceIdentityVerified"])

if __name__=="__main__":
    unittest.main()
