--01 - Unstructured Data Support

CREATE OR REPLACE STAGE UDS.UD_STAGE
    url = 'azure://snowflakeud.blob.core.windows.net/udfiles'
    storage_integration = azure_int
    directory = (enable = true);
    
LIST @UD_STAGE;

SELECT *
  FROM DIRECTORY(@UD_STAGE);
  
/*  
GET_PRESIGNED_URL( @<stage_name> , '<relative_file_path>' , [ <expiration_time> ] )  
expiration_time
Length of time (in seconds) after which the short term access token expires. Default value: 3600 (60 minutes).
*/

SELECT GET_PRESIGNED_URL(@UD_STAGE, RELATIVE_PATH, 300)
  FROM DIRECTORY(@UD_STAGE); 
   
  
SELECT BUILD_SCOPED_FILE_URL(@UD_STAGE, RELATIVE_PATH)
  FROM DIRECTORY(@UD_STAGE);
  
 
SELECT BUILD_STAGE_FILE_URL(@UD_STAGE, RELATIVE_PATH)
  FROM DIRECTORY(@UD_STAGE);
 
--GET_PRESIGNED_URL and BUILD_SCOPED_FILE_URL are non-deterministic functions; the others are deterministic.






--02 - Object Tagging

CREATE [ OR REPLACE ] TAG [ IF NOT EXISTS ] <name> [ COMMENT = '<string_literal>' ];

CREATE [ OR REPLACE ] TAG [ IF NOT EXISTS ] <name>
    [ ALLOWED_VALUES '<val_1>' [ , '<val_2>' , [ ... ] ] ];
    






----- Using Classification ----- Preview Feature — Open - This feature requires Enterprise Edition or higher.
SHOW TAGS IN ACCOUNT;


select extract_semantic_categories('ADVENTUREWORKS.PERSON.PERSONPHONE');

select extract_semantic_categories('ADVENTUREWORKS.PERSON.EMAILADDRESS');

select extract_semantic_categories('ADVENTUREWORKS.PERSON.ADDRESS');

select extract_semantic_categories('ADVENTUREWORKS.PERSON.PERSON');

select extract_semantic_categories('ADVENTUREWORKS.HUMANRESOURCES.EMPLOYEE');




call associate_semantic_category_tags('ADVENTUREWORKS.PERSON.PERSONPHONE', extract_semantic_categories('ADVENTUREWORKS.PERSON.PERSONPHONE'));

call associate_semantic_category_tags('ADVENTUREWORKS.PERSON.EMAILADDRESS', extract_semantic_categories('ADVENTUREWORKS.PERSON.EMAILADDRESS'));

call associate_semantic_category_tags('ADVENTUREWORKS.PERSON.ADDRESS', extract_semantic_categories('ADVENTUREWORKS.PERSON.ADDRESS'));

call associate_semantic_category_tags('ADVENTUREWORKS.PERSON.PERSON', extract_semantic_categories('ADVENTUREWORKS.PERSON.PERSON'));

call associate_semantic_category_tags('ADVENTUREWORKS.HUMANRESOURCES.EMPLOYEE', extract_semantic_categories('ADVENTUREWORKS.HUMANRESOURCES.EMPLOYEE'));


alter table ADVENTUREWORKS.PERSON.PERSON modify column MIDDLENAME set tag snowflake.core.semantic_category='NAME';
alter table ADVENTUREWORKS.PERSON.PERSON modify column MIDDLENAME set tag snowflake.core.privacy_category='IDENTIFIER';



select * from snowflake.account_usage.tag_references
 where tag_name = 'PRIVACY_CATEGORY'
   and tag_value = 'IDENTIFIER';
   
  

select *
  from table(ADVENTUREWORKS.information_schema.tag_references_all_columns('PERSON.PERSON', 'table'));   
  
select *
  from table(ADVENTUREWORKS.information_schema.tag_references_all_columns('HUMANRESOURCES.EMPLOYEE', 'table'));    
  
  




        
        
select distinct f4.value as column_name, f1.value, QUERY_ID, QUERY_START_TIME
from SNOWFLAKE.ACCOUNT_USAGE.access_history
     , lateral flatten(base_objects_accessed) f1
     , lateral flatten(f1.value) f2
     , lateral flatten(f2.value) f3
     , lateral flatten(f3.value) f4
where f1.value:"objectDomain"::string='Table'
and f4.key='columnName'
and f4.value IN (select COLUMN_NAME from snowflake.account_usage.tag_references
                                   where tag_name = 'SEMANTIC_CATEGORY'
                                     and tag_value = 'DATE_OF_BIRTH');        


 



--03 - Object Dependencies


CREATE OR REPLACE VIEW SALES.TOTAL_PER_CUSTOMER
AS
SELECT p.FIRSTNAME, p.LASTNAME, SUM(sod.linetotal) AS TOTAL
 FROM SALES.SALESORDERHEADER AS soh
 JOIN SALES.SALESORDERDETAIL AS sod ON soh.SALESORDERID = sod.SALESORDERID
 JOIN PERSON.PERSON AS p ON soh.CUSTOMERID = p.BUSINESSENTITYID
GROUP BY p.FIRSTNAME, p.LASTNAME;


CREATE OR REPLACE VIEW SALES.CUSTOMER_NAMES
AS
SELECT p.FIRSTNAME, p.LASTNAME, 
 FROM SALES.TOTAL_PER_CUSTOMER AS p
GROUP BY p.FIRSTNAME, p.LASTNAME;


CREATE OR REPLACE MATERIALIZED VIEW PERSON.EMAILS
AS 
SELECT EMAILADDRESS
  FROM PERSON.EMAILADDRESS;
  
 

----Latency for this view may be up to three hours !!!
select *
from snowflake.account_usage.object_dependencies;



select referencing_object_name, referencing_object_domain, referenced_object_name, referenced_object_domain
  from snowflake.account_usage.object_dependencies
 where referenced_object_name = 'PERSON';




with recursive referenced_cte as (
        select referenced_object_name || '-->' || referencing_object_name as object_name_path,
               referenced_object_name, referenced_object_domain, referencing_object_domain, 
               referencing_object_name, referenced_object_id, referencing_object_id
          from snowflake.account_usage.object_dependencies referencing
         where referenced_object_name = 'PERSON' and referenced_object_domain='TABLE'
         union all
        select object_name_path || '-->' || referencing.referencing_object_name,
               referencing.referenced_object_name, referencing.referenced_object_domain, 
               referencing.referencing_object_domain, referencing.referencing_object_name,
               referencing.referenced_object_id, referencing.referencing_object_id
          from snowflake.account_usage.object_dependencies referencing join referenced_cte
            on referencing.referenced_object_id = referenced_cte.referencing_object_id
           and referencing.referenced_object_domain = referenced_cte.referencing_object_domain
)
select object_name_path, referenced_object_name, referenced_object_domain, referencing_object_name, referencing_object_domain
  from referenced_cte;



with recursive referenced_cte as (
        select referenced_object_name || '-->' || referencing_object_name as object_name_path,
               referenced_object_name, referenced_object_domain, referencing_object_domain, 
               referencing_object_name, referenced_object_id, referencing_object_id
          from snowflake.account_usage.object_dependencies referencing          
         where referenced_object_domain='TABLE'
           and referenced_object_name in (select object_name from snowflake.account_usage.tag_references
                                                            where tag_name = 'PRIVACY_CATEGORY'
                                                              and tag_value = 'IDENTIFIER') 
         union all
        select object_name_path || '-->' || referencing.referencing_object_name,
               referencing.referenced_object_name, referencing.referenced_object_domain, 
               referencing.referencing_object_domain, referencing.referencing_object_name,
               referencing.referenced_object_id, referencing.referencing_object_id
          from snowflake.account_usage.object_dependencies referencing join referenced_cte
            on referencing.referenced_object_id = referenced_cte.referencing_object_id
           and referencing.referenced_object_domain = referenced_cte.referencing_object_domain
)
select object_name_path, referenced_object_name, referenced_object_domain, referencing_object_name, referencing_object_domain
  from referenced_cte;
    
     
    
    
    
    
-- 04 - Snowflake Scripting

----Block
BEGIN

    CREATE OR REPLACE TABLE BKP.BACKUP_CONFIG (
          DATABASE_NAME             STRING NOT NULL
        , DAILY_RETENTION           INT NOT NULL
        , WEEKLY_RETENTION          INT NOT NULL
        , MONTHLY_RETENTION         INT NOT NULL
        , IS_ACTIVE                 BOOLEAN NOT NULL DEFAULT TRUE
        , KEEP_LAST_BACKUP_ON_STAGE BOOLEAN NOT NULL DEFAULT TRUE
        , STAGE_DIR                 STRING NULL
        , FILE_FORMAT               STRING NULL
    );

    INSERT OVERWRITE INTO BKP.BACKUP_CONFIG
    SELECT 'ADVENTUREWORKS', 7, 4, 12, TRUE, TRUE, '@SQLDAY.BKP.BKP_STAGE', 'BKP.CSV_FORMAT';
    
    RETURN 'Completed';

END;






----Variables
DECLARE 
    db_name string := 'ADVENTUREWORKS';
BEGIN

    CREATE OR REPLACE TABLE BKP.BACKUP_CONFIG (
          DATABASE_NAME             STRING NOT NULL
        , DAILY_RETENTION           INT NOT NULL
        , WEEKLY_RETENTION          INT NOT NULL
        , MONTHLY_RETENTION         INT NOT NULL
        , IS_ACTIVE                 BOOLEAN NOT NULL DEFAULT TRUE
        , KEEP_LAST_BACKUP_ON_STAGE BOOLEAN NOT NULL DEFAULT TRUE
        , STAGE_DIR                 STRING NULL
        , FILE_FORMAT               STRING NULL
    );

    INSERT OVERWRITE INTO BKP.BACKUP_CONFIG
    SELECT :db_name, 7, 4, 12, TRUE, TRUE, '@SQLDAY.BKP.BKP_STAGE', 'BKP.CSV_FORMAT';
    
    RETURN 'Completed';

END;




----Returning a Value
DECLARE 
    db_name string := 'ADVENTUREWORKS';
    rs resultset;
BEGIN

    CREATE OR REPLACE TABLE BKP.BACKUP_CONFIG (
          DATABASE_NAME             STRING NOT NULL
        , DAILY_RETENTION           INT NOT NULL
        , WEEKLY_RETENTION          INT NOT NULL
        , MONTHLY_RETENTION         INT NOT NULL
        , IS_ACTIVE                 BOOLEAN NOT NULL DEFAULT TRUE
        , KEEP_LAST_BACKUP_ON_STAGE BOOLEAN NOT NULL DEFAULT TRUE
        , STAGE_DIR                 STRING NULL
        , FILE_FORMAT               STRING NULL
    );

    INSERT OVERWRITE INTO BKP.BACKUP_CONFIG
    SELECT :db_name, 7, 4, 12, TRUE, TRUE, '@SQLDAY.BKP.BKP_STAGE', 'BKP.CSV_FORMAT';
    
    rs := (SELECT * FROM BKP.BACKUP_CONFIG);
    RETURN TABLE(rs);

END;



----SP
CREATE OR REPLACE PROCEDURE BKP.SP_BACKUP_DB(database_name STRING)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
DECLARE 
	sql STRING;
    nl  := CHAR(13) || CHAR(10);
    cd  := CONVERT_TIMEZONE('CET', CURRENT_TIMESTAMP())::DATE;    
    bos BOOLEAN;
    cit := '"' || database_name || '"."INFORMATION_SCHEMA"."TABLES"';
    cic := '"' || database_name || '"."INFORMATION_SCHEMA"."COLUMNS"';
BEGIN      
    SELECT KEEP_LAST_BACKUP_ON_STAGE INTO :bos
      FROM SQLDAY.BKP.BACKUP_CONFIG AS bc
     WHERE bc.DATABASE_NAME = :database_name;
     
     IF (:bos = TRUE) THEN
     BEGIN   
        WITH c AS (
            SELECT DISTINCT 
                   t.TABLE_SCHEMA
                 , t.TABLE_NAME
                 , CONCAT(:nl, ' COPY INTO ', bc.STAGE_DIR, '/', t.TABLE_CATALOG, '/', TO_VARCHAR(:cd, 'YYYYMMDD'), '/', t.TABLE_SCHEMA, '/', t.TABLE_NAME, '/', t.TABLE_SCHEMA, '_', t.TABLE_NAME
                        , :nl, ' FROM "', t.TABLE_CATALOG, '"."', t.TABLE_SCHEMA, '"."', t.TABLE_NAME, '"'
                        , :nl, ' FILE_FORMAT = (FORMAT_NAME = ', bc.FILE_FORMAT, ')'
                        , :nl, ' MAX_FILE_SIZE = 262144000'
                        , :nl, ' OVERWRITE = TRUE'                                 
                        , :nl, ' HEADER = TRUE;') AS l
              FROM IDENTIFIER(:cit) AS t
              JOIN IDENTIFIER(:cic) AS c ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
              JOIN SQLDAY.BKP.BACKUP_CONFIG AS bc ON t.TABLE_CATALOG = bc.DATABASE_NAME
             WHERE t.TABLE_TYPE = 'BASE TABLE'
        )
        SELECT CONCAT('BEGIN', LISTAGG(c.l, :nl), :nl, 'END;') INTO :sql
          FROM c;
     
        EXECUTE IMMEDIATE :sql;                       
        
    END;
    END IF;
     
  RETURN 'Completed';        
END; 



CREATE OR REPLACE PROCEDURE BKP.SP_BACKUP_ALL_DB()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
DECLARE 
	sql STRING;
    res RESULTSET;    
BEGIN
    sql := 'SELECT DATABASE_NAME FROM BKP.BACKUP_CONFIG WHERE IS_ACTIVE = TRUE;';
    
    res := (EXECUTE IMMEDIATE :sql);
        
    DECLARE 
        cur1 CURSOR FOR res;
    BEGIN
        FOR rw IN cur1 DO
            
            sql := 'CALL BKP.SP_BACKUP_DB(''' || rw.DATABASE_NAME || ''');';
            
            res := (EXECUTE IMMEDIATE :sql);

        END FOR;
    END;
    
  RETURN 'Completed';              
END; 



CREATE OR REPLACE PROCEDURE BKP.SP_BACKUP_DB(database_name STRING)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
DECLARE 
	sql STRING;
    nl  := CHAR(13) || CHAR(10);
    cd  := CONVERT_TIMEZONE('CET', CURRENT_TIMESTAMP())::DATE;
    spn := 'SP_BACKUP_DB';
    rtn := ARRAY_CONSTRUCT();
    
    bos BOOLEAN;
    cdb := CURRENT_DATABASE();
    cit := '"' || database_name || '"."INFORMATION_SCHEMA"."TABLES"';
    cic := '"' || database_name || '"."INFORMATION_SCHEMA"."COLUMNS"';
BEGIN      
    SELECT KEEP_LAST_BACKUP_ON_STAGE INTO :bos
      FROM SQLDAY.BKP.BACKUP_CONFIG AS bc
     WHERE bc.DATABASE_NAME = :database_name;
     
     /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Check KEEP_LAST_BACKUP_ON_STAGE', 'KEEP_LAST_BACKUP_ON_STAGE', :bos)) INTO :rtn;
     
     IF (:bos = TRUE) THEN
     BEGIN          
        WITH c AS (
            SELECT DISTINCT 
                   t.TABLE_SCHEMA
                 , t.TABLE_NAME
                 , CONCAT(:nl, ' COPY INTO ', bc.STAGE_DIR, '/', t.TABLE_CATALOG, '/', TO_VARCHAR(:cd, 'YYYYMMDD'), '/', t.TABLE_SCHEMA, '/', t.TABLE_NAME, '/', t.TABLE_SCHEMA, '_', t.TABLE_NAME
                        , :nl, ' FROM "', t.TABLE_CATALOG, '"."', t.TABLE_SCHEMA, '"."', t.TABLE_NAME, '"'
                        , :nl, ' FILE_FORMAT = (FORMAT_NAME = ', bc.FILE_FORMAT, ')'
                        , :nl, ' MAX_FILE_SIZE = 262144000'
                        , :nl, ' OVERWRITE = TRUE'                                 
                        , :nl, ' HEADER = TRUE;') AS l
              FROM IDENTIFIER(:cit) AS t
              JOIN IDENTIFIER(:cic) AS c ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
              JOIN SQLDAY.BKP.BACKUP_CONFIG AS bc ON t.TABLE_CATALOG = bc.DATABASE_NAME
             WHERE t.TABLE_TYPE = 'BASE TABLE'
        )
        SELECT CONCAT('BEGIN', LISTAGG(c.l, :nl), :nl, 'END;') INTO :sql
          FROM c;

        /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'COPY INTO stage', 'Description', '')) INTO :rtn;

        EXECUTE IMMEDIATE :sql;                     
        
    END;
    END IF;
     
  /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Result', 'Description', 'Success')) INTO :rtn;
  RETURN (:rtn);
    
EXCEPTION
    WHEN OTHER THEN 
        /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Result', 'Description', 'Error')) INTO :rtn;
        RETURN ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Exception', 'SQLCODE', sqlcode, 'SQLERRM', sqlerrm, 'SQLSTATE', sqlstate));
        
END; 



CREATE OR REPLACE PROCEDURE BKP.SP_BACKUP_ALL_DB()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
DECLARE 
	sql STRING;
    nl  := CHAR(13) || CHAR(10);
    cd  := CONVERT_TIMEZONE('CET', CURRENT_TIMESTAMP())::DATE;
    spn := 'SP_BACKUP_ALL_DB';
    rtn := ARRAY_CONSTRUCT();
    itn VARIANT;
    res RESULTSET;    
BEGIN
    sql := 'SELECT DATABASE_NAME FROM BKP.BACKUP_CONFIG WHERE IS_ACTIVE = TRUE;';
    
    /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Get DB list', 'Description', :sql)) INTO :rtn;
        
    res := (EXECUTE IMMEDIATE :sql);
        
    DECLARE 
        cur1 CURSOR FOR res;
    BEGIN
        FOR rw IN cur1 DO
            
            sql := 'CALL BKP.SP_BACKUP_DB(''' || rw.DATABASE_NAME || ''');';
            
            /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Call SP', 'Description', :sql)) INTO :rtn;
            
            res := (EXECUTE IMMEDIATE :sql);
            
            DECLARE 
                itn_cur CURSOR FOR res;
            BEGIN
                open itn_cur;
                fetch itn_cur INTO :itn;
                /*LOG*/SELECT ARRAY_PREPEND(:rtn, PARSE_JSON(:itn)) INTO :rtn;
            END;  

        END FOR;
    END;
    
    /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Result', 'Description', 'Success')) INTO :rtn;
    
  RETURN (:rtn);
                
EXCEPTION    
    WHEN OTHER THEN  
        /*LOG*/SELECT ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Result', 'Description', 'Error')) INTO :rtn;
        RETURN ARRAY_PREPEND(:rtn, OBJECT_CONSTRUCT('DateTime', CURRENT_TIMESTAMP(), 'Source', :spn, 'Step', 'Exception', 'SQLCODE', sqlcode, 'SQLERRM', sqlerrm, 'SQLSTATE', sqlstate));                
END; 



--------------------------------------------------------------------------------
CALL BKP.SP_BACKUP_ALL_DB();
--------------------------------------------------------------------------------


LIST @BKP.BKP_STAGE;

ALTER STAGE BKP.BKP_STAGE REFRESH;

SELECT *
  FROM DIRECTORY(@BKP.BKP_STAGE)
 WHERE SIZE > 0;

