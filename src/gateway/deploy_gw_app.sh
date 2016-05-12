#!/bin/bash
# This is gateway application deploy script.
# It will set up gateway application for particular instance.
# The script should be executed only from src/deploy.sh
#
# Arguments:
#       environment: [test, dev, prod]
#	action: [deploy, clean]
#       tenant: [swe, fin, est, nor, grp, cdl_platform]
#       instance_dir: <the release instance number>
#       source: [alpha blueice cem cusin omt eniq fenix]
#       physical flume configuration: [test_flume_conf prod_flume_conf]

#Go to directory where the current script is and assign the path to PWD variable.
cd "$(dirname "$0")"
readonly PWD=$(pwd)

# Receiving needed input information
readonly ENV=$1
readonly ACTION=$2
readonly TENANT=$3
readonly INSTANCE_DIR=$4
readonly SOURCE=$5
readonly PHY_FLUME_CONF=$6

case $SOURCE in
    cem)
        readonly APP_NAME_DIR="file_pull_push"

        if [[ $ACTION == "deploy" ]]; then

            for i in {1..2}; do
                #Create directories per specific build release
                mkdir /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR"_"$i/$INSTANCE_DIR
                mkdir /opt/cdl/log/$ENV/$TENANT/$APP_NAME_DIR"_"$i/$INSTANCE_DIR

                #Deploy gateway applications
                cp $PWD/$APP_NAME_DIR/* /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR"_"$i/$INSTANCE_DIR
            done
        elif [[ $ACTION == clean ]]; then

            for i in {1..2}; do
                rm -r /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR"_"$i/$INSTANCE_DIR
                rm -r /opt/cdl/log/$ENV/$TENANT/$APP_NAME_DIR"_"$i/$INSTANCE_DIR
            done
        fi
        ;;
    cusin)
        readonly APP_NAME_DIR="message_flume"

        if [[ $ACTION == "deploy" ]]; then

            #Create directories per specific build release
            mkdir /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
            			
            #Deploy gateway applications
            cp -r $PWD/$APP_NAME_DIR/common_files/* /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
            cp -r $PWD/$APP_NAME_DIR/$PHY_FLUME_CONF/* /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
        elif [[ $ACTION == clean ]]; then
            rm -r /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
        fi
        ;;
	toolbox)
        readonly APP_NAME_DIR="message_flume"

        if [[ $ACTION == "deploy" ]]; then

            #Create directories per specific build release
            mkdir -p /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
            mkdir -p /opt/cdl/log/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR 
			
            #Deploy gateway applications
            cp -r $PWD/$APP_NAME_DIR/common_files/* /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
            cp -r $PWD/$APP_NAME_DIR/$PHY_FLUME_CONF/* /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
        elif [[ $ACTION == clean ]]; then
            rm -r /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
        fi
        ;;
    *)
        readonly APP_NAME_DIR="file_push"

        if [[ $ACTION == "deploy" ]]; then

            #Create directories per specific build release
            #Deploy gateway applications (only once for all these sources)
            if [[ ! -d /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR  ]]; then
                mkdir /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
                mkdir /opt/cdl/log/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR 

                cp $PWD/$APP_NAME_DIR/* /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
            fi
        elif [[ $ACTION == clean ]]; then
            if [[ -d /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR  ]]; then
                rm -r /opt/cdl/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR
                rm -r /opt/cdl/log/$ENV/$TENANT/$APP_NAME_DIR/$INSTANCE_DIR 
            fi
        fi
        ;;
esac
