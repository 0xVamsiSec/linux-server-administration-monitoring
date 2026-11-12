# Implementation and validation checklist

Work through the [Ubuntu setup](installation.md) before running the [administration lab](lab.md). Use this checklist to record results from the target machine.

## Implementation order

| Stage | Build or exercise | Evidence to capture |
| --- | --- | --- |
| 1. Environment | Verify the Ubuntu release, WSL2, systemd, and the baseline commands. | Ubuntu version, WSL distribution version, and PID 1. |
| 2. Users, groups, and files | Create a disposable lab user and group. Practice group membership, ownership, and file and directory permissions on sample data. | `id` and `stat` output plus one successful and one denied access check. |
| 3. Processes and services | Inspect CPU and memory with `ps`, `top`, and `free`. Practice starting, stopping, and inspecting a lab service. | Process output and the service status and journal before and after a change. |
| 4. Networking and SSH | Inspect interfaces, routes, name resolution, and listening sockets. Configure a loopback-only SSH listener and test key-based authentication as an unprivileged user. | Confirm the listening address with `ss` and record a successful `ssh` login from inside Ubuntu. |
| 5. Health reporting | Build `system_health.sh` to print a timestamp, hostname, uptime, sampled CPU usage, memory, disk usage, top processes, and IP addresses. | Compare one report with native command output and save a sanitized sample. |
| 6. Backups | Build `backup.sh` with `~/linux-monitoring-lab/data` as the default source and `~/linux-monitoring-lab/backups` as the destination. | Create and list an archive, restore it into a temporary directory, and compare the restored contents with the source. |
| 7. Scheduling | Add the health and backup commands to the current user's crontab. The report proposes 09:00 for health and 00:00 for backups, using Ubuntu's time zone. | Run each job on a temporary every-minute schedule, check its timestamped output, then set the daily schedule. |
| 8. Logs and handoff | Build `log_analysis.sh` around `journalctl`, practice troubleshooting, and update the project report with actual results. | Identify a known test log entry, document a service failure and recovery, and include sanitized evidence. |

## Changes to the draft implementation

- **Measure CPU across an interval.** The report's `top -bn1` is useful for a process snapshot. Compute CPU use from two `/proc/stat` samples to report utilization during a known interval.
- **Keep the backup input and output separate.** Back up the lab's sample `data/` directory. Write to a uniquely named temporary archive in the destination directory and publish it after `tar` succeeds. A missing source must produce a nonzero exit status without a completed archive. Test two rapid runs to verify that archive names are distinct.
- **Exercise the actual Cron environment.** Use an explicit `PATH`, absolute paths, and log files in the Linux lab directory. Check `crontab -l`, confirm `cron.service` is active, and verify fresh output from each job. Keep an Ubuntu session open during the timed test. A scheduled run can be missed if WSL is stopped. [Microsoft systemd lifecycle notes](https://learn.microsoft.com/en-us/windows/wsl/systemd/)
- **Make log results interpretable.** Filter by a bounded time window and optionally by systemd unit. Distinguish a successful query with no matching entries from a journal access or command failure.
- **Use reproducible troubleshooting cases.** Use a controlled failure in a disposable service, a small test directory for `du`, and a known local listener for connectivity. Record the symptom, command output, diagnosis, and observed recovery.

## Completion criteria

- All three scripts pass `bash -n` and run successfully in Ubuntu.
- Health alerts trigger at the configured limits and report service status.
- The lab demonstrates group permissions, process inspection, service recovery, and loopback SSH.
- A backup restores the sample data, and a missing source fails clearly. Retention prunes expired matching archives after success.
- Each Cron job produces an observed result under the intended user account.
- The logrotate configuration retains old output and creates new active logs with mode 0600.
- The lab evidence records the results observed in Ubuntu. Review local identifiers and private addresses before sharing the output.
