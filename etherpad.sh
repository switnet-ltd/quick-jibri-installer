#!/bin/bash
# Etherpad Installer for Jitsi Meet
# SwITNet Ltd © - 2021, https://switnet.net/
#
# GPLv3 or later.

while getopts m: option
do
    case "${option}"
    in
        m) MODE=${OPTARG};;
        \?) echo "Usage: sudo ./etherpad.sh [-m debug]" && exit;;
    esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

if ! [ $(id -u) = 0 ]; then
    echo "You need to be root or have sudo privileges!"
    exit 0
fi

clear
echo '
########################################################################
                         Etherpad Docker addon
########################################################################
                    by Software, IT & Networks Ltd
'

check_apt_policy() {
apt-cache policy 2>/dev/null| \
grep http | \
grep $1 | \
awk '{print $3}' | \
head -n 1 | \
cut -d "/" -f2
}
install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo " $1 is installed, skipping..."
else
    echo -e "\n---- Installing $1 ----"
    apt-get -yq2 install $1
fi
}
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
MEET_CONF="/etc/jitsi/meet/$DOMAIN-config.js"
WS_CONF="/etc/nginx/sites-enabled/$DOMAIN.conf"
PSGVER="$(apt-cache madison postgresql | head -n1 | awk '{print $3}' | cut -d "+" -f1)"
NODE_JS_REPO="$(check_apt_policy node_10)"
ETHERPAD_USER="etherpad-lite"
ETHERPAD_HOME="/opt/$ETHERPAD_USER"
ETHERPAD_DB_USER="meetpad"
ETHERPAD_DB_NAME="etherpad"
ETHERPAD_DB_PASS="$(tr -dc "a-zA-Z0-9#*=" < /dev/urandom | fold -w 10 | head -n1)"
ETHERPAD_SYSTEMD="/etc/systemd/system/etherpad-lite.service"

# NodeJS
echo "Addin NodeJS repo..."

if [ "$NODE_JS_REPO" = "main" ]; then
    echo "NodeJS repository already installed"
else
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
    apt-get update
fi

read -p "Set your etherpad docker admin password: " -r ETHERPAD_ADMIN_PASS

# Install required packages
install_ifnot jq
install_ifnot nodejs
install_ifnot postgresql-$PSGVER

# Link LE certs on Etherpad directory
#chmod 755 /etc/letsencrypt/live
#ln -s /etc/letsencrypt/live/$DOMAIN $ETHERPAD_HOME/

# Create DB
echo -e "> Creating postgresql database for etherpad...\n"
sudo -u postgres psql <<DB
CREATE DATABASE ${ETHERPAD_DB_NAME};
CREATE USER ${ETHERPAD_DB_USER} WITH ENCRYPTED PASSWORD '${ETHERPAD_DB_PASS}';
GRANT ALL PRIVILEGES ON DATABASE ${ETHERPAD_DB_NAME} TO ${ETHERPAD_DB_USER};
DB

echo "  -- Your etherpad db password is: $ETHERPAD_DB_PASS"
echo -e "     Please save it somewhere safe."

#Set system users
adduser --system --home=${ETHERPAD_HOME} --group ${ETHERPAD_USER}
sudo -u $ETHERPAD_USER git clone -b master https://github.com/ether/etherpad-lite.git $ETHERPAD_HOME/

  #Issue: https://github.com/ether/etherpad-lite/issues/3460
  cat <<< "$(jq  'del(.devDependencies)'< $ETHERPAD_HOME/src/package.json)" > $ETHERPAD_HOME/src/package.json

bash $ETHERPAD_HOME/bin/installDeps.sh

cp $ETHERPAD_HOME/settings.json $ETHERPAD_HOME/settings.json.backup

cat << SETTINGS_JSON > $ETHERPAD_HOME/settings.json
{
 "title": "Conference Etherpad",
  "favicon": "favicon.ico",
  "skinName": "colibris",
  "ip": "0.0.0.0",
  "port": 9001,
  "showSettingsInAdminPage": true,
//  "ssl" : {
//            "key"  : "$ETHERPAD_HOME/$DOMAIN/privkey.pem",
//            "cert" : "$ETHERPAD_HOME/$DOMAIN/fullchain.pem",
//            "ca"   : "$ETHERPAD_HOME/$DOMAIN/chain.pem"
//          },
  "dbType" : "postgres",
  "dbSettings" : {
    "user"    : "$ETHERPAD_DB_USER",
    "host"    : "localhost",
    "password": "$ETHERPAD_DB_PASS",
    "database": "$ETHERPAD_DB_NAME",
    "charset" : "utf8mb4"
  },
  "defaultPadText" : "Welcome to Etherpad!\n\nThis pad text is synchronized as you type, so that everyone viewing this page sees the same text. This allows you to collaborate seamlessly on documents!\n\nGet involved with Etherpad at https:\/\/etherpad.org\n",
  "users": {
    "admin": {
      // 1) "password" can be replaced with "hash" if you install ep_hash_auth
      // 2) please note that if password is null, the user will not be created
      "password": "$ETHERPAD_ADMIN_PASS",
      "is_admin": true
    }
  }
}
SETTINGS_JSON

cat << SYSTEMD > $ETHERPAD_SYSTEMD
[Unit]
Description=Etherpad-lite, the collaborative editor.
After=syslog.target network.target

[Service]
Type=simple
User=$ETHERPAD_USER
Group=Group=$ETHERPAD_USER
WorkingDirectory=$ETHERPAD_HOME
Environment=NODE_ENV=production
ExecStart=$ETHERPAD_HOME/bin/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
SYSTEMD

#Systemd services
systemctl enable etherpad-lite
systemctl restart etherpad-lite

# Tune webserver for Jitsi App control
if [ $(grep -c "etherpad" $WS_CONF) != 0 ]; then
    echo "> Webserver seems configured, skipping..."
elif [ -f $WS_CONF ]; then
    echo "> Setting up webserver configuration file..."
    sed -i "/Anything that didn't match above/i \ \ \ \ location \^\~\ \/etherpad\/ {" $WS_CONF
    sed -i "/Anything that didn't match above/i \ \ \ \ \ \ \ \ proxy_pass http:\/\/localhost:9001\/;" $WS_CONF
    sed -i "/Anything that didn't match above/i \ \ \ \ \ \ \ \ proxy_set_header X-Forwarded-For \$remote_addr;" $WS_CONF
    sed -i "/Anything that didn't match above/i \ \ \ \ \ \ \ \ proxy_buffering off;" $WS_CONF
    sed -i "/Anything that didn't match above/i \ \ \ \ \ \ \ \ proxy_set_header       Host \$host;" $WS_CONF
    sed -i "/Anything that didn't match above/i \ \ \ \ }" $WS_CONF
    sed -i "/Anything that didn't match above/i \\\n" $WS_CONF
else
    echo "> No etherpad config done to server file, please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi
    
# Configure config.js
if [ $(grep -c "etherpad_base" $WS_CONF) != 0 ]; then
    echo -e "> $MEET_CONF seems configured, skipping...\n"
else
    echo -e "> Setting etherpad domain at $MEET_CONF...\n"
    sed -i "/ domain: '$DOMAIN'/a\ \ \ \ \ \ \ \ etherpad_base: \'https://$DOMAIN/etherpad/p/\'," $MEET_CONF
fi

echo "> Checking nginx configuration..."
nginx -t 2>/dev/null

if [ $? = 0 ]; then
    echo -e "  -- Docker configuration seems fine, enabling it."
    systemctl reload nginx
else
    echo "Please check your configuration, something may be wrong."
    echo "Will not try to enable etherpad nginx configuration, please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi
