# C2 框架与 EDR 对抗

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

## 4. 载荷与免杀（主机侧对抗）

### 检测点与对策
| 检测点 | 对策 |
| --- | --- |
| 文件静态查杀 | 无文件（powershell/反射加载）、加壳混淆（ConfuserEx/VMProtect）、分离加载（payload 加密存远程） |
| AMSI（脚本扫描） | amsi.dll 内存补丁（amsiPatch）、降级 powershell v2、改用 .NET 程序集绕过脚本宿主 |
| 内存扫描 | sleep 混淆（Ekko/Foliage 加密自身内存）、beacon 异构执行（BOF 代替 spawn） |
| 行为链 | 父进程伪装（PPID spoofing）、命令行参数欺骗、避免 lsass 直连（用合法工具 dump） |
| ETW | ETW 内存补丁（Patch EtwEventWrite） |
| Syscall 监控 | 直接/间接系统调用（HellsGate/Halo's Gate/TartarusGate）跳过用户态 hook |

### 典型免杀 loader 流程（理解原理，不追求特定代码）
```text
加密 shellcode（AES/XOR+key 分离）
→ loader（C/C++/C#/Go/Rust/Nim）申请内存（VirtualAlloc 改 NtAllocateVirtualMemory）
→ 解密 → 执行（CreateThread → 改 NtCreateThreadEx / 回调函数执行 / fiber）
→ 可选：AMSI/ETW patch + sleep 混淆
```

命令行快速验证思路（C# 例）：
```powershell
# donut 把 exe/dll 转 shellcode
donut -f x64 -a 2 payload.exe -o payload.bin
# sRDI / pezor / Freeze 等链式工具组合
```

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
- [ ] 能说清 AMSI、ETW、用户态 hook 三类检测的差异与对应绕过思路。
- [ ] 能基于任一开源 loader 改出一个过 Windows Defender 的上线载荷（本地验证）。
