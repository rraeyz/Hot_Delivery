#!/usr/bin/env bash
# Online smoke test: a host and a client on localhost, both driven by the bot.
# Usage: tests/net_test.sh [seconds]
set -u
SECS=${1:-25}
MODE=${2:-normal}
cd "$(dirname "$0")/.."
godot --headless --path . -- --autotest --nethost --secs="$SECS" --mode="$MODE" --len="${3:-999}" > /tmp/net_host.log 2>&1 &
HOST=$!
sleep 3
godot --headless --path . -- --autotest --netjoin=127.0.0.1 --secs="$SECS" > /tmp/net_client.log 2>&1
CLIENT=$?
wait $HOST
HOSTRC=$?
grep -E "NET|SCRIPT ERROR" /tmp/net_host.log /tmp/net_client.log
if grep -q "SCRIPT ERROR" /tmp/net_host.log /tmp/net_client.log; then exit 1; fi
[ $CLIENT -eq 0 ] && [ $HOSTRC -eq 0 ]
