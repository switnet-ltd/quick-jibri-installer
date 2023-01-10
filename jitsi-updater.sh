#!/bin/bash
# Jitsi Meet recurring upgrader and customization keeper
# for Debian/*buntu binaries.
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

Blue='\e[0;34m'
Purple='\e[0;35m'
Red='\e[0;31m'
Green='\e[0;32m'
Yellow='\e[0;33m'
Color_Off='\e[0m'
printwc() {
    printf "%b$2%b" "$1" "${Color_Off}"
}
#Check if user is root
if ! [ "$(id -u)" = 0 ]; then
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
ENABLE_BLESSM="TBD"
CHD_LTST="$(curl -sL https://chromedriver.storage.googleapis.com/LATEST_RELEASE)"
CHD_LTST_2D="$(cut -d "." -f 1,2 <<<  "$CHD_LTST")"
CHDB="$(whereis chromedriver | awk '{print$2}')"
if [ -d /etc/prosody/conf.d/ ]; then
DOMAIN="$(find /etc/prosody/conf.d/ -name \*.lua | \
          awk -F'.cfg' '!/localhost/{print $1}' | xargs basename)"
else
    echo -e "Seems no prosody is installed...\n  > is this a jibri node?"
fi
NC_DOMAIN="TBD"
JITSI_MEET_PROXY="/etc/nginx/modules-enabled/60-jitsi-meet.conf"
if [ -f "$JITSI_MEET_PROXY" ];then
PREAD_PROXY="$(grep -nr "preread_server_name" "$JITSI_MEET_PROXY" | cut -d ":" -f1)"
fi
INT_CONF="/usr/share/jitsi-meet/interface_config.js"
INT_CONF_ETC="/etc/jitsi/meet/$DOMAIN-interface_config.js"
read -r -a jibri_packages < <(grep ^Package /var/lib/apt/lists/download.jitsi.org_*_Packages | \
                              sort -u | awk '{print $2}' | sed '/jigasi/d' | \
                              xargs)
AVATAR="$(grep -r avatar /etc/nginx/sites-*/ 2>/dev/null)"
if [ -f "$apt_repo"/google-chrome.list ]; then
read -r -a google_package < <(grep ^Package /var/lib/apt/lists/dl.google.com_*_Packages | \
                              sort -u | awk '{print $2}' | xargs)
else
    echo "Seems no Google repo installed"
fi
if [ -z "$CHDB" ]; then
    echo "Seems no chromedriver installed"
else
    CHD_VER_LOCAL="$($CHDB -v | awk '{print $2}')"
    CHD_VER_2D="$(awk '{printf "%.1f\n", $NF}' <<< "$CHD_VER_LOCAL")"
fi
if [ -f "$apt_repo"/nodesource.list ]; then
read -r -a nodejs_package < <(grep ^Package /var/lib/apt/lists/deb.nodesource.com_node*_Packages | \
                              sort -u | awk '{print $2}' | xargs)
else
    echo "Seems no nodejs repo installed"
fi
# True if $1 is greater than $2
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

restart_jibri() {
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
    restart_jibri
    systemctl restart prosody
}

update_jitsi_repo() {
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/jitsi-$1.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    apt-get install -q2 --only-upgrade <<< printf "${jibri_packages[@]}"
}

update_google_repo() {
    if [ -f "$apt_repo"/google-chrome.list ]; then
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/google-chrome.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    apt-get install -q2 --only-upgrade <<< printf "${google_package[@]}"
    else
        echo "No Google repository found"
    fi
}
update_nodejs_repo() {
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/nodesource.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    apt-get install -q2 --only-upgrade <<< printf "${nodejs_package[@]}"
}
printwc "${Purple}" "Checking for Google Chrome\n"
if [ -f /usr/bin/google-chrome ]; then
    GOOGL_VER_2D="$(/usr/bin/google-chrome --version|awk '{printf "%.1f\n", $NF}')"
else
    printwc "${Yellow}" " -> Seems there is no Google Chrome installed\n"
    IS_GLG_CHRM="no"
fi
upgrade_cd() {
if [ -n "$GOOGL_VER_2D" ]; then
    if version_gt "$GOOGL_VER_2D" "$CHD_VER_2D" ; then
        echo "Upgrading Chromedriver to Google Chromes version"
        wget -q https://chromedriver.storage.googleapis.com/"$CHD_LTST"/chromedriver_linux64.zip \
             -O /tmp/chromedriver_linux64.zip
        unzip -o /tmp/chromedriver_linux64.zip -d /usr/local/bin/
        chown root:root "$CHDB"
        chmod 0755 "$CHDB"
        rm -rf /tpm/chromedriver_linux64.zip
        printf "Current version: "
        printwc "$Green" "$($CHDB -v |awk '{print $2}'|awk '{printf "%.1f\n", $NF}')"
        echo -e " (latest available)\n"
    elif [ "$GOOGL_VER_2D" = "$CHD_LTST_2D" ]; then
        echo "No need to upgrade Chromedriver"
        printf "Current version: "
        printwc "$Green" "$CHD_VER_2D\n"
    fi
else
  printwc "${Yellow}" " -> No Google Chrome versión to match, leaving untouched.\n"
fi
}

check_lst_cd() {
printwc "${Purple}" "Checking for the latest Chromedriver\n"
if [ -f "$CHDB" ]; then
    printf "Current installed Chromedriver: "
    printwc "${Yellow}" "$CHD_VER_2D\n"
    printf "Current installed Google Chrome: "
    printwc "${Green}" "$GOOGL_VER_2D\n"
    upgrade_cd
else
    printwc "${Yellow}" " -> Seems there is no Chromedriver installed\n"
    IS_CHDB="no"
fi
}

printwc "${Blue}" "Update & upgrade Jitsi and components\n"
if [ -f "$apt_repo"/jitsi-unstable.list ]; then
    update_jitsi_repo unstable
    update_google_repo
    check_lst_cd
elif [ -f "$apt_repo"/jitsi-stable.list ]; then
    update_jitsi_repo stable
    update_google_repo
    check_lst_cd
else
    echo "Please check your repositories, something is not right."
    exit 1
fi
printwc "${Blue}" "Check for supported nodejs LTS version"
if version_gt "14" "$(dpkg-query -W -f='${Version}' nodejs)"; then
    curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
    apt-get install -yq2 nodejs
else
    update_nodejs_repo
fi
check_if_installed(){
if [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo "1"
else
    echo "0"
fi
}
check_for_jibri_node() {
if [ "$(check_if_installed jibri)" = 1 ] && \
   [ "$(check_if_installed jitsi-meet)" = 0 ] && \
   [ "$(check_if_installed prosody)" = 0 ]; then
    printwc "${Green}" "\n::: This seems to be a jibri node :::\n"
JIBRI_NODE="yes"
fi
}
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
#Check for jibri node
check_for_jibri_node

[ "$JIBRI_NODE" != yes ] && \
if [ -f "$INT_CONF_ETC" ]; then
    echo "Static interface_config.js exists, skipping modification..."
else
    echo "This setup doesn't have a static interface_config.js, checking changes..."
    printwc "${Purple}" "========== Setting Static Avatar  ==========\n"
    if [ -z "$AVATAR" ]; then
        echo "Moving on..."
    else
        echo "Setting Static Avatar"
        sed -i "/RANDOM_AVATAR_URL_PREFIX/ s|false|\'http://$DOMAIN/avatar/\'|" "$INT_CONF"
        sed -i "/RANDOM_AVATAR_URL_SUFFIX/ s|false|\'.png\'|" "$INT_CONF"
    fi
    printwc "${Purple}" "========== Setting Support Link  ==========\n"
    if [ -z "$support" ]; then
        echo "Moving on..."
    else
        echo "Setting Support custom link"
        sed -i "s|https://jitsi.org/live|$support|g" "$INT_CONF"
    fi
    printwc "${Purple}" "========== Disable Blur my background  ==========\n"
    sed -i "s|'videobackgroundblur', ||" "$INT_CONF"
fi
if [ "$(check_if_installed openjdk-8-jre-headless)" = 1 ]; then
    printwc "${Red}" "\n::: Unsupported OpenJDK JRE version found :::\n"
    apt-get install -y openjdk-11-jre-headless
    apt-get purge -y openjdk-8-jre-headless
    printwc "${Green}" "\n::: Updated to supported OpenJDK JRE version 11 :::\n"
fi

[ "$JIBRI_NODE" != yes ] && \
if [  "$NC_DOMAIN" != "TBD" ]; then
printwc "${Purple}" "========== Enable $NC_DOMAIN for sync client ==========\n"
    if [ -f "$JITSI_MEET_PROXY" ] && [ -z "$PREAD_PROXY" ]; then
        printf "\n  Setting up Nextcloud domain on Jitsi Meet turn proxy\n\n"
        sed -i "/server {/i \ \ map \$ssl_preread_server_name \$upstream {" "$JITSI_MEET_PROXY"
        sed -i "/server {/i \ \ \ \ \ \ $DOMAIN    web;" "$JITSI_MEET_PROXY"
        sed -i "/server {/i \ \ \ \ \ \ $NC_DOMAIN    web;" "$JITSI_MEET_PROXY"
        sed -i "/server {/i \ \ }" "$JITSI_MEET_PROXY"
      else
        echo "$NC_DOMAIN seems to be on place, skipping..."
    fi
fi
if [ "$JIBRI_NODE" = "yes" ]; then
    restart_jibri
else
    restart_services
fi

if  [ "$JIBRI_NODE" = "yes" ] && \
    [ "$IS_CHDB" = "no" ] && \
    [ "$IS_GLG_CHRM" = "no" ];then
printwc "${Red}" "\nBeware: This jibri node seems to be missing important packages.\n"
echo " > Googe Chrome"
echo " > Chromedriver"
fi
########################################################################
#                         Brandless mode                               #
########################################################################
if [ "$ENABLE_BLESSM" = "on" ]; then
    if [ "$MODE" = "debug" ]; then
        bash "$PWD"/jm-bm.sh -m debug
    else
        bash "$PWD"/jm-bm.sh
    fi
fi
printwc "${Blue}" "Script completed \o/!\n"
