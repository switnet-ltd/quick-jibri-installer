#!/bin/bash
# Jibri Node Aggregator
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.

### 0_LAST EDITION TIME STAMP ###
# LETS: AUTOMATED_EDITION_TIME
### 1_LAST EDITION ###

#Make sure the file name is the required one
if [ ! "$(basename $0)" = "add-jibri-node.sh" ]; then
	echo "For most cases naming won't matter, for this one it does."
	echo "Please use the original name for this script: \`add-jibri-node.sh', and run again."
	exit
fi

while getopts m: option
do
	case "${option}"
	in
		m) MODE=${OPTARG};;
		\?) echo "Usage: sudo ./add_jibri_node.sh [-m debug]" && exit;;
	esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

#Check admin rights
if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

### 0_VAR_DEF
MAIN_SRV_DIST=TBD
MAIN_SRV_REPO=TBD
MAIN_SRV_DOMAIN=TBD
JibriBrewery=TBD
JB_NAME=TBD
JB_AUTH_PASS=TBD
JB_REC_PASS=TBD
THIS_SRV_DIST=$(lsb_release -sc)
JITSI_REPO=$(apt-cache policy | grep http | grep jitsi | grep stable | awk '{print $3}' | head -n 1 | cut -d "/" -f1)
START=0
LAST=TBD
CONF_JSON="/etc/jitsi/jibri/config.json"
DIR_RECORD="/var/jbrecord"
REC_DIR="/home/jibri/finalize_recording.sh"
CHD_VER="$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)"
GOOGL_REPO="/etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list"
GCMP_JSON="/etc/opt/chrome/policies/managed/managed_policies.json"
### 1_VAR_DEF

# sed limiters for add-jibri-node.sh variables
var_dlim() {
	grep -n $1 add-jibri-node.sh|head -n1|cut -d ":" -f1
}

check_var() {
	if [ -z "$2" ]; then
		echo "$1 is not defined, please check. Exiting..."
		exit
	else
		echo "$1 is set to: $2"
	fi
	}

if [ -z "$LAST" ]; then
	echo "There is an error on the LAST definition, please report."
	exit
elif [ "$LAST" = "TBD" ]; then
	ADDUP=$((START + 1))
else
	ADDUP=$((LAST + 1))
fi

#Check server and node OS
if [ ! "$THIS_SRV_DIST" = "$MAIN_SRV_DIST" ]; then
	echo "Please use the same OS for the jibri setup on both servers."
	echo "This server is based on: $THIS_SRV_DIST"
	echo "The main server record claims is based on: $MAIN_SRV_DIST"
	exit
fi

echo "
#-----------------------------------------------------------------------
# Checking initial necessary variables...
#-----------------------------------------------------------------------"

check_var MAIN_SRV_DIST "$MAIN_SRV_DIST"
check_var MAIN_SRV_REPO "$MAIN_SRV_REPO"
check_var MAIN_SRV_DOMAIN "$MAIN_SRV_DOMAIN"
check_var JibriBrewery "$JibriBrewery"
check_var JB_NAME "$JB_NAME"
check_var JB_AUTH_PASS "$JB_AUTH_PASS"
check_var JB_REC_PASS "$JB_REC_PASS"

# Jitsi-Meet Repo
echo "Add Jitsi repo"
if [ -z "$JITSI_REPO" ]; then
	echo "deb http://download.jitsi.org $MAIN_SRV_REPO/" > /etc/apt/sources.list.d/jitsi-$MAIN_SRV_REPO.list
	wget -qO -  https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
elif [ ! "$JITSI_REPO" = "$MAIN_SRV_REPO" ]; then
	echo "Main and node servers repository don't match, extiting.."
	exit
elif [ "$JITSI_REPO" = "$MAIN_SRV_REPO" ]; then
	echo "Main and node servers repository match, continuing..."
else
	echo "Jitsi $JITSI_REPO repository already installed"
fi

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
				linux-image-generic-hwe-"$(lsb_release -r|awk '{print$2}')" \
				unzip \
				wget

check_snd_driver

echo "
#--------------------------------------------------
# Install Jibri
#--------------------------------------------------
"
apt-get -y install \
                jibri \
                openjdk-8-jre-headless

echo "# Installing Google Chrome / ChromeDriver"
if [ -f $GOOGL_REPO ]; then
	echo "Google repository already set."
else
	echo "Installing Google Chrome Stable"
	wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
	echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee $GOOGL_REPO
fi
apt-get -q2 update
apt-get install -y google-chrome-stable
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

echo '
########################################################################
                        Start Jibri configuration
########################################################################
'
echo "
Remove Chrome warning...
"
mkdir -p /etc/opt/chrome/policies/managed
echo '{ "CommandLineFlagSecurityWarningsEnabled": false }' > $GCMP_JSON

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
                "$MAIN_SRV_DOMAIN"
            ],
            "xmpp_domain": "$MAIN_SRV_DOMAIN",
            "control_login": {
                "domain": "auth.$MAIN_SRV_DOMAIN",
                "username": "jibri",
                "password": "$JB_AUTH_PASS"
            },
            "control_muc": {
                "domain": "internal.auth.$MAIN_SRV_DOMAIN",
                "room_name": "$JibriBrewery",
                "nickname": "Live-$ADDUP"
            },
            "call_login": {
                "domain": "recorder.$MAIN_SRV_DOMAIN",
                "username": "recorder",
                "password": "$JB_REC_PASS"
            },

            "room_jid_domain_string_to_strip_from_start": "conference.",
            "usage_timeout": "0"
        }
    ]
}
CONF_JSON

echo "Writting last node number..."
sed -i "$(var_dlim 0_VAR),$(var_dlim 1_VAR){s|LAST=.*|LAST=$ADDUP|}" add-jibri-node.sh
sed -i "$(var_dlim 0_LAST),$(var_dlim 1_LAST){s|LETS: .*|LETS: $(date -R)|}" add-jibri-node.sh
echo "Last file edition at: $(grep "LETS:" add-jibri-node.sh|head -n1|awk -F'LETS:' '{print$2}')"

echo "Start Jibri at system boot"
systemctl enable jibri

echo "
########################################################################
                        Node addition complete!!
               for customized support: http://switnet.net
########################################################################
"

echo "Rebooting in..."
secs=$((15))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
reboot
