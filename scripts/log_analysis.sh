#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s [--since TIME] [--unit UNIT] [--priority LEVEL] [--lines COUNT]\n' "${0##*/}"
    printf 'Defaults: the last hour, all units, warning and above, up to 50 entries.\n'
}

since='1 hour ago'
unit=
priority=warning
lines=50

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --since|--unit|--priority|--lines)
            if [[ $# -lt 2 || -z $2 || $2 == --* ]]; then
                printf 'Missing value for %s.\n' "$1" >&2
                exit 2
            fi
            case $1 in
                --since) since=$2 ;;
                --unit) unit=$2 ;;
                --priority) priority=$2 ;;
                --lines) lines=$2 ;;
            esac
            shift 2
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! $lines =~ ^[1-9][0-9]*$ ]]; then
    printf 'The entry limit must be a positive integer.\n' >&2
    exit 2
fi

if ! command -v journalctl >/dev/null; then
    printf 'journalctl is required. Run this script inside Ubuntu with systemd.\n' >&2
    exit 1
fi

arguments=(--system --no-pager --output=short-iso "--since=$since" "--priority=$priority" "--lines=$lines")
if [[ -n $unit ]]; then
    arguments+=("--unit=$unit")
fi

# Preserve journalctl's output, permission diagnostics, and exit status.
exec journalctl "${arguments[@]}"
