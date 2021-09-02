# Description.

Scripts to use with Cardano nodes

## crearStakePool.sh
This script performs the following actions:
- Install all the necessary libraries to run a Cardano node.
- Register a Cardano pool.
- Configure the files needed to run Cardano nodes.
- It allows to carry out transactions of ADAs and tokens.
- Allows to create tokens and NFTC

## banpeers.sh
This script performs the following actions:
- Protects against DOS attacks Identifying which IP address tries to establish more than 10 TCP sessions with the Cardano node port, blocking for a day and eliminating the sessions already established by said IP.
- Gets the number of peers_in with the Cardano node and saves them to a file to send the information to Grafana.
- When it identifies the attack, it captures traffic with tcpdump for one minute and saves it in a .pcap file.
- It records in a log file the blocked IPs that have tried to attack the Cardano node.

## simWinAda.py
Script that roughly calculates the profits that a delegator can obtain when staking.

