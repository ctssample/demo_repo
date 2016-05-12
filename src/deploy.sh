#!/bin/bash
# This is main deploy script.
# It will set up/tear down environment and trigger source specific deploy scripts for particular instance.
#
# Arguments:
# 	environment: [test, dev, prod]
#	tenant: [swe, fin, est, nor, grp, cdl_platform]
#	action: [deploy, clean]
#	instances: <number of build instances to deploy on the gateway>

# Validation of current build.
if [[ ! -s release_version.txt ]]; then
    echo "DEPLOYMENT ERROR: The current build version is invalid."
    exit;
fi

readonly RELEASE=$(cat release_version.txt)

#Validation of input arguments.
for i in "$@"
do
    case $i in
        -e=*|--environment=*)
            readonly ENV="${i#*=}"
            shift
            ;;
        -t=*|--tenant=*)
            readonly TENANT="${i#*=}"
            shift
            ;;
        -a=*|--action=*)
            readonly ACTION="${i#*=}"
            shift
            ;;
        -i=*|--instances=*)
            readonly INSTANCES="${i#*=}"
            shift
            ;;
        *)
            echo "DEPLOYMENT ERROR: invalid argument $1"
            exit 1
            ;;
    esac
done

#Validation of tenant argument value.
case $TENANT in
    swe)
        readonly SOURCES=(retention rio )
        ;;
    fin)
        readonly SOURCES=()
        ;;
    est);;
    nor);;
    grp)
        readonly SOURCES=(retention toolbox)
        ;;
    cdl_platform);;
    *)
    echo "DEPLOYMENT ERROR: invalid tenant, --tenant=$TENANT is not allowed"
    exit 1
    ;;
esac

if [[ ! $INSTANCES =~ ^[0-9]+$ ]]; then
    echo "DEPLOYMENT ERROR: invalid instance, only number is allowed"
    exit 1
fi

#Validation of action argument value
case $ACTION in
    deploy);;
    clean);;
    *)
        echo "DEPLOYMENT ERROR: invalid action, --action=$ACTION is not allowed"
        exit 1
        ;;
esac

#Go to directory where the current script is and assign the path to PWD variable.
cd "$(dirname "$0")"
readonly PWD=$(pwd)

#Read physical environment configuration
readonly PHY_NAME_NODE=$(hadoop fs -cat /apps/$ENV/config/cluster.properties | awk 'sub(/nameNode=/, "")')
readonly PHY_JOB_TRACKER=$(hadoop fs -cat /apps/$ENV/config/cluster.properties | awk 'sub(/jobTracker=/, "")')
readonly PHY_HCAT_METASOTRE_URI=$(hadoop fs -cat /apps/$ENV/config/cluster.properties | awk 'sub(/hcatMetastoreUri=/, "")')
readonly PHY_FLUME_CONF=$(hadoop fs -cat /apps/$ENV/config/cluster.properties | awk 'sub(/flumeConf=/, "")')

#Prepare all configuration files for deployment on virtual environment
find -name "job.properties" -exec sed -i "s/nameNode=?/nameNode=$(echo $PHY_NAME_NODE | sed -r 's/\//\\\//g')/g" {} \;
find -name "job.properties" -exec sed -i "s/jobTracker=?/jobTracker=$PHY_JOB_TRACKER/g" {} \;
find -name "job.properties" -exec sed -i "s/env=?/env=$ENV/g" {} \;
find -name "job.properties" -exec sed -i "s/release=?/release=$RELEASE/g" {} \;
find -name "job.properties" -exec sed -i "s/hcatMetastoreUri=?/hcatMetastoreUri=$(echo $PHY_HCAT_METASOTRE_URI | sed -r 's/\//\\\//g')/g" {} \;
find -name "*flume.conf" -exec sed -i "s/env=?/$ENV/g" {} \;

readonly GATEWAY_DIR=$PWD/gateway
readonly HDFS_DIR=$PWD/hdfs

#Source specific application code deployment
for inst_nbr in $(seq $INSTANCES); do
    for pattern_nm in ${SOURCES[@]}; do
        #Gateway source specific deployment triggering
        $GATEWAY_DIR/deploy_gw_app.sh $ENV $ACTION $TENANT $RELEASE-instance-$inst_nbr ${pattern_nm} $PHY_FLUME_CONF

        #HDFS source specific deployment cleaning
        #HDFS deployment doesn't know about instances. It should be deployed only once per release
        if [[ $inst_nbr == 1 ]]; then
            $HDFS_DIR/deploy_hdfs_apps.sh $ENV $ACTION $TENANT $RELEASE ${pattern_nm}
        fi
    done
done
