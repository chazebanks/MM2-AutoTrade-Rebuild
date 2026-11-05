# Immutable Delta accessibility audit entry

Use the single DELTA_AUDIT_ENTRY.lua after replacing prior Auto Execute code and fully restarting Delta/Roblox. Bootstrap/module source commit: `5422928b0fa538802bd3d13f0a8dc89c77e15a82`. The wrapper starts original V15.8 loader `3daded63893a9165ad6b2a65fcbbf507f1afc571` and retains all original trading dependencies.

This is an audit-only entry. It emits one read-only snapshot per new JobId before the unchanged trader startup. It does not automatically close Delta. Issue32 remains blocked on native accessibility/Exit evidence; see README.md for the exact trace and manual workaround.

No native trial was run in this workspace. Fixture passes do not establish accessible UIKit, a real Exit selector or successful automatic hide. No GUI input/mutation, extra source fetch, polling task, price refresh, native final Accept or Discord completion was added.
