---
name: kbs-weekly-update
description: >-
  Runs the KBS Monday weekly update: KEV/N-day, AI audit case studies, CTF
  tricks, EDR, phishing, perimeter devices, and third-party offensive skill
  library changelogs (Claude-Red, Claude-BugHunter, Claude-OSINT). Use when
  the user asks for 周更, 每周情报, weekly intel, or to scan similar GitHub
  skill repos. Follows 维护/每周更新SOP.md and never copies exploit payloads
  from third-party skills into the repo.
---

# KBS 周更

完整步骤与红线以 [`维护/每周更新SOP.md`](../../../维护/每周更新SOP.md) 与 [`维护/周更提示词.md`](../../../维护/周更提示词.md) 为准。本 skill 只强调**容易漏的两项**：大范围扫源，以及 **同类 AI 攻防 skill 仓库**。

## 执行前

1. 打开 [`维护/周更重点关注源.md`](../../../维护/周更重点关注源.md)，按 P0 → P1 勾选。
2. 产出必须符合 [`红队渗透知识库/12_每周情报/README.md`](../../../红队渗透知识库/12_每周情报/README.md) 模板（含 3.5–**3.9**）。
3. 不入库：真实目标/凭证、完整 exploit、完整免杀载荷、完整 PhaaS、第三方 skill 原文。

## 同类 skill 仓库（硬性，周报 3.9）

扫过去 7 天：Release / 默认分支 commits / README skill 表变化。源名单见关注源 **P1 · AI 攻防 Skill 库**。

每条只抽：

| 字段 | 说明 |
| --- | --- |
| 仓库 | 全名与链接 |
| 变化 | 新 skill / 新攻击面 / 工作流变化（一句话） |
| KBS 缺口？ | 我方分册是否已有；要加厚哪本 / 仅观察 |
| 安全 | 是否含完整载荷、可执行 scripts、提示注入风险 → 见审查清单 |
| 建议动作 | 写入分册对照项 / 本机 overlay（须先审查）/ 观察 / 忽略 |

禁止：把第三方 `SKILL.md` 整篇拷进 `.agents/skills/` 或分册。允许：把**漏测轴、测试顺序、适用条件**改写成 KBS 体例后写入对应分册。

引入或改本仓库 skill 前，走 [`kbs-skill-guard`](../kbs-skill-guard/SKILL.md) 并运行 `维护/review-kbs-skills.ps1`。

## 完成后

- 路线图勾选；关注源可追加高产仓库。
- `git status` 排除 `AGENTS.local.md`、`.firecrawl/`、个人笔记；按仓库约定提交推送。
