# pdiddler — Part 1: modular boot

Run `pdiddler/loader.lua` in a Luau environment that supports `game:HttpGet` and `loadstring`.

The loader downloads `pdiddler/core/health.lua`, compiles it **separately**, runs a smoke test, and prints PASS or FAIL. No trade requests, inventory operations, webhook calls, or server hopping occur in Part 1.

The loader currently reads the `main` branch; pin to a commit for reproducible releases. GitHub raw URLs for private repositories require authenticated access and will not work as written.

Future parts will be implemented as separate independently loaded modules, not pasted into the same source chunk.
