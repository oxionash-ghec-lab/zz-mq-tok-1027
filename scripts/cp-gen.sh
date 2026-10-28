#!/usr/bin/env bash
# Authored by a NON-COLLABORATOR. Never reviewed. The only file in the attacker's pull request.
mkdir -p cpdir
echo "AUTHORED-BY=ATTACKER-NEVER-REVIEWED run=${GITHUB_RUN_ID:-?} event=${GITHUB_EVENT_NAME:-?}" > cpdir/marker.txt
echo "CP|GENERATED|$(cat cpdir/marker.txt)"
