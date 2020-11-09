#!/bin/bash

set -euo pipefail

get_page() {
  curl -fLsS https://github.com/curl/curl/wiki/DNS-over-HTTPS
}

extract_hosts() {
  grep -Eo 'rel="nofollow">https://.+?<' |
    grep -E 'd(ns|oh)' |
    sed -E 's|^.+>https://||;s|(:[0-9]+)?/.*<||'
}

for zone in $(get_page | extract_hosts | sort | uniq); do
  printf 'local-zone: "%s." redirect\n' "${zone}"
  printf 'local-data: "%s. 3600 A 0.0.0.0"\n' "${zone}"
  printf 'local-data: "%s. 3600 AAAA ::"\n' "${zone}"
done
