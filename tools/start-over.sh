#!/bin/bash
#Start over


while getopts m: option
do
    case "${option}"
    in
        m) MODE=${OPTARG};;
        \?) echo "Usage: sudo ./start-over.sh [-m debug]" && exit;;
    esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
  set -x
fi

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

wait_seconds() {
secs=$(($1))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}
purge_debconf() {
  echo PURGE | debconf-communicate $1
}

echo "We are about to remove and clean all the jitsi-meet plaform bits and pieces...
Please make sure you have backed up anything you don't want to loose."

echo "
# WARGNING #: This is only recommended if you want to start over a failed installation,
or plain and simple remove jitsi from your system."

while [[ "$CONTINUE_PURGE1" != "yes" && "$CONTINUE_PURGE1" != "no" ]]
do
read -p "> Do you want to continue?: (yes or no)"$'\n' -r CONTINUE_PURGE1
if [ "$CONTINUE_PURGE1" = "no" ]; then
    echo "  Good, see you next time..."
    exit
elif [ "$CONTINUE_PURGE1" = "yes" ]; then
    echo ""
fi
done

echo "Let me ask just one more time..."
while [[ "$CONTINUE_PURGE2" != "yes" && "$CONTINUE_PURGE2" != "no" ]]
do
read -p "> Do you want to continue?: (yes or no)"$'\n' -r CONTINUE_PURGE2
if [ "$CONTINUE_PURGE2" = "no" ]; then
    echo "  Good, see you next time..."
    exit
elif [ "$CONTINUE_PURGE2" = "yes" ]; then
    echo "No going back, lets start..."
    wait_seconds 3
fi
done

#Purging all jitsi meet packages
apt-get -y purge jibri \
                 jicofo \
                 jigasi \
                 jitsi-meet \
                 jitsi-meet-web \
                 jitsi-meet-web-config \
                 jitsi-meet-prosody \
                 jitsi-meet-turnserver \
                 jitsi-videobridge2 \
                 prosody

#Cleaning packages
apt-get -y autoremove
apt-get clean

#Removing residual files
rm -r /etc/jitsi
rm -r /opt/jitsi
rm -r /usr/share/jicofo
rm -r /usr/share/jitsi-*

#Purging debconf db
purge_debconf jicofo
purge_debconf jigasi
purge_debconf jitsi-meet
purge_debconf jitsi-meet-prosody
purge_debconf jitsi-meet-turnserver
purge_debconf jitsi-meet-web-config
purge_debconf jitsi-videobridge2

echo "We are done..."
