# Linux Server Administration & Monitoring

A hands-on Ubuntu lab for user and group administration, Linux permissions, processes and services, local SSH, resource monitoring, backups, Cron, and journal troubleshooting. It targets Ubuntu under WSL2 or in an Ubuntu VM with systemd.

## Quick start

Verify Ubuntu and install the lab utilities using the [setup guide](documentation/installation.md). Keep a copy of this folder at `~/linux-server-administration` for the Cron example. From that folder inside Ubuntu:

```bash
mkdir -p "$HOME/linux-monitoring-lab"/{data,reports,logs,backups}
printf 'Linux monitoring lab\n' > "$HOME/linux-monitoring-lab/data/example.txt"

bash scripts/system_health.sh | tee "$HOME/linux-monitoring-lab/reports/health.txt"
archive=$(bash scripts/backup.sh)
tar -tzf "$archive"
sudo bash scripts/log_analysis.sh --since '30 minutes ago' --priority warning --lines 20
```

Run the health and backup scripts as your regular user. The log query requires permission to read the system journal. The [administration lab](documentation/lab.md) walks through permissions, service recovery, loopback SSH, backup restoration, and a timed Cron test.

## Scripts

| Script | Inputs and output |
| --- | --- |
| [system_health.sh](scripts/system_health.sh) | Prints a timestamped report with uptime, one-second CPU utilization, memory, disk, top processes, and interface addresses. |
| [backup.sh](scripts/backup.sh) | Accepts optional source and destination directories. Defaults to `~/linux-monitoring-lab/data` and `~/linux-monitoring-lab/backups`. Prints the path of the completed archive. |
| [log_analysis.sh](scripts/log_analysis.sh) | Queries the system journal for up to 50 warning-or-higher entries from the past hour by default. Supports `--since`, `--unit`, `--priority`, and `--lines`. |

## Verification and documentation

- Run `bash tests/smoke.sh` on Ubuntu. The [GitHub Actions workflow](.github/workflows/checks.yml) runs it on pushes and pull requests.
- Use the [validation checklist](documentation/build-plan.md) and [troubleshooting guide](documentation/troubleshooting.md) during the lab.
- See the [project report](documentation/project_report.md) and [example health report](reports/sample_health_report.txt).

## Publish to GitHub

Create an empty GitHub repository named `linux-server-administration`. From this project folder, initialize and commit the source if you have not already done so:

```bash
git init -b main
git add .
git diff --cached --stat
git commit -m "Build Linux server administration and monitoring lab"
```

Then replace `YOUR_USERNAME` with your GitHub username and push:

```bash
git remote add origin https://github.com/YOUR_USERNAME/linux-server-administration.git
git push -u origin main
```

[GitHub guide to publishing an existing project](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)
