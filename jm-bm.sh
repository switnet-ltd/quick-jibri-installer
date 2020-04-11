#!/bin/bash
# Jitsi Meet brandless mode
# for Debian/*buntu binaries.
# 2020 - SwITNet Ltd
# GNU GPLv3 or later.

CSS_FILE="/usr/share/jitsi-meet/css/all.css"
TITLE_FILE="/usr/share/jitsi-meet/title.html"
INT_CONF="/usr/share/jitsi-meet/interface_config.js"
#
JM_IMG_PATH="/usr/share/jitsi-meet/images/"
WTM2_PATH="$JM_IMG_PATH/watermark2.png"
FICON_PATH="$JM_IMG_PATH/favicon2.ico"
#
APP_NAME="Conferences"
PART_USER="Participant"
echo '
#--------------------------------------------------
# Applying Brandless mode
#--------------------------------------------------
'
#Watermark
if [ ! -f $WTM2_PATH ]; then
	cp images/watermark2.png $WTM2_PATH
else
	echo "watermark2 file exists, skipping copying..."
fi
#Favicon
if [ ! -f $FICON_PATH ]; then
	cp images/favicon2.ico $FICON_PATH
else
	echo "favicon2 file exists, skipping copying..."
fi

#Custom / Remove icons
sed -i "s|watermark.png|watermark2.png|g" $CSS_FILE
sed -i "s|favicon.ico|favicon2.ico|g" $TITLE_FILE
sed -i "s|jitsilogo.png|watermark2.png|g" $TITLE_FILE

#Disable logo and url
sed -i "s|.leftwatermark{|.leftwatermark{display:none;|" $CSS_FILE

#Customize room title
sed -i "s|Jitsi Meet|$APP_NAME|g" $TITLE_FILE
sed -i "s| powered by the Jitsi Videobridge||g" $TITLE_FILE
sed -i "21,32 s|Jitsi Meet|$APP_NAME|g" $INT_CONF

#Custom UI changes
echo "
Please note that brandless mode will also overwrite support links.
"
sed -i "s|Fellow Jitster|$PART_USER|g" $INT_CONF
sed -i "s|LIVE_STREAMING_HELP_LINK: .*|LIVE_STREAMING_HELP_LINK: '#',|g" $INT_CONF
sed -i "s|SUPPORT_URL: .*|SUPPORT_URL: '#',|g" $INT_CONF
