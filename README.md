# Linux Server Administration & Monitoring

A hands-on Linux administration lab for Ubuntu on WSL2 or in a VM. Practice managing users and services, diagnosing failures with the system journal, and connecting over SSH. Use Bash and Cron to collect system health reports and run backups you can restore.

## Quick start

Use Ubuntu with systemd and the utilities listed in the [setup guide](documentation/installation.md). Run these commands from your Ubuntu shell. The clone path matches the one used by the Cron template.

```bash
git clone https://github.com/0xVamsiSec/linux-server-administration-monitoring.git \
  "$HOME/linux-server-administration"
cd "$HOME/linux-server-administration"

mkdir -p "$HOME/linux-monitoring-lab"/{data,reports,logs,backups}
printf 'Linux monitoring lab\n' > "$HOME/linux-monitoring-lab/data/quickstart.txt"

bash scripts/system_health.sh | tee "$HOME/linux-monitoring-lab/reports/health.txt"
archive=$(bash scripts/backup.sh)
tar -tzf "$archive"
```

The health report and backup are saved under `~/linux-monitoring-lab`. To inspect recent warnings and errors, run the journal script with an account that can read the system journal.

```bash
sudo bash scripts/log_analysis.sh --since '30 minutes ago' --priority warning --lines 20
```

## Scripts

| Script | What it does |
| --- | --- |
| [`system_health.sh`](scripts/system_health.sh) | Samples CPU utilization over one second and reports uptime, memory, disks, processes, and interfaces. Supports CPU, memory, and disk alerts and checks named systemd services. See a [sanitized report from WSL2](reports/sample_health_report.txt). |
| [`backup.sh`](scripts/backup.sh) | Publishes a timestamped `.tar.gz` after compression succeeds. Accepts custom paths and an optional `--retain-days` policy. The default source and destination are `~/linux-monitoring-lab/data` and `~/linux-monitoring-lab/backups`. |
| [`log_analysis.sh`](scripts/log_analysis.sh) | Filters the system journal by time, unit, severity, and entry count. By default it shows up to 50 entries at warning priority or higher from the past hour. |

## Scheduled monitoring and maintenance

The [Cron template](cron/monitoring.crontab.example) checks CPU and memory at 85%, disk usage at 90%, and the status of `cron.service` at 09:00. Backups run at midnight with 30-day retention. Both jobs write to the lab user's logs. An optional 00:30 job [rotates those logs](documentation/lab.md#rotate-the-lab-logs). Schedules use Ubuntu's system time zone, and the distribution must be running when a job is due.

```bash
bash scripts/system_health.sh --cpu-threshold 85 --memory-threshold 85 \
  --disk-threshold 90 --service cron.service
```

Alerts appear in the report at or above the threshold. Add `--service UNIT` for each unit you want to check. Retention applies only when you supply `--retain-days`, after the new archive has been published. Use a separate backup destination per source if you enable pruning.

## Lab exercises

1. Create a user and group, set file ownership and permissions, and verify who can read the file. [Users and permissions](documentation/lab.md#users-groups-and-permissions)
2. Inspect and stop a process. Diagnose a deliberate systemd service failure from its journal entries. [Processes and services](documentation/lab.md#processes-and-systemd-services)
3. Check interfaces, routes, and listening sockets. Verify key-based SSH on `127.0.0.1:2222`. [Networking and local SSH](documentation/lab.md#networking-and-local-ssh)
4. Extract an archive into a temporary directory and compare it with the source. [Backup and restore](documentation/lab.md#backup-and-restore)
5. Verify that the scheduled jobs write a fresh health report and create a restorable backup. [Cron setup](documentation/lab.md#schedule-and-verify-cron)

## Verification

Verified on Ubuntu 24.04.5 LTS under WSL2. The live checks confirmed group access and outsider denial, systemd failure recovery, key-based loopback SSH, and backup restoration. Both Cron jobs ran as a regular user on a temporary every-minute schedule. [Full test results](documentation/project_report.md#verification)

The updated Cron commands also ran under a clean environment with a temporary Linux home. View the sanitized terminal output for [health alerts and service states](screenshots/health-alerts.png) and [backup retention and log rotation](screenshots/backup-and-log-rotation.png).

Run the smoke tests from the repository root with `logrotate` installed. They cover report output, alert thresholds, service states, backup restoration and pruning, log rotation, and journal filter arguments. The same tests run on pushes and pull requests. [GitHub Actions workflow](.github/workflows/checks.yml)

```bash
bash tests/smoke.sh
```

Use the [validation checklist](documentation/build-plan.md) to record your lab results and the [troubleshooting guide](documentation/troubleshooting.md) to investigate failures. The [interview notes](documentation/interview.md) explain the design choices and how the exercises relate to SAP BASIS work.
