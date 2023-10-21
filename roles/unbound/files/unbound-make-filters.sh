#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
readonly workdir

{
  curl -fLsS https://raw.githubusercontent.com/Sekhan/TheGreatWall/master/TheGreatWall.txt |
    grep -Eo '^[^#]+' |
    awk '$1=="0.0.0.0" && NF==2 {print $2}'
} | sort | uniq | awk 'BEGIN {print "server:"}; NF==1 {print "\tlocal-zone: \"" $1 ".\" inform_redirect"}' >"${workdir}/blacklist-doh.conf"

blacklist="${workdir}/blacklist.raw"
whitelist="${workdir}/whitelist.raw"

cat >>"${blacklist}" <<EOT
2cnt.net
adservice.google.com.sg
advertising.amazon.co.uk
advertising.amazon.com
adtag.sphdigital.com
api.revenuecat.com
apptelemetry.io
assets.adobetm.com
c.betly.me
c4-ads-creative-prod.s3.eu-west-1.amazonaws.com.
c5ads.ott.skymedia.co.uk
captive.roku.com
cde-ta-g7g.amazon.com
cdn.http.anno.channel4.com
codepush.appcenter.ms
data.meethue.com
delivery.aimatch.net
demdex.net
device.marketingcloudapis.com
diag.meethue.com
diagnostics.meethue.com
e.reddit.com
events.channel4.com
events.data.microsoft.com
faro-collector-dev-us-central-0.grafana-dev.net
faro-collector-ops-us-east-0.grafana-ops.net
faro-collector-prod-eu-west-2.grafana.net
faro-collector-prod-us-central-0.grafana.net
firebaselogging-pa.googleapis.com
getup.today
graph.facebook.com
gstaticadssl.l.google.com
hawker.liftoff.io
hits-secure.theguardian.com
icons.duckduckgo.icons
in.appcenter.ms
init.cedexis-radar.net
iphonesubmissions.apple.com
metrics.tfe.apple-dns.net
mobile-app-expan.amazon.com
monitoring.ede565d7c6c3ee6b.xhst.bbci.co.uk
myadcash.com
nui.media
piwik.nic.cz
pixel.ad
public-live-ibl-user-activity-772687216.eu-west-1.elb.amazonaws.com
public.edigitalresearch.com
sc.omtrdc.net
sec-flare.com
skyadsuk.hs.llnwd.net
socialbars-web1.com
socialbars-web5.com
stats.grafana.org
stats.puri.sm
telemetry-in.battle.net
telemetry.insights.video.a2z.com
test.huedatastore.com
trace.aws.singtel.com
trk.adtracker3.com
txt.chatango.com
unagi.amazon.com
unagi-fe.amazon.com
unagi-na.amazon.com
unifi-report.ubnt.com
win10.ipv6.microsoft.com
win1710.ipv6.microsoft.com
yospace.com
EOT

cat >>"${whitelist}" <<EOT
channel4.sc.omtrdc.net
EOT

curl -fLsS https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains |
  grep -Eo '^[^#]+' |
  awk 'NF==1 {print tolower($1)}' >>"${blacklist}"

# for list in disconnect-ads.json disconnect-malvertising.json disconnect-tracking.json nextdns-recommended.json; do
#   data="$(curl -fLsS "https://raw.githubusercontent.com/nextdns/metadata/master/privacy/blocklists/${list}")"
#
#   jq -r '(.exclusions // []) | .[]' <<<"${data}" | sed 's/^\*\.//' >>"${whitelist}"
#
#   {
#     for url in $(jq -r '.source | select(.format=="hosts") | .url' <<<"${data}"); do
#       curl -fLsS "${url}" |
#         grep -Eo '^[^#]+' |
#         awk 'NF==2 {print tolower($2)}'
#     done
#
#     for url in $(jq -r '.sources[] | select(.format=="hosts") | .url' <<<"${data}"); do
#       curl -fLsS "${url}" |
#         grep -Eo '^[^#]+' |
#         awk 'NF==2 {print tolower($2)}'
#     done
#
#     for url in $(jq -r '.source | select(.format=="domains") | .url' <<<"${data}"); do
#       curl -fLsS "${url}" |
#         grep -Eo '^[^#]+' |
#         awk 'NF==1 {print tolower($1)}'
#     done
#
#     for url in $(jq -r '.sources[] | select(.format=="domains") | .url' <<<"${data}"); do
#       curl -fLsS "${url}" |
#         grep -Eo '^[^#]+' |
#         awk 'NF==1 {print tolower($1)}'
#     done
#   } | grep -Ex '.+\..+' | grep -Evx '([0-9]\.[0-9]\.[0-9]\.[0-9]|localhost\..+)' >>"${blacklist}"
# done

# Moved to RPZ.
# for name in alexa apple huawei roku samsung sonos windows xiaomi; do
#   curl -fLsS "https://raw.githubusercontent.com/nextdns/native-tracking-domains/main/domains/${name}"
# done | grep -Eo '^[^#]+' | awk 'NF==1 {print tolower($1)}' >>"${blacklist}"

# # shellcheck disable=SC2043
# for name in parked-domains-cname; do
#   curl -fLsS "https://raw.githubusercontent.com/nextdns/metadata/master/security/${name}"
# done | grep -Eo '^[^#]+' | awk 'NF==1 {print tolower($1)}' >>"${blacklist}"

curl -fLsS https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts |
  grep -Eo '^[^#]+' |
  awk 'NF==2 && $1=="0.0.0.0" {print tolower($2)}' >>"${blacklist}"

sort "${blacklist}" |
  uniq |
  unbound-shrink-filters.pl |
  sort |
  awk 'BEGIN {print "server:"}; {print "\tlocal-zone: \"" $1 ".\" inform_redirect"}' >"${workdir}/blacklist.conf"

sort "${whitelist}" |
  uniq |
  awk 'BEGIN {print "server:"}; NF==1 {print "\tlocal-zone: \"" $1 ".\" transparent"}' >"${workdir}/whitelist.conf"

changes=0
for file in blacklist.conf blacklist-doh.conf whitelist.conf; do
  if ! cmp -s "${workdir}/${file}" "/etc/unbound/unbound.conf.d/${file}"; then
    if [[ -e "/etc/unbound/unbound.conf.d/${file}" ]]; then
      cp -afv "/etc/unbound/unbound.conf.d/${file}" "/etc/unbound/unbound.conf.d/${file}.bak"
    fi
    cp -fv "${workdir}/${file}" "/etc/unbound/unbound.conf.d/${file}"
    changes=1
  fi
done
if [[ ${changes} -ne 0 ]]; then
  unbound-checkconf
  systemctl reload unbound.service
fi

exit # FIXME

# shellcheck disable=SC2043
for list in threat-intelligence-feeds.json; do
  data="$(curl -fLsS "https://raw.githubusercontent.com/nextdns/metadata/master/security/${list}")"

  jq -r '(.exclusions // []) | .[]' <<<"${data}" | sed 's/^\*\.//' >>"${whitelist}"

  {
    for url in $(jq -r '.sources[] | select(.format=="hosts") | .url' <<<"${data}"); do
      curl -fLsS "${url}" |
        grep -Eo '^[^#]+' |
        awk 'NF==2 {print $2}'
    done

    for url in $(jq -r '.sources[] | select(.format=="domains") | .url' <<<"${data}"); do
      curl -fLsS "${url}" |
        grep -Eo '^[^#]+' |
        awk 'NF==1 {print $1}'
    done
  } | grep -Ex '.+\..+' | grep -Evx '([0-9]\.[0-9]\.[0-9]\.[0-9]|localhost\..+)' >>"${blacklist}"
done
