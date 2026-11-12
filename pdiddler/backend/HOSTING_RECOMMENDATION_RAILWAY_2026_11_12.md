# Hosting recommendation for months-long Gingerscope backend — Nov 12, 2026

**Decision status:** RECOMMENDATION, not provisioning, purchase, credentials access, deployment, or runtime verification. User explicitly rejected Supabase; do not deploy one. Use the existing SQLite-only private backend in draft PR #242. No live RBLXValue price feed is authorized; latest HTTP403, unclear source reuse rights and exact item mapping still block market trading.

## Primary recommendation: Railway Hobby, managed persistent-service hosting

**Why this for the current user:** GitHub-connected browser dashboard, straightforward Python service deployment, durable volume mounting and scheduled backups, app availability without a PC/terminal and less VPS administrative burden. The user is primarily on an iPad and wants a long-running service for a potentially months-long Gingerscope trading project. Railway hosts the **backend/market research service** only, not the MM2 client or Delta, whose runtime can still disconnect.

Official evidence checked Nov12:
- https://railway.com/pricing and https://docs.railway.com/pricing — Hobby **$5/month minimum**, with **$5 monthly usage credit**, excess usage charged. Standard compute usage pricing approx **$10/GB RAM-month** + **$20/vCPU-month (usage metered)**, and volume billed **$0.15/GB-month**. $5 is a floor, NOT a guaranteed all-inclusive limit. Estimate light 0.1–0.3 GB RAM plus little CPU may fit near $5, but actual hosting bill is unknown until measured; set billing alerts and thresholds before deployment. Hobby supports 5 GB per volume by default and additional private volumes within plan limits.
- https://docs.railway.com/quick-start and https://docs.railway.com/services — connect GitHub repo using web UI; Railway service can remain always running and redeploy from GitHub. This draft backend has no Dockerfile/Railpack configuration yet; do not claim deploy-ready until startup validated.
- https://docs.railway.com/deployments/serverless — **disable Serverless/auto-sleep**; otherwise a quiet process can be suspended after 5–10 min of low outbound activity, contrary to the user's continuous goal.
- https://docs.railway.com/deployments/restart-policy — Hobby supports **Always** restart policy. A process crash should relaunch; restart is NOT the same as database disaster recovery.
- https://docs.railway.com/volumes and https://docs.railway.com/volumes/reference — mount a private durable volume at e.g. `/data`; run exactly **one replica** writing a single SQLite DB at `/data/gingerscope.sqlite`, not the ephemeral container filesystem. Mount occurs at startup, not build.
- https://docs.railway.com/volumes/backups — enable daily/weekly/monthly volume snapshots. Restores are **within the same Railway project/environment only**; wiping the volume deletes backups. Therefore volume backups alone are NOT independent disaster recovery. Use separate private, encrypted offsite backups, test restoration to a NEW DB path, never send data to public Git or log.
- https://docs.railway.com/deployments/healthchecks — Railway deployment healthchecks are startup checks, **not continuous availability monitoring**. Need an independent uptime or health heartbeat alert.
- https://docs.railway.com/deployments/regions — app and attached volume share region; moving regions can incur downtime.
- https://docs.railway.com/pricing/cost-control — set email usage alerts and distinguish hard budget shutdowns from guaranteed continuity. Hard cap can STOP service; never portray as safe always-on choice without tradeoff.

## Alternatives considered

| Hosting | Official base price in Nov 2026 | Pros | Drawbacks for current stage |
|---|---|---|---|
| Railway Hobby | $5/mo min (includes usage credit, overage possible) | GitHub web deploy; volumes; backups; always-on when Serverless OFF | Billing variable; backups same project; extra backend edge bridge needed |
| DigitalOcean Basic Droplet (1 GB) | $6/mo + backups (weekly +20% / daily +30% of VM cost) | Conventional always-on Linux VM, 25 GB disk, fixed plan cap | SSH/OS patching/firewall, backups/admin harder from iPad; more operator burden |
| Fly.io | shared-cpu 256MB about $2.19/mo + $0.15/GB volume | Small always-on app and persistent disk; 10GB snapshot included | 256MB tight, more CLI/configuration; rootfs/snapshot/region considerations |
| Render Starter paid service | $7/mo for 512 MB + $0.25/GB disk | GitHub support, TLS, persistence | More expensive at the small size; attached disk needed for SQLite |

Source links: https://www.digitalocean.com/pricing/droplets ; https://docs.digitalocean.com/products/backups/details/pricing/ ; https://fly.io/pricing-update/ ; https://render.com/pricing ; https://render.com/docs/disks . Recheck prices at checkout, including taxes and billing settings; no service/account was purchased.

## Operational plan — only AFTER user chooses and connects Railway

1. Connect the Railway app via ChatGPT or create a Railway account through https://railway.com ; **connection/installation requires explicit user action**. Do not assume access to account or charge.
2. Review draft PR #242 and prepare a minimal service build/start for a stdlib Python monorepo; configure no public domain initially. Current `pdiddler.backend.runtime` binds **127.0.0.1 only**; this is intentionally **not** reachable through Railway public routing. Until a separately reviewed authenticated/TLS bridge exists, do not expose a port or inject a bearer token into public Delta script.
3. Railway Hobby service with **one** replica, persistent volume `/data` (or an available private Railway mount), database `/data/gingerscope.sqlite`, disabled Serverless, restart Always, limited resources and cost alerts. Private environment secret `GINGERSCOPE_BACKEND_READ_TOKEN` only if status API is used; never reuse RBLXValue key.
4. First bring up **research-only health and SQLite** with `MarketStatus=UNAVAILABLE`, `authorizesTrade=false`, `authorizesAccept=false`, `maySendDiscordWebhook=false`. Verify actual DB read/write across deployment restart, backup/restore, and service crash from provider logs.
5. Enable Railway volume backups daily plus a separate encrypted offsite snapshot in a different account/provider when proper storage access and security review exist. SQLite online backup method already exists and passed draft PR #242 Python tests; offsite storage transport is **not yet implemented**. Regularly perform a restore drill.
6. Only after source rights/fresh per-item licensed quote authentication and exact game raw keys are established, add permitted private market polling and planner read-only output. The actual Luau/Delta client requires a separate short-lived, least-privilege authorization protocol. Never expose source credentials to game client.
7. Never conflate backend continuous uptime with 24/7 Roblox game presence. An iPad connection, game crash or platform restrictions can still stop gameplay. P3/P4 remain separately supervised and final Accept off; no Discord learning until verified settlement and separate approval.

## Current GitHub state

- Draft PR #242 on `infra/gingerscope-persistent-backend-v1`: SQLite WAL, research-only market receipt, client-only inventory/trade event journal, local health scheduler, loopback read-only status API, private online backup and restore-readback tests. **Not deployed to any cloud**.
- Draft PR #236: RBLXValue P1 provider API research, GitHub manual test HTTP403 and source licensing unresolved.
- Draft PR #241: P3/P4 client trade test plan and strategy requirements; not modified by this hosting choice.
- Do not enable automatic final Accept, trade/market authority, live loss budget, webhook profit messages or learning because hosting is selected.
