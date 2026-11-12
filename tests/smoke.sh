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
chmod +x "$work_directory/bin/tar" "$work_directory/bin/journalctl"
export PATH="$work_directory/bin:$PATH"

failure_directory="$work_directory/failed-backup"
if bash scripts/backup.sh "$source_directory" "$failure_directory"; then
    printf 'Backup unexpectedly accepted a failed tar command.\n' >&2
    exit 1
fi
[[ -z $(find "$failure_directory" -mindepth 1 -maxdepth 1 -print) ]]

bash scripts/log_analysis.sh --since '30 minutes ago' --priority info --unit cron.service --lines 20 > "$work_directory/journal-args"
for argument in --system --no-pager --output=short-iso '--since=30 minutes ago' --priority=info --unit=cron.service --lines=20; do
    grep -Fxq -- "$argument" "$work_directory/journal-args"
done
journal_status=0
JOURNAL_FAIL=1 bash scripts/log_analysis.sh || journal_status=$?
[[ $journal_status == 42 ]]

printf 'Smoke tests passed.\n'
