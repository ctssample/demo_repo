---------------------------------------------------------------------------------------------------------------------------
--  Script : rio_data_segregate.pig
--  Description : This script reads the specified rio source file dirand performs following transformations on the file
--                1. Change encoding to UTF8
--                2. Segregate various record types based on CMT (GSM and GPRS, Header and Footer)
--                3. Validate and remove Header/Footer
--  Run Command(s) : rio_data_segregate.pig 
--
--  By: Priyank Gupta
--  Email : Priyank.Gupta@cognizant.com
--
--  Modification History:
--  Rev#     Date        Developer        Description
--  ----  ----------  ----------------    ---------------------------------------------------------
--  1.0   2016-01-05  Priyank Gupta       First Release
--  1.1   2016-01-15  Saurabh Chhajed	  Defect 491 fix
--  1.2   2016-01-26  Priyank Gupta       RejectList dir parameterized and GPS/GPRS dir parameter made optional
---------------------------------------------------------------------------------------------------------------------------


--Mandatory Parameters:
--%default InputDir hdfs://nameservice1/data/dev/swe/raw/rio/tmp/0001624-160125133648490-oozie-oozi-W
--%default InputCharSet iso-8859-1
--%default TargetDelimiter '`'
--%default TargetDir hdfs://nameservice1/data/dev/swe/raw/rio/tmp/0001624-160125133648490-oozie-oozi-W
--%default Charset_UDF_URI hdfs://nameservice1/apps/dev/swe/lib/teliasonera_cdl.jar
--%default RejectListDir hdfs://nameservice1/data/dev/swe/raw/rio/tmp/0001624-160125133648490-oozie-oozi-W/rejectList
--%FilePattern rio_prag_incoming_dsp_*.dat


--Optional Parameter initialization
%default MetaExpectedCount '2'
%default MetaPattern '^[ ]*inco_dsp.*'

%default GPRS_dir '${TargetDir}/gprs' --Out Dir for GPRS
%default GSM_dir '${TargetDir}/gsm' --Out Dir for GSM

%declare GPRSRecordPattern '^[ ]*(GPG|GPS).*'
--%declare GSMRecordPattern '^[ ]*(MSO|CFO|MST|M94|FXL).*' --### Other CMTs will fall under GSM


-- jar for decoding data into utf8
REGISTER '${Charset_UDF_URI}'; 


-- function to convert in utf8
DEFINE DecodeByteToString com.teliasonera.cdl.pig.udf.evaluation.convert.DecodeByteToString();

%declare TEXT_CONVERTER 'com.twitter.elephantbird.pig.util.TextConverter';
%declare SEQFILE_STORAGE 'com.twitter.elephantbird.pig.store.SequenceFileStorage';


-- load data from input directory prepending filename to record using tagfile
-- each line read as bytearray to prevent character encoding
data = LOAD '${InputDir}/${FilePattern}' USING PigStorage('~','-tagFile') AS (filename:chararray,org_record:bytearray);

-- decode file records data with supplied encoding
decoded_data =  FOREACH data 
				GENERATE filename, DecodeByteToString (org_record,'${InputCharSet}') AS decoded_record;

-- split the data into metadata records and actual data records
SPLIT decoded_data INTO 
				meta IF (decoded_record MATCHES '${MetaPattern}'),				 
				payload OTHERWISE;

-- verify individual file's metadata as having 2 rows of distinct meta records 
meta_match = FILTER (
				FOREACH (GROUP meta BY filename) 
				GENERATE group AS filename,
				(int) COUNT(meta) as meta_count
			)	BY (meta_count IS NOT NULL AND meta_count==(int)${MetaExpectedCount});



SPLIT (
	JOIN payload BY filename LEFT OUTER,
		meta_match BY filename USING 'replicated'
	)
INTO data_out IF meta_match::filename IS NOT NULL,
reject_files OTHERWISE;

-- combine all rejected data, and get bad file names
reject_file_names = DISTINCT (FOREACH reject_files GENERATE CONCAT('${InputDir}/',payload::filename,';CDL1104;MetaRecord count or specification mismatch') );



SPLIT (FOREACH data_out GENERATE $0,$1) INTO
	GPRS_data_out IF $1 MATCHES '${GPRSRecordPattern}',
	GSM_data_out OTHERWISE ;

sh bash -c 'echo `$(hadoop fs -test -e ${RejectListDir}) &&  $(hadoop fs -rm -R ${RejectListDir})`';
sh bash -c 'echo `$(hadoop fs -test -e ${GPRS_dir}) &&  $(hadoop fs -rm -R ${GPRS_dir})`';
sh bash -c 'echo `$(hadoop fs -test -e ${GSM_dir}) &&  $(hadoop fs -rm -R ${GSM_dir})`';

STORE reject_file_names INTO '${RejectListDir}' USING PigStorage();
STORE GPRS_data_out INTO '${GPRS_dir}' 	USING PigStorage('${TargetDelimiter}');
STORE GSM_data_out INTO '${GSM_dir}' 	USING PigStorage('${TargetDelimiter}') ;