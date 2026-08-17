# KBS · 攻防专业知识库

个人学习 / 复习 / 授权测试用的公开技术知识库，覆盖**代码审计**与**红队渗透**全流程。  
仅在明确书面授权范围内使用。

## 该打开哪本库

| 你要做的事 | 打开 | 入口 |
| --- | --- | --- |
| 读源码找漏洞、补丁 diff、语言 sink 对照 | **代码审计** | [`代码审计知识库/INDEX.md`](代码审计知识库/INDEX.md) |
| 授权渗透全流程、打点/提权/域/C2、靶场自学 | **红队渗透** | [`红队渗透知识库/INDEX.md`](红队渗透知识库/INDEX.md)（人读导航：[`README.md`](红队渗透知识库/README.md)） |
| 每周追新、补缺口、改库纪律 | **维护** | [`维护/每周更新SOP.md`](维护/每周更新SOP.md) |

两库互补，不重复堆料：

- **红队**写「怎么打、怎么测、怎么复习」（场景 → 命令 → 自测）。
- **审计**写「代码里长什么样、怎么搜、怎么判」（危险特征 → 审计要点 → Checklist）。
- 同一漏洞类（如上传/反序列化）：红队 `02_Web` 练手法，审计对应语言分册挖根因；时效洞进 `09_漏洞库` / 分册「时效条目」。

## 安装

本仓库是 Markdown 知识库，没有编译步骤，也没有 npm / pip 依赖。

```bash
git clone <本仓库 URL>
cd KBS
```

人读：从本文件进入两库 `INDEX.md` 即可。

若用 AI Agent（Cursor、Kimi Code、Reasonix、Claude Code、Codex 等）打开本仓库：

1. 把仓库根目录作为工作区。
2. 兼容 [Agent Skills](https://agentskills.io/skill.md) 的工具会自动加载 [`.agents/skills/`](.agents/skills/README.md)。
3. Cursor、Kimi Code 会直接扫描该目录；Claude Code、Reasonix 若未扫描到，在仓库根执行一次适配：

```powershell
powershell -NoProfile -File 维护/install-agent-skills.ps1
```

Unix 可用符号链接代替：

```bash
mkdir -p .claude .reasonix
ln -s ../.agents/skills .claude/skills
ln -s ../.agents/skills .reasonix/skills
```

公开入口是两库 `INDEX.md` 与 [`.agents/skills/`](.agents/skills/README.md)。本机可另放 `AGENTS.md`（不入库）。

## 目录一览

```
KBS/
├── README.md                 ← 你在这里
├── .agents/skills/           ← 项目级 Agent Skills
├── 代码审计知识库/            ← 语言分册 + INDEX 速查
├── 红队渗透知识库/            ← INDEX 作战入口 + 00–12 分册
└── 维护/                     ← SOP、关注源、路线图、体例
```

## 学习 / 复习路径（最短）

1. 红队：`11_自学体系/01-能力自测清单.md` 自评 → 按链接精读 → 做文末「自测锚点」。
2. 审计：`INDEX.md` 选语言分册 + 必读 `通用审计方法论.md` → 跑文末 Checklist。
3. 临场：红队 `INDEX.md` → 对应分册；审计 `INDEX` 高频速查表。
4. 追新：每周一看红队 `12_每周情报`；审计新模式在各分册「时效条目」。

分册写法见 [`维护/文档体例约定.md`](维护/文档体例约定.md)。

## 每周更新

| 产物 | 位置 |
| --- | --- |
| 渗透周报 | `红队渗透知识库/12_每周情报/` |
| 审计新模式 | 对应分册文末「时效条目」 |
| AI 审计案例 | 综合分册「五」+ 通用方法论「十一」 |

流程与关注源：[`维护/每周更新SOP.md`](维护/每周更新SOP.md)、[`维护/周更重点关注源.md`](维护/周更重点关注源.md)。缺口优先级：[`维护/内容缺口与补充路线图.md`](维护/内容缺口与补充路线图.md)。
