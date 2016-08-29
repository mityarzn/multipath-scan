#!/bin/bash

scan_host ()
{
    host=$1
    echo - - - > /sys/class/scsi_host/$host/scan 
}

scan_all_hosts ()
{
    # Run scans in parallel
    for i in `ls /sys/class/scsi_host`
    do
	scan_host $i &
    done
    # wait scans to end
    wait
}

# Test if SCSI device is still responding to commands
testonline ()
{
    SGDEV=$1
    RC=0
    if test ! -x /usr/bin/sg_turs; then echo "sg3-utils not installed"; exit 1; fi
    if test -z "$SGDEV"; then return 0; fi
    sg_turs /dev/$SGDEV >/dev/null 2>&1
    RC=$?
    # Handle in progress of becoming ready and unit attention -- wait at max 11s
    declare -i ctr=0
    while test $RC = 2 -o $RC = 6 && test $ctr -le 8; do
	if test $RC = 2 
	then 
	    let $LN+=1
	    sleep 1
	else 
	    sleep 0.02
	fi
	let ctr+=1
	sg_turs /dev/$SGDEV >/dev/null 2>&1
	RC=$?
    done
    return $RC
}

try_delete_lun ()
{
    DEV=$1
    testonline $DEV
    RC=$?
    if [ $RC -ne 0 ]
    then
        echo 1 > /sys/block/$DEV/device/delete
    fi
}

delete_offline_luns ()
{
    for dev in  /dev/sd*[a-z]
    do
	dev=`echo $dev | sed 's/\/dev\///'`;
	try_delete_lun $dev &
    done
    wait
}

rescan_mpdev ()
{
    WWN=$1
    DMDEV=`readlink /dev/disk/by-id/dm-uuid-mpath-0x$WWN | grep -P -o 'dm-\d+'`
    [ -z "$DMDEV" ] && exit 0

    for dev in `ls /sys/block/$DMDEV/slaves`
    do
	echo 1 > /sys/block/$dev/device/rescan &
    done
    wait
}

delete_mpdev ()
{
    WWN=$1
    DMDEV=`readlink /dev/disk/by-id/dm-uuid-mpath-0x$WWN | grep -P -o 'dm-\d+'`
    [ -z "$DMDEV" ] && exit 0
    devs=`ls /sys/block/$DMDEV/slaves`

    multipath -f 0x$WWN

    for dev in $devs
    do
	echo 1 > /sys/block/$dev/device/delete &
    done
    wait
}

case "$1" in
    --scan-new)
	scan_all_hosts
	;;
     --remove-offline)
	delete_offline_luns
	;;
     --rescan-all)
	delete_offline_luns
	scan_all_hosts
	;;
    --rescan-wwid)
	if [ -z "$2" ]
	then
	    echo "This command needs 2nd argument: device's WWID"
	    exit 2
	fi
	rescan_mpdev $2
	;;
    --delete-wwid)
	if [ -z "$2" ]
	then
	    echo "This command needs 2nd argument: device's WWID"
	    exit 2
	fi
	delete_mpdev $2
	;;
    *)
	echo "Need one of commands:"
	echo "	--scan-new		Scans all SCSHI hosts for new|changed devices."
	echo "	--remove-offline	Removes stale offline devices."
	echo "	--resca-nall		Combo of two above."
	echo "	--rescan-wwid <WWID>	Rescan slaves of single multipath device WWID"
	echo "				for changes."
	echo "	--delete-wwid <WWID>	Remove sinddle multipath device WWID and its slaves"
	;;
esac

