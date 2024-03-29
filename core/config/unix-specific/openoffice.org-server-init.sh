#!/bin/sh
### BEGIN INIT INFO
# Provides:          openoffice.org-server
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Required-Start:    $local_fs $network_fs $network $syslog
# Required-Stop:     $local_fs $network_fs $network $syslog
# Short-Description: OpenOffice.org Server Daemon
# Description:       Start/stop OpenOffice.org in server mode
### END INIT INFO

scriptDirectory=$( dirname "$0" )
scriptDirectory=$( cd $scriptDirectory; pwd )

ooocommand="$scriptDirectory/openoffice.org-server.sh"
kill="/bin/kill"
pidfile="/tmp/openoffice.org-server.pid"
username="$2"
groupname="$3"
cat="/bin/cat"
startStopDaemon="/sbin/start-stop-daemon"
rpmDaemon="/usr/bin/daemon"
whoami=$( whoami )

export HOME=/tmp/

if [ -e "$startStopDaemon" ]
then
	if [ -n "$username" ]
	then
		username="-c $username "
	fi
	if [ -n "$groupname" ]
	then
		groupname="-g $groupname "
	fi
elif [ -e "$rpmDaemon" ]
then
	if [ -n "$username" ]
	then
		username="--user=$username"
		if [ -n "$groupname" ]
		then
			username="$username.$groupname"
		fi
	fi
fi

if [ -s "$ooocommand" ]
then
	sleep 0
else
	echo "Comand not found at $ooocommand"
	exit 1
fi
ooo_start()
{
	if [ -s "$pidfile" ]
	then
		pid=$( $cat "$pidfile" )
		echo "Already running? pid file exists at $pidfile that contains process #$pid"
	else
		rm -f "$pidfile"
		if [ -e "$startStopDaemon" ]
		then
			$startStopDaemon "$groupname" "$username" --pidfile $pidfile -m --start --exec "$ooocommand"
		elif [ -e "$rpmDaemon" ]
		then
			$rpmDaemon --pidfile=$pidfile $ooocommand
		else
			echo "Warning: Unable to find $startStopDaemon or $rpmDaemon so instead I'll daemonize by forking as the current user, $whoami."
			$ooocommand &
		fi
		sleep 2
		pgrep "soffice" > "$pidfile"

		if [ -s "$pidfile" ]
		then
			pid=$( $cat "$pidfile" )
			echo "Started OpenOffice.org with process(s) #$pid"
			sleep 0
		else
			echo "Unable to start OpenOffice.org (empty pid file at $pidfile)"
		fi
		return 0
	fi
}

ooo_stop()
{
	if [ -s "$pidfile" ]
	then
		pids=$( $cat "$pidfile" )
		if [ -e "$startStopDaemon" ]
		then
			$startStopDaemon "$groupname" "$username" --stop --quiet --pidfile "$pidfile"
		else
			$cat "$pidfile" |   
                        while read line
                        do
                                $kill "${line}" 2> /dev/null
				sleep 1
				$kill -s 9 "${line}" 2> /dev/null
                        done
		fi
		$cat "$pidfile" |   
                while read line
                do
			remainingProcess=$( ps "${line}" | grep ${line} )
			if [ -n "$remainingProcess" ]
			then
				echo "Unable to kill #$remainingProcess. You'll have to clean up manually."
				exit 1
			fi
		done
		rm -f "$pidfile"
		echo "Successfully stopped."
	else
		echo "Stopped. Warning: No pid file found at $pidfile so I'm assuming it was never running."
	fi
}

case "$1" in
	start)
		ooo_start
	;;
	stop)
		ooo_stop
	;;
	restart)
		ooo_stop
		sleep 1
		ooo_start
	;;
	*)
		echo "Usage: openoffice.org-server.init.sh {start|stop|restart}"
		exit 1
	;;
esac

