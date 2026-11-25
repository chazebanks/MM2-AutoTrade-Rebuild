"""Test canonical qualification entry and its fail-closed export behavior."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from pdiddler.gingerscope import _parser
from pdiddler.system2.qualification import QualificationError, _child, qualify


ROOT = Path(__file__).resolve().parents[2]


class QualificationCommandTests(unittest.TestCase):
    def command(self, *arguments):
        return subprocess.run(
            [sys.executable, "-m", "pdiddler.gingerscope", "qualify", *arguments],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )

    def test_missing_lune_has_sanitized_startup_failure_and_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / "receipt.json"
            result = self.command("--public-only", "--lune", str(root / "private-location"),
                                  "--copy-to", str(artifact))
            self.assertEqual(result.returncode, 2)
            report = json.loads(result.stdout)
            self.assertEqual(report, json.loads(artifact.read_text()))
            self.assertEqual(report["status"], "FAILED")
            self.assertEqual(report["stages"][0]["reason"], "LUNE_UNAVAILABLE")
            self.assertFalse(report["authoritative_settlement_verified"])
            self.assertNotIn("private-location", result.stdout + result.stderr)

    def test_rejects_invalid_endurance_configuration_before_running_host(self):
        result = self.command("--public-only", "--cycles", "0")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)["stages"][0]["reason"], "CONFIGURATION_INVALID")

    def test_existing_copy_destination_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "receipt.json"
            artifact.write_text("prior")
            result = self.command("--public-only", "--copy-to", str(artifact))
            self.assertEqual(result.returncode, 2)
            self.assertEqual(artifact.read_text(), "prior")
            self.assertEqual(json.loads(result.stdout)["stages"][0]["reason"], "COPY_PATH_UNAVAILABLE")

    def test_unavailable_scratch_storage_has_safe_failure_receipt(self):
        args = _parser().parse_args(["qualify", "--public-only"])
        with patch("pdiddler.system2.qualification.tempfile.TemporaryDirectory",
                   side_effect=OSError("private path")):
            report, status = qualify(args)
        self.assertEqual(status, 2)
        self.assertEqual(report["stages"][0]["reason"], "SCRATCH_UNAVAILABLE")
        self.assertNotIn("private path", str(report))

    def test_excessive_child_output_is_rejected_before_reading_the_rest(self):
        with self.assertRaisesRegex(QualificationError, "DEPENDENCY_OUTPUT_LIMIT"):
            _child([sys.executable, "-c", "print('X' * 1000000)"])


if __name__ == "__main__":
    unittest.main()
