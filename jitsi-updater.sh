#!/bin/bash
# Jitsi Meet recurring upgrader and customization keeper
# for Debian/*buntu binaries.
# 2020 - SwITNet Ltd
# GNU GPLv3 or later.

Blue='\e[0;34m'
Purple='\e[0;35m'
Green='\e[0;32m'
Yellow='\e[0;33m'
Color_Off='\e[0m'
#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi
if [ ! -f jm-bm.sh ]; then
        echo "Please check that you are running the jitsi updater while being on the project folder"
        echo "other wise the updater might have errors or be incomplete. Exiting..."
        exit
fi
support="https://switnet.net/support"
apt_repo="/etc/apt/sources.list.d"
LOC_REC="TBD"
ENABLE_BLESSM="TBD"
CHD_LST="$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)"
CHDB="$(whereis chromedriver | awk '{print$2}')"
DOMAIN="$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')"
NC_DOMAIN="TBD"
JITSI_MEET_PROXY="/etc/nginx/modules-enabled/60-jitsi-meet.conf"
if [ -f $JITSI_MEET_PROXY ];then
PREAD_PROXY=$(grep -nr "preread_server_name" $JITSI_MEET_PROXY | cut -d ":" -f1)
fi
INT_CONF="/usr/share/jitsi-meet/interface_config.js"
INT_CONF_ETC="/etc/jitsi/meet/$DOMAIN-interface_config.js"
jibri_packages="$(grep Package /var/lib/apt/lists/download.jitsi.org_*_Packages |sort -u|awk '{print $2}'|sed 's|jigasi||'|paste -s -d ' ')"
AVATAR="$(grep -r avatar /etc/nginx/sites-*/ 2>/dev/null)"
if [ -f $apt_repo/google-chrome.list ]; then
    google_package=$(grep Package /var/lib/apt/lists/dl.google.com_linux_chrome_deb_dists_stable_main_binary-amd64_Packages | sort -u | cut -d ' ' -f2 | paste -s -d ' ')
else
    echo "Seems no Google repo installed"
fi
if [ -z $CHDB ]; then
	echo "Seems no chromedriver installed"
else
    CHD_AVB=$(chromedriver -v | awk '{print $2}')
fi

version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

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
	check_jibri
	systemctl restart prosody
}

upgrade_cd() {
if version_gt $CHD_LST $CHD_AVB
then
	echo "Upgrading ..."
	wget https://chromedriver.storage.googleapis.com/$CHD_LST/chromedriver_linux64.zip
	unzip chromedriver_linux64.zip
	sudo cp chromedriver $CHDB
	rm -rf chromedriver chromedriver_linux64.zip
	chromedriver -v
else
	echo "No need to upgrade Chromedriver"
	printf "Current version: ${Green} $CHD_AVB ${Color_Off}\n"
fi
}

update_jitsi_repo() {
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/jitsi-$1.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    apt-get install -qq --only-upgrade $jibri_packages
}

update_google_repo() {
	if [ -f $apt_repo/google-chrome.list ]; then
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/google-chrome.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    apt-get install -qq --only-upgrade $google_package
    else
		echo "No Google repository found"
	fi
}

check_lst_cd() {
printf "${Purple}Checking for the latest Chromedriver${Color_Off}\n"
if [ -f $CHDB ]; then
        printf "Current installed Chromedriver: ${Yellow} $CHD_AVB ${Color_Off}\n"
        printf "Latest Chromedriver version available: ${Green} $CHD_LST ${Color_Off}\n"
        upgrade_cd
else
	printf "${Yellow} -> Seems there is no Chromedriver installed${Color_Off}\n"
fi
}

printf "${Blue}Update & upgrade Jitsi and components - v2.3${Color_Off}\n"
if [ -f $apt_repo/jitsi-unstable.list ]; then
	update_jitsi_repo unstable
	update_google_repo
	check_lst_cd
elif [ -f $apt_repo/jitsi-stable.list ]; then
	update_jitsi_repo stable
	update_google_repo
	check_lst_cd
else
	echo "Please check your repositories, something is not right."
	exit 1
fi
# Any customization, image, name or link change for any purpose should
# be documented here so new updates won't remove those changes.
# We divide them on UI changes and branding changes, feel free to adapt
# to your needs.
#
# Please keep in mind that fees for support customization changes may
# apply.
########################################################################
#                     User interface changes                           #
########################################################################

if [ -f "$INT_CONF_ETC" ]; then
    echo "Static interface_config.js exists, skipping modification..."
else
    echo "This setup doesn't have a static interface_config.js, checking changes..."
	printf "${Purple}========== Setting Static Avatar  ==========${Color_Off}\n"
	if [[ -z "$AVATAR" ]]; then
		echo "Moving on..."
	else
		echo "Setting Static Avatar"
		sed -i "/RANDOM_AVATAR_URL_PREFIX/ s|false|\'http://$DOMAIN/avatar/\'|" $INT_CONF
		sed -i "/RANDOM_AVATAR_URL_SUFFIX/ s|false|\'.png\'|" $INT_CONF
	fi

	printf "${Purple}========== Setting Support Link  ==========${Color_Off}\n"
	if [[ -z $support ]]; then
		echo "Moving on..."
	else
		echo "Setting Support custom link"
		sed -i "s|https://jitsi.org/live|$support|g" $INT_CONF
	fi

	printf "${Purple}========== Disable Localrecording  ==========${Color_Off}\n"
	if [ "$LOC_REC" != "on" ]; then
			echo "Removing localrecording..."
			sed -i "s|'localrecording',||" $INT_CONF
	fi

	printf "${Purple}========== Disable Blur my background  ==========${Color_Off}\n"
	sed -i "s|'videobackgroundblur', ||" $INT_CONF

fi

if [  "$NC_DOMAIN" != "TBD" ]; then
printf "${Purple}========== Enable $NC_DOMAIN for sync client ==========${Color_Off}\n"
    if [ -z "$PREAD_PROXY" ]; then
        echo "
  Setting up Nextcloud domain on Jitsi Meet turn proxy
"
        sed -i "/server {/i \ \ map \$ssl_preread_server_name \$upstream {" $JITSI_MEET_PROXY
        sed -i "/server {/i \ \ \ \ \ \ $DOMAIN      web;" $JITSI_MEET_PROXY
        sed -i "/server {/i \ \ \ \ \ \ $NC_DOMAIN web;" $JITSI_MEET_PROXY
        sed -i "/server {/i \ \ }" $JITSI_MEET_PROXY
      else
        echo "$NC_DOMAIN seems to be on place, skipping..."
    fi
fi

restart_services


########################################################################
#                         Brandless mode                               #
########################################################################
if [ $ENABLE_BLESSM = on ]; then
	bash $PWD/jm-bm.sh
fi
printf "${Blue}Script completed \o/! ${Color_Off}\n"
