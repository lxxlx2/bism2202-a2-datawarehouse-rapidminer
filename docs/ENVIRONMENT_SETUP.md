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
- SQL Server `setup.exe` launched in unattended mode: PASS
- SQL Server setup process is still active
- Setup is running from mounted media at `E:\setup.exe`
- Integration Services runtime service `MsDtsServer160` now exists
- `MsDtsServer160` is currently `Stopped`, startup type `Automatic`
- SQL Server Database Engine service `MSSQLSERVER`: not yet confirmed
- SQL Server install completion: PENDING
- `SELECT @@VERSION`: PENDING
- `ozmart_db` restore: PENDING

The setup log was observed continuing to update during installation, including Integration Services package activity. No final SQL Server setup success result has yet been recorded.

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

Current blocker: SQL Server 2022 unattended installation is still in progress. The next status update should be based on the actual installer exit result and service/database validation, not on elapsed time.
