#!/bin/bash --
#===============================================================================
#          FILE: main.sh
#         USAGE: ./main.sh-
#   DESCRIPTION:-
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jess Portnoy <jess.portnoy@kaltura.com>
#  ORGANIZATION: Kaltura, inc.
#       CREATED: 03/04/2014 12:15:55 PM IST
#      REVISION:  ---
#===============================================================================

#set -o nounset                              # Treat unset variables as an error
. ~/.bashrc
FUNCTIONS_LIB=/home/csi/platform-continuous-integration/csi-functions.rc

if [ -r $FUNCTIONS_LIB ];then
. $FUNCTIONS_LIB
else
	echo "where is $FUNCTIONS_LIB :("
fi
set -x
LOGIE=/tmp/csi_all1_`date +%d_%m_%Y_%h_%M`.log
install_kalt_allin1 $NIGHTLY_RELEASE_RPM_URL $KALTURA_NODE_IMG 1 > $LOGIE 2>&1; 
MAIL_TO="jess.portnoy@kaltura.com"
#MAIL_TO="jess.portnoy@kaltura.com,zohar.babin@kaltura.com"
EPOCH_CURR=`date +%s`
MIN_TIMESTAMP=`expr $EPOCH_CURR - 7200`
MAX_TIMESTAMP=`expr $EPOCH_CURR + 7200`
CSV_FILE=`create_csv $MIN_TIMESTAMP $MAX_TIMESTAMP`
echo "Sanity for Kaltura $BASE_VERSION. See attached log and CSV report." | mutt -s "Sanity for Kaltura $BASE_VERSION" $MAIL_TO -a $LOGIE -a $CSV_FILE


