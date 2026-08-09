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
