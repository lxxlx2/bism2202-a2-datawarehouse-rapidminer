# Student A SSIS execution

The native Visual Studio project is `STUDENT_A_ID_SSIS/STUDENT_A_ID_SSIS.sln`. Its deployment artifact was built using the installed SSIS Projects extension, targeting SQL Server 2022. The master package executes eleven native Data Flows after a guarded reset of `[STUDENT_A_ID_dw]`. Opening the project does not execute the reset; starting the package reloads that student's warehouse.

The verified environment uses local SQL Server (`.`), Windows integrated authentication, SQL Server 2022 SSIS runtime and the existing restored `ozmart_db`. The source database is read-only in all package flows. No embedded SQL credentials are supplied. Reuse the installed environment; no reinstall is required.

## Prepare the files and empty target on another machine

1. Restore the teacher's original source backup as `ozmart_db`, using the teacher instructions. The source backup is supplied separately in the original assignment ZIP.
2. Copy the four unchanged CSVs from the project's `Support/csv` directory into `C:\BISM2202\assignment_work\csv`. These are the actual Flat File Source paths in Master.dtsx. Retain both conflicting seller-location rows.
3. Create `[STUDENT_A_ID_dw]` if absent, then run `Support/schema.sql` with that database selected in SSMS. The schema allowlist rejects other database names. It creates missing objects without moving any source rows.
4. Open the solution in Visual Studio, expand SSIS Packages and open `Master.dtsx`. Confirm the two SQL connection managers point to local `ozmart_db` and `[STUDENT_A_ID_dw]`. Start the master package. It resets only the allowlisted student target and loads references, dimensions and facts in dependency order.
5. Inspect every Data Flow and the native row counts. Expected counts are listed below. Stop debugging after capturing real successful views.
6. Execute the supplied warehouse validation and business audit SQL, followed by Q4.1, Q4.2, Q4.3 and the explicitly labelled customer-destination sensitivity. Save genuine SSMS outputs and screenshots.

## Expected native destination counts

Age reference 78; Education reference 6; State reference 8; raw SellerLocation reference 100; Seller 100; Customer 21,000; Product 2,199; customer Geography 1,500; seller Geography 99; Date 493; FactSales 137,901. Both geography streams load one shared role-aware dimension, totalling 1,599 records. Fact quantity totals 688,367 across all retained statuses.

Validation compares raw original floats and rounded money separately, checks original source fields and transaction relationships, rejects disabled/untrusted foreign keys and preserves all-null freight. One seller location remains UNK because its TAS and WA records conflict. Delivered items form the documented query population. A uses Lookup education integration and DENSE_RANK; B uses Sort/Merge Join education integration and deterministic ROW_NUMBER.

## Backup verification

The current backup's actual restore and query comparisons passed; see `../database/restore_validation.txt` and the shared hash verification. Every new ETL execution changes the warehouse build. After a final rerun, regenerate the backup and repeat actual restoration/full-row/query comparisons before treating that new build as frozen. The previous backup validation does not automatically validate later reloads.

The current overall delivery is PARTIAL because genuine required screenshots and final report/package acceptance remain outstanding. Native runtime/build/restore passes are recorded separately from this remaining evidence work.
