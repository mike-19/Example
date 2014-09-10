#!/bin/ksh
#
#  SCRIPT: oem_route.ksh
#  AUTHOR: Michael Varun
#  REV: 1.0.D  - Used for developement
#  DATE: 03/19/2014
#  PURPOSE: This Script is used to set static route
#           to OEM 12c on oracle database servers used in EBS
#           BU
#	    Applies to both VM and Baremetals ,
#
# set -x # Uncomment to debug this script
# set -n # Uncomment to verify syntax without any execution.
#        # REMEMBER: Put the comment back or the script will
#        # NOT EXECUTE!
#
####################################################
############## DEFINE FUNCTIONS HERE ###############
####################################################
#
#
#########################################################################################
#Function to determine hostname , as because not all hosts always resolv to ".data"
#as well return the correct "domain" from the hostname command
#########################################################################################
func_host()
{
HOST=`hostname -s`
DOMAIN=`cat /etc/resolv.conf |grep -i search|sed 's/search//g'|tr -s ' '`
HOSTNAME=`echo $HOST.data.$DOMAIN`
DAT_HOSTNAME=`echo "${HOSTNAME// /}"`
GW=`route -n | grep '^0\.0\.\0\.0[ \t]\+[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*[ \t]\+0\.0\.0\.0[ \t]\+[^ \t]*G[^ \t]*[ \t]' | awk '{print $2}'`
host $DAT_HOSTNAME >/dev/null 2>&1
if [ $? -eq 0 ]
        then
        DATA_HOSTNAME="$DAT_HOSTNAME"
        else
        DATA_HOSTNAME=`echo $HOST.$DOMAIN`
fi
IP_ADDR=`host $DATA_HOSTNAME|awk '{print $NF}'`
}
#########################################################################################
#Function to determine the correct 12c OEM url
#########################################################################################
func_oem()
{
OEM=""
OEM_IP=""
PORT="1159"
THIS_HOST=`hostname`
if echo $THIS_HOST |grep -i prd
	then
	OEM="ebsoem.intuit.net"
	else
		if echo $THIS_HOST |grep -i prf
		 then
		 OEM="ebsoemprf.intuit.net"
		 else
		 OEM="ebsoemsys.bosptc.intuit.net"
		fi
fi
OEM_IP=`host $OEM |grep -i address |awk '{print $NF}'`
}
########################################################################################
#sometimes due to CIS scan they simply remove the nc ,this is to validate if the
#acl is in place between the host and OEM
########################################################################################
func_nc()
{
rpm -qa |grep -w nc  >/dev/null 2>&1
if [ $? -eq 0 ]
	then
	 echo "nc installed " >/dev/null 2>&1
	else
	 yum -y install nc.x86_64 >/dev/null 2>&1
		if [ $? -eq 0 ]
		  then
		   echo "nc successfully installed "
		  else
		   echo "nc failed installation "
		   exit
		fi
fi
}
#
#
#########################################################################################
#Check if the ACL' is in place between the OEM and the HOST
########################################################################################
func_acl()
{
nc -s $IP_ADDR -z -w 5 $OEM_IP $PORT >/dev/null 2>&1
if [ $? -eq 0 ]
	then
	 echo "ACL is in place"
	else
	 echo "ACL is not in place check manaully"
	 CODE=1
fi
}
#
#
########################################################################################
#Determine the interface to which network route needs to be bound,some servers are VM
#some server are bare metals ,so they use different drivers
########################################################################################
func_nic()
{
HWTYPE=""
lsmod |grep -i bond >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
	HWTYPE="BM" && DRIVER="bond"
	else
	HWTYPE="VM" && DRIVER="eth"
	fi
for DEV in `cat /proc/net/dev|grep -i $DRIVER|awk -F':' '{print $1}'|tr -s ' '`
do
ifconfig $DEV |grep -i $IP_ADDR >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
	NIC="$DEV"
	fi
done
}
#
#######################################################################################
#Set the route to OEM for URL to resolv via DATA interface,and add configuration to an
#existsing route configuration to the identified device ,if not create one
#######################################################################################
func_route()
{
route add -host $OEM_IP gw $GW dev $NIC >/dev/null 2>&1
if [ $? -eq 0 ]
	then
	cd /tmp;
	wget --no-check-certificate https://$OEM:$PORT/em >/dev/null 2>&1
		if [ $? -eq 0 ]
		then
		echo "URL resolv's to DATA interface"
			if [ -s /etc/sysconfig/network-scripts/route-$NIC ]
			then
			COUNT=`grep ADDRESS /etc/sysconfig/network-scripts/route-$NIC|wc -l`
				if [ $COUNT -gt 0 ]
					then
					N=`grep -i ADDRESS route-eth0|tail -n 1|cut -c8-|awk -F'=' '{print $1}'|wc -l`
					N=`expr $N + 1`
					cp /etc/sysconfig/network-scripts/route-$NIC /etc/sysconfig/network-scripts/route-$NIC.bak
					echo "#" >>/etc/sysconfig/network-scripts/route-$NIC
					echo "#OEM Route" >>/etc/sysconfig/network-scripts/route-$NIC
					echo "GATEWAY$N=$GW" >>/etc/sysconfig/network-scripts/route-$NIC
					echo "NETMASK$N=255.255.255.255">>/etc/sysconfig/network-scripts/route-$NIC
					echo "ADDRESS$N=$OEM_IP">>/etc/sysconfig/network-scripts/route-$NIC
					echo "#" >>/etc/sysconfig/network-scripts/route-$NIC
					else
					echo "#OEM Route" >>/etc/sysconfig/network-scripts/route-$NIC
					echo "$OEM_IP via $GW dev $NIC" >>/etc/sysconfig/network-scripts/route-$NIC
				fi
			else
				touch /etc/sysconfig/network-scripts/route-$NIC
				echo "#OEM Route" >>/etc/sysconfig/network-scripts/route-$NIC
				echo "$OEM_IP via $GW dev $NIC">>/etc/sysconfig/network-scripts/route-$NIC
			fi
		else
			if [ $CODE -eq 1 ]
			then
			echo "URL doesnt work due to ACL not in place"
			fi
		fi
	  else
	  	 echo "Could not set route,manaually check"
	  	 exit
	fi
}
#
#############################################################################################
#Check if route already exists ,if so exit from the script and manaully troubleshoot
#############################################################################################
func_route_check()
{
netstat -rnv |grep -i $OEM_IP >>/dev/null
if [ $? -eq 0 ]
	then
	 grep $OEM_IP /etc/sysconfig/network-scripts/route-$NIC >/dev/null 2>&1
		if [ $? -eq 0 ]
			then
			echo "Route exists,already"
			else
			echo "Route exists but not permanently set via configuration"

		fi
	 exit
fi
}

#
#Main
func_host
func_oem
func_nc
func_nic
func_route_check
func_route
func_acl
