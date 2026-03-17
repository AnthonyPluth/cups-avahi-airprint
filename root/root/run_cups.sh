#!/bin/bash
set -e
set -x

# Is CUPSADMIN set? If not, set to default
if [ -z "$CUPSADMIN" ]; then
    CUPSADMIN="cupsadmin"
fi

# Is CUPSPASSWORD set? If not, set to $CUPSADMIN
if [ -z "$CUPSPASSWORD" ]; then
    CUPSPASSWORD=$CUPSADMIN
fi

if [ $(grep -ci $CUPSADMIN /etc/shadow) -eq 0 ]; then
    adduser --system --ingroup lpadmin --no-create-home $CUPSADMIN
fi
echo "$CUPSADMIN:$CUPSPASSWORD" | chpasswd

mkdir -p /config/ppd
mkdir -p /services
rm -rf /etc/avahi/services/*
rm -rf /etc/cups/ppd
ln -s /config/ppd /etc/cups
if [ `ls -l /services/*.service 2>/dev/null | wc -l` -gt 0 ]; then
    cp -f /services/*.service /etc/avahi/services/
fi
if [ `ls -l /config/printers.conf 2>/dev/null | wc -l` -eq 0 ]; then
    touch /config/printers.conf
fi
cp /config/printers.conf /etc/cups/printers.conf

if [ `ls -l /config/cupsd.conf 2>/dev/null | wc -l` -ne 0 ]; then
    cp /config/cupsd.conf /etc/cups/cupsd.conf
else
    cp /etc/cups/cupsd.conf /config/cupsd.conf
fi

# Function to handle cleanup on exit
cleanup() {
    echo "Cleaning up..."
    if [ -f /var/run/avahi-daemon/pid ]; then
        PID=$(cat /var/run/avahi-daemon/pid)
        if kill -0 $PID 2>/dev/null; then
            kill $PID
            rm -f /var/run/avahi-daemon/pid
        fi
    fi
    pkill -f printer-update.sh || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Ensure any stale PID files are removed before starting
if [ -f /var/run/avahi-daemon/pid ]; then
    rm -f /var/run/avahi-daemon/pid
fi
if [ -f /var/run/avahi-daemon.pid ]; then
    rm -f /var/run/avahi-daemon.pid
fi

# Start avahi-daemon service in the background
/root/root/avahi-service.sh &
AVAHI_SERVICE_PID=$!

sleep 2

# Start CUPS and printer update
/root/root/printer-update.sh &
exec /usr/sbin/cupsd -f
