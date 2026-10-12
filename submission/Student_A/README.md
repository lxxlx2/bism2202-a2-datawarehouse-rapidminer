# Student A assignment files

Fill the report's `STUDENT_A_ID` field with the real student ID before submitting through the teacher's designated entrances. The Word report is in `report/`; its PDF is an auxiliary review copy.

- `ssis/STUDENT_A_ID_ssis.zip`: complete Visual Studio SSIS solution and required support files. The expanded solution is also provided. Follow `ssis/README_RUN.md` to rebuild the warehouse.
- `database/STUDENT_A_ID_dw.bak`: SQL Server 2022 warehouse backup. In SSMS, restore it to `STUDENT_A_ID_dw`, selecting suitable local MDF/LDF destinations.
- `diagrams/`: dimensional model and native fact Data Flow images.
- `sql/Q4_1.sql`, `Q4_2.sql`, `Q4_3.sql`: the three analysis queries, with current CSV results and native screenshots in `evidence/`. Run against this student's restored warehouse.
- `rapidminer/STUDENT_A_ID_rapidminer.rmp`: main AI Studio process, containing both models, training-only cross-validation and fixed holdout evaluation. Keep its `data/` folder beside it and follow `rapidminer/README_RUN.md`.
- `AI_DISCLOSURE.md` and the package's `shared/ai_disclosure/` folder: declared AI assistance and visible prompts/outputs.

The model test results include zero default recall. Review the report's limitations before interpreting accuracy or AUC.
