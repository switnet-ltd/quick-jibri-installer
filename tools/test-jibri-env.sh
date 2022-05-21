#!/bin/bash
# Simple Jibri Env tester
# SwITNet Ltd © - 2022, https://switnet.net/
# GNU GPLv3 or later.

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

echo -e '
########################################################################
                  Welcome to Jibri Environment Tester
########################################################################
                    by Software, IT & Networks Ltd
\n'

#Check if user is root
if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

echo "Checking for updates...."
apt-get -q2 update
apt-get -yq2 install apt-show-versions \
                     curl

check_google_binaries() {
if [ -z "$2" ]; then
  echo "Warning: No $1 doesn't seem installed"
else
  echo "$2"
fi
}

# True if $1 is greater than $2
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

JITSI_REPO="$(apt-cache policy | grep http | grep jitsi | grep stable | awk '{print $3}' | head -n 1 | cut -d "/" -f1)"
SND_AL_MODULE=$(lsmod | awk '{print$1}'| grep snd_aloop)
HWE_VIR_MOD="$(apt-cache madison linux-image-generic-hwe-"$(lsb_release -sr)" 2>/dev/null|head -n1|grep -c hwe-"$(lsb_release -sr)")"
CONF_JSON="/etc/jitsi/jibri/config.json"
JIBRI_CONF="/etc/jitsi/jibri/jibri.conf"
JMS_DOMAIN="$(awk -F '"' '/xmpp-domain/{print$2}' "$JIBRI_CONF")"
CHDB="$(whereis chromedriver | awk '{print$2}')"
CHD_VER_LOCAL="$($CHDB --version 2>/dev/null| awk '{print$1,$2}')"
GOOGL_VER_LOCAL="$(/usr/bin/google-chrome --version 2>/dev/null)"
CHD_VER_2D="$(echo "$CHD_VER_LOCAL"|awk '{print$2}'|cut -d "." -f 1,2)"
GOOGL_VER_2D="$(echo "$GOOGL_VER_LOCAL"|awk '{print$3}'|cut -d "." -f 1,2)"
CHD_LTST="$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)"
CHD_LTST_2D="$(echo "$CHD_LTST"|cut -d "." -f 1,2)"

#T1
echo -e "\n#1 -- Check repository --\n"
if [ -z "$JITSI_REPO" ]; then
    echo "No repository detected, wait whaaaat?..."
    while [[ "$CONT_TEST" != "yes" && "$CONT_TEST" != "no" ]]
    do
      read -p "> Do you still want to continue the test?: (yes or no)"$'\n' -r CONT_TEST
      if [ "$CONT_TEST" = "no" ]; then
        echo "Exiting..."
        exit
      elif [ "$CONT_TEST" = "yes" ]; then
        echo "Hmm, seems there won't be anything to test, continuing anyway..."
        T1=0
      fi
    done
else
    echo "This installation is using the \"$JITSI_REPO\" repository."
    T1=1
fi

#T2
echo -e "\n#2 -- Check latest updates for jibri --\n"
if [ "$(dpkg-query -W -f='${Status}' jibri 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo "Jibri is installed, checking version:"
    apt-show-versions jibri
else
    echo "Wait!, jibri is not installed on this system using apt, exiting..."
    exit
fi

if [ "$(apt-show-versions jibri | grep -c "uptodate")" = "1" ]; then
    echo -e "Jibri is already up to date: \xE2\x9C\x94"
else
    echo -e "\nAttempting jibri upgrade!"
    apt-get -y install --only-upgrade jibri
fi
T2=1

#T3
echo -e "\n#3 -- Check Google Chrome/driver software.  --\n"
check_google_binaries "Google Chrome" "$GOOGL_VER_LOCAL"
check_google_binaries "Chromedriver" "$CHD_VER_LOCAL"

if [ -n "$CHD_VER_LOCAL" ] && [ -n "$GOOGL_VER_LOCAL" ]; then
# Chrome upgrade process
  if [ "$(apt-show-versions google-chrome-stable | grep -c "uptodate")" = "1" ]; then
    echo -e "Google Chrome is already up to date: \xE2\x9C\x94"
  else
    echo -e "\nAttempting Google Chrome upgrade!"
    apt-get -yq install --only-upgrade google-chrome-stable
  fi
# Only upgrade chromedriver if it's on a lower version, not just a different one.
  if [ "$CHD_VER_2D" = "$GOOGL_VER_2D" ]; then
      echo -e "\nChromedriver version seems according to Google Chrome: \xE2\x9C\x94"
      T3=1
      elif version_gt "$GOOGL_VER_2D" "$CHD_VER_2D" && \
      [ "$GOOGL_VER_2D" = "$CHD_LTST_2D" ]; then
          echo -e "\nAttempting  Chromedriver update!"
          wget -q https://chromedriver.storage.googleapis.com/"$CHD_LTST"/chromedriver_linux64.zip \
               -O /tmp/chromedriver_linux64.zip
          unzip -o /tmp/chromedriver_linux64.zip -d /usr/local/bin/
          chown root:root "$CHDB"
          chmod 0755 "$CHDB"
          rm -rf /tpm/chromedriver_linux64.zip
          if [ "$($CHDB -v | awk '{print $2}'|cut -d "." -f 1,2)" = "$GOOGL_VER_2D" ]; then
              echo "Successful update"
              T3=1
          else
              echo "Something might gone wrong on the update process, please report."
              T3=0
          fi
      else
      T3=0
  fi
 else
  T3=0
fi

#T4
echo -e "\n#4 -- Test kernel modules --\n"
if [ -z "$SND_AL_MODULE" ]; then
#First make sure the recommended kernel is installed.
  if [ "$HWE_VIR_MOD" = "1" ]; then
      apt-get -y install \
      linux-image-generic-hwe-"$(lsb_release -sr)"
      else
      apt-get -y install \
      linux-image-generic \
      linux-modules-extra-"$(uname -r)"
  fi
    echo -e "\nNo module snd_aloop detected. \xE2\x9C\x96 <== IMPORTANT! \nCurrent kernel: $(uname -r)\n"
    echo -e "\nIf you just installed a new kernel, \
please try rebooting.\nFor now wait 'til the end of the recommended kernel installation."
  echo "# Check and Install HWE kernel if possible..."
  if uname -r | grep -q aws;then
  KNL_HWE="$(apt-cache madison linux-image-generic-hwe-"$(lsb_release -sr)"|awk 'NR==1{print$3}'|cut -d "." -f1-4)"
  KNL_MENU="$(awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg|awk '!/recovery/&&/generic/{print$3,$4}'|grep "$KNL_HWE")"
      if [ -n "$KNL_MENU" ];then
      echo -e "\nSeems you are using an AWS kernel \xE2\x9C\x96 <== IMPORTANT! \nYou might consider modify your grub (/etc/default/grub) to use the following:" && \
      echo -e "\n > $KNL_MENU"
      fi
  fi
  T4=0
else
    echo -e "Great!, module snd-aloop found. \xE2\x9C\x94"
    T4=1
fi

#T5
echo -e "\n#5 -- Test .asoundrc file --\n"
ASRC_MASTER="https://raw.githubusercontent.com/jitsi/jibri/master/resources/debian-package/etc/jitsi/jibri/asoundrc"
ASRC_INSTALLED="/home/jibri/.asoundrc"
ASRC_MASTER_MD5SUM="$(curl -sL "$ASRC_MASTER" | md5sum | cut -d ' ' -f 1)"
ASRC_INSTALLED_MD5SUM="$(md5sum "$ASRC_INSTALLED" | cut -d ' ' -f 1)"

if [ "$ASRC_MASTER_MD5SUM" == "$ASRC_INSTALLED_MD5SUM" ]; then
    echo -e "Seems to be using the latest asoundrc file available. \xE2\x9C\x94"
    T5=1
else
    echo -e "asoundrc files differ, if you have errors, you might wanna check this file \xE2\x9C\x96"
    T5=0
fi

#T6
echo -e "\n#6 -- Old or new config --\n"

echo -e "What config version is this using?"
if [ -f "${CONF_JSON}"_disabled ] && \
   [ -f "$JIBRI_CONF" ] && \
   [ -f "$JIBRI_CONF"-dpkg-file ]; then
    echo -e "\n> This jibri config has been upgraded already. \xE2\x9C\x94 \n\nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
T6=1
elif [ ! -f "$CONF_JSON" ] && \
     [ -f "$JIBRI_CONF" ] && \
     [ -f "${JIBRI_CONF}"-dpkg-file ]; then
    echo -e "\n> This jibri seems to be running the latest configuration already. \xE2\x9C\x94 \n\nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
T6=1
elif [ -f "${CONF_JSON}" ] && \
     [ -f "$JIBRI_CONF" ]; then
    echo -e "\n> This jibri config seems to be candidate for upgrading. \xE2\x9C\x96 \nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
T6=0
fi

#T6.1
echo -e "\n#6.1 -- Check for specific Chrome flag --\n"
if [ "$(grep -c "ignore-certificate-errors"  $JIBRI_CONF)" != 0 ]; then
    echo -e "\n> Seems you have the \"--ignore-certificate-errors\" flag required for Chrome v88 and later. \xE2\x9C\x94 \n\nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
T6_1="0.1"
else
echo -e "\n> The jibri config may be missing the required chrome flags. \xE2\x9C\x96 \nPlease check:\n https://github.com/switnet-ltd/quick-jibri-installer/blob/master/quick_jibri_installer.sh#L820 \n\nIf you think there maybe an error on checking you current jibri configuration.\nPlease report this to \
https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
T6_1=0
fi

#T7
echo -e "\n#7 -- Check for open communication port among Jibri and JMS --\n"
if ! nc -z -v -w5 "$JMS_DOMAIN" 5222 ; then
  echo -e "Connection failed! \xE2\x9C\x96\n > You might want to check both Jibri & JMS firewall rules (TCP 5222)."
  T7=0
else
  echo -e "Connection succeeded! \xE2\x9C\x94\n"
  T7=1
fi

TEST_TOTAL=$(awk "BEGIN{ print $T1 + $T2 + $T3 + $T4 + $T5 + $T6 + $T6_1 + $T7 }")
echo "
##############################
     \
Score: $TEST_TOTAL out of 7.1
##############################
"
echo -e "\nJibri Test complete, thanks for testing.\n"
