#!/bin/bash
#
# daily_healthcheck.sh
# Apex Health Systems - Daily SysAdmin Routine Check (Task 3 PoC)
#
# What it does:
#   1. Checks disk usage on all mounted filesystems, flags any over $DISK_THRESHOLD
#   2. Extracts failed SSH login attempts from auth logs and ranks offending IPs
#   3. Checks the status of critical services listed in $SERVICES
#   4. Writes a timestamped report to $LOG_DIR and prints a summary to stdout
#
# Suggested crontab (run daily at 7:00 AM):
#   0 7 * * * /path/to/daily_healthcheck.sh >> /var/log/apex_healthcheck/cron.log 2>&1
#
# Run manually with: sudo bash daily_healthcheck.sh

set -uo pipefail

# ---------- Configuration ----------
DISK_THRESHOLD=80                 # percent used before flagging
SERVICES=("sshd" "cron" "networking")   # edit to match your critical services
LOG_DIR="/var/log/apex_healthcheck"
DATE_STAMP=$(date +"%Y-%m-%d")
TIME_STAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/healthcheck_${DATE_STAMP}.log"

# Auth log location varies by distro; check the common ones
if [ -f /var/log/auth.log ]; then
    AUTH_LOG="/var/log/auth.log"
elif [ -f /var/log/secure ]; then
    AUTH_LOG="/var/log/secure"
else
    AUTH_LOG=""
fi

mkdir -p "$LOG_DIR"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "========================================"
log "Apex Health Systems - Daily Health Check"
log "Run time: $TIME_STAMP"
log "========================================"

# ---------- 1. Disk Usage Check ----------
log ""
log "--- Disk Usage ---"
FLAGGED=0
while read -r line; do
    USE_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
    MOUNT=$(echo "$line" | awk '{print $6}')
    FS=$(echo "$line" | awk '{print $1}')
    if [[ "$USE_PCT" =~ ^[0-9]+$ ]]; then
        if [ "$USE_PCT" -ge "$DISK_THRESHOLD" ]; then
            log "  [WARNING] $FS mounted on $MOUNT is at ${USE_PCT}% (threshold: ${DISK_THRESHOLD}%)"
            FLAGGED=$((FLAGGED + 1))
        fi
    fi
done < <(df -hP | tail -n +2)

if [ "$FLAGGED" -eq 0 ]; then
    log "  All filesystems below ${DISK_THRESHOLD}% usage."
else
    log "  $FLAGGED filesystem(s) flagged above threshold."
fi

# ---------- 2. Failed SSH Login Attempts ----------
log ""
log "--- Failed SSH Login Attempts (last 24h) ---"
if [ -n "$AUTH_LOG" ] && [ -r "$AUTH_LOG" ]; then
    FAILED_COUNT=$(grep -c "Failed password" "$AUTH_LOG" 2>/dev/null || echo 0)
    log "  Total failed attempts found in log: $FAILED_COUNT"
    if [ "$FAILED_COUNT" -gt 0 ]; then
        log "  Top offending IPs:"
        grep "Failed password" "$AUTH_LOG" \
            | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" \
            | sort | uniq -c | sort -rn | head -n 5 \
            | while read -r count ip; do
                log "    $ip - $count attempt(s)"
              done
    fi
else
    log "  [INFO] No readable auth log found (checked auth.log / secure). Skipping."
fi

# ---------- 3. Critical Service Status ----------
log ""
log "--- Critical Service Status ---"
SERVICE_ISSUES=0
for svc in "${SERVICES[@]}"; do
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            log "  [OK] $svc is running"
        else
            log "  [ALERT] $svc is NOT running"
            SERVICE_ISSUES=$((SERVICE_ISSUES + 1))
        fi
    else
        log "  [INFO] systemctl not available; cannot check $svc"
    fi
done

# ---------- Summary ----------
log ""
log "--- Summary ---"
log "  Disk warnings: $FLAGGED"
log "  Service issues: $SERVICE_ISSUES"
log "  Full report saved to: $LOG_FILE"
log "========================================"

exit 0
