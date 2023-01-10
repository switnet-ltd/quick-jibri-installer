#!/bin/bash
# Simple Fail2ban configuration

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

#Check if user is root
if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

apt-get -y install fail2ban

if \
[ -f /var/log/ssh_f2b.log ] && \
[ "$(grep -c 604800 /etc/fail2ban/jail.local)" = "1" ] && \
[ "$(grep -c ssh_f2b.log /etc/fail2ban/jail.local)" = "1" ]; then
    echo -e "\nFail2ban seems to be already configured.\n"
else
    echo -e "\nConfiguring Fail2ban...\n"
cat << F2BAN >> /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/ssh_f2b.log
maxretry = 3
bantime = 604800
F2BAN
fi
systemctl restart fail2ban
