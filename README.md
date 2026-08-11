# Project Ironclad — Apex Health Systems SysAdmin Strategy

Course activity for CS 401 - System Administration. This repository contains the
strategy report, automation script, and supporting documentation for stabilizing
Apex Health Systems' IT operations.

## Repository Structure

```
project-ironclad/
├── README.md                         # This file — project overview and repo guide
├── SysAdmin_Strategy_Report.docx     # Full strategy report (Tasks 1-3)
├── daily_check.sh                    # Bash script: daily disk/SSH/service check
└── screenshots/                      # (add) VM setup, script output, monitoring dashboards
```

## Contents

- **SysAdmin_Strategy_Report.docx** — Workforce & AI policy, hybrid infrastructure
  and Active Directory design, and the monitoring/backup/DR plan.
- **daily_check.sh** — Automated routine check covering disk usage, failed SSH
  login attempts, and critical service status. Run with `sudo ./daily_check.sh`.
  Logs to `/var/log/daily_check/`.

## To Complete Before Submission

- [ ] Run `daily_check.sh` on the Ubuntu VM and add a screenshot/log excerpt to `screenshots/`
- [ ] Add Active Directory / GPO screenshots from the Windows Server VM
- [ ] Record the 3-5 minute video walkthrough (script execution + strategy summary)
- [ ] Fill in name/date placeholders in the report
- [ ] Submit repo link + video via Canvas/Moodle before Sunday 11:59 PM
