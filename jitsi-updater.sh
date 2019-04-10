#!/bin/bash
# Jitsi Meet upgrade and custom keeper for Debian/*buntu binaries.
# 2018 - SwITNet Ltd
# GNU GPLv3 or later.

Blue='\e[0;34m'
Purple='\e[0;35m'
Color_Off='\e[0m'
support="https://switnet.net/support"
apt_repo="/etc/apt/sources.list.d"
jibri_packages=$(grep Package /var/lib/apt/lists/download.jitsi.org_*_Packages | sort -u | awk '{print $2}' | paste -s -d ' ')
CHD_LST=$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)
CHDB=/usr/local/bin/chromedriver
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | grep -v save | cut -d "." -f "1-3")
if [ -f $apt_repo/google-chrome.list ]; then
    google_package=$(grep Package /var/lib/apt/lists/dl.google.com_linux_chrome_deb_dists_stable_main_binary-amd64_Packages | sort -u | cut -d ' ' -f2 | paste -s -d ' ')
else
    echo "Seems no Google repo installed"
fi
if [ -f $CHDB ]; then
	CHD_AVB=$(chromedriver -v | awk '{print $2}' | cut -d . -f "1,2")
else
    echo "Seems no chromedriver installed"
fi

version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

check_jibri() {
if [ "$(dpkg-query -W -f='${Status}' "jibri" 2>/dev/null | grep -c "ok installed")" == "1" ]
then
	service jibri restart
	service jibri-icewm restart
	service jibri-xorg restart
else
	echo "Jibri service not installed"
fi
}

# Restarting services
restart_services() {
	service jitsi-videobridge restart
	service jicofo restart
	check_jibri
	service prosody restart
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

########################################################################
#                         Keeping changes                              #
########################################################################
printf "${Purple}========== Setting Static Avatar  ==========${Color_Off}\n"
avatar="$(grep -r avatar /etc/*/sites-*/ 2>/dev/null)"
if ($avatar) < /dev/null > /dev/null 2>&1; then
	echo "Moving on..."
else
	echo "Setting Static Avatar"
	sed -i "/RANDOM_AVATAR_URL_PREFIX/ s|false|\'http://$DOMAIN/avatar/\'|" /usr/share/jitsi-meet/interface_config.js
	sed -i "/RANDOM_AVATAR_URL_SUFFIX/ s|false|\'.png\'|" /usr/share/jitsi-meet/interface_config.js
fi

printf "${Purple}========== Setting Support Link  ==========${Color_Off}\n"
if ($support) < /dev/null > /dev/null 2>&1; then
	echo "Moving on..."
else
	echo "Setting Support custom link"
	sed -i "s|https://jitsi.org/live|$support|g" /usr/share/jitsi-meet/interface_config.js
fi

restart_services
printf "${Blue}Script completed \o/! ${Color_Off}\n"
