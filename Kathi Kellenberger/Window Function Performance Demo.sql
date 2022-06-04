--Demo 0 set up
USE master; 
GO
ALTER DATABASE AdventureWorks2019
SET COMPATIBILITY_LEVEL = 140 WITH NO_WAIT
GO
SET STATISTICS IO ON;
SET NOCOUNT ON;
--Remember to turn on actual execution plan
GO
USE AdventureWorks2019;
GO
DROP INDEX IF EXISTS Perf1 ON Sales.SalesOrderHeader;
GO



--Demo 1 Show the Execution Plan
--
SELECT CustomerID, SalesOrderID, TotalDue, 
   ROW_NUMBER() OVER(ORDER BY SalesOrderID) AS RowNum, --Sort, Sequence, Segment
   SUM(TotalDue) OVER() AS GrandTotal, --Table spool
   SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS RunningTotal --Segment, Window spool
FROM Sales.SalesOrderHeader;


--Compare these queries
PRINT '
Ranking'
SELECT CustomerID, SalesOrderID, 
	CAST(OrderDate AS DATE) AS OrderDate, 
	TotalDue, 
	ROW_NUMBER() 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS RowNum
FROM Sales.SalesOrderHeader
;

Print '
Windows Aggregate function'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	SUM(TotalDue) OVER(PARTITION BY CustomerID) AS SubTotal
FROM Sales.SalesOrderHeader;

Print '
Running total'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	SUM(TotalDue) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS RunningTotal
FROM Sales.SalesOrderHeader;

Print '
Offset function, LAG'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	LAG(SalesOrderID) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS PrevOrder
FROM Sales.SalesOrderHeader;

PRINT '
Offset function, FIRST_VALUE'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	FIRST_VALUE(SalesOrderID) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS FirstOrder
FROM Sales.SalesOrderHeader;

PRINT '
Statistical'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	PERCENT_RANK() 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS PercentRank
FROM Sales.SalesOrderHeader;



--Demo 2
Print 'POC index: partition, order by, covering'
CREATE NONCLUSTERED INDEX Perf1 ON Sales.SalesOrderHeader
	(CustomerID, SalesOrderID) INCLUDE(OrderDate,TotalDue);


PRINT '
Ranking, 689'
SELECT CustomerID, SalesOrderID, 
	CAST(OrderDate AS DATE) AS OrderDate, 
	TotalDue, 
	ROW_NUMBER() 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS RowNum
FROM Sales.SalesOrderHeader
;

Print '
Windows Aggregate function, 689 + 139407'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	SUM(TotalDue) OVER(PARTITION BY CustomerID) AS SubTotal
FROM Sales.SalesOrderHeader;

Print '
Running total 689 + 188791'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	SUM(TotalDue) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS RunningTotal
FROM Sales.SalesOrderHeader;

Print '
Offset function, LAG 689'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	LAG(SalesOrderID) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS PrevOrder
FROM Sales.SalesOrderHeader;

PRINT '
Offset function, FIRST_VALUE 689 + 188791'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	FIRST_VALUE(SalesOrderID) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS FirstOrder
FROM Sales.SalesOrderHeader;

PRINT '
Statistical 689 + 139407'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	PERCENT_RANK() 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS PrevOrder
FROM Sales.SalesOrderHeader;



--Demo 3 Framing
PRINT '
Running Total with Default frame'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue, 
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) 
	AS RunningTotal
FROM Sales.SalesOrderHeader;

PRINT '
Running total with RANGE'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue, 
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID
		RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
FROM Sales.SalesOrderHeader;

PRINT '
Running Total with ROWS'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue, 
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID
		ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
FROM Sales.SalesOrderHeader;

PRINT '
FIRST_VALUE no frame'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	FIRST_VALUE(SalesOrderID) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) AS PrevOrder
FROM Sales.SalesOrderHeader;

PRINT '
FIRST_VALUE with frame'
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue,
	FIRST_VALUE(SalesOrderID) 
	OVER(PARTITION BY CustomerID ORDER BY SalesOrderID
	   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS FirstOrder
FROM Sales.SalesOrderHeader;


--Can't use RANGE with N Proceeding
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue, 
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID
		ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeMonthTotal
FROM Sales.SalesOrderHeader;

SELECT CustomerID, SalesOrderID, OrderDate, TotalDue, 
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID
		RANGE BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeMonthTotal
FROM Sales.SalesOrderHeader;

--Demo 4 Batch Mode on Rowstore
--Create a bigger table
DROP TABLE IF EXISTS dbo.SOD ;

CREATE TABLE dbo.SOD(SalesOrderID INT, SalesOrderDetailID INT, LineTotal Money);

INSERT INTO dbo.SOD(SalesOrderID, SalesOrderDetailID, LineTotal)
SELECT SalesOrderID, SalesOrderDetailID, LineTotal 
FROM Sales.SalesOrderDetail
UNION ALL 
SELECT SalesOrderID + MAX(SalesOrderID) OVER(), SalesOrderDetailID, LineTotal 
FROM Sales.SalesOrderDetail;

CREATE INDEX SalesOrderID_SOD ON dbo.SOD 
(SalesOrderID, SalesOrderDetailID) INCLUDE(LineTotal);

PRINT '
Aggregate query'
SELECT SalesOrderID, SalesOrderDetailID, LineTotal, 
   SUM(LineTotal) OVER(PARTITION BY SalesOrderID) AS SubTotal
FROM dbo.SOD;

 PRINT '
 Analytic function'
 SELECT SalesOrderID, SalesOrderDetailID, LineTotal, 
   PERCENT_RANK() OVER(PARTITION BY SalesOrderID ORDER BY LineTotal) AS Ranking
 FROM dbo.SOD; 

--Switch to 2019 compatibility
USE master; 
GO
ALTER DATABASE AdventureWorks2019
SET COMPATIBILITY_LEVEL = 150 WITH NO_WAIT
GO
USE AdventureWorks2019;
GO


--Rerun the queries
PRINT '
Aggregate query'
SELECT SalesOrderID, SalesOrderDetailID, LineTotal, 
   SUM(LineTotal) OVER(PARTITION BY SalesOrderID) AS GrandTotal
FROM dbo.SOD;

 PRINT '
 Analytic function'
 SELECT SalesOrderID, SalesOrderDetailID, LineTotal, 
   PERCENT_RANK() OVER(PARTITION BY SalesOrderID ORDER BY LineTotal) AS Ranking
 FROM dbo.SOD; 

 --Hack from Itzik, works with 2016 and up
USE master; 
GO
ALTER DATABASE AdventureWorks2019
SET COMPATIBILITY_LEVEL = 130 WITH NO_WAIT
GO
USE AdventureWorks2019;
GO

--An empty table with a column store index
CREATE TABLE #CS(KeyCol INT NOT NULL PRIMARY KEY, 
	Col1 NVARCHAR(25));
CREATE COLUMNSTORE INDEX CSI_CS ON #CS(KeyCol, Col1);

PRINT '
 Analytic function'
 SELECT SalesOrderID, SalesOrderDetailID, LineTotal, 
   PERCENT_RANK() OVER(PARTITION BY SalesOrderID ORDER BY LineTotal) AS Ranking
 FROM dbo.SOD
 OUTER APPLY #CS; 

--One of the better performing techniques if < 2019
WITH TOTALS AS (
	SELECT SUM(LINETOTAL) AS subtotal, SalesOrderID
	FROM SOD
	GROUP BY SalesOrderID)
SELECT sod.SALESORDERID, sod.SalesOrderDetailID, subtotal
FROM sod 
join totals ON sod.SalesOrderID = totals.SalesOrderID; 

--Instead of 
SELECT salesOrderID, SalesOrderDetailID, 
	SUM(LineTotal) OVER(PARTITION BY SalesOrderID)  AS SubTotal
FROM SOD 
