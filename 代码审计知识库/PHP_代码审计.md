# PHP 代码审计分册

> 适用：PHP Web 应用（CMS / 论坛 / 商城 / 板卡程序）。
> 用法：对照"危险特征"grep 源码，命中后按"审计要点"追踪数据流，按"验证思路"构造请求。
> 更新：2026-08-09（v1.1：时效条目 + CI4 上传模式）

---

## 1. SQL 注入

| 形态 | 危险特征 | 审计要点 |
|---|---|---|
| 直接拼接 | `"... '{$var}' ..."`、`".$_GET[` 进 SQL | 顺参数回溯是否有全局过滤（如 GPC 模拟层），过滤是否可绕 |
| 尾反斜杠/宽字节 | GBK/Big5 连接编码 + addslashes/mysql_real_escape_string | `%df%27`：%df 与转义符 `\`（%5c）组成合法宽字节字符，单引号逃逸。重点查 charset 设置与 mysql_set_charset 是否缺失 |
| 二次注入 | 先入库（转义后存储），后取出拼 SQL | 取出时是否再次过滤；注册/资料修改 → 后续查询场景高发 |
| order by / limit | `ORDER BY $sort`、`LIMIT $a, $b` | 不能预编译的位置常被忽略，order by 可报错注入，limit 可堆叠/procedure analyse（老版本） |
| PDO 误区 | `PDO::ATTR_EMULATE_PREPARES=true`（模拟预处理） | 模拟模式下仍按 charset 拼接，宽字节可绕；查初始化选项 |
| insert/update 型 | 注册、留言、日志写入点 | 报错注入 / 时间盲注；注意 values 中多点可控 |

**验证思路**：先判过滤层（单引号是否被转义）→ 再判编码（宽字节可行性）→ 布尔/时间盲注兜底。拿到注入后评估：`FILE` 权限可 `INTO OUTFILE` 写 shell；堆叠可查版本差异。

## 2. 文件上传

| 校验缺陷 | 绕过手法 |
|---|---|
| 黑名单（禁 php/asp…） | 双写（.pphphp）、大小写（.PhP）、变体（.phtml/.phar/.php5/.pht）、点空格点（Windows）、::$DATA（Windows/NTFS） |
| 仅查 Content-Type | 改包 MIME 为 image/jpeg |
| 仅 getimagesize | 图片马（真图 + 尾部插 PHP），配合包含或解析漏洞执行 |
| 仅内容 MIME/`is_image` 类规则、不校验客户端扩展 | 魔数合法 + 文件名 `.php`（CI4 CVE-2026-63223 典型）；见「时效条目」 |
| 前端校验 | 直接改包 |
| 二次渲染 | 找未被渲染的保留区插马，成功率低、需专用工具 |
| .htaccess / .user.ini | Apache：上传 .htaccess 改解析；Nginx+fpm：.user.ini 指定 auto_prepend_file 让任意图片变马 |
| 条件竞争 | 先落地后校验删除：并发请求抢时间窗直接访问上传的 php |
| 解析差异 | Apache 多后缀从右向左解析（x.php.xxx）、Nginx 经典 0day 型 `x.jpg/.php`（老配置）、IIS6 分号 |

**审计要点**：定位 move_uploaded_file 的目标路径是否含用户可控部分（文件名/目录参数）；查 .htaccess/.user.ini 是否被禁传；查临时目录与最终目录是否同域可访问。

## 3. 文件包含（LFI/RFI）

- 危险特征：`include/require/include_once/require_once` 参数中含变量
- 常用 payload：
  - `php://filter/convert.base64-encode/resource=index.php` 读源码（黄金第一步）
  - `phar://上传的图马/x.php` 执行 + 触发反序列化
  - `data://text/plain,<?php phpinfo();?>`（需 allow_url_include）
  - 包含 session 文件 / 日志（access_log 插 UA 马）/ /proc/self/environ
  - pearcmd.php 无文件 getshell（注册了 pearcmd 的 PHP7+）
- 审计要点：是否有后缀拼接（`.php` 固定后缀 → %00 截断仅限 PHP<5.3.4；否则转向伪协议）；open_basedir 是否限制。

## 4. 命令执行

- 危险特征：`system/exec/passthru/shell_exec/反引号/popen/proc_open`
- 绕过与变形：分隔符 `; | & || &&`、换行 %0a、通配符（/???/c?t 读文件）、变量替换 `${PATH:0:1}`、无字母数字 webshell（异或/取反构造）
- 参数注入：命令本身固定但参数可控，查目标命令有无危险选项（tar --checkpoint-action=exec=sh、find -exec、git --exec 等，查 GTFOBins）
- escapeshellarg/escapeshellcmd 缺陷：仅 escapeshellarg 时，参数含单引号闭合仍可注入选项（参考 PHPMailer CVE-2016-10033）

## 5. 代码执行

- 危险特征：`eval/assert`（assert 在 PHP7 后不可字符串调用）、`preg_replace /e`（<5.5）、`create_function`（<7.2）、`call_user_func*` 可控回调、动态调用 `$func($arg)`、反射 `ReflectionFunction`
- 变量覆盖三件套：`extract($_GET)`、`parse_str`、`$$var`——优先看是否覆盖认证标志、配置数组、过滤白名单
- 审计要点：框架的"钩子/事件/回调"注册处常把字符串当函数名调用，是隐蔽入口。

## 6. 反序列化

- 入口：`unserialize(可控)`；`phar://` 触发（file_exists/is_file/getimagesize 等均可）；session 反序列化（处理器不一致：php vs php_binary vs php_serialize）
- 链构造：从 `__destruct/__wakeup/__toString/__call` 出发，找文件写（file_put_contents）、命令执行（call_user_func）、或二次反序列化节点
- 属性控制：注意 private/protected 属性序列化后的 \0 前缀；`__wakeup` 可被属性数大于实际值绕过（CVE-2016-7124，PHP5<5.6.25/7<7.0.10）
- 审计要点：grep 全项目魔术方法，画"入口魔术方法 → 危险操作"调用图；phar 入口在纯文件操作函数处，常被漏审。

## 7. 弱类型与比较陷阱（CTF 与实战高发）

| 陷阱 | 利用 |
|---|---|
| `==` 松散比较 | `"0e123"=="0e456"` 为 true（科学计数法 0）；MD5/SHA1 找 0e 开头的碰撞串 |
| in_array 未开严格 | `in_array("1abc", [1])` 为 true；必须查第三参数 true |
| strcmp/strcasecmp | 传数组返回 NULL，`NULL==0` 绕过 |
| hash_hmac 等参数为数组 | 第二参数传数组返回 NULL，密钥校验形同虚设 |
| is_numeric/ intval | 十六进制/科学计数法/截断特性 |
| switch loose、json_decode 比较 | 同理按松散比较处理 |
| md5($a)===md5($b) 严格 | 数组双双传 array 使两边同 NULL；或真碰撞（fastcoll） |

## 8. SSRF / XXE

- SSRF：curl_setopt URL 可控、file_get_contents/fsockopen 可控 host；绕过：302 跳转、短链、DNS rebinding、进制 IP（2130706433=127.0.0.1）、0x7f、@[user@host] 混淆；目标：内网、云元数据、Gopher 打 Redis/MySQL（老版本）
- XXE：simplexml_load_string/DOMDocument，libxml<2.9.0 默认解析外部实体；新版默认关但代码里 `LIBXML_NOENT` 即开；盲 XXE 用外带 DTD

## 9. XSS / CSRF / 越权

- XSS 审计看输出点：`echo $var` 是否过 htmlspecialchars（注意默认不转义单引号，需 ENT_QUOTES）；富文本看白名单实现（HTMLPurifier 还是自写正则，自写基本可绕）
- CSRF：改密、绑邮箱、发文等敏感操作查 token 校验与 SameSite
- 越权：资源 ID 来自参数且无归属校验（水平）；后台功能仅靠前端隐藏、无角色判断（垂直）

## 10. 认证与会话逻辑

- 密码重置：token 随机性（mt_rand 种子可预测）、是否绑定账号、有效期、重放、是否泄露在响应/邮件模板里
- 记住我 cookie：是否可逆推（uid+固定密钥 md5 类）
- session 固定：登录前后 session_id 是否轮换
- 社交绑定：state 校验、code 与账号绑定、email 未验证即信任

## 11. 信息泄露速查

`.git/ .svn/ .DS_Store composer.json *.bak *.swp *~ .sql phpinfo.php 报错页面物理路径 注释中的测试账号`

## 12. 审计 Checklist（开工过一遍）

- [ ] 入口枚举：\$_GET/\$_POST/\$_COOKIE/\$_REQUEST/\$_SERVER 全部出现位置
- [ ] 全局过滤层：找到并判断可绕性（宽字节？白名单数组可覆盖？）
- [ ] sink 清单：SQL / 命令 / 代码 / 包含 / 文件写 / 反序列化 / 重定向，逐一回溯 source
- [ ] 上传链路：校验逻辑、落地路径、二次处理
- [ ] 认证逻辑：重置、记住我、绑定、越权
- [ ] 第三方组件：composer.json 对照公开 CVE
- [ ] 安装/升级脚本：install 目录残留常是老代码重灾区

## 13. 工具

Seay（危险函数初筛）、PHPStan/Phan（静态）、RIPS、Semgrep（自定义规则）、Xdebug（断点跟踪数据流）、Burp（重放验证）、phar 生成器（phpggc 对应 PHP 链，类比 ysoserial）

## 14. 时效条目（周更回链）

### 2026-08-09 · CodeIgniter4 `is_image`/`mime_in` 扩展名缺口（CVE-2026-63223）

- **危险特征**：只靠内容型规则放行上传；`getClientName` 原样落地；目录可解析 PHP。
- **利用条件**：无独立扩展白名单 / 未服务端重命名；Web 根可执行。
- **审计要点**：规则表是否同时有 `ext_in`；`move()` 路径是否用户可控；`public/` 下是否存上传。
- **自测锚点**：在示例项目中标出「仅改扩展名能否绕过」的最小证明路径（勿对未授权目标实测）。

## 15. 参考资料

- [代码审计-PHP 篇：从原理到实战的全景指南](https://www.gm7.org/archives/120527)
- [羊城杯官方 Writeup（hash_hmac 数组绕过、PHP UAF 等实战点）](https://raw.githubusercontent.com/gwht/2020YCBCTF/main/wp/羊城杯官方Writeup.pdf)
- phpggc（PHP 反序列化链库）：https://github.com/ambionics/phpggc
- GTFOBins（参数注入字典）：https://gtfobins.github.io/
