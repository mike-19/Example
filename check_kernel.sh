#!/bin/bash
#
HOSTNAME=`hostname -s`
#
func_check_repo()
{
REPO_TMP=`mktemp /tmp/repos.XXXXXXX`
REPO_TMP1=`mktemp /tmp/repos1.XXXXXX`
yum repolist --verbose|grep -i repo-baseurl >$REPO_TMP
sed -e 's/Repo-baseurl//g' -e 's/^.://g' -e 's/,//g' $REPO_TMP |tr -s ' ' >$REPO_TMP1
for URL in `cat $REPO_TMP1`
do
wget --output-document=/tmp/repo.html $URL >/dev/null 2>&1
        if [ $? -eq 0 ]
        	then
        		echo $URL is working >/dev/null 2>&1
       			break
		else
			mailx -s "$HOSTNAME Repo URL's" michael_varun@intuit.com <<-EOF
			Please check the RPM repository URL's to validate if they are accesisble for patch updates
			EOF
			exit
        fi
done
}
#
#
#
#
#
func_get_kernel()
{
KERNEL=`mktemp /tmp/kern.XXXXXX`
#
#

rpm -qf /etc/redhat-release |grep -i redhat
        if [ $? -eq 0 ]
        	then
        	OS="RHEL"
        	else
        	OS="OEL"
        fi
KERNEL_RUNNING=`cat /proc/version|awk '{print $3}'|sed -e 's/xen//g' -e 's/uek//g'`
KERNEL_DEFAULT=`/sbin/grubby --default-kernel |sed -e 's/\/boot\/vmlinuz-//' -e 's/xen//g' -e 's/uek//g'`
	if [ $OS == RHEL ]
		then
		sed -n '/kernel-[0-9]/ s:^.*href="\(.[^"]*\)".*right">\([0-9][0-9]-[A-Z][a-z][a-z]-2[0-9][0-9][0-9]\).*$:\1 \2:gp' /tmp/repo.html | column -t|tail -n 2 |head -n 1 |awk '{print $1}' >$KERNEL
		KERNEL_DATE=`sed -n '/kernel-[0-9]/ s:^.*href="\(.[^"]*\)".*right">\([0-9][0-9]-[A-Z][a-z][a-z]-2[0-9][0-9][0-9]\).*$:\1 \2:gp' /tmp/repo.html | column -t|tail -n 2 |head -n 1 |awk '{print $2}'`
		else
		sed -n '/kernel-[0-9]/ s:^.*href="\(.[^"]*\)".*right">\([0-9][0-9]-[A-Z][a-z][a-z]-2[0-9][0-9][0-9]\).*$:\1 \2:gp' /tmp/repo.html | column -t|tail -n 1|awk '{print $1}' >$KERNEL
		KERNEL_DATE=`sed -n '/kernel-[0-9]/ s:^.*href="\(.[^"]*\)".*right">\([0-9][0-9]-[A-Z][a-z][a-z]-2[0-9][0-9][0-9]\).*$:\1 \2:gp' /tmp/repo.html | column -t|tail -n 1|awk '{print $2}'`
	fi
KERNEL_LATEST=`sed -e 's/kernel-//g' -e 's/.x86_64.rpm//g' $KERNEL`
}
#
#
#
func_check_version()
{
if [ $KERNEL_DEFAULT == $KERNEL_LATEST ]
then
	if [ $KERNEL_RUNNING == $KERNEL_DEFAULT ]
		then
			echo "Server is running on the latest available kernel $KERNEL_LATEST ,Release date $KERNEL_DATE, No action is required." >/tmp/mail
		else
			echo "server is running on $KERNEL_RUNNING , The latest $KERNEL_DEFAULT is already installed , Please schedule a reboot to activate the latest kernel" >/tmp/mail
	fi
else
	echo "Server is running on old kernel ,latest kernel is $KERNEL_LATEST ,Released on $KERNEL_DATE is available in repo $URL  ,Schedule a patch task with SDT  and reboot the server to activate the patched kernel " >/tmp/mail
fi
}
#
#
#
#
func_package_update()
{
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
echo =============================== >>/tmp/mail
echo RUNNING_KERNEL		:$KERNEL_RUNNING >>/tmp/mail
echo INSTALLED_KERNEL		:$KERNEL_DEFAULT >>/tmp/mail
echo LATEST_KERNEL		:$KERNEL_LATEST >>/tmp/mail
echo VERSION 			:$VERSION >>/tmp/mail
echo OS				:$OS >>/tmp/mail
echo ===============================>>/tmp/mail
#
#
yum check-update |egrep "x86_64|i386" >/tmp/package_updates
	if [ -s /tmp/package_updates ]
		then
			echo "Available packages which have updates" >>/tmp/mail
			echo ===============================>>/tmp/mail
			cat /tmp/package_updates >>/tmp/mail
	else
		echo "There is no any specific updates for packages installed" >>/tmp/mail
	fi
}
func_mail()
{
mailx -s "$HOSTNAME Patch Status" michael_varun@intuit.com </tmp/mail
}
#
func_remove()
{
rm -f /tmp/mail
rm -f /tmp/package_updates
rm -f $REPO_TMP
rm -f $KERNEL
rm -f $REPO_TMP1
}
#
#
func_check_repo
func_get_kernel
func_check_version
func_package_update
func_mail
func_remove
