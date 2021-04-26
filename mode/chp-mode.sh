#!/bin/bash
# Custom High Performance Jitsi conf
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have privileges!"
   exit 0
fi

while getopts m: option
do
	case "${option}"
	in
		m) MODE=${OPTARG};;
		\?) echo "Usage: sudo ./chp-mode.sh [-m debug]" && exit;;
	esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

wait_seconds() {
secs=$(($1))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}
set_once() {
if [ -z "$(awk '!/^ *#/ && NF {print}' "$2"|grep $(echo $1|awk -F '=' '{print$1}'))" ]; then
  echo "Setting "$1" on "$2"..."
  echo "$1" | tee -a "$2"
else
  echo " \"$(echo $1|awk -F '=' '{print$1}')\" seems present, skipping setting this variable"
fi
}
# True if $1 is greater than $2
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }


LTS_REL="$(lsb_release -d | awk '{print$4}')"
DOMAIN="$(ls /etc/prosody/conf.d/ | awk -F'.cfg' '!/localhost/{print $1}' | awk '!NF || !seen[$0]++')"
JVB_LOG_POP="/etc/jitsi/videobridge/logging.properties"
JVB_RC="/usr/share/jitsi-videobridge/lib/videobridge.rc"
JICOFO_LOG_POP="/etc/jitsi/videobridge/logging.properties"
MEET_LOG_CONF="/usr/share/jitsi-meet/logging_config.js"
MEET_CONF="/etc/jitsi/meet/$DOMAIN-config.js"
MEET_CONF_HP="/etc/jitsi/meet/${DOMAIN}-chp-config.js"
INT_CONF_JS="/etc/jitsi/meet/${DOMAIN}-interface_config.js"
INT_CONF_JS_HP="/etc/jitsi/meet/${DOMAIN}-chp-interface_config.js"
WS_CONF="/etc/nginx/sites-enabled/$DOMAIN.conf"
FSTAB="/etc/fstab"
CHAT_DISABLED="TBD"

if [ -f $MEET_CONF_HP ] || [ -f $INT_CONF_JS_HP ]; then
echo "
This script can't be run multiple times on the same system,
idempotence not guaranteed, exiting..."
exit
fi

if [ -z $LTS_REL ] || [ -z $DOMAIN ];then
echo "This system isn't suitable to configure."
exit
  else
echo "This system seems suitable to configure..."
fi
echo "What does this script do?
Overview:
 - Disables swap partition
 - Tunes,
   * Some kernel networking settings
   * nginx connections number
   * jvb2 logging
   * jicofo logging
   * meet logging
 - Modify UX by changing session configuration & toolbar.
 - Disable browsers not compatible with CHP,
   * Safari
   * Firefox*
"

echo "# Note: As for January 2021 Firefox can't handle correctly widescreen sizing
# on lower resolution than HD (nHD & qHD), setting as incompatible for now.
# (If you know this is no longer the case. Please report it to \
https://github.com/switnet-ltd/quick-jibri-installer/issues)
"

#Tools to consider
##Profiling
#https://github.com/jvm-profiling-tools/async-profiler

while [[ "$CONTINUE_HP" != "yes" && "$CONTINUE_HP" != "no" ]]
    do
    read -p "> Do you want to continue?: (yes or no)"$'\n' -r CONTINUE_HP
    if [ "$CONTINUE_HP" = "no" ]; then
            echo "See you next time!..."
            exit
    elif [ "$CONTINUE_HP" = "yes" ]; then
            echo "Good, then let's get it done..."
    fi
done

# Video resolution selector
echo "
#--------------------------------------------------
# Conference widescreen video resolution.
#--------------------------------------------------
"
echo "If you are using a high volume of users we recommend to use nHD (640x360),
or at most qHD (960x540) resolution as default, since bandwith increase
exponentially with the more concurrent users on a meeting.
Either way, choose your desired video resolution.
"

PS3='Select the desired resolution for high performance mode: '
options=("nHD - 640x360" "qHD - 960x540" "HD - 1280x720")
select opt in "${options[@]}"
do
    case $opt in
        "nHD - 640x360")
            echo -e "\n  > Setting 640x360 resolution.\n"
            VID_RES="360"
            break
            ;;
        "qHD - 960x540")
            echo -e "\n  > Setting 960x540 resolution.\n"
            VID_RES="540"
            break
            ;;
        "HD - 1280x720")
            echo -e "\n  > Setting 1280x720 resolution.\n"
            VID_RES="720"
            break
            ;;
        *) echo "Invalid option $REPLY, choose 1, 2 or 3";;
    esac
done

echo "
# Disable Chat?
> In case you have your own chat solution for the meetings you might
wanna disable Jitsi's chat from the toolbox.
"
while [[ "$CHAT_DISABLED" != "yes" && \
         "$CHAT_DISABLED" != "no" && \
         "$CHAT_DISABLED" != "" ]]
do
echo "> Do you want to disable jitsi's built-in chat?: (yes or no)"
read -p "(Also you can leave empty to disable)"$'\n' CHAT_DISABLED
if [ "$CHAT_DISABLED" = "no" ]; then
	echo -e "-- Jitsi's built-in chat will be kept active.\n"
elif [ "$CHAT_DISABLED" = "yes" ] || [ -z "$CHAT_DISABLED" ]; then
	echo -e "-- Jitsi's built-in chat will be disabled. \n"
fi
done

#SYSTEM
##Disable swap
swapoff -a
sed -ir  '/\sswap\s/s/^#?/#/' $FSTAB

##Kernel
#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/5/html/tuning_and_optimizing_red_hat_enterprise_linux_for_oracle_9i_and_10g_databases/sect-oracle_9i_and_10g_tuning_guide-adjusting_network_settings-changing_network_kernel_settings
sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=262144
sysctl -w net.core.wmem_max=262144
set_once "net.core.rmem_default=262144" "/etc/sysctl.conf"
set_once "net.core.wmem_default=262144" "/etc/sysctl.conf"
set_once "net.core.rmem_max=262144" "/etc/sysctl.conf"
set_once "net.core.wmem_max=262144" "/etc/sysctl.conf"

#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/reduce_tcp_performance_spikes
sysctl -w net.ipv4.tcp_timestamps=0
set_once "net.ipv4.tcp_timestamps=0" "/etc/sysctl.conf"

#https://bugzilla.redhat.com/show_bug.cgi?id=1283676
sysctl -w net.core.netdev_max_backlog=100000
set_once "net.core.netdev_max_backlog=100000" "/etc/sysctl.conf"

##nginx
sed -i "s|worker_connections.*|worker_connections 2000;|" /etc/nginx/nginx.conf

#Missing docs
#sysctl -w net.ipv4.tcp_low_latency=1

#JVB2
##Loose up logging
# https://community.jitsi.org/t/23641/13
sed -i "/java.util.logging.FileHandler.level/s|ALL|WARNING|g" $JVB_LOG_POP
sed -i "s|^.level=INFO|.level=WARNING|" $JVB_LOG_POP
sed -i "/VIDEOBRIDGE_MAX_MEMORY=/i \ VIDEOBRIDGE_MAX_MEMORY=8192m" $JVB_RC

#JICOFO
sed -i "/java.util.logging.FileHandler.level/s|ALL|OFF|g" $JICOFO_LOG_POP
sed -i "s|^.level=INFO|.level=WARNING|" $JICOFO_LOG_POP

#MEET
sed -i "s|defaultLogLevel:.*|defaultLogLevel: 'error',|" $MEET_LOG_CONF
sed -i "/TraceablePeerConnection.js/s|info|error|" $MEET_LOG_CONF
sed -i "/CallStats.js/s|info|error|" $MEET_LOG_CONF
sed -i "/strophe.util.js/s|log|error|" $MEET_LOG_CONF

#UX - Room settings and interface
## config.js
cp $MEET_CONF $MEET_CONF_HP
sed -i "s|// disableAudioLevels:.*|disableAudioLevels: true,|" $MEET_CONF_HP
sed -i "s|enableNoAudioDetection:.*|enableNoAudioDetection: false,|" $MEET_CONF_HP
sed -i "s|enableNoisyMicDetection:.*|enableNoisyMicDetection: false,|" $MEET_CONF_HP
sed -i "s|startAudioMuted:.*|startAudioMuted: 5,|" $MEET_CONF_HP
sed -i "s|// startVideoMuted:.*|startVideoMuted: 5,|" $MEET_CONF_HP
sed -i "s|startWithVideoMuted: true,|startWithVideoMuted: false,|" $MEET_CONF_HP
sed -i "s|channelLastN:.*|channelLastN: 10,|" $MEET_CONF_HP
sed -i "s|// enableLayerSuspension:.*|enableLayerSuspension: true,|" $MEET_CONF_HP
sed -i "s|// apiLogLevels:.*|apiLogLevels: \['warn', 'error'],|" $MEET_CONF_HP

if [ "$VID_RES" = "360" ]; then
sed -i "/Start QJI/,/End QJI/d" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \/\/ Start QJI - Set resolution and widescreen format" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ resolution: 360," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ constraints: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ aspectRatio: 16 \/ 9," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ video: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ height: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 360," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 360," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 180" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ width: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 640," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 640," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 320" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ }" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ }," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \/\/ End QJI" $MEET_CONF_HP
fi
if [ "$VID_RES" = "540" ]; then
sed -i "/Start QJI/,/End QJI/d" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \/\/ Start QJI - Set resolution and widescreen format" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ resolution: 540," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ constraints: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ aspectRatio: 16 \/ 9," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ video: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ height: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 540," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 540," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 180" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ width: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 960," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 960," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 320" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ }" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ }," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \/\/ End QJI" $MEET_CONF_HP
fi
if [ "$VID_RES" = "720" ]; then
sed -i "/Start QJI/,/End QJI/d" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \/\/ Start QJI - Set resolution and widescreen format" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ resolution: 720," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ constraints: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ aspectRatio: 16 \/ 9," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ video: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ height: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 720," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 720," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 180" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ width: {" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ ideal: 1280," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ max: 1280," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ min: 320" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ \ \ \ \ }" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ \ \ \ \ }" $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \ \ \ \ \ }," $MEET_CONF_HP
sed -i "/Enable \/ disable simulcast support/i \/\/ End QJI" $MEET_CONF_HP
fi

## interface_config.js
cp $INT_CONF_JS $INT_CONF_JS_HP
sed -i "s|CONNECTION_INDICATOR_DISABLED:.*|CONNECTION_INDICATOR_DISABLED: true,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_DOMINANT_SPEAKER_INDICATOR:.*|DISABLE_DOMINANT_SPEAKER_INDICATOR: true,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_FOCUS_INDICATOR:.*|DISABLE_FOCUS_INDICATOR: false,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_JOIN_LEAVE_NOTIFICATIONS:.*|DISABLE_JOIN_LEAVE_NOTIFICATIONS: true,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_VIDEO_BACKGROUND:.*|DISABLE_VIDEO_BACKGROUND: true,|" $INT_CONF_JS_HP
sed -i "s|OPTIMAL_BROWSERS: \[.*|OPTIMAL_BROWSERS: \[ 'chrome', 'chromium', 'electron' \],|" $INT_CONF_JS_HP
sed -i "s|UNSUPPORTED_BROWSERS: .*|UNSUPPORTED_BROWSERS: \[ 'nwjs', 'safari', 'firefox' \],|" $INT_CONF_JS_HP

### Toolbars
if version_gt "$(apt-show-versions jitsi-meet|awk '{print$2}')" "2.0.5390-3" ; then
  #New toolbar in config.js
  sed -i "/\/\/ toolbarButtons:/i \ \ \ \ toolbarButtons:: \[" $MEET_CONF_HP
  sed -i "/\/\/ toolbarButtons:/i \ \ \ \ \ \ \ \ 'microphone', 'camera', 'desktop', 'fullscreen'," $MEET_CONF_HP
  if [ -z "$CHAT_DISABLED" ] || [ "$CHAT_DISABLED" = "yes" ]; then
    sed -i "/\/\/ toolbarButtons:/i \ \ \ \ \ \ \ \ 'fodeviceselection', 'hangup', 'profile', 'recording'," $MEET_CONF_HP
  else
    sed -i "/\/\/ toolbarButtons:/i \ \ \ \ \ \ \ \ 'fodeviceselection', 'hangup', 'profile', 'chat', 'recording'," $MEET_CONF_HP
  fi
  sed -i "/\/\/ toolbarButtons:/i \ \ \ \ \ \ \ \ 'livestreaming', 'etherpad', 'settings', 'raisehand'," $MEET_CONF_HP
  sed -i "/\/\/ toolbarButtons:/i \ \ \ \ \ \ \ \ 'videoquality', 'filmstrip', 'feedback'," $MEET_CONF_HP
  sed -i "/\/\/ toolbarButtons:/i \ \ \ \ \ \ \ \ 'tileview', 'download', 'help', 'mute-everyone', 'mute-video-everyone', 'security'" $MEET_CONF_HP
  sed -i "/\/\/ toolbarButtons:/i \ \ \ \ \]," $MEET_CONF_HP
else
  #Old toolbar in interface.js (soon deprecated on newer versions)
  sed -i "/^\s*TOOLBAR_BUTTONS*\]$/ s|^|//|; /^\s*TOOLBAR_BUTTONS/, /\],$/ s|^|//|" $INT_CONF_JS_HP

  sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ TOOLBAR_BUTTONS: \[" $INT_CONF_JS_HP
  sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'microphone', 'camera', 'desktop', 'fullscreen'," $INT_CONF_JS_HP
  if [ -z "$CHAT_DISABLED" ] || [ "$CHAT_DISABLED" = "yes" ]; then
    sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'fodeviceselection', 'hangup', 'profile', 'recording'," $INT_CONF_JS_HP
  else
    sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'fodeviceselection', 'hangup', 'profile', 'chat', 'recording'," $INT_CONF_JS_HP
  fi
  sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'livestreaming', 'etherpad', 'settings', 'raisehand'," $INT_CONF_JS_HP
  sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'videoquality', 'filmstrip', 'feedback'," $INT_CONF_JS_HP
  sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'tileview', 'download', 'help', 'mute-everyone', 'mute-video-everyone', 'security'" $INT_CONF_JS_HP
  sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \]," $INT_CONF_JS_HP
fi

#Check config file
echo -e "\n# Checking $MEET_CONF file for errors\n"
CHECKJS_MEET_CHP=$(esvalidate $MEET_CONF_HP| cut -d ":" -f2)
if [ -z "$CHECKJS_MEET_CHP" ]; then
echo -e "\n# The $MEET_CONF_HP configuration seems correct. =)\n"
else
echo -e "\n  Watch out!, there seems to be an issue on $MEET_CONF_HP line:
    $CHECKJS_MEET_CHP
  Most of the times this is due upstream changes, please report to
  https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
fi
CHECKJS_INT_CHP=$(esvalidate $INT_CONF_JS_HP| cut -d ":" -f2)
if [ -z "$CHECKJS_INT_CHP" ]; then
echo -e "\n# The $INT_CONF_JS_HP configuration seems correct. =)\n"
else
echo -e "\n  Watch out!, there seems to be an issue on $INT_CONF_JS_HP line:
    $CHECKJS_INT_CHP
  Most of the times this is due upstream changes, please report to
  https://github.com/switnet-ltd/quick-jibri-installer/issues\n"
fi

sed -i "s|$MEET_CONF|$MEET_CONF_HP|g" $WS_CONF
sed -i "s|$INT_CONF_JS|$INT_CONF_JS_HP|" $WS_CONF
nginx -t
#systemctl restart nginx

echo "Done!, yeah, that quick ;)"

echo "Rebooting in..."
wait_seconds 15
reboot
