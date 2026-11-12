# Gingerscope private backend — V1 offline durable foundation

**Status:** Implementation in an isolated DRAFT PR; **not hosted, deployed, or attached to P3/P4 or any real MM2 data**. This is a persistent-state building block for the long-running strategy, not a running cloud service or a working market feed.

## Scope implemented

- `persistent_store.py`: SQLite WAL + FULL synchronous commits, atomic idempotent source-research receipts, client-only inventory snapshots (100+ items and stacked copies), bounded client-only offer/decline/unknown event journal, monotonic trade revision guard, conflict/double-write prevention, atomic cross-process health-job leases, crash recovery. Transactions roll back on error. Database schema versioned. Secret-free status output. No verified settlement/learning/profit can be stored from these client-only inputs.
- `runtime.py`: optional local process with a heartbeat on startup and at most every five minutes, using a one-hour durable `local_health` job lease. `GET /healthz` reports only that process is running, and `GET /v1/status` requires a private bearer token. Read-only HTTP API, fixed paths, POST/PUT/DELETE denied, no query URLs. Binds to **127.0.0.1 only** and does **not** implement TLS; deploy only behind a private TLS/auth reverse proxy or private network (never directly expose `8787` publicly). No provider fetch, no source cache, no Luau/trader connection, and no outgoing webhooks. Server status is a **blocked read-only** contract, never execution authority.

## How to test offline (standard library; no keys)

```sh
python3 -m unittest -v pdiddler.ci.test_persistent_backend
python3 -m pdiddler.backend.runtime init --db /persistent-private-volume/gingerscope.sqlite
python3 -m pdiddler.backend.runtime once --db /persistent-private-volume/gingerscope.sqlite
```

**Private online SQLite backup and recovery drill** (source connection stays live while a consistent snapshot is made):

```sh
python3 -m pdiddler.backend.runtime backup --db /persistent-private-volume/gingerscope.sqlite --to /encrypted-offsite-backups/gingerscope-2026-11-12.sqlite
```

The backup command makes a **new, never-overwritten** file with the SQLite online backup API, validates `PRAGMA integrity_check`, and returns only a safe status string. Offline regression tests reopen backups and check that research market receipts, client-only inventory checkpoints and trade observations survived. To recover after host loss, stop all backend writers and verify a separately preserved backup before restoring to a NEW private database path; **no automatic destructive restore operation is enabled**. Backups on the same disk do not protect against host/disk loss. Production requires an encrypted, separately retained copy, restore drills, retention policy and access controls. Backup contains private inventory observations and must never be committed to public GitHub.

**Production data-loss gate:** `python3 -m pdiddler.backend.runtime worker --db /data/gingerscope.sqlite` refuses to start unless **`/data` is actually a mounted filesystem**. A bare directory in a deploy image is not persistence. The guard also rejects paths escaping `/data` through symlinks. GitHub CI runs a Docker regression confirming the worker fails on an unmounted `/data`, plus a separate read-only tmpfs-mounted smoke test. This checks the production path contract, not Railway's real volume until a user-approved deployment.

The examples require an existing writable directory that survives process restarts and provider reboots. **GitHub Actions storage is ephemeral and must not be treated as the production persistent disk.** Never put private `.sqlite` files in the public repo or commit inventory records.

For a local-only read-only status endpoint, configure a *different* private random bearer secret `GINGERSCOPE_BACKEND_READ_TOKEN` (at least 32 ASCII characters) and run:

```sh
python3 -m pdiddler.backend.runtime serve --db /persistent-private-volume/gingerscope.sqlite --port 8787
```

Do not reuse the RBLXValue provider key as a reader token and **do not place either credential into the public Delta/Luau client**. The production identity/transport bridge has not been built and cannot be inferred from this local interface.

## Stage boundaries carried forward

- Market feed: P1 PR236 `MarketFeedV1` source rights, data age, actual game raw-key mapping, upstream restrictions and latest RBLXValue response remain **BLOCKED**. This backend stores only research receipt **metadata**, not unapproved actual price data. A source observation is not source-published, licensed live market authority.
- Inventory: client-only snapshots, not exact raw item or server ownership proof. One stage-to-stage restart does not transform client observations into settled transactions.
- P3: existing server selection/contacts/outgoing, cannot be rebuilt here. P4: guarded item trade UI, growth planner and future authorized Discord/learning, **not called** by this backend. Four **physical** slots remain distinct from four copies. Gingerscope stays protected outbound.
- Economic decisions: no old blanket +15, no forced highest opener, no automatic loss budget, no final Accept or unattributed profit. Separate Stage120 quality-adjusted strategy integration is a future issue.
- Discord: only **after** mandatory live trade/settlement tests and separately approved release; no webhook configuration or sending in this code.
- RBLXValue secret: currently managed in GitHub Actions, **not** installed on a persistent host. A GitHub Actions repository secret is not accessible to an independent cloud backend without a separate authorized deployment process. Do not move it to a game client.

## What must happen before calling this long-running system operational

1. **Deploy on an always-on private host with an attached persistent volume.** SQLite is the sole database in this design; do not introduce Supabase. No host, plan, private disk or cloud account has been provisioned.
2. Add backups/snapshot retention, uptime alerts, TLS termination, outbound allowlists, audited credentials and server health/restart policy; verify actual runtime survives restarts and database corruption/recovery.
3. Resolve P1 legal right to use actual derived MM2 prices. RBLXValue `ACTIVE` dashboard and GitHub HTTP403 `UNRECOGNIZED_JSON` are **not** a successful authenticated feed. No live snapshots/quotes until approval, exact mapping and true publisher timestamp.
4. After that, add a separately licensed source poller using sane refresh cadence and versioned validated snapshot promotion, then a read-only, integrity-checked planning *proposal* interface; never grant trade authority from the backend alone.
5. Later, integrate P4 with the read-only proposal boundary in a supervised test and independently authenticate server settlement before any Discord training, final Accept or unattended deployment.

Keep this DRAFT PR independent from P1 research PR236 and P3/P4 PR241. **Do not merge it into production trading or activate bots merely because CI passes.**
