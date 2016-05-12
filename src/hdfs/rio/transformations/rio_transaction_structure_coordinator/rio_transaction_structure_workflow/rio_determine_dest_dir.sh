#!/bin/bash
########################################################################################################################
###  Script : rio_determine_dest_dir.sh												
###  Description : This script determines the destination dir for rio based on specified raw dir path and nominal time of coordinator
###                                                                                                                    
###  Run Command(s) : rio_determine_dest_dir.sh <Nominal Time> <Raw Dir>
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
    NOMINAL_TIME=$1 # <Nominal Time>
    RAW_DIR=$2 # <Raw Dir>
    
    TS_PATTERN=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z #Eg - 2015-12-08T05:00Z
    STREAM_GPRS=rio_prag_incoming_gprs
    STREAM_GSM=rio_prag_incoming_gsm
    
#Sanity Checks    
    if [[ ( ${ARG_CNT} -ne 2 ) ]]; then
        echo "status=ERROR"
        echo "msg=Incorrect Usage. Usage: ${PROG_NAME} <Nominal Time> <Raw Dir>"
        exit 0
    fi
    

    if [[ ! $NOMINAL_TIME =~ $TS_PATTERN ]]; then
                echo "status=ERROR"
                echo "msg=Incorrect Timestamp Format. Expected Format::YYYY-MM-DDTHH:MMZ";
                exit 0;
    fi

nominalYear=${NOMINAL_TIME:0:4}
nominalMonth=${NOMINAL_TIME:5:2}
nominalDay=${NOMINAL_TIME:8:2}
nominalHour=${NOMINAL_TIME:11:2}
nominalMinute=${NOMINAL_TIME:14:2}

destDirGPRS=${RAW_DIR}/${STREAM_GPRS}/${nominalYear}/${nominalMonth}/${nominalDay}/${nominalHour}/${nominalMinute}
destDirGSM=${RAW_DIR}/${STREAM_GSM}/${nominalYear}/${nominalMonth}/${nominalDay}/${nominalHour}/${nominalMinute}


echo "dest_dir_gprs=${destDirGPRS}"
echo "dest_dir_gsm=${destDirGSM}"

