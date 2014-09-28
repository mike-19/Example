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
#
func_symlink_bind_file()
{
if [ -h /var/lib/multipath/bindings ]
then
	cp /etc/multipath/bindings /etc/multipath/bindings.$DATE
else
	mkdir -p /var/lib/multipath
	ln -s /etc/multipath/bindings /var/lib/multipath/bindings
	cp /etc/multipath/bindings /etc/multipath/bindings.$DATE
fi
}
#
func_total_disks()
{
SAN_DISKS=`sanlun lun show all |grep -i host1 |awk '{print $1,$2}' |sort -k 2,2n |uniq|wc -l`
MPATH_DISKS=`multipath -ll |grep -i mpath |wc -l`
BIND_DISKS=`grep -i mpath $BIND |wc -l `
if [$SAN_DISKS -eq $MPATH_DISKS -eq $BIND_DISKS ] 
  then
    echo "OK" 
  else
    print "em_result="DISKS Configs on MPATH ,BINDINGS are not matching to total allocated luns ,There is mismatch.\n"
fi
}
#
#
fucn_check_bind_file()
{
 multipath -ll |grep -i mpath|awk '{print $1 ,$2}'|sed -e 's/(//g' -e 's/)//g'|column -t |sort +1.7 -1.6 > $TMP
    grep -i mpath /etc/multipath/bindings|column -t |sort +1.6 -1.7 > $TMP1
    diff -a --suppress-common-lines -y $TMP $TMP1 >$TMP3 
      if [ -s $TMP3 ]
      then
      echo "MPATH names match with the bindings file entry"
      else

      cat $TMP3
      
