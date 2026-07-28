# mac-declutter

An agent skill for deep-cleaning macOS developer machines: AI agent sprawl, zombie background services, app leftovers, stale login items, dead-proxy network traps, cache purges, and performance audits.

Born from a real-world cleanup session that reclaimed ~20 GB and removed dozens of stale agents/services from a working developer's Mac.

## What it covers

- **Network triage** — diagnose the classic "everything is disconnected" failure: a proxy tool (Clash & friends) sets the macOS system proxy and then its core dies
- **Inventory** — agents/CLIs, config dirs, launchd services, apps (size / last-used / App Store receipt), cache hotspots
- **Uninstall playbook** — launchd teardown, root-owned apps, Library leftovers, sandbox containers, system extensions & SIP, stale login items, updater-spawned zombie processes
- **Cache purge** — npm/pip/bun/app caches (sessions and user data are never touched)
- **Performance audit** — memory pressure, swap, per-app-family RSS, Spotlight re-index awareness

## Layout

- `SKILL.md` — the skill (works with pi, Kimi Code, Claude Code-style skill loaders)
- `scripts/inventory.sh` — read-only system snapshot used in Phase 1

## Install

```bash
# pi (recommended)
pi install npm:mac-declutter

# or copy manually
cp -R skills/mac-declutter ~/.pi/agent/skills/

# or symlink to share across agents
ln -s "$PWD/mac-declutter" ~/.agents/skills/mac-declutter
```

## License

MIT
