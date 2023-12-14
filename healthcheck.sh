#!/bin/sh

# Usage: healthcheck.sh <chain>
# where <chain> is likely liquidv1

[ -n "$1" ] && [ -d "/var/lib/elementsd/$1" ] || exit 255
CHAIN="$1"; shift 1
[ -s "/var/lib/elementsd/$CHAIN/.cookie" ] || exit 1

get_getblockchaininfo_value_for_key() {
  [ -n "$1" ] && \
    timeout -k 60s 50s elements-cli -conf="/etc/elements/elements.conf" -datadir="/var/lib/elementsd/$CHAIN" -rpccookiefile="/var/lib/elementsd/$CHAIN/.cookie" getblockchaininfo | \
    sed -e 's/[{}]//g' -e 's/^\s\s*//g' -e '/^\s*$/d' | \
    awk '{ n = split($0, a, ","); for (i=1; i<=n; i++) print a[i]; }' | \
    sed  -e '/^\s*$/d' -e 's/\(^"\S\S*":\)\s\s*/\1/' | \
    awk -F ':' -v key="\"$1\"" '($1 == key) { print $2 }'
}

[ "$(get_getblockchaininfo_value_for_key 'initialblockdownload')" != "true" ] || exit 1
[ "$(get_getblockchaininfo_value_for_key 'headers')" = "$(get_getblockchaininfo_value_for_key 'blocks')" ] || exit 1

block_count=$(timeout -k 60s 50s elements-cli -conf="/etc/elements/elements.conf" -datadir="/var/lib/elementsd/$CHAIN" -rpccookiefile="/var/lib/elementsd/$CHAIN/.cookie" getblockcount 2> /dev/null)
[ -n "$block_count" ] || exit 1
latest_block_hash=$(timeout -k 60s 50s elements-cli -conf="/etc/elements/elements.conf" -datadir="/var/lib/elementsd/$CHAIN" -rpccookiefile="/var/lib/elementsd/$CHAIN/.cookie" getblockhash $block_count)
[ -n "$latest_block_hash" ] || exit 1
latest_block_time_stamp=$(timeout -k 60s 50s elements-cli -conf="/etc/elements/elements.conf" -datadir="/var/lib/elementsd/$CHAIN" -rpccookiefile="/var/lib/elementsd/$CHAIN/.cookie" getblock $latest_block_hash | awk -F ':' '($1 ~ /\s*"time"/) { sub(/^\s*/, "", $2); sub(/,$/, "", $2); print $2; }')
[ -n "$latest_block_time_stamp" ] || exit 1
latest_block_age=$(( $(date '+%s') - $latest_block_time_stamp ))

[ $latest_block_age -lt 300 ] || exit 1

exit 0
