#!/bin/sh
# manage_conf.sh
# usage:
#   manage_conf.sh spec.txt /path/to/file.conf

set -eu

spec="$1"
conf="$2"
backup="${conf}.orig"
tmp="${conf}.tmp.$$"

if [ ! -f "$backup" ]; then
  cp "$conf" "$backup"
fi

awk -f /root/pgconf_filter.awk "$spec" "$backup" > "$tmp"
mv "$tmp" "$conf"
