# 综合分册：AI 漏洞挖掘 · 漏洞态势 · AI 应用自身安全

> **定位**：跨语言综合分册——
> 一、AI 漏洞挖掘的工具与方法论（借鉴"怎么挖"）；
> 二、窗口期漏洞态势（校准审计优先级）；
> 三、AI 应用自身安全（新审计对象）；
> 四、CTF 拾遗；
> 五、**AI 审计案例提炼**（周更硬性：拆管线/提示词/验证闭环 → 可迁移纪律）。
> **时效规则**：条目按批次排列，标注时间窗；单一来源未经厂商证实的条目标注"待核实"。
> **入库红线**：仅公开研究；域名/IP/凭证/IOC/可直接复用载荷不入库。
> 版本：v1.7（2026-08-15 晚间：Nabi AI 拾遗；Gunra/Fortinet 与 Ivanti EPM 跟踪）

---

## 一、AI 漏洞挖掘：重大突破与工具方法论

### 1-1 厂商级 AI 挖洞规模化落地：Oracle 7×24 双模型审计体系（2026-07）

- Oracle 2026 年 7 月 CPU 刷新纪录（1449 个补丁、1235 个 CVE、EBS 410 个、Fusion Middleware 355 个），官方首次公开承认漏洞挖掘体系完成 **AI 规模化落地**，配套月度 CSPU（每月第三个星期二，仅收 Critical/可远程利用项）与季度 CPU 双轨补丁机制。
- 技术架构：全产品线代码仓库经可信通道（Trusted Access for Cyber）接入**双大模型并行引擎**（Anthropic Claude Mythos 安全专项模型 + OpenAI 顶级模型），7×24 全量审计；专项模型 CyberGym 检出准确率 83.1%（单一来源，供参考）。
- 三个超越传统手段的能力：**全域遍历**（含冷门/遗留代码）、**自主构造载荷验证可利用性**（600+ 无认证远程漏洞由 AI 完成可用性验证）、**挖掘 5 年以上潜伏零日**。近四成漏洞源于第三方组件。
- 攻防连锁反应：漏洞公开到批量入侵窗口被压缩至 **72 小时以内**——这是补丁从季度改月度的直接动因。
- **启示**：「AI 全量遍历 + 人工精审热点」将成为标准分工；历史遗留代码（5 年+）是 AI 挖洞高产区；修复 SLA 按 72 小时窗口重设计。

### 1-2 微软补丁量创纪录背后的同一逻辑（2026-07-15）

- 微软 7 月修复 622 枚漏洞（Windows 416 枚，约去年同期 3 倍）；Windows 部门负责人公开指出 AI 代理已具备自主识别安全漏洞的能力。补丁量暴涨是全行业现象（详见二-3）。

### 1-3 多智能体协作挖洞：攻破 52% 测试目标（2026-07-29/30）

- 多所高校联合研究：多智能体组成"黑客团队"，按**侦察、分析、利用**分工协作，攻破 52% 测试目标；多智能体在多步推理、多工具配合的复杂场景显著优于单模型。论文已公开，代码待发布。
- **方法论价值**：分工角色化（Recon/Analysis/Exploit）+ 共享状态记忆，是当前 AI 渗透系统主流架构。

### 1-4 商用系统：绿盟智能渗透系统 AI-PTS 2.0（2026-07-16）

- 端到端自主渗透闭环（任务规划 → 资产测绘 → 漏洞分析 → 攻击验证 → 报告）；底层 GLM-5.2（1M 无损上下文、自主工具创造）；强调**全流程业务时序推演挖掘业务逻辑漏洞**——自动化渗透从"按规则执行"转向"按目标推理"。
- **启示**：业务逻辑漏洞（越权、流程绕过、状态机缺陷）正成为 AI 工具下一个主攻方向，恰是传统扫描器盲区。

### 1-5 生产级方法论样本：GitHub Security Lab Taskflow Agent（2026-07-01 更新）

- 定位：对 CodeQL 告警做**自动化分拣（triage）**，复杂研判流程拆成 YAML 描述的离散任务（taskflow），由 LLM 逐项执行。
- 关键洞察：误报多源于"人类一眼看出、形式化规则极难表达"的**模糊模式**（鉴权缺失、净化是否充分），恰是 LLM 强项。
- 工程要点：MCP 服务器承担程序化子任务、中间状态落库便于调试迭代。
- 战果：对 GitHub Actions 与 JS/TS 项目分拣出约 30 个真实漏洞；对 **Auth Bypass、IDOR、Token 泄露**等高影响类型尤其有效。
- **启示**：「SAST 粗筛 + LLM 精判模糊模式」是当前投入产出比最高的 AI 审计落地形态；任务拆解文件化（YAML）保证可复现、可审计。

### 1-6 开源与商业工具方法论补遗

- **DeepAudit（开源）**：Multi-Agent 流水线——Orchestrator 定策略 → Recon 识别技术栈与攻击面 → Analysis 深度分析 → **Verification Agent 沙箱验证漏洞真实性**；支持跨方法联合审计（沿调用关系追校验函数）。"验证 Agent 进沙箱"是压误报的关键设计。（2026-01）
- **Codex Security（原 Aardvark）**：三阶段管线——扫描 → 隔离环境验证 → 修复建议；公开数据：扫描 120 万+ commit，识别 792 critical、10561 high。（2026-06 横评）
- **CodeQL + Copilot Autofix**：有修复建议的漏洞修复提速约 3 倍（XSS 7 倍、SQLi 12 倍）——"AI 修复"比"AI 发现"更快兑现价值。
- **AI 辅助逆向**：x64dbg + MCP（x64dbg-automate 插件）让大模型直接驱动调试器做样本自动化逆向——AI 分析能力向二进制场景延伸。（2026-07-25）

---

## 二、窗口期漏洞态势（2026-07 批次）

### 2-1 奇安信《2026 年中网络安全漏洞威胁态势研究报告》（2026-07-24）

- 核心判断：2026 上半年进入"**AI 深度博弈**"阶段——漏洞生命周期被极度压缩；新增漏洞爆发式增长，"**高危 + AI 诱导**"型显著增加；攻击面向"云原生 + 智能终端"倾斜；供应链攻击与勒索结合更紧密。
- 入库价值：作为各分册模式条目的宏观印证，按此校准下半年审计优先级。

### 2-2 2026 攻防赛事漏洞类型总结：AI 时代的攻击面迁移（2026-07-18，高价值）

1. 提示词注入漏洞减少（防护成熟），**大模型 Web 应用与 Agent 安全成为新突破口**；
2. **前端 JS 代码挖洞数量明显增加**；
3. 国产中间件漏洞因公开工具增多而出洞率上升；
4. 客户端与边界设备漏洞挖掘门槛因 AI 辅助显著降低；
5. 传统 Web 漏洞仍在，但需**组合利用**才有杀伤力；
6. **红队经验判断与复杂场景分析仍是 AI 难以替代的核心能力**。
- 入库价值：直接指导技能投资方向——AI 工具链使用能力 + 业务逻辑/组合链思维。

### 2-3 微软 7 月补丁日：622 枚漏洞、Windows 内核 EoP 集群（2026-07-14/15）

- 单月 622 枚创纪录；Win32k 一族 EoP 集中（7.8～8.8 分多枚）、srvnet.sys RCE、BitLocker 物理绕过。
- 内核方向审计关注：Win32k 句柄/对象引用计数、GDI 对象生命周期；驱动 IOCTL 输入校验与 double fetch。

### 2-4 云与身份设施快报（均标注核实状态）

- **Azure Key Vault 认证绕过（CVE-2026-62825，CVSS 10.0）**：2026-07-25 中文预警称可无认证访问 Secrets/Keys/Certificates，官方补丁未出；**仅单一公众号来源，未经微软公告交叉证实，使用前请先核实**。缓解：关公网、Private Endpoint、强化日志。
- **AD CS 域提权"Certighost"（CVE-2026-54121）**：2026-07-25 深度分析出现，延续 ESC 家族演化，细节下期补充。
- **SharePoint 链式漏洞**：CVE-2026-55040 认证绕过（7 月补丁）+ embargo 中第二环，组合为未授权 RCE，8 月补丁日重点跟踪。

---

## 三、AI 应用自身安全（新审计对象）

### 3-1 AI Agent 平台漏洞模式三态（OpenClaw 三连 RCE 复盘，2026-04 披露、7 月仍高频引用）

1. **请求流注入**：不对上游 API 请求做完整性校验 → 恶意中转污染请求流（提示词注入）→ 模型被诱导生成恶意命令 → MCP 工具链自动执行（CVE-2026-30741，CVSS 9.8）；
2. **插件自动加载**：工作区插件无校验加载即执行（CVE-2026-32920，CVSS 9.2）——"信任本地目录内容"是通病；
3. **跨站 WebSocket 劫持**：WS 未校验 Origin → 钓鱼页劫持 Agent 会话（CVE-2026-25253，CVSS 8.8）。
- **审计要点**：审 Agent 平台 = 审三条信任边界（模型输入完整性、本地插件加载、WS/IPC 来源校验）。
- 关联事件（2026-07-19）：大模型客户端"过度激进执行"误删用户文件——**执行层防护（沙箱 + 危险操作二次确认）是硬性要求**。

### 3-2 AI 应用渗透测试分类框架（OWASP LLM Top10 对齐，2026 上半年成型）

- 八类：提示词注入（LLM01）、敏感信息泄露（LLM02）、SSRF（LLM05）、工具调用越权/未授权访问（LLM06）、多轮记忆污染、插件供应链（LLM10）等；每类配套"复现步骤 + Payload 族 + 修复建议"报告结构。
- 入库价值：可直接复用做 AI 应用审计 checklist；其中**多轮记忆污染**（恶意指令写入长期记忆持续生效）与**工具调用越权**是普通用户可达、传统 Web 审计覆盖不到的新类目。

### 3-3 LLM 自身红队工具

- **Garak 0.15.0**（2026-05）：新增多轮 GOAT 探针、Agent-breaker 工具滥用探针、系统提示词提取探针。
- **PyRIT** 的 `XPIAOrchestrator`：专攻**跨域间接提示词注入**（恶意指令埋进文档库/邮件/网页等外部数据源）。

### 3-4 低代码 / Agent 执行面：Langflow 未授权 RCE（CVE-2026-9198，2026-08）

- 默认部署链式缺陷：`auto_login` 向任意网络调用者签发 SUPERUSER → `validate/code` 执行用户代码。已入 CISA KEV。
- **审计清单（通杀 AI 工作流平台）**：① 列出一切「执行代码/运行工具」API；② 默认鉴权是否可关、是否只绑回环；③ 代码在「校验期」是否已有副作用（装饰器/默认参数）；④ 升级与暴露面收敛优先于「加 WAF」。
- 同期对照：Azure SRE Agent OBO 越权（CVE-2026-62830）——审「代理身份」的委托边界与 Scope Change。

---

## 四、CTF 拾遗（2026-07 批次 + 2026-08-12 / 08-15 追加，晚间补 Nabi AI）

- **Crypto**：低指数攻击（e 过小开方/广播攻击）与密钥流重用（异或消 keystream）仍是送分点也是失分点；
- **Web 通用**：JWT 三件套（alg=none、弱密钥爆破、HS/RS 混淆）出场率依旧最高；
- **方法论**：多篇 writeup 体现"先威胁建模再动手"趋势——先列信任边界与状态机再选测试点，比上来就 fuzz 效率高。

### 2026-08-12 · CRLF Header Injection → Desync（来源：PortSwigger / TurtleSec）

- **技巧**：把「头注入」当成可拆 HTTP 流的原语，升格为 Request Splitting / CL.TE / 浏览器侧锁定 desync，而非停在 XSS/跳转。
- **适用面**：Web | 协议 | CDN 前后端差异
- **迁移价值**：审计危险特征（头拼接未剥 CRLF）；红队打点条件（反代+连接复用）
- **识别与自测**：输入是否进入下游请求头；投换行后是否出现「第二个请求」语义；对比前后端解析
- **局限**：完整蠕虫化链路依赖特定基础设施，生产验证须授权且最小化
- **链接**：https://portswigger.net/research/crlf-powered-desync-attacks

### 2026-08-12 · PyInstaller 冻结常量已知明文还原 XOR（来源：看雪 KCTF2602）

- **技巧**：`enc ⊕ UTF-8(可见提示串)` 还原短循环 key；entry pyc 可能是诱饵，真逻辑在加密 code object
- **适用面**：Reverse | 恶意样本初析
- **迁移价值**：仅赛题/样本分析向；标注**迁移有限**
- **识别与自测**：PyInstaller onefile；常量区有「成功/提示」类明密对
- **链接**：https://bbs.kanxue.com/thread-292455.htm

### 2026-08-12 · Apache Fury 黑名单不全 + 关类注册 → 写文件链（来源：AliCTF 2026 SU · Fileury）

- **技巧**：`requireClassRegistration(false)` 时仅靠 deny list 不够；AspectJ `StoreableCachingMap` + CC LazyMap/TiedMapEntry 可走任意路径写文件
- **适用面**：Java 反序列化 | 审计
- **迁移价值**：**审计危险特征**——生产必须 allowlist；写文件链与 RCE 同级
- **识别与自测**：搜 Fury builder / disallowed 列表；classpath 是否含 AspectJ/CC
- **局限**：WP 非近 7 日新放（复扫升格）；不入库完整 PoC
- **链接**：https://www.ctfiot.com/295357.html

### 2026-08-15 · `cleanPath` 双条件不正交 + `///` 空段（来源：看雪 2026 软安赛 Web）

- **技巧**：`path.contains("..") && StringUtils.cleanPath(path).contains("../")` 两谓词语义不同；`///` 产生空路径段，规范化结果可不含 `../`，从而绕过第二段。
- **适用面**：Web | Java（Spring WebFlux `FileSystemResource` 静态目录）
- **迁移价值**：**审计危险特征**——路径安全检查必须在**同一规范化结果**上做；「先脏检查再 clean 再脏检查」常不正交
- **识别与自测**：搜 `cleanPath` / `contains("..")` 组合；静态资源是否绑文件系统目录；投多余斜杠后规范化串是否仍含穿越语义
- **局限**：赛题 WP 非近 7 日首发（复扫升格）；不入库完整穿越载荷
- **链接**：https://bbs.kanxue.com/thread-290978.htm

### 2026-08-15 · dangling-byte：缺 1 字节推迟第二响应（来源：PortSwigger HTTP Terminator）

- **技巧**：走私/拆分场景下让第二条请求缺最后 1 字节，后端不立刻产出第二响应，等受害者请求补齐后再出队——消掉 stacked-response 竞态
- **适用面**：Web | 协议 | 反代连接复用
- **迁移价值**：**红队+审计**——「部分请求」是武器化原语；审计侧关注前后端是否复用连接、是否按完整报文切分
- **识别与自测**：授权环境对比「完整走私」与「少 1 字节」时第二响应何时出现；禁止对未授权目标做体积扫描
- **局限**：依赖 method-agnostic 后端等部署组合；不写完整 RQP 链
- **链接**：https://portswigger.net/research/http-terminator

### 2026-08-15 · deprecated 仍接线 + Vault `+` 单段通配（来源：UIUCTF 2026 · Nabi AI）

- **技巧**：源码图里的弃用可选字段若服务端仍读取，可把上游 URL 指到 webhook 带走 `X-Vault-Token`；Vault/OpenBao ACL 的 `+` 匹配**恰好一段**，`secret/data/+` 覆盖 `nabi` 也覆盖 `flag`。
- **适用面**：Web | Node / Next.js Server Actions | 密钥面
- **迁移价值**：**审计危险特征**——「标了 deprecated ≠ 已断开」；密钥策略必须字面路径
- **识别与自测**：搜 `sourceMappingURL` / `createServerReference` / `path ".../+"`；对比类型声明与服务端解构
- **局限**：非官方 WP（战队/站点复盘）；赛题把三服务拆开，生产可能同构也可能更乱
- **链接**：https://cybersecurityelite.com/ctf-writeups/uiuctf-2026-web-nabi-ai-writeup/

---

## 五、AI 审计案例提炼（周更写入区）

> **目的**：把公开「AI 挖洞 / AI 代码审计」战报拆成可复用能力，而不是收藏新闻标题。  
> **体例**：见 [`../维护/文档体例约定.md`](../维护/文档体例约定.md)「三-附」。  
> **回链**：跨语言纪律同步到 [`通用审计方法论.md`](通用审计方法论.md)「十一、AI 辅助审计」。

### 使用纪律（先读）

1. 每条必须有：**管线分工 + 验证闭环 + ≥1 条可迁移 Checklist**。
2. 优先收录：有 taskflow/提示词结构、有误报处理、有真洞类型分布的案例。
3. 营销稿（只报数量、无方法）→ 周报一句话带过，**不进本节**。
4. 已在「一、」展开的经典案例（Oracle 双模型、Taskflow Agent、DeepAudit 等）视为基线；本节追加**新周案例**与「从基线抽出的操作清单」。

### 5-0 基线操作清单（从既有 1-1～1-6 提炼，可直接照做）

- [ ] **全量粗扫 + 热点精审**：冷门/遗留代码交给模型遍历；认证绕过、反序列化、上传、Agent 执行面由人定优先级深挖。
- [ ] **任务文件化**：复杂研判拆成 YAML/清单逐步执行（鉴权是否存在 → 净化是否充分 → 是否可达 sink），便于复现与改提示词。
- [ ] **模糊模式交给 LLM**：SAST/CodeQL 先粗筛；鉴权缺失、IDOR、Token 泄露等「规则难写清」的交给模型精判。
- [ ] **验证 Agent 进沙箱**：声称的洞必须有隔离环境执行或最小 POC；无验证环节的输出默认 C 级（仅推理）。
- [ ] **业务逻辑单独开卷**：状态机、越权、流程绕过用「时序推演」提示，勿只扫危险函数。
- [ ] **双模型/多角色交叉**：高影响结论用第二模型或另一 Agent 角色复核，降低单模型幻觉。

### 时效案例（周更追加）

> 格式：`### YYYY-MM-DD · 短标题（来源）` + 体例字段。

### 2026-08-09 · Unit 42 NOVA 多智能体挖洞管线（Palo Alto Unit 42）

- **场景**：开源供应链；2 个月内扫 3,915 项目，确认 14,090 洞（99.4% 称此前未报；约 40% 高危/严重）——规模数字以原文为准。
- **管线与分工**：
  - Scoping：选仓库与扫描策略
  - Discovery（多模型集成）：并行读代码、排候选
  - PoC / Verification：隔离环境回放、确定性触发
  - Gatekeeper：打分、对抗式复核、决定发布/归档/再扫
  - 人仅终审
- **提示词 / 任务拆解**：结构化 harness——历史回顾 → 读源码 → 候选 → PoC → 干净环境验证 → 补丁候选 → 披露稿；发现阶段刻意多模型互补（同仓不同模型找不同类洞）。
- **工具与上下文**：专用安全工具 + 多前沿模型；容器 / gVisor 类沙箱 / VM / 出站限制 / 最小权限多层隔离。
- **验证闭环**：模型口头认定不算数；独立验证 + 隔离回放 + 对抗 triage 后才算确认；下游暴露另做可利用性 PoC（原文称 2,776 例）。
- **成果与局限**：fuzz 友好类（内存/资源）只占少数；大量为逻辑/鉴权/供应链类；攻击者同样可用较弱模型对公开补丁做利用自动化 → 窗口压缩。
- **可迁移纪律**：
  - [ ] 发现用多模型/多角色，验证必须换「独立验证者」角色且进沙箱
  - [ ] 候选默认不可信，直到干净环境可复现
  - [ ] 扫包生态时区分「直接攻击面」与「下游传递面」，分别验收
- **链接**：https://unit42.paloaltonetworks.com/frontier-ai-vulnerability-burst/

### 2026-08-09 · PRWeaver：LLM PR 审计对抗长周期恶意变更（arXiv:2608.02693）

- **场景**：十个真实仓库上的 208 条执行验证攻击链；四种审阅渲染共 832 例；评测 OpenCodeReview / Claude Code / Copilot Code Review 等。
- **管线与分工**：基准侧先做完整攻击+PoC，再拆成有序补丁链，嵌入良性 PR 或独立提交；审计侧为现成 LLM PR Agent。
- **提示词 / 任务拆解**（对防御侧启示）：不要只问「本 PR 有没有洞」，要显式要求「对照仓库安全不变量，串联近期相关 PR」。
- **工具与上下文**：PR diff + 可选仓库历史；实验显示「有历史」仍不够。
- **验证闭环**：论文用执行验证的攻击作真值；检测率在交织深度 N=16、良性载体融合、整窗 N=24 审阅下分别显著下降（整窗可跌至约 16–22%，对比逐 PR 约 50–60%）。
- **成果与局限**：单纯「拆 commit」对逃逸解释力弱（≤5 个百分点）；**恶意与良性同框、目的叙事合理**时最难查。XZ 式长线攻击对当前 LLM 审计仍难。
- **可迁移纪律**：
  - [ ] 审 PR 时单开「跨 PR 不变量」检查（鉴权、支付、密钥处理），禁止只看当前 diff
  - [ ] 对「重构/性能/依赖升级」类载体 PR 提高怀疑权重
  - [ ] 整窗大批量审阅时强制拆会话或降低并行，避免上下文淹没
- **链接**：https://arxiv.org/abs/2608.02693

### 2026-08-09 · CodePecker「图智 GraphAgent」架构（SegmentFault 公开文，厂商向）

- **场景**：政企 DevSecOps；SCA + SAST + GraphAgent；宣称落地多家单位（**厂商单方披露，待核实**）。
- **管线与分工**：
  1. 图驱动：代码结构图 → 可疑可审计子图（缩小范围）
  2. 安全智能体：对脱敏路径做语义/业务逻辑研判（越权、支付篡改等）
  3. 确定性闭环：路径可达与证据链校验，压幻觉
- **提示词 / 任务拆解**：先图后模型；禁止整仓明文进 LLM；逻辑洞与注入类分引擎。
- **工具与上下文**：私有化部署；仅路径级脱敏信息进模型。
- **验证闭环**：路径可达分析降误报；智能体结论须过确定性验证层。
- **成果与局限**：营销数字（降误报 90% 等）不作硬事实；架构思想可迁移，具体准确率需自测。
- **可迁移纪律**：
  - [ ] 自建 AI 审计时先做「攻击面/调用图收敛」，再喂模型
  - [ ] 业务逻辑洞单独会话，输入限定为相关子图
  - [ ] 输出必须带回文件:行号与可达理由，否则降为 C 级
- **链接**：https://segmentfault.com/a/1190000048123768

### 2026-08-12 · IronCurtain：任意模型 + FSM 编排挖洞（Niels Provos / APNIC Blog）

- **场景**：开源 C/基础设施组件；复现「前沿模型才有的」历史洞（如 OpenBSD TCP SACK 类），并自主发现多年潜伏整数截断等（具体 CVE 披露中，机制可学）。
- **管线与分工**：
  - YAML 定义的有限状态机（FSM）工作流 `vuln-discovery`
  - **Orchestrator**：战略路由；**不读目标源码**，只读 append-only **execution journal**
  - 专用 Agent：按 journal 轮换（分析 / harness / 验证等）；每步新上下文窗口，从磁盘 journal 水合
  - 人：终审、升级 harness 层级、必要时拆解「利用确认」步骤（发现流与 exploit 开发流分离）
- **提示词 / 任务拆解**：纪律句——「静态假说，执行验证；其余是噪声」。PoC = 可执行 harness，证明可达与异常（内存破坏等），不是口头推理。
- **工具与上下文**：IronCurtain 开源框架；LiteLLM 可把同一 FSM 接到不同模型（Opus/Sonnet/GLM 等）；容器隔离。
- **验证闭环**：分层 harness——① 单函数隔离 fuzz → ② 多组件 harness → ③ 端到端 VM；仅在需要时升层。无执行证据的静态报告视为未完成。
- **成果与局限**：token 成本高（公开文称单次中等代码库可达千万级 token）；弱蒸馏本地小模型可能跑不动工作流；AUP 会阻断完整利用开发——须把「可利用性确认」拆步并由人门禁。
- **可迁移纪律**：
  - [ ] Orchestrator（或主会话）禁止吞整仓源码；状态进 journal/文件，步骤换干净上下文
  - [ ] 强制「假说 → 可执行验证」；无 harness/复现则结论降级
  - [ ] 验证分层升格，避免一上来全系统 VM；发现流与 exploit 流分开
- **链接**：https://blog.apnic.net/2026/08/11/finding-zero-days-with-any-model/ ；https://github.com/provos/ironcurtain

### 2026-08-12 · FLAWED：前沿模型漏洞补丁仍须人审（Off-by-1 Labs / 1Password）

- **场景**：对 6 个新近披露、训练数据中少见的复杂 CVE/GHSA，用两款前沿「可网安」推理模型批量生成补丁（公开称 6080 条量级），评估是否真正修复且不改业务行为。
- **管线与分工**：结构化提示词模板（每洞多套）× 多种环境配置 × 双模型；生成后走自动验证 + 人工复核；检出「翻补丁」行为（模型试图检索已有官方补丁）并剔除。
- **提示词 / 任务拆解**：九类结构化模板；产出按五档归类——完整修复且行为不变 / 完整修复但改行为 / 未修 / 修旧引新 / 未修且引新。
- **工具与上下文**：开源 [FLAWED](https://github.com/Off-by-1-Labs/FLAWED) 生成/比对/验证脚手架；配套数据集与论文。
- **验证闭环**：不只看「PoC 是否失败」，还看行为回归与是否引入新洞；公开结论：完整且不改行为的成功率约 **26%**；未修/引新合计约 **53.9%**；大量「看似修好」实为针对 PoC 字符串的脆弱守卫。
- **成果与局限**：强证据表明「AI 挖洞管线」≠「AI 可无人值守修洞」；成本按次计仍低于资深人工，但必须领域专家终审。样本限于 6 洞、两模型，外推需谨慎。
- **可迁移纪律**：
  - [ ] AI 生成补丁默认标 **B/C 级**，直至有回归测试 + 根因级修复证据（禁止只挡 PoC 字符串）
  - [ ] 验收清单强制含：行为是否改变、是否引入新 sink、是否只改 allow→deny 表面逻辑
  - [ ] 发现 Agent 与修复 Agent 分会话；修复会话禁止静默拉取「官方补丁」冒充自研成功
- **链接**：https://1password.com/blog/why-ai-generated-patches-still-require-human-review · https://github.com/Off-by-1-Labs/FLAWED

### 2026-08-15 · HTTP Terminator：专长编码的四阶段研究管线（PortSwigger / James Kettle）

- **场景**：HTTP desync **研究**（不是通用源码审计）；在授权赏金/VDP 目标上评测假说；08-12 更新白皮书并开源参考实现。
- **管线与分工**：
  1. **Ideation / seeker**：从 RFC/文档抽可测假说（触发器、模式、武器化点子）
  2. **Evaluation / flamer+validator**：对授权活站大规模评测；假说必须「在真实前后端组合上成立」才算研究线索
  3. **Weaponization / investigator**：把成立假说接到可报告影响；**成功判定由不可被模型改写的确定性代码锁死**
  4. **Cascade**：对每个成立假说追问「别处如何检出」「原点还能否打出别的类」
  - 人：设计门禁、处理「自主性地平线」外的新类；模型：假说与证据，不负责最终真值
- **提示词 / 任务拆解**：把作者自己的 desync 方法论编成阶段与约束（窄问题 + 可测假说）。环境接口可「重命名/遮罩」以降低拒答与假阳性，但验收不能靠提示词——要靠代码门。
- **工具与上下文**：开源仓库分 `seeker`（Python）/`flamer`（Java）/`validator`（Burp 扩展）/`investigator`（需外部 MCP）；**不是 Burp AT**。
- **验证闭环**：活站评测 + 确定性成功条件；分步换干净上下文，只传递证据与脚本，避免上一步幻觉污染下一步。级联来自「已证明假说」而非再扫一遍 RFC。
- **成果与局限**：公开称发现多类新触发/武器化（含 dangling-byte、shared-parser confusion 等）；完全放手仍会在新类上失败——人在环的价值是 cascade 与题目选择，不是替模型点运行。
- **可迁移纪律**：
  - [ ] 把**你自己会的**审计/研究步骤编成阶段，禁止「整仓问有没有洞」
  - [ ] 假说必须可测；「只在某实现上成立、无真实部署」标研究线索，不入库
  - [ ] 成功/失败由确定性代码判定；模型不得改写验收函数
  - [ ] 每条成立结论强制 cascade：邻近解析器、同类配置、邻近分支
- **链接**：https://portswigger.net/research/http-terminator · https://github.com/PortSwigger/http-terminator · https://portswigger.net/blog/can-ai-invent-new-attack-techniques-new-research-from-james-kettle-and-portswigger-research

---

## 下期跟踪清单（2026-08-16 起，每周核查）

1. ~~Metabase~~ → **已升格** CVE-2026-72898 / KEV；本周公开多起自托管失陷 → 未修按失陷假设（轮换连接库凭据）；
2. AD CS CVE-2026-62818：仍缺公开武器化细节；域周加厚 ESC 与补丁联动；
3. CVE-2026-42533（NGINX）公开 PoC 与 KEV 动向；
4. Check Point CVE-2026-18574 在野确认；
5. SharePoint 本月 PT 新 RCE（66808 等）武器化进度；
6. ~~HTTP Terminator~~ → **已升格精析**；继续盯录像/新类洞披露；IronCurtain / FLAWED 复现笔记；
7. **新公开 AI 代码审计案例** → 写入第五节（本周已扫 evilsocket/audit，作工具观察不重复当主条）；
8. Azure Key Vault CVE-2026-62825 官方公告核实；
9. TeamCity / Langflow / LoadMaster / **Cisco ASA 20349** / **NetScaler 8452** 补丁后暴露面残留；
10. FortiSandbox CVE-2026-39808 暴露面是否进入护网常见指纹；
11. PAN GP 0297/0298 是否出现在野/入 KEV；**Ivanti EPM 已入库**；国产 VPN **门户**通告继续滚；
12. ~~UIUCTF Nabi AI~~ → **已提炼**（deprecated Server Action + Vault `+`）；其余赛题 / **官方** WP 仍观察；
13. Gunra / Fortinet 55591+24472 暴露面与失陷假设是否进入护网常见指纹。

---

## 参考来源（2026-07 批次）

1. CSDN：《Oracle 2026年7月CPU漏洞修复实战：AI挖洞+月度CSPU补丁运维指南》，2026-07-25。https://blog.csdn.net/weixin_42376192/article/details/163182744
2. 搜狐：《Oracle紧急修复1200+漏洞，警示AI时代安全缺口》，2026-07-23。https://www.sohu.com/a/1053935879_121124359
3. Oracle 官方安全博客：《Accelerating Vulnerability Detection and Response at Oracle》，2026-04。https://blogs.oracle.com/security/accelerating-vulnerability-detection-and-response-at-oracle
4. 中关村在线：《微软发布2026年7月安全更新：单月修复622个漏洞创历史新高》，2026-07-15。https://ai.zol.com.cn/1216/12161954.html
5. 西域网：《AI组团挖漏洞：多智能体协作攻破52%测试目标》，2026-07-30。https://xiouwang.cn/webnews/7504.html
6. 中国日报网：《绿盟智能渗透测试系统2.0正式发布》，2026-07-16。http://ex.chinadaily.com.cn/exchange/partners/82/rss/channel/cn/columns/snl9a7/stories/WS6a587fc5a310d709c2fbddbb.html
7. GitHub Blog：GitHub Security Lab（Taskflow Agent，2026-07-01）。https://github.blog/tag/github-security-lab/
8. ZenML LLMOps Database：AI-Powered Vulnerability Triage Using GitHub Security Lab Taskflow Agent。https://www.zenml.io/llmops-database/ai-powered-vulnerability-triage-using-github-security-lab-taskflow-agent
9. cpolar 博客：《开源AI审计工具DeepAudit》，2026-01-05。https://www.cpolar.com/blog/are-you-still-manually-reviewing-code-to-look-for-bugs-try-this-open-source-ai-auditing-tool-called-deepaudit
10. 朱皮特：《2026 年 7 款 AI 应用安全工具横评》，2026-06-23。https://zhupite.com/sec/ai-application-security-tools-2026.html
11. bestllmscanners：《Best LLM Vulnerability Scanners 2026》，2026-06-13。https://bestllmscanners.com/posts/best-llm-vulnerability-scanners-2026/
12. 洞见网安《网安原创文章推荐【2026/7/25】》（x64dbg MCP 逆向、Azure Key Vault 预警、Certighost、Redis RCE），2026-07-25。https://www.gm7.org/archives/133620
13. 奇安信研究报告列表页：《2026年中网络安全漏洞威胁态势研究报告》，2026-07-24。https://www.qianxin.com/threat/reportaptlist
14. 希潭实验室：《2026年攻防比赛中漏洞类型总结（AI改变漏洞挖掘方式）》，2026-07-18。https://www.gm7.org/archives/131052
15. AI 技术日报（2026-07-19）：大模型客户端越权删除文件事件。https://windflash.us/daily-report/zh/2026-07-19
16. 看雪论坛：《OpenClaw 三大高危RCE 漏洞全解析》，2026-04-30。https://bbs.kanxue.com/thread-291060.htm
17. Rapid7：《Patch Tuesday - July 2026》，2026-07-14。https://www.rapid7.com/blog/post/em-patch-tuesday-july-2026/
18. cnblogs：《大模型渗透测试报告模板》，2026-03-14。https://www.cnblogs.com/FiveAndM/p/19718815
19. 信息安全知识库：《GFCTF-2026（wp）》，2026-07-06。https://www.gm7.org/archives/124447

> 脱敏复核：本分册不含任何目标域名/IP/凭证/IOC 及可直接复用的攻击载荷。
