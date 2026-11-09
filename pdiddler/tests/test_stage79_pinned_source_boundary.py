"""Stage79: prove earlier client report erased original owned key TYPES.

Uses exact Git object bytes for the scanner and Stage66 core, never
pretends those old reports identify a user's private weapon.
"""
import hashlib
import os
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
SCANNER_BLOB="5395de38d88c76d049a51d801f2a01412defb8ee"
STAGE66_BLOB="1579a2a70047783e8579f91540ff03037e13ba59"

def sha(v):
    return hashlib.sha1(b"blob "+str(len(v)).encode()+b"\0"+v).hexdigest()

class Stage79SourceProof(unittest.TestCase):
    def test_pinned_prior_client_type_information_was_lost(self):
        scanner=os.environ.get("STAGE79_PINNED_SCANNER")
        core=os.environ.get("STAGE79_PINNED_STAGE66")
        if not scanner or not core:
            if os.environ.get("STAGE79_REQUIRE_PINNED")=="1":
                self.fail("Stage79 CI requires TWO verified real historical source blobs")
            self.skipTest("pinned older scanner/observer sources not supplied")
        scan=Path(scanner).read_bytes()
        old=Path(core).read_bytes()
        self.assertEqual(sha(scan),SCANNER_BLOB)
        self.assertEqual(sha(old),STAGE66_BLOB)
        s=scan.decode("utf-8")
        o=old.decode("utf-8")
        self.assertIn('local id=tostring(rawId)',s)
        self.assertIn('local meta=Meta["Weapons|"..id]',s)
        self.assertIn('local rf=invFolder and invFolder:FindFirstChild("GetProfileData")',s)
        self.assertIn('return rf:InvokeServer()',s)
        self.assertIn('out.seen[#out.seen+1]=id.."x"..tostring(qty)',s)
        self.assertIn('local function stage66PrivateRawOwned(inv)',o)
        self.assertIn('local raw,number=token:match("^(.*)x(%d+)$")',o)
        self.assertIn('return result,nil',o)
        # The old table keys have already lost their primitive type before
        # Stage66 parses the stringized tokens. No old data is backfilled.
    def test_new_native_is_exactly_one_bounded_own_profile_read(self):
        c=(ROOT/"pdiddler/new_part4/STAGE79_READONLY_OWNED_TYPED_CENSUS.lua").read_text()
        self.assertEqual(c.count('rf:InvokeServer()'),1)
        self.assertIn('local deadline=os.clock()+4.5',c)
        self.assertIn('return done("OWN_READ_TIMED_OUT"',c)
        self.assertNotIn("FireServer(",c)
        self.assertNotIn("GetFullInventory",c)
        self.assertNotIn("AcceptTrade",c)
        self.assertNotIn("OfferItem",c)
        self.assertNotIn("TeleportService",c)
        self.assertNotIn("getconnections(",c)
        self.assertNotIn("hookfunction(",c)
        self.assertIn('profile.Weapons.Owned,sync.Weapons',c)
    def test_aggregate_guard_has_no_market_authority(self):
        c=(ROOT/"pdiddler/intelligence_lab/stage79_typed_owned_census.lua").read_text()
        self.assertIn('rawget(cat,k)',c)
        self.assertNotIn("FireServer(",c)
        self.assertNotIn("InvokeServer(",c)
        self.assertNotIn("GetProfileData",c)
        self.assertIn('authorizesTrade=false',c)
        self.assertIn('mayUseForStrategyLearning=false',c)
        self.assertIn('authenticatedOwnedInventory=false',c)

if __name__=="__main__":
    unittest.main()
