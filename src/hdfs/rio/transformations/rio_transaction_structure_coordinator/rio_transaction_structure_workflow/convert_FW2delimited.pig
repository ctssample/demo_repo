---------------------------------------------------------------------------------------------------------------------------
--  Script : convert_FW2delimited.pig
--  Description : This script reads the specified source file and converts to Delimited file in target dir
--              
--  By: Priyank Gupta
--  Email : Priyank.Gupta@cognizant.com
--
--  Modification History:
--  Rev#     Date        Developer        Description
--  ----  ----------  ----------------    ---------------------------------------------------------
--  1.0   2015-01-05  Priyank Gupta       First Release
--  1.1   2015-05-11  Priyank Gupta       Perametrized piggybank_URI
---------------------------------------------------------------------------------------------------------------------------

--Mandatory Parameters:
--%default InputDir '/data/dev/swe/raw/ime/tmp/target'
--%default TargetDir '/data/dev/swe/raw/ime/tmp/target/structured'
--%default Delimiter '`'
--%default FWPattern '-10, 11-30, 31-50, 51-70, 71-'
--%default PiggyBankFileURI 'hdfs://nameservice1/apps/dev/swe/lib/piggybank.jar'

REGISTER '${PiggyBankFileURI}';

input_data = LOAD '${InputDir}'
  USING org.apache.pig.piggybank.storage.FixedWidthLoader(
    '${FWPattern}', 'USE_HEADER'
  );

STORE input_data INTO '${TargetDir}' USING PigStorage('${Delimiter}');