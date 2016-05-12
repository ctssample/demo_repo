#!/bin/bash
# Scipt sets up direcory structure, puts header files and creates tables.
# Arguments:
#       envirionment
#       action
#       namenode
#
# example:  ./deploy_hdfs_rio_data.sh --environment=dev --action=deploy --namenode=hdfs://nameservice1

set -e
#Validation of input arguments.
for i in "$@"
do
    case $i in
        -e=*|--environment=*)
            readonly ENV="${i#*=}"
            shift
            ;;
        -a=*|--action=*)
            readonly ACTION="${i#*=}"
            shift
            ;;
        -n=*|--namenode=*)
            readonly NAMENODE="${i#*=}"
            shift
            ;; 
        *)
            echo "DEPLOYMENT ERROR: invalid argument $1"
            exit 1
            ;;
    esac
done

#Validation of action argument value
case $ACTION in
    deploy);;
    clean);;
    *)
        echo "DEPLOYMENT ERROR: invalid action, --action=$ACTION is not allowed"
        exit 1
        ;;
esac

#Validation of environment argument value
if [[ -z "$ENV" ]]; then
    echo "DEPLOYMENT ERROR: environment is absent"
    exit 1
fi

#Validation of namenode argument value
if [[ -z "$NAMENODE" ]]; then
    echo "DEPLOYMENT ERROR: namenode is absent"
    exit 1
fi

if [[ ${ACTION} == "deploy" ]];
then

    echo "INFO: Creating base tables"
    hive -f create_rio_prag_incoming_gprs_table.hql -hivevar env=${ENV} -hivevar nameNode=${NAMENODE}
	hive -f create_rio_prag_incoming_gsm_table.hql -hivevar env=${ENV} -hivevar nameNode=${NAMENODE}

    # put headers

elif [[ ${ACTION} == "clean" ]];
then
    # clean all data there is
    #set script NOT to fail if any sub-command fails
    set +e

    echo "INFO: removing rio tables"
    # delete tables 
    hive -f drop_rio_tables.hql -hivevar env=${ENV}

    set -e

else
    echo "ERROR: Unknown action."
    exit 1
fi

echo "Done."
