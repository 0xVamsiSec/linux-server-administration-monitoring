#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for script in scripts/*.sh tests/*.sh; do
    bash -n "$script"
done

work_directory=$(mktemp -d)
trap 'rm -r -- "$work_directory"' EXIT

bash scripts/system_health.sh > "$work_directory/health.txt"
grep -Fx 'Linux System Health Report' "$work_directory/health.txt"
grep -E '^CPU utilization \(1-second sample\): [0-9]+\.[0-9]%$' "$work_directory/health.txt"
for heading in 'Memory usage:' 'Disk usage:' 'Top 5 processes by lifetime CPU percentage:' 'Interface addresses:'; do
    grep -Fxq "$heading" "$work_directory/health.txt"
done

export HOME="$work_directory/test home"
source_directory="$HOME/linux-monitoring-lab/data"
backup_directory="$HOME/linux-monitoring-lab/backups"
mkdir -p "$source_directory" "$work_directory/restore"
printf 'sample data\n' > "$source_directory/example.txt"
printf 'hidden data\n' > "$source_directory/.example"

first_archive=$(bash scripts/backup.sh)
second_archive=$(bash scripts/backup.sh "$source_directory" "$backup_directory")
[[ $first_archive != "$second_archive" && -f $first_archive && -f $second_archive ]]
tar -xzf "$first_archive" -C "$work_directory/restore"
diff -r -- "$source_directory" "$work_directory/restore/data"

if bash scripts/backup.sh "$work_directory/missing" "$work_directory/unused"; then
    printf 'Backup unexpectedly accepted a missing source.\n' >&2
    exit 1
fi
[[ ! -e $work_directory/unused ]]
if bash scripts/backup.sh "$source_directory" "$source_directory/nested"; then
    printf 'Backup unexpectedly accepted a destination inside the source.\n' >&2
    exit 1
fi
[[ ! -e $source_directory/nested ]]

unrelated_archive="$backup_directory/manual-backup.tar.gz"
nested_archive="$backup_directory/nested/backup_20200101T000000Z_ABCDEFGH.tar.gz"
mkdir -p -- "$(dirname -- "$nested_archive")"
touch -d '45 days ago' -- "$first_archive" "$unrelated_archive" "$nested_archive"
ln -s -- "$unrelated_archive" "$backup_directory/backup_20200101T000000Z_SYMLINK1.tar.gz"
bash scripts/backup.sh > /dev/null
[[ -f $first_archive ]]

retained_archive=$(bash scripts/backup.sh --retain-days 30)
[[ ! -e $first_archive && -f $second_archive && -f $retained_archive ]]
[[ -f $unrelated_archive && -f $nested_archive ]]
[[ -L $backup_directory/backup_20200101T000000Z_SYMLINK1.tar.gz ]]
if bash scripts/backup.sh --retain-days 0; then
    printf 'Backup unexpectedly accepted a zero-day retention period.\n' >&2
    exit 1
fi

log_directory="$HOME/linux-monitoring-lab/logs"
mkdir -p -- "$log_directory"
printf 'previous health report\n' > "$log_directory/health.log"
printf 'previous backup run\n' > "$log_directory/backup.log"
sed "s|LAB_HOME|$HOME|g" cron/monitoring.logrotate.example > "$work_directory/logrotate.conf"
logrotate --force --state "$work_directory/logrotate.state" "$work_directory/logrotate.conf"
grep -Fxq 'previous health report' "$log_directory/health.log.1"
grep -Fxq 'previous backup run' "$log_directory/backup.log.1"
[[ $(stat -c %a "$log_directory/health.log") == 600 && ! -s $log_directory/health.log ]]
[[ $(stat -c %a "$log_directory/backup.log") == 600 && ! -s $log_directory/backup.log ]]
printf 'next health report\n' > "$log_directory/health.log"
logrotate --force --state "$work_directory/logrotate.state" "$work_directory/logrotate.conf"
gzip -cd "$log_directory/health.log.2.gz" | grep -Fx 'previous health report'

mkdir -p "$work_directory/bin"
cat > "$work_directory/bin/tar" <<'EOF'
#!/bin/bash
printf 'simulated partial output\n' > "$2"
exit 1
EOF
cat > "$work_directory/bin/journalctl" <<'EOF'
#!/bin/bash
if [[ ${JOURNAL_FAIL:-0} == 1 ]]; then
    exit 42
fi
printf '%s\n' "$@"
EOF
cat > "$work_directory/bin/systemctl" <<'EOF'
#!/bin/bash
[[ $# == 3 && $1 == is-active && $2 == -- ]] || exit 2
case $3 in
    cron.service) printf 'active\n' ;;
    failed.service) printf 'failed\n'; exit 3 ;;
    *) exit 1 ;;
esac
EOF
cat > "$work_directory/bin/df" <<'EOF'
#!/bin/bash
if [[ $1 == --output=pcent,target ]]; then
    printf 'Use%% Mounted on\n89%% /below\n90%% /at threshold\n'
else
    exec /usr/bin/df "$@"
fi
EOF
chmod +x "$work_directory/bin/"*
export PATH="$work_directory/bin:$PATH"

failure_directory="$work_directory/failed-backup"
mkdir -p -- "$failure_directory"
old_archive="$failure_directory/backup_20200101T000000Z_ABCDEFGH.tar.gz"
touch -d '45 days ago' -- "$old_archive"
if bash scripts/backup.sh --retain-days 30 "$source_directory" "$failure_directory"; then
    printf 'Backup unexpectedly accepted a failed tar command.\n' >&2
    exit 1
fi
[[ $(find "$failure_directory" -mindepth 1 -maxdepth 1 -print) == "$old_archive" ]]

bash scripts/system_health.sh --cpu-threshold 0 --memory-threshold 0 --disk-threshold 90 \
    --service cron.service --service failed.service --service unknown.service > "$work_directory/alerts.txt"
grep -Eq '^ALERT CPU: [0-9]+\.[0-9]% \(threshold 0%\)$' "$work_directory/alerts.txt"
grep -Eq '^ALERT memory: [0-9]+\.[0-9]% \(threshold 0%\)$' "$work_directory/alerts.txt"
grep -Fxq 'ALERT disk /at threshold: 90% (threshold 90%)' "$work_directory/alerts.txt"
if grep -q '^ALERT disk /below' "$work_directory/alerts.txt"; then
    printf 'Disk threshold alerted below the configured limit.\n' >&2
    exit 1
fi
grep -Fxq 'cron.service active' "$work_directory/alerts.txt"
grep -Fxq 'ALERT service failed.service: failed' "$work_directory/alerts.txt"
grep -Fxq 'ALERT service unknown.service: status unavailable' "$work_directory/alerts.txt"
if bash scripts/system_health.sh --cpu-threshold 101; then
    printf 'Health check unexpectedly accepted a threshold above 100.\n' >&2
    exit 1
fi

bash scripts/log_analysis.sh --since '30 minutes ago' --priority info --unit cron.service --lines 20 > "$work_directory/journal-args"
for argument in --system --no-pager --output=short-iso '--since=30 minutes ago' --priority=info --unit=cron.service --lines=20; do
    grep -Fxq -- "$argument" "$work_directory/journal-args"
done
journal_status=0
JOURNAL_FAIL=1 bash scripts/log_analysis.sh || journal_status=$?
[[ $journal_status == 42 ]]

printf 'Smoke tests passed.\n'
