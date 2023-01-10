#!/bin/bash
# JRA (Jibri Recordings Access) via Nextcloud

# GPLv3 or later.

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

if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi
exit_if_not_installed() {
if [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed")" != "1" ]; then
    echo " This instance doesn't have $1 installed, exiting..."
    echo " If you think this is an error "
    exit
fi
}
clear
echo -e '\n
########################################################################
                 Jibri Recordings Access via Nextcloud
########################################################################
                    by Software, IT & Networks Ltd
\n'
exit_if_not_installed jitsi-meet

DISTRO_RELEASE="$(lsb_release -sc)"
DOMAIN="$(find /etc/prosody/conf.d/ -name \*.lua|awk -F'.cfg' '!/localhost/{print $1}'|xargs basename)"
PHP_REPO="$(apt-cache policy | awk '/http/&&/php/{print$2}' | awk -F "/" 'NR==1{print$5}')"
PHPVER="7.4"
PSGVER="$(apt-cache madison postgresql|awk -F'[ +]' 'NR==1{print $3}')"
PHP_FPM_DIR="/etc/php/$PHPVER/fpm"
PHP_INI="$PHP_FPM_DIR/php.ini"
PHP_CONF="/etc/php/$PHPVER/fpm/pool.d/www.conf"
NC_NGINX_SSL_PORT="$(grep "listen 44" /etc/nginx/sites-available/"$DOMAIN".conf | awk '{print$2}')"
NC_REPO="https://download.nextcloud.com/server/releases"
NCVERSION="$(curl -s -m 900 $NC_REPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)"
STABLEVERSION="nextcloud-$NCVERSION"
NC_PATH="/var/www/nextcloud"
NC_CONFIG="$NC_PATH/config/config.php"
NC_DB_USER="nextcloud_user"
NC_DB="nextcloud_db"
NC_DB_PASSWD="$(tr -dc "a-zA-Z0-9#_*=" < /dev/urandom | fold -w 14 | head -n1)"
DIR_RECORD="$(awk  -F '"' '/RECORDING/{print$2}'  /home/jibri/finalize_recording.sh|awk 'NR==1{print$1}')"
REDIS_CONF="/etc/redis/redis.conf"
JITSI_MEET_PROXY="/etc/nginx/modules-enabled/60-jitsi-meet.conf"
if [ -f $JITSI_MEET_PROXY ];then
PREAD_PROXY=$(grep -nr "preread_server_name" $JITSI_MEET_PROXY | cut -d ":" -f1)
fi
PUBLIC_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
ISO3166_CODE=TBD
NL="$(printf '\n  ')"

while [[ "$ANS_NCD" != "yes" ]]
do
  read -p "> Please set your domain (or subdomain) here for Nextcloud: (e.g.: cloud.domain.com)$NL" -r NC_DOMAIN
  if [ -z "$NC_DOMAIN" ];then
    echo " - This field is mandatory."
  elif [ "$NC_DOMAIN" = "$DOMAIN" ]; then
    echo " - You can not use the same domain for both, Jitsi Meet and JRA via Nextcloud."
  fi
  read -p "  > Did you mean?: $NC_DOMAIN (yes or no)$NL" -r ANS_NCD
  if [ "$ANS_NCD" = "yes" ]; then
    echo "   - Alright, let's use $NC_DOMAIN."
  else
    echo "   - Please try again."
  fi
done
  #Simple DNS test
if [ "$PUBLIC_IP" = "$(dig -4 +short "$NC_DOMAIN"|awk -v RS='([0-9]+\\.){3}[0-9]+' 'RT{print RT}')" ]; then
  echo -e "Server public IP  & DNS record for $NC_DOMAIN seems to match, continuing...\n\n"
else
  echo "Server public IP ($PUBLIC_IP) & DNS record for $NC_DOMAIN don't seem to match."
  echo "  > Please check your dns records are applied and updated, otherwise Nextcloud may fail."
  read -p "  > Do you want to continue?: (yes or no)$NL" -r DNS_CONTINUE
  if [ "$DNS_CONTINUE" = "yes" ]; then
    echo "  - We'll continue anyway..."
  else
    echo "  - Exiting for now..."
  exit
  fi
fi

NC_NGINX_CONF="/etc/nginx/sites-available/$NC_DOMAIN.conf"
while [ -z "$NC_USER" ]
do
    read -p "Nextcloud user: " -r NC_USER
    if [ -z "$NC_USER" ]; then
        echo " - This field is mandatory."
    fi
done
while [ -z "$NC_PASS" ]  || [ ${#NC_PASS} -lt 6 ]
do
    read -p "Nextcloud user password: " -r NC_PASS
    if [ -z "$NC_PASS" ] || [ ${#NC_PASS} -lt 6 ]; then
        echo -e " - This field is mandatory. \nPlease make sure it's at least 6 characters.\n"
    fi
done
#Enable HSTS
while [ "$ENABLE_HSTS" != "yes" ] && [ "$ENABLE_HSTS" != "no" ]
do
    read -p "> Do you want to enable HSTS for this domain?: (yes or no)
  Be aware this option apply mid-term effects on the domain, choose \"no\"
  in case you don't know what you are doing. More at https://hstspreload.org/$NL" -r ENABLE_HSTS
    if [ "$ENABLE_HSTS" = "no" ]; then
        echo " - HSTS won't be enabled."
    elif [ "$ENABLE_HSTS" = "yes" ]; then
        echo " - HSTS will be enabled."
    fi
done

echo -e "#Default country phone code\n
> Starting at Nextcloud 21.x it's required to set a default country phone ISO 3166-1 alpha-2 code.\n
>>> https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements  <<<\n"
sleep .1
while [ ${#ISO3166_CODE} -gt 2 ];
do
echo -e "Some examples might be: Germany > DE | Mexico > MX | Spain > ES | USA > US\n
Do you want to set such code for your installation?"
sleep .1
read -p "Leave empty if you don't want to set any: " -r ISO3166_CODE
  if [ ${#ISO3166_CODE} -gt 2 ]; then
    echo -e "\n-- This code is only 2 characters long, please check your input.\n"
  fi
done
sleep .1
echo -e "\n# Check for jitsi-meet/jibri\n"
if [ "$(dpkg-query -W -f='${Status}' jibri 2>/dev/null | grep -c "ok installed")" == "1" ] || \
   [ -f /etc/prosody/conf.d/"$DOMAIN".conf ]; then
    echo "jitsi meet/jibri is installed, checking version:"
    apt-show-versions jibri
else
    echo "Wait!, jitsi-meet/jibri is not installed on this system using apt, exiting..."
    exit
fi

exit_ifinstalled() {
if [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo " This instance already has $1 installed, exiting..."
    echo " If you think this is an error "
    exit
fi
}
install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    echo " $1 is installed, skipping..."
else
    echo -e "\n---- Installing $1 ----"
    apt-get -yq2 install "$1"
fi
}
add_php74() {
if [ "$PHP_REPO" = "php" ]; then
    echo "PHP $PHPVER already installed"
    apt-get -q2 update
    apt-get -yq2 dist-upgrade
else
    echo "# Adding Ondrej PHP $PHPVER PPA Repository"
    apt-key adv --recv-keys --keyserver keyserver.ubuntu.com E5267A6C
    echo "deb [arch=amd64] http://ppa.launchpad.net/ondrej/php/ubuntu $DISTRO_RELEASE main" > /etc/apt/sources.list.d/php7x.list
    apt-get update -q2
fi
}
#Prevent root folder permission issues
cp "$PWD"/files/jra-nc-app-ef.json /tmp

exit_ifinstalled postgresql-"$PSGVER"

## Install software requirements
# PostgresSQL
install_ifnot postgresql-"$PSGVER"

# PHP 7.4
add_php74
apt-get install -y \
            imagemagick \
            php"$PHPVER"-fpm \
            php"$PHPVER"-bcmath \
            php"$PHPVER"-bz2 \
            php"$PHPVER"-curl \
            php"$PHPVER"-gd \
            php"$PHPVER"-gmp \
            php"$PHPVER"-imagick \
            php"$PHPVER"-intl \
            php"$PHPVER"-json \
            php"$PHPVER"-ldap \
            php"$PHPVER"-mbstring \
            php"$PHPVER"-pgsql \
            php"$PHPVER"-redis \
            php"$PHPVER"-soap \
            php"$PHPVER"-xml \
            php"$PHPVER"-xmlrpc \
            php"$PHPVER"-zip \
            redis-server \
            unzip

#System related
install_ifnot smbclient
sed -i "s|.*env\[HOSTNAME\].*|env\[HOSTNAME\] = \$HOSTNAME|" "$PHP_CONF"
sed -i "s|.*env\[PATH\].*|env\[PATH\] = /usr/local/bin:/usr/bin:/bin|" "$PHP_CONF"
sed -i "s|.*env\[TMP\].*|env\[TMP\] = /tmp|" "$PHP_CONF"
sed -i "s|.*env\[TMPDIR\].*|env\[TMPDIR\] = /tmp|" "$PHP_CONF"
sed -i "s|.*env\[TEMP\].*|env\[TEMP\] = /tmp|" "$PHP_CONF"
sed -i "s|;clear_env = no|clear_env = no|" "$PHP_CONF"

echo "
Tunning PHP.ini...
"
# Change values in php.ini (increase max file size)
# max_execution_time
sed -i "s|max_execution_time =.*|max_execution_time = 3500|g" "$PHP_INI"
# max_input_time
sed -i "s|max_input_time =.*|max_input_time = 3600|g" "$PHP_INI"
# memory_limit
sed -i "s|memory_limit =.*|memory_limit = 512M|g" "$PHP_INI"
# post_max
sed -i "s|post_max_size =.*|post_max_size = 1025M|g" "$PHP_INI"
# upload_max
sed -i "s|upload_max_filesize =.*|upload_max_filesize = 1024M|g" "$PHP_INI"

phpenmod opcache
{

echo "# OPcache settings for Nextcloud"
echo "opcache.enable=1"
echo "opcache.enable_cli=1"
echo "opcache.interned_strings_buffer=8"
echo "opcache.max_accelerated_files=10000"
echo "opcache.memory_consumption=256"
echo "opcache.save_comments=1"
echo "opcache.revalidate_freq=1"
echo "opcache.validate_timestamps=1"
} >> "$PHP_INI"

systemctl restart php"$PHPVER"-fpm.service

#--------------------------------------------------
# Create DB user
#--------------------------------------------------

echo -e "\n---- Creating the PgSQL DB & User  ----"
cd /tmp || return
sudo -u postgres psql <<DB
CREATE DATABASE nextcloud_db;
CREATE USER ${NC_DB_USER} WITH ENCRYPTED PASSWORD '${NC_DB_PASSWD}';
GRANT ALL PRIVILEGES ON DATABASE ${NC_DB} TO ${NC_DB_USER};
DB
echo "Done!
"

#nginx - configuration
cat << NC_NGINX > "$NC_NGINX_CONF"
#nextcloud config
upstream php-handler {
    #server 127.0.0.1:9000;
    server unix:/run/php/php${PHPVER}-fpm.sock;
}

server {
    listen 80;
    listen [::]:80;
    server_name $NC_DOMAIN;
    # enforce https
    return 301 https://\$server_name\$request_uri;
}

server {
    listen $NC_NGINX_SSL_PORT ssl http2;
    listen [::]:$NC_NGINX_SSL_PORT ssl http2;
    server_name $NC_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$NC_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$NC_DOMAIN/privkey.pem;

    # HSTS settings
    # WARNING: Only add the preload option once you read about
    # the consequences in https://hstspreload.org/. This option
    # will add the domain to a hardcoded list that is shipped
    # in all major browsers and getting removed from this list
    # could take several months.
    #add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;" always;

   # Enable gzip but do not remove ETag headers
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;

    # Pagespeed is not supported by Nextcloud, so if your server is built
    # with the \`ngx_pagespeed\` module, uncomment this line to disable it.
    #pagespeed off;

    # HTTP response headers borrowed from Nextcloud \`.htaccess\`
    add_header Referrer-Policy                      "no-referrer"   always;
    add_header X-Content-Type-Options               "nosniff"       always;
    add_header X-Download-Options                   "noopen"        always;
    add_header X-Frame-Options                      "SAMEORIGIN"    always;
    add_header X-Permitted-Cross-Domain-Policies    "none"          always;
    add_header X-Robots-Tag                         "none"          always;
    add_header X-XSS-Protection                     "1; mode=block" always;

    # Remove X-Powered-By, which is an information leak
    fastcgi_hide_header X-Powered-By;

    # set max upload size
    client_max_body_size 1024M;
    fastcgi_buffers 64 4K;

    # Path to the root of your installation
    root $NC_PATH/;

    # Specify how to handle directories -- specifying \`/index.php\$request_uri\`
    # here as the fallback means that Nginx always exhibits the desired behaviour
    # when a client requests a path that corresponds to a directory that exists
    # on the server. In particular, if that directory contains an index.php file,
    # that file is correctly served; if it doesn't, then the request is passed to
    # the front-end controller. This consistent behaviour means that we don't need
    # to specify custom rules for certain paths (e.g. images and other assets,
    # \`/updater\`, \`/ocm-provider\`, \`/ocs-provider\`), and thus
    # \`try_files \$uri \$uri/ /index.php\$request_uri\`
    # always provides the desired behaviour.
    index index.php index.html /index.php\$request_uri;

    # Rule borrowed from \`.htaccess\` to handle Microsoft DAV clients
    location = / {
        if ( \$http_user_agent ~ ^DavClnt ) {
            return 302 /remote.php/webdav/\$is_args\$args;
        }
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # Make a regex exception for \`/.well-known\` so that clients can still
    # access it despite the existence of the regex rule
    # \`location ~ /(\.|autotest|...)\` which would otherwise handle requests
    # for \`/.well-known\`.
    location ^~ /.well-known {
        # The rules in this block are an adaptation of the rules
        # in \`.htaccess\` that concern \`/.well-known\`.

        location = /.well-known/carddav { return 301 /remote.php/dav/; }
        location = /.well-known/caldav  { return 301 /remote.php/dav/; }

        location /.well-known/acme-challenge    { try_files \$uri \$uri/ =404; }
        location /.well-known/pki-validation    { try_files \$uri \$uri/ =404; }

        # Let Nextcloud's API for \`/.well-known\` URIs handle all other
        # requests by passing them to the front-end controller.
        return 301 /index.php\$request_uri;
    }

    # Rules borrowed from \`.htaccess\` to hide certain paths from clients
    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:\$|/)  { return 404; }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console)                { return 404; }

    # Ensure this block, which passes PHP files to the PHP process, is above the blocks
    # which handle static assets (as seen below). If this block is not declared first,
    # then Nginx will encounter an infinite rewriting loop when it prepends \`/index.php\`
    # to the URI, resulting in a HTTP 500 error response.
    location ~ \.php(?:\$|/) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)\$;
        set \$path_info \$fastcgi_path_info;

        try_files \$fastcgi_script_name =404;

        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param HTTPS on;

        fastcgi_param modHeadersAvailable true;         # Avoid sending the security headers twice
        fastcgi_param front_controller_active true;     # Enable pretty urls
        fastcgi_pass php-handler;

        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
    }

    location ~ \.(?:css|js|svg|gif)\$ {
        try_files \$uri /index.php\$request_uri;
        expires 6M;         # Cache-Control policy borrowed from \`.htaccess\`
        access_log off;     # Optional: Don't log access to assets
    }

    location ~ \.woff2?\$ {
        try_files \$uri /index.php\$request_uri;
        expires 7d;         # Cache-Control policy borrowed from \`.htaccess\`
        access_log off;     # Optional: Don't log access to assets
    }

    # Rule borrowed from \`.htaccess\`
    location /remote {
        return 301 /remote.php\$request_uri;
    }

    location / {
        try_files \$uri \$uri/ /index.php\$request_uri;
    }
}
NC_NGINX
systemctl stop nginx
letsencrypt certonly --standalone --renew-by-default --agree-tos -d "$NC_DOMAIN"
if [ -f /etc/letsencrypt/live/"$NC_DOMAIN"/fullchain.pem ];then
    ln -s "$NC_NGINX_CONF" /etc/nginx/sites-enabled/
else
    echo "There are issues on getting the SSL certs..."
    read -n 1 -s -r -p "Press any key to continue"
fi
nginx -t
systemctl restart nginx

if [ "$ENABLE_HSTS" = "yes" ]; then
    sed -i "s|#add_header Strict-Transport-Security|add_header Strict-Transport-Security|g" "$NC_NGINX_CONF"
fi

if [ -n "$PREAD_PROXY" ]; then
    echo "
  Setting up Nextcloud domain on Jitsi Meet turn proxy
"
    sed -i "/server {/i \ \ map \$ssl_preread_server_name \$upstream {" "$JITSI_MEET_PROXY"
    sed -i "/server {/i \ \ \ \ \ \ $DOMAIN      web;" "$JITSI_MEET_PROXY"
    sed -i "/server {/i \ \ \ \ \ \ $NC_DOMAIN web;" "$JITSI_MEET_PROXY"
    sed -i "/server {/i \ \ }" "$JITSI_MEET_PROXY"
fi

echo -e "\n  Latest version to be installed: $STABLEVERSION
  (This might take sometime, please be patient...)\n"
curl -s "$NC_REPO"/"$STABLEVERSION".zip > /tmp/"$STABLEVERSION".zip
unzip -q /tmp/"$STABLEVERSION".zip
mv nextcloud "$NC_PATH"

chown -R www-data:www-data "$NC_PATH"
chmod -R 755 "$NC_PATH"

echo -e "\nDatabase installation...\n"
sudo -u www-data php "$NC_PATH"/occ maintenance:install \
--database=pgsql \
--database-name="$NC_DB" \
--database-user="$NC_DB_USER" \
--database-pass="$NC_DB_PASSWD" \
--admin-user="$NC_USER" \
--admin-pass="$NC_PASS"

echo -e "\nApply custom mods...\n"
sed -i "/datadirectory/a \ \ \'skeletondirectory\' => \'\'," "$NC_CONFIG"
sed -i "/skeletondirectory/a \ \ \'simpleSignUpLink.shown\' => false," "$NC_CONFIG"
sed -i "/simpleSignUpLink.shown/a \ \ \'knowledgebaseenabled\' => false," "$NC_CONFIG"
sed -i "s|http://localhost|http://$NC_DOMAIN|" "$NC_CONFIG"

echo -e "\nAdd crontab...\n"
crontab -u www-data -l | { cat; echo "*/5  *  *  *  * php -f $NC_PATH/cron.php"; } | crontab -u www-data -

echo -e "\nAdd memcache support...\n"
sed -i "s|# unixsocket .*|unixsocket /var/run/redis/redis.sock|g" "$REDIS_CONF"
sed -i "s|# unixsocketperm .*|unixsocketperm 777|g" "$REDIS_CONF"
sed -i "s|port 6379|port 0|" "$REDIS_CONF"
systemctl restart redis-server

echo -e "\n--> Setting config.php...\n"
if [ -n "$ISO3166_CODE" ]; then
  sed -i "/);/i \ \ 'default_phone_region' => '$ISO3166_CODE'," "$NC_CONFIG"
fi
sed -i "/);/i \ \ 'filelocking.enabled' => 'true'," "$NC_CONFIG"
sed -i "/);/i \ \ 'memcache.locking' => '\\\OC\\\Memcache\\\Redis'," "$NC_CONFIG"
sed -i "/);/i \ \ 'memcache.local' => '\\\OC\\\Memcache\\\Redis'," "$NC_CONFIG"
sed -i "/);/i \ \ 'memcache.local' => '\\\OC\\\Memcache\\\Redis'," "$NC_CONFIG"
sed -i "/);/i \ \ 'memcache.distributed' => '\\\OC\\\Memcache\\\Redis'," "$NC_CONFIG"
sed -i "/);/i \ \ 'redis' =>" "$NC_CONFIG"
sed -i "/);/i \ \ \ \ array (" "$NC_CONFIG"
sed -i "/);/i \ \ \ \ \ 'host' => '/var/run/redis/redis.sock'," "$NC_CONFIG"
sed -i "/);/i \ \ \ \ \ 'port' => 0," "$NC_CONFIG"
sed -i "/);/i \ \ \ \ \ 'timeout' => 0," "$NC_CONFIG"
sed -i "/);/i \ \ )," "$NC_CONFIG"
echo -e "Done\n"

echo -e "\nAddding & Setting up Files External App for Local storage...\n"
sudo -u www-data php "$NC_PATH"/occ app:install files_external
sudo -u www-data php "$NC_PATH"/occ app:enable files_external
sudo -u www-data php "$NC_PATH"/occ app:disable support
sudo -u www-data php "$NC_PATH"/occ files_external:import /tmp/jra-nc-app-ef.json

usermod -a -G jibri www-data
chmod -R 770 "$DIR_RECORD"
chmod -R g+s "$DIR_RECORD"

echo -e "\nFixing possible missing tables...\n\n"
echo "y"|sudo -u www-data php "$NC_PATH"/occ db:convert-filecache-bigint
sudo -u www-data php "$NC_PATH"/occ db:add-missing-indices
sudo -u www-data php "$NC_PATH"/occ db:add-missing-columns

echo -e "\nAdding trusted domain...\n"
sudo -u www-data php "$NC_PATH"/occ config:system:set trusted_domains 0 --value="$NC_DOMAIN"

echo -e "\nSetting JRA domain on jitsi-updater.sh\n"
cd ~/quick-jibri-installer || return
sed -i "s|NC_DOMAIN=.*|NC_DOMAIN=\"$NC_DOMAIN\"|" jitsi-updater.sh

echo -e "\nQuick Nextcloud installation complete!\n"
