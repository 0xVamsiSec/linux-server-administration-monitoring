# Troubleshooting

Start with the failing command and its exact error. Record the time, the unit or resource involved, the diagnostic output, and the result of rerunning the check after a change.

| Symptom | Check | What to verify |
| --- | --- | --- |
| systemctl cannot connect to the system bus | ps -p 1 -o comm= | PID 1 is systemd. Recheck the [WSL setup](installation.md) after restarting Ubuntu. |
| A service fails to start | systemctl status UNIT and sudo journalctl -u UNIT -n 30 --no-pager | Compare the unit exit status with its latest log entries. The [lab service](lab.md#processes-and-systemd-services) provides a known failure to practice on. |
| High CPU or memory use | top, free -h, and the health report | Review the sampled CPU percentage and the processes consuming resources. Compare available memory across repeated runs. |
| The filesystem is filling up | df -h PATH and du -h --max-depth=1 PATH | Identify the filesystem and the directories contributing to usage. Use the lab data directory to practice reading the output. |
| SSH connection refused | ss -ltn 'sport = :2222' and sudo journalctl -u linux-monitoring-ssh.service -n 30 | Confirm the dedicated listener is active and bound to 127.0.0.1:2222. |
| SSH rejects the key | ssh -v with the same options used in the lab | Verify the selected client identity, login name, home directory permissions, and server log. |
| Network name lookup fails | ip route and getent hosts HOSTNAME | Compare the interface and route state with name lookup. Test localhost independently of external DNS. |
| Backup returns an error | Verify the source exists and use df -h and ls -ld on the destination | Check free space and write access. Keep the destination outside the source and use a filesystem that supports hard links. |
| Cron logs are missing | crontab -l, systemctl is-active cron.service, and sudo journalctl -u cron.service -n 30 | Check the Linux time zone, script paths, and existence of the log directory. Keep Ubuntu open for the next scheduled minute. |
| Log output is empty or access is denied | sudo bash scripts/log_analysis.sh --since '1 hour ago' --priority info | A successful query can contain zero matching entries. If the command reports an error, check journal access and the unit or time filter. |

Before publishing captured output, remove local hostnames, personal account names, private IPs, and unrelated journal entries. Keep backups, raw logs, and SSH keys outside the repository.
