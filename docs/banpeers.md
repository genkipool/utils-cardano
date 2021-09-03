# Description

- Protects against DOS attacks Identifying which IP address tries to establish more than 10 TCP sessions with the Cardano node port, blocking for a day and eliminating the sessions already established by said IP.
- Gets the number of peers_in with the Cardano node and saves them to a file to send the information to Grafana.
- When it identifies the attack, it captures traffic with tcpdump for one minute and saves it in a .pcap file.
- It records in a log file the blocked IPs that have tried to attack the Cardano node.

# Requirements

- Fail2ban
- Prometheus exporters
- Grafana
- Tcpdump
- ss
- cron

# Settings
## Fail2ban:

Install fail2ban


```
sudo apt-get update
sudo apt-get install fail2ban -y
```

Edit a config file that monitors Cardano port and logs.

```
nano sudo /etc/fail2ban/jail.d/cardano.conf
```

Add the following lines.

```
# service name
[cardano]
# turn on /off
enabled  = true
#Ignore IP
ignoreip = < subnet of your nodes > # e.g 192.168.100.0/24 
# ports to ban (numeric or text)
port     = <port node Cardano > # eg 8001
# filter file
filter   = cardano
# file to parse
logpath  = <dir logs cardano > # e.g /home/cardano/relay/logs/relay.log
# ban rule:
# 3 times in 3 minutes
maxretry = 5
findtime = 180
# ban for 1 day
bantime = 86400
```

Edit a config file that monitors Cardano port and logs.

```
sudo nano /etc/fail2ban/filter.d/cardano.conf
```

Add the following lines.

```
[Definition]

#Theses regex expressions capture nodes that are not on the latest fork and also
#nodes from other networks (testnets)

failregex = ^.*HardForkEncoderDisabledEra.*"address":"<HOST>:.*$
            ^.*version data mismatch.*"address":"<HOST>:.*$
            ^.*ErrorPolicySuspendPeer.*"address":"<HOST>:.*$
            ^.*"address":"<HOST>:.*version data mismatch.*$
            ^.*"address":"<HOST>:.*HardForkEncoderDisabledEra.*$
```

Restart fail2ban

```
sudo systemctl restart fail2ban
```

## Prometheus exporters

Install Prometheus exporters

```
sudo apt-get install -y prometheus-node-exporter
```

Edit file and add logs directory

```
sudo  nano /etc/default/prometheus-node-exporter
```

Add the following lines. In the ip port and log directory parameters we will use the previous examples, replace these parameters with yours.

```
ARGS="--web.listen-address=192.168.100.1:8001 --collector.textfile.directory= /home/cardano/relay/monitor --collector.textfile"
```

Restart Prometheus exporters

```
sudo systemctl restart prometheus-node-exporter.service 
```

## Grafana

Install Grafana

```
sudo apt-get install -y grafana
```

Create query

```
cardano_node_peers_in{instance="192.168.100.1:9100"}
```

## banpeers.sh

save the banpeers.sh script in the directory where the env file of the cntools scripts is located

Edit environment variables

```
nano banpeers.sh
```
- **WORKDIR:** Put directory where the env file of the cn scripts is located.
- **FILEMONITOR:** Put the name and directory of the file where you want the number of peers_in to be saved to send the statistics to Grafana.
- **FILELOG:** Put the name and the directory where you want the log file to be saved.
- **FILEPCAP:** Put the name and the directory where you want the pcap traffic capture to be saved.

```
WORKDIR="/home/genki_relay_1/cardano-my-node/relay_1"

FILEMONITOR="$WORKDIR/genkiStats/banpeers.prom"
FILELOG="$WORKDIR/logs/banpeers.log"
FILEPCAP="$WORKDIR/genkiStats/banpeer"
```

add execute permissions

```
chmod +x banpeers.sh
```

## Cron

Edit file cron

```
crontab -e
```

Add the following lines.

```
* * * * * /home/cardano/relay/scripts/cntools/banpeers.sh
```
