-- V15.8 quote-status regression test ONLY. One server/session, no teleport requeue.
-- Rejoin MM2 first. Do NOT run beside the normal V15.8 loader.
-- Only test change: pinned P4 clears stale displayed profit when offers change.
if game.PlaceId~=142823291 then
    warn("[PDIDDLER QUOTE TEST] Wrong Roblox place; not running")
    return
end
local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/bc32f9da25460a22a2dcf0ac6e487c70d395a3a5/pdiddler/quote_status_test/INTEGRATED_V15_8_QUOTE_STATUS_FENCE.lua"
local source=game:HttpGet(url,true)
local run=assert(loadstring(source,"=PDIDDLER_QUOTE_STATUS_TEST"))
print("[PDIDDLER QUOTE TEST] Starting one-session V15.8 with P4 quote-status fence; final Accept remains disabled")
return run()
