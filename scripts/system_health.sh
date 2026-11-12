#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [[ $# -gt 0 ]]; then
    if [[ $# -eq 1 && ( $1 == -h || $1 == --help ) ]]; then
        printf 'Usage: %s\n' "${0##*/}"
        exit 0
    fi
    printf 'Usage: %s\n' "${0##*/}" >&2
    exit 2
fi

read_cpu_counters() {
    local label user nice system idle iowait irq softirq steal rest
    if ! read -r label user nice system idle iowait irq softirq steal rest < /proc/stat || [[ $label != cpu ]]; then
        printf 'Could not read aggregate CPU counters from /proc/stat.\n' >&2
        return 1
    fi

    # Linux already includes guest time in user and nice counters.
    cpu_busy=$((user + nice + system + irq + softirq + steal))
    cpu_idle=$((idle + iowait))
}

read_cpu_counters
start_busy=$cpu_busy
start_idle=$cpu_idle
sleep 1
read_cpu_counters

busy_ticks=$((cpu_busy - start_busy))
idle_ticks=$((cpu_idle - start_idle))
total_ticks=$((busy_ticks + idle_ticks))

printf 'Linux System Health Report\n'
printf 'Timestamp: %s\n' "$(date --iso-8601=seconds)"
printf 'Hostname: %s\n' "$(hostname)"
printf 'Uptime and load averages:\n'
uptime

if (( busy_ticks >= 0 && idle_ticks >= 0 && total_ticks > 0 )); then
    awk -v busy="$busy_ticks" -v total="$total_ticks" \
        'BEGIN { printf "\nCPU utilization (1-second sample): %.1f%%\n", 100 * busy / total }'
else
    printf '\nCPU utilization (1-second sample): unavailable (invalid counter change)\n'
fi

printf '\nMemory usage:\n'
free -h

printf '\nDisk usage:\n'
df -h -x tmpfs -x devtmpfs

printf '\nTop 5 processes by lifetime CPU percentage:\n'
ps -eo pid,comm,pcpu,pmem --sort=-pcpu | awk 'NR <= 6'

printf '\nInterface addresses:\n'
ip -brief address
