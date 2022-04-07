#!/bin/bash
# Automated AWS generic kernel setup for jibri.
# SwITNet Ltd © - 2022, https://switnet.net/
# GPLv3 or later.

####
# NOTE: Only use this script if you know what you are doing.
# Under your own risk.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY.
####
wait_seconds() {
secs=$(($1))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}

# Check if user is root
if [ $UID != 0 ]; then
    echo You need to run this script as root or sudo rights!
    exit 1
fi

TMP_DIR="$(mktemp -d)"
KERNEL_LOG="$TMP_DIR/kernel_log"
GRUB_FILE="/etc/default/grub"

echo "# Check and update HWE kernel if possible..."
apt-get -q2 update
HWE_VIR_MOD=$(apt-cache madison linux-image-generic-hwe-$(lsb_release -sr) 2>/dev/null|head -n1|grep -c "hwe-$(lsb_release -sr)")
if [ "$HWE_VIR_MOD" = "1" ]; then
    apt-get -y install \
    linux-image-generic-hwe-$(lsb_release -sr) \
    linux-tools-generic-hwe-$(lsb_release -sr)
else
    apt-get -y install \
    linux-image-generic \
    linux-modules-extra-$(uname -r)
fi
apt-get -y autoremove
apt-get autoclean

#Write update-grub output
update-grub > $KERNEL_LOG 2>&1

#Get clean output
cat $KERNEL_LOG | awk -F'boot/' '{print$2}'|sed '/^[[:space:]]*$/d' | \
tee ${KERNEL_LOG}.tmp
mv ${KERNEL_LOG}.tmp $KERNEL_LOG

echo "Check if AWS kernel is installed."
[ $(grep -wc aws $KERNEL_LOG) = 0 ] && echo "No AWS kernel found, exiting..." && exit

#Get kernel number
RAW_KERNEL_NUM="$(grep -Fn generic $KERNEL_LOG|head -n1|cut -d ':' -f1)"
FIXED_KERNEL_NUM="$(awk "BEGIN{ print $RAW_KERNEL_NUM - 1 }")"

#Set up grub kernel number.
sed -i "s|GRUB_DEFAULT=.*|GRUB_DEFAULT=\"1\>$FIXED_KERNEL_NUM\"|" $GRUB_FILE

update-grub

echo "Time to reboot..."
echo "Rebooting in..."
wait_seconds 15
reboot
