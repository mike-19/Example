#!/bin/bash
#
#
#
#  SCRIPT: flush_mapth
#  AUTHOR: Michael Varun SDT PI-PE
#  REV: 1.0.D  - Used for developement
#  DATE: 10/03/2014
#  PURPOSE: This script is used to remove the MPATH devices
#	    The script iterates through the list of devices
#	    inputted by the user and then it checks and does
#	    a validation against the ASM labels
#
# set -x # Uncomment to debug this script
# set -n # Uncomment to verify syntax without any execution.
#        # REMEMBER: Put the comment back or the script will
#        # NOT EXECUTE!
#
DATE=$(date "+%Y%m%d")
MULTIPATH="/sbin/multipath"
SANLUN="/usr/sbin/sanlun"
SCSI_ID="/sbin/scsi_id"
DMSETUP="/sbin/dmsetup"
BLOCKDEV="/sbin/blockdev"
KPARTX="/sbin/kpartx"
BINDINGS="/etc/multipath/bindings"
TMP="`mktemp /tmp/mpathXXXXXXX`"
TMP1="`mktemp /tmp/MPATH_XXXXXX`"
TMP2="`mktemp /tmp/DEV_XXXXXXX`"
#
#
#
##############################
#check for sanlun utility    #
##############################
#
#
#
#
if [ ! -e ${SANLUN} ]
then
	echo "No 'netapp host utilities'" >/dev/stderr
	exit
fi
#
#
#
#
##############################
#Populate user inputed mpath #
#devices		     #
##############################
#
#
#
#
if [ $# -gt 0 ]
then
	echo "Total disks to remove is $#"
	echo $* >/tmp/remove
else
	echo "No mpath device provided"
	echo "Usage flush_mpath <mpath1> <mpath2> ......."
	exit
fi
#
#
#
#
##################################
#Create symbolic link to BINDINGS#
#file,fixes confusion on userdefi#
#ned config and default		 #
##################################
#
#
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
#
#
##################################
#Iterte and remove devices       #
##################################
#
#
#
for MPATH in `cat /tmp/remove`
do
	${MULTIPATH} -ll ${MPATH} |grep -i running > /dev/null 2>&1
		if [ $? -eq 1 ]
		then
			grep -w ${MPATH} ${BINDINGS} > /dev/null 2>&1
			if [ $? -eq 1 ]
			then
				echo "There is no device by ${MPATH}"
			else
				echo "${MPATH} does not exists but config entry in ${BINDINGS} exists"
			fi
		else
			echo "${MPATH} is ok to remove" |tee -a ${TMP1}
			echo "Removing only those marked as OK"
			echo "Please press <RETURN> to proceed"
			read
		fi
done
#
#
#
#
#
if [ -s ${TMP1} ]
then
for MPATH in `awk '{print $1}' ${TMP1}`
do
ls /dev/oracleasm/disks |xargs /etc/init.d/oracleasm querydisk -p -d |grep -iw ${MPATH}
	if [ $? -eq 1 ]
	then
	DEV_NODE=`${MULTIPATH} -ll ${MPATH} |grep -i running |sed 's:^.*\(sd.[^ ]*\).*$:\1:g'|head -n 1`
	DEV_NODE_ALL=`${MULTIPATH} -ll ${MPATH} |grep -i running |sed 's:^.*\(sd.[^ ]*\).*$:\1:g'>${TMP2}`
	WWID=`${SCSI_ID} -g -u -s /block/${DEV_NODE}`
	LUN=`${SANLUN} lun show all |grep -i ${DEV_NODE}|awk '{print $1,$2}'`
	BIND_MPATH=`grep -i $WWID /etc/multipath/bindings|awk '{print $1}'`
		if [ $BIND_MPATH == $MPATH ]
		then
		#	sed -i.bak "/^${MPATH}/d" ${BINDINGS}
			sed -i.bak "/\<$MPATH\>/d" ${BINDINGS}
			${BLOCKDEV} --flushbufs /dev/mapper/${MPATH} > /dev/null 2>&1
			${KPARTX} -d /dev/mapper/$MPATH
			if [ $? -eq 0 ]
				then
				${MULTIPATH} -f ${MPATH} > /dev/null 2>&1
				if [ $? -eq 0 ]
				then
					for DEVICE in `cat ${TMP2}`
        				 do
						echo "offline" >/sys/block/${DEVICE}/device/state
          					echo "1" >/sys/block/${DEVICE}/device/delete
          					echo $MPATH $LUN path Successfully removed
					 done
				else
					echo "$MPATH could not be flushed"
					echo "Can we wipe the device table enter: yes|YES|y or no|NO|n"
					read OPTION;
						case $OPTION in
							yes|YES|y)
							${DMSETUP} wipe_table ${MPATH}
							${MULTIPATH} -f ${MPATH}
								if [ $? -eq 0 ]
								then
						 	 	 for DEVICE in `cat ${TMP2}`
                                         			  do
                                                		  	echo "offline" >/sys/block/${DEVICE}/device/state
                                                                 	echo "1" >/sys/block/${DEVICE}/device/delete
                                                                  	echo $MPATH $LUN path Successfully removed
                                        			 done
								fi;;
							no|NO|n)
							echo "Unable to remove ${MPATH}"
							cp /etc/multipath/bindings.bak /etc/multipath/bindings;;

							*)
							echo "Invalid option"
							cp /etc/multipath/bindings.bak /etc/multipath/bindings
							exit;;
						esac
				fi
			else
			echo "Unable to delete partiton table on $MPATH,Not risking"
			fi
		else
		echo "${MPATH} ${LUN} ${BIND_MPATH} doesnt match in bindings file not modifying"
		fi
	else
	ASM_LABEL=`ls /dev/oracleasm/disks|xargs /etc/init.d/oracleasm querydisk -p |grep -w "$MPATH"p1|awk -F "\"" '{ print $2}'`
	echo "${MPATH}still does have ${ASM_LABEL}"
fi
done
else
echo "No Action being taken ,I am silent watcher now :-)"
fi
#
#
#
rm ${TMP}
rm ${TMP1}
rm ${TMP2}
cp /dev/null /tmp/remove