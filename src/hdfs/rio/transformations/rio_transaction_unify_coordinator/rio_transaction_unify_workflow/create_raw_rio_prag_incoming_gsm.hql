DROP TABLE IF EXISTS ${env}_swe_raw.${raw_table_gsm};

CREATE EXTERNAL TABLE ${env}_swe_raw.${raw_table_gsm}
(
`SOURCE_FILE_NAME` VARCHAR(100),
`CMT` VARCHAR(3) COMMENT 'Call Module Type + Not 1',
`IMSI` VARCHAR(15)  COMMENT 'IMSI',
`SCHDATE` VARCHAR(8)  COMMENT 'Date',
`SCHTIME` VARCHAR(6)  COMMENT 'Time',
`CHDUR_S` VARCHAR(6)  COMMENT 'Duration',
`OPERATOR_ID` VARCHAR(8)  COMMENT 'Operator',
`PRICE_PLAN_ID` VARCHAR(8)  COMMENT 'Price plan',
`SERVICE_ID` VARCHAR(8)  COMMENT 'Service',
`PRICE_LIST_ID` VARCHAR(8)  COMMENT 'Price list',
`DISCPLAN_ID` VARCHAR(8)  COMMENT 'Discount plan',
`SERVPROV_ID` VARCHAR(8)  COMMENT 'Service provider',
`ZONE_PRGRP` VARCHAR(8)  COMMENT 'Zone price group code',
`ZONE_DISCGRP` VARCHAR(8)  COMMENT 'Zone discount group code',
`TOTAL_CHARGE` FLOAT  COMMENT 'Total charge',
`TOTAL_CHARGE_REG` FLOAT  COMMENT 'Total charge regular',
`ORIG_CHARGE` FLOAT  COMMENT 'Original charge',
`DISC_AMOUNT` FLOAT  COMMENT 'Discount amount',
`IN_FILE_ID` VARCHAR(21)  COMMENT 'In file id',
`OUT_FILE_ID` VARCHAR(15)  COMMENT 'Out file id',
`PREPAID` VARCHAR(1)  COMMENT 'Prepaid flag + 1 if prepaid',
`UDV`   BIGINT  COMMENT 'Uplink Data Volume',
`DDV`   BIGINT  COMMENT 'Downlink Data Volume',
`CTYPE` VARCHAR(5)  COMMENT 'Call type',
`CTYPE2` VARCHAR(5)  COMMENT 'Call type 2',
`CTYPE3` VARCHAR(5)  COMMENT 'Call type 3',
`MSISDN` VARCHAR(20)  COMMENT 'MSISDN',
`NETINC` VARCHAR(1)  COMMENT 'Netinc flag + 1 if netinc, 0 otherwise',
`REC_TYPE` VARCHAR(1)  COMMENT 'Record type + 1-normal, 2-test, 3-n+t',
`AGREEMENT_ID` VARCHAR(8)  COMMENT 'Agreement id',
`PPLAN_CATEGORY_ID` VARCHAR(10)  COMMENT 'Price plan category id',
`CUST_CATEGORY` VARCHAR(2)  COMMENT 'Customer category',
`IP_ADDRESS` VARCHAR(15)  COMMENT 'SGSN address',
`CHARGED_UNITS` BIGINT  COMMENT 'Charged units',
`INT_PREFIX` VARCHAR(6)  COMMENT 'International prefix',
`INFO` VARCHAR(100)  COMMENT 'Info',
`OSERPROV` VARCHAR(8)  COMMENT 'ORIG SERVICE PROVIDER ID + ‘MOBITEL’',
`SUBSCR` VARCHAR(14)  COMMENT 'SUBSCRIPTION ID + Not 4',
`CUSTOM` VARCHAR(10)  COMMENT 'CUSTOMER ID',
`SUBSTYPE` VARCHAR(3)  COMMENT 'SUBSCRIBER TYPE ID',
`PRODUCT` VARCHAR(3)  COMMENT 'PRODUCT ID',
`BALMOD` VARCHAR(8)  COMMENT 'BALANCE MODEL',
`NOPRPLAN` VARCHAR(3)  COMMENT 'NUMBER of PRICE PLAN',
`PRPLAN` VARCHAR(210)  COMMENT 'PRAG_PRICE_PLAN_V',
`SUBSERVNO` VARCHAR(3)  COMMENT 'SUBSCR SERVICE_NO',
`SUBSERV` VARCHAR(220)  COMMENT 'SUBSCR_SERVICE_V',
`RECEIVETIMESTAMP` VARCHAR(14)  COMMENT 'RECEIVE_TIMESTAMP',
`FILPROD` VARCHAR(3)  COMMENT 'FILE PRODUCT',
`CHUNIT` BIGINT  COMMENT 'USED CHUNITS',
`TCHUNIT` BIGINT  COMMENT 'TOTAL CHUNITS',
`OCHITEM` VARCHAR(1)  COMMENT 'ORIG CHARGEABLE ITEM',
`SATJANST` VARCHAR(5)  COMMENT 'SS ATJANST',
`GC` VARCHAR(1)  COMMENT 'GENERAL CONTENT',
`ATJANST` VARCHAR(5)  COMMENT 'ATJANST',
`NTJANST1` VARCHAR(1)  COMMENT 'NTJANST-1',
`NTJANST2` VARCHAR(2)  COMMENT 'NTJANST-2',
`NTJANST3` VARCHAR(2)  COMMENT 'NTJANST-3',
`CALLTYPE` VARCHAR(5)  COMMENT 'CALL TYPE',
`STYP` VARCHAR(2)  COMMENT 'STYP',
`DESTKOD` VARCHAR(10)  COMMENT 'DESTKOD',
`PRICING_SUBSCR_TYPE_ID` VARCHAR(3)  COMMENT 'PRICING SUBSCR TYPE ID',
`PARENT_SUBSCR_ID` VARCHAR(14)  COMMENT 'PARENT SUBSCR ID',
`PARENT_SUBSCR_TYPE_ID` VARCHAR(3)  COMMENT 'PARENT SUBSCR TYPE ID',
`PARENT_CUSTOMER_ID` VARCHAR(10)  COMMENT 'PARENT CUSTOMER ID',
`USE_PARENT_BALANCE` VARCHAR(1)  COMMENT 'USE_PARENT_BALANCE_IND',
`MTXFORK` VARCHAR(4)  COMMENT 'MTXFORK',
`GPRSSUBSCRSERVSUR` VARCHAR(10)  COMMENT 'GPRS_TPP_SUBSCR_SERVICE_SUR',
`CUST_CATEGORY_2` VARCHAR(2)  COMMENT 'CUSTOMER CATEGORY',
`DISCPLAN` VARCHAR(8)  COMMENT 'DISCOUNT PLAN ID',
`FILENAME` VARCHAR(40)  COMMENT 'IN FILE NAME',
`ROUTID` VARCHAR(10)  COMMENT 'ROUTING ID',
`PRPLCAT` VARCHAR(10)  COMMENT 'PRICE PLAN CATEGORY ID',
`PRPLCAMP_1` VARCHAR(8)  COMMENT 'CAMPAIGN ID',
`PRPLCAMP_2` VARCHAR(8)  COMMENT 'PRICE PLAN CAMPAIGN ID',
`GLM` VARCHAR(1)  COMMENT 'GENERAL ALARM ENGINE',
`ROAMING_POSTPAID_IND` VARCHAR(1)  COMMENT 'ROAMING POSTPAID IND',
`TAXETYP` VARCHAR(1)  COMMENT 'TAXETYP',
`PRICING_SUBSCRIPTION_ID` VARCHAR(14)  COMMENT 'PRICING SUBSCRIPTION ID',
`POOL_MEMBER_INDICATOR` VARCHAR(1)  COMMENT 'POOL MEMBER INDICATOR',
`FILLER` VARCHAR(4)  COMMENT 'SPARE',
`PT` VARCHAR(2)  COMMENT 'POSTTYP',
`ABGNR` VARCHAR(14)  COMMENT 'ABONNEMANGS_NUMMER',
`EXPDAT` VARCHAR(10)  COMMENT 'DATUM_START_SAMTAL',
`EXPTID` VARCHAR(8)  COMMENT 'TID_START_SAMTAL',
`DEBTID` VARCHAR(6)  COMMENT 'SAMTALS_TID',
`AVGIFT` FLOAT  COMMENT 'SAMTALS_AVGIFT',
`ORDAVG` FLOAT  COMMENT 'ORDINARIE_AVGIFT',
`PRBAL` VARCHAR(9)  COMMENT 'PRICE BALANCE',
`PRBALP` VARCHAR(1)  COMMENT 'PRICE BALANCE PERIOD',
`BNR` BIGINT  COMMENT 'RINGT NUMMER',
`INTTID` VARCHAR(6)  COMMENT 'INTERUPTION TIME',
`BNET` VARCHAR(6)  COMMENT 'NÄTTILLHÖRIGHET',
`INKVIA` VARCHAR( 7)  COMMENT 'INKOMMANDE VIA (CELL)',
`TRFLAND` VARCHAR(3)  COMMENT 'TRAFIK_LAND',
`TRFTYP` VARCHAR(3)  COMMENT 'TRAFIK_TYP',
`PRODUKT` VARCHAR(3)  COMMENT 'PRODUKT',
`ATJANST_2` VARCHAR(5)  COMMENT 'TJÄNST',
`NTJANST` VARCHAR(5)  COMMENT 'NÄT_REALTERAD_TJÄNST',
`CALLTYPE_2` INT  COMMENT 'DESTINATONS_GRUPP',
`TAXETYP_2` VARCHAR(1)  COMMENT 'PRIS_DIFFRENSIERING',
`IP` VARCHAR(3)  COMMENT 'INTERNATIONELLT-PREXIX',
`FILLER_1` VARCHAR(4)  COMMENT 'UTFYLLNAD',
`TINFOFLG` VARCHAR(1)  COMMENT 'TILLÄGGS_INFO-FLAGG',
`PT_2` VARCHAR(2),
`OPER` VARCHAR(5),
`LANDSKOD` VARCHAR(4),
`IMSI_2` VARCHAR(15),
`FILLER_2` VARCHAR(66),
`CIN` BIGINT,
`CHUNITS` BIGINT,
`NETUSE` VARCHAR(1),
`FILLER_3` VARCHAR(75)
)
COMMENT 'Temporary table for RiO FC GSM feed'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '`'
LOCATION '${hdfs_raw_dir_gsm}';
