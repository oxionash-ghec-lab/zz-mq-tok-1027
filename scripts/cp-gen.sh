#!/usr/bin/env bash
mkdir -p cpdir
echo "AUTHORED-BY=MAINTAINER run=${GITHUB_RUN_ID:-?} event=${GITHUB_EVENT_NAME:-?}" > cpdir/marker.txt
echo "CP|GENERATED|$(cat cpdir/marker.txt)"
