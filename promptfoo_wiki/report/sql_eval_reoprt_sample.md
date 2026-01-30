## 📚 代码‑Wiki 对照检查报告  

下面按照 **“代码 ↔ 文档”** 的方式逐段对比，指出 **不一致、遗漏或可以改进的地方**，并给出 **改进建议**。  
报告采用 **红色** 标记（❌）指出问题，**绿色** 标记（✅）说明已经覆盖，**蓝色** 给出补充说明或建议。

---

## 1️⃣ 过程签名 & 参数

| 项目 | 源代码 | Wiki | 说明 |
|------|--------|------|------|
| **输入参数** | `i_NSHORIBI IN NUMBER`<br>`i_VMACHINE_NAME IN NVARCHAR2`<br>`i_NSHOKUIN_NO IN NVARCHAR2` | ✅ 正确列出并解释（处理日、端末编号、操作员个人编号） |  |
| **输出参数** | `o_NSQL_CODE OUT NUMBER`<br>`o_VSQL_MSG OUT NVARCHAR2` | ✅ 正确列出并解释（过程执行状态、错误信息） |  |
| **返回码含义** | `c_ISUCCESS = 0` (正常) <br>`c_INOT_SUCCESS = -1` (异常) <br>`c_IRETNG = 1` (业务返回码) | ✅ 正确描述 |  |

**建议**：在 Wiki 的“过程签名”小节里补上一行 **“返回码 `c_IRETNG` 在本过程里并未直接使用，仅保留供外部调用者参考”**，避免读者误以为该值会被返回。

---

## 2️⃣ 常量 & 变量

| 项目 | 源代码 | Wiki | 说明 |
|------|--------|------|------|
| `c_VTABLE` / `c_VTABLE1` | `'JIBTJUSHOHENKO_JKN_ERR'` / `'JIBWJUSHOHENKO_KEY'` | ✅ 正确列出 |  |
| `I_JICHI_KBN` | `NUMBER := 1` | ✅ 正确列出（旧自治体区分） |  |
| **控制参数** `CTLPRM1~CTLPRM9` | 9 个 `NUMBER` 变量，用于 “必填 / 自动填充” 控制 | ✅ 说明了它们是从 `KKAPK0030.FPRMSHUTOKU` 读取的 9 条开关 |  |
| **O_SHISHO_CD** | **`CHAR(3)`**（注释 `--2022/08/19 H.Furui Mod`） | ✅ 在 “返回的行政信息” 小节列出为 `CHAR(3)`，并标记了修改时间 |  |

**❌ 缺失**：  
- **每个 `CTLPRMx` 对应的业务字段** 没有在文档中逐一说明。比如 `CTLPRM1` 控制 **行政区代码** 必填，`CTLPRM2` 控制 **地区代码** 必填，… `CTLPRM9` 控制 **支所代码** 必填。  

**建议**：在“关键业务规则”或单独的 **“控制参数映射表”** 中加入：

| CTLPRM | 控制字段 | 必填标记 | 说明 |
|--------|----------|----------|------|
| 1 | `VGYOSEIKU_CD`（行政区） | `#` | 当 `CTLPRM1 = 1` 时必填，否则可为 0/空 |
| 2 | `VCHIKU_CD`（地区） | `#` | 同上 |
| … | … | … | … |
| 9 | `VSHISHO_CD`（支所） | `#` | 同上 |

---

## 3️⃣ 辅助函数/过程

| 函数/过程 | 源代码行为 | Wiki 描述 | 备注 |
|-----------|------------|----------|------|
| `EBPFCHKNUMERIC` | 判断全为数字，返回 `TRUE`，同时通过 `o_ISNULL` 标记是否为 `NULL` | ✅ 完全对应 |  |
| `EBPFCHKIKETASU` | 若 `i_IKETASU <> 0` 检查长度 ≤ 上限；若 `i_IKETASU = 0` 返回 **NULL**（未显式返回 `TRUE`） | ✅ 描述为“检查长度是否超出上限”。未提及 `i_IKETASU = 0` 时返回 `NULL` 的细节。 | **建议**：补充说明 “当上限为 0（表示不检查）时函数返回 NULL，调用者默认视为通过”。 |
| `EBPFCHKCDHENKOU` | 从 `GABTGYOSEIJOHO` 按 `GYOSEI_JOHO_KBN` 检查代码是否存在 | ✅ 正确 |  |
| `EBPFCHKCDHENKOU1` | 从 `KKATCD` 检查 **垃圾/污水业者代码**（`GYOUMUCODE='KKN'`、`CODECODE='001'`） | ✅ 正确 |  |
| `EBPFCHKSONOTA` | 检查工作表 `JIBWJUSHOHENKO_KEY` 中是否已有相同 **BF** 地址组合 | ✅ 正确 |  |
| `EBPFTOONAJIBANCHK` | 若同番冲突 (`NSQLCOUNT>0`) 在 **所有 BF 错误字段** 追加 `$` | ✅ 正确 |  |
| `PROCCLEAR` | 将 **错误记录结构体** 所有错误字段清空 | ✅ 正确 |  |

---

## 4️⃣ 主流程（Main Block）

### 4.1 初始化、表清空、参数读取  

| 步骤 | 源代码 | Wiki | 备注 |
|------|--------|------|------|
| 清空错误表 `JIBTJUSHOHENKO_JKN_ERR` | `KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM)` | ✅ 说明了“清空错误表” |  |
| 清空工作表 `JIBWJUSHOHENKO_KEY` | `KKAPK3000.FTRUNCATE(c_VTABLE1, VSQLERRM)` | ✅ 同上 |  |
| 读取 9 条控制参数 | `KKAPK0030.FPRMSHUTOKU('JIB','00JHGYOSEIJOHO','0',TACONSPRM,NPRM_LENGTH)` | ✅ 提及了 “从公共库读取 9 条业务开关” |  |
| 参数缺失默认 0 | `IF ((RTN = c_ISUCCESS) AND (TACONSPRM.LAST IS NULL)) OR (RTN = c_IRETNG) THEN …` | ✅ 说明了默认值为 0 |  |

**❌ 小细节**：Wiki 没有明确指出 **`CTLPRMx` 为 `NUMBER`，若读取失败会全部设为 `0`**（即“全部不必填、全部不自动填充”。）

### 4.2 行读取 & CSV 解析  

| 步骤 | 源代码 | Wiki | 备注 |
|------|--------|------|------|
| 读取 `JIBWJUSHOHENKO_TMP` 的 `DATA` (BLOB) | `CURSOR CFD_FILE IS SELECT A.DATA FROM JIBWJUSHOHENKO_TMP A;` | ✅ 描述为 “读取临时表 BLOB（UTF‑8 CSV）并逐行解析”。 |  |
| 通过 `DBMS_LOB.INSTR` 与 `CHR(13)` 定位每行 | 代码块 `NINDEX := DBMS_LOB.INSTR(RCFD_FILE.DATA,UTL_RAW.CAST_TO_RAW(CHR(13)),1,NCOUNT);` | ✅ 说明使用 LOB 解析并转换为 UTF‑8 → `VDATA` |  |
| 为防止列不足，行尾追加 `',,,,,…'` | `VDATA := VDATA || ',,,,,,,,,,,,,,,,,,,,,,,,,,';` | ✅ 说明了 “追加占位列” |  |
| 去除双引号 `"` | `VDATA := REPLACE(VDATA,'"','');` | ✅ 说明 |  |

**❌ 未说明**：  
- **行号计数** `NCOUNT`、`NBAK_INDEX`、`NOFFSET` 的具体作用（用于处理多行 BLOB）。  
- **每行解析完后**，`NCOUNT` 增加，`NINDEX` 再次定位下一行的逻辑。  

**建议**：在 “CSV 解析细节” 小节补充一段简要说明这些计数器的角色，帮助维护者快速定位定位错误时的行号。

### 4.3 字段逐项校验  

Wiki 对每个字段的 **数值 → 长度 → 必填 → 代码映射** 检查都给出了概览，整体覆盖良好。下面列出 **细节差异**：

| 字段 | 代码细节 | Wiki 说明 | 差异/补充 |
|------|----------|-----------|-----------|
| `BF_CITY_CD` | 必填 (无 `CTLPRM` 控制) → 代码映射 `GABTSHIKUCHOSON` | ✅ |  |
| `BF_JICHI_CD` | 必填 → 代码映射 `GABTSHIKUCHOSON`（`JICHITAI_CD`） | ✅ |  |
| `BF_OAZA_CD` | 必填 → `GABTOAZA` | ✅ |  |
| `BF_HONBAN`、`BF_EDABAN1~3` | 必填仅针对本番/枝番关联（后面关联检查），长度 5，`BF_EDABAN1~3` 为 **可选**（若非 `NULL` 才检查） | ✅ |  |
| `BF_BANCHI_HENSHU_TYPE` | 必填 (`CTLPRM8`?) → 代码映射 `GABTBANCHIHENSHU`，关联检查（>20 → 必须有 EDABAN1，>30 → 必须有 EDABAN2，>40 → 必须有 EDABAN3） | ✅ |  |
| `AF_CITY_CD`、`AF_JICHI_CD`、`AF_OAZA_CD`、`AF_HONBAN`、`AF_EDABAN1~3`、`AF_BANCHI_HENSHU_TYPE` | 同上，只是 **后置**（AF）字段的必填受 `CTLPRMx` 控制 | ✅ |  |
| `AF_YUBIN_NO` | 必填受 `CTLPRM9` 控制（注：代码中是 `CTLPRM9`，对应 **支所代码** 必填，邮编并未受 `CTLPRM9` 控制） | **❌** Wiki 把 “邮编必填受 CTLPRM9 控制” 写成了 “支所代码必填受 CTLPRM9 控制”。实际代码中 **支所代码** (`VSHISHO_CD`) 使用 `CTLPRM9`，而 **邮编** (`VAF_YUBIN_NO`) 始终必填（`BOUT_ISNULL` 检查 + `#`）。 | **建议**：将支所代码的必填说明独立出来，邮编必填不受 `CTLPRM` 控制。 |
| `VSHISHO_CD`（支所代码） | 必填受 `CTLPRM9` 控制；若 `CTLPRM9 <> 1` 且值不为 `0`/空，则视为错误（代码块 `ELSIF CTLPRM9 <> 1 AND BOUT_ISNULL = FALSE THEN …`）| ✅ 说明了 “支所代码受 CTLPRM9 控制”。 | **补充**：解释 “非必填情况下，只有值为 `0`、空或 NULL 才被接受”。 |
| `VCHIKU_CD`（地区代码） | 必填受 `CTLPRM2` 控制；非必填时若值不为 `0`/空也视为错误（同支所代码的逻辑） | ✅ 说明了 “地区代码受 CTLPRM2 控制”。 | 同上，补充 “非必填时仅 `0`、空或 NULL 可接受”。 |
| `VGYOSEIKU_CD`（行政区） | 必填受 `CTLPRM1` 控制；非必填时仅 `0`、空或 NULL 可接受 | ✅ | 同上 |
| `VHAN_CD`（班代码） | 必填受 `CTLPRM3` 控制；若 `NJOKEN=1`（从 `FCTGetR('JIB','SYSTEM_JOKEN','0001',1…)` 读取）则必须进行代码映射检查；否则仅在必填时检查 | ✅ 解释了 `NJOKEN` 用法 | **建议**：在文档中说明 `NJOKEN` 是 “系统参数 0001，控制班代码是否强制校验”。 |
| `VSHOGAKU_CD`、`VCHUGAKU_CD`、`VTOHYOKU_CD` | 必填受 `CTLPRM4~6` 控制；代码映射通过 `EBPFCHKCDHENKOU`（对应业务码 4、5、6） | ✅ |  |
| `VGOMI_CD`（垃圾业者） | 必填受 `CTLPRM7` 控制；代码映射通过 `EBPFCHKCDHENKOU1`（业务码 30） | ✅ |  |
| `VSINYO_CD`（污水业者） | 必填受 `CTLPRM8` 控制；代码映射通过 `EBPFCHKCDHENKOU1`（业务码 31） | ✅ |  |
| **关联性检查**（枝番、本番、编辑类型） | 代码块 `--BF_EDABAN1その他チェック`、`--BF_EDABAN2その他チェック`、`--BF_BANCHI_HENSHU_TYPEその他チェック` 等 | ✅ 解释为 “相関チェック”。 |  |
| **自动行政信息获取** (`JIBSKGYOSEGET`) | 仅在 **AF_OAZA_CD、AF_HONBAN、AF_EDABAN1、AF_EDABAN2** 均无错误时调用；随后依据 `CTLPRMx` 再次检查自动填充的字段是否为空 → 追加 `%` 错误 | ✅ 描述了 “地址自动填充”。 | **补充**：说明 `JIBSKGYOSEGET` 返回的 10+ 个输出（`O_GYOSEIKU_CD`、`O_HANCD`…）以及它们在错误标记中的作用（`%`）。 |
| **同番检查** | 仅当 **所有 BF 错误字段均为 NULL** 时调用 `EBPFTOONAJIBANCHK` → 如冲突则在所有 BF 错误字段追加 `$` | ✅ 正确描述 |  |

### 4.4 错误聚合 (`ERRFLG`)

| 源代码 | Wiki | 说明 |
|--------|------|------|
| 将所有错误字段的符号拼接成 `W_ERRFLG1`，遍历字符并设布尔标记 `BKIGOUFLG1~6`，最终生成 `W_ERRFLG2`（最多 10 字符），写入 `ERRFLG` | ✅ 完全描述了 “错误标识约定” 与 “聚合过程”。 |  |

**❌ 小细节**：Wiki 中没有说明 **`ERRFLG` 长度限制为 10**（代码使用 `SUBSTR(W_ERRFLG2,1,10)`）。虽然在 “错误标识约定” 提到 “最多 10 个字符”，建议在该小节再次强调 `ERRFLG` 字段实际在表中定义为 `VARCHAR2(10)`，因此超过 10 的符号会被截断。

---

## 5️⃣ 插入目标表

| 目标表 | 写入条件 | 关键字段 | Wiki 说明 |
|--------|----------|----------|-----------|
| `JIBWJUSHOHENKO_KEY` | **全部错误字段均为 NULL**（即数据合法） | BF 地址组合 (`BF_CITY_CD`, `BF_OAZA_CD`, `BF_HONBAN`, `BF_EDABAN1~3`) + 元数据 (`SYS_SAKUSEIBI`, `SYS_KOSHINBI`, `SYS_JIKAN`, `SYS_SHOKUINKOJIN_NO`, `SYS_TANMATSU_NO`) | ✅ 描述为 “写入工作表”。 |
| `JIBTJUSHOHENKO_JKN_ERR` | **任意错误字段不为 NULL** | 所有原始字段值 + 对应错误标记 (`*_ERR`) + `ERRFLG` + 同样的元数据 | ✅ 描述为 “写入错误表”。 |
| **异常处理** | `INSERT` 过程抛异常 → `ROLLBACK` 并返回 `c_INOT_SUCCESS`、`SQLERRM` | – | ✅ 说明了异常捕获并返回错误码。 |

**❌ 未说明**：  
- **`RJUSHOHENKO_JKN_ERR.RENBAN`** 为 **行号**（`NDATACOUNT`），用于错误表的行序。Wiki 中只说 “记录号”，可以补充 “对应原始 CSV 的第几行”。  

---

## 6️⃣ 事务 & 返回码

| 代码 | 行为 | Wiki |
|------|------|------|
| `COMMIT` 在全部循环结束后统一提交 | ✅ 说明了 “统一 COMMIT”。 |
| 若 **无错误** (`NERRORFLG = 0`) → `o_NSQL_CODE := c_ISUCCESS`；否则 `c_INOT_SUCCESS` | ✅ 正确描述。 |
| `EXCEPTION WHEN OTHERS THEN ROLLBACK; o_NSQL_CODE := c_INOT_SUCCESS; o_VSQL_MSG := SUBSTR(SQLERRM,1,255);` | ✅ 说明了 “异常返回 -1”。 |  

**补充**：可以在文档里标明 **`c_INOT_SUCCESS = -1` 表示“过程内部错误”，而不是业务校验失败**（业务校验失败仍返回 `c_ISUCCESS`，仅 `ERRFLG` 标记错误）。

---

## 7️⃣ 其他细节 & 潜在改进点

| 项目 | 代码中的实际行为 | Wiki 中的覆盖情况 | 建议 |
|------|------------------|-------------------|------|
| **`O_SHISHO_CD` 类型变更** | 从 `NUMBER` 改为 `CHAR(3)`（注释 `--2022/08/19 H.Furui Mod`） | ✅ 已标记为 `CHAR(3)`，但未解释为何改为字符。 | 在 “返回的行政信息” 小节补充 “支所代码改为固定 3 位字符，以兼容外部系统的编码格式”。 |
| **`NJOKEN` 读取** | `KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0001',1,o_tITEM);` → 若返回 0，则不做班代码校验 | 未在文档中出现 | 在 “班代码 (VHAN_CD) 校验” 小节加入 “`NJOKEN` 为系统参数，控制是否强制检查班代码”。 |
| **默认 `0` 处理** | 在同番检查 `EBPFTOONAJIBANCHK` 中把 `NULL` 的枝番字段设为 `0`，防止 `NULL` 与数值比较异常 | 未提及 | 在 “同番检查” 小节说明 “空枝番统一视为 0”。 |
| **`CTLPRMx` 为数字 0/1** | 0 表示 **不必填**，1 表示 **必填**；若 `CTLPRMx <> 1` 且字段非空且不为 `0`，会被视为错误（支所、地区、行政区的非必填逻辑） | 未解释 “非必填情况下仅接受 0/空”。 | 在 “控制参数” 表中加入 “`0` → 非必填（仅接受 0/空），`1` → 必填”。 |
| **`EBPFCHKIKETASU` 返回 NULL** | 当 `i_IKETASU = 0`（不检查长度）函数返回 **NULL**，调用方并未检查返回值（默认视为通过） | 文档未提到此细节 | 在函数说明中补充 “如果上限为 0，函数返回 NULL，调用者应视为长度检查通过”。 |
| **错误字段拼接顺序** | 错误标记的拼接顺序固定（`* & # @ % $`），最终 `ERRFLG` 按出现顺序聚合 | 文档只列出符号意义，未说明顺序 | 在 “错误聚合” 小节注明 “拼接顺序固定，最终 `ERRFLG` 按出现顺序保留”。 |

---

## 8️⃣ 汇总建议（文档改进清单）

1. **控制参数映射表**  
   - 添加 **`CTLPRM1~9` ↔ 业务字段** 的对应关系表（必填/自动填充）。  
   - 说明 **`0`、`1` 含义**（非必填仅接受 `0`/空）。

2. **特殊业务标志**  
   - `NJOKEN`（班代码校验开关）说明。  
   - `O_SHISHO_CD` 类型从 `NUMBER` 改为 `CHAR(3)` 的原因。  

3. **函数细节**  
   - `EBPFCHKIKETASU` 在 `i_IKETASU = 0` 时返回 `NULL`，调用者默认视为通过。  
   - `EBPFCHKNUMERIC` 的 `o_ISNULL` 语义（区别 “空值” 与 “非数字”）。  

4. **错误标识**  
   - 再次强调 `ERRFLG` 长度限制（`VARCHAR2(10)`），超出部分被截断。  
   - 说明 **拼接顺序**（`* & # @ % $`）与 **聚合规则**（只保留出现的标识）。  

5. **CSV 解析计数器**  
   - 简要解释 `NCOUNT`、`NBAK_INDEX`、`NOFFSET` 在多行 BLOB 读取中的作用。  

6. **行号 (`RENBAN`)**  
   - 明确说明它是原始 CSV 的行号（从 1 开始），用于错误报表定位。  

7. **返回码语义**  
   - 在 “返回码” 小节补充：`c_INOT_SUCCESS (-1)` 表示 **过程内部异常**（如表 truncate 失败、INSERT 异常），而 **业务校验失败** 仍返回 `c_ISUCCESS (0)`，错误信息通过 `ERRFLG` 与错误表呈现。

8. **代码块引用**  
   - 为每个关键代码块（如 “支所代码必填逻辑”）提供 **锚点**（`#支所代码`）或内部链接，方便读者快速跳转到源码对应位置。

---

## 结论

整体来看，**Wiki 已经非常完整**，覆盖了过程的 **业务目标、整体流程、关键函数、错误处理** 等核心信息。  
但在 **细节层面**（控制参数映射、特殊标志、函数返回细节、错误聚合顺序）还有提升空间。按照上面列出的 **改进清单** 进行补充后，文档将达到 **“一目了然、零歧义”** 的水平，帮助新加入的开发者快速定位、修改并安全扩展此过程。  

如需进一步细化（例如提供 **示例 CSV**、**错误表查询模板**），也可以在 Wiki 中加入相应章节。祝维护顺利 🚀!