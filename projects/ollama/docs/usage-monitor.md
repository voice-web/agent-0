# Usage monitor (macOS)

Lightweight monitor that runs periodically and **publishes a message** when memory or CPU usage exceeds a threshold.

- **Publish** = macOS notification (default), or append to a log file.
- Runs as a **user LaunchAgent** (no root). You install it and grant nothing extra; the agent runs with your user permissions and can run `sysctl`, `vm_stat`, `top`, and show notifications.

## Install

1. Copy the LaunchAgent plist into your LaunchAgents directory and set the script path:

   ```bash
   # From projects/ollama (this bundle)
   MONITOR_SCRIPT="$(pwd)/scripts/usage-monitor"
   sed "s|SCRIPT_PATH_PLACEHOLDER|$MONITOR_SCRIPT|g" scripts/com.local.usage-monitor.plist > ~/Library/LaunchAgents/com.local.usage-monitor.plist
   ```

2. Load and start the agent (runs every 60 seconds):

   ```bash
   launchctl load ~/Library/LaunchAgents/com.local.usage-monitor.plist
   ```

3. Optional: change thresholds via the plist’s `EnvironmentVariables` (e.g. `USAGE_MONITOR_MEM_PCT` = 90, `USAGE_MONITOR_CPU_PCT` = 95), or edit the script defaults.

## Unload

```bash
launchctl unload ~/Library/LaunchAgents/com.local.usage-monitor.plist
```

## Config (env)

launchd reads the plist only when the job is **loaded**. If you change the plist (e.g. `EnvironmentVariables` or thresholds), **unload and load** the agent so the new config applies:

```bash
launchctl unload ~/Library/LaunchAgents/com.local.usage-monitor.plist
launchctl load   ~/Library/LaunchAgents/com.local.usage-monitor.plist
```

| Variable | Default | Meaning |
|----------|---------|---------|
| `USAGE_MONITOR_MEM_PCT` | 90 | Notify when memory used % ≥ this |
| `USAGE_MONITOR_CPU_PCT` | 95 | Notify when CPU used % ≥ this |
| `USAGE_MONITOR_PUBLISH` | notify | `notify` = macOS notification; `log` = append to log file |
| `USAGE_MONITOR_LOG` | ~/Library/Logs/usage-monitor.log | Log path when `PUBLISH=log` |

For `notify`, the agent must run in your login session (user LaunchAgent); then `osascript` can show the notification.

## System-level (optional)

To run at **system** level (when no one is logged in), install the plist in `/Library/LaunchDaemons/` and run as root. Then “publish” cannot be a user notification; use `USAGE_MONITOR_PUBLISH=log` or change the script to write to a file/socket/webhook. User LaunchAgent is usually enough for “alert me when my Mac is busy.”
