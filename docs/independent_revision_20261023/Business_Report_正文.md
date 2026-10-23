# BISM2202 Assignment 2 — Business Report (editable text source)

1. Executive Summary
This assignment examines retail sales analysis and credit-risk prediction using the lecturer-supplied OzMart database and loan dataset. For OzMart, a dimensional warehouse design stores the original order-item grain with separate customer- and seller-location dimensions plus an order-status dimension. The design aims to support three specified management questions: revenue-leading customer ages by state, five leading product categories in each state, and five NSW-based suppliers per purchase year. Delivered orders will be used as a declared completed-sales proxy; no profitability inference is made without cost data. The SQL queries are ready, but their results require actual warehouse execution and verification.

The loan experiment compares Naive Bayes with Gradient Boosted Trees under a stratified 75/25 holdout and five-fold validation restricted to training data. The positive class is loan default, so recall, F1 and false-negative counts will be considered alongside AUC and accuracy. No model performance claims are made before both processes run in the university-provided AI Studio environment. If either approach misses defaults or shows unacceptable group disparities, it should remain exploratory. The report will be finalised using the actual outputs, documented limitations, native evidence and an accurate AI-use disclosure.
2. Dimensional Data Warehouse Design
2.1 Dimensional star schema

Figure 1. Dimensional model for the OzMart order-item sales warehouse.
2.2 Kimball four-step design
The selected business process is OzMart retail order-item sales, with one source order_item_id defining each fact row. This transaction-level grain enables additive quantities without re-aggregating orders. The dimension set consists of customer, product, seller, date, customer geography, seller geography and order status. Distinct customer-origin and seller-origin geography tables prevent ambiguous NSW interpretations, while DimOrderStatus separates workflow status from numeric facts. Customer and product dimensions retain their natural IDs and descriptive rollups; DimDate supplies a calendar hierarchy. The measures are ItemQuantity, the supplied LineAmount, UnitSalesPrice, ExtendedAmount and AmountDifference. Source prices and line totals are preserved for reconciliation.

The design follows the transaction grain and surrogate-key conventions described by Kimball and Ross (2013). It captures the source snapshot only, with no unsupported Type 2 history. A supplier location identifier has inconsistent original state descriptions, so the proposed ETL marks its seller geography as unresolved instead of arbitrarily assigning a state. Exact quantities, relationship coverage, and dimension counts must be verified in SQL Server before this model is accepted.
3. SSIS Data Integration
3.1 Dimension Data Flow evidence
The ETL package integrates source customer, product, seller, date, geography and order-status data with the original age, education, state and seller-location reference files. The pipeline uses SSIS Data Flow transformations, including Lookup, Derived Column, Sort, Data Conversion and Row Count, to construct the dimension records and enforce referential consistency.
3.2 Fact Data Flow evidence
3.3 Implementation explanation
The master package builds the warehouse from fixed teaching assets in dependency order. Flat File Sources ingest the age, education, state and seller-location references; OLE DB Sources project operational fields without performing ETL joins in source SQL. Lookup transformations resolve natural and surrogate keys, while Derived Column operators derive date keys, standardise education codes and calculate consistent monetary fields. Native Sort removes duplicate date and normalised seller-geography records, and Data Conversion matches SQL Server target types. An independent status stream creates the DimOrderStatus members from observed order states.

The seller-location source conflict remains visible in the reference table, with an explicit unknown state in its conformed output. The fact stream must fail unresolved mandatory lookups instead of silently dropping order items. SQL validation checks referential integrity, source-to-target row counts, quantities and monetary source preservation. Screenshots and log evidence are necessary before making any claim that the package completed successfully (Microsoft, n.d.-a; Microsoft, n.d.-b).
4. Data Warehouse Queries
4.1 Revenue-leading customer age in each state
For each customer address state, the query sums delivered order-item line amounts by exact customer age. TOP (1) WITH TIES includes any age groups sharing the highest total. The count of distinct customers provides additional context for interpreting cohort-level sales. These totals are descriptive and do not establish individual spending propensity.
SET NOCOUNT ON;

/* Q4.1: Exact customer age yielding highest delivered line revenue by customer destination state.
   Include count of distinct customers to contextualize large-cohort effects.
   TOP (1) WITH TIES may yield more than one age per state. */
WITH state_age_sales AS (
    SELECT cg.StateCode, c.Age,
           SUM(f.LineAmount) AS Revenue,
           COUNT_BIG(*) AS OrderItemCount,
           COUNT(DISTINCT c.CustomerID) AS UniqueCustomers
    FROM dbo.FactOrderItem f
    JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey
    JOIN dbo.DimCustomerGeography cg ON cg.CustomerGeographyKey=f.CustomerGeographyKey
    JOIN dbo.DimOrderStatus os ON os.StatusKey=f.StatusKey
    WHERE os.StatusCode=N'delivered' AND c.Age IS NOT NULL AND cg.StateCode IS NOT NULL
    GROUP BY cg.StateCode,c.Age
)
SELECT s.StateCode, best.Age, best.Revenue, best.OrderItemCount,
       best.UniqueCustomers,
       CAST(best.Revenue/NULLIF(best.UniqueCustomers,0) AS DECIMAL(19,4)) AS RevenuePerUniqueCustomer
FROM (SELECT DISTINCT StateCode FROM state_age_sales) s
CROSS APPLY (
    SELECT TOP (1) WITH TIES a.Age,a.Revenue,a.OrderItemCount,a.UniqueCustomers
    FROM state_age_sales a WHERE a.StateCode=s.StateCode
    ORDER BY a.Revenue DESC
) best
ORDER BY s.StateCode,best.Age;
4.2 Five highest-volume product categories per state
For each customer state, the query ranks parent product categories using delivered units sold. ROW_NUMBER applies CategoryID as a deterministic tie-breaker, returning at most five categories per state. Revenue and order-item counts provide supplementary measures; ranking by units alone does not establish product profitability.
/* Q4.2: Exactly five product CATEGORIES by delivered unit volume, in each destination state.
   Revenue supports context; category ID is a deterministic tie breaker. */
WITH state_category AS (
    SELECT cg.StateCode, p.CategoryID, p.CategoryName,
           SUM(CONVERT(BIGINT,f.ItemQuantity)) AS UnitsSold,
           SUM(f.LineAmount) AS Revenue,
           COUNT_BIG(*) AS ItemRows
    FROM dbo.FactOrderItem f
    JOIN dbo.DimCustomerGeography cg ON cg.CustomerGeographyKey=f.CustomerGeographyKey
    JOIN dbo.DimProduct p ON p.ProductKey=f.ProductKey
    JOIN dbo.DimOrderStatus os ON os.StatusKey=f.StatusKey
    WHERE os.StatusCode=N'delivered' AND cg.StateCode IS NOT NULL
    GROUP BY cg.StateCode,p.CategoryID,p.CategoryName
)
SELECT states.StateCode, topcat.CategoryID, topcat.CategoryName,
       topcat.UnitsSold, topcat.Revenue, topcat.ItemRows
FROM (SELECT DISTINCT StateCode FROM state_category) states
CROSS APPLY (
    SELECT TOP (5) a.CategoryID,a.CategoryName,a.UnitsSold,a.Revenue,a.ItemRows
    FROM state_category a WHERE a.StateCode=states.StateCode
    ORDER BY a.UnitsSold DESC,a.CategoryID ASC
) topcat
ORDER BY states.StateCode,topcat.UnitsSold DESC,topcat.CategoryID;
4.3 Five NSW-origin suppliers by year
NSW identifies suppliers whose recorded seller locations resolve to New South Wales. The query ranks their delivered quantities by purchase year using supplier identifiers to resolve ties. Locations with unresolved source conflicts are excluded. The year-on-year comparison is descriptive because observed periods may have different coverage.
/* Q4.3: Five NSW-origin sellers by item quantity in each purchase year.
   Do not use NSW destination or resolve conflicting geography by guessing.
   Annual change is supplemental and compares the SAME seller in consecutive years. */
WITH seller_year AS (
    SELECT d.CalendarYear,s.SellerID,s.SellerName,
           SUM(CONVERT(BIGINT,f.ItemQuantity)) AS UnitsSold,
           SUM(f.LineAmount) AS Revenue,
           COUNT_BIG(*) AS ItemRows
    FROM dbo.FactOrderItem f
    JOIN dbo.DimDate d ON d.DateKey=f.PurchaseDateKey
    JOIN dbo.DimSeller s ON s.SellerKey=f.SellerKey
    JOIN dbo.DimSellerGeography sg ON sg.SellerGeographyKey=f.SellerGeographyKey
    JOIN dbo.DimOrderStatus os ON os.StatusKey=f.StatusKey
    WHERE os.StatusCode=N'delivered'
      AND sg.StateCode=N'NSW' AND sg.LocationConflict=0
    GROUP BY d.CalendarYear,s.SellerID,s.SellerName
)
SELECT years.CalendarYear, leaders.SellerID,leaders.SellerName,
       leaders.UnitsSold,leaders.Revenue,leaders.ItemRows,
       prev.UnitsSold AS PreviousYearUnits,
       CASE WHEN prev.UnitsSold IS NOT NULL AND prev.UnitsSold>0
            THEN CAST((leaders.UnitsSold-prev.UnitsSold)*100.0/prev.UnitsSold AS DECIMAL(14,2))
            ELSE NULL END AS YearOnYearPercent
FROM (SELECT DISTINCT CalendarYear FROM seller_year) years
CROSS APPLY (
    SELECT TOP (5) sy.SellerID,sy.SellerName,sy.UnitsSold,sy.Revenue,sy.ItemRows
    FROM seller_year sy WHERE sy.CalendarYear=years.CalendarYear
    ORDER BY sy.UnitsSold DESC,sy.SellerID ASC
) leaders
LEFT JOIN seller_year prev
 ON prev.CalendarYear=years.CalendarYear-1 AND prev.SellerID=leaders.SellerID
ORDER BY years.CalendarYear,leaders.UnitsSold DESC,leaders.SellerID;
5. Predictive Modeling in RapidMiner
5.1 Preprocessing and methodology
The supplied loan dataset is imported using explicit encoding and field types. Records with missing or invalid Loan_defaulted values are excluded from supervised learning. Customer_id receives the identifier role, and the selected feature subset contains eleven financial or credit-related variables. The positive label denotes default. A stratified 75/25 split reserves the final test partition, while five-fold cross-validation is performed on the training partition only. Fold-specific imputation and category handling are fitted within training folds to avoid information leakage.
5.2 Model 1: Naive Bayes
Naive Bayes estimates class-conditional attribute probabilities and provides a comparatively simple probabilistic baseline. Its conditional independence assumption is restrictive when financial variables are correlated, and Laplace smoothing helps avoid zero probability estimates for observed nominal categories (Domingos & Pazzani, 1997).
5.3 Model 2: Gradient Boosted Trees
Gradient Boosted Trees combines shallow decision trees to model nonlinear predictors and their interactions. The candidate configuration uses sixty trees, a maximum depth of four and learning rate 0.06. Hyperparameters and software support must be confirmed on the specified AI Studio installation before evaluating holdout performance (Friedman, 2001).
5.4 Predictor interpretation
Model interpretation should consider the conditional probabilities reported for Naive Bayes and the variable importance available for boosted trees. Associations involving debt, balance, loan purpose and credit history can inform further investigation, but they do not establish causal explanations of default.
6. Comparison and Recommended Bank Model
The comparison uses default-class precision, recall and F1, together with AUC and confusion-matrix counts. Overall accuracy is secondary because an imbalanced class distribution can conceal missed defaults. A model should be evaluated against the consequences of false negatives and false positives, alongside the suitability of its probability estimates. The final choice depends on the completed holdout results and the bank’s risk controls.
	Metric
	Naive Bayes
	Gradient Boosted Trees

	Cross-validation F1(default)
	
	

	Holdout accuracy
	
	

	Holdout default precision
	
	

	Holdout default recall
	
	

	Holdout default F1
	
	

	Holdout AUC
	
	

	False negatives (defaults missed)
	
	

7. Recommendations and Ethical Implications
7.1 Business recommendations and further research
For OzMart, use the state-level age, category and NSW supplier queries as descriptive inputs to merchandising and supplier-review meetings. Review category availability, completed-order coverage, customer cohort sizes and supplier delivery history before reallocating inventory. Do not describe LineAmount as profit: the source lacks reliable transaction cost data. Audit the unresolved seller-location conflict and preserve its source records.

For credit risk, keep both classifiers in a research setting until actual default detection, calibration and subgroup performance can be documented. Revisit model selection with temporal holdout data, payment history, debt-service burden and observation-time validation of predictors. Define the acceptable error trade-off using expected loss and an independently collected cohort. Threshold optimisation, if attempted, must occur within training data or a new validation set rather than the reserved final holdout. All operational credit decisions should remain subject to accountable human review.
7.2 Ethical implications
Loan-level prediction can lead to unfair exclusion, unsuitable credit or false reassurance when default risk is underestimated. An algorithm trained on existing customers may reproduce selection effects and historical disadvantage. Excluding demographic columns does not by itself prevent proxy bias: income, assets and credit history may still correlate with protected characteristics. Compare false-negative rates, false-positive rates and calibration across appropriate groups using adequate sample sizes and uncertainty bounds (Mehrabi et al., 2021).

Protect personal information through minimisation, access controls, justified retention and documented processing authority. Applicants should be able to correct inaccurate records, understand the basis for an adverse assessment and obtain human reconsideration. Financial variables may shift across cohorts; ongoing independent assessment is required before use. Model governance should include versioned processes, explicit approval owners, reproducible performance evidence and clear stop conditions. The NIST AI Risk Management Framework provides a structured lens for documenting these risks (Tabassi, 2023). No assertion of regulatory compliance or ethical fairness is supported by the unexecuted analysis.
8. References
Altair Engineering. (n.d.). AI Studio documentation. https://docs.rapidminer.com/
Domingos, P., & Pazzani, M. (1997). On the optimality of the simple Bayesian classifier under zero-one loss. Machine Learning, 29, 103–130. https://doi.org/10.1023/A:1007413511361
Friedman, J. H. (2001). Greedy function approximation: A gradient boosting machine. The Annals of Statistics, 29(5), 1189–1232. https://doi.org/10.1214/aos/1013203450
Kimball, R., & Ross, M. (2013). The data warehouse toolkit: The definitive guide to dimensional modeling (3rd ed.). Wiley.
Kimball Group. (n.d.). The four-step dimensional design process. https://www.kimballgroup.com/
Kohavi, R. (1995). A study of cross-validation and bootstrap for accuracy estimation and model selection. Proceedings of the 14th International Joint Conference on Artificial Intelligence (pp. 1137–1145). https://www.ijcai.org/Proceedings/95-2/Papers/016.pdf
Mehrabi, N., Morstatter, F., Saxena, N., Lerman, K., & Galstyan, A. (2021). A survey on bias and fairness in machine learning. ACM Computing Surveys, 54(6), Article 115. https://doi.org/10.1145/3457607
Microsoft. (n.d.-a). Data flow. SQL Server Integration Services documentation. https://learn.microsoft.com/en-us/sql/integration-services/data-flow/data-flow?view=sql-server-ver16
Microsoft. (n.d.-b). Lookup transformation. SQL Server Integration Services documentation. https://learn.microsoft.com/en-us/sql/integration-services/data-flow/transformations/lookup-transformation?view=sql-server-ver16
Microsoft. (n.d.-c). ROW_NUMBER (Transact-SQL). SQL Server documentation. https://learn.microsoft.com/en-us/sql/t-sql/functions/row-number-transact-sql?view=sql-server-ver16
Microsoft. (n.d.-d). Back up a database. SQL Server documentation. https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/create-a-full-database-backup-sql-server?view=sql-server-ver16
Saito, T., & Rehmsmeier, M. (2015). The precision-recall plot is more informative than the ROC plot when evaluating binary classifiers on imbalanced datasets. PLOS ONE, 10(3), e0118432. https://doi.org/10.1371/journal.pone.0118432
Tabassi, E. (2023). Artificial intelligence risk management framework (AI RMF 1.0) (NIST AI 100-1). National Institute of Standards and Technology. https://doi.org/10.6028/NIST.AI.100-1
