SET hive.exec.compress.output=true;
SET avro.output.codec=snappy;
SET hive.merge.mapfiles=true;
SET hive.merge.mapredfiles=true;
SET hive.merge.smallfiles.avgsize=1073741824;

INSERT INTO ${env}_swe_base.${base_table} PARTITION
    (schdate_year, schdate_month , schdate_day, schtime_hour)
SELECT
cmt
,imsi
,schdate as src_schdate
,schtime as src_schtime
,chdur_s
,operator_id
,price_plan_id
,service_id
,price_list_id
,discplan_id
,servprov_id
,zone_prgrp
,zone_discgrp
,total_charge
,total_charge_reg
,orig_charge
,disc_amount
,in_file_id
,out_file_id
,prepaid
,udv
,ddv
,ctype
,ctype2
,ctype3
,msisdn
,netinc
,rec_type
,agreement_id
,pplan_category_id
,cust_category
,ip_address
,charged_units
,int_prefix
,info
,oserprov
,subscr
,custom
,substype
,product
,balmod
,noprplan
,prplan
,subservno
,subserv
,receivetimestamp
,filprod
,chunit
,tchunit
,ochitem
,satjanst
,gc
,atjanst
,ntjanst1
,ntjanst2
,ntjanst3
,calltype
,styp
,destkod
,pricing_subscr_type_id
,parent_subscr_id
,parent_subscr_type_id
,parent_customer_id
,use_parent_balance
,mtxfork
,gprssubscrservsur
,cust_category_2
,discplan
,filename
,routid
,prplcat
,prplcamp_1
,prplcamp_2
,glm
,roaming_postpaid_ind
,taxetyp
,pricing_subscription_id
,pool_member_indicator
,filler
,pt
,abgnr
,expdat
,exptid
,debtid
,avgift
,ordavg
,prbal
,prbalp
,bnr
,inttid
,bnet
,inkvia
,trfland
,trftyp
,produkt
,atjanst_2
,ntjanst
,calltype_2
,taxetyp_2
,ip
,filler_1
,tinfoflg
,pt_2
,oper
,landskod
,imsi_2
,filler_2
,cin
,chunits
,netuse
,filler_3
,source_file_name
,CONCAT(substr (schdate, 1, 4),'-',substr (schdate, 5, 2),'-',substr (schdate, 7, 2)) as schdate
,CONCAT(substr (schtime, 1, 2),':',substr (schtime, 3, 2),':',substr (schtime, 5, 2)) as schtime
,Substr(schdate, 1, 4) as schdate_year
,substr(schdate, 5, 2) as schdate_month
,Substr(schdate, 7, 2) as schdate_day
,substr(schtime, 1, 2) as schtime_hour
FROM ${env}_swe_raw.${raw_table};
