#!/bin/bash
#
#
ls -l /etc/sysconfig/network-scripts/ifcfg-bond? > /dev/null 2>&1
 if [ $? -eq 0 ]
  then
  COUNT1=`ls -l /etc/sysconfig/network-scripts/ifcfg-bond?|wc -l`
  BOND_COUNT=`expr $COUNT1 - 1`
   for COUNT in `seq 0 $BOND_COUNT`
    do
     SLAVE=`cat /proc/net/bonding/bond$COUNT|grep -i interface |wc -l`
      if [ $SLAVE -lt 2 ]
       then
        echo "bond$COUNT is misconfigured has only one interface"
       else
        DEV1=`cat /proc/net/bonding/bond$COUNT|grep -i interface|sed 's/ //g'|head -n 1 |awk -F":" '{print $NF}'`
        DEV2=`cat /proc/net/bonding/bond$COUNT|grep -i interface|sed 's/ //g'|tail -n 1 |awk -F":" '{print $NF}'`
         if [ $DEV1 = $DEV2 ]
          then
           echo "bond$COUNT is messier,Needs Manually Check"
          else
           SWITCH1=`/usr/sbin/tcpdump -i $DEV1 -v -s 1500 -c 1 'ether[20:2] == 0x2000'|grep -i "System Name"|awk -F":" '{print $NF}'|sed 's/ //g'|tr -d "'"`
           SWITCH2=`/usr/sbin/tcpdump -i $DEV2 -v -s 1500 -c 1 'ether[20:2] == 0x2000'|grep -i "System Name"|awk -F":" '{print $NF}'|sed 's/ //g'|tr -d "'"`
            if [ $SWITCH1 = $SWITCH2 ]
             then
              echo "bond$COUNT $DEV1 $DEV2 are connected to same switch"
             else
              echo "bond$COUNT $DEV1 $DEV2 status OK ,Connected to different switch $SWITCH1 $SWITCH2 respectively"
            fi
          fi
        fi
      done
    else
    echo "There is no BONDING configuration for the host"
    exit
  fi
