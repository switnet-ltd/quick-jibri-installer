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
MJS_USER=TBD
MJS_USER_PASS=TBD
THIS_SRV_DIST=$(lsb_release -sc)
JITSI_REPO=$(apt-cache policy | grep http | grep jitsi | grep stable | awk '{print $3}' | head -n 1 | cut -d "/" -f1)
START=0
LAST=TBD
JIBRI_CONF="/etc/jitsi/jibri/jibri.conf"
DIR_RECORD="/var/jbrecord"
REC_DIR="/home/jibri/finalize_recording.sh"
CHD_VER="$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)"
GOOGL_REPO="/etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list"
GCMP_JSON="/etc/opt/chrome/policies/managed/managed_policies.json"
PUBLIC_IP="$(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short)"
NJN_RAND_TAIL="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 4 | head -n1)"
NJN_USER="jbnode${ADDUP}_${NJN_RAND_TAIL}"
NJN_USER_PASS="$(tr -dc "a-zA-Z0-9#_*=" < /dev/urandom | fold -w 32 | head -n1)"
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

#Check system resources
echo "Verifying System Resources:"
if [ "$(nproc --all)" -lt 4 ];then
  echo "
Warning!: The system do not meet the minimum CPU requirements for Jibri to run.
>> We recommend 4 cores/threads for Jibri!
"
  CPU_MIN="N"
else
  echo "CPU Cores/Threads: OK ($(nproc --all))"
  CPU_MIN="Y"
fi
### Test RAM size (8GB min) ###
mem_available=$(grep MemTotal /proc/meminfo| grep -o '[0-9]\+')
if [ ${mem_available} -lt 7700000 ]; then
  echo "
Warning!: The system do not meet the minimum RAM requirements for Jibri to run.
>> We recommend 8GB RAM for Jibri!
"
  MEM_MIN="N"
else
  echo "Memory: OK ($((mem_available/1024)) MiB)"
  MEM_MIN="Y"
fi
if [ "$CPU_MIN" = "Y" ] && [ "$MEM_MIN" = "Y" ];then
    echo "All requirements seems meet!"
    echo "
    - We hope you have a nice recording/streaming session
    "
else
    echo "CPU ($(nproc --all))/RAM ($((mem_available/1024)) MiB) does NOT meet minimum recommended requirements!"
    echo "Even when you can use the videconference sessions, we advice to increase the resources in order to user Jibri."
    while [[ "$CONTINUE_LOW_RES" != "yes" && "$CONTINUE_LOW_RES" != "no" ]]
    do
    read -p "> Do you want to continue?: (yes or no)"$'\n' -r CONTINUE_LOW_RES
    if [ "$CONTINUE_LOW_RES" = "no" ]; then
            echo "See you next time with more resources!..."
            exit
    elif [ "$CONTINUE_LOW_RES" = "yes" ]; then
            echo "Please keep in mind that trying to use Jibri with low resources might fail."
    fi
    done
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

# Rename hostname for each jibri node
hostnamectl set-hostname "jbnode${ADDUP}.${MAIN_SRV_DOMAIN}"
sed -i "1i ${PUBLIC_IP} jbnode${ADDUP}.${MAIN_SRV_DOMAIN}" /etc/hosts

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
                apt-show-versions \
                bmon \
                curl \
                ffmpeg \
                git \
                htop \
                inotify-tools \
                jq \
                rsync \
                ssh \
                unzip \
                wget

echo "# Check and Install HWE kernel if possible..."
HWE_VIR_MOD=$(apt-cache madison linux-modules-extra-virtual-hwe-$(lsb_release -sr) 2>/dev/null|head -n1|grep -c "extra-virtual-hwe")
if [ "$HWE_VIR_MOD" == "1" ]; then
    apt-get -y install \
    linux-image-generic-hwe-$(lsb_release -sr) \
    linux-modules-extra-virtual-hwe-$(lsb_release -sr)
    else
    apt-get -y install \
    linux-modules-extra-$(uname -r)
fi

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

## New Jibri Config (2020)
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
				xmpp-server-hosts = [ "$MAIN_SRV_DOMAIN" ]

				// The base XMPP domain
				xmpp-domain = "$MAIN_SRV_DOMAIN"

				// The MUC we'll join to announce our presence for
				// recording and streaming services
				control-muc {
					domain = "internal.auth.$MAIN_SRV_DOMAIN"
					room-name = "$JibriBrewery"
					nickname = "Live-$ADDUP"
				}

				// The login information for the control MUC
				control-login {
					domain = "auth.$MAIN_SRV_DOMAIN"
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
					domain = "recorder.$MAIN_SRV_DOMAIN"
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

echo -e "\n---- Create random nodesync user ----"
useradd -m -g jibri $NJN_USER
echo "$NJN_USER:$NJN_USER_PASS" | chpasswd

#Create ssh key
sudo su $NJN_USER -c "ssh-keygen -t rsa -f ~/.ssh/id_rsa -b 4096 -o -a 100 -q -N ''"
ssh $MJS_USER@$MAIN_SRV_DOMAIN sh -c "'cat >> .ssh/authorized_keys'" < /home/$NJN_USER/.ssh/id_rsa.pub
#Temp Workaround
echo "Please manually accept the connection by executing: ssh $MJS_USER@$MAIN_SRV_DOMAIN ...then exit"
su $NJN_USER

echo -e "\n---- Setup Log system ----"
cat << INOT_RSYNC > /etc/jitsi/jibri/remote-jbsync.sh
#!/bin/bash

# Log process
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/var/log/$NJN_USER/remote_jnsync.log 2>&1

# Run sync
while true; do
  inotifywait  -t 60 -r -e modify,attrib,close_write,move,delete $DIR_RECORD
  sudo su $NJN_USER -c "rsync -Aax  --info=progress2 --remove-source-files --exclude '.*/' $DIR_RECORD/ $MJS_USER@$MAIN_SRV_DOMAIN:$DIR_RECORD" && \\
  find $DIR_RECORD -depth -type d -empty -not -path $DIR_RECORD -delete
done
INOT_RSYNC


mkdir /var/log/$NJN_USER

cat << LOG_ROT >> /etc/logrotate.d/$NJN_USER
/var/log/$NJN_USER/*.log {
    monthly
    missingok
    rotate 12
    compress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        service remote_jnsync restart
    endscript
}
LOG_ROT

echo -e "\n---- Create systemd service file ----"
cat << REMOTE_SYNC_SERVICE > /etc/systemd/system/remote_jnsync.service
[Unit]
Description = Sync Node to Main Jibri Service
After = network.target

[Service]
PIDFile = /run/syncservice/remote_jnsync.pid
User = root
Group = root
WorkingDirectory = /var
ExecStartPre = /bin/mkdir /run/syncservice
ExecStartPre = /bin/chown -R root:root /run/syncservice
ExecStart = /bin/bash /etc/jitsi/jibri/remote-jbsync.sh
ExecReload = /bin/kill -s HUP \$MAINPID
ExecStop = /bin/kill -s TERM \$MAINPID
ExecStopPost = /bin/rm -rf /run/syncservice
PrivateTmp = true

[Install]
WantedBy = multi-user.target
REMOTE_SYNC_SERVICE

chmod 755 /etc/systemd/system/remote_jnsync.service
systemctl daemon-reload

systemctl enable remote_jnsync.service
systemctl start remote_jnsync.service

echo "Copying updated add-jibri-node.sh file to main server sync user..."
cp $PWD/add-jibri-node.sh /tmp
sudo su $NJN_USER -c "scp /tmp/add-jibri-node.sh $MJS_USER@$MAIN_SRV_DOMAIN:/home/$MJS_USER"

echo "Writting last node number..."
sed -i "$(var_dlim 0_VAR),$(var_dlim 1_VAR){s|LAST=.*|LAST=$ADDUP|}" add-jibri-node.sh
sed -i "$(var_dlim 0_LAST),$(var_dlim 1_LAST){s|LETS: .*|LETS: $(date -R)|}" add-jibri-node.sh
echo "Last file edition at: $(grep "LETS:" add-jibri-node.sh|head -n1|awk -F'LETS:' '{print$2}')"

#Enable jibri services
systemctl enable jibri
systemctl enable jibri-xorg
systemctl enable jibri-icewm

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
