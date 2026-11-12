#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
    printf 'Usage: %s [--retain-days DAYS] [--] [source-directory [destination-directory]]\n' "${0##*/}"
    printf 'Defaults: ~/linux-monitoring-lab/data and ~/linux-monitoring-lab/backups\n'
}

if [[ $# -eq 1 && ( $1 == -h || $1 == --help ) ]]; then
    usage
    exit 0
fi

retain_days=
if [[ ${1:-} == --retain-days ]]; then
    if [[ ! ${2:-} =~ ^[1-9][0-9]{0,4}$ ]]; then
        printf '%s requires a positive integer from 1 to 99999.\n' "$1" >&2
        exit 2
    fi
    retain_days=$2
    shift 2
fi
if [[ ${1:-} == -- ]]; then
    shift
fi

if [[ $# -gt 2 || ( $# -ge 1 && -z ${1:-} ) || ( $# -eq 2 && -z ${2:-} ) ]]; then
    usage >&2
    exit 2
fi

source_directory=${1-"$HOME/linux-monitoring-lab/data"}
destination_directory=${2-"$HOME/linux-monitoring-lab/backups"}

if [[ ! -d $source_directory ]]; then
    printf 'Backup source is not a directory: %s\n' "$source_directory" >&2
    exit 1
fi
source_directory=$(realpath -e -- "$source_directory")
destination_directory=$(realpath -m -- "$destination_directory")

if [[ $source_directory == / || $destination_directory/ == "$source_directory/"* ]]; then
    printf 'Choose a backup destination outside the source directory.\n' >&2
    exit 1
fi

mkdir -p -- "$destination_directory"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
temporary_archive=$(mktemp -- "$destination_directory/.backup_${timestamp}_XXXXXXXX")
trap 'rm -f -- "$temporary_archive"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

temporary_name=${temporary_archive##*/}
archive="$destination_directory/${temporary_name#.}.tar.gz"

tar -czf "$temporary_archive" -C "$(dirname -- "$source_directory")" -- "${source_directory##*/}"

# Publish the complete archive without overwriting an existing backup.
ln -T -- "$temporary_archive" "$archive"
printf '%s\n' "$archive"

if [[ -n $retain_days ]]; then
    cutoff=$(( $(date +%s) - retain_days * 86400 ))
    # Restrict pruning to top-level regular files with the published naming pattern.
    find "$destination_directory" -maxdepth 1 -ignore_readdir_race -regextype posix-extended \
        -type f -regex '.*/backup_[0-9]{8}T[0-9]{6}Z_[[:alnum:]]{8}\.tar\.gz' \
        ! -samefile "$archive" ! -newermt "@$cutoff" -delete \
        -printf 'Pruned expired backup: %f\n' >&2
fi
