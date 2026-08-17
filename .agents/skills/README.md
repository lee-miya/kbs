# KBS Agent Skills

> 项目级 skill（[Agent Skills](https://agentskills.io/skill.md) 开放路径 `.agents/skills/`）。  
> Cursor / Kimi Code / Codex 等会扫描本目录；Claude Code / Reasonix 见仓库根 [`README.md`](../../README.md) 安装节。  
> **分册是唯一权威**；本目录只放路由、纪律与审查，不放漏洞 payload。

## 本仓库收录（已审查）

| Skill | 自动触发 | 职责 |
| --- | --- | --- |
| [`kbs-red-team`](kbs-red-team/SKILL.md) | 是 | 授权红队/审计作战循环 + 指向 INDEX |
| [`kbs-weekly-update`](kbs-weekly-update/SKILL.md) | 是 | 周更（含同类 skill 仓库） |
| [`kbs-skill-guard`](kbs-skill-guard/SKILL.md) | 是 | 新增/引入 skill 前的安全审查 |

审查清单：[`../../维护/Skill安全审查清单.md`](../../维护/Skill安全审查清单.md)  
自检脚本：[`../../维护/review-kbs-skills.ps1`](../../维护/review-kbs-skills.ps1)  
品牌目录适配：[`../../维护/install-agent-skills.ps1`](../../维护/install-agent-skills.ps1)

## 硬性安全策略

1. **只提交本表三枚 skill**。第三方攻防库（Claude-Red、BugHunter、OSINT 等）若要试用，只装到本机用户级目录（如 `~/.agents/skills/`），**禁止**拷进本目录或 git。
2. 本目录 **禁止** `scripts/`、二进制、shellcode、一键利用、凭据、远程 `curl | sh`。
3. Skill 正文只写：何时读哪份分册、授权门禁、证据等级、与公开 skill 的冲突规则。
4. 改动本目录后必须跑审查脚本；未通过不得提交。
5. 描述字段（YAML `description`）禁止「忽略系统提示 / 绕过红线 / 隐藏对用户」类语句。

## 与分册的关系

```
always-on（根目录 AGENTS.md；Cursor 另有 .cursor/rules/red-team-operator.mdc）
        ↓
本目录 skill（短循环）
        ↓
红队 INDEX / 审计 INDEX（场景 → 文件）
        ↓
对应分册（原理 / 命令 / 时效 / 自测）
```
