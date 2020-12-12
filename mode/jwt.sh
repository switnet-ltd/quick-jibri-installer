#!/bin/bash
# JWT Mode Setup
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
MEET_CONF="/etc/jitsi/meet/$DOMAIN-config.js"
APP_ID="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 16 | head -n1)"
SECRET_APP="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 64 | head -n1)"
echo $APP_ID && echo $SECRET_APP

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
sed -i "s|c2s_require_encryption = true|c2s_require_encryption = false|" /etc/prosody/prosody.cfg.lua
sed -i "/app_secret/a \ \ \ \ \ \ \ \ asap_accepted_issuers = { \"$APP_ID\" }" /etc/prosody/conf.d/$DOMAIN.cfg.lua
sed -i "/app_secret/a \ \ \ \ \ \ \ \ asap_accepted_audiences = { \"$APP_ID\" }" /etc/prosody/conf.d/$DOMAIN.cfg.lua

#allow_empty_token = true

sed -i "s|// anonymousdomain: 'guest.example.com'|anonymousdomain: \'guest.$DOMAIN\'|" $MEET_CONF

echo -e "\nUse the following for your App (e.g. Rocket.Chat):\n"
pyjwt3 --key="$SECRET_APP" \
    encode \
    group="Rocket.Chat" \
    aud="$APP_ID" \
    iss="$APP_ID" \
    sub="$DOMAIN" \
    room="*" \
    algorithm="HS256"
