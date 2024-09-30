#!/usr/bin/env bash

set -e

TIMEOUT_SECS=$((60 * 60))

if [ $# -lt 1 ]; then
  echo "Usage: $0 LOCKFILE" >&2
  exit 1
fi
LOCKFILE=$1
shift 1

echo "ourboros-consensus-tools"
echo "Lockfile: $LOCKFILE"

echo "Waiting for lock..."
flock --wait "$TIMEOUT_SECS" "$LOCKFILE" -- bash -e "${@}"
