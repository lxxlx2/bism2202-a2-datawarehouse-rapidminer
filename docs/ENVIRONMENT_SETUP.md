# BISM2202 Assignment 2 Environment Status

Last updated: 2026-10-07

## Current verified state

This file records only environment state that has been directly observed during setup. It does not mark later stages as complete until they are actually validated.

### Host

- macOS on Apple Silicon / arm64
- Host RAM: 48 GB
- UTM: installed and in use
- VM architecture: x86_64 via QEMU emulation
- VM RAM: 16 GB
- VM CPU: 8 cores
- VM disk: 160 GB

### Windows VM

- VM name: `BISM2202-Windows`
- Windows Server installation: PASS
- Installed edition: Windows Server 2025 Standard Evaluation (Desktop Experience)
- Reported OS version during setup script: `10.0.26100`
- Reported Windows architecture: `AMD64`
- Administrator login: PASS
- Internet access from Windows: PASS

### Teacher materials

- Teacher source repository materials are present under `requirements/original/`
- The Windows setup script successfully downloaded and extracted the SSIS package from the repository
- Teacher material stage: PASS
- Database backup `ozmart_db_bism2202` was located and copied for restore

### Automated setup script

Script:

```text
scripts/windows/setup_environment.ps1
```

Commit that introduced the script:

```text
4b727b67f5833303b557f7e5a33c0782fd0c9574
```

The script is designed to install and validate:

1. SQL Server 2022 Developer
2. SQL Server Integration Services runtime
3. Restore of `ozmart_db`
4. SSMS
5. Visual Studio 2022 Community
6. SQL Server Integration Services Projects extension

The script stops on a real failure and records logs under:

```text
C:\BISM2202\logs\
```

Final environment result is intended to be written to:

```text
C:\BISM2202\environment-result.txt
```

## SQL Server / SSIS runtime progress

Verified as of the latest check:

- SQL Server 2022 Developer installation media download: PASS
- SQL Server installation ISO mounted in Windows: PASS
- SQL Server unattended setup completed with exit code `0`: PASS
- SQL Server Database Engine service `MSSQLSERVER`: RUNNING / Automatic
- SQL Server Integration Services runtime service `MsDtsServer160`: RUNNING / Automatic
- SQL Server service creation/startup: PASS
- Local SQL client validation using `Server=.`: PASS
- `SELECT @@VERSION`: PASS
- Verified SQL Server build: Microsoft SQL Server 2022 RTM 16.0.1000.6 Developer Edition (64-bit)
- Verified Windows login used for the successful SQL connection: `WIN-LR4ELCKRUA0\Administrator`
- SQL ERRORLOG reported `SQL Server is now ready for client connections`: PASS
- `ozmart_db` restore: PASS
- Source tables query after restore: PASS
- Verified restored base tables include `address_type`, `customer_address`, `customer_table`, `order_items_table`, `orders_table`, `product_category`, `product_subcategory`, `product_table`, `sellers_table`, and `sysdiagrams`
- SSMS 22 installation: PASS (confirmed by collected Visual Studio Installer state and setup logs)
- Installed SSMS version: 22.10.2 (`22.10.12217.157`)
- SSMS installation path: `C:\Program Files\Microsoft SQL Server Management Studio 22\Release`
- SSMS launch executable: `Common7\IDE\SSMS.exe`
- Initial SSMS install completed successfully; installer returned `3010` indicating restart required
- Later `exit code 1` reruns were not install failures: the installer log explicitly reports `SQL Server Management Studio 22 is already installed.`

Observed root cause of the script stop: the first automation version validated the local instance via `localhost`, while a direct connection to the default local instance via `Server=.` succeeded. The setup script has now been updated to use `Server=.` for local validation and database operations.
Additional script fix: the SQL query helper now returns the `DataTable` object without PowerShell pipeline enumeration (`return ,$dt`). This prevents the readiness loop from waiting even when a local SQL connection is already successful.


## Remaining environment work

The core Windows-side installation is complete, but final GUI smoke validation is still required before assignment work is considered fully ready.

Required remaining validation:

- [x] SQL Server 2022 Database Engine installation completes successfully
- [x] `MSSQLSERVER` service exists and runs
- [x] `SELECT @@VERSION` confirms SQL Server 2022
- [x] `ozmart_db` restores successfully and is ONLINE
- [x] Teacher source tables can be queried
- [x] SSMS 22 installs successfully
- [x] Reboot Windows to clear the installer restart-required state
- [ ] Launch SSMS and connect to local SQL Server with Windows Authentication (SSMS launches; equivalent local Windows-auth connection to `ozmart_db` has been independently verified via `System.Data.SqlClient`, but the GUI connection dialog itself has not been completed)
- [x] Visual Studio 2022 Community installs
- [x] SSIS Projects 2.2 package installs successfully
- [x] Integration Services Project template is available (observed in Visual Studio 2022 Create a new project)
- [x] An isolated real SSIS Data Flow executed with actual row counts (product_category smoke test, 19 source and 19 destination rows)
- [x] SSIS smoke-test destination row count verified (19), assignment warehouse counts pending
- [ ] macOS Altair AI Studio classification smoke test executes
- [ ] AI Studio process can be saved and reopened as `.rmp`

## Readiness

```text
READY_FOR_ASSIGNMENT = PARTIAL
```

Current status: Windows SQL Server, SSIS project designer, SSIS components, and an isolated real Data Flow with 19 transferred rows have passed. Remaining: build the rubric-specific dimensional warehouse ETL with SSIS screenshots, validate warehouse totals, separately complete macOS Altair AI Studio smoke test, and capture any required GUI evidence.

- Visual Studio 2022 was successfully installed, but the first automation passed an unquoted `--installPath` containing spaces through `Start-Process`, so the instance landed at `C:\Program`. `vswhere` and a recursive search confirmed `C:\Program\Common7\IDE\devenv.exe`. The setup script now discovers the actual instance path with `vswhere`, verifies/adds `Microsoft.VisualStudio.Workload.Data`, and no longer hard-codes the expected Visual Studio path.

- SSIS Projects Marketplace discovery failed because the scripted `extensionquery` path did not return a usable package asset. The automation now pins the current GA `SQL Server Integration Services Projects 2022+` release 2.2 and downloads it through the direct Visual Studio Marketplace `vspackage` endpoint. Microsoft lists 2.2 as released 2026-04-01 and tested against Visual Studio 2022 17.14.


## Latest automated setup completion

The Windows setup script reached its final result stage successfully.

Observed terminal output:

```text
[PASS] SSIS Projects package install
7. RESULT
DONE. Result: C:\BISM2202\environment-result.txt
Log: C:\BISM2202\logs\setup-20261007-114406.log
```

This confirms the scripted installation sequence completed through the SSIS Projects package stage. It does **not** yet prove that the SSIS project template opens correctly or that a real Data Flow executes successfully; those remain explicit GUI smoke-test gates.


## Display / guest integration status

Verified after installing UTM Windows Guest Tools:

- Windows display driver: `Red Hat VirtIO GPU DOD controller`
- Driver version: `22.8.5.664`
- Display resolution improved from `800x600` to `1024x768`
- Windows DPI: `LogPixels=96` / 100% scaling
- UTM Guest Tools ISO mounted and guest display driver installed successfully
- Current display is usable for assignment work; no further resolution tuning is required unless screenshot quality becomes a problem

## Local database connectivity re-check

A direct Windows-authenticated connection to `Server=.;Database=ozmart_db` was re-validated successfully after setup:

```text
DATABASE = ozmart_db
LOGIN    = WIN-LR4ELCKRUA0\Administrator
TABLES   = 10
SSMS/SQL CONNECTION CHECK = PASS
```

This confirms the database engine, restored source database, and Windows authentication path are working. The remaining SSIS readiness gates are template visibility and execution of a real Data Flow with verified row counts.


## 2026-10-08 Visual Studio SSIS project and blank-package execution

Observed in the Windows VM screenshots on 2026-10-08:

- Visual Studio 2022 displayed the ordinary `Integration Services Project` template as well as the Azure-enabled variant and import wizard.
- A solution named `BISM2202_SSIS` was created. Its Solution Explorer displayed `Package.dtsx` and SSIS designer.
- Actual package file executed: `C:\BISM2202\teacher\SSIS\BISM2202_SSIS\BISM2202_SSIS\Package.dtsx`.
- Execution explicitly invoked `C:\Program Files\Microsoft SQL Server\160\DTS\Binn\DTExec.exe` with `/FILE`.
- Observed result: `The package execution returned DTSER_SUCCESS (0).`, `DTEXEC EXIT CODE = 0`, elapsed `2.984 seconds`.

Scope limitation: the executed package was an empty starter package. This passes the SSIS project creation and basic package runtime smoke test, **not** the required Data Flow ETL test. No actual ETL row counts or destination counts were verified.

### Updated readiness gates

- SSIS Projects 2.2 installed: PASS
- Visual Studio SSIS project template visible: PASS
- SSIS project created and designer launched: PASS
- Blank SSIS package executed with SQL Server 2022 DTExec 160: PASS
- Real OLE DB source/transformation/destination Data Flow execution: PENDING
- Destination row counts verified: PENDING
- macOS Altair AI Studio process executed and `.rmp` saved/reopened: PENDING

`READY_FOR_ASSIGNMENT = PARTIAL`. Core Windows tooling works; full rubric-specific ETL and Altair capability remain to be verified.


## 2026-10-08 real SSIS Data Flow execution VERIFIED

Evidence: user-supplied Windows VM PowerShell screenshot, 2026-10-08 (7:46 AM on VM). The code was run on the user's VM; this is a screenshot-supported result, not an independent GitHub CI run.

- Script: `scripts/windows/ssis_category_dataflow_smoke.ps1` (previous code patch `1984192f7192e67d6f0308352c611e04bf2d24b4`).
- Dynamically resolved locally registered components as `DTSAdapter.OLEDBSource.8`, `DTSTransform.RowCount.8`, and `DTSAdapter.OLEDBDestination.8` (as reported in the terminal).
- Observed: `CSHARP_COMPILE = PASS`; each of SOURCE, ROWCOUNT, and DESTINATION initialization passed.
- Observed: `SSIS_PACKAGE_EXECUTION = PASS`, `SSIS_ROW_COUNT = 19`, `DESTINATION_ROWS = 19`, `DATA_FLOW_SMOKE = PASS`, `SCRIPT EXIT CODE = 0`.
- Package output: `C:\BISM2202\analysis\product_category_dataflow_smoke.dtsx`.
- Log output: `C:\BISM2202\analysis\product_category_dataflow_result.txt`.
- Target: isolated `BISM2202_ETL_SANDBOX.dbo.ProductCategorySmoke`; source was `ozmart_db.dbo.product_category` (19 rows, verified in prior profile).

**Windows SSIS runtime + source/transform/destination pipeline smoke-test gate: PASS.** This resolves the prior COM `0xC0048021` blocker. The native runtime 2022 catalog resolves the versioned `.8` component class names. No software reinstall needed. This test does not prove that the rubric-specific dimensional Data Flows, assignments, screenshot evidence, or Altair task are complete.
