#!/bin/bash
# JWT Mode Setup
# SwITNet Ltd © - 2022, https://switnet.net/
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

DOMAIN="$(find /etc/prosody/conf.d/ -name \*.lua|awk -F'.cfg' '!/localhost/{print $1}'|xargs basename)"
MEET_CONF="/etc/jitsi/meet/$DOMAIN-config.js"
JICOFO_SIP="/etc/jitsi/jicofo/sip-communicator.properties"
PROSODY_FILE="/etc/prosody/conf.d/$DOMAIN.cfg.lua"
PROSODY_SYS="/etc/prosody/prosody.cfg.lua"
APP_ID="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 16 | head -n1)"
SECRET_APP="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 64 | head -n1)"
SRP_STR="$(grep -n "VirtualHost \"$DOMAIN\"" "$PROSODY_FILE" | head -n1 | cut -d ":" -f1)"
SRP_END="$((SRP_STR + 10))"

## Required  openssl for Focal 20.04
if [ "$(lsb_release -sc)" = "focal" ]; then
echo "deb http://ppa.launchpad.net/rael-gc/rvm/ubuntu focal main" | \
sudo tee /etc/apt/sources.list.d/rvm.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F4E3FBBE
apt-get update
fi

apt-get -y install \
                    lua5.2 \
                    liblua5.2 \
                    luarocks \
                    libssl1.0-dev \
                    python3-jwt

luarocks install basexx
luarocks install luacrypto
luarocks install lua-cjson 2.1.0-1

echo "set jitsi-meet-tokens/appid string $APP_ID" | debconf-set-selections
echo "set jitsi-meet-tokens/appsecret password $SECRET_APP" | debconf-set-selections

apt-get install -y jitsi-meet-tokens

#Setting up
sed -i "s|c2s_require_encryption = true|c2s_require_encryption = false|" "$PROSODY_SYS"
#-
sed -i "$SRP_STR,$SRP_END{s|authentication = \"jitsi-anonymous\"|authentication = \"token\"|}" "$PROSODY_FILE"
sed -i "s|--app_id=\"example_app_id\"|app_id=\"$APP_ID\"|" "$PROSODY_FILE"
sed -i "s|--app_secret=\"example_app_secret\"|app_secret=\"$SECRET_APP\"|" "$PROSODY_FILE"
sed -i "/app_secret/a \\\\" "$PROSODY_FILE"
sed -i "/app_secret/a \ \ \ \ allow_empty_token = false" "$PROSODY_FILE"
sed -i "/app_secret/a \\\\" "$PROSODY_FILE"
sed -i "/app_secret/a \ \ \ \ asap_accepted_issuers = { \"$APP_ID\" }" "$PROSODY_FILE"
sed -i "/app_secret/a \ \ \ \ asap_accepted_audiences = { \"$APP_ID\", \"RocketChat\" }" "$PROSODY_FILE"
sed -i "/app_secret/a \\\\" "$PROSODY_FILE"
sed -i "s|--allow_empty_token =.*|allow_empty_token = false|" "$PROSODY_FILE"
sed -i 's|--"token_verification"|"token_verification"|' "$PROSODY_FILE"

#Request auth
sed -i "s|#org.jitsi.jicofo.auth.URL=EXT_JWT:|org.jitsi.jicofo.auth.URL=EXT_JWT:|" "$JICOFO_SIP"
sed -i "s|// anonymousdomain: 'guest.example.com'|anonymousdomain: \'guest.$DOMAIN\'|" "$MEET_CONF"

#Enable jibri recording
cat  << REC-JIBRI >> "$PROSODY_FILE"

VirtualHost "recorder.$DOMAIN"
  modules_enabled = {
    "ping";
  }
  authentication = "internal_hashed"

REC-JIBRI

#Setup guests and lobby
cat << P_SR >> "$PROSODY_FILE"
-- #Change back lobby - https://community.jitsi.org/t/64769/136
VirtualHost "guest.$DOMAIN"
    authentication = "token"
    allow_empty_token = true
    c2s_require_encryption = false
    speakerstats_component = "speakerstats.$DOMAIN"
    app_id="$APP_ID";
    app_secret="$SECRET_APP";

    modules_enabled = {
      "speakerstats";
--      "conference_duration";
    }
P_SR

echo -e "\nUse the following for your App (e.g. Rocket.Chat):\n"
echo -e "\nAPP_ID: $APP_ID" && \
echo -e "SECRET_APP: $SECRET_APP\n"

echo -e "You can test JWT authentication with the following token:\n"
pyjwt3 --key="$SECRET_APP" \
    encode \
    group="Rocket.Chat" \
    aud="$APP_ID" \
    iss="$APP_ID" \
    sub="$DOMAIN" \
    room="*" \
    algorithm="HS256"

read -n 1 -s -r -p $'\n'"Press any key to continue..."$'\n'
