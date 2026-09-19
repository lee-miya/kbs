# API 与认证攻击面

## 1. API 发现与测绘

```bash
# 路径来源
JS 文件提取：LinkFinder / JSFinder / 手工看 webpack 分包
接口文档：/swagger-ui.html /v2/api-docs /v3/api-docs /doc.html /actuator /druid
常见前缀：/api /v1 /v2 /openapi /graphql /gateway
# 历史流量
burp 被动爬全站后筛选 XHR；waybackurls + gau 挖历史接口
```

GraphQL 专项：开 introspection 直接拉全 schema；没开就 fuzz 字段名；重点关注嵌套查询 DoS 与越权字段。

版本过滤 /「未来字段」回落（2026-08-29，GitLab CVE-2026-19478 启示；禁止完整查询体）：

- 滚动发布用的指令（如「该字段尚未在本版本存在」）若把**缺失字段**合成无 resolver 的 Field，运行时可能把字段名当方法名打到后端对象
- 审计/打点：schema 里出现自定义 version-filter 指令时，问「未知字段是报错、返回 null，还是隐式调用？」；补丁形态应是显式空 resolver，不是默认方法分发
- 自建 GitLab：看 `/api/graphql` 是否未认证可达；升 19.2.4 / 19.1.6 / 19.0.8 / 18.11.11

长度受限字段上的 SSTI（2026-08-29 对照 BugHunter 已披露报告，禁止照搬 payload）：

- 短输入框（昵称、显示名、webhook 路径片段）不要只测长 polyglot；优先引擎探测串与分片拼接
- 过滤型 SSRF：除直连内网 IP 外，测重定向、再绑定、只验原始 URL 不验对端套接字（对照 MLflow 64849）

资金/账本类 GraphQL（漏测轴，2026-08-18 对照第三方 skill 后改写，禁止照搬原文）：

- 资金类 mutation（转账/调账/出金）是否按**账户归属**授权，而不是「登录即可调任意 `accountId`/`ledgerId`」
- 金额用浮点/字符串时的小数精度与舍入方向；幂等键（`Idempotency-Key` / `clientMutationId`）能否重放同一笔或换金额重放
- KYC/PII、管理员覆盖字段是否出现在普通用户可选的嵌套 selection 里（字段级授权，不是只挡顶层 mutation 名）

业务状态机 / HPP / 上传（2026-09-19 对照 offensive-claude v1.11 coverage map 后改写，禁止照搬 SKILL.md）：

- 价格、退款、工单状态迁移是否允许「跳步」或重复提交同一幂等键换金额
- HTTP 参数污染（同名参数数组 vs 最后一个）：鉴权读 A、业务读 B
- 上传：魔数、扩展名、存储名、内容处理（图床转码）四项必须正交，缺一按 RCE 候选项

## 2. 认证与令牌攻击

### JWT 攻击清单

| 攻击 | 条件 | 手法 |
| --- | --- | --- |
| alg=none | 服务端不校验签名 | 头部改 `{"alg":"none"}` 去签名段 |
| RS256→HS256 混淆 | 服务端用公钥当 HMAC 密钥 | 拿公钥（/jwks、证书）当 secret 重签 |
| 弱密钥爆破 | HS256 + 弱 secret | `hashcat -m 16500 jwt.txt dict.txt` |
| kid 注入 | kid 参与读文件/SQL | `kid` 指向 `/dev/null` 或命令注入 |
| jku/x5u 伪造 | 服务端从指定 URL 拉公钥 | 自建 JWKS 端点重定向 |
| 过期与刷新 | exp 不校验/refresh_token 不过期 | 重放旧 token |

工具：`jwt_tool -T <token>` 一键跑全套；手工用 jwt.io 调试。

### OAuth / SSO 缺陷

- redirect_uri 校验不严（子域、目录、@ 混淆、正则缺失）→ code/token 窃取。
- state 缺失或可预测 → 登录 CSRF，绑定攻击者账号。
- 第三方登录绑定逻辑缺陷：用手机号/邮箱自动绑定时，改绑他人账号。

### 会话与密码

- 会话固定：登录前后 sessionid 不变 → 钓鱼让受害者用攻击者 session 登录。
- 密码喷洒（外网入口通用）：每账户 ≤2 次/时，优先 `Company@2026`、`Aa123456`、键盘串；先单账户试锁定阈值。
- 默认口令库：按指纹匹配（见 09-01 各组件默认口令列）。

## 3. 越权与多租户

- IDOR 系统排查：所有带数字 ID/UUID 的接口换账号重放。
- 多租户绕过：`tenant_id`、`org_id`、`X-Org-Id` 头篡改。
- 前端隐藏 ≠ 后端鉴权：管理接口直接请求（js 里有路径），垂直越权高发。

## 4. 限流与业务防护绕过

- IP 限流：`X-Forwarded-For` 轮换、IPv6、网关多出口。
- 设备指纹/滑块：协议层复现（逆向 JS 生成参数）绕过前端逻辑。
- OTP 爆破：无失败计数 + 4/6 位数字 = 可破；响应差异可侧信道。

## 5. 使用场景

| 场景 | 首选打法 |
| --- | --- |
| 小程序/App 后端 | 抓包提接口 → swagger/actuator → JWT 与越权 |
| 前后端分离站 | JS 全量提取接口 → 未授权访问 → IDOR |
| 统一认证入口 | OAuth 回调缺陷 → 账号绑定劫持 |
| GraphQL 端点 | introspection → 敏感 mutation 越权 |

## 自测锚点

- [ ] 拿到一个 JWT，能按清单逐项测完六种攻击。
- [ ] 能从任意前端 JS 中提取接口清单并标注鉴权方式。
- [ ] 能解释 OAuth 中 state 与 redirect_uri 各自防什么攻击。
