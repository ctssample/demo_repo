#!/bin/bash
# Script monitors the new file arrival from MFT side.
# If new file was arrived and it is valid, it will be saved in HDFS (RAW light).
# Arguments:
# Current environment
# Tenant name
# Directory to monitor new files arrival.
#
# example: /opt/cdl/dt1/grp/file_push/R0b001-instance-1/data_ingestion.sh  --environment=dt1 --tenant=grp --source=eniq

echo "$(date) - File_push transfer transformation launched."

function writeHdfs () {
    local hdfs_dir=$1
    local mft_file=$2

    hadoop fs -mkdir -p $hdfs_dir
    hadoop fs -moveFromLocal $mft_file $hdfs_dir
}

function checkStatus () {
    "$@"
    local status=$?
    if [ $status -ne 0 ]
    then
        echo "$(date) - error with $1" >&2
#FixMe: Add move operation of failed file to failed
    else
        echo "$(date) - Move operation to HDFS done."
    fi
}

function ingestData () {
    for DIR in $DIRS
    do
        case "$DIR" in
        mft_data_eniq)
            local pattern_array="${!eniq_pattern[@]}"
            local pattern_sample=eniq_pattern
            local pattern_dest=$ENIQ_DEST
            ;;
        mft_data_fenix)
            local pattern_array="${!fenix_pattern[@]}"
            local pattern_sample=fenix_pattern
            local pattern_dest=$FENIX_DEST
            ;;
        mft_data_omt)
            local pattern_array="${!omt_pattern[@]}"
            local pattern_sample=omt_pattern
            local pattern_dest=$OMT_DEST
            ;;
        mft_data_alpha)
            local pattern_array="${!alpha_pattern[@]}"
            local pattern_sample=alpha_pattern
            local pattern_dest=$ALPHA_DEST
            ;;
        mft_data_blueice)
            local pattern_array="${!blueice_pattern[@]}"
            local pattern_sample=blueice_pattern
            local pattern_dest=$BLUEICE_DEST
            ;;
        mft_data_nps)
            local pattern_array="${!nps_pattern[@]}"
            local pattern_sample=nps_pattern
            local pattern_dest=$NPS_DEST
            ;;
        mft_data_ime)
            local pattern_array="${!ime_pattern[@]}"
            local pattern_sample=ime_pattern
            local pattern_dest=$IME_DEST
            ;;
        mft_data_mosaic)
            local pattern_array="${!mosaic_pattern[@]}"
            local pattern_sample=mosaic_pattern
            local pattern_dest=$MOSAIC_DEST
            ;;
        mft_data_rio)
            local pattern_array="${!rio_pattern[@]}"
            local pattern_sample=rio_pattern
            local pattern_dest=$RIO_DEST
            ;;
        mft_data_cdn)
            local pattern_array="${!cdn_pattern[@]}"
            local pattern_sample=cdn_pattern
            local pattern_dest=$CDN_DEST
            ;;
        *)
            local pattern_array="None"
            local pattern_sample="None"
            local pattern_dest="None"
            ;;
        esac

        if [[ $pattern_array != "None" ]]
        then
            local mft_in_dir=$IN_PATH${DIR}'/in'
            local mft_out_dir=$IN_PATH${DIR}'/out'
            local mft_failed_dir=$IN_PATH${DIR}'/failed'

            local files=`find $mft_in_dir -type f -printf "%f\n"`

            for file in $files
            do
                for pattern in $pattern_array
                do
                    local pattern_item=${pattern_sample}[$pattern]
                    if [[ $file =~ ${!pattern_item} ]]
                    then
                        local mft_file=$mft_in_dir'/'${file}
                        mv $mft_file $mft_out_dir
                        mft_file=$mft_out_dir'/'${file}
                        echo "$(date) - INFO - Found files to ingest in $mft_file Starting move operation to HDFS..."

                        checkStatus writeHdfs $pattern_dest $mft_file
#FixMe: Remove that when workaround causing issue will be resolved
                    fi
                done
            done
        fi
    done
    echo "Function ingestData() finished."
}

#Main function

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
        -s=*|--source=*)
            readonly SOURCE="${i#*=}"
            shift
            ;;
        *)
            echo "$(date) - invalid argument $1"
            exit 1
            ;;
    esac
done

#Validation of tenant argument value.
case $TENANT in
    swe);;
    fin);;
    est);;
    nor);;
    grp);;
    cdl_platform);;
    *)
        echo "$(date) - invalid tenant, --tenant=$TENANT is not allowed"
        exit 1
        ;;
esac

#Validation of environment argument value.
if [[ -z $ENV ]]; then
    echo "$(date) - invalid environment, environment cannot be empty"
    exit 1
else
    readonly IN_PATH="/opt/tibco/mft/$ENV/$TENANT/"
    readonly HDFS_PREFIX="/data/$ENV/"
fi

#Validation of source argument value.
case $SOURCE in
    alpha | blueice | omt | ime | mosaic | rio)
        if [[ $TENANT != swe ]]; then
            echo "$(date) - source $SOURCE is not allowed for $TENANT tenant"
            exit 1
        else
            readonly DIRS="mft_data_$SOURCE"
        fi
        ;;
    eniq | fenix)
        if [[ $TENANT != grp ]]; then
            echo "$(date) - source $SOURCE is not allowed for $TENANT tenant"
            exit 1
        else
            readonly DIRS="mft_data_$SOURCE"
        fi
        ;;
    cdn)
        if [[ $TENANT != grp && $TENANT != fin  && $TENANT != swe ]]; then
            echo "$(date) - source $SOURCE is not allowed for $TENANT tenant"
            exit 1
        else
            readonly DIRS="mft_data_$SOURCE"
        fi
        ;;
    all)
        readonly DIRS=$(ls -l --time-style="long-iso" $IN_PATH | egrep '^d' | awk '{print $8}')
        ;;
    *)
        echo "$(date) - invalid source, --source=$SOURCE is not allowed"
        exit 1
        ;;
esac

declare -A eniq_pattern=( ["eniq_ps_2g_huawei"]="^ENIQ_PS_2G_Huawei_[0-9]{8}.csv$"
                          ["eniq_cs_2g_huawei"]="^ENIQ_CS_2G_Huawei_[0-9]{8}.csv$"
                          ["eniq_ps_3g_huawei"]="^ENIQ_PS_3G_Huawei_[0-9]{8}.csv$"
                          ["eniq_cs_3g_huawei"]="^ENIQ_CS_3G_Huawei_[0-9]{8}.csv$"
                          ["eniq_ps_4g_huawei"]="^ENIQ_PS_4G_Huawei_[0-9]{8}.csv$"
                          ["eniq_ps_2g_ericsson"]="^ENIQ_PS_2G_Ericsson_[0-9]{8}.csv$"
                          ["eniq_cs_2g_ericsson"]="^ENIQ_CS_2G_Ericsson_[0-9]{8}.csv$"
                          ["eniq_ps_3g_ericsson"]="^ENIQ_PS_3G_Ericsson_[0-9]{8}.csv$"
                          ["eniq_cs_3g_ericsson"]="^ENIQ_CS_3G_Ericsson_[0-9]{8}.csv$"
                          ["eniq_ps_4g_ericsson"]="^ENIQ_PS_4G_Ericsson_[0-9]{8}.csv$"
                          ["eniq_ps_2g_nsn"]="^ENIQ_PS_2G_NSN_[0-9]{8}.csv$"
                          ["eniq_cs_2g_nsn"]="^ENIQ_CS_2G_NSN_[0-9]{8}.csv$"
                          ["eniq_ps_3g_nsn"]="^ENIQ_PS_3G_NSN_[0-9]{8}.csv$"
                          ["eniq_cs_3g_nsn"]="^ENIQ_CS_3G_NSN_[0-9]{8}.csv$"
                          ["eniq_ps_4g_nsn"]="^ENIQ_PS_4G_NSN_[0-9]{8}.csv$"
                          )

declare -A fenix_pattern=( ["fenix_umts"]="^fenix_cdl_umts_[0-9]{8}.csv$"
                           ["fenix_gsm"]="^fenix_cdl_gsm_[0-9]{8}.csv$"
                           ["fenix_lte"]="^fenix_cdl_lte_[0-9]{8}.csv$"
                           )

declare -A omt_pattern=( ["omt_order"]="^omt_order_[0-9]{8}.csv$"
                         ["omt_produkt"]="^omt_produkt_[0-9]{8}.csv$"
                         )

declare -A alpha_pattern=( ["alpha_sr"]="^alpha_sr_daily_[0-9]{8}.csv$"
                           ["alpha_notes"]="^alpha_notes_daily_[0-9]{8}.csv$"
                           ["alpha_tasks"]="^alpha_tasks_daily_[0-9]{8}.csv$"
                           )

declare -A blueice_pattern=( ["blueice_o"]="^blueice_spaktmpr_o_[0-9]{14}.txt$"
                             ["blueice_y"]="^blueice_spaktmpr_y_[0-9]{14}.txt$"
                             )

declare -A nps_pattern=( ["nps_satmetrix"]="^fbk_data\.report_[0-9]{8}.csv$" )

declare -A mosaic_pattern=( ["mosaic_biseg"]="^bi-seg_dmp_B2C_processed_[0-9]{8}.csv$" )

declare -A ime_pattern=( ["nobill_call"]="^TSS_CALLRECORD_[0-9]{14}_[0-9]{14}_[0-9]{6}.csv$"
                         ["nobill_pads"]="^TSS_PADSRECORD_[0-9]{14}_[0-9]{14}_[0-9]{6}.csv$"
                         ["nobill_call_last"]="^TSS_CALLRECORD_[0-9]{14}_[0-9]{14}_[0-9]{6}_LAST.csv$"
                         ["nobill_pads_last"]="^TSS_PADSRECORD_[0-9]{14}_[0-9]{14}_[0-9]{6}_LAST.csv$"
                         ["rio_operinfo"]="^AF52_PROD_OPERINFO_[0-9]{8}_[0-9]{8}.dat"
                         ["ime_cdfn"]="^AF50\.(FREMPG1SGW|HYMPG1SGW|LDHMPG1SGW|VRRMPG1SGW|LDHMME1|VRRMME1|FREMME2|HYMME2|FRE1MS|GBR1MS|GRA1MS|HY1MS|LDH1MS|MB1MS|FREMPG1|HYMPG1|LDHMPG1|VRRMPG1)\.TTFILE[0-9][0-9]\..*[^(tmp)]$"
                         )

declare -A rio_pattern=( ["rio_prag"]="^rio_prag_incoming_dsp_[0-9]{9}_[0-9]{8}.dat")

declare -A cdn_pattern=( ["ott_usage"]="^ott_"$TENANT"_"$ENV"_[0-9]{4}_[0-1][0-9]_[0-3][0-9]\.json$"
                         ["iptv_usage"]="^iptv_"$TENANT"_"$ENV"_[0-9]{4}_[0-1][0-9]_[0-3][0-9]_[0-2][0-9]\.txt$"
                         ["materials_usage"]="^materials_"$TENANT"_"$ENV"_[0-9]{4}_[0-1][0-9]_[0-3][0-9]\.txt$"
                         )

readonly ENIQ_DEST=$HDFS_PREFIX$TENANT"/raw/eniq/in"
readonly FENIX_DEST=$HDFS_PREFIX$TENANT"/raw/fenix/in"
readonly OMT_DEST=$HDFS_PREFIX$TENANT"/raw/omt/in"
readonly ALPHA_DEST=$HDFS_PREFIX$TENANT"/raw/alpha/in"
readonly BLUEICE_DEST=$HDFS_PREFIX$TENANT"/raw/blueice/in"
readonly NPS_DEST=$HDFS_PREFIX$TENANT"/raw/nps/in"
readonly IME_DEST=$HDFS_PREFIX$TENANT"/raw/ime/in"
readonly MOSAIC_DEST=$HDFS_PREFIX$TENANT"/raw/mosaic/in"
readonly RIO_DEST=$HDFS_PREFIX$TENANT"/raw/rio/in"
readonly CDN_DEST=$HDFS_PREFIX$TENANT"/raw/cdn/in"

#Kerberos ticket authentication
readonly USER=$(whoami)
kinit $USER@TCAD.TELIA.SE -k -t ~/$USER.keytab

ingestData
