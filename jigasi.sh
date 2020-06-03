#!/bin/bash
# Quick Jigasi Installer - *buntu (LTS) based systems.
# SwITNet Ltd © - 2020, https://switnet.net/
# GPLv3 or later.

##################### Whistlist #######################
# Saves final transcript in translated languages #130 - 
# https://github.com/jitsi/jigasi/pull/130
#######################################################

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

clear
echo '
########################################################################
                       Jigasi Transcript addon
########################################################################
                    by Software, IT & Networks Ltd
'

JIGASI_CONFIG=/etc/jitsi/jigasi/config
GC_API_JSON=/opt/gc-sdk/GCTranscriptAPI.json
DOMAIN=$(ls /etc/prosody/conf.d/ | grep -v localhost | awk -F'.cfg' '{print $1}' | awk '!NF || !seen[$0]++')
MEET_CONF=/etc/jitsi/meet/${DOMAIN}-config.js
JIG_SIP_PROP=/etc/jitsi/jigasi/sip-communicator.properties
DIST=$(lsb_release -sc)
CHECK_GC_REPO=$(apt-cache policy | grep http | grep cloud-sdk | head -n1 | awk '{print $3}' | awk -F '/' '{print $1}')

install_gc_repo() {
	if [ "$CHECK_GC_REPO" = "cloud-sdk-$DIST" ]; then
	echo "
Google Cloud SDK repository already on the system!
"
else
	echo "
Adding Google Cloud SDK repository for latest updates
"
	export CLOUD_SDK_REPO="cloud-sdk-$DIST"
	echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

fi
}
install_gc_repo
apt-get -q2 update
apt-get -y install google-cloud-sdk google-cloud-sdk-app-engine-java

echo "Please select one of the current options:
[1] I want to configure a new project, service account, billing and JSON credentials.
[2] I already have one project configured and already have a JSON key file from Google"
while [[ $SETUP_TYPE != 1 && $SETUP_TYPE != 2 ]]
do
read -p "What option suits your setup?: (1 or 2)"$'\n' -r SETUP_TYPE
if [ $SETUP_TYPE = 1 ]; then
	echo "We'll setup a GC Projects from scratch"
elif [ $SETUP_TYPE = 2 ]; then
	echo "We'll setup only the proect and JSON key."
fi
done

if [ $SETUP_TYPE = 1 ]; then
### Start of new project configuration - Google SDK
#Setup option 1 - Google Cloud SDK
echo "Once logged on Google Cloud SDK, please create a new project (last option)."
gcloud init
read -p "Enter the project name you just created for Jigasi Speech-to-Text"$'\n' -r GC_PROJECT_NAME
#Second login - Google Auth Library
echo "Login to Google Auth Library"
gcloud auth application-default login

# Start Google Cloud Configuration - Application Service
GC_MEMBER=transcript
echo "Checking if project exist..."
PROJECT_GC_ID=$(gcloud projects list | grep $GC_PROJECT_NAME | awk '{print$3}')
while [ -z $PROJECT_GC_ID ]
do
read -p "Enter the project name you just created for Jigasi Speech-to-Text"$'\n' -r GC_PROJECT_NAME
if [ -z PROJECT_GC_ID ]; then
	echo "Please check your project name,
	There is no project listed with the provided name: $GC_PROJECT_NAME"
	PROJECT_GC_ID=$(gcloud projects list | grep $GC_PROJECT_NAME | awk '{print$3}')
fi
done
echo "Your $GC_PROJECT_NAME ID's project is: $PROJECT_GC_ID"

# Enable Speech2Text
echo "Important: Please enable billing on your project using the following URL:
https://console.developers.google.com/project/$PROJECT_GC_ID/settings"

echo "Checking billing..."
CHECK_BILLING="$(gcloud services enable speech.googleapis.com 2>/dev/null)"
while [[ $? -eq 1 ]]
do
CHECK_BILLING="$(gcloud services enable speech.googleapis.com 2>/dev/null)"
if [[ $? -eq 1 ]]; then
        echo "Seems you haven't enabled billing for this project: $GC_PROJECT_NAME
    For that go to: https://console.developers.google.com/project/$PROJECT_GC_ID/settings
    "
        read -p "Press Enter to continue"
        CHECK_BILLING="$(gcloud services enable speech.googleapis.com 2>/dev/null)"
fi
done
echo "Billing account seems setup, continuing..."

gcloud iam service-accounts create $GC_MEMBER

gcloud projects add-iam-policy-binding  $GC_PROJECT_NAME \
    --member serviceAccount:$GC_MEMBER@$GC_PROJECT_NAME.iam.gserviceaccount.com \
    --role  roles/editor

echo "Setup credentials:"
echo "Please go and download your valid json key at:
https://console.developers.google.com/apis/credentials?folder=&organizationId=&project=$GC_PROJECT_NAME"
### End of new project configuration - Google SDK
fi

if [ $SETUP_TYPE = 2 ]; then
#Setup option 1 - Google Cloud SDK
echo "Once logged on Google Cloud SDK, please select the project that owns to the JSON key."
gcloud init
echo "Login to Google Auth Library"
gcloud auth application-default login
fi

echo "Setting up JSON key file..."
sleep 2
mkdir /opt/gc-sdk/
cat << KEY_JSON > $GC_API_JSON
#
# Paste below this comment your GC JSON key for the service account:
# $GC_MEMBER@$GC_PROJECT_NAME.iam.gserviceaccount.com
#
# Visit the following URL and create a *Service Account Key*:
# https://console.developers.google.com/apis/credentials?folder=&organizationId=&project=$GC_PROJECT_NAME
# These comment lines will be deleted afterwards.
#
KEY_JSON
chmod 644 $GC_API_JSON
nano $GC_API_JSON
sed -i '/^#/d' $GC_API_JSON

CHECK_JSON_KEY="$(cat $GC_API_JSON | python -m json.tool 2>/dev/null)"
while [[ $? -eq 1 ]]
do
CHECK_JSON_KEY="$(cat $GC_API_JSON | python -m json.tool 2>/dev/null)"
if [[ $? -eq 1 ]]; then
        echo "Check again your JSON file, syntax doesn't seem right"
        sleep 2
        nano $GC_API_JSON
        CHECK_JSON_KEY="$(cat $GC_API_JSON | python -m json.tool 2>/dev/null)"
fi
done
echo "
Great, seems your JSON key syntax is fine.
"
sleep 2

export GOOGLE_APPLICATION_CREDENTIALS=$GC_API_JSON

echo "Installing Jigasi, your SIP credentials will be asked. (mandatory)"
apt-get -y install jigasi=1.0-235
apt-mark hold jigasi

cat  << JIGASI_CONF >> $JIGASI_CONFIG

GOOGLE_APPLICATION_CREDENTIALS=$GC_API_JSON

JIGASI_CONF

echo "Your Google Cloud credentials are at $GC_API_JSON"

echo "Setting up Jigasi transcript with current platform..."
#Connect callcontrol
sed -i "s|// call_control:|call_control:|" $MEET_CONF
sed -i "s|// transcribingEnabled|transcribingEnabled|" $MEET_CONF
sed -i "/transcribingEnabled/ s|false|true|" $MEET_CONF

#siptest2siptest@domain.con
#changed from conference to internal.auth from jibri
sed -i "s|siptest|siptest@internal.auth.$DOMAIN|" $JIG_SIP_PROP

#Enable transcript / disable sip
sed -i "/ENABLE_TRANSCRIPTION/ s|#||" $JIG_SIP_PROP
sed -i "/ENABLE_TRANSCRIPTION/ s|false|true|" $JIG_SIP_PROP
sed -i "/ENABLE_SIP/ s|#||" $JIG_SIP_PROP
sed -i "/ENABLE_SIP/ s|true|false|" $JIG_SIP_PROP

#Transcript format
sed -i "/SAVE_JSON/ s|# ||" $JIG_SIP_PROP
sed -i "/SEND_JSON/ s|# ||" $JIG_SIP_PROP
sed -i "/SAVE_TXT/ s|# ||" $JIG_SIP_PROP
sed -i "/SEND_TXT/ s|# ||" $JIG_SIP_PROP
#sed -i "/SEND_TXT/ s|false|true|" $JIG_SIP_PROP

#Remember to study how to use LE or what's needed #ToDo
sed -i "/ALWAYS_TRUST_MODE_ENABLED/ s|# ||" $JIG_SIP_PROP

#Jigasi credentials
sed -i "/xmpp.acc.USER_ID/ s|# ||" $JIG_SIP_PROP
sed -i "/xmpp.acc.USER_ID/ s|SOME_USER\@SOME_DOMAIN|transcript\@auth.$DOMAIN|" $JIG_SIP_PROP
sed -i "/xmpp.acc.PASS/ s|# ||" $JIG_SIP_PROP
sed -i "/xmpp.acc.PASS/ s|SOME_PASS|jigasi|" $JIG_SIP_PROP
sed -i "/xmpp.acc.ANONYMOUS_AUTH/ s|# ||" $JIG_SIP_PROP

prosodyctl register transcript auth.$DOMAIN jigasi

#Temp fix Jigasi Transcript
if grep -q "sleep" /etc/init.d/jicofo; then
	echo "Jicofo delay already present."
	else
	echo "Adding Jicofo delay..."
	sed -i "/\/lib\/lsb\/init-functions/i sleep 20" /etc/init.d/jicofo
	systemctl daemon-reload
fi

systemctl restart 	prosody \
					jicofo \
					jibri* \
					jitsi-videobridge*
echo "
To test, you need to enable subtitles beforehand then invite \
\"jitsi_meet_transcribe\" to the meeting (no quotes).
"

echo "
Full transcript files are available at:
--> /var/lib/jigasi/transcripts/
"

echo "
Happy transcripting!
"

#APP.conference._room.dial("jitsi_meet_transcribe");
