# Technical project report

## Objective

Build a repeatable Linux administration lab that exercises account management, file permissions, processes, services, networking, and operational troubleshooting. Use Bash and Cron to automate health reporting and backups on Ubuntu.

## Architecture

| Component | Role |
| --- | --- |
| Windows 11 and WSL2, or an Ubuntu VM | Hosts the Ubuntu environment. |
| Ubuntu and systemd | Run the lab and provide service management and journal access. |
| Bash and Linux utilities | Read resource counters, create backup archives, and query journal entries. |
| User crontab | Runs health reporting at 09:00 and backups at 00:00 in Ubuntu's system time zone. |
| Linux home directory | Stores sample data, generated reports, logs, and archives outside the Git source tree. |
| GitHub Actions | Runs the smoke tests against the repository on Ubuntu 24.04. |

## Implementation

The health script calculates aggregate CPU usage from two /proc/stat readings taken one second apart. It prints memory and filesystem usage, uptime, process statistics, and network interface addresses.

The backup script creates a unique, private temporary archive in the destination directory. It publishes the archive only after tar succeeds. It rejects missing sources and destinations inside the source tree. The documented restore procedure compares extracted files with the input directory.

The log script wraps journalctl with time, unit, priority, and entry-limit filters. It preserves the underlying command's diagnostics and exit status. The lab uses a disposable service failure as a source of known log messages.

The administration exercises use a disposable user and group, transient systemd services, and a key-authenticated SSH listener bound to loopback. The Cron example uses a regular user's crontab and appends to local log files.

## Verification

The [smoke test](../tests/smoke.sh) checks Bash syntax, report sections, backup extraction, distinct archive names, missing and nested paths, failed-archive cleanup, and journal argument and exit-status handling. The test uses a stand-in journal command for deterministic checks.

The smoke tests and live checks passed on Ubuntu 24.04.5 LTS under WSL2 with systemd. The live checks used temporary lab resources and removed them afterward.

| Check | Observed result |
| --- | --- |
| Group permissions | A member read the group-owned file. An unrelated account was denied. |
| Processes | A disposable process appeared in the process list and terminated on request. |
| Services and journal | The deliberately failing service entered the failed state. The log script found its test message. A separate service started and stopped successfully. |
| Local SSH | The only listener on port 2222 was bound to 127.0.0.1. A temporary user authenticated with its SSH key. |
| Health report and backup | The health script printed all report sections. Two rapid backup runs produced distinct archives, and the restored files matched the source. Failure cases produced no completed archive. |
| Cron | Both jobs ran on a temporary every-minute schedule as a non-root user. The health log contained a fresh report and the scheduled archive restored the sample file. |

The [lab runbook](lab.md) and [validation checklist](build-plan.md) provide the commands and checks to reproduce these results.

## Limitations

This lab covers local Ubuntu administration. It uses local backups and report files. Monitoring is point-in-time, archives are kept until manually removed, and scheduled jobs depend on the Ubuntu runtime being active. The checked-in health report was captured on WSL2 and sanitized for publication.
