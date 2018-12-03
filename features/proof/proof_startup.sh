#! /bin/sh
#
# xrootd    Start/Stop the XROOTD daemon
#
# chkconfig: 345 99 0
# description: The xrootd daemon is used to as file server and starter of
#              the PROOF worker processes.
#
# processname: xrootd
# pidfile: /var/run/xrootd.pid
# config:

XROOTD=/opt/root/bin/xrootd
XRDLIBS=/opt/root/lib
XRDLOG=/var/log/xroot.log

# Source function library.
. /etc/init.d/functions

# Get config.
. /etc/sysconfig/network

# Get xrootd config
[ -f  /etc/sysconfig/xrootd ] && . /etc/sysconfig/xrootd

# Read user config
[ ! -z "$XRDUSERCONFIG" ] && [ -f "$XRDUSERCONFIG" ] && . $XRDUSERCONFIG

# Check that networking is up.
if [ ${NETWORKING} = "no" ]
then
    exit 0
fi

if [ ! -x $XROOTD ]
then
    echo "Xrootd daemon not found ($XROOTD)"
    exit 4
fi

RETVAL=0
prog="xrootd"

export DAEMON_COREFILE_LIMIT=unlimited

start() {
    echo -n $"Starting $prog: "
    # Options are specified in /etc/sysconfig/xrootd .
    # See $ROOTSYS/etc/daemons/xrootd.sysconfig for an example.
    # $XRDUSER *must* be the name of an existing non-privileged user.
    if [ -z "$XRDUSER" ]
    then
        echo "XRDUSER must be defined in site configuration. Aborting"
        RETVAL=5
        return $RETVAL
    fi
    # $XRDCF must be the name of the xrootd configuration file
    if [ -z "$XRDCF" ]
    then
        echo "XRDCF must be defined in site configuration. Aborting"
        RETVAL=5
        return $RETVAL
    fi
    export LD_LIBRARY_PATH=$XRDLIBS:$LD_LIBRARY_PATH
    # Set xrootd log file to be writable by XRDUSER
    touch $XRDLOG
    chown $XRDUSER $XRDLOG
    # limit on 1 GB resident memory, and 2 GB virtual memory
    #ulimit -m 1048576 -v 2097152 -n 65000
        daemon $XROOTD -b -l $XRDLOG -R $XRDUSER -c $XRDCF $XRDDEBUG
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && touch /var/lock/subsys/xrootd
        return $RETVAL
}

stop() {
    [ ! -f /var/lock/subsys/xrootd ] && return 0 || true
        echo -n $"Stopping $prog: "
        killproc xrootd
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/xrootd
    return $RETVAL
}

# See how we were called.
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status xrootd
        RETVAL=$?
        ;;
    restart|reload)
        stop
        start
        ;;
    condrestart)
        if [ -f /var/lock/subsys/xrootd ]; then
            stop
            start
        fi
        ;;
    *)
        echo  $"Usage: $0 {start|stop|status|restart|reload|condrestart}"
        exit 1
esac

exit $RETVAL
