#!/bin/bash
# mac-declutter inventory: read-only snapshot of agents, services, apps, caches, and hidden bloat.
# Usage: bash inventory.sh
set -u

echo "===== 1. Proxy state ====="
scutil --proxy | grep -E 'Enable|Port|Proxy' || true

echo; echo "===== 2. Agent config dirs (size, last activity) ====="
for d in "$HOME"/.[a-z]*; do
  [ -d "$d" ] || continue
  case "$d" in */.cache|*/.cargo|*/.rustup|*/.npm|*/.bun|*/.conda|*/.anaconda|*/.docker|*/.homebrew|*/.local|*/.config|*/.kimi-code) continue;; esac
  sz=$(du -sh "$d" 2>/dev/null | cut -f1)
  last=$(find "$d" -type f -not -name '.DS_Store' 2>/dev/null -exec stat -f '%m' {} + | sort -rn | head -1)
  [ -n "$sz" ] && printf '%-40s %-8s last: %s\n' "$d" "$sz" "$([ -n "$last" ] && date -r "$last" '+%Y-%m-%d' || echo empty)"
done | sort -rhk2

echo; echo "===== 3. Non-Apple launch agents (loaded) ====="
launchctl list 2>/dev/null | grep -vE 'com\.apple' | awk '{print $3}' | grep -v '^$' || true

echo; echo "===== 4. LaunchAgent plists ====="
ls "$HOME/Library/LaunchAgents/" 2>/dev/null || true

echo; echo "===== 5. Apps (size, MAS, last used) ====="
for app in /Applications/*.app "$HOME"/Applications/*.app; do
  [ -d "$app" ] || continue
  bid=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)
  case "$bid" in com.apple.*) continue;; esac
  sz=$(du -sh "$app" 2>/dev/null | cut -f1)
  used=$(mdls -name kMDItemLastUsedDate -raw "$app" 2>/dev/null)
  [ "$used" = "(null)" ] && used="never"
  mas=$([ -d "$app/Contents/_MASReceipt" ] && echo MAS || echo -)
  printf '%-32s %-7s %-4s %s\n' "$(basename "$app" .app)" "$sz" "$mas" "${used%% *}"
done | sort -k4

echo; echo "===== 6. Cache hotspots ====="
du -sh "$HOME/Library/Caches" "$HOME/.npm" "$HOME/.cache" "$HOME/.bun/install/cache" 2>/dev/null | sort -rh
du -sh "$HOME/Library/Caches/"* 2>/dev/null | sort -rh | head -8

echo; echo "===== 7. Build artifact hotspots ====="
# Rust target dirs
find "$HOME/projects" -maxdepth 5 -type d -name "target" -exec du -sh {} \; 2>/dev/null | sort -rh | head -5
# Node modules
find "$HOME/projects" -maxdepth 4 -type d -name "node_modules" -exec du -sh {} \; 2>/dev/null | sort -rh | head -5

echo; echo "===== 8. Sandbox container bloat ====="
du -d1 -sh "$HOME/Library/Containers/"*/ 2>/dev/null | sort -rh | head -10

echo; echo "===== 9. Xcode junk ====="
for d in "iOS DeviceSupport" "DerivedData" "Archives" "CoreSimulator"; do
  du -sh "$HOME/Library/Developer/Xcode/$d" 2>/dev/null
done

echo; echo "===== 10. Python virtual envs ====="
find "$HOME" -maxdepth 5 \( -name ".venv" -o -name "venv" -o -name ".step_ai_env" \) -not -path "*/node_modules/*" -exec du -sh {} \; 2>/dev/null | sort -rh | head -5

echo; echo "===== 11. Large files outside Library (>= 100M) ====="
find "$HOME" -maxdepth 6 -type f -size +100M -not -path "*/Library/*" -not -path "*/.Trash/*" -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -10

echo; echo "===== 12. Performance ====="
memory_pressure 2>/dev/null | tail -2
sysctl -n vm.swapusage vm.loadavg
echo; echo "Disk: $(df -h / | awk 'NR==2{print $4 " available of " $2}')"
