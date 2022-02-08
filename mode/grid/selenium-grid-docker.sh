#!/bin/bash
# Custom Selenium Grid-Node fro Jitsi Meet
# Pandian © - https://community.jitsi.org/u/Pandian
# SwITNet Ltd © - 2021, https://switnet.net/
# GPLv3 or later.

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

WAN_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
AV_SPACE="$(df -h .|grep -v File|awk '{print$4}'|sed -e 's|G||')"

echo -e "\n-- Make sure you have at least 10GB of disk space available.\n"
if [ $(echo "$AV_SPACE > 9" | bc) -ne 0 ]; then
  echo "> Seems we have enough disk space."
else
  echo "> Please meet the minimum required disk space for this installer, exiting..."
  exit
fi

apt-get update
apt-get dist-upgrade -y
apt-get install -y \
                         gnupg \
                         bmon \
                         curl \
                         wget \
                         unzip \
                         maven \
                         openjdk-8-jdk
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
## Docker Compose
curl -sL "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Jitsi Meet Torture
cd /opt
git clone https://github.com/jitsi/jitsi-meet-torture
cd jitsi-meet-torture/resources
if [ -f FourPeople_1280x720_30.y4m ] ; then
  echo "FourPeople_1280x720_30.y4m exists"
else
  echo "FourPeople_1280x720_30.y4m doesn't exists, getting a copy..."
  wget -c https://media.xiph.org/video/derf/y4m/FourPeople_1280x720_60.y4m
  cp FourPeople_1280x720_60.y4m FourPeople_1280x720_30.y4m
fi
cd ..

#150 "participants" available
## Tested up to 120 with AWS c5.24xlarge
cat << SELENIUM_GRID_DOCKER > selenium.yml
version: "3"
services:
  selenium-hub:
    image: selenium/hub:3.141.59-20200525
    container_name: selenium-hub
    ports:
      - "4444:4444"
    restart: always
  chrome:
    image: selenium/node-chrome:3.141.59-20200525
    volumes:
      - /dev/shm:/dev/shm
      - ./resources:/usr/share/jitsi-meet-torture/resources
    depends_on:
      - selenium-hub
    environment:
      - HUB_HOST=selenium-hub
      - HUB_PORT=4444
      - NODE_MAX_INSTANCES=30
      - NODE_MAX_SESSION=30
    restart: always
  chrome2:
    image: selenium/node-chrome:3.141.59-20200525
    volumes:
      - /dev/shm:/dev/shm
      - ./resources:/usr/share/jitsi-meet-torture/resources
    depends_on:
      - selenium-hub
    environment:
      - HUB_HOST=selenium-hub
      - HUB_PORT=4444
      - NODE_MAX_INSTANCES=30
      - NODE_MAX_SESSION=30
    restart: always
  chrome3:
    image: selenium/node-chrome:3.141.59-20200525
    volumes:
      - /dev/shm:/dev/shm
      - ./resources:/usr/share/jitsi-meet-torture/resources
    depends_on:
      - selenium-hub
    environment:
      - HUB_HOST=selenium-hub
      - HUB_PORT=4444
      - NODE_MAX_INSTANCES=30
      - NODE_MAX_SESSION=30
    restart: always
  chrome4:
    image: selenium/node-chrome:3.141.59-20200525
    volumes:
      - /dev/shm:/dev/shm
      - ./resources:/usr/share/jitsi-meet-torture/resources
    depends_on:
      - selenium-hub
    environment:
      - HUB_HOST=selenium-hub
      - HUB_PORT=4444
      - NODE_MAX_INSTANCES=30
      - NODE_MAX_SESSION=30
    restart: always
  chrome5:
    image: selenium/node-chrome:3.141.59-20200525
    volumes:
      - /dev/shm:/dev/shm
      - ./resources:/usr/share/jitsi-meet-torture/resources
    depends_on:
      - selenium-hub
    environment:
      - HUB_HOST=selenium-hub
      - HUB_PORT=4444
      - NODE_MAX_INSTANCES=30
      - NODE_MAX_SESSION=30
    restart: always
SELENIUM_GRID_DOCKER

docker-compose -f selenium.yml up -d

echo -e "\n#=================== End of Seleniun Grid build ========================#\n"
echo -e "\nChange the values according to you test requirements using something like;\n"
echo "cd /opt/jitsi-meet-torture
sudo bash /opt/jitsi-meet-torture/scripts/malleus.sh \\
                        --conferences=1 \\
                        --participants=30 \\
                        --senders=2 \\
                        --audio-senders=1 \\
                        --duration=120 \\
                        --room-name-prefix=hamertesting \\
                        --hub-url=http://localhost:4444/wd/hub \\
                        --instance-url=https://YOUR.JITSI-MEET-INSTANCE.DOMAIN
"
echo -e "\n-- If using 'hamertesting' as prefix name you can join the room 
hamertesting0, hamertesting1, hamertestingN 
according to the 'N' number of conferences you have set to watch the test.

*Beware* for 120 \"participants\" to join video-muted it was necessary at least a c5.24xlarge AWS instance.
So start low, monitor your server resources and go from there."

echo -e "\n-- You can check the grid status at:
http://$WAN_IP:4444/grid/console
"
