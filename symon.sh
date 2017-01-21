#!/bin/sh

readonly now=$(date +%s)
readonly prefix=/var/collectd/$(hostname)

rrdtool xport \
  --start 'end-1h' \
  --end "${now}" \
  --showtime \
  --json \
  "DEF:interrupt=${prefix}/cpu/percent-interrupt.rrd:value:AVERAGE" \
  "DEF:nice=${prefix}/cpu/percent-nice.rrd:value:AVERAGE" \
  "DEF:system=${prefix}/cpu/percent-system.rrd:value:AVERAGE" \
  "DEF:user=${prefix}/cpu/percent-user.rrd:value:AVERAGE" \
  'XPORT:interrupt:Interrupt' \
  'XPORT:nice:Nice' \
  'XPORT:system:System' \
  'XPORT:user:User' \
  >/var/www/symon/cpu.json

rrdtool xport \
  --start 'end-1h' \
  --end "${now}" \
  --showtime \
  --json \
  "DEF:read=${prefix}/disk-sd0/disk_octets.rrd:read:AVERAGE" \
  "DEF:write=${prefix}/disk-sd0/disk_octets.rrd:write:AVERAGE" \
  'XPORT:read:Read' \
  'XPORT:write:Write' \
  >/var/www/symon/disk-sd0.json

for interface in pppoe0 tun0 tun1; do
  rrdtool xport \
    --start 'end-1h' \
    --end "${now}" \
    --showtime \
    --json \
    "DEF:rx_errors=${prefix}/interface-${interface}/if_errors.rrd:rx:MAX" \
    "DEF:rx_octets=${prefix}/interface-${interface}/if_octets.rrd:rx:AVERAGE" \
    "DEF:tx_errors=${prefix}/interface-${interface}/if_errors.rrd:tx:MAX" \
    "DEF:tx_octets=${prefix}/interface-${interface}/if_octets.rrd:tx:AVERAGE" \
    'XPORT:rx_errors:RX Errors' \
    'XPORT:rx_octets:RX Octets' \
    'XPORT:tx_errors:TX Errors' \
    'XPORT:tx_octets:TX Octets' \
    >/var/www/symon/interface-${interface}.json
done

rrdtool xport \
  --start 'end-1h' \
  --end "${now}" \
  --showtime \
  --json \
  "DEF:shortterm=${prefix}/load/load.rrd:shortterm:AVERAGE" \
  "DEF:midterm=${prefix}/load/load.rrd:midterm:AVERAGE" \
  "DEF:longterm=${prefix}/load/load.rrd:longterm:AVERAGE" \
  'XPORT:shortterm:1 min' \
  'XPORT:midterm:5 min' \
  'XPORT:longterm:15 min' \
  >/var/www/symon/load.json

rrdtool xport \
  --start 'end-1h' \
  --end "${now}" \
  --showtime \
  --json \
  "DEF:states_current=${prefix}/pf/pf_states-current.rrd:value:AVERAGE" \
  'XPORT:states_current:State Table Entries' \
  >/var/www/symon/pf.json

rrdtool xport \
  --start 'end-1h' \
  --end "${now}" \
  --showtime \
  --json \
  "DEF:isp_average=${prefix}/ping/ping-81.187.81.187.rrd:value:AVERAGE" \
  "DEF:isp_min=${prefix}/ping/ping-81.187.81.187.rrd:value:MIN:step=60" \
  "DEF:isp_max=${prefix}/ping/ping-81.187.81.187.rrd:value:MAX:step=60" \
  "DEF:vpn_average=${prefix}/ping/ping-10.4.0.1.rrd:value:AVERAGE" \
  "DEF:vpn_min=${prefix}/ping/ping-10.4.0.1.rrd:value:MIN:step=60" \
  "DEF:vpn_max=${prefix}/ping/ping-10.4.0.1.rrd:value:MAX:step=60" \
  'XPORT:isp_average:ISP Average' \
  'XPORT:isp_min:ISP Min' \
  'XPORT:isp_max:ISP Max' \
  'XPORT:vpn_average:VPN Average' \
  'XPORT:vpn_min:VPN Min' \
  'XPORT:vpn_max:VPN Max' \
  >/var/www/symon/ping.json

#rrdtool graph /var/www/symon/pf.png \
#  --start 'end-1h' \
#  --end "${now}" \
#  --title 'pf' \
#  --width 600 \
#  --height 150 \
#  --lazy \
#  'DEF:states_entries=/var/db/symon/pf.rrd:states_entries:AVERAGE' \
#  'AREA:states_entries#0000FF:states_entries\l'
