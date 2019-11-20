#!/bin/bash
# Quick Jibri Installer - *buntu 16.04 (LTS) based systems.
# SwITNet Ltd © - 2019, https://switnet.net/
# GPLv3 or later.

# SYSTEM SETUP
JITSI_UNS_REPO=$(apt-cache policy | grep http | grep jitsi | grep unstable | awk '{print $3}' | head -n 1 | cut -d "/" -f 1)
CERTBOT_REPO=$(apt-cache policy | grep http | grep certbot | head -n 1 | awk '{print $2}' | cut -d "/" -f 4)
APACHE_2=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
NGINX=$(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed")
DIST=$(lsb_release -sc)
GOOGL_REPO="/etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list"

if [ $DIST = flidas ]; then
DIST="xenial"
fi
install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
	echo " $1 is installed, skipping..."
    else
    	echo -e "\n---- Installing $1 ----"
		apt -yqq install $1
fi
}
check_serv() {
if [ "$APACHE_2" -eq 1 ] || [ "$NGINX" -eq 1 ]; then
	echo "
Webserver already installed!
"
elif [ "$APACHE_2" -eq 1 ] && [ "$NGINX" -eq 0 ]; then

echo "
Apache webserver already installed!
"

else
	echo "
Installing nginx as webserver!
"
	install_ifnot nginx
fi
}
check_snd_driver() {
modprobe snd-aloop
echo "snd-aloop" >> /etc/modules
if [ "$(lsmod | grep snd_aloop | head -n 1 | cut -d " " -f1)" = "snd_aloop" ]; then
	echo "Audio driver seems ok."
else
	echo "Seems to be an issue with your audio driver, please fix this before continue."
	#exit
fi
}
update_certbot() {
	if [ "$CERTBOT_REPO" = "certbot" ]; then
	echo "
Cerbot repository already on the system!
Checking for updates...
"
	apt -qq update
	apt -yqq dist-upgrade
else
	echo "
Adding cerbot (formerly letsencrypt) PPA repository for latest updates
"
	echo "deb http://ppa.launchpad.net/certbot/certbot/ubuntu $DIST main" > /etc/apt/sources.list.d/certbot.list
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 75BCA694
	apt -qq update
	apt -yqq dist-upgrade
fi
}

clear
echo '
########################################################################
                    Welcome to Jitsi/Jibri Installer
########################################################################
                    by Software, IT & Networks Ltd
'

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

# Jitsi-Meet Repo
echo "Add Jitsi key"
if [ "$JITSI_UNS_REPO" = "unstable" ]; then
	echo "Jitsi unstable repository already installed"
else
	echo 'deb https://download.jitsi.org unstable/' > /etc/apt/sources.list.d/jitsi-unstable.list
	wget -qO -  https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
fi

# Requirements
echo "We'll start by installing system requirements this may take a while please be patient..."
apt update -yq2
apt dist-upgrade -yq2
apt -yqq install \
				bmon \
				curl \
				ffmpeg \
				git \
				htop \
				letsencrypt \
				linux-image-extra-virtual \
				unzip \
				wget
check_serv

echo "
#--------------------------------------------------
# Install Jitsi Framework
#--------------------------------------------------
"
apt -yqq install \
				jitsi-meet \
				jibri

echo "
#--------------------------------------------------
# Install NodeJS
#--------------------------------------------------
"
if [ "$(dpkg-query -W -f='${Status}' nodejs 2>/dev/null | grep -c "ok")" == "1" ]; then
		echo "Nodejs is installed, skipping..."
    else
		curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
		apt install -yqq nodejs
		echo "Installing nodejs esprima package..."
		npm install -g esprima
fi

if [ "$(npm list -g esprima 2>/dev/null | grep -c "empty")" == "1" ]; then
	echo "Installing nodejs esprima package..."
	npm install -g esprima
elif [ "$(npm list -g esprima 2>/dev/null | grep -c "esprima")" == "1" ]; then
	echo "Good. Esprima package is already installed"
fi

# ALSA - Loopback
echo "snd-aloop" | tee -a /etc/modules
check_snd_driver
CHD_VER=$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)
echo "# Installing Google Chrome / ChromeDriver"
if [ -f $GOOGL_REPO ]; then
echo "Google repository already set."
else
echo "Installing Google Chrome Stable"
	wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
	echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee $GOOGL_REPO
fi
apt -qq update
apt install -yqq google-chrome-stable
rm -rf /etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list

if [ -f /usr/local/bin/chromedriver ]; then
	echo "Chromedriver already installed."
else
	echo "Installing Chromedriver"
	wget https://chromedriver.storage.googleapis.com/$CHD_VER/chromedriver_linux64.zip -O /tmp/chromedriver_linux64.zip
	unzip /tmp/chromedriver_linux64.zip -d /usr/local/bin/
	chown root:root /usr/local/bin/chromedriver
	chmod 0755 /usr/local/bin/chromedriver
	rm -rf /tpm/chromedriver_linux64.zip
fi

echo "
Check Google Software Working...
"
/usr/bin/google-chrome --version
/usr/local/bin/chromedriver --version | awk '{print$1,$2}'

echo '
########################################################################
                    Starting Jibri configuration
########################################################################
'
# MEET / JIBRI SETUP
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
JB_AUTH_PASS_FILE=/var/JB_AUTH_PASS.txt
JB_REC_PASS_FILE=/var/JB_REC_PASS.txt
PROSODY_FILE=/etc/prosody/conf.d/$DOMAIN.cfg.lua
JICOFO_SIP=/etc/jitsi/jicofo/sip-communicator.properties
MEET_CONF=/etc/jitsi/meet/$DOMAIN-config.js
CONF_JSON=/etc/jitsi/jibri/config.json
DIR_RECORD=/tmp/recordings
REC_DIR=/home/jibri/finalize_recording.sh
JB_NAME="Jibri Sessions"
LE_RENEW_LOG="/var/log/letsencrypt/renew.log"
echo "## Setting up Jitsi Meet language ##
You can define your language by using a two letter code (ISO 639-1);
	English -> en
	Spanish -> es
	German -> de
	...

Jitsi Meet web interface will be set to use such language (if availabe).
"
read -p "Please set your language:"$'\n' -r LANG
read -p "Jibri internal.auth.$DOMAIN password: "$'\n' -sr JB_AUTH_PASS
read -p "Jibri recorder.$DOMAIN password: "$'\n' -sr JB_REC_PASS
read -p "Set sysadmin email: "$'\n' -r SYSADMIN_EMAIL
while [[ $ENABLE_DB != yes && $ENABLE_DB != no ]]
do
read -p "Do you want to setup the Dropbox feature now: (yes or no)"$'\n' -r ENABLE_DB
if [ $ENABLE_DB = no ]; then
	echo "Dropbox won't be enable"
elif [ $ENABLE_DB = yes ]; then
	read -p "Please set your Drobbox App key: "$'\n' -r DB_CID
fi
done
while [[ $ENABLE_SSL != yes && $ENABLE_SSL != no ]]
do
read -p "Do you want to setup LetsEncrypt with your domain: (yes or no)"$'\n' -r ENABLE_SSL
if [ $ENABLE_SSL = no ]; then
	echo "Please run letsencrypt.sh manually post-installation."
elif [ $ENABLE_SSL = yes ]; then
	echo "SSL will be enabled."
fi
done
#Jigasi
while [[ $ENABLE_TRANSCRIPT != yes && $ENABLE_TRANSCRIPT != no ]]
do
read -p "Do you want to setup Jigasi Transcription: (yes or no)"$'\n' -r ENABLE_TRANSCRIPT
if [ $ENABLE_TRANSCRIPT = no ]; then
	echo "Jigasi Transcription won't be enabled."
elif [ $ENABLE_TRANSCRIPT = yes ]; then
	echo "Jigasi Transcription will be enabled."
fi
done

echo "$JB_AUTH_PASS" > $JB_AUTH_PASS_FILE
chmod 600 $JB_AUTH_PASS_FILE
echo "$JB_REC_PASS" > $JB_REC_PASS_FILE
chmod 600 $JB_REC_PASS_FILE
JibriBrewery=JibriBrewery
INT_CONF=/usr/share/jitsi-meet/interface_config.js
WAN_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

ssl_wa() {
service $1 stop
	letsencrypt certonly --standalone --renew-by-default --agree-tos --email $5 -d $6
	sed -i "s|/etc/jitsi/meet/$3.crt|/etc/letsencrypt/live/$3/fullchain.pem|" $4
	sed -i "s|/etc/jitsi/meet/$3.key|/etc/letsencrypt/live/$3/privkey.pem|" $4
service $1 restart
	#Add cron
	crontab -l | { cat; echo "@weekly certbot renew --${2} > $LE_RENEW_LOG 2>&1 || mail -s 'LE SSL Errors' $SYSADMIN_EMAIL < $LE_RENEW_LOG"; } | crontab -
	crontab -l
}

enable_letsencrypt() {
if [ "$ENABLE_SSL" = "yes" ]; then
echo '
########################################################################
                    Starting LetsEncrypt configuration
########################################################################
'
#Disabled 'til fixed upstream
#bash /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

update_certbot

else
echo "SSL setup will be skipped."
fi
}

check_jibri() {
if [ "$(dpkg-query -W -f='${Status}' "jibri" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
	service jibri restart
	service jibri-icewm restart
	service jibri-xorg restart
else
	echo "Jibri service not installed"
fi
}

# Restarting services
restart_services() {
	service jitsi-videobridge restart
	service jicofo restart
	service prosody restart
	check_jibri
}

# Configure Jibri
## PROSODY
cat  << MUC-JIBRI >> $PROSODY_FILE

-- internal muc component, meant to enable pools of jibri and jigasi clients
Component "internal.auth.$DOMAIN" "muc"
    modules_enabled = {
      "ping";
    }
    storage = "null"
    muc_room_cache_size = 1000

MUC-JIBRI

cat  << REC-JIBRI >> $PROSODY_FILE

VirtualHost "recorder.$DOMAIN"
  modules_enabled = {
    "ping";
  }
  authentication = "internal_plain"

REC-JIBRI

### Prosody users
prosodyctl register jibri auth.$DOMAIN $JB_AUTH_PASS
prosodyctl register recorder recorder.$DOMAIN $JB_REC_PASS

## JICOFO
# /etc/jitsi/jicofo/sip-communicator.properties
cat  << BREWERY >> $JICOFO_SIP
#org.jitsi.jicofo.auth.URL=XMPP:$DOMAIN
org.jitsi.jicofo.jibri.BREWERY=$JibriBrewery@internal.auth.$DOMAIN
org.jitsi.jicofo.jibri.PENDING_TIMEOUT=90
#org.jitsi.jicofo.auth.DISABLE_AUTOLOGIN=true
BREWERY

# Jibri tweaks for /etc/jitsi/meet/$DOMAIN-config.js
sed -i "s|// anonymousdomain: 'guest.example.com'|anonymousdomain: \'guest.$DOMAIN\'|" $MEET_CONF
sed -i "s|conference.$DOMAIN|internal.auth.$DOMAIN|" $MEET_CONF
sed -i "s|// fileRecordingsEnabled: false,|fileRecordingsEnabled: true,| " $MEET_CONF
sed -i "s|// liveStreamingEnabled: false,|liveStreamingEnabled: true,\\
\\
    hiddenDomain: \'recorder.$DOMAIN\',|" $MEET_CONF

#Dropbox feature
if [ $ENABLE_DB = "yes" ]; then
DB_STR=$(grep -n "dropbox:" $MEET_CONF | cut -d ":" -f1)
DB_END=$((DB_STR + 10))
sed -i "$DB_STR,$DB_END{s|// dropbox: {|dropbox: {|}" $MEET_CONF
sed -i "$DB_STR,$DB_END{s|//     appKey: '<APP_KEY>'|appKey: \'$DB_CID\'|}" $MEET_CONF
sed -i "$DB_STR,$DB_END{s|// },|},|}" $MEET_CONF
fi

#LocalRecording
echo "# Enabling local recording (audio only)."
DI_STR=$(grep -n "deploymentInfo:" $MEET_CONF | cut -d ":" -f1)
DI_END=$((DI_STR + 6))
sed -i "$DI_STR,$DI_END{s|}|},|}" $MEET_CONF
LR_STR=$(grep -n "// Local Recording" $MEET_CONF | cut -d ":" -f1)
LR_END=$((LR_STR + 18))
sed -i "$LR_STR,$LR_END{s|// localRecording: {|localRecording: {|}" $MEET_CONF
sed -i "$LR_STR,$LR_END{s|//     enabled: true,|enabled: true,|}" $MEET_CONF
sed -i "$LR_STR,$LR_END{s|//     format: 'flac'|format: 'flac'|}" $MEET_CONF
sed -i "$LR_STR,$LR_END{s|// }|}|}" $MEET_CONF

sed -i "s|'tileview'|'tileview', 'localrecording'|" $INT_CONF
#EOLR

#Setup main language
if [ -z $LANG ] || [ "$LANG" = "en" ]; then
	echo "Leaving English (en) as default language..."
	#sed -i "s|// defaultLanguage: 'en',|defaultLanguage: 'en',|" $MEET_CONF
else
	echo "Changing default language to: $LANG"
	#sed -i "s|// defaultLanguage: 'en',|defaultLanguage: \'$LANG\',|" $MEET_CONF
fi

#Check config file
echo "
# Checking $MEET_CONF file for errors
"
CHECKJS=$(esvalidate $MEET_CONF| cut -d ":" -f2)
if [[ -z "$CHECKJS" ]]; then
echo "
# The $MEET_CONF configuration seems correct. =)
"
else
echo "
Watch out!, there seems to be an issue on $MEET_CONF line:
$CHECKJS
Most of the times this is due upstream changes, please report to
https://github.com/switnet-ltd/quick-jibri-installer/issues
"
fi

# Recording directory
cat << REC_DIR > $REC_DIR
#!/bin/bash

RECORDINGS_DIR=$1

echo "This is a dummy finalize script" > /tmp/finalize.out
echo "The script was invoked with recordings directory $RECORDINGS_DIR." >> /tmp/finalize.out
echo "You should put any finalize logic (renaming, uploading to a service" >> /tmp/finalize.out
echo "or storage provider, etc.) in this script" >> /tmp/finalize.out

exit 0
REC_DIR

## JSON Config
cp $CONF_JSON $CONF_JSON.orig
cat << CONF_JSON > $CONF_JSON
{
    "recording_directory":"$DIR_RECORD",
    "finalize_recording_script_path": "$REC_DIR",
    "xmpp_environments": [
        {
            "name": "$JB_NAME",
            "xmpp_server_hosts": [
                "$WAN_IP"
            ],
            "xmpp_domain": "$DOMAIN",
            "control_login": {
                "domain": "auth.$DOMAIN",
                "username": "jibri",
                "password": "$JB_AUTH_PASS"
            },
            "control_muc": {
                "domain": "internal.auth.$DOMAIN",
                "room_name": "$JibriBrewery",
                "nickname": "Live"
            },
            "call_login": {
                "domain": "recorder.$DOMAIN",
                "username": "recorder",
                "password": "$JB_REC_PASS"
            },

            "room_jid_domain_string_to_strip_from_start": "internal.auth",
            "usage_timeout": "0"
        }
    ]
}
CONF_JSON

#Tune webserver for Jitsi App control
if [ -f /etc/apache2/sites-available/$DOMAIN.conf ]; then
WS_CONF=/etc/apache2/sites-available/$DOMAIN.conf
sed -i '$ d' $WS_CONF
cat << NG_APP >> $WS_CONF

  Alias "/external_api.js" "/usr/share/jitsi-meet/libs/external_api.min.js"
  Alias "/external_api.min.js" "/usr/share/jitsi-meet/libs/external_api.min.js"

</VirtualHost>
NG_APP
service apache2 reload
elif [ -f /etc/nginx/sites-available/$DOMAIN.conf ]; then
WS_CONF=/etc/nginx/sites-enabled/$DOMAIN.conf
WS_STR=$(grep -n "external_api.js" $WS_CONF | cut -d ":" -f1)
WS_END=$((WS_STR + 2))
sed -i "${WS_STR},${WS_END} s|^|#|" $WS_CONF
sed -i '$ d' $WS_CONF
cat << NG_APP >> $WS_CONF

    location /external_api.min.js {
        alias /usr/share/jitsi-meet/libs/external_api.min.js;
    }

    location /external_api.js {
        alias /usr/share/jitsi-meet/libs/external_api.min.js;
    }
}
NG_APP
service nginx reload
else
	echo "No app configuration done to server file, please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi

#Enable static avatar
while [[ "$ENABLE_SA" != "yes" && "$ENABLE_SA" != "no" ]]
do
read -p "Do you want to enable static avatar?: (yes or no)"$'\n' -r ENABLE_SA
if [ "$ENABLE_SA" = "no" ]; then
	echo "Static avatar won't be enable"
elif [ "$ENABLE_SA" = "yes" ] && [ -f /etc/apache2/sites-available/$DOMAIN.conf ]; then
	echo "Static avatar are being enable"
	wget https://switnet.net/static/avatar.png -O /usr/share/jitsi-meet/images/avatar2.png
	WS_CONF=/etc/apache2/sites-available/$DOMAIN.conf
	sed -i "/Alias \"\/external_api.js\"/i \ \ AliasMatch \^\/avatar\/\(.\*\)\\\.png /usr/share/jitsi-meet/images/avatar2.png" $WS_CONF
	sed -i "/RANDOM_AVATAR_URL_PREFIX/ s|false|\'https://$DOMAIN/avatar/\'|" $INT_CONF
	sed -i "/RANDOM_AVATAR_URL_SUFFIX/ s|false|\'.png\'|" $INT_CONF
elif [ "$ENABLE_SA" = "yes" ] && [ -f /etc/nginx/sites-available/$DOMAIN.conf ]; then
	wget https://switnet.net/static/avatar.png -O /usr/share/jitsi-meet/images/avatar2.png
	WS_CONF=/etc/nginx/sites-enabled/$DOMAIN.conf
	sed -i "/location \/external_api.min.js/i \ \ \ \ location \~ \^\/avatar\/\(.\*\)\\\.png {\\
\
\ \ \ \ \ \ \ \ alias /usr/share/jitsi-meet/images/avatar2.png;\\
\
\ \ \ \ }\\
\ " $WS_CONF
	sed -i "/RANDOM_AVATAR_URL_PREFIX/ s|false|\'https://$DOMAIN/avatar/\'|" $INT_CONF
	sed -i "/RANDOM_AVATAR_URL_SUFFIX/ s|false|\'.png\'|" $INT_CONF
else
		echo "No app configuration done to server file, please report to:
		-> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi
done

# Temporary disable "Blur my background" until is stable
sed -i "s|'videobackgroundblur', ||" $INT_CONF

#Enable secure rooms?
cat << P_SR >> $PROSODY_FILE
VirtualHost "$DOMAIN"
    authentication = "internal_plain"

VirtualHost "guest.$DOMAIN"
    authentication = "anonymous"
    c2s_require_encryption = false
P_SR
while [[ "$ENABLE_SC" != "yes" && "$ENABLE_SC" != "no" ]]
do
read -p "Do you want to enable secure rooms?: (yes or no)"$'\n' -r ENABLE_SC
if [ "$ENABLE_SC" = "no" ]; then
	echo "Secure rooms won't be enable"
elif [ "$ENABLE_SC" = "yes" ]; then
	echo "Secure rooms are being enable"
#Secure room initial user
read -p "Set username for secure room moderator: "$'\n' -r SEC_ROOM_USER
read -p "Secure room moderator password: "$'\n' -sr SEC_ROOM_PASS
echo "You'll be able to login Secure Room chat with '${SEC_ROOM_USER}' \
or '${SEC_ROOM_USER}@${DOMAIN}' using the password you just entered.
If you have issues with the password refer to your sysadmin."
sed -i "s|#org.jitsi.jicofo.auth.URL=XMPP:|org.jitsi.jicofo.auth.URL=XMPP:|" $JICOFO_SIP
prosodyctl register $SEC_ROOM_USER $DOMAIN $SEC_ROOM_PASS
fi
done

#Start with video muted by default
sed -i "s|// startWithVideoMuted: false,|startWithVideoMuted: true,|" $MEET_CONF

#Start with audio muted but admin
sed -i "s|// startAudioMuted: 10,|startAudioMuted: 1,|" $MEET_CONF

#Disable/enable welcome page
while [[ $ENABLE_WELCP != yes && $ENABLE_WELCP != no ]]
do
read -p "Do you want to disable the Welcome page: (yes or no)"$'\n' -r ENABLE_WELCP
if [ $ENABLE_WELCP = no ]; then
	echo "Welcome page won't be enabled."
	sed -i "s|// enableWelcomePage: true,|enableWelcomePage: false,|" $MEET_CONF
elif [ $ENABLE_WELCP = yes ]; then
	echo "Welcome page will be enabled."
	sed -i "s|// enableWelcomePage: true,|enableWelcomePage: true,|" $MEET_CONF
fi
done

#Set displayname as not required since jibri can't set it up.
sed -i "s|// requireDisplayName: true,|requireDisplayName: false,|" $MEET_CONF

#Enable jibri services
systemctl enable jibri
systemctl enable jibri-xorg
systemctl enable jibri-icewm
restart_services

enable_letsencrypt

#SSL workaround
if [ "$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
	ssl_wa apache2 apache $DOMAIN $WS_CONF $SYSADMIN_EMAIL $DOMAIN
	install_ifnot python3-certbot-apache
elif [ "$(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
	ssl_wa nginx nginx $DOMAIN $WS_CONF $SYSADMIN_EMAIL $DOMAIN
	install_ifnot python3-certbot-nginx
else
	echo "No webserver found please report."
fi

if [ $ENABLE_TRANSCRIPT = yes ]; then
	echo "Jigasi Transcription will be enabled."
	bash $PWD/jigasi.sh
fi

echo "
########################################################################
                    Installation complete!!
           for customized support: http://switnet.net
########################################################################
"
apt -y autoremove
apt autoclean

echo "Rebooting in..."
secs=$((15))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
reboot
