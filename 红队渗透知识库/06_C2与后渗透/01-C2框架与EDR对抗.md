# C2 框架与 EDR 对抗

> 主机侧免杀矩阵、loader 管线、周更时效见专册 [`02-免杀与载荷对抗.md`](02-免杀与载荷对抗.md)。本册侧重框架选型、流量基建与上线后作业纪律。

## 1. 知识点讲解

C2（Command & Control）= 被控端（beacon/agent）与控制端（teamserver/listener）之间的持久通道。红队三要素：上线（载荷不被杀）、通联（流量不被识别）、作业（动作不被告警）。EDR 对抗的本质：理解检测点（文件、内存、行为、流量）并逐项降噪，而不是追求「永远不杀」。
## 2. 框架选型对比

| 框架 | 形态 | 优点 | 短板 | 适用 |
| --- | --- | --- | --- | --- |
| Cobalt Strike | 商业 | 生态最全（BOF/Aggressor）、malleable C2 流量塑形 | 特征被全行业盯防，需深度免杀 | 主力作战 |
| Sliver | 开源(BishopFox) | Go 跨平台、mTLS/HTTP/DNS 多协议、免费 | 中文资料少 | 个人/演练 |
| Mythic | 开源 | 模块化 agent（Apollo/Poseidon…）、UI 现代 | 部署重 | 长期项目 |
| Havoc | 开源 | 轻量、demon agent 免杀底子好 | 社区较小 | 快速试验 |
| Metasploit | 开源 |  exploit 库无敌、meterpreter 全 | 流量与载荷特征老 | 漏洞利用+临时会话 |
| 自研/微型 loader | — | 特征最少 | 开发成本高 | 高对抗环境 |

## 3. 基础设施（流量侧对抗）

```text
目标 → [CDN/域前置] → 重定向器(redirector) → teamserver（永不暴露）
```

- 重定向器：nginx/apache 反代，只放行符合 malleable profile 的 URI/UA，其余转正常网站（搅浑水）。
- 域前置（domain fronting）：借大厂 CDN 域名掩盖真实 C2；注意多数云商已限制跨域前置，选可自定义 Host 的 CDN 或改用「合法云函数/云存储」做中转（C2 via 云 API）。
- Malleable C2 profile：把 beacon 流量伪装成 jquery cdn、google analytics 等，URI、UA、header、元数据隐写位置全部自定义。
- 多 listener 冗余：HTTPS 主通道 + DNS 慢速备用通道（dnscat2/iodine 思维）。

## 4. 载荷与免杀（摘要 · 详册见 02）

主机侧检测点矩阵、loader 六段管线、环境决策表与**周更时效条目**已迁至 [`02-免杀与载荷对抗.md`](02-免杀与载荷对抗.md)。此处只留与 C2 上线直接相关的最小提醒：

- 上线前：同版本 Defender/目标 EDR 本地实测，先判「死因」再改层。
- 制备：`donut`/`sRDI` 等只负责 PE→shellcode，**不等于免杀**。
- 作业：BOF / 少 spawn；流量塑形仍用本章 §3。

## 5. 上线后的作业纪律（防告警）
- 先 `ps`/`getsystem`/`mimikatz` 三连是最响的行为链；换成 BOF/合法管理工具组合。
- 不主动扫内网：靠 BloodHound 离线分析结果定点打，不在被控机上跑扫描器。
- 文件操作走 beacon 原生命令（有 opsec 提示），少 spawn cmd/powershell。
- 重要操作（DCSync、金票）挑工作时间外的低峰，减少 SOC 肉眼发现概率。

## 6. 应急：上线被杀/通道被封怎么办

1. 判断死因：静态杀（换 loader）还是行为杀（换打法）还是流量杀（换通道/profile）。
2. 永远准备 B 计划通道与 C 计划持久化（07 分册）。
3. 复盘特征提交到知识库 `09` 或 `12`，避免同环境二次踩坑。

## 自测锚点
- [ ] 能画出「CDN→重定向器→teamserver」架构并解释每一跳的作用。
- [ ] 能说清 malleable profile 与重定向器如何降低流量侧检出。
- [ ] 主机侧 AMSI/ETW/hook/loader 自测转到 [`02-免杀与载荷对抗.md`](02-免杀与载荷对抗.md) 文末锚点。
