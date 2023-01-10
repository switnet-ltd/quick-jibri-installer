#!/bin/bash
# Automated AWS generic kernel setup for jibri.

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

wait_seconds() {
secs=$(($1))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}

echo "####
# WARNING: Only use this script if you know what you are doing.
# Under your own risk.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY.
####"

# Check if user is root
if [ "$UID" != 0 ]; then
    echo You need to run this script as root or sudo rights!
    exit 1
fi

TMP_DIR="$(mktemp -d)"
KERNEL_LOG="$TMP_DIR/kernel_log"
GRUB_FILE="/etc/default/grub"

echo -e "# Check and update HWE kernel if possible...\n"
apt-get -q2 update
HWE_VIR_MOD="$(apt-cache madison linux-image-generic-hwe-"$(lsb_release -sr)" 2>/dev/null|head -n1|grep -c hwe-"$(lsb_release -sr)")"
if [ "$HWE_VIR_MOD" = "1" ]; then
    apt-get -y install \
    linux-image-generic-hwe-"$(lsb_release -sr)" \
    linux-tools-generic-hwe-"$(lsb_release -sr)"
else
    apt-get -y install \
    linux-image-generic \
    linux-modules-extra-"$(uname -r)"
fi
apt-get -y autoremove
apt-get autoclean

#Write update-grub output
update-grub > "$KERNEL_LOG" 2>&1

#Get clean output
awk -F'boot/' '{print$2}' < "$KERNEL_LOG"|sed '/^[[:space:]]*$/d' | \
tee "$KERNEL_LOG".tmp
mv "$KERNEL_LOG".tmp "$KERNEL_LOG"

echo -e "Check if AWS kernel is installed.\n"
[ "$(grep -wc aws "$KERNEL_LOG")" = 0 ] && echo "No AWS kernel found, exiting..." && exit

#Get kernel number
RAW_KERNEL_NUM="$(grep -Fn generic "$KERNEL_LOG"|head -n1|cut -d ':' -f1)"
FIXED_KERNEL_NUM="$(awk "BEGIN{ print $RAW_KERNEL_NUM - 1 }")"

echo -e "Set up GRUB for custom kernel.\n"
sed -i "s|GRUB_DEFAULT=.*|GRUB_DEFAULT=\"1\>$FIXED_KERNEL_NUM\"|" "$GRUB_FILE"

echo -e "Saving changes...\n"
update-grub

echo "Time to reboot..."
echo "Rebooting in..."
wait_seconds 15
reboot
