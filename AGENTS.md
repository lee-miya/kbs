# AGENTS.md · KBS 跨 Agent 作战指南

> 入仓文件。任意兼容 Agent（Cursor / Kimi Code / Reasonix / Claude Code / Codex 等）打开本仓库时先读本文。  
> 本地工作记忆写在 `AGENTS.local.md`（gitignore，勿提交）。

## 概览

- **定位**：个人攻防专业知识库（学习 / 复习 / 授权测试），同时是 Agent 的作战手册，而不是通识聊天。
- **双库分工**：审计 = 源码/模式；红队 = 场景/命令/自学；维护 = 周更与体例。
- **红线**：公开知识 only；无真实目标/凭证；无完整生产级 exploit / 免杀载荷 / PhaaS 套件。
- **权威**：分册是唯一权威。Skill 只做路由与门禁，禁止把分册正文复制进 `SKILL.md`。

## 加载协议（每轮会话）

1. 读本文；若存在 `AGENTS.local.md` 再读本地进展。
2. 按任务打开 **1 个** INDEX：红队 [`红队渗透知识库/INDEX.md`](红队渗透知识库/INDEX.md) 或审计 [`代码审计知识库/INDEX.md`](代码审计知识库/INDEX.md)。
3. 再打开 **最多 1～2 本**分册。禁止整库塞进上下文。
4. 对具体目标发包前必须有书面授权与范围；没有则只讲公开原理与靶场/虚构示例。
5. 结论标证据等级：C 假设 / B sink 或行为可达 / A 授权范围内最小证明。对照分册「自测锚点」才可声称该能力完成。
6. 第三方 overlay skill（Claude-Red 等）只作漏测轴对照；与 KBS **红线 / 时效 / 选型**冲突时以分册为准。

## 结构

```
README.md                 # 人读总入口 + 安装
AGENTS.md                 # 本文件（跨 Agent 作战指南）
AGENTS.local.md           # 本地工作记忆（勿提交）
.agents/skills/           # 已审查：kbs-red-team / kbs-weekly-update / kbs-skill-guard
代码审计知识库/            # INDEX + 语言分册 + 时效条目
红队渗透知识库/            # INDEX + 00–12 分册 + 每周情报
维护/                     # SOP、关注源、体例、路线图、隐私清单、skill 审查
个人笔记/                 # gitignore；未脱敏实战笔记
```

Cursor 另有 `.cursor/rules/` 适配器（`red-team-operator.mdc` + `kb-maintenance.mdc` 入仓）。其他 Agent 以本文 + `.agents/skills/` 为准，不必依赖 `.cursor/`。

## Skills

项目级 skill 只放 [`.agents/skills/`](.agents/skills/README.md)（Agent Skills 开放标准路径）。

| Skill | 何时用 |
| --- | --- |
| `kbs-red-team` | 授权红队 / 渗透 / 审计作战 |
| `kbs-weekly-update` | 周更、每周情报、同类 skill 库扫描 |
| `kbs-skill-guard` | 新建/引入 skill 前的安全审查 |

改 skill 后必须运行 `维护/review-kbs-skills.ps1`。第三方 `SKILL.md` **禁止**拷进本仓库。

不扫描 `.agents/skills/` 的 Agent（如部分 Claude Code / Reasonix 品牌目录）见 [`README.md`](README.md)「安装」一节，运行 `维护/install-agent-skills.ps1` 做本地 junction。

## 约定

- 面向用户用简体中文；代码、路径、CVE、工具名可英文。
- 不入库真实域名/IP/凭证/内部组织名。提交前过 [`维护/隐私与脱敏排查清单.md`](维护/隐私与脱敏排查清单.md)。
- 分册体例：[`维护/文档体例约定.md`](维护/文档体例约定.md)。不要再创建 `增量池/`。
- 06-01 = C2/流量；06-02 = 主机免杀；03-01 = 钓鱼；03-02 / 09-03 = 边界打点。

## 进展（稳定摘要）

| 时间 | 状态 | 说明 |
| --- | --- | --- |
| 2026-08-17 | 已完成 | Agent 作战层：INDEX + 三枚 skill + 周更 3.9 |
| 2026-08-17 | 已完成 | skill 迁到 `.agents/skills/`；`AGENTS.md` 入仓；多 Agent 安装说明 |
| 下一步 | 进行中 | 国产 VPN 门户通告；UIUCTF 官方 WP；AD CS 武器化；提权/维持分册加厚 |

细进度与本机备注写 `AGENTS.local.md`。
