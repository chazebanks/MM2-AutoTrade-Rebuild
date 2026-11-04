from pathlib import Path
import json
r=Path(__file__).resolve().parents[2]/'pdiddler'
old=(r/'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_OPPONENT_ADDED.lua').read_text()
new=(r/'pdiddler_FASTGATE_V6_INTEGRATED_TEST_v15_1_CURRENT_PRICES.lua').read_text()
new=new.replace('V15_1_CURRENT_PRICES','V15_OPPONENT_ADDED')
new=new.replace(',"PDIDDLER_INTEGRATION_V15_OPPONENT_ADDED"}', '}')
new=new.replace('profile={"snapshots/pdiddler_supreme_snapshot_2026_11_04.lua","11537dfd47f8df72aec7aeba9ecaffdfc5c879d4"}',
 'profile={"pdiddler_supreme_snapshot_2026_11_03_ISSUE4.lua","7ecd5b44b30f513a16061f0cb92476cb8cd2e6fa"}')
assert old==new,'unexpected trading logic change'
before=json.loads((r/'supreme_snapshot_2026_11_03_ISSUE4.json').read_text())
after=json.loads((r/'snapshots/supreme_snapshot_2026_11_04.json').read_text())
assert [(x['page'],x['id'],x['name']) for x in before['rows']]==[(x['page'],x['id'],x['name']) for x in after['rows']]
assert len(json.loads((r/'snapshots/supreme_unmapped_2026_11_04.json').read_text()))==9
assert before['expiresAt']=='2026-11-04T21:42:28Z'
assert after['publishedAt']=='2026-11-04T17:27:12Z'
assert after['expiresAt']=='2026-11-05T21:55:32Z'
print('PASS price-only loader delta, unchanged canonical mapping, nine excluded rows and fixed source timestamps')
