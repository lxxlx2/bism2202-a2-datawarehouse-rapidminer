# Execution support and provenance

These are byte-identical copies of the project's implementation and audit code.
The recorded experiments and database checks are the execution evidence; copying
code is not a new execution or an acceptance result.

Use the Visual Studio solution and its `ssis/README_RUN.md` for the verified
native SSIS route. The PowerShell warehouse scripts use the existing Windows
layout `C:\BISM2202\assignment_work` and `C:\BISM2202\submission`, local
SQL Server and an already authorised Windows SQL login. They create/load only
the named assignment warehouses; read each script before running it. The source
`ozmart_db` comes from the teacher's original backup, which is not duplicated in
this delivery. Earlier individual loaders preserve the implementation history;
`load_warehouse_master.ps1` is the final full data-flow loader.

The Python generators and Java native runner are repository-oriented audit
companions. Their relative paths assume the original repository layout and the
installed AI Studio version recorded in the validation evidence. These copied
sources are not claimed to be a standalone rebuild system. For ordinary model
reopening, use the supplied `.rmp` files and `rapidminer/README_RUN.md`.

Do not rerun the holdout to choose settings or candidates. Preserve the frozen
pre-holdout decision, seeds, feature lists and training-only preprocessing.
