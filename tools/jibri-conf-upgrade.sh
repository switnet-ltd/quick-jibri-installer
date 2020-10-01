#!/bin/bash
# Simple Jibri conf updater
# 2020 - SwITNet Ltd
# GNU GPLv3 or later.

while getopts m: option
do
	case "${option}"
	in
		m) MODE=${OPTARG};;
		\?) echo "Usage: sudo ./test-jibri-env.sh [-m debug]" && exit;;
	esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

echo -e '
########################################################################
                  Welcome to Jibri Config Upgrader
########################################################################
                    by Software, IT & Networks Ltd
\n'

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

echo "Checking for updates...."
apt -q2 update
apt install -y apt-show-versions jq

echo -e "\n# Check for jibri\n"
if [ "$(dpkg-query -W -f='${Status}' jibri 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo "Jibri is installed, checking version:"
    apt-show-versions jibri
else
    echo "Wait!, jibri is not installed on this system using apt, exiting..."
    exit
fi

DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
CONF_JSON="/etc/jitsi/jibri/config.json"
JIBRI_CONF="/etc/jitsi/jibri/jibri.conf"
DIR_RECORD=/var/jbrecord
REC_DIR=/home/jibri/finalize_recording.sh
JibriBrewery=JibriBrewery

check_read_vars() {
    echo "Checking $1"
    if [ -z "$2" ];then
    echo "This variable seems wrong, please check before continue"
    exit 1
    fi
}
restart_services_jibri() {
if [ "$(dpkg-query -W -f='${Status}' "jibri" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
	systemctl restart jibri
	systemctl restart jibri-icewm
	systemctl restart jibri-xorg
else
	echo "Jibri service not installed"
fi
}

#Prevent re-run on completed jibri upgraded instance
if [ -f $CONF_JSON_disabled ] && \
   [ -f $JIBRI_CONF ] && \
   [ -f $JIBRI_CONF-dpkg-file ]; then
    echo -e "\n> This jibri config has been upgraded already, we'll exit...\n\nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
    exit
elif [ ! -f $CONF_JSON ] && \
   [ -f $JIBRI_CONF ] && \
   [ -f $JIBRI_CONF-dpkg-file ]; then
    echo -e "\n> This jibri seems to be running the lastest configuration already, we'll exit...\n\nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
    exit
elif [ -f $CONF_JSON ] && \
   [ -f $JIBRI_CONF ]; then
    echo -e "\n> This jibri config seems to be candidate for upgrading, we'll continue...\nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
fi

#Read missing variables
if [ -f $CONF_JSON ]; then
    echo "Reading current config.json file..."
    JB_NAME=$(jq .xmpp_environments[0].name $CONF_JSON|cut -d '"' -f2)
    JB_AUTH_PASS=$(jq .xmpp_environments[0].control_login.password $CONF_JSON|cut -d '"' -f2)
    JB_REC_PASS=$(jq .xmpp_environments[0].call_login.password $CONF_JSON|cut -d '"' -f2)
else
    echo "Can't find the instance config.json file, exiting..."
    exit
fi

check_read_vars "Jibri Name" $JB_NAME
check_read_vars "Control login passwd" $JB_AUTH_PASS
check_read_vars "Call login passwd" $JB_REC_PASS

if [ "$MODE" = "debug" ]; then
echo "$JB_NAME"
echo "$JB_AUTH_PASS"
echo "$JB_REC_PASS"
fi

#Backup and setup new conf file
echo -e "Backing up config.json for historical porpuses at:\n ${CONF_JSON}_disabled"
mv $CONF_JSON ${CONF_JSON}_disabled

mv $JIBRI_CONF ${JIBRI_CONF}-dpkg-file
cat << NEW_CONF > $JIBRI_CONF
// New XMPP environment config.
jibri {
    recording {
         recordings-directory = $DIR_RECORD
         finalize-script = $REC_DIR
    }
    api {
        xmpp {
            environments = [
                {
				// A user-friendly name for this environment
				name = "$JB_NAME"

				// A list of XMPP server hosts to which we'll connect
				xmpp-server-hosts = [ "$DOMAIN" ]

				// The base XMPP domain
				xmpp-domain = "$DOMAIN"

				// The MUC we'll join to announce our presence for
				// recording and streaming services
				control-muc {
					domain = "internal.auth.$DOMAIN"
					room-name = "$JibriBrewery"
					nickname = "Live"
				}

				// The login information for the control MUC
				control-login {
					domain = "auth.$DOMAIN"
					username = "jibri"
					password = "$JB_AUTH_PASS"
				}

				// An (optional) MUC configuration where we'll
				// join to announce SIP gateway services
			//	sip-control-muc {
			//		domain = "domain"
			//		room-name = "room-name"
			//		nickname = "nickname"
			//	}

				// The login information the selenium web client will use
				call-login {
					domain = "recorder.$DOMAIN"
					username = "recorder"
					password = "$JB_REC_PASS"
				}

				// The value we'll strip from the room JID domain to derive
				// the call URL
				strip-from-room-domain = "conference."

				// How long Jibri sessions will be allowed to last before
				// they are stopped.  A value of 0 allows them to go on
				// indefinitely
				usage-timeout = 0 hour

				// Whether or not we'll automatically trust any cert on
				// this XMPP domain
				trust-all-xmpp-certs = true
                }
            ]
        }
    }
}
NEW_CONF

echo "Check final jibri.conf file:"
cat $JIBRI_CONF
read -n 1 -s -r -p "Press any key to continue..."$'\n'

restart_services_jibri
systemctl status jibri
