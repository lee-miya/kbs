# 知识库总索引与高频速查表

> **审计库加载入口**（人读导航见 [`README.md`](README.md)）。新对话先读本文件，再按需打开分册。  
> 最近更新：2026-08-15（v1.10：晚间增量 — Nabi AI deprecated/Vault `+`；Gunra/Fortinet；Ivanti EPM）

## 一、分册索引

| 分册文件 | 适用场景 | 核心内容 | 更新 |
|---|---|---|---|
| [通用审计方法论.md](通用审计方法论.md) | 所有项目开工前必读 | 审计三路径、patch diffing、fail-open、**AI 辅助审计**；**弃用仍接线** | 2026-08-15 |
| [综合分册_AI漏洞挖掘与态势.md](综合分册_AI漏洞挖掘与态势.md) | AI 挖洞 / 审 AI 应用 / **案例精析** | 工具方法论、Agent 攻击面、第五节案例提炼；**Nabi AI 拾遗** | 2026-08-15 |
| [PHP_代码审计.md](PHP_代码审计.md) | PHP Web（CMS、论坛、商城） | SQLi、上传、包含、反序列化、弱类型；CI4 时效 | 2026-08-09 |
| [Java_代码审计.md](Java_代码审计.md) | Java Web（Spring/Struts/Shiro） | 反序列化、表达式/SSTI、内存马；Tomcat fail-open；**JWT 验签**；**cleanPath 不正交** | 2026-08-15 |
| [Python_代码审计.md](Python_代码审计.md) | Python Web 与脚本 | pickle/yaml、SSTI、命令执行；**Langflow 执行面** | 2026-08-09 |
| [JavaScript_Node_代码审计.md](JavaScript_Node_代码审计.md) | Node.js 后端 | 原型链污染、命令注入、NoSQL、供应链；**CRLF→desync**；**dangling-byte**；**Server Action / Vault `+`** | 2026-08-15 |
| [Go_代码审计.md](Go_代码审计.md) | Go 服务与工具 | 命令执行、SQL、SSRF、路径、并发 | 2026-07-31 |
| [C_CPP_内存破坏与Fuzzing.md](C_CPP_内存破坏与Fuzzing.md) | C/C++ 二进制 | 内存破坏、AFL++、崩溃到 PoC；分层 harness 启示 | 2026-08-12 |

## 二、按需加载指引

| 你的任务 | 建议拉取 |
|---|---|
| 审计 PHP 项目 | PHP 分册 + 通用方法论 |
| 审计 Java 项目 | Java 分册 + 通用方法论 |
| 补丁 diff 逆向（任何语言） | 通用方法论 + 对应语言分册 |
| 二进制/C 目标、fuzzing | C/C++ 分册 + 通用方法论 |
| 未知语言新项目 | 通用方法论（先跑攻击面枚举） |
| 借鉴 AI 挖洞 / 审 AI 应用 | 综合分册 + 通用方法论 |
| 用 AI 做代码审计（提示词/闭环） | 通用方法论「十一」+ 综合分册「五」 |
| Web 渗透手法（非源码） | [`../红队渗透知识库/INDEX.md`](../红队渗透知识库/INDEX.md) 再打开 `02` |

## 三、高频速查表（跨语言 TOP 模式）

> 最高频的入手点，一行一条。看到特征立刻联想模式，细节回分册查。

| # | 模式 | 危险特征（代码里搜什么） | 一句话利用 |
|---|---|---|---|
| 1 | SQL 注入 | SQL 语句中出现字符串拼接 `"...".$var` / `${}` / `%` 格式化 | 拼接点注入，注意宽字节与尾反斜杠绕过转义 |
| 2 | 尾反斜杠 SQLi | GBK/Big5 等宽字节集 + addslashes/转义 | `%df%27` 吃掉转义反斜杠逃出单引号 |
| 3 | 文件上传 RCE | 黑名单校验、只查 MIME/getimagesize | 双扩展名、大小写、.phtml/.phar、user.ini、条件竞争 |
| 4 | 文件包含 | include/require 参数可控 | 伪协议 php://filter 读源码、phar:// 触发反序列化 |
| 5 | 命令注入 | system/exec/shell_exec/反引号 + 用户输入 | 分隔符 `;|&` 或参数注入（如 tar --checkpoint-action） |
| 6 | PHP 反序列化 | unserialize(可控输入) | 找 __destruct/__wakeup/__toString 拼 POP 链 |
| 7 | phar 反序列化 | file_exists/is_file 等文件函数参数可控 | 构造 phar 包，phar:// 触发元数据反序列化 |
| 8 | 弱类型比较 | == 比较、in_array 未加 true、strcmp | 0e 哈希、数组绕过（返回 NULL）、类型魔术 |
| 9 | 变量覆盖 | extract/parse_str/$$ | 覆盖认证标志位、覆盖白名单数组 |
| 10 | Java 反序列化 | readObject/XMLDecoder/fastjson parse | 依赖里有 commons-collections 等即试 ysoserial 链 |
| 11 | 表达式注入 | SpEL/OGNL/MVEL 表达式拼接用户输入 | T() 调用 Runtime / #root 反射执行命令 |
| 12 | SSTI | 模板字符串拼接（Jinja2/Freemarker/Velocity） | {{7*7}} 探测，进一步读对象树到 RCE |
| 13 | XXE | XML 解析未禁外部实体（DOM/SAX/DocumentBuilder） | 读文件、SSRF、盲 XXE 外带 |
| 14 | SSRF | 请求 URL 可控（curl/file_get_contents/requests/http.Get） | 打内网、读云元数据 169.254.169.254 |
| 15 | 路径穿越 | 文件读写路径拼接用户输入 | ../ 跳出，注意 filepath.Join/ServeFile 误判 |
| 16 | 解压穿越 | tarfile/zipfile 解压未校验成员名 | 成员名带 ../ 写任意文件（Zip Slip） |
| 17 | pickle 反序列化 | pickle.loads(可控) | __reduce__ 返回 (os.system, (cmd,)) |
| 18 | 原型链污染 | 递归 merge/clone 用户 JSON（lodash 等） | __proto__ 污染 Object.prototype，链到 RCE |
| 19 | NoSQL 注入 | Mongo 查询直接吃用户 JSON | `{"$gt":""}` 绕过登录、$where 执行 JS |
| 20 | 越权（IDOR） | 资源 ID 直接来自参数，无归属校验 | 改 ID 水平越权；无角色校验垂直越权 |
| 21 | 认证令牌缺陷 | 密码重置 token 可预测/不过期/不绑定账号 | 爆破或重放 token 接管账号 |
| 22 | 硬编码密钥 | 源码/配置中的 key、token、密码 | grep 常见模式，配合 .git 泄露挖历史 |
| 23 | 组件 N-day | pom/package.json/composer.json 里的旧版本 | 按版本对照公开 CVE，确认可达性后直接用 |
| 24 | 条件竞争 | 先上传后校验删除、临时文件、TOCTOU | 并发请求抢时间窗落地 WebShell |
| 25 | 两遍求值共享状态（NGINX map 模式） | "先测量后写入"的两遍式实现 | 两遍间共享可变状态（正则捕获等）被覆写 → 长度与内容失配堆溢出 |
| 26 | Go 鉴权不中断 | 写 401/错误响应后不 return/Abort | 后续业务逻辑照跑 = 未授权执行，可链穿越+伪造+竞争 |
| 27 | Go err 静默丢弃 | err 未检查（尤其权限/边界检查返回） | 错误被忽略 → 逻辑绕过与状态错乱 |
| 28 | 安全边界 fail-open | 解密/验签/鉴权失败只打日志仍继续 | 原始输入到达反序列化等 sink（Tomcat EncryptInterceptor 课） |
| 29 | 上传校验不正交 | 只验 MIME/魔数、不验扩展名或存储名 | 图头 + `.php` 名落地可执行目录 → RCE |

## 四、维护说明

- 本索引随任何分册更新而同步更新「更新」列；方法论与综合分册排在语言分册之前（开工顺序）。
- 速查表只放 TOP 高频模式；新增模式先写分册「时效条目」，足够高频再进本表。
- **周更审计内容直接写入分册**，不再使用增量池目录。节奏与红队 `12_每周情报` 对齐，见 [`../维护/每周更新SOP.md`](../维护/每周更新SOP.md)；体例见 [`../维护/文档体例约定.md`](../维护/文档体例约定.md)。
