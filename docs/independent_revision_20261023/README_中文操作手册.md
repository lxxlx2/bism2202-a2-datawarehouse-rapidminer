# BISM2202 Assignment 2 中文操作手册

## 零、文件准备与操作顺序

### 一眼看懂哪些可以删

| 文件或目录 | 是否可删除 | 原因 |
|---|---|---|
| `_可删除_校验与开发记录/` | **可以整个删除** | 仅供开发过程静态检查和 A/B 差异记录；不参与模型训练和 SSIS 加载 |
| `docs/RapidMiner_流程图.dot`、`docs/Warehouse_Star.dot` | 最终提交前通常可删 | 只是绘图源码；如果需要重新修改示意图，先保留 |
| `scripts/generate_rapidminer.py` | 运行并验证 `.rmp` 后可删 | 用于重新生成流程 XML；原生 `.rmp` 才是交付流程 |
| `scripts/generate_warehouse_windows.py` | 生成 Windows C# 和 PowerShell 后可删 | **必须先生成**, 否则 `ssis/BISM2202_A2_SSIS/` 不完整 |
| `scripts/prepare_teacher_data.py` | 原始 CSV、源数据库文件准备好后可删 | 前期数据准备脚本 |
| `sql/03_validation.sql` | 建议保留到验收完毕 | 验证 SQL 查询及数据完整性；只读 SQL，保留有助查错 |
| `sql/04_backup.sql` | 生成并恢复 `.bak` 后可删 | 用于数据库备份的执行脚本 |
| `report/BISM2202_A2_Business_Report_DRAFT.docx` | **不要直接提交** | 是可编辑英文报告草稿，含待填真实结果和截图，尚未套用老师原始模板 |

### 操作顺序

先准备老师原始 CSV，打开 `rapidminer/NaiveBayes_Full.rmp`，运行并核对结果；再打开 `rapidminer/GradientBoostedTrees_Full.rmp`；两个模型正常后运行主程序 `rapidminer/BISM2202_A2_rapidminer.rmp`。首次运行保持预设参数；出现错误时查看 Problems / Log。

报告文档在 `report/` 目录。可先检查第 1 至 8 节的正文，随后填入软件运行的图表。

## 一、原始数据与软件

**本作业要求同时完成两个部分：**

- Part 1：OzMart 零售业务数据仓库，SQL Server 2022、SSIS、数据仓库图、三道 SQL 查询及截图、数据库备份。
- Part 2：老师提供的贷款数据，Altair RapidMiner AI Studio 两个分类模型，交叉验证及测试集、报告和真实截图。

老师固定了这两个数据源和三个业务问题；第三版不能擅自把 OzMart 换成餐厅或把贷款换成其他网站数据。第三版与 A/B 版本的区别是：数据仓库把顾客地理位置和卖家地理位置拆开、额外添加订单状态维度；贷款部分用 Naive Bayes 和 Gradient Boosted Trees（H2O），分层 75/25 划分，5 折训练交叉验证，重视违约类 recall 和 F1。模型指标填写在第六节的对比表中。

### 程序文件与用途

| 路径 | 用途 |
| --- | --- |
| `rapidminer/BISM2202_A2_rapidminer.rmp` | 一次运行两个模型、CV、独立测试 |
| `rapidminer/NaiveBayes_CV.rmp` | 单独检查朴素贝叶斯 CV |
| `rapidminer/NaiveBayes_Full.rmp` | 朴素贝叶斯 CV + 测试集 |
| `rapidminer/GradientBoostedTrees_CV.rmp` | 单独检查梯度提升树 CV |
| `rapidminer/GradientBoostedTrees_Full.rmp` | 梯度提升树 CV + 测试集 |
| `sql/01_schema.sql` | 新建专用数据仓库及 7 维度 + 1 事实表 |
| `sql/02_queries.sql` | 作业 Q4.1 至 Q4.3 |
| `sql/03_validation.sql` | 数据、源表、外键及冲突检查 |
| `sql/04_backup.sql` | 生成 `.bak` 并做 VERIFYONLY |
| `scripts/prepare_teacher_data.py` | 从老师的原始 ZIP 准备 CSV、BAK、模板 |
| `scripts/generate_warehouse_windows.py` | 从仓库已验证 SDK 适配器生成第三版 SSIS 代码 |
| `scripts/Start-Warehouse-Windows.ps1` | Windows 上执行第三版 SSIS ETL |
| `scripts/make_visual_studio_project.py` | 把生成的原生 Master.dtsx 包装成 `.sln` 工程 |

## 二、在 Mac 上准备老师原始数据

### 第 1 步：解压交付 ZIP

把下载的 `BISM2202_A2_新版交付包.zip` 解压到 `Downloads`，此时应有 `~/Downloads/BISM2202_A2_新版交付包`。打开 Mac「终端」。

### 第 2 步：拉取老师固定的原始文件

安装 Git LFS（若没有 Homebrew，先从 https://brew.sh 安装；学校软件可能无需自己安装）：

```zsh
brew install git-lfs
```

执行以下命令：

```zsh
mkdir -p "$HOME/BISM2202-C"
cd "$HOME/BISM2202-C"
git clone https://github.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer.git
cd bism2202-a2-datawarehouse-rapidminer
git lfs install --local
git lfs pull
```

仓库的大文件由 Git LFS 管理。`git clone` 成功并不等于教师 ZIP 已经下载，必须让 `git lfs pull` 完成。

### 第 3 步：用源码原样释放所需数据

```zsh
cd "$HOME/Downloads/BISM2202_A2_新版交付包"
python3 scripts/prepare_teacher_data.py --repo "$HOME/BISM2202-C/bism2202-a2-datawarehouse-rapidminer"
python3 scripts/generate_warehouse_windows.py --repo "$HOME/BISM2202-C/bism2202-a2-datawarehouse-rapidminer"
python3 scripts/generate_rapidminer.py
```

完成时可以检查终端输出：`SOURCE_HASH_PASS`、`LOAN_READY`、`SUPPORT_READY`、`TEACHER_DATA_PREPARED=PASS`、`NATIVE_SSIS_BUILDER_GENERATED` 和 `XML_OK`。出现 SHA256 错误时重新核对源文件。

此时 RapidMiner `data/` 里是老师完整 CSV，SSIS `Support/csv/` 里是四个参考表。`ssis/teacher_source_backup/` 如能识别原始 BAK 会自动保留。

## 三、在大学官方 RapidMiner 里一步步执行（最重要）

### 第 1 步：打开大学提供的 AI Studio / RapidMiner

用学校授权的账号登录学校提供的 RapidMiner/Altair AI Studio。若学校提供远程实验桌面，在远程桌面打开；如果允许安装 Mac 版，也可以在自己的 Mac 运行。官方安装说明：https://docs.rapidminer.com/2026.1/studio/installation/index.html 。

从同一台运行 RapidMiner 的机器复制完整 `rapidminer/` 文件夹，**必须保留 `.rmp` 与 `data/` 互为同级目录结构**：

```text
rapidminer/
  BISM2202_A2_rapidminer.rmp
  NaiveBayes_Full.rmp
  GradientBoostedTrees_Full.rmp
  NaiveBayes_CV.rmp
  GradientBoostedTrees_CV.rmp
  data/
    BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv
```

### 第 2 步：先用小程序确认能读取 CSV

在 RapidMiner 顶部 File > Open Process，打开 `NaiveBayes_CV.rmp`。如果你的软件只能从 Repository 打开，请选择 File > Import Process 或把 `.rmp` 导入本地 Repository；不同大学界面可能略有区别。

进入 **Design（设计）** 页面，检查最左边绿色的 **Read CSV** 算子。单击它，在右侧 Parameters 检查：

1. `csv file`：选择同目录 `data/BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv` 的实际路径。如果 `%{source_csv}` 路径解析失败，就在此选择完整文件路径，再按 Save 保存 第三版 自己的副本。
2. `column separators`：`,`。
3. `first row as names`：启用（原数据第一行字段名）。
4. `encoding`：`windows-1252`，无法显示时不要直接改编码，先检查原 CSV。
5. `data set meta data information`：重点核对 `Loan_defaulted` 被读取为 integer，`Income` 与 `Loan_purpose` 为 nominal，金额、余额为 numerical。

流程中随后是 Set Role、Filter Examples、Numerical to Binominal、Select Attributes 和 Split Data。

运行后在 Results 页面核对是否实际读取了正确字段。原仓库曾验证有 14,999 条原始记录，其中可监督训练的有效标签为 9,998 条。如样本数不一致，检查文件版本、数据类型和筛选设置。

### 第 3 步：核对训练目标和数据划分

返回 Design，依次单击以下算子：

- **Set Label**：`Loan_defaulted`，`target role = label`。
- **Set ID**：`Customer_id`，`target role = id`，ID 不作为预测特征。
- **Remove Unknown Outcomes**：过滤缺失结果的样本。缺失标签的样本不参加监督训练。
- **Map Loan Default To Boolean**：确认 `0 = 未违约（false）`，`1 = 违约（true）`。如果结果颠倒，先停下来修正编码映射。
- **Select Risk Predictors**：11 个变量，Age、Loan_amount、Income、Current_mortgage、Student_debt、Bank_balance、Capital_gain、Capital_loss、Loan_purpose、Credit_history、Past_bankruptcy。
- **75-25 Stratified Split**：按标签分层，训练 75%，最终测试 25%，随机种子 73421。

在 Split Data 的输出端 `partition 1` 应进入交叉验证；`partition 2` 必须只连接模型最终测试，不允许参与训练调参。

### 第 4 步：运行第一个模型 Naive Bayes

先打开 `NaiveBayes_Full.rmp`，或者在刚才的单模型流程中检查。双击 **Five-Fold Training CV**，进入内部两个子过程：

**Training 子过程**：Training Fold Imputation > Training Fold Vocabulary > Train NB > Fitted Imputation Vocabulary and Model。

**Testing 子过程**：Apply Fold Model > Evaluate Folds。验证集仅调用训练折拟合的转换模型。

单击 CV 外层，查看：`number of validations = 5`、`stratified sampling`、`local random seed = 74219`、`create complete model = true`。返回主流程后点击顶部 **Run ▶**。

如果看到红色错误，打开底部 Problems / Log，记录具体 operator 名字和错误消息。检查 CV 内部端口和输入分区。

成功后应出现交叉验证 Performance、测试集 Performance、预测结果和最终模型。实际结果的 Accuracy、Recall(true)、Precision(true)、F1(true)、AUC、混淆矩阵截图，放入 `evidence/rapidminer/`。记录界面显示的 Recall 数值。

### 第 5 步：运行第二个模型 Gradient Boosted Trees

打开 `GradientBoostedTrees_Full.rmp`，检查 **Train GBT**。建议初始设置：

- `number of trees = 60`
- `maximal depth = 4`
- `learning rate = 0.06`
- `reproducible = true`
- `maximum number of threads = 1`
- `local random seed = 73421`

这个算子需要学校的版本含 H2O Gradient Boosted Trees。如果导入时提示 **Unknown operator** 或 `h2o:gradient_boosted_trees` 找不到，说明导出的算子标识与学校版本不兼容。请在 Operators 搜索 **Gradient Boosted Trees**，从当前软件原生拖入替换红色算子，复制参数，将前后两个端口重新连接，然后另存真正能跑的学校版 `.rmp`。不要把红色流程拍成成功截图。

双击 Five-Fold Training CV 再检查两个子过程，确认 Train GBT 位于 Training 内，Apply Fold Model 位于 Testing 内，分层设置和 75/25 与第一个模型一致。

点击 Run；记录 CV 与 Holdout 的所有实际性能指标。H2O 初次启动可能更慢，具体以学校资源为准。

### 第 6 步：运行两个模型合一的正式主程序

打开 `BISM2202_A2_rapidminer.rmp`。可以看到 NB 和 GBT 两条相互独立的分支，分别完整读取固定教师 CSV，按照同一参数得到各自 CV、Holdout 结果。点击 Run，成功后截图整个主流程以及两个模型的子过程。建议使用以下截图文件名：

```text
evidence/rapidminer/01_main_process.png
evidence/rapidminer/02_nb_cv_training.png
evidence/rapidminer/03_nb_cv_testing.png
evidence/rapidminer/04_nb_holdout_performance.png
evidence/rapidminer/05_nb_model.png
evidence/rapidminer/06_gbt_cv_training.png
evidence/rapidminer/07_gbt_cv_testing.png
evidence/rapidminer/08_gbt_holdout_performance.png
evidence/rapidminer/09_gbt_model.png
```

报告应比较**违约类召回率、Precision、F1、AUC 及误判数量**，Accuracy 只能作为辅助。将混淆矩阵中的 TP、FP、TN、FN 填入报告。

### 第 7 步：新建独立保存版，不覆盖 A/B

使用 File > Save Process As，保存为本次真实学号对应的 `学号_rapidminer.rmp`。保留旁边同级 `data/` 子目录，重新关闭、打开、执行一次，才可视为可交付。

## 四、Windows SSIS 和数据仓库完整执行

此部分必须在安装 SQL Server 2022、SSMS、Visual Studio 2022、SSIS Projects 扩展和 SSIS SDK 的 **Windows 环境** 中运行。RapidMiner 软件自身不能运行 SSIS。

### 第 1 步：把完整第三版目录拷贝到 Windows

例如 `C:\BISM2202\bism2202_a2_package\`。务必在 Mac 已执行过第 2 节的数据准备和代码生成，否则不会有 `ssis/BISM2202_A2_SSIS/WarehouseFlow.cs`。保留整个 `ssis/Support/csv` 子目录。

### 第 2 步：先恢复老师的源数据库

在 SSMS 连接到本机实例（如 `.`），Object Explorer 右键 **Databases > Restore Database... > Device > Browse**，选择 `ssis/teacher_source_backup/` 中提取的老师 `.bak`。目标数据库名应为 `ozmart_db`，Files 页面设置不冲突的 MDF/LDF 绝对路径。不覆盖现有数据库，尤其不得把源恢复到 第三版 的目标库。

完成后执行：

```sql
USE ozmart_db;
SELECT COUNT_BIG(*) AS OriginalItems FROM dbo.order_items_table;
SELECT COUNT_BIG(*) AS OriginalOrders FROM dbo.orders_table;
```

原仓库的参考数量分别是 137901 和 25000。看到不同结果时停止排查源版本。

### 第 3 步：在 SSMS 新建第三版独立数据库

打开 `sql/01_schema.sql`，按 Execute。脚本在 `[BISM2202_A2_dw]` 已存在时会拒绝覆盖。如果是重跑，先保存现有结果和备份，然后由使用者决定如何处理这个独立数据库。

打开数据库 Tables，预期看到 RefAge、RefEducation、RefState、RefSellerLocation、DimSeller、DimCustomer、DimProduct、DimDate、DimCustomerGeography、DimSellerGeography、DimOrderStatus、FactOrderItem。

### 第 4 步：运行原生 SSIS 加载器

打开 Windows PowerShell 5.1（以符合学校本地 SQL 身份的账号执行）。切换目录并运行：

```powershell
cd C:\BISM2202\bism2202_a2_package
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Warehouse-Windows.ps1
```

这一步会把四个教师原始 CSV 拷贝到 `C:\BISM2202\assignment_work\csv`，编译真实 SSIS Pipeline SDK 代码，依次运行四个参考表、各个维度以及事实表加载。SQL Server 连接使用 Windows 集成身份和 `MSOLEDBSQL`。若学校 SQL Server 使用远程实例名或 SQL 登录，先修改脚本中的连接配置。

如果执行成功，会输出 `WAREHOUSE_MASTER_RUNTIME=PASS`；同时应在 `ssis/BISM2202_A2_SSIS/` 生成 **Master.dtsx** 和真实运行日志。如果输出 FAIL，请查看执行日志。

### 第 5 步：实际查看 SSIS 设计和记录屏幕截图

生成 `.dtsx` 后，在 Visual Studio 2022 打开一个 Integration Services Project 并添加 Existing Package，选择上一步生成的 Master.dtsx；或者使用附带 `scripts/make_visual_studio_project.py` 从复制进本包的原生工程模板生成第三版 `.sln`。如 Windows 有 Python 3，可执行：

```powershell
py -3 .\scripts\make_visual_studio_project.py --package C:\BISM2202\bism2202_a2_package\ssis\BISM2202_A2_SSIS\Master.dtsx --output C:\BISM2202\bism2202_a2_package\ssis\BISM2202_A2_SSIS
```

这会创建 `.sln`、`.dtproj` 和引用真实 `Master.dtsx` 的工程文件，不会自己完成原生 SSIS 执行。如果 Windows 没有 Python，直接在 Visual Studio 新建 Integration Services Project 并添加 Existing Package。

在 Control Flow 双击每个 Data Flow，逐个检查 Source、Lookup、Derived Column、Data Conversion、Sort、Row Count、OLE DB Destination，并截图。第一次运行截图应显示真正在本机执行后的绿色成功状态；运行完成后在 Control Flow 查看各任务执行标记。至少截取 Customer、Product、Seller、Customer Geography、Seller Geography、Date、Order Status、Fact 以及总控流程。

**验收参考**：RefAge 78，RefEducation 6，RefState 8，RefSellerLocation 100，DimCustomer 21000，DimProduct 2199，DimSeller 100，DimCustomerGeography 1500，DimSellerGeography 99，DimDate 493，DimOrderStatus 6，FactOrderItem 137901；这些数字来自 A/B 固定教师数据历史执行记录，第三版 必须重新验证真实值。

### 第 6 步：执行 SQL 并截图

在 SSMS 打开 `sql/03_validation.sql`，确认维度和事实数量、销售单位数、重复/缺失/地理位置冲突。然后执行 `sql/02_queries.sql`，每个以 `GO` 分隔的查询分别返回题目所需结果。分别截取 SQL 编辑器和完整 Result Grid，确保屏幕上能看出是哪个数据库以及查询语句。

Part 1 三道问题固定，结果与 A/B 在基础销售计数上相同通常是正确的，相同源数据可能产生相同的基础统计结果。第三版另外输出 UniqueCustomers、ItemRows、卖家同期同比等上下文指标。

### 第 7 步：生成真实 `.bak` 并恢复复核

在 Windows 建立 `C:\BISM2202\deliveries`，执行 `sql/04_backup.sql`。随后在 SSMS 用 Restore Database 创建另一个隔离名字 `BISM2202_A2_RESTORE_QA`（并指定新的物理数据文件），再在恢复库重新执行表行数和查询。`RESTORE VERIFYONLY` 通过仍然不足以说明真实恢复通过。

### 第 8 步：准备上交文件

按大学要求把学号代入所有 `BISM2202_A2`，应分别提供：`学号_ssis.zip`（真实工程及 Support）、`学号_dw.bak`、`学号_dm.png`、`学号_fact.png`、`学号_rapidminer.rmp`（含相对路径数据支持）、`学号.docx`。保存程序、SQL、执行截图和参考文件。

## 五、遇到问题怎么排查

| 现象 | 首先检查 |
| --- | --- |
| Read CSV File not found | `.rmp` 同级 `data/` 是否存在，实际 CSV 路径及 `source_csv` 宏 |
| Number of examples 明显不一致 | 老师原始 CSV hash、`Loan_defaulted` 类型、有效标签过滤 |
| Unknown operator GBT | 当前大学安装的 H2O 扩展/算子版本，从 Operators 拖入本机同名算子修复 |
| Numerical to Binominal 标签变成反的 | 看原始 0/1 到 false/true 的实际映射，确认 positive class 是 true |
| CV 子流程红线或端口不连 | 双击 CV，确保 Training 模型、Testing 数据及 performance 的端口对应 |
| SQL 连接失败 | 实例是否 `.`、Windows 身份、MSOLEDBSQL、是否有数据库访问权限 |
| SSIS 找不到 DLL | 电脑是否真的安装 SQL Server 2022 SSIS Runtime 和 SDK；PowerShell 日志的 DLL 路径 |
| SSIS Error 0xC0048021 | 组件创建版本/注册不一致，检查日志中选定 DTSAdapter/DTSTransform 版本；不要重复盲目重装 |
| Teacher source backup 找不到 | 在原始 SSIS ZIP 中检查 `.bak`；当前脚本只自动提取唯一匹配的文件 |
| 数据库已有同名 第三版 | 脚本有保护机制；先备份旧库，不要随意修改脚本删除原库 |
| `.dtsx` 打不开 | 确认 Visual Studio 2022 的 SSIS Projects 插件及工程目标 2022 版本 |

## 六、每一张截图怎么截

### RapidMiner 图片 01：整体流程

1. 打开大学 RapidMiner，切换到 **Design**。
2. 用 File > Open Process 导入 `BISM2202_A2_rapidminer.rmp`。若看到红色未知算子，先按本手册第五节修复，先按第五节排查错误。
3. 让整条模型链在画布上可见：左侧 `Read Teacher Loan CSV`、`Set Label`、`Set ID`、`Remove Unknown Outcomes`、`Select Risk Predictors`、`75-25 Stratified Split`、中间 `Five-Fold Training CV`、右侧 Holdout performance。
4. 缩小画布至所有算子可见，确保没有被悬浮工具提示挡住；需要时分成两个局部截图，分别保存两个局部截图。
5. 保存 `01_main_process.png`。截图中最好能看到软件顶部标签与整个流程名称，避免裁掉所有运行软件标识。

### RapidMiner 图片 02/03：朴素贝叶斯的 CV 内部

1. 打开 `NaiveBayes_Full.rmp`，双击 `Five-Fold Training CV`。
2. 在 CV 界面打开 **Training** 标签，确认 `Training Fold Imputation`、`Training Fold Vocabulary`、`Train NB`、`Fitted Imputation Vocabulary and Model` 四步及连线；截 `02_nb_cv_training.png`。
3. 再选 **Testing** 标签，显示 `Apply Fold Model` 和 `Evaluate Folds`；截 `03_nb_cv_testing.png`。
4. 如果你看不到 Training/Testing 标签，一般是没双击进入 CV，或导入流程格式与学校版本不兼容。

### RapidMiner 图片 04/05：朴素贝叶斯真实结果

1. 返回主流程，点击绿色 Run；若学校限制了 CPU 或扩展，先记录错误并排查。
2. 切换到 **Results**，选择 `Evaluate Untouched Holdout` 的 Performance 结果。
3. 展开 **accuracy, precision, recall, F1, AUC** 和 Confusion Matrix；如界面需要滚动，可分两张截图，必须能读出违约 `true` 行列。
4. 保存为 `04_nb_holdout_performance.png`。随后点击实际模型对象，保存 `05_nb_model.png`。
5. 在自己的笔记中记录：样本数、TP、FP、TN、FN，特别是 `true` 类别 recall。报告所有数字必须取自当前机器的执行结果。

### RapidMiner 图片 06 到 09：梯度提升树

1. 打开 `GradientBoostedTrees_Full.rmp`，依次核对 **Training**、**Testing**，生成 `06_gbt_cv_training.png`、`07_gbt_cv_testing.png`。
2. 执行 Run，进入 Results 查看性能、混淆矩阵、模型对象，生成 `08_gbt_holdout_performance.png`、`09_gbt_model.png`。
3. `Unknown operator` 不应通过把算子随意换成 Random Forest 或 Decision Tree 掩盖，这会改变第三版的核心设计。请先检查版本与扩展后再考虑原生替换。

### Windows SSIS 图片 10 到 18

1. 在 Visual Studio 的 **Solution Explorer > SSIS Packages > Master.dtsx** 打开项目。
2. 在 **Control Flow** 截整体执行图，要求是真实执行后出现绿色勾的状态；保存 `10_ssis_master.png`。
3. 双击每一条 **Data Flow Task**，在 Data Flow 画布尽量同时显示 Source、Lookup / Derived Column、Data Conversion、Row Count、Destination，分别截参考表、DimCustomer、DimProduct、DimSeller、DimCustomerGeography、DimSellerGeography、DimDate、DimOrderStatus 和 FactOrderItem。
4. 如果画布太长，看不清算子和行数，请保存 **overview** 和 **detail** 两张，分别保存 overview 和 detail。
5. 如出现红色错误标记或 Destination 行数为 0，查看执行日志。

### SSMS 图片 19 到 23

1. 打开 `sql/02_queries.sql`，分别选中 Q4.1、Q4.2、Q4.3 的完整语句，点击 **Execute**。
2. 将窗口布局调整为上半部分 SQL、下半部分 **Results**，截图上要看见已连接的数据库与结果列名。
3. Q4.1 核对各州与客户年龄，Q4.2 核对每州五类，Q4.3 核对每年 NSW 供应商数量，并保存对应的三张截图。
4. 打开 `sql/03_validation.sql`，截图 FactOrderItem 的记录行数及所有维表行数；再在成功备份及独立恢复后截图还原后的结果表。

### 截图保存快捷键和质量要求

- macOS：`Command + Shift + 4` 框选，或 `Command + Shift + 5` 选择窗口与保存位置。
- Windows：`Windows + Shift + S` 截取区域；也可以用 `Alt + Print Screen` 截取活动窗口。
- 建议使用 PNG；不要压缩到字段和数值模糊，也保证字段和数字清晰可读。
- 如果某张需要的信息一页显示不完，可以拆为 `overview` 和 `detail` 两张，并在报告中写明。

## 七、填写英文 Word 报告

打开 `report/BISM2202_A2_Business_Report_DRAFT.docx`，按下面顺序更新：

1. **封面**：填写真实学号，检查课程代码、老师要求的封面和声明。
2. **Section 2.1**：放最终星型模型图。暂时的 `Warehouse_Star_PROPOSED.png` 只能代表草图，需核对真正 SQL DDL。
3. **Section 3.1 / 3.2**：插入本次 SSIS Data Flow 截图，说明数据流关键处理。
4. **Section 4**：保留三个 SQL 全文，分别插入在 SSMS 中执行的查询结果截图；核对本次查询结果。
5. **Section 5**：贴真实的 RapidMiner Overall Process、CV Training / Testing 和模型页面截图。
6. **Section 6**：把两个算法的 Accuracy、Precision、Recall、F1、AUC、TP/FP/TN/FN 填到指标表，形成基于本次实际输出的比较与推荐。
7. **Section 7**：根据模型实际表现复核行动建议和伦理问题。如果召回为零，报告必须明确说明。
8. **Section 8**：对照教师报告模板检查固定章节、分页和图表位置。
