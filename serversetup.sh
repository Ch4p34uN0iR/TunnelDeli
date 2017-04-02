#!/bin/bash

###################################################
#
#   ServerSetup - written by Justin Ohneiser
# ------------------------------------------------
# This program will install and configure the
# server portion of the TunnelDeli system
# including the following services:
# 	- ssh
#	- iodine
#	- ptunnel
# 	- stunnel
#
# [Warning]:
# This script comes as-is with no promise of functionality or accuracy.  I strictly wrote it for personal use
# I have no plans to maintain updates, I did not write it to be efficient and in some cases you may find the
# functions may not produce the desired results so use at your own risk/discretion. I wrote this script to
# target machines in a lab environment so please only use it against systems for which you have permission!!
#-------------------------------------------------------------------------------------------------------------
# [Modification, Distribution, and Attribution]:
# You are free to modify and/or distribute this script as you wish.  I only ask that you maintain original
# author attribution and not attempt to sell it or incorporate it into any commercial offering (as if it's
# worth anything anyway :)
#
# Designed for use in Ubuntu 16.04
###################################################

Y="\033[93m"
G="\033[92m"
R="\033[91m"
END="\033[0m"

if [[ $EUID -ne 0 ]]; then
  echo -e $R"[-] Script must be run as root"$END
  exit 1
fi

declare -a ISSUES

function check() {
  if [ $? -ne 0 ]; then
    echo -e $R"[-] Error with: $1"$END
    ISSUES[${#ISSUES[*]}]="Error with: $1"
    return 1
  fi
  return 0
}

function shouldInstall() {
  for arg in "${@:2}"
  do
    [ "all" == $arg ] && return 0
    [ $1 == $arg ] && return 0
  done
  return 1
}

if [ $# -eq 0 ]
then
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "    all"
  echo "    ssh"
  echo "    iodine"
  echo "    ptunnel"
  echo "    stunnel"
  exit 2
fi

echo "=============================================="
echo "         TunnelDeli Server Installer"
echo ""
echo "  Intended for installation on Ubuntu 16.04."
echo "=============================================="

while true; do
  read -s -p "What password should the tunnel services use? " tunnel_password
  echo ""
  read -s -p "Confirm password: " t2
  echo ""
  if [ "$t2" = "$tunnel_password" ]; then
    unset t2
    break
  else
    echo -e $R"[-] Passwords must match"$END
  fi
done

echo -e $Y"[*] Updating system..."$END
apt-get update
apt-get upgrade -y
check "System update"

#
# ======= Configure SSH =======
#

if $(shouldInstall "ssh" $@)
then

  echo -e $Y"[*] Installing ssh..."$END
  apt-get install -y openssh-server openssh-sftp-server
  check "Installing ssh"

  echo -e $Y"[*] Configuring ssh..."$END
  sed -i -- 's/PermitRootLogin/PermitRootLogin yes # /' /etc/ssh/sshd_config
  check "Configuring ssh"

  echo -e $Y"[*] Enabling ssh to start at boot..."$END
  systemctl enable ssh
  check "Enabling ssh to start at boot"

fi

#
# ======= Configure iodine =======
#

if $(shouldInstall "iodine" $@)
then

  echo -e $Y"[*] Installing iodine DNS tunnel..."$END
  apt-get install iodine -y
  check "Installing iodine"

  echo -e $Y"[*] Configuring iodine DNS tunnel (/etc/default/iodine)..."$END
  read -p "What subdomain will the DNS tunnel be using? (e.g. tunnel.mydomain.com) " tunnel_domain
  sed -i -- 's/START_IODINED=/START_IODINED="true" # /g' /etc/default/iodine
  sed -i -- 's/IODINED_ARGS=/IODINED_ARGS="10.9.8.1 $tunnel_domain" # /g' /etc/default/iodine
  sed -i -- 's/IODINED_PASSWORD=/IODINED_PASSWORD="$tunnel_password" # /g' /etc/default/iodine
  check "Configuring iodine"

  echo -e $Y"[*] Enabling iodine DNS tunnel to start at boot..."$END
  systemctl enable iodined
  check "Enabling iodine to start at boot"

fi

#
# ======= Configure ptunnel =======
#

if $(shouldInstall "ptunnel" $@)
then

  echo -e $Y"[*] Installing ptunnel ICMP tunnel..."$END
  apt-get install ptunnel -y
  check "Installing ptunnel"

  echo -e $Y"[*] Configuring ptunnel ICMP tunnel (/etc/default/ptunnel)..."$END
  echo '# Default settings for ptunnel.  This file is sourced from /etc/init.d/ptunnel' > /etc/default/ptunnel
  echo 'PTUNNEL_PASSWORD="'$tunnel_password'"' >> /etc/default/ptunnel
  chmod 600 /etc/default/ptunnel
  check "Configuring ptunnel"

  echo -e $Y"[*] Configuring ptunnel ICMP tunnel to start at boot..."$END
  echo '#!/bin/sh' > /etc/init.d/ptunnel
  echo '### BEGIN INIT INFO' >> /etc/init.d/ptunnel
  echo '# Provides: 		ptunnel' >> /etc/init.d/ptunnel
  echo '# Required-Start: 	$remote_fs $network $syslog $named' >> /etc/init.d/ptunnel
  echo '# Required-Stop: 	$remote_fs $network $syslog' >> /etc/init.d/ptunnel
  echo '# Default-Start:	2 3 4 5' >> /etc/init.d/ptunnel
  echo '# Default-Stop:		0 1 6' >> /etc/init.d/ptunnel
  echo '# Short-Description: 	initscript for ptunnel' >> /etc/init.d/ptunnel
  echo '# Description: 		initscript for ptunnel' >> /etc/init.d/ptunnel
  echo '### END INIT INFO' >> /etc/init.d/ptunnel
  echo '# Adapted from iodined, written by gregor herrmann <gregor+debian@comodo.priv.at>' >> /etc/init.d/ptunnel
  echo 'PATH=/sbin:/usr/sbin:/bin:/usr/bin' >> /etc/init.d/ptunnel
  echo 'DESC="IP over ICMP tunneling server"' >> /etc/init.d/ptunnel
  echo 'NAME=ptunnel' >> /etc/init.d/ptunnel
  echo 'DAEMON=/usr/sbin/$NAME' >> /etc/init.d/ptunnel
  echo 'DEFAULT=$NAME' >> /etc/init.d/ptunnel
  echo 'CHROOTDIR=/var/run/$NAME' >> /etc/init.d/ptunnel
  echo 'DAEMON_ARGS="-setuid proxy -setgid proxy -chroot $CHROOTDIR"' >> /etc/init.d/ptunnel
  echo 'PIDFILE=/var/run/$NAME.pid' >> /etc/init.d/ptunnel
  echo 'SCRIPTNAME=/etc/init.d/$NAME' >> /etc/init.d/ptunnel
  echo '[ -x "$DAEMON" ] || exit 0' >> /etc/init.d/ptunnel
  echo '. /lib/init/vars.sh' >> /etc/init.d/ptunnel
  echo '. /lib/lsb/init-functions' >> /etc/init.d/ptunnel
  echo '. /etc/default/$DEFAULT' >> /etc/init.d/ptunnel
  echo 'check_chrootdir() {' >> /etc/init.d/ptunnel
  echo 'if [ -d "$CHROOTDIR" ] || mkdir -p "$CHROOTDIR" ; then' >> /etc/init.d/ptunnel
  echo 'return 0' >> /etc/init.d/ptunnel
  echo 'else' >> /etc/init.d/ptunnel
  echo '[ "$VERBOSE" != no ] && log_failure_msg "$CHROOTDIR does not exist and cannot be created."' >> /etc/init.d/ptunnel
  echo 'exit 0' >> /etc/init.d/ptunnel
  echo 'fi' >> /etc/init.d/ptunnel
  echo '}' >> /etc/init.d/ptunnel
  echo 'do_start() {' >> /etc/init.d/ptunnel
  echo 'check_chrootdir' >> /etc/init.d/ptunnel
  echo 'start-stop-daemon --start --quiet --exec $DAEMON --test > /dev/null 		|| return 1' >> /etc/init.d/ptunnel
  echo 'start-stop-daemon --start --quiet --exec $DAEMON -- $DAEMON_ARGS -x "$PTUNNEL_PASSWORD" 		|| return 2' >> /etc/init.d/ptunnel
  echo '}' >> /etc/init.d/ptunnel
  echo 'do_stop() {' >> /etc/init.d/ptunnel
  echo 'start-stop-daemon --stop --quiet --retry=TERM/5/KILL/5 --exec $DAEMON' >> /etc/init.d/ptunnel
  echo 'RETVAL="$?"' >> /etc/init.d/ptunnel
  echo '[ "$RETVAL" = 2 ] && return 2' >> /etc/init.d/ptunnel
  echo 'start-stop-daemon --stop --quiet --oknodo --retry=0/5/KILL/5 --exec $DAEMON' >> /etc/init.d/ptunnel
  echo '[ "$?" = 2 ] && return 2' >> /etc/init.d/ptunnel
  echo 'rm -f $PIDFILE' >> /etc/init.d/ptunnel
  echo 'return "$RETVAL"' >> /etc/init.d/ptunnel
  echo '}' >> /etc/init.d/ptunnel
  echo 'case "$1" in' >> /etc/init.d/ptunnel
  echo 'start)' >> /etc/init.d/ptunnel
  echo '[ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"' >> /etc/init.d/ptunnel
  echo 'do_start' >> /etc/init.d/ptunnel
  echo 'case "$?" in' >> /etc/init.d/ptunnel
  echo '0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;' >> /etc/init.d/ptunnel
  echo '2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;' >> /etc/init.d/ptunnel
  echo 'esac' >> /etc/init.d/ptunnel
  echo ';;' >> /etc/init.d/ptunnel
  echo 'stop)' >> /etc/init.d/ptunnel
  echo '[ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"' >> /etc/init.d/ptunnel
  echo 'do_stop' >> /etc/init.d/ptunnel
  echo 'case "$?" in' >> /etc/init.d/ptunnel
  echo '0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;' >> /etc/init.d/ptunnel
  echo '2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;' >> /etc/init.d/ptunnel
  echo 'esac' >> /etc/init.d/ptunnel
  echo ';;' >> /etc/init.d/ptunnel
  echo 'status)' >> /etc/init.d/ptunnel
  echo 'status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?' >> /etc/init.d/ptunnel
  echo ';;' >> /etc/init.d/ptunnel
  echo 'restart|force-reload)' >> /etc/init.d/ptunnel
  echo 'log_daemon_msg "Restarting $DESC" "$NAME"' >> /etc/init.d/ptunnel
  echo 'do_stop' >> /etc/init.d/ptunnel
  echo 'case "$?" in' >> /etc/init.d/ptunnel
  echo '0|1)' >> /etc/init.d/ptunnel
  echo 'do_start' >> /etc/init.d/ptunnel
  echo 'case "$?" in' >> /etc/init.d/ptunnel
  echo '0) log_end_msg 0 ;;' >> /etc/init.d/ptunnel
  echo '1) log_end_msg 1 ;;' >> /etc/init.d/ptunnel
  echo '*) log_end_msg 1 ;;' >> /etc/init.d/ptunnel
  echo 'esac' >> /etc/init.d/ptunnel
  echo ';;' >> /etc/init.d/ptunnel
  echo '*)' >> /etc/init.d/ptunnel
  echo 'log_end_msg 1' >> /etc/init.d/ptunnel
  echo ';;' >> /etc/init.d/ptunnel
  echo 'esac' >> /etc/init.d/ptunnel
  echo ';;' >> /etc/init.d/ptunnel
  echo '*)' >> /etc/init.d/ptunnel
  echo 'echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2' >> /etc/init.d/ptunnel
  echo 'exit 3' >> /etc/init.d/ptunnel
  echo ';;' >> /etc/init.d/ptunnel
  echo 'esac' >> /etc/init.d/ptunnel
  echo ':' >> /etc/init.d/ptunnel
  chmod 755 /etc/init.d/ptunnel
  update-rc.d ptunnel defaults
  check "Configuring ptunnel to start at boot"

  echo -e $Y"[*] Enabling ptunnel ICMP server to start at boot..."$END
  systemctl enable ptunnel
  check "Enabling ptunnel to start at boot"

fi

#
# ======= Configure stunnel =======
#

if $(shouldInstall "stunnel" $@)
then

  echo -e $Y"[*] Installing stunnel..."$END
  apt-get install -y stunnel4
  check "Installing stunnel"

  echo -e $Y"[*] Configuring stunnel..."$END

  echo 'cert=/etc/stunnel/stunnel.pem' > /etc/stunnel/stunnel.conf
  echo 'setuid=nobody' >> /etc/stunnel/stunnel.conf
  echo '[https]' >> /etc/stunnel/stunnel.conf
  echo 'accept=443' >> /etc/stunnel/stunnel.conf
  echo 'connect=127.0.0.1:22' >> /etc/stunnel/stunnel.conf
  check "Configuring stunnel"

  echo -e $Y"[*] Generating stunnel certificate..."$END
  openssl genrsa -out /tmp/key.pem 2048
  openssl req -new -x509 -key /tmp/key.pem -out /tmp/cert.pem -days 1095
  cat /tmp/key.pem /tmp/cert.pem >> /etc/stunnel/stunnel.pem && rm /tmp/key.pem /tmp/cert.pem
  check "Generating stunnel certificate"

  echo -e $Y"[*] Enabling stunnel to start at boot..."$END
  sed -i -- 's/ENABLED=/ENABLED=1 # /g' /etc/default/stunnel4
  systemctl enable stunnel4
  check "Enabling stunnel to start at boot"

fi

#
# ======= Completion  =======
#

echo -e $Y"[*] Make sure to configure the firewall to allow the following INPUTs:"$END
echo -e "\t- 22/tcp"
echo -e "\t- 53/udp"
echo -e "\t- 443/tcp"
echo -e "\t- ICMP"

echo -e $Y"[*] Issues encountered: ${#ISSUES[*]}"$END
if [ ${#ISSUES[*]} -ne 0 ]; then
  for i in ${ISSUES[*]}
    do echo -e $R"\t- $i"$END
  done
fi

echo -e $Y"[*] Reboot to start services"$END
