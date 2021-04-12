#!/bin/bash
# JVB2 Node Aggregator
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.

### 0_LAST EDITION TIME STAMP ###
# LETS: AUTOMATED_EDITION_TIME
### 1_LAST EDITION ###

#Make sure the file name is the required one
if [ ! "$(basename $0)" = "add-jvb2-node.sh" ]; then
    echo "For most cases naming won't matter, for this one it does."
    echo "Please use the original name for this script: \`add-jvb2-node.sh', and run again."
    exit
fi

while getopts m: option
do
    case "${option}"
    in
        m) MODE=${OPTARG};;
        \?) echo "Usage: sudo ./add-jvb2-node.sh [-m debug]" && exit;;
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

JVB_HOSTNAME=TBD
JVB_HOST=TBD
JVB_PORT=TBD
JVB_SECRET=TBD
JVB_OPTS=TBD
SYS_PROPS=TBD
AWS_HARVEST=TBD
STUN_MAPPING=TBD
ENABLE_STATISTICS=TBD
SHARD_HOSTNAME=TBD
SHARD_DOMAIN=TBD
SHARD_PASS=TBD
MUC_JID=TBD

MJS_USER=TBD
MJS_USER_PASS=TBD
START=0
LAST=TBD

THIS_SRV_DIST=$(lsb_release -sc)
JITSI_REPO=$(apt-cache policy | grep http | grep jitsi | grep stable | awk '{print $3}' | head -n 1 | cut -d "/" -f1)
JVB2_CONF="/etc/jitsi/videobridge/config"
JVB2_NCONF="/etc/jitsi/videobridge/jvb.conf"
JVB2_SIP="/etc/jitsi/videobridge/sip-communicator.properties"
#PUBLIC_IP="$(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short)"
NJN_RAND_TAIL="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w 4 | head -n1)"
NJN_USER="jvbnode${ADDUP}_${NJN_RAND_TAIL}"
NJN_USER_PASS="$(tr -dc "a-zA-Z0-9#_*=" < /dev/urandom | fold -w 32 | head -n1)"
#GITHUB_RAW="https://raw.githubusercontent.com"
#GIT_REPO="switnet-ltd/quick-jibri-installer"
### 1_VAR_DEF

# sed limiters for add-jvb2-node.sh variables
var_dlim() {
    grep -n $1 add-jvb2-node.sh|head -n1|cut -d ":" -f1
}

check_var() {
    if [ -z "$2" ]; then
        echo -e "Check if variable $1 is set: \xE2\x9C\x96 \nExiting..."
        exit
    else
        echo -e "Check if variable $1 is set: \xE2\x9C\x94"
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
    echo "Please use the same OS for the JVB2 setup on both servers."
    echo "This server is based on: $THIS_SRV_DIST"
    echo "The main server record claims is based on: $MAIN_SRV_DIST"
    exit
fi

#Check system resources
echo "Verifying System Resources:"
if [ "$(nproc --all)" -lt 4 ];then
  echo "
Warning!: The system do not meet the CPU recomendations for a JVB node for heavy loads.
>> We recommend 4 cores/threads for JVB2!
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
Warning!: The system do not meet the CPU recomendations for a JVB node for heavy loads.
>> We recommend 8GB RAM for JVB2!
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
    echo "We highly advice to increase the resources in order to install this JVB2 node."
    while [[ "$CONTINUE_LOW_RES" != "yes" && "$CONTINUE_LOW_RES" != "no" ]]
    do
    read -p "> Do you want to continue?: (yes or no)"$'\n' -r CONTINUE_LOW_RES
    if [ "$CONTINUE_LOW_RES" = "no" ]; then
            echo "See you next time with more resources!..."
            exit
    elif [ "$CONTINUE_LOW_RES" = "yes" ]; then
            echo "Please keep in mind that we might not support underpowered nodes."
    fi
    done
fi

echo "
#-----------------------------------------------------------------------
# Checking initial necessary variables...
#-----------------------------------------------------------------------"

check_var JVB_HOSTNNAME "$JVB_HOSTNAME"
if [ -z $JVB_HOST ]; then
  echo "JVB_HOST is empty, but it may be ok for it to be empty, skipping empty test."
else
  check_var JVB_HOST "$JVB_HOST"
fi
check_var JVB_PORT "$JVB_PORT"
check_var JVB_SECRET "$JVB_SECRET"
check_var JVB_OPTS "$JVB_OPTS"
check_var SYS_PROPS "$SYS_PROPS"
check_var AWS_HARVEST "$AWS_HARVEST"
check_var STUN_MAPPING "$STUN_MAPPING"
check_var ENABLE_STATISTICS "$ENABLE_STATISTICS"
check_var SHARD_HOSTNAME "$SHARD_HOSTNAME"
check_var SHARD_DOMAIN "$SHARD_DOMAIN"
check_var SHARD_PASS "$SHARD_PASS"
check_var MUC_JID "$MUC_JID"
check_var MAIN_SRV_DOMAIN "$MAIN_SRV_DOMAIN"

# Rename hostname for each jvb2 node
hostnamectl set-hostname "jvb${ADDUP}.${MAIN_SRV_DOMAIN}"
sed -i "1i 127.0.0.1 jvb${ADDUP}.${MAIN_SRV_DOMAIN}" /etc/hosts

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

# Requirements
echo "We'll start by installing system requirements this may take a while please be patient..."
apt-get update -q2
apt-get dist-upgrade -yq2

apt-get -y install \
                    apt-show-versions \
                    bmon \
                    curl \
                    git \
                    htop \
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

echo "
#--------------------------------------------------
# Install JVB2
#--------------------------------------------------
"
echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string $MAIN_SRV_DOMAIN" | debconf-set-selections

apt-get -y install \
                    jitsi-videobridge2 \
                    openjdk-8-jre-headless

echo '
########################################################################
                        Start JVB2 configuration
########################################################################
'

mv $JVB2_CONF ${JVB2_CONF}-dpkg-file

## JVB2 - CONFIG
cat << JVB2_CONF > $JVB2_CONF
# Jitsi Videobridge settings

# sets the XMPP domain (default: none)
JVB_HOSTNAME=$JVB_HN

# sets the hostname of the XMPP server (default: domain if set, localhost otherwise)
JVB_HOST=$JVB_HOST

# sets the port of the XMPP server (default: 5275)
JVB_PORT=$JVB_PORT

# sets the shared secret used to authenticate to the XMPP server
JVB_SECRET=$JVB_SECRET

# extra options to pass to the JVB daemon
JVB_OPTS=$JVB_OPTS

# adds java system props that are passed to jvb (default are for home and logging config file)
JAVA_SYS_PROPS=$SYS_PROPS

JVB2_CONF


mv $JVB2_SIP $JVB2_SIP-dpkg-file
## JVB2 - SIP
cat << JVB2_SIP > $JVB2_SIP
# Legacy conf file, new format already at
# /etc/jitsi/videobridge/jvb.conf
# --add-jvb2-node.sh
JVB2_SIP

echo -e "\n---- Setting new config format for jvb2 node. ----"
sed -i '${/\}/d;}' $JVB2_NCONF
cat << JVB2 >> $JVB2_NCONF
    stats {
      # Enable broadcasting stats/presence in a MUC
      enabled = true
      transports = [
        { type = "muc" }
      ]
    }

    apis {
      xmpp-client {
        configs {
          # Connect to the first XMPP server
          xmpp-server-$ADDUP {
            hostname="$MAIN_SRV_DOMAIN"
            domain = "auth.$MAIN_SRV_DOMAIN"
            username = "jvb"
            password = "$SHARD_PASS"
            muc_jids = "JvbBrewery@internal.auth.$MAIN_SRV_DOMAIN"
            # The muc_nickname must be unique across all jitsi-videobridge instances
            muc_nickname = "jvb2-$ADDUP"
            disable_certificate_verification = true
        }
      }
    }
  }
}
JVB2

echo -e "\n---- Create random nodesync user ----"
useradd -m -g jitsi $NJN_USER
echo "$NJN_USER:$NJN_USER_PASS" | chpasswd

echo -e "\n---- We'll connect to main server ----"
read -n 1 -s -r -p "Press any key to continue..."$'\n'
sudo su $NJN_USER -c "ssh-keygen -t rsa -f ~/.ssh/id_rsa -b 4096 -o -a 100 -q -N ''"
echo "Remote pass: $MJS_USER_PASS"
ssh-keyscan -t rsa $MAIN_SRV_DOMAIN >> ~/.ssh/known_hosts
ssh $MJS_USER@$MAIN_SRV_DOMAIN sh -c "'cat >> .ssh/authorized_keys'" < /home/$NJN_USER/.ssh/id_rsa.pub
sudo su $NJN_USER -c "ssh-keyscan -t rsa $MAIN_SRV_DOMAIN >> /home/$NJN_USER/.ssh/known_hosts"

echo "Writting last node number..."
sed -i "$(var_dlim 0_VAR),$(var_dlim 1_VAR){s|LAST=.*|LAST=$ADDUP|}" add-jvb2-node.sh
sed -i "$(var_dlim 0_LAST),$(var_dlim 1_LAST){s|LETS: .*|LETS: $(date -R)|}" add-jvb2-node.sh
echo "Last file edition at: $(grep "LETS:" add-jvb2-node.sh|head -n1|awk -F'LETS:' '{print$2}')"

#Enable jvb2 services
systemctl enable jitsi-videobridge2.service
systemctl restart jitsi-videobridge2.service

echo -e "\nSending updated add-jvb2-node.sh file to main server sync user...\n"
cp $PWD/add-jvb2-node.sh /tmp
sudo -u $NJN_USER scp /tmp/add-jvb2-node.sh $MJS_USER@$MAIN_SRV_DOMAIN:/home/$MJS_USER/
rm $PWD/add-jvb2-node.sh /tmp/add-jvb2-node.sh

echo "
########################################################################
                        Node addition complete!!

                               IMPORTANT:
   The updated version of this file has been sent to the main server
    at the sync user home directory, please use that one in order to
  install new nodes. For security reason this version has been deleted
                          from this very node.

               For customized support: http://switnet.net
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
