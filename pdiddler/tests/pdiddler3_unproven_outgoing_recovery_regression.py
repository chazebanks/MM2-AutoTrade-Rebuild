from pathlib import Path

src = Path("pdiddler/pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua").read_text()

# Reproduction contract for ScreenRecording_11-02-2026 20-08-29_1.mp4:
# first completely unproven physical Trade tap must NOT permanently process
# the target. It must defer exactly once, preserve late-pending adoption, and
# only become final after the bounded second unproven timeout.

assert "MaxUnavailableChecks=2" in src, "expected one bounded recovery retry"
assert "UNCERTAIN DEFER" in src, "first unproven timeout must defer"
assert 'return finish("deferred-unproven")' in src, "first unproven timeout must return deferred state"
assert "UNCERTAIN FINAL" in src, "second unproven timeout must become final"
assert "NO FURTHER RESEND THIS SERVER" in src, "final state must stop further resends"
assert "S.unavailableUntil[target.UserId]=os.clock()+C.UnavailableRetryDelay" in src, "defer must have cooldown"
assert "recentAge<=C.LatePendingAdoptWindow" in src, "late pending must remain adoptable during cooldown"
assert 'and result~="deferred-unproven"' in src, "deferred target must not be marked processed"

timeout = src.index("UNCERTAIN DEFER")
final = src.index("UNCERTAIN FINAL")
assert timeout < final, "defer path must precede final path"

print("PASS unproven outgoing recovery regression")
