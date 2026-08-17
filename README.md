# KBS · 攻防专业知识库

给**人和 Agent 共用**的授权红队 / 代码审计知识库。

它不是 Cursor 配置仓库，也不是 exploit 收藏夹。核心是两套可复习的分册，外加一层跨工具的 Agent 作战协议：先定范围，再按 INDEX 打开 1～2 本分册，用证据等级和自测锚点收口。只收公开技术知识；不含真实目标、凭证或环境信息。仅在明确书面授权范围内使用。

| 层 | 放什么 | 权威？ |
| --- | --- | --- |
| 分册（红队 00–12 / 审计语言册） | 原理、命令、时效、自测 | **唯一权威** |
| `AGENTS.md` + `.agents/skills/` | 身份、红线、何时打开哪本 | 路由与纪律 |
| 本机 overlay（Claude-Red 等） | 漏测轴对照 | 冲突时以 KBS 分册为准 |

## 该打开哪本

| 你要做的事 | 打开 | 入口 |
| --- | --- | --- |
| 读源码找漏洞、补丁 diff、语言 sink 对照 | **代码审计** | [`代码审计知识库/INDEX.md`](代码审计知识库/INDEX.md) |
| 授权渗透全流程、打点/提权/域/C2、靶场自学 | **红队渗透** | [`红队渗透知识库/INDEX.md`](红队渗透知识库/INDEX.md)（人读：[`README.md`](红队渗透知识库/README.md)） |
| 每周追新、补缺口、改库纪律 | **维护** | [`维护/每周更新SOP.md`](维护/每周更新SOP.md) |
| 让任意兼容 Agent 按本库作战 | **Skills** | [`.agents/skills/README.md`](.agents/skills/README.md)（须先过 [`维护/Skill安全审查清单.md`](维护/Skill安全审查清单.md)） |

两库互补，不重复堆料：

- **红队**写「怎么打、怎么测、怎么复习」（场景 → 命令 → 自测）。
- **审计**写「代码里长什么样、怎么搜、怎么判」（危险特征 → 审计要点 → Checklist）。
- 同一漏洞类（如上传/反序列化）：红队 `02_Web` 练手法，审计对应语言分册挖根因；时效洞进 `09_漏洞库` / 分册「时效条目」。

## 安装

本仓库没有编译产物、没有 npm/pip 依赖。所谓安装 = **克隆 + 用 Agent 打开仓库**；技能按 [Agent Skills](https://agentskills.io/skill.md) 开放标准放在 `.agents/skills/`。

### 1. 克隆

```bash
git clone <本仓库 URL>
cd KBS
```

人读：从本 README 进两库 `INDEX.md` 即可，无需额外步骤。

### 2. 用 Agent 打开（推荐）

把仓库根目录作为工作区打开。兼容 Agent 会：

1. 读取根目录 [`AGENTS.md`](AGENTS.md)（作战身份与加载协议）
2. 自动发现 [`.agents/skills/`](.agents/skills/) 下三枚已审查 skill

| Agent | `.agents/skills/` | 还需要做什么 |
| --- | --- | --- |
| Cursor | 原生扫描 | 打开文件夹即可；另有 `.cursor/rules/` 适配器 |
| Kimi Code（kimicode） | 原生扫描 | 在仓库根启动即可 |
| Codex / Copilot CLI 等 | 通常扫描 | 打开仓库即可 |
| Reasonix | 默认扫 `.reasonix/skills/` 与 `.claude/skills/` | 跑下面的适配脚本，或先读 `AGENTS.md` 再按需打开 skill |
| Claude Code | 默认扫 `.claude/skills/` | 跑下面的适配脚本 |

### 3. 品牌目录适配（仅当 Agent 不扫 `.agents/skills/`）

在仓库根执行：

```powershell
powershell -NoProfile -File 维护/install-agent-skills.ps1
```

脚本会在本机创建指向 `.agents/skills/` 的 junction / 符号链接（`.claude/skills`、`.reasonix/skills`）。这些品牌目录已 gitignore，**不要提交**。

Unix：

```bash
mkdir -p .claude .reasonix
ln -s ../.agents/skills .claude/skills
ln -s ../.agents/skills .reasonix/skills
```

可选自检（改 skill 后必须跑）：

```powershell
powershell -NoProfile -File 维护/review-kbs-skills.ps1
```

### 4. 不要做的事

- 不要把第三方攻防 skill 库（Claude-Red 等）拷进 `.agents/skills/` 或 git。
- 不要把本机 `AGENTS.local.md`、`.firecrawl/`、`个人笔记/` 提交上去。
- 完整 exploit / 免杀载荷 / PhaaS 套件不入库、不作为「安装内容」。

## 目录一览

```
KBS/
├── README.md                 ← 你在这里
├── AGENTS.md                 ← 跨 Agent 作战指南（入仓）
├── AGENTS.local.md           ← 本地工作记忆（gitignore）
├── .agents/skills/           ← 已审查的路由 / 周更 / skill 审查
├── 代码审计知识库/            ← 语言分册 + INDEX 速查
├── 红队渗透知识库/            ← INDEX 作战入口 + 00–12 分册
├── 维护/                     ← SOP、关注源、路线图、体例、隐私清单、安装/审查脚本
└── 个人笔记/                 ← 本地未脱敏笔记（gitignore）
```

## 学习 / 复习路径（最短）

1. 红队：`11_自学体系/01-能力自测清单.md` 自评 → 按链接精读 → 做文末「自测锚点」。
2. 审计：`INDEX.md` 选语言分册 + 必读 `通用审计方法论.md` → 跑文末 Checklist。
3. 临场：红队 `INDEX.md` → 对应分册；审计 `INDEX` 高频速查表。
4. 追新：每周一看红队 `12_每周情报`（含同类 skill 库 3.9）；审计新模式直接在各分册「时效条目」。

分册写法统一约定见 [`维护/文档体例约定.md`](维护/文档体例约定.md)。

## 给 Agent 用（作战而不是闲聊）

1. **Always-on**：根目录 `AGENTS.md`（所有 Agent）。Cursor 额外加载 `.cursor/rules/red-team-operator.mdc` 与 `kb-maintenance.mdc`。
2. **Skills**：`.agents/skills/` 三枚（作战路由、周更、skill 审查）。第三方 overlay 只装本机用户级目录（如 `~/.agents/skills/`），须先过审查清单。
3. **知识**：红队/审计 `INDEX.md` → 分册。Skills 不替代分册。
4. 改 skill 后运行 `维护/review-kbs-skills.ps1`。

## 先进性（每周一）

| 产物 | 位置 |
| --- | --- |
| 渗透周报 | `红队渗透知识库/12_每周情报/YYYY-MM-DD_每周渗透情报.md`（含 CTF/免杀/钓鱼/**边界 3.8** / **skill 库 3.9**） |
| 审计新模式 | **直接**写入对应分册「时效条目」（无单独增量目录） |
| AI 审计案例精析 | 综合分册「五」+ 可迁移纪律 → 通用方法论「十一」 |
| 红队回链 | `09_漏洞库`（含 **09-03 边界**）/ `10_工具速查` / `03-02` 等 |

周更须**大范围**覆盖专家博客、厂商实验室、论坛等，清单见 [`维护/周更重点关注源.md`](维护/周更重点关注源.md)。权威版本永远是**分册**。详情：[`维护/每周更新SOP.md`](维护/每周更新SOP.md)。缺口优先级：[`维护/内容缺口与补充路线图.md`](维护/内容缺口与补充路线图.md)。

## 红线（摘要）

- 不入库：真实域名/IP/凭证/内部组织名、可直接打穿生产的完整 exploit 载荷、未脱敏个人实战笔记。
- 要入库：原理、利用条件、识别特征、审计/作战要点、公开链接。
- 单一来源未经厂商证实 → 标注「待核实」。
- 提交前自检：[`维护/隐私与脱敏排查清单.md`](维护/隐私与脱敏排查清单.md)。
