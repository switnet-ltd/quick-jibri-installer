#!/bin/bash
# Simple Jibri resolution enhancer
# SwITNet Ltd © - 2021, https://switnet.net/
# GNU GPLv3 or later.

while getopts m: option
do
    case "${option}"
    in
        m) MODE=${OPTARG};;
        \?) echo "Usage: sudo ./jibri-resolution-enhancer.sh [-m debug]" && exit;;
    esac
done

#DEBUG
if [ "$MODE" = "debug" ]; then
  set -x
fi

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

# Make sure jibri is installed
if [ "$(dpkg-query -W -f='${Status}' jibri 2>/dev/null | grep -c "ok installed")" == "1" ]; then
  echo "Good Jibri is installed on this server"
else
  echo "Jibri is not on this system, it is a requirement.
Exiting..."
  exit
fi

apt-get -y install apt-show-versions

JIBRI_OPT="/opt/jitsi/jibri"
JIBRI_ENH_PATH="/opt/jibri-res-enhancer"
INSTALLED_JIBRI_VERSION="$(apt-show-versions jibri|awk '{print$2}')"

#Check if already run
if [ -f "$JIBRI_OPT/jibri-res_enh.jar" ] && \
   [ -d "$JIBRI_ENH_PATH" ]; then
  echo "Seems this tools have been run before..."
  exit
fi

mkdir /tmp/jibri
cd /tmp/jibri

#Get md5sum for current jibri installed.
apt-get download jibri=$INSTALLED_JIBRI_VERSION
ar x jibri_*.deb
tar xvf data.tar.xz
UPSTREAM_DEB_JAR_SUM="$(md5sum opt/jitsi/jibri/jibri.jar |awk '{print$1}')"

if [ -z $UPSTREAM_DEB_JAR_SUM ]; then
  echo "Not possible to continue, exiting..."
  exit
fi

#Compile requisites
apt-get -y install devscripts \
                   git \
                   maven \
                   openjdk-8-jdk

#Build repository
git clone https://github.com/jitsi/jibri $JIBRI_ENH_PATH
cd $JIBRI_ENH_PATH

# Default values
## videoEncodePreset - "veryfast" || h264ConstantRateFactor - 25
# Recomemended values based on: https://trac.ffmpeg.org/wiki/Encode/H.264#crf
## videoEncodePreset - "medium" || h264ConstantRateFactor - 15
sed -i "/videoEncodePreset/s|String =.*|String = \"medium\",|"  src/main/kotlin/org/jitsi/jibri/capture/ffmpeg/FfmpegCapturer.kt
sed -i "/h264ConstantRateFactor/s|Int =.*|Int = 15,|"  src/main/kotlin/org/jitsi/jibri/capture/ffmpeg/FfmpegCapturer.kt
mvn package

JIBRI_JAR="$(ls -Sh $JIBRI_ENH_PATH/target|awk '/dependencies/&&/.jar/{print}'|awk 'NR==1{print}')"
cp $JIBRI_ENH_PATH/target/$JIBRI_JAR $JIBRI_ENH_PATH/target/jibri.jar

# Backing up default binaries
if [ "$UPSTREAM_DEB_JAR_SUM" = "$(md5sum $JIBRI_OPT/jibri.jar)" ]; then
  cp $JIBRI_OPT/jibri.jar $JIBRI_OPT/jibri-dpkg-package.jar
fi

# Migrate original to enhanced jibri
cp $JIBRI_ENH_PATH/target/jibri.jar $JIBRI_OPT/jibri-res_enh.jar
if [ -f $JIBRI_OPT/jibri-dpkg-package.jar ];then
 cp $JIBRI_OPT/jibri-res_enh.jar $JIBRI_OPT/jibri.jar
fi

JIBRI_RES_ENH_HASH="$(md5sum $JIBRI_OPT/jibri-res_enh.jar)"
USED_JIBRI_HASH="$(md5sum $JIBRI_OPT/jibri.jar)"

if [ "$JIBRI_RES_ENH_HASH" = "$USED_JIBRI_HASH" ]; then
  echo "Everything seems to have gone well."
else 
  echo "Something went wrong, restoring default package..."
  if [ "$(md5sum $JIBRI_OPT/jibri-dpkg-package.jar)" = "$UPSTREAM_DEB_JAR_SUM" ]; then
    cp $JIBRI_OPT/jibri-dpkg-package.jar $JIBRI_OPT/jibri.jar 
  else
    if [ -f /tmp/jibri/opt/jitsi/jibri/jibri.jar ]; then
      echo "Restoring from upstream package..."
      cp /tmp/jibri/opt/jitsi/jibri/jibri.jar $JIBRI_OPT/jibri.jar
    else
      echo "Wow, someone took the time to avoid restauration, please manually review your changes."
      echo "Exiting..."
      exit
    fi
  fi
fi
systemctl restart jibri*

