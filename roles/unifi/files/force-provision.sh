#!/bin/bash

set -o errexit
set -o nounset

gateway_mac="e0:63:da:8b:98:80"   #MAC address of the gateway you wish to manage
unifi_server="unifi.home.arpa"    #Name/IP of unifi controller server
username="ubnt"                   #Unifi username
password="jexWid-qicbo1-vazneh"   #Unifi password
baseurl="https://${unifi_server}" #Unifi URL

cookie=$(mktemp)
trap 'rm "${cookie}"' EXIT

login() {
  curl --fail --insecure --show-error --silent \
    --cookie-jar "${cookie}" \
    --data "$(printf '{"username":"%s","password":"%s"}' "${username}" "${password}")" \
    --header 'Content-Type: application/json' \
    --url "${baseurl}/api/auth/login"
}

token=$(login | jq -r .deviceToken)

echo "----"
cat "${cookie}"
echo "----"

# curl --fail --insecure \
#   --cookie "${cookie}" \
#   --cookie-jar "${cookie}" \
#   --url "${baseurl}/proxy/network/api/s/default/stat/health"

curl -v --fail --insecure \
  --cookie "${cookie}" \
  --data "$(printf '{"mac":"%s","cmd":"force-provision"}' "${gateway_mac}")" \
  --header 'Accept: application/json, text/plain, */*' \
  --header 'Accept-Encoding: gzip, deflate, br' \
  --header 'Accept-Language: en-GB,en;q=0.9' \
  --header 'Connection: keep-alive' \
  --header 'Content-Type: application/json' \
  --header 'Origin: https://unifi.home.arpa' \
  --header 'X-CSRF-Token: d439dd43-6923-4a45-99e7-5918e8a51ce3' \
  --referer "https://unifi.home.arpa/network/default/devices/properties/${gateway_mac}/settings" \
  --url "${baseurl}/proxy/network/v2/api/s/default/cmd/devmgr" \
  --user-agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.3 Safari/605.1.15'

# curl --fail --insecure \
#   --cookie "${cookie}" \
#   --header 'Content-Type: application/json' \
#   --request POST \
#   --url "${baseurl}/logout"
