"""Regression: verify the complete supervised P3 fork differs from
the original 1,782-line request queue ONLY by the explicit start barrier.
This is an exact reverse-diff audit, not a source-text keyword test."""
from pathlib import Path
import subprocess

original=Path("pdiddler/pdiddler3_outgoing_PART4_BRIDGE_v5.lua")
fork=Path("pdiddler/supervised/pdiddler3_outgoing_START_GATED_v1.lua")
original_blob=subprocess.check_output(["git","hash-object",str(original)],text=True).strip()
assert original_blob=="a13596ecae607c323b1fc93f34072b3e959c3f84",original_blob
src=original.read_text()
out=fork.read_text()
prefix=(
"-- SUPERVISED P3 START-BARRIER FORK. Original real P3 outgoing behavior\n"
"-- retained except explicit start-gate protection. This file must be loaded\n"
"-- through the new guarded runtime; never invoke old v5 directly.\n"
"-- No automatic final item-trade Accept is introduced.\n"
"-- Original pinned main Git blob: a13596ecae607c323b1fc93f34072b3e959c3f84\n"
)
assert out.startswith(prefix),"fork must carry exact provenance header"
out=out[len(prefix):]
changes=[
(
"""function M.run(scanner,options)
    -- Do not start the legacy request loop without a separate explicit
    -- authorization + a LIVE supervisor-ready predicate.
    if type(options)~="table"
        or options.requiresExplicitStart~=true
        or type(options.readyCheck)~="function" then
        error("[PDIDDLER P3 OUT] supervised start barrier required")
    end
""",
"""function M.run(scanner)
"""
),
(
"""        incomingDeclined=0,
        startGateOpen=false,
        joinedAt={},""",
"""        incomingDeclined=0,
        joinedAt={},"""
),
(
"""        while alive() do
            -- Even incoming-request Decline is an action. Before the real
            -- coordinator is installed, do not run ANY original P3 loop
            -- branch that might tap, send, cancel, hop or decline.
            if S.startGateOpen~=true then
                task.wait(0.10)
                continue
            end
            if S.paused then""",
"""        while alive() do
            if S.paused then"""
),
(
"""    return {
        session=SESSION,
        state=S,
        isArmed=function()
            return alive() and S.startGateOpen==true
        end,
        arm=function()
            if not alive() then return false,"stale-session" end
            if S.startGateOpen then return false,"already-armed" end
            local ok,ready=pcall(options.readyCheck)
            if not ok or ready~=true then
                return false,"supervisor-not-ready"
            end
            S.startGateOpen=true
            return true,"P3_QUEUE_ARMED_NO_FINAL_ACCEPT"
        end,
        isPaused=function()""",
"""    return {
        session=SESSION,
        state=S,
        isPaused=function()"""
)
]
for i,(injected,original_chunk) in enumerate(changes):
    assert out.count(injected)==1, f"fork barrier change {i} absent or duplicated"
    out=out.replace(injected,original_chunk,1)
assert out==src,"P3 fork changed original request/decline/queue code outside reviewed start-barrier additions"
for forbidden in ('AcceptTrade:FireServer(', 'OfferItem:FireServer(', 'PostAsync('):
    assert forbidden not in fork.read_text(),forbidden
print("[PASS] full original P3 source reverse-diff matches, four reviewed start-gate changes only")
