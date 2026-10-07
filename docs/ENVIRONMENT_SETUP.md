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
- `ozmart_db` restore: not yet completed

Observed root cause of the script stop: the first automation version validated the local instance via `localhost`, while a direct connection to the default local instance via `Server=.` succeeded. The setup script has now been updated to use `Server=.` for local validation and database operations.

## Remaining environment work

The environment is **not yet ready for assignment work**.

Required remaining validation:

- [ ] SQL Server 2022 Database Engine installation completes successfully
- [ ] `MSSQLSERVER` service exists and runs
- [ ] `SELECT @@VERSION` confirms SQL Server 2022
- [ ] `ozmart_db` restores successfully and is ONLINE
- [ ] Teacher source tables can be queried
- [ ] SSMS installs and connects to `localhost` with Windows Authentication
- [ ] Visual Studio 2022 Community installs
- [ ] Integration Services Project template is available
- [ ] A real SSIS Data Flow executes successfully with actual row counts
- [ ] SSIS destination row count is verified
- [ ] macOS Altair AI Studio classification smoke test executes
- [ ] AI Studio process can be saved and reopened as `.rmp`

## Readiness

```text
READY_FOR_ASSIGNMENT = NO
```

Current blocker: database restore and the remaining SSMS / Visual Studio / SSIS Projects installation stages have not yet completed. SQL Server 2022 itself is installed, running, and locally queryable.
