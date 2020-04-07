#!/bin/bash
# Quick Nextcloud Jitsi
#

read -p "Dominio a usar para nextcloud: " -r NC_DOMAIN
read -p "Usuario para Nextcloud: " -r NC_USER
read -p "Password de usuario para Nextcloud: " -r NC_PASS

DISTRO_RELEASE=$(lsb_release -sc)
PHPVER=7.4
MDBVER=10.4
PHP_FPM_DIR=/etc/php/$PHPVER/fpm
PHP_INI=$PHP_FPM_DIR/php.ini
NC_REPO="https://download.nextcloud.com/server/releases"
NCVERSION=$(curl -s -m 900 $NC_REPO/ | sed --silent 's/.*href="nextcloud-\([^"]\+\).zip.asc".*/\1/p' | sort --version-sort | tail -1)
STABLEVERSION="nextcloud-$NCVERSION"
NC_PATH="/var/www/nextcloud"
NC_CONFIG="$NC_PATH/config/config.php"
NC_DB_USER="nextcloud_user"
NC_DB="nextcloud_db"
NC_DB_PASSWD="opwezyLWSVZ3_"
DIR_RECORD="$(grep -nr RECORDING /home/jibri/finalize_recording.sh|head -n1|cut -d "=" -f2)"

install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
	echo " $1 is installed, skipping..."
    else
    	echo -e "\n---- Installing $1 ----"
		apt -yqq install $1
fi
}
add_mariadb() {
	if [ "$(dpkg-query -W -f='${Status}' "mariadb-server" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
		echo "MariaDB already installed"
	else
		echo "# Adding MariaDB $MDBVER Repository"
		apt-key adv --recv-keys --keyserver keyserver.ubuntu.com C74CD1D8
		echo "deb [arch=amd64] http://ftp.ddg.lth.se/mariadb/repo/$MDBVER/ubuntu $DISTRO_RELEASE main" > /etc/apt/sources.list.d/mariadb.list
		apt update -qq
	fi
}
add_php74() {
	if [ "$(dpkg-query -W -f='${Status}' "php$PHPVER-fpm" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
		echo "MariaDB already installed"
	else
		echo "# Adding PHP 7.x Repository"
		apt-key adv --recv-keys --keyserver keyserver.ubuntu.com E5267A6C
		echo "deb [arch=amd64] http://ppa.launchpad.net/ondrej/php/ubuntu $DISTRO_RELEASE main" > /etc/apt/sources.list.d/php7x.list
		apt update -qq
		
	fi
}

## Install software requirements
# MariaDB
add_mariadb
install_ifnot mariadb-server-$MDBVER

# PHP 7.4
add_php74
apt install -y \
			php$PHPVER-fpm \
			php$PHPVER-bz2 \
			php$PHPVER-curl \
			php$PHPVER-gd \
			php$PHPVER-gmp \
			php$PHPVER-intl \
			php$PHPVER-json \
			php$PHPVER-ldap \
			php$PHPVER-mbstring \
			php$PHPVER-mysql \
			php$PHPVER-soap \
			php$PHPVER-xml \
			php$PHPVER-xmlrpc \
			php$PHPVER-zip \
			php-imagick

#System related
install_ifnot smbclient
sed -i "s|.*env\[HOSTNAME\].*|env\[HOSTNAME\] = \$HOSTNAME|" /etc/php/$PHPVER/fpm/pool.d/www.conf
sed -i "s|.*env\[PATH\].*|env\[PATH\] = /usr/local/bin:/usr/bin:/bin|" /etc/php/$PHPVER/fpm/pool.d/www.conf
sed -i "s|.*env\[TMP\].*|env\[TMP\] = /tmp|" /etc/php/$PHPVER/fpm/pool.d/www.conf
sed -i "s|.*env\[TMPDIR\].*|env\[TMPDIR\] = /tmp|" /etc/php/$PHPVER/fpm/pool.d/www.conf
sed -i "s|.*env\[TEMP\].*|env\[TEMP\] = /tmp|" /etc/php/$PHPVER/fpm/pool.d/www.conf
sed -i "s|;clear_env = no|clear_env = no|" /etc/php/$PHPVER/fpm/pool.d/www.conf

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

echo -e "\n---- Creating the MariaDB User  ----"
cd /tmp

mysql -u root <<DB
CREATE DATABASE ${NC_DB};
CREATE USER ${NC_DB_USER}@localhost IDENTIFIED BY '${NC_DB_PASSWD}';
GRANT ALL PRIVILEGES ON ${NC_DB}.* TO '${NC_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
DB

#Tune MariaDB
#mysql_secure_installation

#nginx - configuration
cat << NC_NGINX > /etc/nginx/sites-available/$NC_DOMAIN.conf
server {
    listen 80;
    server_name $NC_DOMAIN;

    # Add headers to serve security related headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header X-Download-Options noopen;
    add_header X-Permitted-Cross-Domain-Policies none;

    # Path to the root of your installation
    root $NC_PATH;

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

    # Disable gzip to avoid the removal of the ETag header
    gzip off;

    # Uncomment if your server is build with the ngx_pagespeed module
    # This module is currently not supported.
    #pagespeed off;

    error_page 403 /core/templates/403.php;
    error_page 404 /core/templates/404.php;

    location / {
       rewrite ^ /index.php\$uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
       deny all;
    }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
       deny all;
     }

    location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+|core/templates/40[34])\.php(?:\$|/) {
       include fastcgi_params;
       fastcgi_split_path_info ^(.+\.php)(/.*)\$;
       fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
       fastcgi_param PATH_INFO \$fastcgi_path_info;
       #Avoid sending the security headers twice
       fastcgi_param modHeadersAvailable true;
       fastcgi_param front_controller_active true;
       fastcgi_pass unix:/run/php/php7.4-fpm.sock;
       fastcgi_intercept_errors on;
       fastcgi_request_buffering off;
    }

    location ~ ^/(?:updater|ocs-provider)(?:\$|/) {
       try_files \$uri/ =404;
       index index.php;
    }

    # Adding the cache control header for js and css files
    # Make sure it is BELOW the PHP block
    location ~* \.(?:css|js)\$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        add_header Cache-Control "public, max-age=7200";
        # Add headers to serve security related headers (It is intended to
        # have those duplicated to the ones above)
#        add_header X-Content-Type-Options nosniff;
#        add_header X-XSS-Protection "1; mode=block";
#        add_header X-Robots-Tag none;
#        add_header X-Download-Options noopen;
#        add_header X-Permitted-Cross-Domain-Policies none;
        # Optional: Don't log access to assets
        access_log off;
   }

   location ~* \.(?:svg|gif|png|html|ttf|woff|ico|jpg|jpeg)\$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        # Optional: Don't log access to other assets
        access_log off;
   }
}
NC_NGINX

ln -s /etc/nginx/sites-available/$NC_DOMAIN.conf /etc/nginx/sites-enabled/

nginx -t
systemctl reload nginx

echo "
  Latest version to be installed: $STABLEVERSION
"
cd /tmp && wget $NC_REPO/$STABLEVERSION.zip
unzip -q $STABLEVERSION.zip
sudo mv nextcloud $NC_PATH

chown -R www-data:www-data $NC_PATH
chmod -R 755 $NC_PATH

if $(dpkg --compare-versions "$NCVERSION" "le" "18.0.3"); then 
echo "
-> Patching #425 (scssphp/src/Compiler.php)..."
cd $NC_PATH/3rdparty/leafo/scssphp/src
sudo -u www-data curl -s https://nc.switnet.net/s/J89EmtEKcgj9AwP/download \
> patch_425_3thy.patch
sudo -u www-data patch -p0  < patch_425_3thy.patch
rm patch_425_3thy.patch
fi

echo "
Database installation...
"
cd $NC_PATH
sudo -u www-data php occ maintenance:install \
--database=mysql \
--database-name="$NC_DB" \
--database-user="$NC_DB_USER" \
--database-pass="$NC_DB_PASSWD" \
--admin-user="$NC_USER" \
--admin-pass="$NC_PASS"

echo "
Prevent demo data on accounts and custom mods...
"
sed -i "/datadirectory/a \ \ \'skeletondirectory\' => \'\'," $NC_CONFIG
sed -i "/skeletondirectory/a \ \ \'simpleSignUpLink.shown\' => false," $NC_CONFIG
sed -i "/simpleSignUpLink.shown/a \ \ \'knowledgebaseenabled\' => false," $NC_CONFIG
sed -i "s|http://localhost|http://$NC_DOMAIN|" $NC_CONFIG

echo "
Addding & Setting up Files External App for Local storage...
"
sudo -u www-data php occ app:install files_external
sudo -u www-data php occ app:enable files_external
curl -s https://nc.switnet.net/s/r22QLNMYzLcay39/download > /tmp/jb-qnci-ef.json
sudo -u www-data php $NC_PATH/occ files_external:import /tmp/jb-qnci-ef.json

usermod -a -G jibri www-data
chown -R jibri:www-data $DIR_RECORD
chmod -R 770 $DIR_RECORD
chmod -R g+s $DIR_RECORD

echo "
Fixing possible missing tables...
"
echo "y"|sudo -u www-data php occ db:convert-filecache-bigint
sudo -u www-data php occ db:add-missing-indices

echo "
Adding trusted domain...
"
sudo -u www-data php occ config:system:set trusted_domains 0 --value=$NC_DOMAIN

echo "Quick Nextcloud installation complete!"
