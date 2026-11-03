"""Structured Supreme parsing, canonical identity and fixed freshness regressions."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("refresh_supreme_snapshot", ROOT / "pdiddler/refresh_supreme_snapshot.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


def row(name="Alice", value="1,250", demand="5", stability="Stable", attr_value="1250"):
    return (f'<div class="itemcolumn" data-value="{attr_value}" data-demand="{demand}" data-stability="{stability}">'
            f'<button data-name="{name}"></button><div class="itemhead">{name}</div><div class="itembody">'
            f'Value - <b class="itemvalue">{value}</b><br>Stability - <b class="itemstability">{stability}</b><br>'
            f'Demand - <b>{demand}</b><sep/>Rarity - <b>3</b></div></div>')


def page(rows):
    return '<div data-updated-iso="2026-11-02T12:34:27-05:00"></div>' + rows


class ParserTests(unittest.TestCase):
    def test_numeric_display_and_metadata_are_checked(self):
        rows, published = R.parse_page(page(row()), "ancient")
        self.assertEqual(rows[0]["name"], "Alice")
        self.assertEqual(rows[0]["supremeValue"], 1250)
        self.assertEqual(rows[0]["demand"], 5)
        self.assertEqual(rows[0]["stability"], "Stable")
        self.assertEqual(published, "2026-11-02T17:34:27Z")

    def test_value_metadata_disagreement_fails(self):
        with self.assertRaisesRegex(ValueError, "value"):
            R.parse_page(page(row(attr_value="500")), "ancient")

    def test_displayed_demand_and_stability_cannot_disagree(self):
        for text in (row().replace('data-demand="5"', 'data-demand="4"'),
                     row().replace('data-stability="Stable"', 'data-stability="Fluctuating"')):
            with self.assertRaises(ValueError):
                R.parse_page(page(text), "godly")

    def test_unknown_stability_or_nonfinite_value_fails(self):
        for text in (row(stability="Mystery"), row(value="NaN", attr_value="NaN")):
            with self.assertRaises(ValueError):
                R.parse_page(page(text), "godly")

    def test_priceless_has_metadata_but_no_numeric_price(self):
        text = row("Nik's Scythe", "Priceless", "11", "Overpaid For").replace('data-value="1250"', '')
        rows, _ = R.parse_page(page(text), "ancient")
        self.assertIsNone(rows[0]["supremeValue"])
        self.assertEqual(rows[0]["supremeLabel"], "Priceless")
        self.assertEqual(rows[0]["demand"], 11)

    def test_chroma_abbreviation_needs_exact_full_source_name(self):
        text = row("Chroma Traveler&#039;s Gun").replace(
            '<div class="itemhead">Chroma Traveler&#039;s Gun</div>', '<div class="itemhead">C. Traveler&#039;s Gun</div>')
        rows, _ = R.parse_page(page(text), "chroma")
        self.assertEqual(rows[0]["name"], "Chroma Traveler's Gun")

    def test_duplicate_casefolded_source_identity_fails(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            R.parse_page(page(row("Alice") + row("ALICE")), "ancient")

    def test_missing_or_ambiguous_publication_fails(self):
        for text in (row(), page(row()) + '<div data-updated-iso="2026-11-01T12:00:00Z"></div>'):
            with self.assertRaisesRegex(ValueError, "publication"):
                R.parse_page(text, "ancient")

    def test_mapping_keeps_canonical_id_name_and_category(self):
        parsed, _ = R.parse_page(page(row("Battleaxe")), "godly")
        records = R.map_rows([{"page": "godly", "id": "41", "name": "BattleAxe"}], {"godly": parsed})
        self.assertEqual((records[0]["page"], records[0]["id"], records[0]["name"]), ("godly", "41", "BattleAxe"))
        self.assertEqual(records[0]["sourceName"], "Battleaxe")
        with self.assertRaisesRegex(ValueError, "unmapped"):
            R.map_rows([{"page": "ancient", "id": "41", "name": "BattleAxe"}], {"godly": parsed})

    def test_duplicate_mapping_fails(self):
        mapping = [{"page": "godly", "id": "41", "name": "Alice"}] * 2
        with self.assertRaisesRegex(ValueError, "duplicate"):
            R.map_rows(mapping, {})

    def test_expiry_is_anchored_to_oldest_retrieval_and_publication(self):
        sources = {"ancient": {"observedAt": "2026-11-03T20:29:00Z", "publishedAt": "2026-11-02T17:34:27Z"},
                   "godly": {"observedAt": "2026-11-03T20:30:00Z", "publishedAt": "2026-11-01T22:00:00Z"}}
        self.assertEqual(R.expiry(sources), R.epoch("2026-11-04T20:29:00Z"))
        sources["godly"]["publishedAt"] = "2026-10-31T22:00:00Z"
        self.assertEqual(R.expiry(sources), R.epoch("2026-11-03T22:00:00Z"))

    def test_canonical_mapping_file_preserves_exact_strings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "old.lua"
            path.write_text('add("godly","41",35,"BattleAxe",33,nil,1,"Stable")\n')
            self.assertEqual(R.load_mapping(path), [{"page": "godly", "id": "41", "name": "BattleAxe"}])


class SnapshotTests(unittest.TestCase):
    def test_generated_rows_and_lua_consumer_use_fixed_freshness(self):
        snapshot = json.loads((ROOT / "pdiddler/supreme_snapshot_2026_11_03.json").read_text())
        self.assertEqual(len(snapshot["rows"]), 190)
        self.assertEqual(sum(r["supremeValue"] is not None for r in snapshot["rows"]), 189)
        self.assertEqual(snapshot["coverage"], {
            "ancient": 16, "chroma": 46, "godly": 128, "total": 190,
            "finite": 189, "unpriced": 1, "ancientFinite": 15, "chromaFinite": 46, "godlyFinite": 128})
        self.assertEqual(R.epoch(snapshot["expiresAt"]), R.expiry(snapshot["sources"]))
        for page_name, source in snapshot["sources"].items():
            self.assertEqual(source["url"], "https://supremevalues.com/mm2/" + R.PAGES[page_name])
            self.assertRegex(source["sha256"], r"^[0-9a-f]{64}$")
        runtime = next((shutil.which(name) for name in ("lua5.4", "lua5.3", "texlua", "lua") if shutil.which(name)), None)
        self.assertIsNotNone(runtime, "Lua runtime required to verify actual snapshot consumer")
        lua_path = json.dumps(str(ROOT / "pdiddler/pdiddler_supreme_snapshot_2026_11_03.lua"))
        lua = [f"local S=dofile({lua_path})", "assert(S.liveReady and S.coverage().finite==189)"]
        for record in snapshot["rows"]:
            value = str(record["supremeValue"]) if record["supremeValue"] is not None else "nil"
            lua += [f'local r=S.get({json.dumps(record["page"])},{json.dumps(record["id"])})',
                    f'assert(r and r.name=={json.dumps(record["name"])} and r.supremeValue=={value})',
                    f'assert(r.verified and r.demand=={record["demand"]} and r.stability=={json.dumps(record["stability"])})',
                    f'assert(r.provenance.sha256==S.sources[{json.dumps(record["page"])}].sha256)']
        lua += ["assert(S.get('godly','not-a-canonical-id')==nil)",
                "os.time=function() return S.observedAtEpoch end; assert(S.isFresh())",
                "os.time=function() return S.observedAtEpoch-1 end; assert(not S.isFresh())",
                "os.time=function() return S.expiresAtEpoch-1 end; assert(S.isFresh())",
                "os.time=function() return S.expiresAtEpoch end; assert(not S.isFresh())",
                f"local reloaded=dofile({lua_path}); assert(not reloaded.isFresh())",
                "assert(reloaded.expiresAtEpoch==S.expiresAtEpoch)", "print('PASS 190 real Lua records and fixed expiry across reload')"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "snapshot_check.lua"
            path.write_text("\n".join(lua))
            subprocess.run([runtime, str(path)], cwd=ROOT, check=True)


if __name__ == "__main__":
    unittest.main()
