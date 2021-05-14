#!/bin/bash
# System-tune-up to remove system restrictions on a huge load of connections.
# SwITNet Ltd © - 2021, https://switnet.net/
# GPLv3 or later.

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have privileges!"
   exit 0
fi

while getopts m: option
do
	case "${option}"
	in
		m) MODE=${OPTARG};;
		\?) echo "Usage: sudo ./jms-stu.sh [-m debug]" && exit;;
	esac
done

echo '
#--------------------------------------------------
# Starting system tune up configuration 
# for high performance
#--------------------------------------------------
'

#DEBUG
if [ "$MODE" = "debug" ]; then
set -x
fi

set_once() {
if [ -z "$(awk '!/^ *#/ && NF {print}' "$2"|grep $(echo $1|awk -F '=' '{print$1}'))" ]; then
  echo "Setting "$1" on "$2"..."
  echo "$1" | tee -a "$2"
else
  echo " \"$(echo $1|awk -F '=' '{print$1}')\" seems present, skipping setting this variable"
fi
}

##Disable swap
swapoff -a
sed -r  '/\sswap\s/s/^#?/#/' -i $FSTAB

##Alternative swap tuning (need more documentation).
#vm.swappiness=10
#vm.vfs_cache_pressure=50

##Kernel
#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/5/html/tuning_and_optimizing_red_hat_enterprise_linux_for_oracle_9i_and_10g_databases/sect-oracle_9i_and_10g_tuning_guide-adjusting_network_settings-changing_network_kernel_settings
sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=262144
sysctl -w net.core.wmem_max=262144
set_once "net.core.rmem_default=262144" "/etc/sysctl.conf"
set_once "net.core.wmem_default=262144" "/etc/sysctl.conf"
set_once "net.core.rmem_max=262144" "/etc/sysctl.conf"
set_once "net.core.wmem_max=262144" "/etc/sysctl.conf"

#system
#https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart
sysctl -w DefaultLimitNOFILE=65000
sysctl -w DefaultLimitNPROC=65000
sysctl -w DefaultTasksMax=65000
set_once "DefaultLimitNOFILE=65000" "/etc/sysctl.conf"
set_once "DefaultLimitNPROC=65000" "/etc/sysctl.conf"
set_once "DefaultTasksMax=65000" "/etc/sysctl.conf"

#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/reduce_tcp_performance_spikes
sysctl -w net.ipv4.tcp_timestamps=0
set_once "net.ipv4.tcp_timestamps=0" "/etc/sysctl.conf"

#https://bugzilla.redhat.com/show_bug.cgi?id=1283676
sysctl -w net.core.netdev_max_backlog=100000
set_once "net.core.netdev_max_backlog=100000" "/etc/sysctl.conf"

##nginx
sed -i "s|worker_connections.*|worker_connections 2000;|" /etc/nginx/nginx.conf
nginx -t

#Missing docs
#sysctl -w net.ipv4.tcp_low_latency=1

echo "System tune up...
  Done!"
