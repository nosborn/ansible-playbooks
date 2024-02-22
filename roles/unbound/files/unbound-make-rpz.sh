#!/bin/sh

set -o errexit
set -o nounset

fetch_trackers() {
  curl -fLsS https://v.firebog.net/hosts/Easyprivacy.txt
  curl -fLsS https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt
  curl -fLsS https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/android-tracking.txt
  curl -fLsS https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/alexa
  curl -fLsS https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/apple
  curl -fLsS https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/huawei
  curl -fLsS https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/samsung
  curl -fLsS https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/sonos
  curl -fLsS https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/windows
  curl -fLsS https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/xiaomi
}

fetch_advertising() {
  curl -fLsS https://small.oisd.nl/rpz
  curl -fLsS https://v.firebog.net/hosts/AdguardDNS.txt
}

fetch_malware() {
  curl -fLsS https://urlhaus.abuse.ch/downloads/hostfile
}

fetch() {
  fetch_trackers
  fetch_advertising
  fetch_malware
}

format() {
  sed -E -e 's/^([0]{1,3}\.){3}[0]{1,3} //' |
    sed -e 's/^localhost //' |
    sed -e 's/^127\.0\.0\.1//' |
    sed -e 's/^::1//' |
    sed -e '/ localhost/d' |
    sed -e '/^#/d' |
    sed -e '/^;/d' |
    sed -e '/^$/d' |
    sed -e '/^@/d' |
    sed -e '/^\$TTL/d' |
    sed -e 's/#.*$//' |
    sed -E -e 's/^[[:space:]]+//' |
    sed -e 's/CNAME \.$//' |
    sed -e 's/\.$//' |
    sed -e '/^$/d' |
    grep -Fvx 'a1.api.bbc.co.uk' |
    grep -Fvx 'ati-a1.946d001b783803c1.xhst.bbci.co.uk' |
    sort |
    uniq |
    awk '{print $1, "IN CNAME ."}'
}

zone="$(mktemp)"
trap 'rm -f "${zone}"' EXIT

{
  cat <<EOT
@ IN SOA rpz.home.arpa. nobody.home.arpa. $(date +%s) 86400 7200 2592000 3600
@ IN NS localhost.
EOT
  fetch | dos2unix | format
} >"${zone}"

if ! cmp -s "${zone}" /var/lib/unbound/rpz.home.arpa.zone; then
  cp -f "${zone}" /var/lib/unbound/rpz.home.arpa.zone
  unbound-control reload || :
fi
