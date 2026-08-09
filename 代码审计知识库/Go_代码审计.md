# Go 代码审计分册

> 适用：Go Web 服务（Gin/Echo/原生 net/http）、CLI 工具、云原生组件。
> 更新：2026-07-31（v1.0）

---

## 1. 命令执行

- `exec.Command("sh", "-c", 拼接)`：等价 shell 注入，最高危形态。
- `exec.Command(name, args...)`：无 shell 分隔符注入，但**选项注入**照旧（git/tar/ssh 等危险选项，查 GTFOBins）。
- `syscall.Exec` 同理。审计要点：grep `exec.Command|sh", "-c|bash", "-c`，回溯参数来源。

## 2. SQL 注入

- `db.Query("SELECT ... " + var)`、`fmt.Sprintf` 拼 SQL：经典注入。
- ORM（gorm/xorm）：`Where("name = '" + v + "'")` 原生字符串条件、`Raw()`、`Exec()`；参数化写法 `Where("name = ?", v)` 才安全。
- 审计要点：全文搜 `Sprintf.*SELECT|Raw(|Exec(|Order(`（order by 注入高发）。

## 3. SSRF

- `http.Get/Post/NewRequest` URL 可控；`http.Client` 默认跟随重定向 → 校验被绕。
- 云原生场景重点：metadata（169.254.169.254）、K8s API、内网 Prometheus/Consul。
- 加固绕过：只校验首次 URL 不校验重定向目标；只判字符串前缀。

## 4. 模板

- `text/template`：**不做转义**，输出到 HTML 即 XSS；`html/template` 按上下文转义。
- 模板名/模板内容可控 → SSTI 面有限（Go 模板无直接 RCE，但 {{.Secret}} 可遍历结构体字段泄露数据）。

## 5. 反序列化

- `encoding/gob`：类型受接口注册限制，风险中等，但见可控 gob 仍要查注册的 concrete type 有无危险方法。
- `gopkg.in/yaml.v2` 的 `Unmarshal` 到 interface{}：无直接 RCE，但配合类型断言逻辑漏洞。
- `encoding/json` 到 map[string]interface{}：类型断言不检查 → panic 或逻辑绕过（"1" vs 1 的比较）。

## 6. 路径与文件

- `filepath.Join(base, user)`：user 为绝对路径或含 `../` 时逃逸——Join 只做 Clean 不做围栏；必须 `strings.HasPrefix(结果, base+separator)` 校验。
- `http.ServeFile(w, r, path)`：path 含 r.URL 直接拼接即穿越（net/http 对 r.URL 有 Clean，但拼接后的参数不管）。
- `io.Copy` 到文件、os.WriteFile 路径可控 → 任意写。
- 解压：archive/zip、archive/tar 成员名未校验 → Zip Slip（Go 生态同样高发）。

## 7. 并发与逻辑

- data race：共享 map/slice 并发读写 → 逻辑绕过（先读后改 TOCTOU）；`go run -race` 可复现。
- defer 顺序与资源未关：连接泄漏被用于 DoS。
- 整数溢出：int 在 32/64 位差异；`len()` 是 int，大文件转 uint64 比较陷阱。
- 错误处理：`err != nil` 被忽略（特别是权限检查返回 err 后仍继续用结果）。

## 8. Web 框架与中间件

- Gin：`c.Param`/`c.Query` 进 sink 同上；中间件 Use() 顺序错误导致鉴权绕过；`ShouldBind` 绑结构体后未做字段级校验（mass assignment：结构体含 IsAdmin 字段被直接绑定）。
- 路由冲突与通配：`:id` 与静态段混用的匹配优先级。
- CORS：AllowAllOrigins + AllowCredentials。

## 9. 审计 Checklist

- [ ] grep：`exec.Command|sh", "-c|Sprintf.*SELECT|Raw(|ServeFile|filepath.Join|http.Get(`
- [ ] 结构体 Bind 字段审查（是否有权限类字段暴露）
- [ ] 中间件注册顺序与分组
- [ ] go.mod 依赖：`govulncheck ./...` 跑一遍
- [ ] `-race` 跑测试 / 压测看 race
- [ ] 错误处理：权限检查 err 被忽略的点

## 10. 工具

gosec（官方安全扫描）、govulncheck（依赖 CVE，可分析可达性）、CodeQL（Go 规则）、staticcheck、Semgrep、`go vet`

## 11. 参考资料

- gosec 规则集：https://github.com/securego/gosec
- govulncheck：https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck
- GTFOBins（选项注入字典）：https://gtfobins.github.io/
- [万字长文：代码审计全流程（含 Go 路径遍历示例与修复）](http://mp.weixin.qq.com/s?__biz=MzAxMjE3ODU3MQ==&mid=2650612198&idx=3&sn=6260c5b81bcda79bc50fb100f11ede77)


---

## 时效条目（2026-07 批次）

### Go 工具链与运行时自身漏洞两则

- **CVE-2026-39817**：`go tool pack` 调用时未清理 `cmd/go` 中的输出路径（CWE-787 越界写）——构建期工具链漏洞，CI 构建环境注意工具版本。
- **CVE-2026-33811**：`net` 包处理超长 CNAME 响应时崩溃（DoS）——任何对外发起 DNS 查询的 Go 服务均受影响。
- **审计要点**：供应链基线应包含工具链自身版本（go 编译器、net 标准库）；对外 DNS 解析服务跟进修复版本并加 panic recover 兜底。

### Go 高频风险清单补充（静态扫描复核视角）

硬编码凭证；监听 `0.0.0.0` 全接口；**`err` 未检查**（错误被静默丢弃导致逻辑绕过，Go 特色高发）；`strconv.Atoi` 结果强转 `int16/32` 整数截断溢出；解压炸弹与压缩包内路径穿越；`net/http` 未设超时（慢请求 DoS）；弱算法 DES/RC4/MD5/SHA1、RSA<2048；`math/rand` 当安全随机数（应 `crypto/rand`）；切片/数组越界。
**审计要点**：govulncheck（依赖）+ gosec（代码模式）双跑是基线；人工优先看 `err` 丢弃与类型截断这两类工具覆盖弱的逻辑层问题。

### 经典链模式：写 401 但不 return 式鉴权失效（Gitea LFS 链）

1. **鉴权失败不中断**：`requireAuth` 只写 401 状态码，**函数没有 return，后续业务逻辑照跑** → 未授权创建对象；
2. 对象 ID 未过滤 → `filepath.Join` 拼接 → 目录穿越任意读；
3. 读到服务端配置密钥 → 伪造 JWT 完整读写；
4. 先写临时文件、校验失败 defer 删除 → 条件竞争窗口任意写；
5. 文件型 session（Gob 序列化）写入伪造身份提权。

**审计要点**：Go 中间件/鉴权函数必须确认失败后是否真正中断流程（`return`/`Abort`/panic 链），这是 Go 生态独有的高频坑；`filepath.Join` 不防穿越，ID 类参数先做字符集白名单；"先写后校验"模式天然带竞争窗口。

> 来源：阿里云漏洞库 golang 产品页（2026-07-09 快照）；ScaleBit《B² Network zkEVM Final Audit Report》；wh0ale《go代码审计》（Gitea LFS 链经典分析）；Go 代码审计学习系列（2026 更新版）。
