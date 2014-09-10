#!/bin/bash

LocalIPs=""
GreenIPs=""
Reset=$(tput sgr0)
Red=$(tput setaf 1)
Blue=$(tput setaf 4)
IPcalc="/bin/ipcalc"
SanLUN="/usr/sbin/sanlun"
iSCSIadm="/sbin/iscsiadm"
IFconfig="/sbin/ifconfig"

## Install netapp_linux_host_utilities if its not already installed
if [ ! -e ${SanLUN} ]
then
	echo "Need to install package 'netapp_linux_host_utilities'" > /dev/stderr
	#yum -y install netapp_linux_host_utilities
fi

if [ ! -e ${IPcalc} ]
then
	echo "Need to install package 'initscripts'" > /dev/stderr
	#yum -y install initscripts
fi

## Get the storage IP on the host
StorageIP=$(${IFconfig} \
	| awk -F'[ :]' '/inet addr/&&!/127.0.0.1/ {print $13}' \
	| xargs -n1 host -T \
	| egrep "$(hostname -s)(s|.nfs)" \
	| awk '{print $NF}' \
	| xargs -n1 dig +tcp +short)
echo -e "\n${Blue}Storage IP     : ${Reset}${StorageIP} ($(dig -x ${StorageIP} +short +tcp))" > /dev/stderr

## List duplicate LUNs
Duplicates=$(${SanLUN} lun show -v \
	| awk '/Serial number/ {print $NF}' \
	| sort \
	| uniq -c \
	| awk '($1>1) {print $2}' \
	| tr '\n' ' ')
echo -e "${Blue}Duplicate LUNs : ${Reset}${Duplicates}" > /dev/stderr

## List unique LUNs
Uniques=$(${SanLUN} lun show -v \
	| awk '/Serial number/ {print $NF}' \
	| sort \
	| uniq -c \
	| awk '($1==1) {print $2}' \
	| tr '\n' ' ')
echo -e "${Blue}Unique LUNs    : ${Reset}${Uniques}" > /dev/stderr

## Check which filer IPs are within the same subnet as the Storage IP
IPs=$(${SanLUN} lun show -v | awk '/Controller iSCSI IP address/ {print $5}' | sort -u)
StorageIPNetmask=$(${IFconfig} | grep "${StorageIP}" | awk -F':' '{print $NF}')
StorageIPNetwork=$(${IPcalc} -n ${StorageIP} ${StorageIPNetmask} | cut -d'=' -f2)
for IP in $(echo ${IPs})
do
	Network=$(${IPcalc} -n ${IP} ${StorageIPNetmask} | cut -d'=' -f2)
	if [ "${Network}" = "${StorageIPNetwork}" ]
	then
		LocalIPs="${LocalIPs}|${IP}"
	fi
done

GreenIPs=$(echo ${LocalIPs} | sed 's:\(^|\||$\)::g')
echo -e "${Blue}Valid IPs      : ${Reset}$(echo ${GreenIPs} | sed 's:|: :g')" > /dev/stderr
echo -e "\n${Blue}Need to execute the following login commands:${Reset}" > /dev/stderr
${iSCSIadm} -m node | egrep "${GreenIPs}" | awk -F'[, ]' '{print "	iscsiadm --mode node --targetname",$3,"--portal",$1,"--login"}'
echo -e "\n${Blue}Need to execute the following logout commands:${Reset}" > /dev/stderr
${iSCSIadm} -m node | egrep -v "${GreenIPs}" | awk -F'[, ]' '{print "	iscsiadm --mode node --targetname",$3,"--portal",$1,"--logout"}'
echo -e "\n${Blue}Need to execute the following delete commands:${Reset}" > /dev/stderr
${iSCSIadm} -m node | egrep -v "${GreenIPs}" | awk -F'[,: ]' '{print "	iscsiadm -m node -p",$1,"--op=delete"}'
echo -e "\n${Blue}If 'multipath' is enabled, run the following command:${Reset}" > /dev/stderr
echo -e "	multipath" > /dev/stderr

echo "${Red}
Warnings : This is a test script.
           Check mount entries in /etc/fstab.
           Verify the commands before executing.
${Reset}" > /dev/stderr
