#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

usage() {
    printf 'Usage: %s [--cpu-threshold PCT] [--memory-threshold PCT]\n' "${0##*/}"
    printf '       [--disk-threshold PCT] [--service UNIT]...\n'
    printf 'Thresholds are integers from 0 to 100. Alerts are included in the report.\n'
}

cpu_threshold=
memory_threshold=
disk_threshold=
services=()

while (( $# > 0 )); do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --cpu-threshold|--memory-threshold|--disk-threshold)
            if [[ ! ${2:-} =~ ^(0|[1-9][0-9]?|100)$ ]]; then
                printf '%s requires an integer from 0 to 100.\n' "$1" >&2
                exit 2
            fi
            case $1 in
                --cpu-threshold) cpu_threshold=$2 ;;
                --memory-threshold) memory_threshold=$2 ;;
                --disk-threshold) disk_threshold=$2 ;;
            esac
            shift 2
            ;;
        --service)
            if [[ -z ${2:-} || $2 == -* ]]; then
                printf '%s requires a systemd unit name.\n' "$1" >&2
                exit 2
            fi
            services+=("$2")
            shift 2
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

print_threshold_alert() {
    awk -v metric="$1" -v observed="$2" -v threshold="$3" \
        'BEGIN { if (observed + 0 >= threshold + 0) printf "ALERT %s: %s%% (threshold %s%%)\n", metric, observed, threshold }'
}

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

cpu_percent=
if (( busy_ticks >= 0 && idle_ticks >= 0 && total_ticks > 0 )); then
    cpu_percent=$(awk -v busy="$busy_ticks" -v total="$total_ticks" \
        'BEGIN { printf "%.1f", 100 * busy / total }')
    printf '\nCPU utilization (1-second sample): %s%%\n' "$cpu_percent"
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

if [[ -n $cpu_threshold || -n $memory_threshold || -n $disk_threshold ]]; then
    printf '\nResource checks:\n'
fi

if [[ -n $cpu_threshold ]]; then
    if [[ -n $cpu_percent ]]; then
        print_threshold_alert CPU "$cpu_percent" "$cpu_threshold"
    else
        printf 'ALERT CPU check unavailable: invalid counter change\n'
    fi
fi

if [[ -n $memory_threshold ]]; then
    if memory_percent=$(awk '
        /^MemTotal:/ { total = $2 }
        /^MemAvailable:/ { available = $2 }
        END {
            if (total <= 0 || available == "" || available > total) exit 1
            printf "%.1f", 100 * (total - available) / total
        }' /proc/meminfo); then
        printf 'Memory utilization: %s%%\n' "$memory_percent"
        print_threshold_alert memory "$memory_percent" "$memory_threshold"
    else
        printf 'ALERT memory check unavailable: could not read memory counters\n'
    fi
fi

if [[ -n $disk_threshold ]]; then
    df --output=pcent,target -x tmpfs -x devtmpfs | awk -v threshold="$disk_threshold" '
        NR > 1 && $1 ~ /^[0-9]+%$/ {
            percent = $1
            if (percent + 0 >= threshold + 0) {
                sub(/^[[:space:]]*[0-9]+%[[:space:]]+/, "")
                printf "ALERT disk %s: %s (threshold %s%%)\n", $0, percent, threshold
            }
        }'
fi

if (( ${#services[@]} > 0 )); then
    printf '\nSystemd services:\n'
    for service in "${services[@]}"; do
        if state=$(systemctl is-active -- "$service"); then
            printf '%s %s\n' "$service" "$state"
        else
            printf 'ALERT service %s: %s\n' "$service" "${state:-status unavailable}"
        fi
    done
fi
