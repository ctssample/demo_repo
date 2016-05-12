#!/bin/bash
# This is the deploy script for transformation applications.
# If run wiht action=clean it will remove transformation application code on hdfs.
#
# Arguments
#       envirionment
#       action: [deploy,clean].
#       tenant
#       release
#       source_system
#
# example: ./deploy_hdfs_apps.sh dev deploy swe R0b0123 eniq
# example: ./deploy_hdfs_apps.sh dev clean swe R0b0123 eniq

readonly ENV="$1"
readonly ACTION="$2"
readonly TENANT="$3"
readonly RELEASE="$4"
readonly UNIT="$5"

#Go to directory where the current script is and assign the path to PWD variable.
cd "$(dirname "$0")"
readonly PWD=`pwd`

echo "INFO: Starting transformation deployment with action = $ACTION, envirionment = $ENV, tenant = $TENANT, release = $RELEASE, source = ${UNIT}"

readonly APPS="/apps/${ENV}/${TENANT}/transformations/${UNIT}/${RELEASE}/"

if [[ ${ACTION} == "deploy" ]];
then

    if hadoop fs -test -e ${APPS};
    then
       echo "INFO: ${APPS} already exists. Skipping deploy for env = ${ENV}, tenant = ${TENANT}, release = ${RELEASE}, source = ${UNIT}."
    else

        echo "INFO: putting workflow apps in hdfs"
        # copy apps
        hadoop fs -mkdir -p ${APPS}
        hadoop fs -put $PWD/${UNIT}/transformations/* ${APPS}
    fi

elif [[ ${ACTION} == "clean" ]];
then
    # clean anything there is
    echo "INFO: removing apps for release ${RELEASE}"
    # delete apps
    hadoop fs -rm -r ${APPS}

else
    echo "ERROR: Unknown action."
    exit 1
fi

echo "Done."
