#!/bin/bash
# Quick Jibri Installer - *buntu (LTS) based systems.
# SwITNet Ltd © - 2022, https://switnet.net/
# GPLv3 or later.
{
echo "Started at $(date +'%Y-%m-%d %H:%M:%S')" >> qj-installer.log

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

# SYSTEM SETUP
JITSI_REPO=$(apt-cache policy | awk '/jitsi/&&/stable/{print$3}' | awk -F / 'NR==1{print$1}')
APACHE_2=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
NGINX=$(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed")
DIST=$(lsb_release -sc)
GOOGL_REPO="/etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list"
GOOGLE_ACTIVE_REPO=$(apt-cache policy | awk '/chrome/{print$3}' | awk -F "/" 'NR==1{print$2}')
PROSODY_REPO="$(apt-cache policy | awk '/prosody/{print$3}' | awk -F "/" 'NR==1{print$2}')"
PUBLIC_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
NL="$(printf '\n  ')"

exit_ifinstalled() {
if [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo "
This instance already has $1 installed, exiting...
Please try again on a clean system.
 If you think this is an error, please report to:
  -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
    exit
fi
}
exit_ifinstalled jitsi-meet

rename_distro() {
if [ "$DIST" = "$1" ]; then
  DIST="$2"
fi
}
#Trisquel distro renaming
rename_distro flidas xenial
rename_distro etiona bionic
rename_distro nabia  focal

install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo " $1 is installed, skipping..."
    else
        printf "\n---- Installing %s ----" "$1"
        apt-get -yq2 install "$1"
fi
}
check_serv() {
if [ "$APACHE_2" -eq 1 ]; then
    echo "
The recommended setup is using NGINX, exiting...
"
    exit
elif [ "$NGINX" -eq 1 ]; then

printf "\nWebserver already installed!\n"

else
    printf "\nInstalling nginx webserver!\n"
    install_ifnot nginx
fi
}
check_snd_driver() {
printf "\n# Checking ALSA - Loopback module..."
echo "snd-aloop" | tee -a /etc/modules
modprobe snd-aloop
if [ "$(lsmod|awk '/snd_aloop/{print$1}'|awk 'NR==1')" = "snd_aloop" ]; then
    echo "
#-----------------------------------------------------------------------
# Audio driver seems - OK.
#-----------------------------------------------------------------------"
else
    echo "
#-----------------------------------------------------------------------
# Your audio driver might not be able to load.
# We'll check the state of this Jibri with our 'test-jibri-env.sh' tool.
#-----------------------------------------------------------------------"
#Test tool
  if [ "$MODE" = "debug" ]; then
    bash "$PWD"/tools/test-jibri-env.sh -m debug
  else
    bash "$PWD"/tools/test-jibri-env.sh
  fi
read -n 1 -s -r -p "Press any key to continue..."$'\n'
fi
}
# sed limiters for add-jibri-node.sh variables
var_dlim() {
    grep -n "$1" add-jibri-node.sh|head -n1|cut -d ":" -f1
}
add_prosody_repo() {
echo "Add Prosody repo"
if [ "$PROSODY_REPO" = "main" ]; then
    echo "Prosody repository already installed"
else
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/prosody-debian-packages.key] http://packages.prosody.im/debian $(lsb_release -sc) main" > /etc/apt/sources.list.d/prosody.list
    curl -s https://prosody.im/files/prosody-debian-packages.key > /etc/apt/trusted.gpg.d/prosody-debian-packages.key
fi
}
dpkg-compare() {
dpkg --compare-versions "$(dpkg-query -f='${Version}' --show "$1")" "$2" "$3"
}
wait_seconds() {
secs=$(($1))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}
clear
printf '
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
Wiki and documentation: https://github.com/switnet-ltd/quick-jibri-installer/wiki\n'

read -n 1 -s -r -p "Press any key to continue..."$'\n'

#Check if user is root
if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

    printf "\nOS: %s" "$(lsb_release -sd)"
if [ "$DIST" = "focal" ] || \
   [ "$DIST" = "jammy" ]; then
    printf "\nGood, this is a supported platform!"
else
    printf "\nSorry, this platform is not supported... exiting"
    exit
fi
#Suggest 22.04 LTS release over 20.04 in April 2024
TODAY=$(date +%s)
NEXT_LTS_DATE=$(date -d 2024-04-01 +%s)

if [ "$DIST" = "focal" ]; then
  if [ "$TODAY" -gt "$NEXT_LTS_DATE" ]; then
    echo "  > $(lsb_release -sc), even when it's compatible and functional.
    We suggest to use the next (LTS) release, for longer support and security reasons."
    read -n 1 -s -r -p "Press any key to continue..."$'\n'
  else
    echo "Focal is supported."
  fi
fi

#Check system resources
printf "\n\nVerifying System Resources:"
if [ "$(nproc --all)" -lt 4 ];then
    printf "\nWarning!: The system do not meet the minimum CPU requirements for Jibri to run."
    printf "\n>> We recommend 4 cores/threads for Jibri!\n"
    CPU_MIN="N"
else
    printf "\nCPU Cores/Threads: OK (%s)\n" "$(nproc --all)"
    CPU_MIN="Y"
fi
sleep .1
### Test RAM size (8GB min) ###
mem_available="$(grep MemTotal /proc/meminfo| grep -o '[0-9]\+')"
if [ "$mem_available" -lt 7700000 ]; then
    printf "\nWarning!: The system do not meet the minimum RAM requirements for Jibri to run."
    printf "\n>> We recommend 8GB RAM for Jibri!\n\n"
    MEM_MIN="N"
else
    printf "\nMemory: OK (%s) MiB\n\n" "$((mem_available/1024))"
    MEM_MIN="Y"
fi
sleep .1
if [ "$CPU_MIN" = "Y" ] && [ "$MEM_MIN" = "Y" ];then
    echo "All requirements seems meet!"
    printf "\n    - We hope you have a nice recording/streaming session\n"
else
    printf "CPU (%s)/RAM (%s MiB) does NOT meet minimum recommended requirements!" "$(nproc --all)" "$((mem_available/1024))"
    printf "\nEven when you can use the videoconferencing sessions, we advice to increase the resources in order to user Jibri.\n\n"
sleep .1
    while [ "$CONTINUE_LOW_RES" != "yes" ] && [ "$CONTINUE_LOW_RES" != "no" ]
    do
    read -p "> Do you want to continue?: (yes or no)$NL" -r CONTINUE_LOW_RES
    if [ "$CONTINUE_LOW_RES" = "no" ]; then
            echo " - See you next time with more resources!..."
            exit
    elif [ "$CONTINUE_LOW_RES" = "yes" ]; then
            printf "\n - We highly recommend to increase the server resources."
            printf "\n - Otherwise, please think about adding dedicated jibri nodes instead.\n\n"
    fi
    done
fi
sleep .1
if [ "$CONTINUE_LOW_RES" = "yes" ]; then
echo 'This server will likely have issues due the lack of resources.
If you plan to enable other components such as,

 - JRA via Nextcloud
 - Jigasi Transcriber
 - Additional Jibri Nodes
 - others.

>>> We higly recommend to increase resources of this server. <<<

For now we advice to disable the Jibri service locally and add an external
Jibri node once this installation has finished, using our script:

 >> add-jibri-node.sh'
printf "\nSo you can add a Jibri server on a instance with enough resources.\n\n"
sleep .1
    while [ "$DISABLE_LOCAL_JIBRI" != "yes" ] && [ "$DISABLE_LOCAL_JIBRI" != "no" ]
    do
    read -p "> Do you want to disable local jibri service?: (yes or no)$NL" -r DISABLE_LOCAL_JIBRI
        if [ "$DISABLE_LOCAL_JIBRI" = "no" ]; then
            printf " - Please keep in mind that we might not support underpowered servers.\n"
        elif [ "$DISABLE_LOCAL_JIBRI" = "yes" ]; then
            printf " - You can add dedicated jibri nodes later, see more at the wiki.\n"
        fi
    done
fi
sleep .1
#Check system oriented porpuse
apt-get -yq2 update
SYSTEM_DE="$(apt-cache search "ubuntu-(desktop|mate-desktop)"|awk '{print$1}'|xargs|sed 's|$| trisquel triskel trisquel-mini|')"
SYSTEM_DE_ARRAY=( "$SYSTEM_DE" )
printf "\nChecking for common desktop system oriented purpose....\n"
for de in "${SYSTEM_DE_ARRAY[@]}"
do
    if [ "$(dpkg-query -W -f='${Status}' "$de" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
        printf "\n > This instance has %s installed, exiting...
\nPlease avoid using this installer on a desktop-user oriented GNU/Linux system.
 This is an unsupported use, as it will likely BREAK YOUR SYSTEM, so please don't." "$de"
        exit
    else
        printf " > No standard desktop environment for user oriented porpuse detected, good!, continuing...\n\n"
    fi
done
sleep .1
#Prosody repository
add_prosody_repo
sleep .1
# Jitsi-Meet Repo
printf "\nAdd Jitsi repo\n"
if [ "$JITSI_REPO" = "stable" ]; then
    printf " - Jitsi stable repository already installed\n\n"
else
    echo 'deb [signed-by=/etc/apt/trusted.gpg.d/jitsi-key.gpg.key] http://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list
    curl -s https://download.jitsi.org/jitsi-key.gpg.key > /etc/apt/trusted.gpg.d/jitsi-key.gpg.key
    JITSI_REPO="stable"
fi
sleep .1
#Default to LE SSL?
while [ "$LE_SSL" != "yes" ] && [ "$LE_SSL" != "no" ]
do
read -p "> Do you plan to use Let's Encrypt SSL certs?: (yes or no)$NL" -r LE_SSL
if [ "$LE_SSL" = yes ]; then
    printf " - We'll setup Let's Encrypt SSL certs.\n\n"
else
    printf " - We'll let you choose later on for it."
    printf "   Please be aware that a valid SSL cert is required for some features to work properly.\n\n"
fi
done
sleep .1
#Set domain
if [ "$LE_SSL" = "yes" ]
then
  while [ "$ANS_JD" != "yes" ]
  do
    read -p "> Please set your domain (or subdomain) here: (e.g.: jitsi.domain.com)$NL" -r JITSI_DOMAIN
    read -p "  > Did you mean?: $JITSI_DOMAIN (yes or no)$NL" -r ANS_JD
    if [ "$ANS_JD" = "yes" ]
    then
      echo "   - Alright, let's use $JITSI_DOMAIN."
    else
      echo "   - Please try again."
    fi
  done
sleep .1
  #Sysadmin email
    while [ -z "$SYSADMIN_EMAIL" ]
    do
      read -p "$NL  > Set sysadmin email (this is a mandatory field):$NL" -r SYSADMIN_EMAIL
    done
sleep .1
  #Simple DNS test
    if [ "$PUBLIC_IP" = "$(dig -4 +short "$JITSI_DOMAIN"||awk -v RS='([0-9]+\\.){3}[0-9]+' 'RT{print RT}')" ]; then
        printf "\nServer public IP  & DNS record for %s seems to match, continuing..." "$JITSI_DOMAIN"
    else
       echo "Server public IP ($PUBLIC_IP) & DNS record for $JITSI_DOMAIN don't seem to match."
    echo "  > Please check your dns records are applied and updated, otherwise components may fail."
      read -p "  > Do you want to continue?: (yes or no)$NL" -r DNS_CONTINUE
        if [ "$DNS_CONTINUE" = "yes" ]; then
          echo "  - We'll continue anyway..."
        else
          echo "  - Exiting for now..."
          exit
        fi
    fi
fi
sleep .1
# Requirements
printf "\nWe'll start by installing system requirements this may take a while please be patient...\n"
apt-get update -q2
apt-get dist-upgrade -yq2

apt-get -y install \
                    apt-show-versions \
                    bmon \
                    curl \
                    ffmpeg \
                    git \
                    htop \
                    jq \
                    net-tools \
                    rsync \
                    ssh \
                    unzip \
                    wget

if [ "$LE_SSL" = "yes" ]; then
apt-get -y install \
                certbot
    if [ "$(dpkg-query -W -f='${Status}' ufw 2>/dev/null | grep -c "ok installed")" == "1"  ]; then
        echo "# Disable pre-installed ufw, more on firewall see:
    > https://github.com/switnet-ltd/quick-jibri-installer/wiki/Firewall"
        ufw disable
    fi
fi

echo "# Check and Install HWE kernel if possible..."
HWE_VIR_MOD="$(apt-cache madison linux-image-generic-hwe-"$(lsb_release -sr)" 2>/dev/null|head -n1|grep -c "hwe-$(lsb_release -sr)")"
if [ "$HWE_VIR_MOD" = "1" ]; then
    apt-get -y install \
    linux-image-generic-hwe-"$(lsb_release -sr)" \
    linux-tools-generic-hwe-"$(lsb_release -sr)"
else
    apt-get -y install \
    linux-image-generic \
    linux-modules-extra-"$(uname -r)"
fi

check_serv

echo "
#--------------------------------------------------
# Install Jitsi Framework
#--------------------------------------------------
"
if [ "$LE_SSL" = "yes" ]; then
echo "set jitsi-meet/cert-choice	select	Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)" | debconf-set-selections
echo "jitsi-videobridge2	jitsi-videobridge/jvb-hostname	string	$JITSI_DOMAIN" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-meet/email	string $SYSADMIN_EMAIL" | debconf-set-selections
fi
echo "jitsi-meet-web-config	jitsi-meet/jaas-choice	boolean	false"  | debconf-set-selections
apt-get -y install \
                jitsi-meet \
                jibri \
                openjdk-11-jre-headless

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
    curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
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

CHD_LTST=$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)
GCMP_JSON="/etc/opt/chrome/policies/managed/managed_policies.json"

echo "# Installing Google Chrome / ChromeDriver"
if [ "$GOOGLE_ACTIVE_REPO" = "main" ]; then
    echo "Google repository already set."
else
    echo "Installing Google Chrome Stable"
    curl -s https://dl.google.com/linux/linux_signing_key.pub | \
    gpg --dearmor | tee /etc/apt/trusted.gpg.d/google-chrome-key.gpg  >/dev/null
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee "$GOOGL_REPO"
fi
apt-get -q2 update
apt-get install -yq2 google-chrome-stable
rm -rf /etc/apt/sources.list.d/dl_google_com_linux_chrome_deb.list

if [ -f /usr/local/bin/chromedriver ]; then
    echo "Chromedriver already installed."
else
    echo "Installing Chromedriver"
    wget -q https://chromedriver.storage.googleapis.com/"$CHD_LTST"/chromedriver_linux64.zip \
         -O /tmp/chromedriver_linux64.zip
    unzip -o /tmp/chromedriver_linux64.zip -d /usr/local/bin/
    chown root:root /usr/local/bin/chromedriver
    chmod 0755 /usr/local/bin/chromedriver
    rm -rf /tmp/chromedriver_linux64.zip
fi

printf "\nCheck Google Software Working...\n"
/usr/bin/google-chrome --version
/usr/local/bin/chromedriver --version | awk '{print$1,$2}'

printf "\nRemove Chrome warning...\n"
mkdir -p /etc/opt/chrome/policies/managed
echo '{ "CommandLineFlagSecurityWarningsEnabled": false }' > "$GCMP_JSON"

## JMS system tune up
if [ "$MODE" = "debug" ]; then
    bash "$PWD"/mode/jms-stu.sh -m debug
else
    bash "$PWD"/mode/jms-stu.sh
fi

echo '
########################################################################
                    Please Setup Your Installation
########################################################################
'
# MEET / JIBRI SETUP
DOMAIN="$(find /etc/prosody/conf.d/ -name \*.lua|awk -F'.cfg' '!/localhost/{print $1}'|xargs basename)"
WS_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
JB_AUTH_PASS="$(tr -dc "a-zA-Z0-9#*=" < /dev/urandom | fold -w 10 | head -n1)"
JB_REC_PASS="$(tr -dc "a-zA-Z0-9#*=" < /dev/urandom | fold -w 10 | head -n1)"
PROSODY_FILE="/etc/prosody/conf.d/$DOMAIN.cfg.lua"
PROSODY_SYS="/etc/prosody/prosody.cfg.lua"
JICOFO_SIP="/etc/jitsi/jicofo/sip-communicator.properties"
MEET_CONF="/etc/jitsi/meet/$DOMAIN-config.js"
JIBRI_CONF="/etc/jitsi/jibri/jibri.conf"
JVB2_CONF="/etc/jitsi/videobridge/config"
JVB2_SIP="/etc/jitsi/videobridge/sip-communicator.properties"
DIR_RECORD="/var/jbrecord"
REC_DIR="/home/jibri/finalize_recording.sh"
JB_NAME="Jibri Sessions"
LE_RENEW_LOG="/var/log/letsencrypt/renew.log"
MOD_LISTU="https://prosody.im/files/mod_listusers.lua"
MOD_LIST_FILE="/usr/lib/prosody/modules/mod_listusers.lua"
ENABLE_SA="yes"
GC_SDK_REL_FILE="http://packages.cloud.google.com/apt/dists/cloud-sdk-$(lsb_release -sc)/Release"
MJS_RAND_TAIL="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 4 | head -n1)"
MJS_USER="jbsync_$MJS_RAND_TAIL"
MJS_USER_PASS="$(tr -dc "a-zA-Z0-9#_*=" < /dev/urandom | fold -w 32 | head -n1)"
FQDN_HOST="fqdn"
JIBRI_XORG_CONF="/etc/jitsi/jibri/xorg-video-dummy.conf"

# Rename hostname for jitsi server
while [ "$FQDN_HOST" != "yes" ] && [ "$FQDN_HOST" != "no" ] && [ -n "$FQDN_HOST" ]
do
  printf "> Set %s as a fqdn hostname?: (yes or no)\n" "$DOMAIN" && \
  read -p "Leave empty to default to your current one ($(hostname -f)):$NL" -r FQDN_HOST
  if [ "$FQDN_HOST" = "yes" ]; then
    printf " - %s will be used as fqdn hostname, changes will show on reboot.\n\n" "$DOMAIN"
    hostnamectl set-hostname "${DOMAIN}"
    sed -i "1i ${PUBLIC_IP} ${DOMAIN}" /etc/hosts
  else
    printf " - %s will be keep.\n\n" "$(hostname -f)"
  fi
done
sleep .1
#Language
echo "## Setting up Jitsi Meet language ##
You can define the language, for a complete list of the supported languages

See here:
https://github.com/jitsi/jitsi-meet/blob/master/lang/languages.json"
printf "Jitsi Meet web interface will be set to use such language.\n\n"
sleep .1
read -p "Please set your language (Press enter to default to 'en'):$NL" -r JB_LANG
sleep .1
printf "\nWe'll take a minute to localize some UI excerpts if you need.\n\n"
sleep .1
#Participant
printf "> Do you want to translate 'Participant' to your own language?\n"
sleep .1
read -p "Leave empty to use the default one (English):$NL" -r L10N_PARTICIPANT
sleep .1
#Me
printf "\n> Do you want to translate 'me' to your own language?
This must be a really small word to present one self.
Some suggestions might be: yo (Spanish) | je (French) | ich (German)\n"
sleep .1
read -p "Leave empty to use the default one (English):$NL" -r L10N_ME

#Drop unsecure TLS
while [ "$DROP_TLS1" != "yes" ] && [ "$DROP_TLS1" != "no" ]
do
    read -p "> Do you want to drop support for unsecure protocols TLSv1.0/1.1 now: (yes or no)$NL" -r DROP_TLS1
    if [ "$DROP_TLS1" = "no" ]; then
        printf " - TLSv1.0/1.1 will remain.\n\n"
    elif [ "$DROP_TLS1" = "yes" ]; then
        printf " - TLSv1.0/1.1 will be dropped\n\n"
    fi
done
sleep .1
#Brandless  Mode
while [ "$ENABLE_BLESSM" != "yes" ] && [ "$ENABLE_BLESSM" != "no" ]
do
    read -p "> Do you want to install customized \"brandless mode\"?: (yes or no)$NL" -r ENABLE_BLESSM
    if [ "$ENABLE_BLESSM" = "no" ]; then
        printf " - Brandless mode won't be set.\n\n"
    elif [ "$ENABLE_BLESSM" = "yes" ]; then
        printf " - Brandless mode will be set.\n\n"
    fi
done
sleep .1
#Welcome Page
while [ "$ENABLE_WELCP" != "yes" ] && [ "$ENABLE_WELCP" != "no" ]
do
    read -p "> Do you want to disable the Welcome page: (yes or no)$NL" -r ENABLE_WELCP
    if [ "$ENABLE_WELCP" = "yes" ]; then
        printf " - Welcome page will be disabled.\n\n"
    elif [ "$ENABLE_WELCP" = "no" ]; then
        printf " - Welcome page will be enabled.\n\n"
    fi
done
sleep .1
#Close page
while [ "$ENABLE_CLOCP" != "yes" ] && [ "$ENABLE_CLOCP" != "no" ]
do
    read -p "> Do you want to enable the close page on room exit: (yes or no)$NL" -r ENABLE_CLOCP
    if [ "$ENABLE_CLOCP" = "yes" ]; then
        printf " - Close page will be enabled.\n\n"
    elif [ "$ENABLE_CLOCP" = "no" ]; then
        printf " - Close page will be kept disabled.\n\n"
    fi
done
sleep .1
# Set authentication method
printf "\n> Jitsi Meet Auth Method selection.\n"
PS3='Select the authentication method for your Jitsi Meet instance: '
options=("Local" "JWT" "None")
select opt in "${options[@]}"
do
    case $opt in
        "Local")
            printf "\n  > Users are created manually using prosodyctl, only moderators can open a room or launch recording.\n"
            ENABLE_SC="yes"
            break
            ;;
        "JWT")
            printf "\n  > A external app manage the token usage/creation, like RocketChat does.\n"
            ENABLE_JWT="yes"
            break
            ;;
        "None")
            printf "\n  > Everyone can access the room as moderators as there is no auth mechanism.\n"
            break
            ;;
        *) echo "Invalid option $REPLY, choose 1, 2 or 3";;
    esac
done
sleep .1
# Set jibris default resolution
printf "\n> What jibri resolution should be the default for this and all the following jibri nodes?\n"
PS3='The more resolution the more resources jibri will require to record properly: '
jib_res=("HD 720" "FHD 1080")
select res in "${jib_res[@]}"
do
    case $res in
        "HD 720")
            printf "\n  > HD (1280x720) is good enough for most cases, and requires a moderate high hw requirements.\n\n"
            JIBRI_RES="720"
            break
            ;;
        "FHD 1080")
            printf "\n  > Full HD (1920x1080) is the best resolution available, it also requires high hw requirements.\n\n"
            JIBRI_RES="1080"
            break
            ;;
        *) printf "\nInvalid option «%s», choose 1 or 2\n\n" "$REPLY"
        ;;
    esac
done
sleep .1
if [ "$JIBRI_RES" = "720" ]; then
    JIBRI_RES_CONF="\"1280x720\""
    JIBRI_RES_XORG_CONF="1280 720"
fi

if [ "$JIBRI_RES" = "1080" ]; then
    JIBRI_RES_CONF="\"1920x1080\""
    JIBRI_RES_XORG_CONF="1920 1080"
fi

#Jibri Records Access (JRA) via Nextcloud
while [ "$ENABLE_NC_ACCESS" != "yes" ] && [ "$ENABLE_NC_ACCESS" != "no" ]
do
    read -p "> Do you want to setup Jibri Records Access via Nextcloud: (yes or no)
( Please check requirements at: https://github.com/switnet-ltd/quick-jibri-installer )$NL" -r ENABLE_NC_ACCESS
    if [ "$ENABLE_NC_ACCESS" = "no" ]; then
        printf " - JRA via Nextcloud won't be enabled.\n\n"
    elif [ "$ENABLE_NC_ACCESS" = "yes" ]; then
        printf " - JRA via Nextcloud will be enabled.\n\n"
    fi
done
sleep .1
#Jigasi
if [ "$(curl -s -o /dev/null -w "%{http_code}" "$GC_SDK_REL_FILE" )" == "404" ]; then
    printf "> Sorry Google SDK doesn't have support yet for %s,
    thus, Jigasi Transcript can't be enable.\n\n" "$(lsb_release -sd)"
elif [ "$(curl -s -o /dev/null -w "%{http_code}" "$GC_SDK_REL_FILE" )" == "200" ]; then
    while [ "$ENABLE_TRANSCRIPT" != "yes" ] && [ "$ENABLE_TRANSCRIPT" != "no" ]
    do
        read -p "> Do you want to setup Jigasi Transcription: (yes or no)
( Please check requirements at: https://github.com/switnet-ltd/quick-jibri-installer )$NL" -r ENABLE_TRANSCRIPT
        if [ "$ENABLE_TRANSCRIPT" = "no" ]; then
            printf " - Jigasi Transcription won't be enabled.\n\n"
        elif [ "$ENABLE_TRANSCRIPT" = "yes" ]; then
            printf " - Jigasi Transcription will be enabled.\n\n"
        fi
    done
else
    echo "No valid option for Jigasi. Please report this to
https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi
sleep .1
#Grafana
while [ "$ENABLE_GRAFANA_DSH" != "yes" ] && [ "$ENABLE_GRAFANA_DSH" != "no" ]
do
read -p "> Do you want to setup Grafana Dashboard: (yes or no)
( Please check requirements at: https://github.com/switnet-ltd/quick-jibri-installer )$NL" -r ENABLE_GRAFANA_DSH
if [ "$ENABLE_GRAFANA_DSH" = "no" ]; then
    printf " - Grafana Dashboard won't be enabled.\n\n"
elif [ "$ENABLE_GRAFANA_DSH" = "yes" ]; then
    printf " - Grafana Dashboard will be enabled.\n\n"
fi
done
sleep .1
#Docker Etherpad
while [ "$ENABLE_DOCKERPAD" != "yes" ] && [ "$ENABLE_DOCKERPAD" != "no" ]
do
read -p "> Do you want to setup Docker Etherpad: (yes or no)$NL" -r ENABLE_DOCKERPAD
if [ "$ENABLE_DOCKERPAD" = "no" ]; then
    printf " - Docker Etherpad won't be enabled.\n"
elif [ "$ENABLE_DOCKERPAD" = "yes" ]; then
    printf " - Docker Etherpad will be enabled.\n"
fi
done
sleep .1
#Start configuration
echo '
########################################################################
                  Start Jitsi Framework configuration
########################################################################
'
JibriBrewery=JibriBrewery
INT_CONF="/usr/share/jitsi-meet/interface_config.js"
INT_CONF_ETC="/etc/jitsi/meet/$DOMAIN-interface_config.js"

ssl_wa() {
if [ "$LE_SSL" = "yes" ]; then
  systemctl stop "$1"
  certbot certonly --standalone --renew-by-default --agree-tos --email "$5" -d "$6"
  sed -i "s|/etc/jitsi/meet/$3.crt|/etc/letsencrypt/live/$3/fullchain.pem|" "$4"
  sed -i "s|/etc/jitsi/meet/$3.key|/etc/letsencrypt/live/$3/privkey.pem|" "$4"
  systemctl restart "$1"
  #Add cron
  if [ "$(crontab -l|sed 's|#.*$||g'|grep -c 'weekly certbot renew')" = 0 ];then
    crontab -l | { cat; echo "@weekly certbot renew --${2} > $LE_RENEW_LOG 2>&1"; } | crontab -
  else
    echo "Crontab seems to be already in place, skipping."
  fi
  crontab -l
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

# Configure Jvb2
sed -i "/shard.HOSTNAME/s|localhost|$DOMAIN|" /etc/jitsi/videobridge/sip-communicator.properties

# Configure Jibri
if [ "$ENABLE_SC" = "yes" ]; then
  if [ ! -f "$MOD_LIST_FILE" ]; then
  printf "\n-> Adding external module to list prosody users...\n"
  curl -s "$MOD_LISTU" > "$MOD_LIST_FILE"

  printf "Now you can check registered users with:\nprosodyctl mod_listusers\n"
    else
  printf "Prosody support for listing users seems to be enabled. \ncheck with: prosodyctl mod_listusers\n"
  fi

fi
sleep .1
#Enable jibri recording
cat  << REC-JIBRI >> "$PROSODY_FILE"

VirtualHost "recorder.$DOMAIN"
  modules_enabled = {
    "ping";
  }
  authentication = "internal_hashed"

REC-JIBRI

#Enable Jibri withelist
sed -i "s|-- muc_lobby_whitelist|muc_lobby_whitelist|" "$PROSODY_FILE"

#Fix Jibri conectivity issues
sed -i "s|c2s_require_encryption = .*|c2s_require_encryption = false|" "$PROSODY_SYS"
sed -i "/c2s_require_encryption = false/a \\
\\
consider_bosh_secure = true" "$PROSODY_SYS"

if [ -n "$L10N_PARTICIPANT" ]; then
    sed -i "s|PART_USER=.*|PART_USER=\"$L10N_PARTICIPANT\"|" jm-bm.sh
fi
if [ -n "$L10N_ME" ]; then
    sed -i "s|LOCAL_USER=.*|LOCAL_USER=\"$L10N_ME\"|" jm-bm.sh
fi


### Prosody users
prosodyctl register jibri auth."$DOMAIN" "$JB_AUTH_PASS"
prosodyctl register recorder recorder."$DOMAIN" "$JB_REC_PASS"

## JICOFO
# /etc/jitsi/jicofo/sip-communicator.properties
cat  << BREWERY >> "$JICOFO_SIP"
#org.jitsi.jicofo.auth.URL=XMPP:$DOMAIN
#org.jitsi.jicofo.auth.URL=EXT_JWT:$DOMAIN
org.jitsi.jicofo.jibri.BREWERY=$JibriBrewery@internal.auth.$DOMAIN
org.jitsi.jicofo.jibri.PENDING_TIMEOUT=90
#org.jitsi.jicofo.auth.DISABLE_AUTOLOGIN=true
BREWERY

# Jibri tweaks for /etc/jitsi/meet/$DOMAIN-config.js
sed -i "s|conference.$DOMAIN|internal.auth.$DOMAIN|" "$MEET_CONF"
#New recording implementation.
sed -i "s|// recordingService:|recordingService:|" "$MEET_CONF"
sed -i "/recordingService/,/hideStorageWarning/s|//     enabled: false,|       enabled: true,|" "$MEET_CONF"
sed -i "/hideStorageWarning: false/,/Local recording configuration/s|// },|},|" "$MEET_CONF"
sed -i "s|// liveStreamingEnabled: false,|liveStreamingEnabled: true,\\
\\
    hiddenDomain: \'recorder.$DOMAIN\',|" "$MEET_CONF"

#Setup main language
if [ -z "$JB_LANG" ] || [ "$JB_LANG" = "en" ]; then
    echo "Leaving English (en) as default language..."
    sed -i "s|// defaultLanguage: 'en',|defaultLanguage: 'en',|" "$MEET_CONF"
else
    echo "Changing default language to: $JB_LANG"
    sed -i "s|// defaultLanguage: 'en',|defaultLanguage: \'$JB_LANG\',|" "$MEET_CONF"
fi

# Recording directory
if [ ! -d "$DIR_RECORD" ]; then
    mkdir "$DIR_RECORD"
fi
chown -R jibri:jibri "$DIR_RECORD"

cat << REC_DIR > "$REC_DIR"
#!/bin/bash

RECORDINGS_DIR="$DIR_RECORD"

echo "This is a dummy finalize script" > /tmp/finalize.out
echo "The script was invoked with recordings directory $RECORDINGS_DIR." >> /tmp/finalize.out
echo "You should put any finalize logic (renaming, uploading to a service" >> /tmp/finalize.out
echo "or storage provider, etc.) in this script" >> /tmp/finalize.out

chmod -R 770 \$RECORDINGS_DIR

LJF_PATH="\$(find \$RECORDINGS_DIR -exec stat --printf="%Y\t%n\n" {} \; | sort -n -r|awk '{print\$2}'| grep -v "meta\|-" | head -n1)"
NJF_NAME="\$(find \$LJF_PATH |grep -e "-"|sed "s|\$LJF_PATH/||"|cut -d "." -f1)"
NJF_PATH="\$RECORDINGS_DIR/\$NJF_NAME"
mv \$LJF_PATH \$NJF_PATH

exit 0
REC_DIR
chown jibri:jibri "$REC_DIR"
chmod +x "$REC_DIR"

## New Jibri Config (2020)
mv "$JIBRI_CONF" ${JIBRI_CONF}-dpkg-file
cat << NEW_CONF > "$JIBRI_CONF"
// New XMPP environment config.
jibri {
    streaming {
        // A list of regex patterns for allowed RTMP URLs.  The RTMP URL used
        // when starting a stream must match at least one of the patterns in
        // this list.
        rtmp-allow-list = [
          // By default, all services are allowed
          ".*"
        ]
    }
    ffmpeg {
        resolution = $JIBRI_RES_CONF
    }
    chrome {
        // The flags which will be passed to chromium when launching
        flags = [
          "--use-fake-ui-for-media-stream",
          "--start-maximized",
          "--kiosk",
          "--enabled",
          "--disable-infobars",
          "--autoplay-policy=no-user-gesture-required",
          "--ignore-certificate-errors",
          "--disable-dev-shm-usage"
        ]
    }
    stats {
        enable-stats-d = true
    }
    call-status-checks {
        // If all clients have their audio and video muted and if Jibri does not
        // detect any data stream (audio or video) comming in, it will stop
        // recording after NO_MEDIA_TIMEOUT expires.
        no-media-timeout = 30 seconds

        // If all clients have their audio and video muted, Jibri consideres this
        // as an empty call and stops the recording after ALL_MUTED_TIMEOUT expires.
        all-muted-timeout = 10 minutes

        // When detecting if a call is empty, Jibri takes into consideration for how
        // long the call has been empty already. If it has been empty for more than
        // DEFAULT_CALL_EMPTY_TIMEOUT, it will consider it empty and stop the recording.
        default-call-empty-timeout = 30 seconds
    }
    recording {
         recordings-directory = "$DIR_RECORD"
         finalize-script = "$REC_DIR"
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
            //    sip-control-muc {
            //        domain = "domain"
            //        room-name = "room-name"
            //        nickname = "nickname"
            //    }

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

#Jibri xorg resolution
sed -i "s|[[:space:]]Virtual .*|Virtual $JIBRI_RES_XORG_CONF|" "$JIBRI_XORG_CONF"

#Create receiver user
useradd -m -g jibri "$MJS_USER"
echo "$MJS_USER:$MJS_USER_PASS" | chpasswd

#Create ssh key and restrict connections
sudo su "$MJS_USER" -c "ssh-keygen -t rsa -f ~/.ssh/id_rsa -b 4096 -o -a 100 -q -N ''"
#Allow password authentication
sed -i "s|PasswordAuthentication .*|PasswordAuthentication yes|" /etc/ssh/sshd_config
systemctl restart sshd

#Setting varibales for add-jibri-node.sh
sed -i "s|MAIN_SRV_DIST=.*|MAIN_SRV_DIST=\"$DIST\"|" add-jibri-node.sh
sed -i "s|MAIN_SRV_REPO=.*|MAIN_SRV_REPO=\"$JITSI_REPO\"|" add-jibri-node.sh
sed -i "s|MAIN_SRV_DOMAIN=.*|MAIN_SRV_DOMAIN=\"$DOMAIN\"|" add-jibri-node.sh
sed -i "s|JB_NAME=.*|JB_NAME=\"$JB_NAME\"|" add-jibri-node.sh
sed -i "s|JibriBrewery=.*|JibriBrewery=\"$JibriBrewery\"|" add-jibri-node.sh
sed -i "s|JB_AUTH_PASS=.*|JB_AUTH_PASS=\"$JB_AUTH_PASS\"|" add-jibri-node.sh
sed -i "s|JB_REC_PASS=.*|JB_REC_PASS=\"$JB_REC_PASS\"|" add-jibri-node.sh
sed -i "s|MJS_USER=.*|MJS_USER=\"$MJS_USER\"|" add-jibri-node.sh
sed -i "s|MJS_USER_PASS=.*|MJS_USER_PASS=\"$MJS_USER_PASS\"|" add-jibri-node.sh
sed -i "s|JIBRI_RES_CONF=.*|JIBRI_RES_CONF=\"$JIBRI_RES_CONF\"|" add-jibri-node.sh
sed -i "s|JIBRI_RES_XORG_CONF=.*|JIBRI_RES_XORG_CONF=\"$JIBRI_RES_XORG_CONF\"|" add-jibri-node.sh
sed -i "$(var_dlim 0_LAST),$(var_dlim 1_LAST){s|LETS: .*|LETS: $(date -R)|}" add-jibri-node.sh
echo "Last file edition at: $(grep "LETS:" add-jibri-node.sh|head -n1|awk -F'LETS:' '{print$2}')"

#-- Setting variables for add-jvb2-node.sh
g_conf_value() {
  grep "$1" "$JVB2_CONF"|sed "s|$1||"
}
JVB_HOSTNAME=$(g_conf_value JVB_HOSTNAME=)
JVB_HOST=$(g_conf_value JVB_HOST=)
JVB_PORT=$(g_conf_value JVB_PORT=)
JVB_SECRET=$(g_conf_value JVB_SECRET=)
JVB_OPTS=$(g_conf_value JVB_OPTS=)
JAVA_SYS_PROPS=$(g_conf_value JAVA_SYS_PROPS=)

g_sip_value() {
  grep "$1" "$JVB2_SIP" |cut -d "=" -f2
}
DISABLE_AWS_HARVESTER=$(g_sip_value DISABLE_AWS_HARVESTER=)
STUN_MAPPING_HARVESTER_ADDRESSES=$(g_sip_value STUN_MAPPING_HARVESTER_ADDRESSES=)
ENABLE_STATISTICS=$(g_sip_value ENABLE_STATISTICS=)
SHARD_HOSTNAME=$(g_sip_value shard.HOSTNAME=)
SHARD_DOMAIN=$(g_sip_value shard.DOMAIN=)
SHARD_PASSWORD=$(g_sip_value shard.PASSWORD=)
MUC_JID=$(g_sip_value MUC_JIDS=)

##-- Replacing on add-jvb2-node.sh
sed -i "s|JVB_HOSTNAME=.*|JVB_HOSTNAME=$JVB_HOSTNAME|" add-jvb2-node.sh
sed -i "s|JVB_HOST=.*|JVB_HOST=$JVB_HOST|" add-jvb2-node.sh
sed -i "s|JVB_PORT=.*|JVB_PORT=$JVB_PORT|" add-jvb2-node.sh
sed -i "s|JVB_SECRET=.*|JVB_SECRET=$JVB_SECRET|" add-jvb2-node.sh
sed -i "s|JVB_OPTS=.*|JVB_OPTS=$JVB_OPTS|" add-jvb2-node.sh
sed -i "s|SYS_PROPS=.*|SYS_PROPS=$JAVA_SYS_PROPS|" add-jvb2-node.sh
#-
sed -i "s|AWS_HARVEST=.*|AWS_HARVEST=$DISABLE_AWS_HARVESTER|" add-jvb2-node.sh
sed -i "s|STUN_MAPPING=.*|STUN_MAPPING=$STUN_MAPPING_HARVESTER_ADDRESSES|" add-jvb2-node.sh
sed -i "s|ENABLE_STATISTICS=.*|ENABLE_STATISTICS=$ENABLE_STATISTICS|" add-jvb2-node.sh
sed -i "s|SHARD_HOSTNAME=.*|SHARD_HOSTNAME=$SHARD_HOSTNAME|" add-jvb2-node.sh
sed -i "s|SHARD_DOMAIN=.*|SHARD_DOMAIN=$SHARD_DOMAIN|" add-jvb2-node.sh
sed -i "s|SHARD_PASS=.*|SHARD_PASS=$SHARD_PASSWORD|" add-jvb2-node.sh
sed -i "s|MUC_JID=.*|MUC_JID=$MUC_JID|" add-jvb2-node.sh

sed -i "s|MAIN_SRV_DIST=.*|MAIN_SRV_DIST=\"$DIST\"|" add-jvb2-node.sh
sed -i "s|MAIN_SRV_REPO=.*|MAIN_SRV_REPO=\"$JITSI_REPO\"|" add-jvb2-node.sh
sed -i "s|MAIN_SRV_DOMAIN=.*|MAIN_SRV_DOMAIN=\"$DOMAIN\"|" add-jvb2-node.sh
sed -i "s|MJS_USER=.*|MJS_USER=\"$MJS_USER\"|" add-jvb2-node.sh
sed -i "s|MJS_USER_PASS=.*|MJS_USER_PASS=\"$MJS_USER_PASS\"|" add-jvb2-node.sh
##--

#Tune webserver for Jitsi App control
if [ -f "$WS_CONF" ]; then
    sed -i "/# ensure all static content can always be found first/i \\\n" "$WS_CONF"
    sed -i "/# ensure all static content can always be found first/i \ \ \ \ location = \/external_api.min.js {" "$WS_CONF"
    sed -i "/# ensure all static content can always be found first/i \ \ \ \ \ \ \ \ alias \/usr\/share\/jitsi-meet\/libs\/external_api.min.js;" "$WS_CONF"
    sed -i "/# ensure all static content can always be found first/i \ \ \ \ }" "$WS_CONF"
    sed -i "/# ensure all static content can always be found first/i \\\n" "$WS_CONF"
    systemctl reload nginx
else
    echo "No app configuration done to server file, please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi
#Static avatar
if [ "$ENABLE_SA" = "yes" ] && [ -f "$WS_CONF" ]; then
    cp images/avatar2.png /usr/share/jitsi-meet/images/
    sed -i "/location \/external_api.min.js/i \ \ \ \ location \~ \^\/avatar\/\(.\*\)\\\.png {" "$WS_CONF"
    sed -i "/location \/external_api.min.js/i \ \ \ \ \ \ \ \ alias /usr/share/jitsi-meet/images/avatar2.png;" "$WS_CONF"
    sed -i "/location \/external_api.min.js/i \ \ \ \ }\\
\ " "$WS_CONF"
    sed -i "/RANDOM_AVATAR_URL_PREFIX/ s|false|\'https://$DOMAIN/avatar/\'|" "$INT_CONF"
    sed -i "/RANDOM_AVATAR_URL_SUFFIX/ s|false|\'.png\'|" "$INT_CONF"
fi
#nginx -tlsv1/1.1
if [ "$DROP_TLS1" = "yes" ];then
    printf "\nDropping TLSv1/1.1\n\n"
    sed -i "s|TLSv1 TLSv1.1||" /etc/nginx/nginx.conf
elif [ "$DROP_TLS1" = "no" ];then
    printf "\nNo TLSv1/1.1 dropping was done.\n\n"
else
    echo "No condition meet, please report to
https://github.com/switnet-ltd/quick-jibri-installer/issues "
fi
sleep .1
#================== Setup prosody conf file =================

###Setup secure rooms
if [ "$ENABLE_SC" = "yes" ]; then
    SRP_STR=$(grep -n "VirtualHost \"$DOMAIN\"" "$PROSODY_FILE" | awk -F ':' 'NR==1{print$1}')
    SRP_END=$((SRP_STR + 10))
    sed -i "$SRP_STR,$SRP_END{s|authentication = \"jitsi-anonymous\"|authentication = \"internal_hashed\"|}" "$PROSODY_FILE"
    sed -i "s|// anonymousdomain: 'guest.example.com'|anonymousdomain: \'guest.$DOMAIN\'|" "$MEET_CONF"

    #Secure room initial user
    read -p "Set username for secure room moderator:$NL" -r SEC_ROOM_USER
    read -p "Secure room moderator password:$NL" -r SEC_ROOM_PASS
    prosodyctl register "$SEC_ROOM_USER" "$DOMAIN" "$SEC_ROOM_PASS"
sleep .1
    printf "\nSecure rooms are being enabled...\n"
    echo "You'll be able to login Secure Room chat with '${SEC_ROOM_USER}' \
or '${SEC_ROOM_USER}@${DOMAIN}' using the password you just entered.
If you have issues with the password refer to your sysadmin."
    sed -i "s|#org.jitsi.jicofo.auth.URL=XMPP:|org.jitsi.jicofo.auth.URL=XMPP:|" "$JICOFO_SIP"
    sed -i "s|SEC_ROOM=.*|SEC_ROOM=\"on\"|" jm-bm.sh
fi
sleep .1
###JWT
if [ "$ENABLE_JWT" = "yes" ]; then
    printf "\nJWT auth is being setup...\n"
    if [ "$MODE" = "debug" ]; then
        bash "$PWD"/mode/jwt.sh -m debug
    else
        bash "$PWD"/mode/jwt.sh
    fi
fi
sleep .1
#Guest allow
#Change back lobby - https://community.jitsi.org/t/64769/136
if [ "$ENABLE_SC" = "yes" ];then
    cat << P_SR >> "$PROSODY_FILE"
-- #Change back lobby - https://community.jitsi.org/t/64769/136
VirtualHost "guest.$DOMAIN"
    authentication = "anonymous"
    c2s_require_encryption = false
    speakerstats_component = "speakerstats.$DOMAIN"
    main_muc = "conference.$DOMAIN"

    modules_enabled = {
      "speakerstats";
    }

P_SR
fi

#======================
# Custom settings
#Start with video muted by default
sed -i "s|// startWithVideoMuted: false,|startWithVideoMuted: true,|" "$MEET_CONF"

#Start with audio muted but admin
sed -i "s|// startAudioMuted: 10,|startAudioMuted: 1,|" "$MEET_CONF"

#Disable/enable welcome page
if [ "$ENABLE_WELCP" = "yes" ]; then
    sed -i "s|.*enableWelcomePage:.*|    enableWelcomePage: false,|" "$MEET_CONF"
elif [ "$ENABLE_WELCP" = "no" ]; then
    sed -i "s|.*enableWelcomePage:.*|    enableWelcomePage: true,|" "$MEET_CONF"
fi
#Enable close page
if [ "$ENABLE_CLOCP" = "yes" ]; then
    sed -i "s|.*enableClosePage:.*|    enableClosePage: true,|" "$MEET_CONF"
elif [ "$ENABLE_CLOCP" = "no" ]; then
    sed -i "s|.*enableClosePage:.*|    enableClosePage: false,|" "$MEET_CONF"
fi

#Add pre-join screen by default, since it improves YouTube autoplay capabilities
#pre-join screen by itself don't require autorization by moderator, don't confuse with lobby which does.
sed -i "s|// prejoinPageEnabled:.*|prejoinPageEnabled: true,|" "$MEET_CONF"

#Set HD resolution and widescreen format
sed -i "/Enable \/ disable simulcast support/i \/\/ Start QJI - Set resolution and widescreen format" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ resolution: 720," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ constraints: {" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ aspectRatio: 16 \/ 9," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ video: {" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ height: {" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 720," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 720," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 180" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ width: {" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 1280," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 1280," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 320" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ }" "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ }," "$MEET_CONF"
sed -i "/Enable \/ disable simulcast support/i \/\/ End QJI" "$MEET_CONF"

#Check config file
printf "\n# Checking %s file for errors\n" "$MEET_CONF"
CHECKJS=$(esvalidate "$MEET_CONF"| cut -d ":" -f2)
if [ -z "$CHECKJS" ]; then
    printf "\n# The %s configuration seems correct. =)\n" "$MEET_CONF"
else
    echo -e "\nWatch out!, there seems to be an issue on $MEET_CONF line:
$CHECKJS
Most of the times this is due upstream changes, please report to
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
fi

#Enable jibri services
systemctl enable jibri
systemctl enable jibri-xorg
systemctl enable jibri-icewm
restart_services
if [ "$DISABLE_LOCAL_JIBRI" = "yes" ]; then
    systemctl stop jibri*
    systemctl disable jibri
    systemctl disable jibri-xorg
    systemctl disable jibri-icewm
# Manually apply permissions since finalize_recording.sh won't be triggered under this server options.
    chmod -R 770 "$DIR_RECORD"
fi

# Fix prosody not able to read SSL Certs
chown -R root:prosody /etc/prosody/certs/
chmod -R 650 /etc/prosody/certs/

#SSL workaround
if [ "$(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
    ssl_wa nginx nginx "$DOMAIN" "$WS_CONF" "$SYSADMIN_EMAIL" "$DOMAIN"
    install_ifnot python3-certbot-nginx
else
    echo "No webserver found please report."
fi
#Brandless  Mode
if [ "$ENABLE_BLESSM" = "yes" ]; then
    echo "Custom brandless mode will be enabled."
    sed -i "s|ENABLE_BLESSM=.*|ENABLE_BLESSM=\"on\"|" jitsi-updater.sh
    if [ "$MODE" = "debug" ]; then
        bash "$PWD"/jm-bm.sh -m debug
    else
        bash "$PWD"/jm-bm.sh
    fi
fi

# Applying best practives for interface config.js
printf "\n> Setting up custom interface_config.js according to best practices."
cp "$INT_CONF" "$INT_CONF_ETC"

#Tune webserver for interface_config.js
if [ -f "$WS_CONF" ]; then
    sed -i "/external_api.js/i \\\n" "$WS_CONF"
    sed -i "/external_api.js/i \ \ \ \ location = \/interface_config.js {" "$WS_CONF"
    sed -i "/external_api.js/i \ \ \ \ \ \ \ \ alias \/etc\/jitsi\/meet\/$DOMAIN-interface_config.js;" "$WS_CONF"
    sed -i "/external_api.js/i \ \ \ \ }" "$WS_CONF"
    sed -i "/external_api.js/i \\\n" "$WS_CONF"
    systemctl reload nginx
else
    echo "No interface_config.js configuration done to server file, please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues"
fi
#JRA via Nextcloud
if [ "$ENABLE_NC_ACCESS" = "yes" ]; then
    printf "\nJRA via Nextcloud will be enabled."
    if [ "$MODE" = "debug" ]; then
        bash "$PWD"/jra_nextcloud.sh -m debug
    else
        bash "$PWD"/jra_nextcloud.sh
    fi
fi
sleep .1

#Grafana Dashboard
if [ "$ENABLE_GRAFANA_DSH" = "yes" ]; then
    printf "\nGrafana Dashboard will be enabled."
    if [ "$MODE" = "debug" ]; then
        bash "$PWD"/grafana.sh -m debug
    else
        bash "$PWD"/grafana.sh
    fi
fi
sleep .1
#Docker Etherpad
if [ "$ENABLE_DOCKERPAD" = "yes" ]; then
    printf "\nDocker Etherpad will be enabled."
    if [ "$MODE" = "debug" ]; then
        bash "$PWD"/etherpad-docker.sh -m debug
    else
        bash "$PWD"/etherpad-docker.sh
    fi
fi
sleep .1
#Prevent JMS conecction issue
if [ -z "$(awk "/127.0.0.1/&&/$DOMAIN/{print\$1}" /etc/hosts)" ];then
    sed -i "/127.0.0.1/a \\
127.0.0.1       $DOMAIN" /etc/hosts
else
  echo "Local host already in place..."
fi

check_snd_driver

echo "
########################################################################
                    Installation complete!!
           for customized support: http://switnet.net
########################################################################
"
apt-get -y autoremove
apt-get autoclean

echo "Rebooting in..."
wait_seconds 15
}  > >(tee -a qj-installer.log) 2> >(tee -a qj-installer.log >&2)
reboot
