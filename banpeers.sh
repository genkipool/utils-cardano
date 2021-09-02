#!/bin/bash

WORKDIR="DIR_FILE_ENV_CNTOOLS"

FILEMONITOR="NAME_FILE_MONITOR"
FILELOG="NAME_FILE_LOG"
FILEPCAP="NAME_FILE_PCAP"

IFACE="NAME_INTERFACE"

source "$WORKDIR/env"

getPeers=$(lsof -Pnl +M | grep ESTABLISHED | awk -v pid="${CNODE_PID}" -v port=":${CNODE_PORT}->" '$2 == pid && $9 ~ port' | awk -F "->" '{print $2}' | awk -F ":" '{print $1}')
getCountPeers=$(lsof -Pnl +M | grep ESTABLISHED | awk -v pid="${CNODE_PID}" -v port=":${CNODE_PORT}->" '$2 == pid && $9 ~ port' | awk -F "->" '{print $2}' | awk -F ":" '{print $1}' | wc -l)

echo "cardano_node_peers_in $getCountPeers" > $FILEMONITOR

declare -A dict_ip_peers
for ip in ${getPeers[@]}
  do
    if [ "${dict_ip_peers[$ip]}" ]; then
       dict_ip_peers["${ip}"]=$((${dict_ip_peers[${ip}]} + 1 ))
       if [ "${dict_ip_peers[$ip]}" -gt 10 ]; then
          t="$(date +%Y_%m_%d_%H_%M_%S)"
          sudo tcpdump -G 60 -W 1 -w "${FILEPCAP}_${t}.pcapng" -i $IFACE port ${CNODE_PORT}
          sudo fail2ban-client set cardano banip $ip
          sudo ss -K dst $ip
          t="${t:0:10} ${t:11}"
          echo { \"IP\":\"$ip\", \"count\":${dict_ip_peers[${ip}]}, \"time\":\"${t//_/:}\" } >> $FILELOG
       fi
    else
       dict_ip_peers["${ip}"]=1
    fi
  done

