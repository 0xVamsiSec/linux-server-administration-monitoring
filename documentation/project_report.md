# Technical project report

## Objective

Build a repeatable Linux administration lab that exercises account management, file permissions, processes, services, networking, and operational troubleshooting. Use Bash and Cron to automate health reporting and backups on Ubuntu.

## Architecture

| Component | Role |
| --- | --- |
| Windows 11 and WSL2, or an Ubuntu VM | Hosts the Ubuntu environment. |
| Ubuntu and systemd | Run the lab and provide service management and journal access. |
| Bash and Linux utilities | Read resource counters, create backup archives, and query journal entries. |
| User crontab | Runs health reporting at 09:00, backups at 00:00, and optional log rotation at 00:30 in Ubuntu's system time zone. |
| Linux home directory | Stores sample data, generated reports, logs, and archives outside the Git source tree. |
| GitHub Actions | Runs the smoke tests against the repository on Ubuntu 24.04. |

## Implementation

The health script calculates aggregate CPU usage from two /proc/stat readings taken one second apart. It prints memory and filesystem usage, uptime, process statistics, and network interface addresses. Optional thresholds add CPU, memory, and per-filesystem disk alerts to the report. Named systemd units are checked with systemctl is-active.

The backup script creates a unique, private temporary archive in the destination directory. It publishes the archive only after tar succeeds. It rejects missing sources and destinations inside the source tree. Optional retention removes matching expired archives in the destination after publication. The documented restore procedure compares extracted files with the input directory.

The log script wraps journalctl with time, unit, priority, and entry-limit filters. It preserves the underlying command's diagnostics and exit status. The lab uses a disposable service failure as a source of known log messages.

The administration exercises use a disposable user and group, transient systemd services, and a key-authenticated SSH listener bound to loopback. The Cron example uses a regular user's crontab and appends to local log files. The optional logrotate configuration keeps seven rotations with delayed compression and a private state file.

## Verification

The [smoke test](../tests/smoke.sh) checks Bash syntax, report sections, threshold boundaries, service outcomes, backup restoration, expired archive pruning, failure cleanup, log rotation and compression, and journal argument and exit-status handling. It uses stand-ins for journal access and specific disk and service states.

The smoke tests and live checks passed on Ubuntu 24.04.5 LTS under WSL2 with systemd. The live checks used temporary lab resources and removed them afterward.

| Check | Observed result |
| --- | --- |
| Group permissions | A member read the group-owned file. An unrelated account was denied. |
| Processes | A disposable process appeared in the process list and terminated on request. |
| Services and journal | The deliberately failing service entered the failed state. The log script found its test message. A separate service started and stopped successfully. |
| Local SSH | The only listener on port 2222 was bound to 127.0.0.1. A temporary user authenticated with its SSH key. |
| Health report and backup | The health script printed all report sections. Two rapid backup runs produced distinct archives, and the restored files matched the source. Failure cases produced no completed archive. |
| Cron | Both jobs ran on a temporary every-minute schedule as a non-root user. The health log contained a fresh report and the scheduled archive restored the sample file. |

The expanded tests passed on the same Ubuntu WSL2 environment. A live service check reported the running Cron unit and flagged an inactive unit. The three updated Cron command lines were replayed as a regular user in a clean environment with a temporary home. The run pruned a 45-day-old fixture, restored the newly published backup, and verified that logrotate recreated the active logs with mode 0600. [Monitoring capture](../screenshots/health-alerts.png) · [Maintenance capture](../screenshots/backup-and-log-rotation.png)

The [lab runbook](lab.md) and [validation checklist](build-plan.md) provide the commands and checks to reproduce these results.

## Limitations

This lab covers local Ubuntu administration. Alerts are written to the report and scheduled logs. Backups and reports are stored locally, and scheduled jobs depend on the Ubuntu runtime being active. The checked-in health report was captured on WSL2 and sanitized for publication.
