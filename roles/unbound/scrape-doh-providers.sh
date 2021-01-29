#!/bin/bash

set -euo pipefail

scrape() {
  curl -fLsS https://raw.githubusercontent.com/wiki/curl/curl/DNS-over-HTTPS.md |
    sed -E '1,/^# Publicly available servers/d;/^#/,$d' |
    grep -Eo '^\|[^|]+\|[^|]+\|' |
    sed -E 's/\|[^|]+\|//;s/\|$//' |
    sed -E 's/<br>|,/\n/g' |
    sed -E 's/^ +//;s/ +$//' |
    grep -Eo 'https://.+' |
    sed -E 's|^.*https://||;s|(:[0-9]+)?(/.*)?$||' |
    grep -Fvx 'blog.cloudflare.com' |
    grep -Fvx 'my.nextdns.io'
}

cat <<__END__
\$TTL 30

@ IN SOA rpz.doh. hostmaster.rpz.doh. $(date +%Y%m%d%H%M) 86400 3600 604800 30
     NS localhost.

__END__

for zone in $(scrape | sort | uniq); do
  printf '%s CNAME .\n' "${zone}"
done
