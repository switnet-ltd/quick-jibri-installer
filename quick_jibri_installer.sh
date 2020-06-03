#!/bin/bash
# Quick Jibri Installer - *buntu (LTS) based systems.
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.
{
echo "Started at $(date +'%Y-%m-%d %H:%M:%S')" >> qj-installer.log

while getopts m: option
do
	case "${option}"
	in
		m) MODE=${OPTARG};;
		\?) echo "Usage: sudo ./quick_jibri_installer.sh [-m debug]" && exit;;
	esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

# SYSTEM SETUP
JITSI_REPO=$(apt-cache policy | grep http | grep jitsi | grep stable | awk '{print $3}' | head -n 1 | cut -d "/" -f1)
CERTBOT_REPO=$(apt-cache policy | grep http | grep certbot | head -n 1 | awk '{print $2}' | cut -d "/" -f4)
APACHE_2=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
NGINX=$(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed")
DIST=$(lsb_release -sc)
GOOGL_REPO="/etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list"
PROSODY_REPO=$(apt-cache policy | grep http | grep prosody| awk '{print $3}' | head -n 1 | cut -d "/" -f2)

if [ $DIST = flidas ]; then
DIST="xenial"
fi
if [ $DIST = etiona ]; then
DIST="bionic"
fi
install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
	echo " $1 is installed, skipping..."
    else
    	echo -e "\n---- Installing $1 ----"
		apt-get -yq2 install $1
fi
}
check_serv() {
if [ "$APACHE_2" -eq 1 ]; then
	echo "
The recommended setup is using NGINX, exiting...
"
	exit
elif [ "$NGINX" -eq 1 ]; then

echo "
Webserver already installed!
"

else
	echo "
Installing nginx webserver!
"
	install_ifnot nginx
fi
}
check_snd_driver() {
modprobe snd-aloop
echo "snd-aloop" >> /etc/modules
if [ "$(lsmod | grep snd_aloop | head -n 1 | cut -d " " -f1)" = "snd_aloop" ]; then
	echo "
#-----------------------------------------------------------------------
# Audio driver seems - OK.
#-----------------------------------------------------------------------"
else
	echo "
#-----------------------------------------------------------------------
# Your audio driver might not be able to load, once the installation
# is complete and server restarted, please run: \`lsmod | grep snd_aloop'
# to make sure it did. If not, any feedback for your setup is welcome.
#-----------------------------------------------------------------------"
read -n 1 -s -r -p "Press any key to continue..."$'\n'
fi
}
update_certbot() {
	if [ "$CERTBOT_REPO" = "certbot" ]; then
	echo "
Cerbot repository already on the system!
Checking for updates...
"
	apt-get -q2 update
	apt-get -yq2 dist-upgrade
else
	echo "
Adding cerbot (formerly letsencrypt) PPA repository for latest updates
"
	echo "deb http://ppa.launchpad.net/certbot/certbot/ubuntu $DIST main" > /etc/apt/sources.list.d/certbot.list
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 75BCA694
	apt-get -q2 update
	apt-get -yq2 dist-upgrade
fi
}
# sed limiters for add-jibri-node.sh variables
var_dlim() {
    grep -n $1 add-jibri-node.sh|head -n1|cut -d ":" -f1
}

clear
echo '
########################################################################
                    Welcome to Jitsi/Jibri Installer
########################################################################
                    by Software, IT & Networks Ltd

Featuring:
- Jibri Recording and YouTube Streaming
- Jibri Recordings Access via Nextcloud
- Jigasi Transcription (Advanced)
- Customized brandless mode
- Recurring changes updater

Learn more about these at,
Main repository: https://github.com/switnet-ltd/quick-jibri-installer
Wiki and documentation: https://github.com/switnet-ltd/quick-jibri-installer/wiki
'
read -n 1 -s -r -p "Press any key to continue..."$'\n'

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi
if [ "$DIST" = "xenial" ] || [ "$DIST" = "bionic" ]; then
	echo "OS: $(lsb_release -sd)
Good, this is a supported platform!"
else
	echo "OS: $(lsb_release -sd)
Sorry, this platform is not supported... exiting"
	exit
fi
#Suggest 18.04 LTS release over 16.04
if [ "$DIST" = "xenial" ]; then
echo "$(lsb_release -sc), even when it's compatible and functional.
We suggest to use the next (LTS) release, for longer support and security reasons."
read -n 1 -s -r -p "Press any key to continue..."$'\n'
fi
#Prosody repository
echo "Add Prosody repo"
if [ "$PROSODY_REPO" = "main" ]; then
	echo "Prosody repository already installed"
else
	echo "deb http://packages.prosody.im/debian $(lsb_release -sc) main" > /etc/apt/sources.list.d/prosody.list
	wget -qO - https://prosody.im/files/prosody-debian-packages.key | apt-key add -
fi
# Jitsi-Meet Repo
echo "Add Jitsi repo"
if [ "$JITSI_UNSTBL_REPO" = "unstable" ]; then
	echo "Jitsi stable repository already installed"
else
	echo 'deb http://download.jitsi.org unstable/' > /etc/apt/sources.list.d/jitsi-unstable.list
	wget -qO -  https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
fi

# Requirements
echo "We'll start by installing system requirements this may take a while please be patient..."
apt-get update -q2
apt-get dist-upgrade -yq2

apt-get -y install \
				bmon \
				curl \
				ffmpeg \
				git \
				htop \
				letsencrypt \
				linux-image-generic-hwe-$(lsb_release -r|awk '{print$2}') \
				unzip \
				wget

check_serv

echo "
#--------------------------------------------------
# Install Jitsi Framework
#--------------------------------------------------
"
echo "set jitsi-meet/cert-choice	select	Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)" | debconf-set-selections
apt-get -y install \
				jitsi-meet \
				jibri \
				openjdk-8-jre-headless

# Fix RAND_load_file error
#https://github.com/openssl/openssl/issues/7754#issuecomment-444063355
sed -i "/RANDFILE/d" /etc/ssl/openssl.cnf

echo "
#--------------------------------------------------
# Install NodeJS
#--------------------------------------------------
"
if [ "$(dpkg-query -W -f='${Status}' nodejs 2>/dev/null | grep -c "ok")" == "1" ]; then
		echo "Nodejs is installed, skipping..."
    else
		curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
		apt-get install -yq2 nodejs
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
GCMP_JSON="/etc/opt/chrome/policies/managed/managed_policies.json"

echo "# Installing Google Chrome / ChromeDriver"
if [ -f $GOOGL_REPO ]; then
	echo "Google repository already set."
else
	echo "Installing Google Chrome Stable"
	wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
	echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee $GOOGL_REPO
fi
apt-get -q2 update
apt-get install -yq2 google-chrome-stable
rm -rf /etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list

if [ -f /usr/local/bin/chromedriver ]; then
	echo "Chromedriver already installed."
else
	echo "Installing Chromedriver"
	wget -q https://chromedriver.storage.googleapis.com/$CHD_VER/chromedriver_linux64.zip -O /tmp/chromedriver_linux64.zip
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

echo "
Remove Chrome warning...
"
mkdir -p /etc/opt/chrome/policies/managed
echo '{ "CommandLineFlagSecurityWarningsEnabled": false }' > $GCMP_JSON

echo '
########################################################################
                    Please Setup Your Installation
########################################################################
'
# MEET / JIBRI SETUP
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
WS_CONF=/etc/nginx/sites-enabled/$DOMAIN.conf
JB_AUTH_PASS="$(tr -dc "a-zA-Z0-9#*=" < /dev/urandom | fold -w 10 | head -n1)"
JB_REC_PASS="$(tr -dc "a-zA-Z0-9#*=" < /dev/urandom | fold -w 10 | head -n1)"
PROSODY_FILE=/etc/prosody/conf.d/$DOMAIN.cfg.lua
PROSODY_SYS=/etc/prosody/prosody.cfg.lua
JICOFO_SIP=/etc/jitsi/jicofo/sip-communicator.properties
MEET_CONF=/etc/jitsi/meet/$DOMAIN-config.js
CONF_JSON=/etc/jitsi/jibri/config.json
DIR_RECORD=/var/jbrecord
REC_DIR=/home/jibri/finalize_recording.sh
JB_NAME="Jibri Sessions"
LE_RENEW_LOG="/var/log/letsencrypt/renew.log"
MOD_LISTU="https://prosody.im/files/mod_listusers.lua"
MOD_LIST_FILE="/usr/lib/prosody/modules/mod_listusers.lua"
ENABLE_SA="yes"
#Language
echo "## Setting up Jitsi Meet language ##
You can define the language, for a complete list of the supported languages

See here:
https://github.com/jitsi/jitsi-meet/blob/master/lang/languages.json

Jitsi Meet web interface will be set to use such language.
"
read -p "Please set your language (Press enter to default to 'en'):"$'\n' -r LANG
while [[ -z $SYSADMIN_EMAIL ]]
do
read -p "Set sysadmin email (this is a mandatory field):"$'\n' -r SYSADMIN_EMAIL
done
#Drop unsecure TLS
while [[ "$DROP_TLS1" != "yes" && "$DROP_TLS1" != "no" ]]
do
read -p "> Do you want to drop support for unsecure protocols TLSv1.0/1.1 now: (yes or no)"$'\n' -r DROP_TLS1
if [ "$DROP_TLS1" = "no" ]; then
	echo "TLSv1.0/1.1 will remain."
elif [ "$DROP_TLS1" = "yes" ]; then
	echo "TLSv1.0/1.1 will be dropped"
fi
done
#SSL LE
while [[ "$ENABLE_SSL" != "yes" && "$ENABLE_SSL" != "no" ]]
do
read -p "> Do you want to setup LetsEncrypt with your domain: (yes or no)"$'\n' -r ENABLE_SSL
if [ "$ENABLE_SSL" = "no" ]; then
	echo "Please run letsencrypt.sh manually post-installation."
elif [ "$ENABLE_SSL" = "yes" ]; then
	echo "SSL will be enabled."
fi
done
#Dropbox -- no longer requirement for localrecording
#while [[ $ENABLE_DB != yes && $ENABLE_DB != no ]]
#do
#read -p "> Do you want to setup the Dropbox feature now: (yes or no)"$'\n' -r ENABLE_DB
#if [ $ENABLE_DB = no ]; then
#	echo "Dropbox won't be enable"
#elif [ $ENABLE_DB = yes ]; then
#	read -p "Please set your Drobbox App key: "$'\n' -r DB_CID
#fi
#done
#Brandless  Mode
while [[ "$ENABLE_BLESSM" != "yes" && "$ENABLE_BLESSM" != "no" ]]
do
read -p "> Do you want to install customized \"brandless mode\"?: (yes or no)"$'\n' -r ENABLE_BLESSM
if [ "$ENABLE_BLESSM" = "no" ]; then
	echo "Brandless mode won't be set."
elif [ "$ENABLE_BLESSM" = "yes" ]; then
	echo "Brandless mode will be set."
fi
done
echo "We'll take a minute to localize some UI excerpts if you need."
#Participant
echo "> Do you want to translate 'Participant' to your own language?"
read -p "Leave empty to use the default one (English): "$'\n' L10N_PARTICIPANT
#Me
echo "> Do you want to translate 'me' to your own language?
This must be a really small word to present one self.
Some suggestions might be: yo (Spanish) | je (French) | ich (German)"
read -p "Leave empty to use the default one (English): "$'\n' L10N_ME
#Welcome Page
while [[ "$ENABLE_WELCP" != "yes" && "$ENABLE_WELCP" != "no" ]]
do
read -p "> Do you want to disable the Welcome page: (yes or no)"$'\n' -r ENABLE_WELCP
if [ "$ENABLE_WELCP" = "yes" ]; then
	echo "Welcome page will be disabled."
elif [ "$ENABLE_WELCP" = "no" ]; then
	echo "Welcome page will be enabled."
fi
done
#Enable static avatar
while [[ "$ENABLE_SA" != "yes" && "$ENABLE_SA" != "no" ]]
do
read -p "> (Legacy) Do you want to enable static avatar?: (yes or no)"$'\n' -r ENABLE_SA
if [ "$ENABLE_SA" = "no" ]; then
	echo "Static avatar won't be enabled"
elif [ "$ENABLE_SA" = "yes" ]; then
	echo "Static avatar will be enabled"
fi
done
#Enable local audio recording
while [[ "$ENABLE_LAR" != "yes" && "$ENABLE_LAR" != "no" ]]
do
read -p "> Do you want to enable local audio recording option?: (yes or no)"$'\n' -r ENABLE_LAR
if [ "$ENABLE_LAR" = "no" ]; then
	echo "Local audio recording option won't be enabled"
elif [ "$ENABLE_LAR" = "yes" ]; then
	echo "Local audio recording option will be enabled"
fi
done
#Secure room initial user
while [[ "$ENABLE_SC" != "yes" && "$ENABLE_SC" != "no" ]]
do
read -p "> Do you want to enable secure rooms?: (yes or no)"$'\n' -r ENABLE_SC
if [ "$ENABLE_SC" = "no" ]; then
	echo "-- Secure rooms won't be enabled."
elif [ "$ENABLE_SC" = "yes" ]; then
	echo "-- Secure rooms will be enabled."
	read -p "Set username for secure room moderator: "$'\n' -r SEC_ROOM_USER
	read -p "Secure room moderator password: "$'\n' -r SEC_ROOM_PASS
fi
done
#Jibri Records Access (JRA) via Nextcloud
while [[ "$ENABLE_NC_ACCESS" != "yes" && "$ENABLE_NC_ACCESS" != "no" ]]
do
read -p "> Do you want to setup Jibri Records Access via Nextcloud: (yes or no)
( Please check requirements at: https://github.com/switnet-ltd/quick-jibri-installer )"$'\n' -r ENABLE_NC_ACCESS
if [ "$ENABLE_NC_ACCESS" = "no" ]; then
	echo "JRA via Nextcloud won't be enabled."
elif [ "$ENABLE_NC_ACCESS" = "yes" ]; then
	echo "JRA via Nextcloud will be enabled."
fi
done
#Jigasi
while [[ "$ENABLE_TRANSCRIPT" != "yes" && "$ENABLE_TRANSCRIPT" != "no" ]]
do
read -p "> Do you want to setup Jigasi Transcription: (yes or no)
( Please check requirements at: https://github.com/switnet-ltd/quick-jibri-installer )"$'\n' -r ENABLE_TRANSCRIPT
if [ "$ENABLE_TRANSCRIPT" = "no" ]; then
	echo "Jigasi Transcription won't be enabled."
elif [ "$ENABLE_TRANSCRIPT" = "yes" ]; then
	echo "Jigasi Transcription will be enabled."
fi
done
#Start configuration
echo '
########################################################################
                  Start Jitsi Framework configuration
########################################################################
'
JibriBrewery=JibriBrewery
INT_CONF="/usr/share/jitsi-meet/interface_config.js"
WAN_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

ssl_wa() {
systemctl stop $1
	letsencrypt certonly --standalone --renew-by-default --agree-tos --email $5 -d $6
	sed -i "s|/etc/jitsi/meet/$3.crt|/etc/letsencrypt/live/$3/fullchain.pem|" $4
	sed -i "s|/etc/jitsi/meet/$3.key|/etc/letsencrypt/live/$3/privkey.pem|" $4
systemctl restart $1
	#Add cron
	crontab -l | { cat; echo "@weekly certbot renew --${2} > $LE_RENEW_LOG 2>&1"; } | crontab -
	crontab -l
}

enable_letsencrypt() {
if [ "$ENABLE_SSL" = "yes" ]; then
echo '
#--------------------------------------------------
# Starting LetsEncrypt configuration
#--------------------------------------------------
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
	systemctl restart jibri
	systemctl restart jibri-icewm
	systemctl restart jibri-xorg
else
	echo "Jibri service not installed"
fi
}

# Restarting services
restart_services() {
	systemctl restart jitsi-videobridge2
	systemctl restart jicofo
	systemctl restart prosody
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

#Fix Jibri conectivity issues
sed -i "s|c2s_require_encryption = .*|c2s_require_encryption = false|" $PROSODY_SYS
sed -i "/c2s_require_encryption = false/a \\
\\
consider_bosh_secure = true" $PROSODY_SYS
if [ ! -z $L10N_PARTICIPANT ]; then
	sed -i "s|PART_USER=.*|PART_USER=\"$L10N_PARTICIPANT\"|" jm-bm.sh
fi
if [ ! -z $L10N_ME ]; then
	sed -i "s|LOCAL_USER=.*|LOCAL_USER=\"$L10N_ME\"|" jm-bm.sh
fi
if [ ! -f $MOD_LIST_FILE ]; then
echo "
-> Adding external module to list prosody users...
"
curl -s $MOD_LISTU > $MOD_LIST_FILE

echo "Now you can check registered users with:
prosodyctl mod_listusers
"
else
echo "Prosody support for listing users seems to be enabled.
check with: prosodyctl mod_listusers
"
fi

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
if [ "$ENABLE_DB" = "yes" ]; then
DB_STR=$(grep -n "dropbox:" $MEET_CONF | cut -d ":" -f1)
DB_END=$((DB_STR + 10))
sed -i "$DB_STR,$DB_END{s|// dropbox: {|dropbox: {|}" $MEET_CONF
sed -i "$DB_STR,$DB_END{s|//     appKey: '<APP_KEY>'|appKey: \'$DB_CID\'|}" $MEET_CONF
sed -i "$DB_STR,$DB_END{s|// },|},|}" $MEET_CONF
fi

#LocalRecording
if [ "$ENABLE_LAR" = "yes" ]; then
echo "# Enabling local recording (audio only)."
LR_STR=$(grep -n "// Local Recording" $MEET_CONF | cut -d ":" -f1)
LR_END=$((LR_STR + 18))
sed -i "$LR_STR,$LR_END{s|// localRecording: {|localRecording: {|}" $MEET_CONF
sed -i "$LR_STR,$LR_END{s|//     enabled: true,|enabled: true,|}" $MEET_CONF
sed -i "$LR_STR,$LR_END{s|//     format: 'flac'|format: 'flac'|}" $MEET_CONF
sed -i "$LR_STR,$LR_END{s|// }|}|}" $MEET_CONF

sed -i "s|'tileview'|'tileview', 'localrecording'|" $INT_CONF
sed -i "s|LOC_REC=.*|LOC_REC=\"on\"|" jitsi-updater.sh
fi

#Setup main language
if [ -z $LANG ] || [ "$LANG" = "en" ]; then
	echo "Leaving English (en) as default language..."
	sed -i "s|// defaultLanguage: 'en',|defaultLanguage: 'en',|" $MEET_CONF
else
	echo "Changing default language to: $LANG"
	sed -i "s|// defaultLanguage: 'en',|defaultLanguage: \'$LANG\',|" $MEET_CONF
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
if [ ! -d $DIR_RECORD ]; then
mkdir $DIR_RECORD
fi
chown -R jibri:jibri $DIR_RECORD

cat << REC_DIR > $REC_DIR
#!/bin/bash

RECORDINGS_DIR=$DIR_RECORD

echo "This is a dummy finalize script" > /tmp/finalize.out
echo "The script was invoked with recordings directory $RECORDINGS_DIR." >> /tmp/finalize.out
echo "You should put any finalize logic (renaming, uploading to a service" >> /tmp/finalize.out
echo "or storage provider, etc.) in this script" >> /tmp/finalize.out

chmod -R 770 \$RECORDINGS_DIR

exit 0
REC_DIR
chown jibri:jibri $REC_DIR
chmod +x $REC_DIR

## JSON Config
cp $CONF_JSON ${CONF_JSON}.orig
cat << CONF_JSON > $CONF_JSON
{
    "recording_directory":"$DIR_RECORD",
    "finalize_recording_script_path": "$REC_DIR",
    "xmpp_environments": [
        {
            "name": "$JB_NAME",
            "xmpp_server_hosts": [
                "$DOMAIN"
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

            "room_jid_domain_string_to_strip_from_start": "conference.",
            "usage_timeout": "0"
        }
    ]
}
CONF_JSON

#Setting varibales for add-jibri-node.sh
sed -i "s|MAIN_SRV_DIST=.*|MAIN_SRV_DIST=\"$DIST\"|" add-jibri-node.sh
sed -i "s|MAIN_SRV_REPO=.*|MAIN_SRV_REPO=\"$JITSI_REPO\"|" add-jibri-node.sh
sed -i "s|MAIN_SRV_DOMAIN=.*|MAIN_SRV_DOMAIN=\"$DOMAIN\"|" add-jibri-node.sh
sed -i "s|JB_NAME=.*|JB_NAME=\"$JB_NAME\"|" add-jibri-node.sh
sed -i "s|JibriBrewery=.*|JibriBrewery=\"$JibriBrewery\"|" add-jibri-node.sh
sed -i "s|JB_AUTH_PASS=.*|JB_AUTH_PASS=\"$JB_AUTH_PASS\"|" add-jibri-node.sh
sed -i "s|JB_REC_PASS=.*|JB_REC_PASS=\"$JB_REC_PASS\"|" add-jibri-node.sh
sed -i "$(var_dlim 0_LAST),$(var_dlim 1_LAST){s|LETS: .*|LETS: $(date -R)|}" add-jibri-node.sh
echo "Last file edition at: $(grep "LETS:" add-jibri-node.sh|head -n1|awk -F'LETS:' '{print$2}')"

#Tune webserver for Jitsi App control
if [ -f $WS_CONF ]; then
	sed -i "/Anything that didn't match above/i \\\n" $WS_CONF
	sed -i "/Anything that didn't match above/i \ \ \ \ location = \/external_api.min.js {" $WS_CONF
	sed -i "/Anything that didn't match above/i \ \ \ \ \ \ \ \ alias \/usr\/share\/jitsi-meet\/libs\/external_api.min.js;" $WS_CONF
	sed -i "/Anything that didn't match above/i \ \ \ \ }" $WS_CONF
	sed -i "/Anything that didn't match above/i \\\n" $WS_CONF
	systemctl reload nginx
else
	echo "No app configuration done to server file, please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi
#Static avatar
if [ "$ENABLE_SA" = "yes" ] && [ -f $WS_CONF ]; then
	#wget https://switnet.net/static/avatar.png -O /usr/share/jitsi-meet/images/avatar2.png
	cp images/avatar2.png /usr/share/jitsi-meet/images/
	sed -i "/location \/external_api.min.js/i \ \ \ \ location \~ \^\/avatar\/\(.\*\)\\\.png {" $WS_CONF
	sed -i "/location \/external_api.min.js/i \ \ \ \ \ \ \ \ alias /usr/share/jitsi-meet/images/avatar2.png;" $WS_CONF
	sed -i "/location \/external_api.min.js/i \ \ \ \ }\\
\ " $WS_CONF
	sed -i "/RANDOM_AVATAR_URL_PREFIX/ s|false|\'https://$DOMAIN/avatar/\'|" $INT_CONF
	sed -i "/RANDOM_AVATAR_URL_SUFFIX/ s|false|\'.png\'|" $INT_CONF
fi
#nginx -tlsv1/1.1
if [ "$DROP_TLS1" = "yes" ] && [ "$DIST" = "bionic" ];then
	echo "Dropping TLSv1/1.1 in favor of v1.3"
	sed -i "s|TLSv1 TLSv1.1|TLSv1.3|" /etc/nginx/nginx.conf
	#sed -i "s|TLSv1 TLSv1.1|TLSv1.3|" $WS_CONF
elif [ "$DROP_TLS1" = "yes" ] && [ ! "$DIST" = "bionic" ];then
	echo "Only dropping TLSv1/1.1"
	sed -i "s|TLSv1 TLSv1.1||" /etc/nginx/nginx.conf
	#sed -i "s|TLSv1 TLSv1.1||" $WS_CONF
else
	echo "No TLSv1/1.1 dropping was done. Please report to
https://github.com/switnet-ltd/quick-jibri-installer/issues "
fi

# Disable "Blur my background" until new notice
sed -i "s|'videobackgroundblur', ||" $INT_CONF

#Setup secure rooms
SRP_STR=$(grep -n "VirtualHost \"$DOMAIN\"" $PROSODY_FILE | head -n1 | cut -d ":" -f1)
SRP_END=$((SRP_STR + 10))
sed -i "$SRP_STR,$SRP_END{s|authentication = \"anonymous\"|authentication = \"internal_plain\"|}" $PROSODY_FILE

cat << P_SR >> $PROSODY_FILE

VirtualHost "guest.$DOMAIN"
    authentication = "anonymous"

    speakerstats_component = "speakerstats.$DOMAIN"
	conference_duration_component = "conferenceduration.$DOMAIN"

	modules_enabled = {
		"muc_size";
		"speakerstats";
		"conference_duration";
	}
    c2s_require_encryption = false
P_SR
#Secure room initial user
if [ "$ENABLE_SC" = "yes" ]; then
echo "Secure rooms are being enabled..."
echo "You'll be able to login Secure Room chat with '${SEC_ROOM_USER}' \
or '${SEC_ROOM_USER}@${DOMAIN}' using the password you just entered.
If you have issues with the password refer to your sysadmin."
sed -i "s|#org.jitsi.jicofo.auth.URL=XMPP:|org.jitsi.jicofo.auth.URL=XMPP:|" $JICOFO_SIP
prosodyctl register $SEC_ROOM_USER $DOMAIN $SEC_ROOM_PASS
sed -i "s|SEC_ROOM=.*|SEC_ROOM=\"on\"|" jm-bm.sh
fi
#Start with video muted by default
sed -i "s|// startWithVideoMuted: false,|startWithVideoMuted: true,|" $MEET_CONF

#Start with audio muted but admin
sed -i "s|// startAudioMuted: 10,|startAudioMuted: 1,|" $MEET_CONF

#Disable/enable welcome page
if [ "$ENABLE_WELCP" = "yes" ]; then
	sed -i "s|.*enableWelcomePage:.*|    enableWelcomePage: false,|" $MEET_CONF
elif [ "$ENABLE_WELCP" = "no" ]; then
	sed -i "s|.*enableWelcomePage:.*|    enableWelcomePage: true,|" $MEET_CONF
fi
#Set displayname as not required since jibri can't set it up.
sed -i "s|// requireDisplayName: true,|requireDisplayName: false,|" $MEET_CONF

#Enable jibri services
systemctl enable jibri
systemctl enable jibri-xorg
systemctl enable jibri-icewm
restart_services

enable_letsencrypt

#SSL workaround
if [ "$(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
	ssl_wa nginx nginx $DOMAIN $WS_CONF $SYSADMIN_EMAIL $DOMAIN
	install_ifnot python3-certbot-nginx
else
	echo "No webserver found please report."
fi
#Brandless  Mode
if [ "$ENABLE_BLESSM" = "yes" ]; then
	echo "Custom brandless mode will be enabled."
	sed -i "s|ENABLE_BLESSM=.*|ENABLE_BLESSM=\"on\"|" jitsi-updater.sh
	bash $PWD/jm-bm.sh
fi
#JRA via Nextcloud
if [ "$ENABLE_NC_ACCESS" = "yes" ]; then
	echo "Jigasi Transcription will be enabled."
	bash $PWD/jra_nextcloud.sh
fi
}  > >(tee -a qj-installer.log) 2> >(tee -a qj-installer.log >&2)
#Jigasi Transcript
if [ "$ENABLE_TRANSCRIPT" = "yes" ]; then
	echo "Jigasi Transcription will be enabled."
	bash $PWD/jigasi.sh
fi
{
#Prevent Jibri conecction issue
sed -i "/127.0.0.1/a \\
127.0.0.1       $DOMAIN" /etc/hosts

echo "
########################################################################
                    Installation complete!!
           for customized support: http://switnet.net
########################################################################
"
apt-get -y autoremove
apt-get autoclean

echo "Rebooting in..."
secs=$((15))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}  > >(tee -a qj-installer.log) 2> >(tee -a qj-installer.log >&2)
reboot
