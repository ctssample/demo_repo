The file contains information about mft data ingestion deployment process.

The process of crontab jobs (per source) creation/running consists of the following steps:
   - Prerequisite: <release> of code application sholuld be deployed and <environment> set up should be done according to deployment instruction. 
   - To make script executable in crontab, use the following command: ctontab -e
   - To run file push script in crontab, add the following (with needed modifications): 
* * * * * /opt/cdl/<environment>/<tenant>/file_push/<release>-instance-1/data_ingestion.sh  --environment=<environment> --tenant=<tenant> --source=<source> >> /opt/cdl/log/<environment>/<tenant>/file_push/data_ingestion_<source>_error.log 2>&1

N.B. For Fenix (exclusively) mft ingestion should be triggered with the following crontab options.

* 15 * * * /opt/cdl/<environment>/grp/file_push/<release>-instance-1/data_ingestion.sh  --environment=<environment> --tenant=grp --source=fenix >> /opt/cdl/log/<environment>/grp/file_push/data_ingestion_fenix_error.log 2>&1


=================== N.B. Crontab example configuration with .avro workaround enabled: ==========================

#CDN:
#  1. Make .avro transformation
#  2. Uppload .avro to HDFS
#
#Note:
#  Scripts are working asyncronuosly, but each checks specific files according to file patter

* * * * * /opt/cdl/dev/grp/file_push/R0b000-instance1/data_ingestion.sh  --environment=dev --tenant=grp --source=cdn >> /opt/cdl/log/dev/grp/file_push/data_ingestion_cdn_error.log 2>&1

* * * * * /opt/cdl/dev/grp/file_push/R0b000-instance1/transform_json_tsv_to_avro.sh  --environment=dev --tenant=grp --source=cdn >> /opt/cdl/log/dev/grp/file_push/data_transformation_cdn.log 2>&1

==================================================================================================================