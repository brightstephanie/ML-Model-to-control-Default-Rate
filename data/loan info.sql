DECLARE @StartDate DATETIME
DECLARE @EndDate   DATETIME

SET @StartDate = '09/20/2021'
SET @EndDate =  '12/02/2021'


;WITH LoanInfo AS(
SELECT
    FLI.CustomerID
    ,FLI.ApplicantID
    ,FLI.FundedAmount
    ,FLI.FundingDate
    ,COALESCE(MIG.MigrationType,'NL') AS MigrationType
    ,FLI.IsCycled
    ,FLI.IsFPD
    ,FLI.IsZPD
    ,FLI.[Type]
    ,FLI.Source
    ,FLI.Advertisement
    ,FLI.Affiliate
    ,Status.Name AS AppStatus
    ,REPLACE(APP.Social,'-','') AS SSN
    ,DBK.Date AS DB_Date
    ,DBK.CurrentPeriod
    ,DBK.DueDateDaysLate AS DaysSinceDueDate
    ,CASE WHEN DBK.DueDateDaysLate > 0 THEN 1 ELSE 0 END AS IsLate
    ,DBK.CurrentPeriod AS DB_CurrentPeriod
    ,PFT.[Description] AS PayFrequency
    ,CUS.DOB
    ,E.EmailAddress
    ,Employment.Salary
    ,Employment.Placeofemploy
    ,Employment.WorkDepartment
    ,Employment.YearsOnJob
    ,Employment.MonthsOnJob 
    ,Address.ResidenceType
    ,Address.Abbreviate AS State
    ,B.YearsLenght AS AccLen_Year
    ,B.MonthLenght AS AccLen_Month
    ,B.Name AS BankName
    ,FTR.RiskScore
    -- ,FTR.Response
    ,FLI.PrincipalPaid
    ,FLI.PaymentsAmount
    ,DBK.LastBalance AS DB_LastBalance
    ,DBK.LoanStatus AS DB_LoanStatus
    ,CASE WHEN FPM.FatalReturns > 0 THEN 1 ELSE 0 END AS IsFatal
    ,FPM2.SchedulePayment
    ,FPM2.ReturnCode
    ,LST.LeadDate
    ,LST.ClarityCBBScore AS ClearBankBehaviorScore
    ,LST.ClarityScore AS ClearCreditRiskScore
    ,Clarity.ServiceResponseDetail
FROM 
    BusinessIntelligenceMFCX.dbo.fact_LoanInfo AS FLI LEFT JOIN ApplicationProcess.dbo.ApplicantMigrated AS MIG
        ON FLI.ApplicantId = MIG.ApplicantId
    INNER JOIN ApplicationProcess.dbo.Applicant AS APP ON FLI.ApplicantID = APP.ApplicantID
    LEFT JOIN [ApplicationProcess].[dbo].[Status] ON APP.StatusId = Status.StatusId
    LEFT JOIN ApplicationProcess.dbo.Customer AS CUS
        ON FLI.CustomerId = CUS.CustomerId 
    LEFT JOIN ApplicationProcess.dbo.PayFrecuencyType AS PFT
        ON CUS.PayFrequencyTypeID = PFT.PayFrecuencyTypeID
    LEFT JOIN [ApplicationProcess].[dbo].[EmailXCustomer] AS EC 
        ON CUS.CustomerId = EC.CustomerID
    LEFT JOIN [ApplicationProcess].[dbo].[Email] AS E 
        ON EC.EmailID = E.EmailID
    LEFT JOIN  [DATAWAREHOUSEMFCX].[MFCXStage].LeadsStage AS LST
        ON FLI.ApplicantId = LST.ApplicantId AND DATEDIFF(DAY,LST.LeadDate, FLI.FundingDate) BETWEEN -5 AND 15

    OUTER APPLY(
        SELECT 
            COUNT(1) AS FatalReturns
        FROM 
            BusinessIntelligenceMFCX.dbo.fact_PaymentInfo AS P1
        WHERE 
            P1.LoanId = FLI.LoanId
            AND P1.ReturnCode NOT IN ('R01','R99','R09')
            AND P1.PeriodNumber = 1
    ) AS FPM

    OUTER APPLY(
        SELECT 
            P1.SchedulePayment
            ,P1.ReturnCode
        FROM 
            BusinessIntelligenceMFCX.dbo.fact_PaymentInfo AS P1
        WHERE 
            P1.LoanId = FLI.LoanId
            AND P1.PeriodNumber = 1
            -- AND P1.ReturnCode NOT IN ('R01','R99','R09')
    ) AS FPM2

    OUTER APPLY (
        SELECT 
            BucketName 
            ,[Date]
            ,DueDateDaysLate
            ,PayFrequency
            ,paymentAmount
            ,LastBalance
            ,LoanStatus
            ,InterestSinceLastPayment
            ,TotalFunded
            ,TotalPrincipalPaid
            ,TotalPaid
            ,CurrentPeriod
            ,LoanInformationXCustomerId
            ,FundingDate
        FROM 
            [BusinessIntelligenceMFCX].[Buckets].[DelinquencyBucketSnapshot] AS D1
        WHERE 
            D1.CustomerId = FLI.CustomerId
            AND CAST(DATE AS DATE) = CAST(DATEADD(DAY,-1,CURRENT_TIMESTAMP) AS DATE)
    ) AS DBK -- DB: Delinquency Buckets
    
    OUTER APPLY (
	    SELECT TOP(1)
            EntityId
	        ,StoreID
	        ,RiskScore
            ,Response
	    FROM 
		    WebServiceManager.dbo.FactorTrustResponse
	    WHERE 
            EntityId = FLI.ApplicantID
		    AND StoreID = '0001'
	    ORDER BY FactorTrustResponse.FactorTrustResponseID DESC
    ) AS FTR -- FTR: Factor Trust Risk Score

    OUTER APPLY
    (
        SELECT DISTINCT TOP 1 
            E.Salary
            ,E.YearsOnJob
            ,E.MonthsOnJob
            -- ,E.EmployerID
            ,E.Placeofemploy
            ,E.WorkDepartment
        FROM [ApplicationProcess].[dbo].[EmployerXCustomer] EC
        LEFT JOIN [ApplicationProcess].[dbo].[Employer] E ON EC.EmployerId = E.EmployerID
        WHERE EC.CustomerId = CUS.CustomerId AND EC.IsEnabled = 1
    ) Employment

    OUTER APPLY
    (
    SELECT DISTINCT TOP 1
        A.City
        ,A.ZipCode
        ,S.Abbreviate 
        ,S.StateID
        ,RT.[Description] AS ResidenceType
    FROM [ApplicationProcess].[dbo].[AddressXCustomer] AC
    LEFT JOIN [ApplicationProcess].[dbo].[Address] A ON AC.AddressID = A.AddressID
    LEFT JOIN [ApplicationProcess].[dbo].[State] S ON A.StateID = S.StateID
    LEFT JOIN [ApplicationProcess].[dbo].[ResidentType] RT ON A.ResidentTypeID = RT.ResidentTypeID
    WHERE CUS.CustomerId = AC.CustomerID AND AC.IsEnabled = 1
    ) Address

    OUTER APPLY
    (
    SELECT DISTINCT TOP 1 
        CustomerID
        ,B.AccountNum
        ,B.RoutingNum
        ,B.YearsLenght
        ,B.MonthLenght
        ,B.Name
    FROM [ApplicationProcess].[dbo].[BankInformationXCustomer] BC 
    LEFT JOIN [ApplicationProcess].[dbo].[BankInformation] B ON BC.BankInformationId = B.BankInformationID
    WHERE CUS.CustomerId = BC.CustomerID AND BC.isEnabled = 1
    ) B

    OUTER APPLY
    (
    SELECT 
        DateRequested
        ,JSON_VALUE(XmlIn,'$.DynamicRequestObject.ssn') AS SSN
        ,REPLACE(ServiceResponseDetail,'{ADDRESS}','') AS ServiceResponseDetail
    FROM ApplicationProcess.dbo.ServiceInquiryLog AS Clarity
    WHERE JSON_VALUE(XmlIn,'$.DynamicRequestObject.ssn') = REPLACE(APP.Social,'-','')
	-- AND CONVERT(DATE,ClarityLog.DateRequested) = CONVERT(DATE,APP.CreationDateTime)
    AND ServiceID = 30
    ) Clarity

    -- OUTER APPLY
    -- (
    -- SELECT 
    --     *
    -- FROM [BusinessIntelligenceMFCX].[dbo].[DataStudyOutput] DSO
    -- WHERE DSO.Invoice = APP.ApplicantID
    -- ) IdologyTest

    WHERE 
        FLI.[Type] = 'New Loan'
    AND FLI.LoanStatus NOT IN ('Cancelled')
)


SELECT
    *
    ,RIGHT(RTRIM(EmailAddress), LEN(EmailAddress)-CHARINDEX('@', EmailAddress)) AS Email_Domain
    ,DATEDIFF(YEAR, DOB, FundingDate) AS AgeOfCustomer
    ,CASE WHEN UPPER(Placeofemploy) LIKE 'SSI%' OR UPPER(Placeofemploy) LIKE '%SSI' OR UPPER(Placeofemploy) LIKE 'SOCIAL%' OR UPPER(Placeofemploy) LIKE '%DISAB%' OR UPPER(Placeofemploy) LIKE '%RETIRE%' 
            OR UPPER(WorkDepartment) LIKE 'SSI%' OR UPPER(WorkDepartment) LIKE 'SOCIAL%' OR UPPER(WorkDepartment) LIKE '%DIAB%' OR UPPER(WorkDepartment) LIKE 'RETIRE%' THEN 1 
        WHEN LOWER(Placeofemploy) LIKE '%no income%' OR LOWER(Placeofemploy) LIKE '%unemploy%' OR  LOWER(Placeofemploy) IN ('','NA','N/A') THEN 2
        WHEN LOWER(Placeofemploy) LIKE '%self%' THEN 3
        ELSE 4 END AS flag_CompanyName
    ,(CASE WHEN AccLen_Year IS NULL THEN 0 ELSE AccLen_Year END)*12 + (CASE WHEN AccLen_Month IS NULL THEN 0 ELSE AccLen_Month END) AS AccLen
    ,CASE WHEN Salary = 0 THEN SchedulePayment
        WHEN Salary != 0 AND PayFrequency = 'Biweekly' THEN SchedulePayment/(Salary*12/26) 
        WHEN Salary != 0 AND PayFrequency = 'Weekly' THEN SchedulePayment/(Salary*12/52) 
        WHEN Salary != 0 AND PayFrequency = 'Monthly' THEN SchedulePayment/Salary
        WHEN Salary != 0 AND PayFrequency = 'Twice a month' THEN SchedulePayment/(Salary*12/24) 
        END AS PTI
    ,YearsOnJob*12 + MonthsOnJob AS Monthsonjob
FROM LoanInfo

