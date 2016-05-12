#!/bin/bash
########################################################################################################################
###  Script : rio_determine_dest_dir.sh
###  Description : This script determines the destination dir for rio based on specified raw dir path and nominal time of coordinator
###                                                                                                                    
###  Run Command(s) : move_to_quarantine.sh <REJECT_LIST_FILE> <QUARANTINE_DIR>
###
###  By: Priyank Gupta
###  Email : Priyank.Gupta@cognizant.com
###
###  Modification History:
###  Rev#     Date        Developer        Description
###  ----  ----------  ----------------    ---------------------------------------------------------
###  1.0   2015-01-07  Priyank Gupta       First Release
##########################################################################################################################

#Declarations
    PROG_NAME=`basename $0`
    ARG_CNT=$#
    REJECT_LIST_DIR=$1 # <HDFS path to Reject File List>
    QUARANTINE_DIR=$2 # <HDFS path to QUARANTINE_DIR>
    CONSOL_REJECTLIST_FILE="reject_list.txt"
    QUARANTINED_FILE_COUNT=0
#Sanity Checks    
    if [[ ( ${ARG_CNT} -ne 2 ) ]]; then
        echo "status=ERROR"
        echo "msg=Incorrect Usage. Usage: ${PROG_NAME} <Nominal Time> <Raw Dir>"
        exit 0
    fi
    
    hadoop fs -test -d "${REJECT_LIST_DIR}" || {
        echo "status=ERROR"
        echo "msg=Cannot find the specified HDFS Dir:: ${REJECT_LIST_DIR}"
        exit 0
    }
    
    hadoop fs -cat `hadoop fs -ls -R ${REJECT_LIST_DIR} | egrep "^-" |awk '{print $8}'` >> ${CONSOL_REJECTLIST_FILE} || {
                echo "status=ERROR"
                echo "msg=cannot create ${CONSOL_REJECTLIST_FILE} in local node"
                exit 0
            }
    
    if [[ -s ${CONSOL_REJECTLIST_FILE} ]]; then
        hadoop fs -mkdir -p "$QUARANTINE_DIR" || {
                echo "status=ERROR"
                echo "msg=cannot create the quarantine directory $QUARANTINE_DIR"
                exit 0
            }
        
        hadoop fs -copyFromLocal "${CONSOL_REJECTLIST_FILE}" "${QUARANTINE_DIR}" || {
                echo "status=ERROR"
                echo "msg=cannot copy Consolidated Reject List File:${CONSOL_REJECTLIST_FILE} to ${QUARANTINE_DIR}"
                exit 0
            }
    
        for file in `cat ${CONSOL_REJECTLIST_FILE} | awk -F ";" '{print $1}' | sort -u`; do
            hadoop fs -mv "$file" "$QUARANTINE_DIR" || {
                echo "status=ERROR"
                echo "msg=Error Code:CDL1002;Error Message:Cannot move file to quarantine. File::${file} Target Dir ${QUARANTINE_DIR}"
                exit 0
            }
            ((QUARANTINED_FILE_COUNT++))
        done
    
    fi
    
echo "quarantined_file_count=${QUARANTINED_FILE_COUNT}"
echo "status=OK"