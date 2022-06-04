/*******************************************************************************

	Date:					April 2020
	Session:				Automatic Query Tuning
	SQL Server Version:		2017 + 
							Enterprise Edition and Azure SQL Database

	Author:					Torsten Strauss
							https://inside-sqlserver.com 

	This script is intended only as a supplement to demos and lectures
	given by Torsten Strauss.  
  
	THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
	TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

*******************************************************************************/

SET PARSEONLY ON;
GO



/*******************************************************************************

	automatic query tuning

*******************************************************************************/

/*

	Automatic tuning provides insight into potential query performance problems,
	recommend solutions, and automatically fix identified problems in SQL Server
	2017+.

	There are two automatic tuning features that are available:

	*	Automatic plan correction identifies problematic query execution plans
		and fixes query execution plan performance problems.
		SQL Server 2017+

	*	Automatic index management identifies indexes that should be added in
		your database, and indexes that should be removed. 
		SQL Server 2019+
	
*/



/*******************************************************************************

	automatic query tuning - automatic plan correction

*******************************************************************************/

/*

	Automatic plan correction is an automatic tuning feature that identifies 
	execution plans choice regression and automatically fix the issue by 
	forcing the last known good plan.

	Database Engine automatically detects any potential plan choice regression
	including the plan that should be used instead of the wrong plan. 
	When the Database Engine applies the last known good plan, it automatically
	monitors the performance of the forced plan. 
	If the forced plan is not better than the regressed plan, the new plan will 
	be unforced and the Database Engine will compile a new plan. 

	If the Database Engine verifies that the forced plan is better than the 
	regressed plan, the forced plan will be retained if it is better than the 
	regressed plan, until a recompile occurs (for example, on next statistics 
	update or schema change).

*/



/*******************************************************************************

	automatic query tuning - automatic plan correction

*******************************************************************************/

/*
	
	You can enable automatic tuning per database and specify that last good 
	plan should be forced whenever some plan change regression is detected.

*/

-- Enable automatic query tuning
USE AdventureWorks2017;
GO

-- Disable Query Store
ALTER DATABASE CURRENT SET QUERY_STORE = OFF;
GO

-- Ensure the compatability mode is set to 140+ (SQL Server 2017+)
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150;
GO

-- compatibility_level : 150
SELECT
	name, compatibility_level
FROM
	sys.databases
WHERE
	database_id = DB_ID ();
GO

-- To use automatic tuning, the Query store must be enbaled and operational 
-- Msg 15706, Level 16, State 1, Line 97
-- Automatic Tuning option FORCE_LAST_GOOD_PLAN cannot be enabled, 
-- because Query Store is not turned on.
-- Automatic Tuning option FORCE_LAST_GOOD_PLAN cannot be enabled, 
-- because Query Store is in READ_ONLY mode.
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING(FORCE_LAST_GOOD_PLAN = ON);
GO

-- Enable query store
ALTER DATABASE CURRENT SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
GO

-- Enable automatic tuning | Automatic plan correction
-- Database Engine will automatically force any recommendation where the 
-- estimated CPU gain is higher than 10 seconds.
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING(FORCE_LAST_GOOD_PLAN = ON);
GO

-- Get the status of automatic tuning for the current database
SELECT
	name, desired_state_desc, actual_state_desc, reason_desc
FROM
	sys.database_automatic_tuning_options
WHERE
	name = 'FORCE_LAST_GOOD_PLAN';
GO

-- Disable Query Store
ALTER DATABASE CURRENT SET QUERY_STORE = OFF;
GO

-- desired_state_desc : ON
-- actual_state_desc : OFF
-- reason_desc : QUERY_STORE_OFF
/*
	DISABLED = Option is disabled by system
	QUERY_STORE_OFF = Query Store is turned off
	QUERY_STORE_READ_ONLY = Query Store is in read-only mode
	NOT_SUPPORTED = Available only in SQL Server Enterprise edition
*/

SELECT
	name, desired_state_desc, actual_state_desc, reason_desc
FROM
	sys.database_automatic_tuning_options
WHERE
	name = 'FORCE_LAST_GOOD_PLAN';
GO

-- Housekeeping
ALTER DATABASE CURRENT SET QUERY_STORE = OFF;
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING(FORCE_LAST_GOOD_PLAN = OFF);
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150;
GO



/*******************************************************************************

	automatic query tuning - manual plan correction

*******************************************************************************/

/*
	
	You can use sp_query_store_force_plan to force a specific plan if do not 
	rely on automatic plan correction.

	@query_id
	query_id Is the id of the query. 

	@plan_id
	plan_id Is the id of the query plan to be forced.

	EXECUTE sys.sp_query_store_force_plan 
		  [ @query_id = ] query_id 
		, [ @plan_id = ] plan_id;
	GO

*/



/*******************************************************************************

	automatic query tuning -  automatic plan correction
	sys.dm_db_tuning_recommendations

*******************************************************************************/

/*

	Information returned by sys.dm_db_tuning_recommendations is updated when 
	database engine identifies potential query performance regression, but the
	information are not	not persisted which is different to the Query Store.

*/

SELECT * FROM sys.dm_db_tuning_recommendations;
GO

SELECT
	tr.reason
  , tr.score
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_duration - qsrrec.avg_duration) AS estimated_duration_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (regressedPlanCpuTimeAverage - recommendedPlanCpuTimeAverage) / 1000000 AS estimated_cpu_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_logical_io_reads - qsrrec.avg_logical_io_reads) AS estimated_logical_io_gain
  , IIF(regressedPlanErrorCount > recommendedPlanErrorCount, 'YES', 'NO') AS error_prone
  , tr.valid_since AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS valid_since
  , JSON_VALUE (tr.state, '$.reason') AS current_state_reason
  , JSON_VALUE (tr.details, '$.implementationDetails.script') AS sql_text
  , planForceDetails.query_id
  , planForceDetails.regressedPlanId AS regressed_plan_id
  , planForceDetails.regressedPlanCpuTimeAverage AS regressed_plan_cpu_time_average
  , planForceDetails.regressedPlanExecutionCount AS regressed_plan_execution_count
  , qsrreg.avg_duration AS regressed_plan_avg_duration
  , qsrreg.avg_cpu_time AS regressed_plan_avg_cpu_time
  , qsrreg.avg_logical_io_reads AS regressed_plan_avg_logical_io_reads
  , qsrreg.avg_query_max_used_memory AS regressed_plan_avg_query_max_used_memory
  , qsrreg.avg_rowcount AS regressed_plan_avg_rowcount
  , planForceDetails.recommendedPlanId AS recommended_plan_id
  , planForceDetails.recommendedPlanCpuTimeAverage AS recommended_plan_cpu_time_average
  , planForceDetails.recommendedPlanExecutionCount AS recommended_plan_execution_count
  , qsrrec.avg_duration AS recommended_plan_avg_duration
  , qsrrec.avg_cpu_time AS recommended_plan_avg_cpu_time
  , qsrrec.avg_logical_io_reads AS recommended_plan_avg_logical_io_reads
  , qsrrec.avg_query_max_used_memory AS recommended_plan_avg_query_max_used_memory
  , qsrrec.avg_rowcount AS recommended_plan_avg_rowcount
FROM
	sys.dm_db_tuning_recommendations AS tr
CROSS APPLY
	OPENJSON (details, '$.planForceDetails')
	WITH
		(
			query_id int '$.queryId'
		  , regressedPlanId int '$.regressedPlanId'
		  , recommendedPlanId int '$.recommendedPlanId'
		  , regressedPlanErrorCount int
		  , recommendedPlanErrorCount int
		  , regressedPlanExecutionCount int
		  , regressedPlanCpuTimeAverage float
		  , recommendedPlanExecutionCount int
		  , recommendedPlanCpuTimeAverage float
		) AS planForceDetails
INNER JOIN
	sys.query_store_plan AS qspreg
ON
	qspreg.plan_id = planForceDetails.regressedPlanId
	AND qspreg.query_id = planForceDetails.query_id
INNER JOIN
	sys.query_store_plan AS qsprec
ON
	qsprec.plan_id = planForceDetails.recommendedPlanId
	AND qsprec.query_id = planForceDetails.query_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrreg
ON
	planForceDetails.regressedPlanId = qsrreg.plan_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrrec
ON
	planForceDetails.recommendedPlanId = qsrrec.plan_id;
GO



/*******************************************************************************

	automatic query tuning -  automatic plan correction - preparation

*******************************************************************************/

USE AdventureWorks2017;
GO

-- Create a table 
DROP TABLE IF EXISTS Sales.SalesOrderDetailSmall;
GO

CREATE TABLE Sales.SalesOrderDetailSmall
(
	SalesOrderID int NOT NULL
  , SalesOrderDetailID int NOT NULL
  , CarrierTrackingNumber nvarchar(25) NULL
  , OrderQty smallint NOT NULL
  , ProductID int NOT NULL
  , UnitPrice money NOT NULL
);
GO

-- Insert 500.010 records
INSERT Sales.SalesOrderDetailSmall
	(
		SalesOrderID
	  , SalesOrderDetailID
	  , CarrierTrackingNumber
	  , OrderQty
	  , ProductID
	  , UnitPrice
	)
SELECT TOP 500000
	*
FROM
	Sales.SalesOrderDetailBig
WHERE
	SalesOrderID = 43659
UNION ALL
SELECT TOP 10
	*
FROM
	Sales.SalesOrderDetailBig
WHERE
	SalesOrderID = 43660;
GO

-- Create a non clustered index on SalesOrderID
CREATE INDEX NCL_SalesOrderDetailSmall_SalesOrderID
ON Sales.SalesOrderDetailSmall (SalesOrderID);
GO

-- Get the distribution
-- SalesOrderID : 43659 returns 500000 rows
-- SalesOrderID : 43660 returns 10 rows
SELECT
	SalesOrderID, COUNT (*) AS number_of_rows
FROM
	Sales.SalesOrderDetailSmall
GROUP BY
	SalesOrderID;
GO

-- Create a procedure which returns all rows for a given SalesOrderID
DROP PROCEDURE IF EXISTS regression;
GO

CREATE PROCEDURE regression
(@SalesOrderID int)
AS
	BEGIN
		SELECT *
		FROM
			Sales.SalesOrderDetailSmall
		WHERE
			SalesOrderID = @SalesOrderID;
	END;
GO

-- Create an XEvent to capture automatic_tuning events
-- Event : qds.automatic_tuning_plan_regression_detection_check_completed
IF EXISTS
	(
		SELECT *
		FROM
			sys.server_event_sessions
		WHERE
			name = 'automatic_tuning'
	)
	DROP EVENT SESSION automatic_tuning ON SERVER;
GO

CREATE EVENT SESSION automatic_tuning
ON SERVER
	ADD EVENT qds.automatic_tuning_error
		(ACTION
			 (
				 sqlserver.sql_text
			 )
		)
  , ADD EVENT qds.automatic_tuning_plan_regression_detection_check_completed
		(ACTION
			 (
				 sqlserver.sql_text
			 )
		)
  , ADD EVENT qds.automatic_tuning_recommendation_expired
		(ACTION
			 (
				 sqlserver.sql_text
			 )
		)
  , ADD EVENT sqlserver.automatic_tuning_advisor_settings_invalid
		(ACTION
			 (
				 sqlserver.sql_text
			 )
		)
	ADD TARGET package0.event_file
		(SET filename = N'automatic_tuning')
  , ADD TARGET package0.ring_buffer
		(SET max_memory = (32768))
WITH
	(
		MAX_MEMORY = 192KB
	  , EVENT_RETENTION_MODE = NO_EVENT_LOSS
	  , MAX_DISPATCH_LATENCY = 1 SECONDS
	  , MAX_EVENT_SIZE = 0KB
	  , MEMORY_PARTITION_MODE = NONE
	  , TRACK_CAUSALITY = OFF
	  , STARTUP_STATE = OFF
	);
GO

-- Start the XEvent
ALTER EVENT SESSION automatic_tuning ON SERVER STATE = START;
GO

-- Lightweight profiling is enabled by default on SQL Server 2019 (15.x) 
-- and Azure SQL Database, otherwise enable trace flag 7412.
SELECT *
FROM
	sys.database_scoped_configurations
WHERE
	name = 'LIGHTWEIGHT_QUERY_PROFILING';
GO

-- The last query plan statistics can be enabled at the database level using 
-- the LAST_QUERY_PLAN_STATS database scoped configuration
--ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON;
--GO



/*******************************************************************************

	automatic query tuning - manual plan correction
	
*******************************************************************************/

/*

	The example shows a plan regression for a selective parameter value 
	executed in a table scan.

*/

USE AdventureWorks2017;
GO

ALTER DATABASE CURRENT SET AUTOMATIC_TUNING(FORCE_LAST_GOOD_PLAN = OFF);
GO

SET STATISTICS IO, TIME ON;
GO

-- Enable query store
ALTER DATABASE CURRENT SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
GO

-- Clear the query store
ALTER DATABASE CURRENT
SET QUERY_STORE CLEAR ALL;
GO

-- Flush the procedure cache;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- Execute the procedure with the selective value
-- RID Lookup
-- Costs : 0,0330161
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 13
EXECUTE regression @SalesOrderID = 43660;
GO

SELECT
	st.text, qps.query_plan
FROM
	sys.dm_exec_cached_plans AS cp
INNER JOIN
	sys.dm_exec_query_stats AS qs
ON
	cp.plan_handle = qs.plan_handle
CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st
CROSS APPLY sys.dm_exec_query_plan_stats (cp.plan_handle) AS qps
WHERE
	qs.query_plan_hash = 0x779199ED19636BC5;
GO

-- query_id = 3
-- plan_id : 3
-- avg_cpu_time : 0,27
-- total_cpu_time : 4,36
-- execution_count : 16

-- Clear the procedure cache for the current database
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- Enable Include Actual Execution Plan
-- Execute the procedure with the non selective value
-- Tipping Point (1/3 to 1/4 of the total number of pages)
-- Table Scan
-- Costs : 3,25626
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 3650
EXECUTE regression @SalesOrderID = 43659;
GO

-- Two plans for query_id : 3
-- plan_id : 3
-- avg_cpu_time : 0,27
-- total_cpu_time : 4,36
-- stdev_cpu_time : 0,06
-- execution_count : 16
-- plan_id : 8
-- avg_cpu_time : 806,73
-- total_cpu_time : 806,73
-- stdev_cpu_time : 0
-- execution_count : 1

-- Only the plan for the non selctive values is in the procedure cache
DECLARE @query_hash varbinary(8) = 0xDF0C98BB4FE6C7A8;
SELECT
	sql_handle
  , plan_generation_num
  , plan_handle
  , query_hash
  , query_plan_hash
  , text
  , etqp.dbid
  , etqp.objectid
  , TRY_CAST(query_plan AS xml) AS query_plan
FROM
	sys.dm_exec_query_stats AS eqs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text (eqs.sql_handle) AS est
CROSS APPLY sys.dm_exec_text_query_plan (
											eqs.plan_handle
										  , eqs.statement_start_offset
										  , eqs.statement_end_offset
										) AS etqp
WHERE
	query_hash = @query_hash;
GO

-- Execute the procedure with the selective value
-- SQL Server optimizer will use the plan in cache which was compiled for the
-- non selective value 43659
-- Table Scan (RID Lookup)
-- Costs : 3,25626 (0,03301)
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 3650
-- (Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 13)
EXECUTE regression @SalesOrderID = 43660;
GO

-- Two plans for query_id : 3
-- plan regression
-- avg_cpu_time : 0,27 < 142,33
-- plan_id : 3
-- avg_cpu_time : 0,27
-- total_cpu_time : 4,36
-- stdev_cpu_time : 0,06
-- execution_count : 16
-- plan_id : 8
-- avg_cpu_time : 142,33
-- total_cpu_time : 2419,59
-- stdev_cpu_time : 168,58
-- execution_count : 17

-- XEvent
-- automatic_tuning_plan_regression_detection_check_completed
/*
	query_id							3
	current_plan_id						8
	current_plan_cpu_time_average		147196 | 147.2ms
	current_plan_cpu_time_stddev		178902.0000
	current_plan_execution_count		15
	last_good_plan_id					3
	last_good_plan_cpu_time_average		245.2500 | 025ms
	last_good_plan_cpu_time_stddev		100.8210
	last_good_plan_execution_count		16
	estimated_cpu_time_gain				4555450
	is_regression_detected				1

*/
DECLARE @query_id int = 3;
WITH
	XEvents AS
		(
			SELECT
				object_name, CAST(event_data AS xml) AS event_data
			FROM
				sys.fn_xe_file_target_read_file (
													'automatic_tuning*.xel'
												  , NULL, NULL, NULL
												)
		)
SELECT
	event_data.value ('(event/@name)[1]', 'varchar(150)') AS event_name
  , DATEADD (
				hh, DATEDIFF (hh, GETUTCDATE (), CURRENT_TIMESTAMP)
			  , event_data.value ('(event/@timestamp)[1]', 'datetime2')
			) AS timestamp
  , event_data.value (
						 '(/event/data[@name=''current_plan_cpu_time_average'']/value)[1]'
					   , 'NVARCHAR(MAX)'
					 ) AS current_plan_cpu_time_average
  , event_data.value (
						 '(/event/data[@name=''current_plan_cpu_time_stddev'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS current_plan_cpu_time_stddev
  , event_data.value (
						 '(/event/data[@name=''current_plan_error_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_error_count
  , event_data.value (
						 '(/event/data[@name=''current_plan_execution_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_execution_count
  , event_data.value (
						 '(/event/data[@name=''current_plan_id'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_id
  , event_data.value ('(/event/data[@name=''database_id'']/value)[1]', 'BIGINT') AS database_id
  , event_data.value (
						 '(/event/data[@name=''detection_end_time_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS detection_end_time_date
  , event_data.value (
						 '(/event/data[@name=''detection_end_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS detection_end_time_ms
  , event_data.value (
						 '(/event/data[@name=''detection_start_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS detection_start_date
  , event_data.value (
						 '(/event/data[@name=''detection_start_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS detection_start_time_ms
  , event_data.value (
						 '(/event/data[@name=''estimated_cpu_time_gain'']/value)[1]'
					   , 'BIGINT'
					 ) AS estimated_cpu_time_gain
  , event_data.value (
						 '(/event/data[@name=''internal_status_code'']/value)[1]'
					   , 'BIGINT'
					 ) AS internal_status_code
  , event_data.value ('(/event/data[@name=''is_error_prone'']/value)[1]', 'BIT') AS is_error_prone
  , event_data.value (
						 '(/event/data[@name=''is_regression_corrected'']/value)[1]'
					   , 'BIT'
					 ) AS is_regression_corrected
  , event_data.value (
						 '(/event/data[@name=''is_regression_detected'']/value)[1]'
					   , 'BIT'
					 ) AS is_regression_detected
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_cpu_time_average'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS last_good_plan_cpu_time_average
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_cpu_time_stddev'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS last_good_plan_cpu_time_stddev
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_error_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_error_count
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_execution_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_execution_count
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_id'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_id
  , event_data.value ('(/event/data[@name=''option_id'']/value)[1]', 'SMALLINT') AS option_id
  , event_data.value (
						 '(/event/data[@name=''plan_comparison_process_start_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS plan_comparison_process_start_date
  , event_data.value (
						 '(/event/data[@name=''plan_comparison_process_start_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS plan_comparison_process_start_time_ms
  , event_data.value ('(/event/data[@name=''query_id'']/value)[1]', 'BIGINT') AS query_id
  , event_data.value (
						 '(/event/action[@name=''sql_text'']/value)[1]'
					   , 'NVARCHAR(MAX)'
					 ) AS sql_text
  , event_data.value (
						 '(/event/data[@name=''submitted_with_priority'']/value)[1]'
					   , 'BIT'
					 ) AS submitted_with_priority
FROM
	XEvents
WHERE
	event_data.value ('(/event/data[@name=''query_id'']/value)[1]', 'BIGINT') = @query_id
ORDER BY
	timestamp DESC;
GO

-- Get the tuning recommendations
-- The recommendation only takes CPU savings into account.
-- The query would benefit from a RID Lookup due to the selective value.
/*

	score
	Estimated value/impact for this recommendation on the 0-100 scale - the larger the 
	better.

	reason					
	Average query CPU time changed from 0.25ms to 147.2ms
	
	sql_text
	exec sp_query_store_force_plan @query_id = 3, @plan_id = 3
	
	score									27
	query_id								3
	regressed_plan_id						8
	recommended_plan_id						3

	regressed_plan_execution_count			15
	regressed_plan_cpu_time_average			147195
	regressed_plan_avg_duration				1194646
	regressed_plan_avg_logical_io_reads		4450
	regressed_plan_avg_rowcount				29421

	recommended_plan_execution_count		16
	recommended_plan_cpu_time_average		245
	recommended_plan_avg_duration			9783
	recommended_plan_avg_logical_io_reads	13
	recommended_plan_avg_rowcount			10

	estimated_gain							4,55
	error_prone								NO

*/
SELECT
	tr.reason
  , tr.score
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_duration - qsrrec.avg_duration) AS estimated_duration_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (regressedPlanCpuTimeAverage - recommendedPlanCpuTimeAverage) / 1000000 AS estimated_cpu_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_logical_io_reads - qsrrec.avg_logical_io_reads) AS estimated_logical_io_gain
  , IIF(regressedPlanErrorCount > recommendedPlanErrorCount, 'YES', 'NO') AS error_prone
  , tr.valid_since AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS valid_since
  , JSON_VALUE (tr.state, '$.reason') AS current_state_reason
  , JSON_VALUE (tr.details, '$.implementationDetails.script') AS sql_text
  , planForceDetails.query_id
  , planForceDetails.regressedPlanId AS regressed_plan_id
  , planForceDetails.regressedPlanCpuTimeAverage AS regressed_plan_cpu_time_average
  , planForceDetails.regressedPlanExecutionCount AS regressed_plan_execution_count
  , qsrreg.avg_duration AS regressed_plan_avg_duration
  , qsrreg.avg_cpu_time AS regressed_plan_avg_cpu_time
  , qsrreg.avg_logical_io_reads AS regressed_plan_avg_logical_io_reads
  , qsrreg.avg_query_max_used_memory AS regressed_plan_avg_query_max_used_memory
  , qsrreg.avg_rowcount AS regressed_plan_avg_rowcount
  , planForceDetails.recommendedPlanId AS recommended_plan_id
  , planForceDetails.recommendedPlanCpuTimeAverage AS recommended_plan_cpu_time_average
  , planForceDetails.recommendedPlanExecutionCount AS recommended_plan_execution_count
  , qsrrec.avg_duration AS recommended_plan_avg_duration
  , qsrrec.avg_cpu_time AS recommended_plan_avg_cpu_time
  , qsrrec.avg_logical_io_reads AS recommended_plan_avg_logical_io_reads
  , qsrrec.avg_query_max_used_memory AS recommended_plan_avg_query_max_used_memory
  , qsrrec.avg_rowcount AS recommended_plan_avg_rowcount
FROM
	sys.dm_db_tuning_recommendations AS tr
CROSS APPLY
	OPENJSON (details, '$.planForceDetails')
	WITH
		(
			query_id int '$.queryId'
		  , regressedPlanId int '$.regressedPlanId'
		  , recommendedPlanId int '$.recommendedPlanId'
		  , regressedPlanErrorCount int
		  , recommendedPlanErrorCount int
		  , regressedPlanExecutionCount int
		  , regressedPlanCpuTimeAverage float
		  , recommendedPlanExecutionCount int
		  , recommendedPlanCpuTimeAverage float
		) AS planForceDetails
INNER JOIN
	sys.query_store_plan AS qspreg
ON
	qspreg.plan_id = planForceDetails.regressedPlanId
	AND qspreg.query_id = planForceDetails.query_id
INNER JOIN
	sys.query_store_plan AS qsprec
ON
	qsprec.plan_id = planForceDetails.recommendedPlanId
	AND qsprec.query_id = planForceDetails.query_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrreg
ON
	planForceDetails.regressedPlanId = qsrreg.plan_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrrec
ON
	planForceDetails.recommendedPlanId = qsrrec.plan_id;
GO

-- Force the recommended execution plan. (RID Lookup)
-- The recommended plan is optimzed for the selective value.
EXEC sp_query_store_force_plan @query_id = 3, @plan_id = 3;
GO

-- Get queries with a forces plan
-- query_plan_hash : 0x779199ED19636BC5 
-- RID lookup is forced
SELECT
	p.query_id
  , qt.query_sql_text
  , q.object_id
  , ISNULL (OBJECT_NAME (q.object_id), '') AS object_name
  , p.plan_id
  , p.query_plan_hash
  , TRY_CAST(p.query_plan AS xml) AS query_plan
  , p.plan_forcing_type_desc
  , p.force_failure_count
  , p.last_force_failure_reason_desc
  , p.last_execution_time
  , p.last_compile_start_time
FROM
	sys.query_store_plan AS p
INNER JOIN
	sys.query_store_query AS q
ON
	q.query_id = p.query_id
INNER JOIN
	sys.query_store_query_text AS qt
ON
	q.query_text_id = qt.query_text_id
WHERE
	p.is_forced_plan = 1;
GO

-- Open Regresses Queries Report
-- Change to average logical reads in the last hour

-- Open Queries With Forced Plans
-- Change to average logical reads in the last hour

-- Execute the procedure with the selective value
-- Since the query plan with the RID lookup is forced, the stored procedure will
-- always use the same plan.
-- The costs and IOs are reduced when executing the procedure with the 
-- selective value comparing to plan with the table scan.
-- RID Lookup (Table Scan)
-- Costs : 0,03301 (3,25626)
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 13
-- (Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 3650)
EXECUTE regression @SalesOrderID = 43660;
GO

-- Execute the procedure with the non selective value
-- Since the query plan with the RID lookup is forced, the stored procedure will
-- always use the same plan.
-- The costs and IOs are much higher when executing the procedure with the 
-- non selective value comparing to plan with the table scan.
-- This is again a plan regression caused by the plan recommendation.
-- RID Lookup (Table Scan)
-- Costs : 0,03301 (3,25626)
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 501119
-- CPU time = 1719 ms,  elapsed time = 7108 ms.
EXECUTE regression @SalesOrderID = 43659;
GO

-- Open Tracked Queries and search for query id 3
-- Use CPU AVG as the metric

-- Two plans for query_id : 3
-- plan_id : 3
-- avg_cpu_time : 1059,67
-- total_cpu_time : 34969,03
-- stdev_cpu_time : 457,12
-- plan_id : 8
-- avg_cpu_time : 142,33
-- total_cpu_time : 2419,59
-- stdev_cpu_time : 168,58

-- XEvent
-- The regression is not detected
DECLARE @query_id int = 3;
WITH
	XEvents AS
		(
			SELECT
				object_name, CAST(event_data AS xml) AS event_data
			FROM
				sys.fn_xe_file_target_read_file (
													'automatic_tuning*.xel'
												  , NULL, NULL, NULL
												)
		)
SELECT
	event_data.value ('(event/@name)[1]', 'varchar(150)') AS event_name
  , DATEADD (
				hh, DATEDIFF (hh, GETUTCDATE (), CURRENT_TIMESTAMP)
			  , event_data.value ('(event/@timestamp)[1]', 'datetime2')
			) AS timestamp
  , event_data.value (
						 '(/event/data[@name=''current_plan_cpu_time_average'']/value)[1]'
					   , 'NVARCHAR(MAX)'
					 ) AS current_plan_cpu_time_average
  , event_data.value (
						 '(/event/data[@name=''current_plan_cpu_time_stddev'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS current_plan_cpu_time_stddev
  , event_data.value (
						 '(/event/data[@name=''current_plan_error_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_error_count
  , event_data.value (
						 '(/event/data[@name=''current_plan_execution_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_execution_count
  , event_data.value (
						 '(/event/data[@name=''current_plan_id'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_id
  , event_data.value ('(/event/data[@name=''database_id'']/value)[1]', 'BIGINT') AS database_id
  , event_data.value (
						 '(/event/data[@name=''detection_end_time_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS detection_end_time_date
  , event_data.value (
						 '(/event/data[@name=''detection_end_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS detection_end_time_ms
  , event_data.value (
						 '(/event/data[@name=''detection_start_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS detection_start_date
  , event_data.value (
						 '(/event/data[@name=''detection_start_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS detection_start_time_ms
  , event_data.value (
						 '(/event/data[@name=''estimated_cpu_time_gain'']/value)[1]'
					   , 'BIGINT'
					 ) AS estimated_cpu_time_gain
  , event_data.value (
						 '(/event/data[@name=''internal_status_code'']/value)[1]'
					   , 'BIGINT'
					 ) AS internal_status_code
  , event_data.value ('(/event/data[@name=''is_error_prone'']/value)[1]', 'BIT') AS is_error_prone
  , event_data.value (
						 '(/event/data[@name=''is_regression_corrected'']/value)[1]'
					   , 'BIT'
					 ) AS is_regression_corrected
  , event_data.value (
						 '(/event/data[@name=''is_regression_detected'']/value)[1]'
					   , 'BIT'
					 ) AS is_regression_detected
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_cpu_time_average'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS last_good_plan_cpu_time_average
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_cpu_time_stddev'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS last_good_plan_cpu_time_stddev
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_error_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_error_count
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_execution_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_execution_count
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_id'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_id
  , event_data.value ('(/event/data[@name=''option_id'']/value)[1]', 'SMALLINT') AS option_id
  , event_data.value (
						 '(/event/data[@name=''plan_comparison_process_start_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS plan_comparison_process_start_date
  , event_data.value (
						 '(/event/data[@name=''plan_comparison_process_start_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS plan_comparison_process_start_time_ms
  , event_data.value ('(/event/data[@name=''query_id'']/value)[1]', 'BIGINT') AS query_id
  , event_data.value (
						 '(/event/action[@name=''sql_text'']/value)[1]'
					   , 'NVARCHAR(MAX)'
					 ) AS sql_text
  , event_data.value (
						 '(/event/data[@name=''submitted_with_priority'']/value)[1]'
					   , 'BIT'
					 ) AS submitted_with_priority
FROM
	XEvents
WHERE
	event_data.value ('(/event/data[@name=''query_id'']/value)[1]', 'BIGINT') = @query_id
ORDER BY
	timestamp DESC;
GO

-- Get the tuning recommendations
-- No regression is detected
-- The old recommendation is still shown, despite the plan is forced already but current_state_reason
-- changed to PlanForcedByUser
-- current_state_reason : PlanForcedByUser
SELECT
	tr.reason
  , tr.score
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_duration - qsrrec.avg_duration) AS estimated_duration_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (regressedPlanCpuTimeAverage - recommendedPlanCpuTimeAverage) / 1000000 AS estimated_cpu_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_logical_io_reads - qsrrec.avg_logical_io_reads) AS estimated_logical_io_gain
  , IIF(regressedPlanErrorCount > recommendedPlanErrorCount, 'YES', 'NO') AS error_prone
  , tr.valid_since AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS valid_since
  , JSON_VALUE (tr.state, '$.reason') AS current_state_reason
  , JSON_VALUE (tr.details, '$.implementationDetails.script') AS sql_text
  , planForceDetails.query_id
  , planForceDetails.regressedPlanId AS regressed_plan_id
  , planForceDetails.regressedPlanCpuTimeAverage AS regressed_plan_cpu_time_average
  , planForceDetails.regressedPlanExecutionCount AS regressed_plan_execution_count
  , qsrreg.avg_duration AS regressed_plan_avg_duration
  , qsrreg.avg_cpu_time AS regressed_plan_avg_cpu_time
  , qsrreg.avg_logical_io_reads AS regressed_plan_avg_logical_io_reads
  , qsrreg.avg_query_max_used_memory AS regressed_plan_avg_query_max_used_memory
  , qsrreg.avg_rowcount AS regressed_plan_avg_rowcount
  , planForceDetails.recommendedPlanId AS recommended_plan_id
  , planForceDetails.recommendedPlanCpuTimeAverage AS recommended_plan_cpu_time_average
  , planForceDetails.recommendedPlanExecutionCount AS recommended_plan_execution_count
  , qsrrec.avg_duration AS recommended_plan_avg_duration
  , qsrrec.avg_cpu_time AS recommended_plan_avg_cpu_time
  , qsrrec.avg_logical_io_reads AS recommended_plan_avg_logical_io_reads
  , qsrrec.avg_query_max_used_memory AS recommended_plan_avg_query_max_used_memory
  , qsrrec.avg_rowcount AS recommended_plan_avg_rowcount
FROM
	sys.dm_db_tuning_recommendations AS tr
CROSS APPLY
	OPENJSON (details, '$.planForceDetails')
	WITH
		(
			query_id int '$.queryId'
		  , regressedPlanId int '$.regressedPlanId'
		  , recommendedPlanId int '$.recommendedPlanId'
		  , regressedPlanErrorCount int
		  , recommendedPlanErrorCount int
		  , regressedPlanExecutionCount int
		  , regressedPlanCpuTimeAverage float
		  , recommendedPlanExecutionCount int
		  , recommendedPlanCpuTimeAverage float
		) AS planForceDetails
INNER JOIN
	sys.query_store_plan AS qspreg
ON
	qspreg.plan_id = planForceDetails.regressedPlanId
	AND qspreg.query_id = planForceDetails.query_id
INNER JOIN
	sys.query_store_plan AS qsprec
ON
	qsprec.plan_id = planForceDetails.recommendedPlanId
	AND qsprec.query_id = planForceDetails.query_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrreg
ON
	planForceDetails.regressedPlanId = qsrreg.plan_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrrec
ON
	planForceDetails.recommendedPlanId = qsrrec.plan_id;
GO

-- Create a supportive clustered index
CREATE CLUSTERED INDEX CL_SalesOrderDetailSmall_SalesOrderID
ON Sales.SalesOrderDetailSmall (SalesOrderID);
GO

-- Execute the procedure with the selective value
-- The forced plan ignores the better plan!
-- Key Lookup (RID Lookup)
-- Costs : 0,0330129 (0,03301)
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 33
-- (Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 13)
EXECUTE regression @SalesOrderID = 43660;
GO

-- Adhoc query with the selective value
-- Clustered Index Seek (Key Lookup)
-- Costs : 0,003293 (0,0330129)
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 3
-- (Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 13)
SELECT *
FROM
	Sales.SalesOrderDetailSmall
WHERE
	SalesOrderID = 43660;
GO

-- Execute the procedure with the non selective value
-- Again, the forced plan is used an the index seek is not considered!
-- Key Lookup (RID Lookup)
-- Costs : 0,0330129 (0,03301)
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 1501119
-- (Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 501119)
EXECUTE regression @SalesOrderID = 43659;
GO

-- Adhoc query with the selective value
-- Clustered Index Seek (Key Lookup)
-- Costs : 0,003293 (0,0330129)
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 4046
-- (Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 13)
SELECT *
FROM
	Sales.SalesOrderDetailSmall
WHERE
	SalesOrderID = 43659;
GO

-- XEvent
-- automatic_tuning_recommendation_expired (not always!)
-- Tuning recommendation is expired but the plan is still forced!
DECLARE @query_id int = 3;
WITH
	XEvents AS
		(
			SELECT
				object_name, CAST(event_data AS xml) AS event_data
			FROM
				sys.fn_xe_file_target_read_file (
													'automatic_tuning*.xel'
												  , NULL, NULL, NULL
												)
		)
SELECT
	event_data.value ('(event/@name)[1]', 'varchar(150)') AS event_name
  , DATEADD (
				hh, DATEDIFF (hh, GETUTCDATE (), CURRENT_TIMESTAMP)
			  , event_data.value ('(event/@timestamp)[1]', 'datetime2')
			) AS timestamp
  , event_data.value (
						 '(/event/data[@name=''current_plan_cpu_time_average'']/value)[1]'
					   , 'NVARCHAR(MAX)'
					 ) AS current_plan_cpu_time_average
  , event_data.value (
						 '(/event/data[@name=''current_plan_cpu_time_stddev'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS current_plan_cpu_time_stddev
  , event_data.value (
						 '(/event/data[@name=''current_plan_error_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_error_count
  , event_data.value (
						 '(/event/data[@name=''current_plan_execution_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_execution_count
  , event_data.value (
						 '(/event/data[@name=''current_plan_id'']/value)[1]'
					   , 'BIGINT'
					 ) AS current_plan_id
  , event_data.value ('(/event/data[@name=''database_id'']/value)[1]', 'BIGINT') AS database_id
  , event_data.value (
						 '(/event/data[@name=''detection_end_time_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS detection_end_time_date
  , event_data.value (
						 '(/event/data[@name=''detection_end_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS detection_end_time_ms
  , event_data.value (
						 '(/event/data[@name=''detection_start_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS detection_start_date
  , event_data.value (
						 '(/event/data[@name=''detection_start_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS detection_start_time_ms
  , event_data.value (
						 '(/event/data[@name=''estimated_cpu_time_gain'']/value)[1]'
					   , 'BIGINT'
					 ) AS estimated_cpu_time_gain
  , event_data.value (
						 '(/event/data[@name=''internal_status_code'']/value)[1]'
					   , 'BIGINT'
					 ) AS internal_status_code
  , event_data.value ('(/event/data[@name=''is_error_prone'']/value)[1]', 'BIT') AS is_error_prone
  , event_data.value (
						 '(/event/data[@name=''is_regression_corrected'']/value)[1]'
					   , 'BIT'
					 ) AS is_regression_corrected
  , event_data.value (
						 '(/event/data[@name=''is_regression_detected'']/value)[1]'
					   , 'BIT'
					 ) AS is_regression_detected
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_cpu_time_average'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS last_good_plan_cpu_time_average
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_cpu_time_stddev'']/value)[1]'
					   , 'NUMERIC(30, 4)'
					 ) AS last_good_plan_cpu_time_stddev
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_error_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_error_count
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_execution_count'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_execution_count
  , event_data.value (
						 '(/event/data[@name=''last_good_plan_id'']/value)[1]'
					   , 'BIGINT'
					 ) AS last_good_plan_id
  , event_data.value ('(/event/data[@name=''option_id'']/value)[1]', 'SMALLINT') AS option_id
  , event_data.value (
						 '(/event/data[@name=''plan_comparison_process_start_date'']/value)[1]'
					   , 'BIGINT'
					 ) AS plan_comparison_process_start_date
  , event_data.value (
						 '(/event/data[@name=''plan_comparison_process_start_time_ms'']/value)[1]'
					   , 'DECIMAL(20,0)'
					 ) AS plan_comparison_process_start_time_ms
  , event_data.value ('(/event/data[@name=''query_id'']/value)[1]', 'BIGINT') AS query_id
  , event_data.value (
						 '(/event/action[@name=''sql_text'']/value)[1]'
					   , 'NVARCHAR(MAX)'
					 ) AS sql_text
  , event_data.value (
						 '(/event/data[@name=''submitted_with_priority'']/value)[1]'
					   , 'BIT'
					 ) AS submitted_with_priority
FROM
	XEvents
WHERE
	event_data.value ('(/event/data[@name=''query_id'']/value)[1]', 'BIGINT') = @query_id
ORDER BY
	timestamp DESC;
GO

-- Get the tuning recommendations
-- No regression is detected
-- The old recommendation is still shown, despite the plan is forced already
-- current_state_reason : SchemaChanged (not always!)
SELECT
	tr.reason
  , tr.score
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_duration - qsrrec.avg_duration) AS estimated_duration_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (regressedPlanCpuTimeAverage - recommendedPlanCpuTimeAverage) / 1000000 AS estimated_cpu_gain
  , (regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (qsrreg.avg_logical_io_reads - qsrrec.avg_logical_io_reads) AS estimated_logical_io_gain
  , IIF(regressedPlanErrorCount > recommendedPlanErrorCount, 'YES', 'NO') AS error_prone
  , tr.valid_since AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS valid_since
  , JSON_VALUE (tr.state, '$.reason') AS current_state_reason
  , JSON_VALUE (tr.details, '$.implementationDetails.script') AS sql_text
  , planForceDetails.query_id
  , planForceDetails.regressedPlanId AS regressed_plan_id
  , planForceDetails.regressedPlanCpuTimeAverage AS regressed_plan_cpu_time_average
  , planForceDetails.regressedPlanExecutionCount AS regressed_plan_execution_count
  , planForceDetails.regressedPlanErrorCount
  , planForceDetails.recommendedPlanErrorCount
  , planForceDetails.regressedPlanAbortedCount
  , planForceDetails.recommendedPlanAbortedCount
  , qsrreg.avg_duration AS regressed_plan_avg_duration
  , qsrreg.avg_cpu_time AS regressed_plan_avg_cpu_time
  , qsrreg.avg_logical_io_reads AS regressed_plan_avg_logical_io_reads
  , qsrreg.avg_query_max_used_memory AS regressed_plan_avg_query_max_used_memory
  , qsrreg.avg_rowcount AS regressed_plan_avg_rowcount
  , planForceDetails.recommendedPlanId AS recommended_plan_id
  , planForceDetails.recommendedPlanCpuTimeAverage AS recommended_plan_cpu_time_average
  , planForceDetails.recommendedPlanExecutionCount AS recommended_plan_execution_count
  , qsrrec.avg_duration AS recommended_plan_avg_duration
  , qsrrec.avg_cpu_time AS recommended_plan_avg_cpu_time
  , qsrrec.avg_logical_io_reads AS recommended_plan_avg_logical_io_reads
  , qsrrec.avg_query_max_used_memory AS recommended_plan_avg_query_max_used_memory
  , qsrrec.avg_rowcount AS recommended_plan_avg_rowcount
FROM
	sys.dm_db_tuning_recommendations AS tr
CROSS APPLY
	OPENJSON (details, '$.planForceDetails')
	WITH
		(
			query_id int '$.queryId'
		  , regressedPlanId int '$.regressedPlanId'
		  , recommendedPlanId int '$.recommendedPlanId'
		  , regressedPlanErrorCount int
		  , recommendedPlanErrorCount int
		  , regressedPlanExecutionCount int
		  , regressedPlanCpuTimeAverage float
		  , recommendedPlanExecutionCount int
		  , recommendedPlanCpuTimeAverage float
		  , regressedPlanAbortedCount int
		  , recommendedPlanAbortedCount int
		) AS planForceDetails
INNER JOIN
	sys.query_store_plan AS qspreg
ON
	qspreg.plan_id = planForceDetails.regressedPlanId
	AND qspreg.query_id = planForceDetails.query_id
INNER JOIN
	sys.query_store_plan AS qsprec
ON
	qsprec.plan_id = planForceDetails.recommendedPlanId
	AND qsprec.query_id = planForceDetails.query_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrreg
ON
	planForceDetails.regressedPlanId = qsrreg.plan_id
INNER JOIN
	(
		SELECT
			plan_id
		  , AVG (avg_duration) AS avg_duration
		  , AVG (avg_cpu_time) AS avg_cpu_time
		  , AVG (avg_logical_io_reads) AS avg_logical_io_reads
		  , AVG (avg_query_max_used_memory) AS avg_query_max_used_memory
		  , AVG (avg_rowcount) AS avg_rowcount
		FROM
			sys.query_store_runtime_stats
		GROUP BY
			plan_id
	) AS qsrrec
ON
	planForceDetails.recommendedPlanId = qsrrec.plan_id;
GO

-- Get the queries with a forced plan
-- plan_forcing_type_desc : MANUAL
SELECT
	p.query_id
  , qt.query_sql_text
  , q.object_id
  , ISNULL (OBJECT_NAME (q.object_id), '') AS object_name
  , p.plan_id
  , p.query_plan_hash
  , TRY_CAST(p.query_plan AS xml) AS query_plan
  , p.plan_forcing_type_desc
  , p.force_failure_count
  , p.last_force_failure_reason_desc
  , p.last_execution_time
  , p.last_compile_start_time
FROM
	sys.query_store_plan AS p
INNER JOIN
	sys.query_store_query AS q
ON
	q.query_id = p.query_id
INNER JOIN
	sys.query_store_query_text AS qt
ON
	q.query_text_id = qt.query_text_id
WHERE
	p.is_forced_plan = 1;
GO

-- Unforce the exectuion plan
EXEC sys.sp_query_store_unforce_plan @query_id = 3, @plan_id = 3;
GO

-- Execute the procedure with the selective value
-- Clustered Index Seek 
-- Costs : 0,003293
-- Actual number of rows : 10
-- Estimated number of rows : 10
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 3
EXECUTE regression @SalesOrderID = 43660;
GO

-- Execute the procedure with the non selective value
-- Clustered Index Seek 
-- Costs : 0,003293 (Wrong!)
-- Actual number of rows : 500000
-- Estimated number of rows : 10
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 4046
EXECUTE regression @SalesOrderID = 43659;
GO

-- Execute the procedure with recompile and the non selective value to
-- get the right costs.
-- Clustered Index Seek
-- Costs : 3,53989 (0,00329)
-- Actual number of rows : 500000
-- Estimated number of rows : 500000
-- Table 'SalesOrderDetailSmall'. Scan count 1, logical reads 4046
EXECUTE regression @SalesOrderID = 43659 WITH RECOMPILE;
GO

-- Housekeeping
DROP INDEX IF EXISTS CL_SalesOrderDetailSmall_SalesOrderID
ON Sales.SalesOrderDetailSmall;
GO



/*******************************************************************************

	automatic query tuning - plan correction - score

*******************************************************************************/

/*

	SQL Server will correct the plan when Query Store detects an 
	estimated_cpu_gain of greater then 10 in the last 48 hours.

	Score
	Estimated value/impact for this recommendation on the 0-100 scale -
	the larger the better.

	"Average query CPU time changed from recommended_plan_cpu_time_average / 1000 
	to regressed_plan_cpu_time_average / 1000."

	estimated_cpu_gain
	(regressedPlanExecutionCount + recommendedPlanExecutionCount)
	* (regressedPlanCpuTimeAverage - recommendedPlanCpuTimeAverage) / 1000000 

	
	Average query CPU time changed from 0,27ms to 110,38ms
>	Average query CPU time changed from 272,31us to 110.376,93us

	score									27
	regressed_plan_cpu_time_average			110376
	regressed_plan_avg_duration				254775
	regressed_plan_avg_logical_io_reads		3666
	regressed_plan_avg_rowcount				29421
	recommended_plan_cpu_time_average		272
	recommended_plan_avg_duration			9927
	recommended_plan_avg_logical_io_reads	13
	recommended_plan_avg_rowcount			10
	estimated_duration_gain					7590288
	estimated_cpu_gain						3,41
	estimated_logical_io_gain				113243


	reason					
	Average query CPU time changed from 591,46ms to 2483,28ms
>	Average query CPU time changed from 591.464,4375us to 2.483.284,6us
	
	score									20
	regressed_plan_cpu_time_average			2483284
	regressed_plan_avg_duration				2965350
	regressed_plan_avg_logical_io_reads		334083
	regressed_plan_avg_rowcount				333336
	recommended_plan_cpu_time_average		591464
	recommended_plan_avg_duration			3977177
	recommended_plan_avg_logical_io_reads	3666
	recommended_plan_avg_rowcount			500000
	estimated_duration_gain					-31366637
	estimated_cpu_gain						58,64
	estimated_logical_io_gain				10242927



	The score is based on the CPU only, not on time, memory or IO and is 
	not determined by estimated_cpu_gain.

	score									27	
	CPU regression							40433% 		
	estimated_duration_gain					7590288
	estimated_cpu_gain						3,41
	estimated_logical_io_gain				113243
	
	score									20
	CPU regression							319%		
	estimated_duration_gain					-31366637
	estimated_cpu_gain						58,64
	estimated_logical_io_gain				10242927
	
*/


