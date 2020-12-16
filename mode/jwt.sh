#!/bin/bash
# JWT Mode Setup
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
MEET_CONF="/etc/jitsi/meet/$DOMAIN-config.js"
JICOFO_SIP="/etc/jitsi/jicofo/sip-communicator.properties"
PROSODY_FILE="/etc/prosody/conf.d/$DOMAIN.cfg.lua"
PROSODY_SYS="/etc/prosody/prosody.cfg.lua"
APP_ID="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 16 | head -n1)"
SECRET_APP="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 64 | head -n1)"

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
sed -i "s|c2s_require_encryption = true|c2s_require_encryption = false|" $PROSODY_SYS
sed -i "/app_secret/a \ \ \ \ \ \ \ \ asap_accepted_issuers = { \"$APP_ID\" }" $PROSODY_FILE
sed -i "/app_secret/a \ \ \ \ \ \ \ \ asap_accepted_audiences = { \"$APP_ID\", \"RocketChat\" }" $PROSODY_FILE
#allow_empty_token = true

#Request auth
sed -i "s|#org.jitsi.jicofo.auth.URL=EXT_JWT:|org.jitsi.jicofo.auth.URL=EXT_JWT:|" $JICOFO_SIP
sed -i "s|// anonymousdomain: 'guest.example.com'|anonymousdomain: \'guest.$DOMAIN\'|" $MEET_CONF

#Enable jibri recording
cat  << REC-JIBRI >> $PROSODY_FILE

VirtualHost "recorder.$DOMAIN"
  modules_enabled = {
    "ping";
  }
  authentication = "internal_plain"

REC-JIBRI

#Setup guests and lobby
cat << P_SR >> $PROSODY_FILE

VirtualHost "guest.$DOMAIN"
    authentication = "token"
    allow_empty_token = true
    c2s_require_encryption = false
    muc_lobby_whitelist = { "recorder.$DOMAIN", "auth.$DOMAIN" }
    speakerstats_component = "speakerstats.$DOMAIN"
    conference_duration_component = "conferenceduration.$DOMAIN"
    app_id="$APP_ID";
    app_secret="$SECRET_APP";

    modules_enabled = {
      "speakerstats";
      "conference_duration";
    }
P_SR

echo -e "\nUse the following for your App (e.g. Rocket.Chat):\n"
echo -e "\n$APP_ID" && \
echo -e "$SECRET_APP\n"

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
