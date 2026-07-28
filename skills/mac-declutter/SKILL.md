---
name: mac-declutter
description: Deep-clean a macOS machine — inventory and uninstall stale AI agents/CLIs/apps, remove launchd services, login items, Library leftovers, caches, and fix proxy/network misconfiguration. Use when the user wants to declutter their Mac, remove unused AI coding agents, free disk space, kill zombie background services, diagnose "everything disconnected" proxy failures, or audit system performance (memory/CPU). Triggers include "clean up my mac", "too many agents installed", "uninstall leftovers", "what's taking space", "check my mac's performance".
metadata:
  version: "1.0.0"
---

# mac-declutter

A battle-tested playbook for decluttering a developer's Mac: AI agent sprawl, dead background services, app leftovers, proxy traps, and performance audits.

Core principles:

- **Inventory before deleting.** Never uninstall blind — measure size, last-used date, and running state first, then let the user pick.
- **Never touch session records or user data unless explicitly asked.** Caches regenerate; sessions don't.
- **Verify after every mutation** — process gone, port closed, login item removed.
- **System Integrity Protection (SIP) is a hard wall.** Root-owned apps, sandbox containers, and DriverKit extensions each have a sanctioned removal path; don't fight the OS.

## Phase 0 — Network triage (do this first)

Symptom "everything is disconnected" is almost always a dead local proxy, not broken apps:

```bash
scutil --proxy                       # what the system proxy points to
nc -z -w 2 127.0.0.1 <port>        # is anything actually listening?
lsof -nP -iTCP:<port> -sTCP:LISTEN # who owns it
```

The classic trap: Clash/V2Ray-style tools set the macOS system proxy to `127.0.0.1:PORT`, then the core dies — **rule mode doesn't matter, all traffic dies at the door**. Apps honoring the system proxy (most GUI apps, some CLIs) all fail; `curl` still works because it bypasses the system proxy, which misleads diagnosis. Fixes: restart the proxy core, or disable the proxy (`networksetup -setwebproxystate Wi-Fi off` + `-setsecurewebproxystate` + `-setsocksfirewallproxystate` + WPAD off), or point the app's own proxy setting at nothing. Remember: `curl` ignores system proxy — test app-style connectivity with `curl -x http://127.0.0.1:PORT`.

## Phase 1 — Inventory (read-only)

Run `scripts/inventory.sh`, or manually cover these dimensions:

- **Agent config dirs**: `~/.claude`, `~/.codex`, `~/.pi`, `~/.jcode`, `~/.config/opencode`, etc. For each: size (`du -sh`), last activity (newest file mtime), whether the CLI binary still exists (`which`).
- **Login/auth state**: `auth.json`, `openai-auth.json`, credential files — list keys, never print secrets.
- **Background services**: `launchctl list | grep -v com.apple` and `~/Library/LaunchAgents/*.plist` — read each plist's `ProgramArguments` to learn what it actually runs.
- **Apps**: for every non-Apple `.app` in `/Applications` and `~/Applications`, collect size, `kMDItemLastUsedDate` via `mdls`, and `_MASReceipt` presence (App Store apps). "Never opened" + large = prime candidate.
- **Caches**: `~/Library/Caches`, `~/.npm`, pip/bun caches — big and always safe to purge.

Present findings as a keep/remove table and let the user choose. Flag paid/subscription apps (e.g. `_MASReceipt`, known subscription products) so the user cancels billing before deleting.

## Phase 2 — Uninstall playbook

Per target, in order:

1. **Stop services**: `launchctl remove <label>` for every related LaunchAgent/Daemon.
2. **Delete plists**: `~/Library/LaunchAgents/<label>.plist`.
3. **Delete the app/CLI**: `rm -rf` the `.app` / `npm uninstall -g <pkg>` / remove the binary.
   - `Permission denied` → root-owned (pkg-installed). Use `osascript -e 'do shell script "rm -rf ..." with administrator privileges'` (one GUI password prompt). Never `sudo` blindly.
4. **Library leftovers**: check and remove `~/Library/{Application Support,Caches,Containers,HTTPStorages,Preferences}/<app-or-bundle-id>`.
   - Sandbox `Containers/*` may resist even root (container-manager protection). If tiny, leave them — the OS reaps orphaned containers; disabling SIP is never worth it.
5. **System extensions**: `systemextensionsctl list`. SIP blocks direct uninstall — the only clean path is reinstalling the vendor app and running **its official uninstaller** (look for `uninstall.sh` under `/Library/Application Support/<vendor>/`). DriverKit `.dext` drivers unload only at next reboot — tell the user it's gone after restart.
6. **Stale login items**: after deleting an app, its "Open at Login" entry often remains as a zombie. Remove with `osascript -e 'tell application "System Events" to delete login item "<name>"'`.
7. **Running leftovers**: deleted apps can leave processes running from updater temp dirs (e.g. Squirrel `ShipIt` staging). `ps aux | grep -i <name>`, kill them, and check for a data dir in `$HOME` (`~/.<appname>`) — updater-spawned daemons often hide hundreds of MB there.

## Phase 3 — Cache purge (zero risk)

```bash
npm cache clean --force
rm -rf ~/Library/Caches/pip ~/.bun/install/cache
rm -rf ~/Library/Caches/<deleted-app>/*
```

Caches regenerate. Session histories (`sessions/`, `projects/`, `*.jsonl` conversation logs) do not — leave them unless the user explicitly says otherwise.

## Phase 4 — Performance audit

```bash
memory_pressure | tail -2    # free % and pressure
sysctl -n vm.swapusage       # swap used should be ~0 on a healthy machine
sysctl -n vm.loadavg
ps -axm -o rss,comm | awk 'NR>1 {rss=$1; $1=""; sub(/^ /,""); a[$0]+=rss} END {for (k in a) printf "%d\t%s\n", a[k]/1024, k}' | sort -rn | head -15
```

- "Used memory" in Activity Monitor includes file cache — judge by **memory pressure color and swap**, not the GB number.
- After mass deletion, Spotlight (`mds_stores`, `corespotlightd`) re-indexes for a few hours — temporary, do not "fix" it.
- Group RSS by app family (browsers and chat apps spawn many helpers); report per-family totals, not per-process noise.
- Don't optimize what isn't a problem: on a machine with zero swap and green pressure, trading daily-driver UX (e.g. a smart IME) for a few hundred MB is a bad trade — say so.

## Phase 5 — Final verification

- Deleted labels absent from `launchctl list`; plists gone; no processes matching deleted names (except reboot-pending drivers).
- Proxy port listening matches `scutil --proxy`; key API endpoints reachable (`401` = reachable-but-needs-auth, which is a pass).
- Each surviving agent CLI passes a real end-to-end test (send a one-line prompt, expect a reply).
- `df -h /` before/after for the score.
