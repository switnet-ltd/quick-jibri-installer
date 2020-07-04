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

while getopts m: option
do
	case "${option}"
	in
		m) MODE=${OPTARG};;
		\?) echo "Usage: sudo ./grafana.sh [-m debug]" && exit;;
	esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

MAIN_TEL="/etc/telegraf/telegraf.conf"
TEL_JIT="/etc/telegraf/telegraf.d/jitsi.conf"
GRAFANA_INI="/etc/grafana/grafana.ini"
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
WS_CONF="/etc/nginx/sites-enabled/$DOMAIN.conf"
GRAFANA_PASS="$(tr -dc "a-zA-Z0-9#_*" < /dev/urandom | fold -w 14 | head -n1)"

# Min requirements
apt update && apt install -y gnupg2 curl wget jq

echo "
# Setup InfluxDB Packages
"
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
apt update && apt install influxdb -y
systemctl enable influxdb
systemctl status influxdb

echo "
#  Setup Grafana Packages
"
curl -s https://packages.grafana.com/gpg.key | sudo apt-key add -
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
apt update && apt install grafana -y
systemctl enable grafana-server
systemctl status grafana-server

echo "
# Setup Telegraf Packages
"
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
apt update && apt install telegraf -y
mv /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.original

echo "
# Setup Telegraf config files
"
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

systemctl enable telegraf
systemctl restart telegraf
systemctl status telegraf

echo "
# Setup videobridge  options
"
sed -i "s|JVB_OPTS=\"--apis.*|JVB_OPTS=\"--apis=rest,xmpp\"|" /etc/jitsi/videobridge/config
sed -i "s|TRANSPORT=muc|TRANSPORT=muc,colibri|" /etc/jitsi/videobridge/sip-communicator.properties
systemctl restart jitsi-videobridge2

echo "
# Setup Grafana nginx domain
"
sed -i "s|;protocol =.*|protocol = http|" $GRAFANA_INI
sed -i "s|;http_addr =.*|http_addr = localhost|" $GRAFANA_INI
sed -i "s|;http_port =.*|http_port = 3000|" $GRAFANA_INI
sed -i "s|;domain =.*|domain = $DOMAIN|" $GRAFANA_INI
sed -i "s|;enforce_domain =.*|enforce_domain = false|" $GRAFANA_INI
sed -i "s|;root_url =.*|root_url = http://$DOMAIN:3000/grafana/|" $GRAFANA_INI
sed -i "s|;serve_from_sub_path =.*|serve_from_sub_path = true|" $GRAFANA_INI
systemctl restart grafana-server

if [ -f $WS_CONF ]; then
	sed -i "/Anything that didn't match above/i \ \ \ \ location \~ \^\/(grafana\/|grafana\/login) {" $WS_CONF
	sed -i "/Anything that didn't match above/i \ \ \ \ \ \ \ \ proxy_pass http:\/\/localhost:3000;" $WS_CONF
	sed -i "/Anything that didn't match above/i \ \ \ \ }" $WS_CONF
	sed -i "/Anything that didn't match above/i \\\n" $WS_CONF
	systemctl restart nginx
else
	echo "No app configuration done to server file, please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi

echo "
# Setup Grafana credentials.
"
curl -X PUT -H "Content-Type: application/json" -d "{
  \"oldPassword\": \"admin\",
  \"newPassword\": \"$GRAFANA_PASS\",
  \"confirmNew\": \"$GRAFANA_PASS\"
}" http://admin:admin@localhost:3000/grafana/api/user/password

echo "
# Create InfluxDB datasource
"
curl -X \
POST -H 'Content-Type: application/json;charset=UTF-8' -d \
'{
	"name":"InfluxDB",
	"type":"influxdb",
	"url":"http://localhost:8086",
	"access":"proxy",
	"isDefault":true,
	"database":"jitsi"
}' http://admin:$GRAFANA_PASS@localhost:3000/grafana/api/datasources

echo "
# Add Grafana Dashboard
"
grafana_host="http://localhost:3000/grafana"
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
Go check:

>>    http://$DOMAIN/grafana/

(emphasis on the trailing \"/\") to review configuration and dashboards.

User: admin
Password: $GRAFANA_PASS

Please save it somewhere safe.
"
read -n 1 -s -r -p "Press any key to continue..."$'\n'
