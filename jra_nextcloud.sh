#!/bin/bash
# JRA (Jibri Recordings Access) via Nextcloud
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

clear
echo '
########################################################################
                 Jibri Recordings Access via Nextcloud
########################################################################
                    by Software, IT & Networks Ltd
'
while [[ -z "$NC_DOMAIN" ]]
do
read -p "Please enter the domain to use for Nextcloud: " -r NC_DOMAIN
if [ -z "$NC_DOMAIN" ]; then
	echo "-- This field is mandatory."
fi
done
while [[ -z "$NC_USER" ]]
do
read -p "Nextcloud user: " -r NC_USER
if [ -z "$NC_USER" ]; then
	echo "-- This field is mandatory."
fi
done
while [[ -z "$NC_PASS" ]]
do
read -p "Nextcloud user password: " -r NC_PASS
if [ -z "$NC_PASS" ]; then
	echo "-- This field is mandatory."
fi
done
#Enable HSTS
while [[ "$ENABLE_HSTS" != "yes" && "$ENABLE_HSTS" != "no" ]]
do
read -p "> Do you want to enable HSTS for this domain?: (yes or no)
  Be aware this option apply mid-term effects on the domain, choose \"no\"
  in case you don't know what you are doing. More at https://hstspreload.org/"$'\n' -r ENABLE_HSTS
if [ "$ENABLE_HSTS" = "no" ]; then
	echo "-- HSTS won't be enabled."
elif [ "$ENABLE_HSTS" = "yes" ]; then
	echo "-- HSTS will be enabled."
fi
done
DISTRO_RELEASE="$(lsb_release -sc)"
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
PHP_REPO=$(apt-cache policy | grep http | grep php | head -n 1 | awk '{print $2}' | cut -d "/" -f5)
PHPVER="7.4"
PSGVER="$(apt-cache madison postgresql | head -n1 | awk '{print $3}' | cut -d "+" -f1)"
PHP_FPM_DIR="/etc/php/$PHPVER/fpm"
PHP_INI="$PHP_FPM_DIR/php.ini"
PHP_CONF="/etc/php/$PHPVER/fpm/pool.d/www.conf"
NC_NGINX_CONF="/etc/nginx/sites-available/$NC_DOMAIN.conf"
NC_NGINX_SSL_PORT="$(grep "listen 44" /etc/nginx/sites-enabled/$DOMAIN.conf | awk '{print$2}')"
NC_REPO="https://download.nextcloud.com/server/releases"
NCVERSION="$(curl -s -m 900 $NC_REPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)"
STABLEVERSION="nextcloud-$NCVERSION"
NC_PATH="/var/www/nextcloud"
NC_CONFIG="$NC_PATH/config/config.php"
NC_DB_USER="nextcloud_user"
NC_DB="nextcloud_db"
NC_DB_PASSWD="$(tr -dc "a-zA-Z0-9#_*=" < /dev/urandom | fold -w 14 | head -n1)"
DIR_RECORD="$(grep -nr RECORDING /home/jibri/finalize_recording.sh|head -n1|cut -d "=" -f2)"
REDIS_CONF="/etc/redis/redis.conf"
JITSI_MEET_PROXY="/etc/nginx/modules-enabled/60-jitsi-meet.conf"
if [ -f $JITSI_MEET_PROXY ];then
PREAD_PROXY=$(grep -nr "preread_server_name" $JITSI_MEET_PROXY | cut -d ":" -f1)
fi
exit_ifinstalled() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
	echo " This instance already has $1 installed, exiting..."
	echo " Please report to:
    -> https://github.com/switnet-ltd/quick-jibri-installer/issues "
	exit
fi
}
install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
	echo " $1 is installed, skipping..."
    else
    	echo -e "\n---- Installing $1 ----"
		apt-get -yq2 install $1
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
cp $PWD/files/jra-nc-app-ef.json /tmp

exit_ifinstalled postgresql-$PSGVER

## Install software requirements
# PostgresSQL
install_ifnot postgresql-$PSGVER

# PHP 7.4
add_php74
apt-get install -y \
            php$PHPVER-fpm \
            php$PHPVER-bcmath \
            php$PHPVER-bz2 \
            php$PHPVER-curl \
            php$PHPVER-gd \
            php$PHPVER-gmp \
            php$PHPVER-intl \
            php$PHPVER-json \
            php$PHPVER-ldap \
            php$PHPVER-mbstring \
            php$PHPVER-pgsql \
            php$PHPVER-soap \
            php$PHPVER-xml \
            php$PHPVER-xmlrpc \
            php$PHPVER-zip \
            php-imagick \
            php-redis \
            redis-server

#System related
install_ifnot smbclient
sed -i "s|.*env\[HOSTNAME\].*|env\[HOSTNAME\] = \$HOSTNAME|" $PHP_CONF
sed -i "s|.*env\[PATH\].*|env\[PATH\] = /usr/local/bin:/usr/bin:/bin|" $PHP_CONF
sed -i "s|.*env\[TMP\].*|env\[TMP\] = /tmp|" $PHP_CONF
sed -i "s|.*env\[TMPDIR\].*|env\[TMPDIR\] = /tmp|" $PHP_CONF
sed -i "s|.*env\[TEMP\].*|env\[TEMP\] = /tmp|" $PHP_CONF
sed -i "s|;clear_env = no|clear_env = no|" $PHP_CONF

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

systemctl restart php$PHPVER-fpm.service

#--------------------------------------------------
# Create MySQL user
#--------------------------------------------------

echo -e "\n---- Creating the PgSQL DB & User  ----"

sudo -u postgres psql <<DB
CREATE DATABASE nextcloud_db;
CREATE USER ${NC_DB_USER} WITH ENCRYPTED PASSWORD '${NC_DB_PASSWD}';
GRANT ALL PRIVILEGES ON DATABASE ${NC_DB} TO ${NC_DB_USER};
DB
echo "Done!
"

#nginx - configuration
cat << NC_NGINX > $NC_NGINX_CONF
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

    # Add headers to serve security related headers
    # Before enabling Strict-Transport-Security headers please read into this
    # topic first.
    # add_header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;";
    #
    # WARNING: Only add the preload option once you read about
    # the consequences in https://hstspreload.org/. This option
    # will add the domain to a hardcoded list that is shipped
    # in all major browsers and getting removed from this list
    # could take several months.
    add_header Referrer-Policy "no-referrer" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Download-Options "noopen" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "none" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Path to the root of your installation
    root $NC_PATH/;

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # The following 2 rules are only needed for the user_webfinger app.
    # Uncomment it if you're planning to use this app.
    #rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
    #rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json
    # last;

    location = /.well-known/carddav {
      return 301 \$scheme://\$host/remote.php/dav;
    }
    location = /.well-known/caldav {
      return 301 \$scheme://\$host/remote.php/dav;
    }    
    location ~ /.well-known/acme-challenge {
      allow all;
    }

    # set max upload size
    client_max_body_size 1024M;
    fastcgi_buffers 64 4K;

    # Enable gzip but do not remove ETag headers
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;

    # Uncomment if your server is built with the ngx_pagespeed module
    # This module is currently not supported.
    #pagespeed off;

    location / {
        rewrite ^ /index.php\$uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
        deny all;
    }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
        deny all;
    }

    location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+)\.php(?:\$|/) {
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param HTTPS on;
        #Avoid sending the security headers twice
        fastcgi_param modHeadersAvailable true;
        fastcgi_param front_controller_active true;
        fastcgi_pass php-handler;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
        fastcgi_read_timeout 300;
    }

    location ~ ^/(?:updater|ocs-provider)(?:\$|/) {
        try_files \$uri/ =404;
        index index.php;
    }

    # Adding the cache control header for js and css files
    # Make sure it is BELOW the PHP block
    location ~ \.(?:css|js|woff|svg|gif)\$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        add_header Cache-Control "public, max-age=15778463";
        # Add headers to serve security related headers (It is intended to
        # have those duplicated to the ones above)
        # Before enabling Strict-Transport-Security headers please read into
        # this topic first.
        # add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
        #
        # WARNING: Only add the preload option once you read about
        # the consequences in https://hstspreload.org/. This option
        # will add the domain to a hardcoded list that is shipped
        # in all major browsers and getting removed from this list
        # could take several months.
        add_header Referrer-Policy "no-referrer" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Download-Options "noopen" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Permitted-Cross-Domain-Policies "none" always;
        add_header X-Robots-Tag "none" always;
        add_header X-XSS-Protection "1; mode=block" always;
        # Optional: Don't log access to assets
        access_log off;
    }

    location ~ \.(?:png|html|ttf|ico|jpg|jpeg)\$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        # Optional: Don't log access to other assets
        access_log off;
    }
}
NC_NGINX
systemctl stop nginx
letsencrypt certonly --standalone --renew-by-default --agree-tos -d $NC_DOMAIN
if [ -f /etc/letsencrypt/live/$NC_DOMAIN/fullchain.pem ];then
	ln -s /etc/nginx/sites-available/$NC_DOMAIN.conf /etc/nginx/sites-enabled/
else
	echo "There are issues on getting the SSL certs..."
	read -n 1 -s -r -p "Press any key to continue"
fi
nginx -t
systemctl restart nginx

if [ "$ENABLE_HSTS" = "yes" ]; then
sed -i "s|# add_header Strict-Transport-Security|add_header Strict-Transport-Security|g" $NC_NGINX_CONF
fi

if [ "$DISTRO_RELEASE" = "bionic" ] && [ -z $PREAD_PROXY ]; then
echo "
  Setting up Nextcloud domain on Jitsi Meet turn proxy
"
	sed -i "/server {/i \ \ map \$ssl_preread_server_name \$upstream {" $JITSI_MEET_PROXY
	sed -i "/server {/i \ \ \ \ \ \ $DOMAIN      web;" $JITSI_MEET_PROXY
	sed -i "/server {/i \ \ \ \ \ \ $NC_DOMAIN web;" $JITSI_MEET_PROXY
	sed -i "/server {/i \ \ }" $JITSI_MEET_PROXY
fi

echo "
  Latest version to be installed: $STABLEVERSION
"
curl -s $NC_REPO/$STABLEVERSION.zip > /tmp/$STABLEVERSION.zip
unzip -q /tmp/$STABLEVERSION.zip
mv nextcloud $NC_PATH

chown -R www-data:www-data $NC_PATH
chmod -R 755 $NC_PATH

echo "
Database installation...
"
sudo -u www-data php $NC_PATH/occ maintenance:install \
--database=pgsql \
--database-name="$NC_DB" \
--database-user="$NC_DB_USER" \
--database-pass="$NC_DB_PASSWD" \
--admin-user="$NC_USER" \
--admin-pass="$NC_PASS"

echo "
Apply custom mods...
"
sed -i "/datadirectory/a \ \ \'skeletondirectory\' => \'\'," $NC_CONFIG
sed -i "/skeletondirectory/a \ \ \'simpleSignUpLink.shown\' => false," $NC_CONFIG
sed -i "/simpleSignUpLink.shown/a \ \ \'knowledgebaseenabled\' => false," $NC_CONFIG
sed -i "s|http://localhost|http://$NC_DOMAIN|" $NC_CONFIG

echo "Add crontab..."
crontab -u www-data -l | { cat; echo "*/5  *  *  *  * php -f $NC_PATH/cron.php"; } | crontab -u www-data -

echo "
Add memcache support...
"
sed -i "s|# unixsocket .*|unixsocket /var/run/redis/redis.sock|g" $REDIS_CONF
sed -i "s|# unixsocketperm .*|unixsocketperm 777|g" $REDIS_CONF
sed -i "s|port 6379|port 0|" $REDIS_CONF
systemctl restart redis-server

echo "--> Setting config.php..."
sed -i "/);/i \ \ 'filelocking.enabled' => 'true'," $NC_CONFIG
sed -i "/);/i \ \ 'memcache.locking' => '\\\OC\\\Memcache\\\Redis'," $NC_CONFIG
sed -i "/);/i \ \ 'memcache.local' => '\\\OC\\\Memcache\\\Redis'," $NC_CONFIG
sed -i "/);/i \ \ 'memcache.local' => '\\\OC\\\Memcache\\\Redis'," $NC_CONFIG
sed -i "/);/i \ \ 'memcache.distributed' => '\\\OC\\\Memcache\\\Redis'," $NC_CONFIG
sed -i "/);/i \ \ 'redis' =>" $NC_CONFIG
sed -i "/);/i \ \ \ \ array (" $NC_CONFIG
sed -i "/);/i \ \ \ \ \ 'host' => '/var/run/redis/redis.sock'," $NC_CONFIG
sed -i "/);/i \ \ \ \ \ 'port' => 0," $NC_CONFIG
sed -i "/);/i \ \ \ \ \ 'timeout' => 0," $NC_CONFIG
sed -i "/);/i \ \ )," $NC_CONFIG
echo "Done
"
echo "
Addding & Setting up Files External App for Local storage...
"
sudo -u www-data php $NC_PATH/occ app:install files_external
sudo -u www-data php $NC_PATH/occ app:enable files_external
sudo -u www-data php $NC_PATH/occ files_external:import /tmp/jra-nc-app-ef.json

usermod -a -G jibri www-data
chown -R jibri:www-data $DIR_RECORD
chmod -R 770 $DIR_RECORD
chmod -R g+s $DIR_RECORD

echo "
Fixing possible missing tables...
"
echo "y"|sudo -u www-data php $NC_PATH/occ db:convert-filecache-bigint
sudo -u www-data php $NC_PATH/occ db:add-missing-indices
sudo -u www-data php $NC_PATH/occ db:add-missing-columns

echo "
Adding trusted domain...
"
sudo -u www-data php $NC_PATH/occ config:system:set trusted_domains 0 --value=$NC_DOMAIN

echo "Quick Nextcloud installation complete!"
