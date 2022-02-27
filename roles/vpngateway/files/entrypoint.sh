#!/bin/sh

readonly interface=wg0

docker_network="$(ip -o addr show dev eth0 | awk '$3 == "inet" {print $4}')"
echo "docker_network=${docker_network}" >&2
# docker_network_rule=$([ ! -z "$docker_network" ] && echo "! -d $docker_network" || echo "")
# iptables -I OUTPUT ! -o "${interface}" -m mark ! --mark $(wg show $interface fwmark) -m addrtype ! --dst-type LOCAL "${docker_network_rule}" -j REJECT

docker_network6="$(ip -o addr show dev eth0 | awk '$3 == "inet6" {print $4}')"
if [ -n "${docker6_network}" ]; then
  # docker6_network_rule=$([ ! -z "$docker6_network" ] && echo "! -d $docker6_network" || echo "")
  # ip6tables -I OUTPUT ! -o "${interface}" -m mark ! --mark $(wg show $interface fwmark) -m addrtype ! --dst-type LOCAL "${docker6_network_rule}" -j REJECT
  :
fi

wg-quick up "${interface}"

shutdown() {
  wg-quick down "${interface}"
  exit 0
}
trap shutdown INT QUIT TERM

while true; do
  sleep 86400
done
