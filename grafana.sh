#!/bin/bash
# Grafana Installer
# Based on:
# https://community.jitsi.org/t/how-to-to-setup-grafana-dashboards-to-monitor-jitsi-my-comprehensive-tutorial-for-the-beginner/
# by Woodworker_Life
# Woodworker_Life © - 2020
# Jitsi Metrics - Grafana dashboard by mephisto
# https://grafana.com/grafana/dashboards/11969
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.

MAIN_TEL="/etc/telegraf/telegraf.conf"
TEL_JIT="/etc/telegraf/telegraf.d/jitsi.conf"
GRAFANA_PASS="$(tr -dc "a-zA-Z0-9#_*=" < /dev/urandom | fold -w 14 | head -n1)"
PUBLIC_IP="$(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short)"

# Min requirements
apt update && apt install -y gnupg2 curl wget jq

# InfluxDB Repo
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
apt update && apt install influxdb -y
systemctl enable --now influxdb
systemctl status influxdb

# Grafana Repo
curl -s https://packages.grafana.com/gpg.key | sudo apt-key add -
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
apt update && apt install grafana -y
systemctl enable --now grafana-server
systemctl status grafana-server

# Telegraf Repo
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
apt update && apt install telegraf -y
mv /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.original

cat << TELEGRAF > $MAIN_TEL
[global_tags]

###############################################################################
#                                  GLOBAL                                     #
###############################################################################

[agent]
    interval = "10s"
    debug = false
    hostname = "localhost"
    round_interval = true
    flush_interval = "10s"
    flush_jitter = "0s"
    collection_jitter = "0s"
    metric_batch_size = 1000
    metric_buffer_limit = 10000
    quiet = false
    logfile = ""
    omit_hostname = false

TELEGRAF

cat << JITSI_TELEGRAF > $TEL_JIT
###############################################################################
#                                  INPUTS                                     #
###############################################################################

[[inputs.http]]
    name_override = "jitsi_stats"
    urls = [
      "http://localhost:8080/colibri/stats"
    ]

    data_format = "json"

###############################################################################
#                                  OUTPUTS                                    #
###############################################################################

[[outputs.influxdb]]
    urls = ["http://localhost:8086"]
    database = "jitsi"
    timeout = "0s"
    retention_policy = ""

JITSI_TELEGRAF

systemctl enable --now telegraf
systemctl status telegraf

# Setup videobridge  options
sed -i "s|JVB_OPTS=\"--apis.*|JVB_OPTS=\"--apis=rest,xmpp\"|" /etc/jitsi/videobridge/config
sed -i "s|TRANSPORT=muc|TRANSPORT=muc,colibri|" /etc/jitsi/videobridge/sip-communicator.properties
systemctl restart jitsi-videobridge2

# Grafana Setup
# Reset Grafana admin password
curl -X PUT -H "Content-Type: application/json" -d '{
  "oldPassword": "admin",
  "newPassword": "$GRAFANA_PASS",
  "confirmNew": "$GRAFANA_PASS"
}' http://admin:admin@localhost:3000/api/user/password

# Create InfluxDB datasource
curl "http://admin:$GRAFANA_PASS@localhost:3000/api/datasources" -X \
POST -H 'Content-Type: application/json;charset=UTF-8' \
--data-binary \
'{"name":"InfluxDB","type":"influxdb","url":"http://localhost:8086","access":"proxy","isDefault":true,"database":"jitsi"}'

# Add Grafana Dashboard
grafana_host="http://localhost:3000"
grafana_cred="admin:$GRAFANA_PASS"
grafana_datasource="InfluxDB"
ds=(11969);
for d in "${ds[@]}"; do
  echo -n "Processing $d: "
  j=$(curl -s -k -u "$grafana_cred" $grafana_host/api/gnet/dashboards/$d | jq .json)
  curl -s -k -u "$grafana_cred" -XPOST -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"dashboard\":$j,\"overwrite\":true, \
        \"inputs\":[{\"name\":\"DS_INFLUXDB\",\"type\":\"datasource\", \
        \"pluginId\":\"influxdb\",\"value\":\"$grafana_datasource\"}]}" \
    $grafana_host/api/dashboards/import; echo ""
done

echo "
Go check on http://$PUBLIC_IP:3000 to review configuration and dashboards.
"
