#!/bin/bash
# Grafana Installer for Jitsi Meet
#
# Based on:
# - https://community.jitsi.org/t/38696
# by Igor Kerstges
# - https://grafana.com/grafana/dashboards/11969
# by "mephisto"
#
# Igor Kerstges © - 2021
# SwITNet Ltd © - 2022, https://switnet.net/
#
# GPLv3 or later.

while getopts m: option
do
	case "${option}"
	in
		m) MODE=${OPTARG};;
		\?) echo "Usage: sudo bash ./$0 [-m debug]" && exit;;
	esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

clear
echo '
########################################################################
                      Grafana Dashboard addon
########################################################################
                    by Software, IT & Networks Ltd
'
run_service() {
systemctl enable "$1"
systemctl restart "$1"
systemctl status "$1"
}
MAIN_TEL="/etc/telegraf/telegraf.conf"
TEL_JIT="/etc/telegraf/telegraf.d/jitsi.conf"
GRAFANA_INI="/etc/grafana/grafana.ini"
DOMAIN="$(find /etc/prosody/conf.d/ -name \*.lua|awk -F'.cfg' '!/localhost/{print $1}'|xargs basename)"
WS_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
GRAFANA_PASS="$(tr -dc "a-zA-Z0-9#_*=" < /dev/urandom | fold -w 14 | head -n1)"

# Min requirements
apt-get update && \
apt-get install -y gnupg2 \
                   curl \
                   wget \
                   jq

echo "
# Setup InfluxDB Packages
"
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
apt-get update && apt-get install influxdb -y
run_service influxdb

echo "
#  Setup Grafana Packages
"
curl -s https://packages.grafana.com/gpg.key | sudo apt-key add -
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
apt-get update && apt-get install grafana -y
run_service grafana-server

echo "
# Setup Telegraf Packages
"
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
apt-get update && apt-get install telegraf -y
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

run_service telegraf

echo -n "\n# Setup videobridge  options\n"
echo '
# extra options to pass to the JVB daemon
JVB_OPTS="--apis=rest,xmpp"' >>  /etc/jitsi/videobridge/config
sed -i "s|TRANSPORT=muc|TRANSPORT=muc,colibri|" /etc/jitsi/videobridge/sip-communicator.properties
systemctl restart jitsi-videobridge2

echo -e "\n# Setup Grafana nginx domain\n"
sed -i "s|;protocol =.*|protocol = http|" $GRAFANA_INI
sed -i "s|;http_addr =.*|http_addr = localhost|" $GRAFANA_INI
sed -i "s|;http_port =.*|http_port = 3000|" $GRAFANA_INI
sed -i "s|;domain =.*|domain = $DOMAIN|" $GRAFANA_INI
sed -i "s|;enforce_domain =.*|enforce_domain = false|" $GRAFANA_INI
sed -i "s|;root_url =.*|root_url = http://$DOMAIN:3000/grafana/|" $GRAFANA_INI
sed -i "s|;serve_from_sub_path =.*|serve_from_sub_path = true|" $GRAFANA_INI
sed -i "s|;allow_sign_up =.*|allow_sign_up = false|" $GRAFANA_INI

systemctl restart grafana-server
echo "Waiting for Grafana to load..."
secs=$((10))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done

if [ -f "$WS_CONF" ]; then
    sed -i "/# ensure all static content can always be found first/i \ \ \ \ location \~ \^\/(grafana\/|grafana\/login) {" "$WS_CONF"
    sed -i "/# ensure all static content can always be found first/i \ \ \ \ \ \ \ \ proxy_pass http:\/\/localhost:3000;" "$WS_CONF"
    sed -i "/# ensure all static content can always be found first/i \ \ \ \ }" "$WS_CONF"
    sed -i "/# ensure all static content can always be found first/i \\\n" "$WS_CONF"
    systemctl restart nginx
else
    echo "No app configuration done to server file"
fi

echo "
# Setup Grafana credentials.
"
curl -s -k -u "admin:admin" -X \
PUT -H "Content-Type: application/json;charset=UTF-8" -d \
"{
  \"oldPassword\": \"admin\",
  \"newPassword\": \"$GRAFANA_PASS\",
  \"confirmNew\": \"$GRAFANA_PASS\"
}" http://localhost:3000/api/user/password; echo ""

echo "
# Create InfluxDB datasource
"
curl -s -k -u "admin:$GRAFANA_PASS" -X \
POST -H 'Content-Type: application/json;charset=UTF-8' -d \
'{
    "name": "InfluxDB",
    "type": "influxdb",
    "url": "http://localhost:8086",
    "access": "proxy",
    "isDefault": true,
    "database": "jitsi"
}' http://localhost:3000/api/datasources; echo ""

echo "
# Add Grafana Dashboard
"
grafana_host="http://localhost:3000"
grafana_cred="admin:$GRAFANA_PASS"
grafana_datasource="InfluxDB"
ds=(11969);
for d in "${ds[@]}"; do
  echo "Processing $d: "
  j="$(curl -s -k -u "$grafana_cred" "$grafana_host"/api/gnet/dashboards/"$d" | jq .json)"
  curl -s -k -u "$grafana_cred" -XPOST -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{
    \"dashboard\": $j,
    \"overwrite\": true,
    \"inputs\": [{
        \"name\": \"DS_INFLUXDB\",
        \"type\": \"datasource\",
        \"pluginId\": \"influxdb\",
        \"value\": \"$grafana_datasource\"
        }]
    }" $grafana_host/api/dashboards/import; echo ""
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
