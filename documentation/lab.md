# Ubuntu administration lab

Use a disposable Ubuntu WSL2 distribution or Ubuntu VM with systemd. Run the [quick start](../README.md#quick-start) first. Execute the examples from the project directory as your regular Linux user and use sudo where shown.

## Users, groups, and permissions

Run the two lookups below first. If either returns a result, use different names throughout the exercise.

~~~bash
getent passwd lm-labuser
getent group lm-labops
~~~

Create a user, add it to a supplementary group, and compare access by a group member and an outsider:

~~~bash
sudo groupadd lm-labops
sudo useradd --create-home --user-group --shell /bin/bash lm-labuser
sudo usermod -aG lm-labops lm-labuser
id lm-labuser

permission_dir=$(mktemp -d /tmp/linux-monitoring-permissions.XXXXXX)
chmod 0755 "$permission_dir"
printf 'Project group only\n' > "$permission_dir/team.txt"
sudo chown root:lm-labops "$permission_dir/team.txt"
sudo chmod 0640 "$permission_dir/team.txt"
stat -c '%A %a %U:%G %n' "$permission_dir/team.txt"

sudo -u lm-labuser -- cat "$permission_dir/team.txt"
sudo -u nobody -- cat "$permission_dir/team.txt"   # Expected: permission denied
~~~

Remove the file and accounts created for this exercise:

~~~bash
rm -- "$permission_dir/team.txt"
rmdir -- "$permission_dir"
sudo userdel --remove lm-labuser
sudo groupdel lm-labops
~~~

## Processes and systemd services

Inspect resources and manage a disposable process:

~~~bash
ps -eo pid,comm,pcpu,pmem --sort=-pcpu | head
free -h
df -h "$HOME"
du -sh "$HOME/linux-monitoring-lab"
sleep 300 &
lab_pid=$!
ps -p "$lab_pid" -o pid,stat,cmd
kill "$lab_pid"
~~~

Create a transient service that deliberately exits with status 1. Compare its systemd status with the filtered journal. Clear the failure and demonstrate a working service:

~~~bash
sudo systemd-run --wait --unit=linux-monitoring-demo \
  /bin/sh -c 'printf "lab: deliberate service failure\n" >&2; exit 1'
systemctl status linux-monitoring-demo.service --no-pager
sudo bash scripts/log_analysis.sh --unit linux-monitoring-demo.service --priority info --lines 15
sudo systemctl reset-failed linux-monitoring-demo.service

sudo systemd-run --unit=linux-monitoring-recovery --collect /usr/bin/sleep 300
systemctl is-active linux-monitoring-recovery.service
sudo systemctl stop linux-monitoring-recovery.service
~~~

## Networking and local SSH

Inspect addresses, routes, name resolution, and listening sockets:

~~~bash
ip -brief address
ip route
getent hosts localhost
ping -c 2 127.0.0.1
ss -tuln
~~~

The exercise starts a dedicated OpenSSH instance on 127.0.0.1:2222. On a fresh lab distribution, use runtime masks to prevent the package from starting the default listener during installation. The command records the original state of each unit and tracks which masks it adds. Keep the same Bash session for cleanup. [Ubuntu notes on SSH socket activation](https://documentation.ubuntu.com/release-notes/24.04/)

~~~bash
ssh_lab_masks=()
if [[ ! -x /usr/sbin/sshd ]]; then
    mask_failed=0
    for unit in ssh.service ssh.socket; do
        state=$(systemctl is-enabled "$unit" 2>/dev/null) || true
        printf '%s before lab: %s\n' "$unit" "${state:-not found}"
        case $state in
            masked|masked-runtime) continue ;;
        esac
        if sudo systemctl mask --runtime "$unit"; then
            ssh_lab_masks+=("$unit")
        else
            mask_failed=1
            break
        fi
    done
    if (( mask_failed == 0 )); then
        sudo apt install openssh-server
    fi
fi
~~~

If masking or installation fails, run the mask cleanup below before retrying.

Run `ss -ltn 'sport = :2222'` and verify that it returns no listener before continuing. Run this exercise as your regular, non-root Ubuntu login:

~~~bash
ssh_lab=$(mktemp -d "$HOME/linux-monitoring-lab/ssh.XXXXXX")
ssh_user=$(id -un)
ssh-keygen -q -t ed25519 -N '' -f "$ssh_lab/host_ed25519"
ssh-keygen -q -t ed25519 -N '' -f "$ssh_lab/client_ed25519"

cat > "$ssh_lab/sshd_config" <<EOF
Port 2222
ListenAddress 127.0.0.1
HostKey "$ssh_lab/host_ed25519"
PidFile "$ssh_lab/sshd.pid"
AuthorizedKeysFile "$ssh_lab/client_ed25519.pub"
AllowUsers $ssh_user
PermitRootLogin no
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
DisableForwarding yes
EOF

if [ ! -d /run/sshd ]; then sudo install -d -m 0755 /run/sshd; fi
sudo /usr/sbin/sshd -t -f "$ssh_lab/sshd_config" &&
  sudo systemd-run --unit=linux-monitoring-ssh --collect \
    /usr/sbin/sshd -D -e -f "$ssh_lab/sshd_config"

ss -ltn 'sport = :2222'   # Expected listener: 127.0.0.1:2222
printf '[127.0.0.1]:2222 %s\n' "$(cut -d ' ' -f 1,2 "$ssh_lab/host_ed25519.pub")" > "$ssh_lab/known_hosts"
ssh -F /dev/null -i "$ssh_lab/client_ed25519" -o IdentitiesOnly=yes -o BatchMode=yes \
  -o "UserKnownHostsFile=$ssh_lab/known_hosts" -o StrictHostKeyChecking=yes \
  -p 2222 "$ssh_user@127.0.0.1" id
~~~

If the listener has just started and ss shows no result, rerun the listener check and the SSH command. Confirm that the remote id command shows your Ubuntu user. Stop the listener and remove its temporary keys and configuration:

~~~bash
sudo systemctl stop linux-monitoring-ssh.service
rm -f -- "$ssh_lab"/{client_ed25519,client_ed25519.pub,host_ed25519,host_ed25519.pub,known_hosts,sshd_config,sshd.pid}
rmdir -- "$ssh_lab"
~~~

Remove only the runtime masks added in this Bash session. Unmasking allows the units to be started again and leaves any original masks in place.

~~~bash
if (( ${#ssh_lab_masks[@]} > 0 )); then
    sudo systemctl unmask --runtime "${ssh_lab_masks[@]}"
fi
~~~

## Backup and restore

Use the sample file created in the [quick start](../README.md#quick-start). Restore a fresh archive to a separate directory:

~~~bash
archive=$(bash scripts/backup.sh)
tar -tzf "$archive"
restore_dir=$(mktemp -d)
tar -xzf "$archive" -C "$restore_dir"
diff -r -- "$HOME/linux-monitoring-lab/data" "$restore_dir/data"
~~~

An empty diff and exit status 0 confirm the restored contents match. The script accepts custom paths, including paths with spaces. Choose a destination outside the source tree on a filesystem that supports hard links, such as Ubuntu's native filesystem.

To keep a 30-day window in a dedicated backup directory, run `bash scripts/backup.sh --retain-days 30`. The script first publishes the new archive, then removes matching regular archives in that directory whose modification time is at least 30 days old. It leaves unrelated files, symlinks, and subdirectories alone. If pruning fails, the command reports the error and the new archive remains available. [GNU Findutils timestamp comparisons](https://www.gnu.org/software/findutils/manual/html_node/find_html/Comparing-Timestamps.html)

## Schedule and verify Cron

Verify that Cron is active, check the Ubuntu clock, and review the [schedule template](../cron/monitoring.crontab.example):

~~~bash
sudo systemctl enable --now cron.service
systemctl is-active cron.service
date
cat cron/monitoring.crontab.example
~~~

Run crontab -e as your regular user and add the two commands from the template, keeping any existing jobs. Keep the sample PATH above the lab entries. For a timed test, temporarily replace the first five fields of both lab lines with five asterisks separated by spaces. Keep Ubuntu open through the next minute boundary and inspect the results:

~~~bash
crontab -l
tail -n 30 "$HOME/linux-monitoring-lab/logs/health.log"
tail -n 5 "$HOME/linux-monitoring-lab/logs/backup.log"
ls -lt "$HOME/linux-monitoring-lab/backups"
~~~

Look for a fresh health timestamp and a new archive from the same minute. Restore the template's daily schedules or remove the lab entries when finished. Cron can run while WSL is active. [Microsoft systemd lifecycle notes](https://learn.microsoft.com/en-us/windows/wsl/systemd/)

## Rotate the lab logs

Copy the [logrotate template](../cron/monitoring.logrotate.example) to the lab directory and replace both instances of `LAB_HOME` with your absolute Linux home path, for example `/home/ubuntu`. Validate it as your regular user before enabling the optional 00:30 entry in the Cron template.

~~~bash
cp -i -- cron/monitoring.logrotate.example "$HOME/linux-monitoring-lab/logrotate.conf"
nano "$HOME/linux-monitoring-lab/logrotate.conf"
logrotate --debug --state "$HOME/linux-monitoring-lab/logrotate.status" \
  "$HOME/linux-monitoring-lab/logrotate.conf"
~~~

The configuration keeps seven rotations per log, delays compression until the next rotation, and creates the new active files with mode 0600. It uses a separate state file for the lab. To check the results without waiting a day, run the same command with `--force` in place of `--debug` after both lab logs contain output, then check for `health.log.1` and `backup.log.1`. [logrotate reference](https://github.com/logrotate/logrotate/blob/main/logrotate.8.in)
