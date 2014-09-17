#!/bin/bash
#
#
DATE=$(date "+%Y%m%d")
MULTIPATH="/sbin/multipath"
SANLUN="/usr/sbin/sanlun"
SCSI_ID="/sbin/scsi_id"
DMSETUP="/sbin/dmsetup"
MPATH_CONFIG="/etc/multipath.conf"
#
#
FRIEND=`grep -i friendly /etc/multipath.conf |awk '{print $NF}'`
#
#
rpm -qf /etc/redhat-release |grep -i redhat
if [ $? -eq 0 ]
then
	OS="RHEL"
else
	OS="OEL"
fi
#
cat /etc/redhat-release |grep -ic "release 5"
if [ $? -eq 0 ]
	then
 		VERSION="LINUX5"
        else
cat /etc/redhat-release |grep -ic "release 6"
if [ $? -eq 0 ]
        then
	        VERSION="LINUX6"
fi
fi
#
if [ ! -e ${SANLUN} ]
then
	echo "No 'netapp host utilities'" >/dev/stderr
	exit
fi
#
#
if [ -h /var/lib/multipath/bindings ]
then
	cp /etc/multipath/bindings /etc/multipath/bindings.$DATE
else
	mkdir -p /var/lib/multipath
	ln -s /etc/multipath/bindings /var/lib/multipath/bindings
	cp /etc/multipath/bindings /etc/multipath/bindings.$DATE
fi
#
sed -i.bak "/\#/d" $MPATH_CONFIG
HARD_MPATH=`grep -i mpath $MPATH_CONFIG |wc -l`
#
#
if [ $HARD_MPATH > 0 ]
then
  HARD_FLAG=Y
  echo "$MPATH_CONFIG has an MULTIPATHS alias on itself ,We dont want to achieve that"
  echo "Alias names needs to be removed out from the $MPATH_CONFIG"
  cat  $MPATH_CONFIG
  echo ""
  sed -i.bak '/^multipaths/,/^}$/ d' $MPATH_CONFIG
else
  HARD_FLAG=N
fi
#
#
#
func_check_disks
