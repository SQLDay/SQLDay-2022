CREATE SCHEMA [PartTracking]
go
CREATE TABLE [PartTracking].[Parts]
(
	[ID] INT NOT NULL PRIMARY KEY CLUSTERED,
	[SerialNum] VARCHAR (100) NOT NULL,
	[ManufDate] DATETIME2 NOT NULL,
	[BatchID] INT NOT NULL,
	[CarID] INT NULL
)
WITH (
	SYSTEM_VERSIONING = ON,
	LEDGER = ON (LEDGER_VIEW = [PartTracking].[PartsLedgerView])
);

/* check SSMS objects */


SELECT * FROM sys.database_ledger_transactions
GO

SELECT * FROM sys.database_ledger_blocks
GO


/* check the storage */

select * from [PartTracking].[MSSQL_LedgerHistoryFor_1525580473]
go

select * from [PartTracking].[PartsLedgerView]
go

select * from sys.ledger_table_history

select * from sys.ledger_column_history

/* multiple transactions in a single block */
INSERT INTO [PartTracking].[Parts]
VALUES (1, '123-333-444', '01-02-2019', 1, NULL)
GO
INSERT INTO [PartTracking].[Parts]
VALUES (2, '123-444-333', '01-03-2019', 1, NULL)
go

select * from  [PartTracking].[Parts]
GO

SELECT * FROM sys.database_ledger_transactions
GO

SELECT * FROM sys.database_ledger_blocks
GO

select * from parttracking.MSSQL_LedgerHistoryFor_1525580473
go

select * from [PartTracking].[PartsLedgerView]
go

/* 1 transaction, 1 block and multiple steps */
UPDATE [PartTracking].[Parts] SET [CarID] = 2  where id=2
go

select * from [PartTracking].[Parts]
go

select * from parttracking.MSSQL_LedgerHistoryFor_1525580473
go

select * from [PartTracking].[PartsLedgerView]
order by ledger_transaction_id,ledger_sequence_number
go

SELECT * FROM sys.database_ledger_transactions
GO

SELECT * FROM sys.database_ledger_blocks
GO



/* 1 transactions with multiple steps - 1 single block */
Begin Transaction
	UPDATE [PartTracking].[Parts] SET [CarID] = 3  where id=1
	UPDATE [PartTracking].[Parts] SET [CarID] = 3  where id=2
Commit Transaction
go


select * from parttracking.MSSQL_LedgerHistoryFor_1525580473
go

select * from [PartTracking].[PartsLedgerView]
order by ledger_transaction_id,ledger_sequence_number
go

SELECT * FROM sys.database_ledger_transactions
GO

SELECT * FROM sys.database_ledger_blocks
GO

/* check the storage - previous_block_hash */

select * from [PartTracking].[PartsLedgerView]
order by ledger_transaction_id,ledger_sequence_number
go

select *
from [PartTracking].[Parts]


Delete [PartTracking].[Parts] where ID=2
go

SELECT * FROM sys.database_ledger_transactions
GO

INSERT INTO [PartTracking].[Parts]
VALUES (3, '333-444-123', '01-03-2019', 1, NULL)
go

select * from [PartTracking].[PartsLedgerView]
order by ledger_transaction_id,ledger_sequence_number
go


/* Append Only Table */

Create Schema Transactions
go
CREATE TABLE [Transactions].[Wallets]
(
    UserId INT NOT NULL,
    Operation tinyint NOT NULL /* 0: Credit 1: Debit */,
    [Timestamp] Datetime2 NOT NULL default GetDate(),
	Amount Numeric(15,2) NOT NULL
)
WITH (
    LEDGER = ON (
        APPEND_ONLY = ON
    )
);
GO

/* Show SSMS */

select * from sys.ledger_table_history
GO

SELECT * FROM sys.database_ledger_transactions
GO


INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (1,0,'2022/05/01',100)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (2,0,'2022/05/01',200)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (3,0,'2022/05/01',300)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (2,0,'2022/05/02',50)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (3,1,'2022/05/02',80)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (1,1,'2022/05/02',30)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (3,0,'2022/05/03',20)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (2,1,'2022/05/03',40)
INSERT INTO [Transactions].[Wallets] (UserId,Operation,[Timestamp],Amount) 
			values (1,1,'2022/05/03',20)
GO

select * from [Transactions].[Wallets_Ledger]
go

SELECT * FROM sys.database_ledger_transactions
GO

select UserId, [Timestamp],
	case operation
		when 0 then 'Credit'
		when 1 then 'Debit'
	end OperationType,
	Amount as OperationAmount,
	sum(case operation
                     when 0 then Amount
					 when 1 then Amount * -1
		end) 
		over (partition by UserId order by TimeStamp
				rows between unbounded preceding 
				and current row) CurrentBalance
from [Transactions].[Wallets]


update [Transactions].[Wallets] set Amount=40
where UserId=1 and Amount=30
go

DECLARE @digest_locations NVARCHAR(MAX) = (SELECT * FROM sys.database_ledger_digest_locations FOR JSON AUTO, INCLUDE_NULL_VALUES);
SELECT @digest_locations as digest_locations;
BEGIN TRY
    EXEC sys.sp_verify_database_ledger_from_digest_storage @digest_locations
	--,@table_name=N'[Transactions].[Wallets]'
    SELECT 'Ledger verification succeeded.' AS Result;
END TRY
BEGIN CATCH
    THROW;
END CATCH
GO

SELECT * FROM sys.database_ledger_blocks
GO

Select 'Wallets'
	where exists(
		select 1 from [Transactions].[Wallets_Ledger]
		where ledger_transaction_id in (
			select  transaction_id FROM sys.database_ledger_transactions
			where block_id in (5,7)))
union all
Select 'Parts'
	where exists(
		select 1 from [PartTracking].[PartsLedgerView]
		where ledger_transaction_id in (
			select  transaction_id FROM sys.database_ledger_transactions
			where block_id in (5,7)))

