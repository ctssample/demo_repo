#!/bin/bash
########################################################################################################################
###  Script : bulk_move_to_processing.sh												
###  Description : This script reads the specified source file dir and 
###                                                                                                                    
###  Run Command(s) : bulk_move_to_processing.sh <INPUT_HDFS_DIR> <INPUT_FILE_PATTERN> <PROCESSING_HDFS_DIR> [<DONE_HDFS_DIR> <REJECT_LIST_DIR>]
###
###  By: Priyank Gupta
###  Email : Priyank.Gupta@cognizant.com
###
###  Modification History:
###  Rev#     Date        Developer        Description
###  ----  ----------  ----------------    ---------------------------------------------------------
###  1.0   2016-01-05  Priyank Gupta       First Release
###  1.1   2016-01-25  Priyank Gupta       Files not to be copied to done dir. Instead to be checked if file already exists in done.
##########################################################################################################################

#Declarations
    ARG_CNT=$#
    PROG_NAME=`basename $0`
    STATUS=""
    FILE_COUNT=0

    INPUT_HDFS_DIR=$1 # HDFS Path to Input Dir
    INPUT_FILE_PATTERN=$2 # HDFS Path to Data File
    PROCESSING_HDFS_DIR=$3 # HDFS Path to Processing Dir
    DONE_HDFS_DIR=$4 # HDFS Path to Processing Dir
    REJECT_LIST_DIR=$5 # HDFS Path to Reject List, Parent Dir
    
    REJECT_LIST_FILE="rejected.txt"
    
#Sanity Checks
    if [[ ( ${ARG_CNT} -ne 3 ) ]] && [[ ( ${ARG_CNT} -ne 5 ) ]]; then
        echo "status=ERROR"
        echo "msg=Incorrect Usage. Usage: ${PROG_NAME} <INPUT_HDFS_DIR> <INPUT_FILE_PATTERN> <PROCESSING_HDFS_DIR> [<DONE_HDFS_DIR> <REJECT_LIST_DIR>]"
        exit 0
    fi

    hadoop fs -test -d ${INPUT_HDFS_DIR} || {
        echo "status=ERROR"
        echo "msg=Cannot find the specified HDFS Dir:: ${INPUT_HDFS_DIR}"
        exit 0
    }

    
    for file in `hadoop fs -ls "$INPUT_HDFS_DIR" | egrep "$INPUT_FILE_PATTERN" | awk '{print $8}' | sort`; do
    
        hadoop fs -mkdir -p ${PROCESSING_HDFS_DIR} || {
            echo "status=ERROR"
            echo "msg=Cannot create specified HDFS Dir:: ${PROCESSING_HDFS_DIR}"
            exit 0
        }
        
        #Check if file is already processed and exists in done Dir
        if [[ -n "$DONE_HDFS_DIR" ]]; then
            BASE_FILENAME=`basename ${file}`
            
            hadoop fs -test -f "${DONE_HDFS_DIR}/${BASE_FILENAME}" && {
                echo "$file;CDL3001;Unexpected file,Source File already in Processed Dir:: ${DONE_HDFS_DIR}" >> "${REJECT_LIST_FILE}"
                continue; #Continue to next file loop; Skip file copy to temp step
            }
            
        fi
                
        hadoop fs -mv $file $PROCESSING_HDFS_DIR || {
            echo "status=ERROR"
            echo "msg=Error Code:CDL1002;Error Message:Cannot move file. File::${file} Target Dir ${PROCESSING_HDFS_DIR}"
            exit 0
        }
        ((FILE_COUNT++))
    done
    
    if [[ -s ${REJECT_LIST_FILE} ]]; then
        hadoop fs -mkdir -p ${REJECT_LIST_DIR} || {
            echo "status=ERROR"
            echo "msg=Cannot create specified HDFS Dir:: ${REJECT_LIST_DIR}"
            exit 0
            }
        hadoop fs -copyFromLocal $REJECT_LIST_FILE $REJECT_LIST_DIR || {
            echo "status=ERROR"
            echo "msg=Error Code:CDL1002;Error Message:Cannot move file. File::${REJECT_LIST_FILE} Target Dir ${REJECT_LIST_DIR}"
            exit 0
        }
    fi    
            
    
echo "file_count=${FILE_COUNT}"
echo "status=OK"