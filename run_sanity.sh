#!/bin/sh
CSI_BASE_DIR="/opt/vhosts/csi"
RPM_CLUS_LIST="$CSI_BASE_DIR/rpm_cluster_members"
DEB_CLUS_LIST="$CSI_BASE_DIR/deb_cluster_members"
KALTURA_BASE="/opt/kaltura"
CSI_WEB_IF_HOST=216.200.17.80
DB="$CSI_BASE_DIR/db/csi.db"
ALERTS_ADDR="jess.portnoy@kaltura.com"
rm /tmp/reportme.`date +%d_%m_%Y`.sql
for i in `cat $RPM_CLUS_LIST`;do
	if echo $i|grep '#' -q ;then
		continue
	fi
	ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "yum clean all && yum update '*kaltura*' -y"
	if [ -z "$VERSION" ];then
		VERSION=`ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "rpm -qa kaltura-base --queryformat %{version}" `
	fi
	if [ -z "$DB_UPDATE" ];then

		ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$KALTURA_BASE/bin/kaltura-db-update.sh"
		DB_UPDATE=1

	fi
	if ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no rpm -q kaltura-sphinx;then
		ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $KALTURA_BASE/bin/kaltura-sphinx-config.sh /root/kalt.ans
	fi
	ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$KALTURA_BASE/bin/kaltura-base-config.sh /root/kalt.ans && $KALTURA_BASE/bin/kaltura-batch-config.sh"
	ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $KALTURA_BASE/bin/kaltura-sanity.sh 
	RC=$?
	if [ $RC -ne 0 ];then 
		MSG="Sanity on machine $i aborted."
		if [ $RC -eq 11 ];then
			MSG="${MSG} Machine out of space. Do something"
		fi
		echo $MSG| mail -s "Sanity for machine $i aborted!" $ALERTS_ADDR
	fi
	scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i:"/tmp/$i-reportme.`date +%d_%m_%Y`.sql" /tmp/
	cat "/tmp/$i-reportme.`date +%d_%m_%Y`.sql" >> /tmp/reportme.`date +%d_%m_%Y`.sql
done

for i in `cat $DEB_CLUS_LIST`;do
	if echo $i|grep '#' -q ;then
		continue
	fi
	ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "aptitude update && /root/kalt.ans && aptitude -y dist-upgrade \"~Nkaltura\""
	if [ -z "$VERSION" ];then
		VERSION=`ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "dpkg-query -W -f'${Version}' kaltura-base|awk -F "-" '{print $1}'" `
	fi
	if ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no dpkg -l kaltura-batch;then
		ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "/root/kalt.ans && export DEBIAN_FRONTEND=noninteractive; dpkg-reconfigure kaltura-base && dpkg-reconfigure kaltura-batch" 
	fi
	if ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no dpkg -l kaltura-front;then
		ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "/root/kalt.ans && dpkg-reconfigure kaltura-base && dpkg-reconfigure kaltura-front" 
	fi
	ssh root@$i -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $KALTURA_BASE/bin/kaltura-sanity.sh 
	RC=$?
	if [ $RC -ne 0 ];then 
		MSG="Sanity on machine $i aborted."
		if [ $RC -eq 11 ];then
			MSG="${MSG} Machine out of space. Do something"
		fi
		echo $MSG| mail -s "Sanity for machine $i aborted!" $ALERTS_ADDR
	fi
	scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i:"/tmp/$i-reportme.`date +%d_%m_%Y`.sql" /tmp/
	cat "/tmp/$i-reportme.`date +%d_%m_%Y`.sql" >> /tmp/reportme.`date +%d_%m_%Y`.sql
done
#ssh root@ce-ubuntu0.dev.kaltura.com "/root/kalt.ans && /root/install_kaltura_all_in_1.sh && /opt/kaltura/bin/kaltura-sanity.sh"


cp $DB $DB.older
echo "delete from csi_log where kaltura_version='$VERSION';"|sqlite3 $DB
echo "delete from success_rates where kaltura_version='$VERSION';"|sqlite3 $DB
sqlite3 $DB < /tmp/reportme.`date +%d_%m_%Y`.sql
SUCCESS=0
FAILED=0
SUCCESS=`echo "select count(rc) from csi_log where rc=0 and kaltura_version='$VERSION';"|sqlite3 $DB`
FAILED=`echo "select count(rc) from csi_log where rc!=0 and kaltura_version='$VERSION';"|sqlite3 $DB`
echo "insert into success_rates values(NULL,$FAILED,$SUCCESS,'$VERSION');"|sqlite3 $DB
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $CSI_BASE_DIR/db/csi.db root@$CSI_WEB_IF_HOST:/opt/vhosts/reports/ci/db 
ssh root@ce-front0.dev.kaltura.com -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /usr/local/bin/clientlibs_test.sh
