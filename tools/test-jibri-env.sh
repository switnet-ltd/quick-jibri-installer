#!/bin/bash
# Simple Jibri Env tester
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
                  Welcome to Jibri Environment Tester
########################################################################
                    by Software, IT & Networks Ltd
\n'

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

JITSI_REPO=$(apt-cache policy | grep http | grep jitsi | grep stable | awk '{print $3}' | head -n 1 | cut -d "/" -f1)
SND_AL_MODULE=$(lsmod | awk '{print$1}'| grep snd_aloop)
HWE_VIR_MOD=$(apt-cache madison linux-modules-extra-virtual-hwe-$(lsb_release -sr) 2>/dev/null|head -n1|grep -c "extra-virtual-hwe")

echo "Checking for updates...."
apt -q2 update
apt -yq2 install apt-show-versions

echo -e "\n# Check repository\n"
if [ -z $JITSI_REPO ]; then
    echo "No repository detected, wait whaaaat?..."
else
    echo "This installation is using the \"$JITSI_REPO\" repository."
fi

echo -e "\n# Check latest updates for jibri\n"
if [ "$(dpkg-query -W -f='${Status}' jibri 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo "Jibri is installed, checking version:"
    apt-show-versions jibri
else
    echo "Wait!, jibri is not installed on this system using apt, exiting..."
    exit
fi

echo -e "\nAttempting (any possible) jibri upgrade!"
apt -y install --only-upgrade jibri

echo -e "\n# Test kernel modules\n"
if [ -z $SND_AL_MODULE ]; then
    echo -e "No module snd_aloop detected.\nIf you just installed a new kernel, \
please try rebooting.\nFor now wait 'til the end of the recommended kernel installation."
  echo "# Check and Install HWE kernel if possible..."
  if [ "$HWE_VIR_MOD" == "1" ]; then
      apt-get -y install \
      linux-image-generic-hwe-$(lsb_release -sr) \
      linux-modules-extra-virtual-hwe-$(lsb_release -sr)
    else
      apt-get -y install \
      linux-modules-extra-$(uname -r)
  fi
else
    echo -e "Great!\nModule snd-aloop found!"
fi
echo -e "\n# Test .asoundrc file\n"
ASRC_MASTER="https://raw.githubusercontent.com/jitsi/jibri/master/resources/debian-package/etc/jitsi/jibri/asoundrc"
ASRC_INSTALLED="/home/jibri/.asoundrc"
ASRC_MASTER_MD5SUM=$(curl -sL $ASRC_MASTER | md5sum | cut -d ' ' -f 1)
ASRC_INSTALLED_MD5SUM=$(md5sum $ASRC_INSTALLED | cut -d ' ' -f 1)

if [ "$ASRC_MASTER_MD5SUM" == "$ASRC_INSTALLED_MD5SUM" ]; then
    echo "Seems to be using the latest asoundrc file available!"
else
    echo "asoundrc files differ, if you have errors, you might wanna check this file!"
fi

echo -e "\n# Old or new config (ToDo)\n"

echo -e "What config version is this using?"
echo -e "(Not implemented yet)"

echo -e "\nJibri Test complete, thanks for testing.\n"
