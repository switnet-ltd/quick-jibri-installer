#!/bin/bash
# Custom High Performance Jitsi conf
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have privileges!"
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

LTS_REL="$(lsb_release -d | awk '{print$4}')"
DOMAIN="$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')"
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

if [ -z $LTS_REL ] || [ -z $DOMAIN ];then
echo "This system isn't suitable to configure."
exit
  else
echo "This system seems suitable to configure..."
fi

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

#Tools to consider
##Profiling
#https://github.com/jvm-profiling-tools/async-profiler

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
echo 'net.core.rmem_default=262144' | tee -a /etc/sysctl.conf
echo 'net.core.wmem_default=262144' | tee -a /etc/sysctl.conf
echo 'net.core.rmem_max=262144' | tee -a /etc/sysctl.conf
echo 'net.core.wmem_max=262144' | tee -a /etc/sysctl.conf

#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/reduce_tcp_performance_spikes
sysctl -w net.ipv4.tcp_timestamps=0
echo 'net.ipv4.tcp_timestamps=0' | tee -a /etc/sysctl.conf

#https://bugzilla.redhat.com/show_bug.cgi?id=1283676
sysctl -w net.core.netdev_max_backlog = 100000
echo 'net.core.netdev_max_backlog = 100000' | tee -a /etc/sysctl.conf

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
cp $MEET_CONF $MEET_CONF_HP
sed -i "s|// disableAudioLevels:.*|disableAudioLevels: true,|" $MEET_CONF_HP
sed -i "s|enableNoAudioDetection:.*|enableNoAudioDetection: false,|" $MEET_CONF_HP
sed -i "s|enableNoisyMicDetection:.*|enableNoisyMicDetection: false,|" $MEET_CONF_HP
sed -i "s|startAudioMuted:.*|startAudioMuted: 5,|" $MEET_CONF_HP
sed -i "s|// startVideoMuted:.*|startVideoMuted: 5,|" $MEET_CONF_HP
sed -i "s|startWithVideoMuted: true,|startWithVideoMuted: false,|" $MEET_CONF_HP
sed -i "s|channelLastN:.*|channelLastN: 10,|" $MEET_CONF_HP
sed -i "s|// enableLayerSuspension:.*|enableLayerSuspension: true,|" $MEET_CONF_HP
sed -i "s|// resolution:.*|resolution: 480,|" $MEET_CONF_HP
sed -i "s|// apiLogLevels:.*|apiLogLevels: \['warn', 'error'],|" $MEET_CONF_HP

sed -i "/w3c spec-compliant/,/disableSimulcast:/s|// constraints: {| constraints: {|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|//     video: {|     video: {|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|//         height: {|         height: {|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|//             ideal:.*|             ideal: 480,|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|//             max:.*|             max: 480,|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|//             min:.*|             min:240|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|//         }|         }|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|//     }|     }|" $MEET_CONF_HP
sed -i "/w3c spec-compliant/,/disableSimulcast:/s|// },| },|" $MEET_CONF_HP

cp $INT_CONF_JS $INT_CONF_JS_HP
sed -i "s|CONNECTION_INDICATOR_DISABLED:.*|CONNECTION_INDICATOR_DISABLED: true,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_DOMINANT_SPEAKER_INDICATOR:.*|DISABLE_DOMINANT_SPEAKER_INDICATOR: true,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_FOCUS_INDICATOR:.*|DISABLE_FOCUS_INDICATOR: false,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_JOIN_LEAVE_NOTIFICATIONS:.*|DISABLE_JOIN_LEAVE_NOTIFICATIONS: true,|" $INT_CONF_JS_HP
sed -i "s|DISABLE_VIDEO_BACKGROUND:.*|DISABLE_VIDEO_BACKGROUND: true,|" $INT_CONF_JS_HP
sed -i "s|OPTIMAL_BROWSERS: [.*|OPTIMAL_BROWSERS: [ 'chrome', 'chromium', 'electron' ],|" $INT_CONF_JS_HP
sed -i "s|UNSUPPORTED_BROWSERS: .*|UNSUPPORTED_BROWSERS: \[ 'nwjs', 'safari' \],|" $INT_CONF_JS_HP

##Toolbars
sed -i "/^\s*TOOLBAR_BUTTONS*\]$/ s|^|//|; /^\s*TOOLBAR_BUTTONS/, /\],$/ s|^|//|" $INT_CONF_JS_HP

sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ TOOLBAR_BUTTONS: \[" $INT_CONF_JS_HP
sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'microphone', 'camera', 'desktop', 'fullscreen'," $INT_CONF_JS_HP
sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'fodeviceselection', 'hangup', 'profile', 'recording'," $INT_CONF_JS_HP
sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'etherpad', 'settings', 'raisehand'," $INT_CONF_JS_HP
sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'videoquality', 'filmstrip', 'feedback'," $INT_CONF_JS_HP
sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \ \ \ \ 'tileview', 'download', 'help', 'mute-everyone', 'security'" $INT_CONF_JS_HP
sed -i "/\/\/    TOOLBAR_BUTTONS/i \ \ \ \ \]," $INT_CONF_JS_HP

echo "Done!, yeah, that quick ;)"

echo "Rebooting in..."
wait_seconds 15
reboot
