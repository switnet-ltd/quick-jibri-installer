#!/bin/bash
# System-tune-up to remove system software restrictions on a huge load of connections.
# Be aware that hardware/infrastructure resources are the most common limiters.
#
# SwITNet Ltd © - 2022, https://switnet.net/
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

#Check if user is root
if ! [ "$(id -u)" = 0 ]; then
   echo "You need to be root or have privileges!"
   exit 0
fi

echo '
#--------------------------------------------------
# Starting system tune up configuration
# for high performance
#--------------------------------------------------
'

set_once_hash_comment() {
if ! awk '!/^ *#/ && NF {print}' "$2"|grep -q "$(awk -F '=' '{print$1}' <<< "$1")" ; then
  echo "Setting $1 on $2..."
  echo "$1" | tee -a "$2"
else
  echo "\"$(awk -F '=' '{print$1}' <<< "$1")\" seems already present, skipping setting this variable"
fi
}
FSTAB=/etc/fstab

##Disable swap
swapoff -a
sed -r  '/\sswap\s/s/^#?/#/' -i "$FSTAB"

##Alternative swap tuning (need more documentation).
#vm.swappiness=5
#vm.vfs_cache_pressure=50

##Kernel
#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/5/html/tuning_and_optimizing_red_hat_enterprise_linux_for_oracle_9i_and_10g_databases/sect-oracle_9i_and_10g_tuning_guide-adjusting_network_settings-changing_network_kernel_settings
sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=262144
sysctl -w net.core.wmem_max=262144
set_once_hash_comment "net.core.rmem_default=262144" "/etc/sysctl.conf"
set_once_hash_comment "net.core.wmem_default=262144" "/etc/sysctl.conf"
set_once_hash_comment "net.core.rmem_max=262144" "/etc/sysctl.conf"
set_once_hash_comment "net.core.wmem_max=262144" "/etc/sysctl.conf"

#system
#https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart
set_once_hash_comment "DefaultLimitNOFILE=65000" "/etc/sysctl.conf"
set_once_hash_comment "DefaultLimitNPROC=65000" "/etc/sysctl.conf"
set_once_hash_comment "DefaultTasksMax=65000" "/etc/sysctl.conf"

#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/reduce_tcp_performance_spikes
sysctl -w net.ipv4.tcp_timestamps=0
set_once_hash_comment "net.ipv4.tcp_timestamps=0" "/etc/sysctl.conf"

#https://bugzilla.redhat.com/show_bug.cgi?id=1283676
sysctl -w net.core.netdev_max_backlog=100000
set_once_hash_comment "net.core.netdev_max_backlog=100000" "/etc/sysctl.conf"

##nginx
sed -i "s|worker_connections.*|worker_connections 2000;|" /etc/nginx/nginx.conf
nginx -t

#Missing docs
#sysctl -w net.ipv4.tcp_low_latency=1

echo "System tune up...
  Done!"
