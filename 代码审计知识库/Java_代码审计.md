# Java 代码审计分册

> 适用：Java Web（Servlet/Spring/Struts/Shiro 体系）及中间件。
> 更新：2026-08-12（v1.2：JWT 验签失效链时效）

---

## 1. 反序列化（Java 头号高危）

**入口特征**（grep 优先级从高到低）：
- `ObjectInputStream.readObject()` / `readUnshared()`——数据可控即高危
- `XMLDecoder.readObject()`（天然 RCE）
- fastjson `JSON.parse/parseObject`（按版本对 autoType 绕过史）
- Jackson `readValue` + 开启 defaultTyping / 已知 gadget 多态
- Hessian/Dubbo RPC 接口、SnakeYAML（`new Yaml().load` 非 SafeConstructor）、XStream、Kryo
- Shiro rememberMe（<1.2.4 硬编码密钥；之后版本查密钥泄露与 Padding Oracle <1.4.2）

**利用链常识**：
- 依赖有 commons-collections（3.x/4.x）→ CC 链；commons-beanutils → CB 链；无依赖 → JDK 原生链（如 Jdk7u21）
- 经典 CC1 思路：AnnotationInvocationHandler.readObject → TransformedMap/LazyMap → ChainedTransformer → InvokerTransformer 反射执行 Runtime.exec（注意：JDK 高版本该类不再可序列化，衍生 CC6 走 HashMap.readObject → hash → TiedMapEntry.hashCode → LazyMap.get）
- 工具：ysoserial 直接出 payload；按目标依赖选链，DNSLog 链先盲打探活
- JDBC 反序列化：可控 JDBC URL 时打 MySQL `autoDeserialize=true` + queryInterceptors 链

**防御识别（反推薄弱点）**：重写了 resolveClass 做白名单（SerialKiller/ValidatingObjectInputStream/JEP290）→ 找白名单内可拼的链或找未过滤的第二入口。

## 2. 表达式注入

- SpEL：`expression.getValue(用户输入)`，payload `T(java.lang.Runtime).getRuntime().exec(...)`；Spring Cloud Gateway CVE-2022-22947 即此类
- OGNL（Struts2）：`%{...}` 求值点，历史 S2-0xx 系列全是模式教材
- MVEL/EL（JSP EL `${}` 拼接）、Groovy（GroovyShell/ScriptEngine）

## 3. SSTI（模板注入）

- Freemarker：`${...}` 拼入用户输入 → `<#assign value="freemarker.template.utility.Execute"?new()>${value("id")}`
- Velocity：`#set($x="")$x.class.forName("java.lang.Runtime")...` 反射链
- Thymeleaf：预处理 `__${...}__::` 片段拼接场景（CVE-2021-43466 思路）
- 审计要点：找 Template.process/merge 前是否把用户输入拼进模板本体（不是参数化传值）

## 4. SQL 注入

- MyBatis：XML 里 `${}` 直接拼接 = 注入（`#{}` 才预编译）；like/in/order by 三处开发者最爱用 `${}`；`@Select` 注解同理
- JDBC 原生：`createStatement` + 字符串拼接；Hibernate HQL 拼接
- 二次注入与存储过程场景同样存在

## 5. XXE

- 特征：`DocumentBuilderFactory/SAXParserFactory/XMLReader/Unmarshaller` 未设置
  `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)` 或未禁外部实体
- 审计默认假设：**凡见 XML 解析先查三行禁用配置**，缺即报

## 6. SSRF

- 特征：`HttpURLConnection/HttpClient/RestTemplate/OkHttp/JSoup.connect/URL.openStream` 的 URL 可控
- 加固绕过：只判 host 字符串不含内网 → 用 DNS rebinding、重定向、进制 IP、user@host 混淆
- 云环境直接打 169.254.169.254 元数据

## 7. 命令与代码执行

- `Runtime.exec/ProcessBuilder`：注意 exec(String) 按空格切分的陷阱；参数数组形式仍可能选项注入
- `ScriptEngine.eval`（JS/Groovy）、SpEL（见上）、Javassist/ASM 动态字节码：可控字节码或源码片段即 RCE；审计插桩逻辑时注意 `ClassPool.getDefault().makeClass`、CtClass 插入点来源
- 动态加载：`URLClassLoader` 可控 URL、`Class.forName` 类名可控（配合静态块/构造器副作用）

## 8. 内存马特征（红队向，审计查杀两用）

- Filter 型：动态注册 Filter 到 StandardContext（filterDefs/filterMaps/filterConfigs），常借 Javassist/反射注入，url-pattern 通配
- Servlet/Listener 型同理；Spring 型注册 Controller/Interceptor
- 查杀要点：遍历 context 的 filterMaps 找无 class 文件对应的注册项；排查 JVM 内新增类加载记录
- 审计启发：看到项目里有"动态注册组件"的工具类，优先审其调用方是否鉴权

## 9. 文件操作

- 任意读写/删除：`new File(path拼接)`、Files.write；路径穿越过滤不严（`..`、双写、绝对路径覆盖相对）
- Zip Slip：解压 `ZipEntry.getName()` 未校验 `../`（审计所有解压工具类）
- 上传：Spring MultipartFile 直接 transferTo 拼接文件名

## 10. 组件速查（见版本先联想）

| 组件 | 高危版本/点 |
|---|---|
| Shiro | <1.2.4 反序列化硬编码密钥；<1.4.2 Padding Oracle；<1.5.2/1.7.x 权限绕过（与 Spring 路径归一化差异） |
| fastjson | ≤1.2.68 autoType 多轮绕过史；1.2.80 之后看 safeMode |
| Log4j2 | 2.0–2.14.1 JNDI（CVE-2021-44228） |
| Spring | 4.x/5.x 历史：CVE-2022-22965（Spring4Shell，JDK9+ + WAR 部署）、CVE-2022-22947（Gateway SpEL） |
| Struts2 | S2 系列 OGNL，devMode 开启 |
| Dubbo | Hessian 反序列化多 CVE |
| Tomcat Tribes / EncryptInterceptor | CVE-2026-34486：解密失败仍 `messageReceived` → 反序列化（见时效条目） |

## 11. 审计 Checklist

- [ ] 入口枚举：@*Mapping、web.xml servlet/filter、RPC 接口、消息队列消费者、定时任务
- [ ] readObject/XMLDecoder/parse 全家桶逐点确认数据可控性
- [ ] pom.xml/build.gradle 依赖对照组件速查表与公开 CVE
- [ ] XML/Excel/压缩包等文件解析点（POI、PDFBox 常是入口）
- [ ] MyBatis 全文搜 `${`
- [ ] 鉴权注解（@PreAuthorize/Shiro 注解）覆盖度：有无"靠 Filter 顺序兜底"的漏网路径
- [ ] 动态注册/动态加载工具类的调用方鉴权

## 12. 工具

CodeQL（Java 规则成熟，适合批量 sink 回溯）、tabby（国产 Java 静态分析）、find-sec-bugs（SpotBugs 安全插件）、ysoserial（链生成）、marshalsec（各格式 payload）、JNDI-Injection-Exploit、IDEA 远程调试

## 13. 时效条目（周更回链）

### 2026-08-09 · Tomcat EncryptInterceptor fail-open（CVE-2026-34486）

- **危险特征**：安全拦截器在 catch 中只打日志，随后仍把原始 `msg` 交给下游；下游含原生反序列化。
- **利用条件**：集群启用 EncryptInterceptor；attacker 可达 Tribes receiver；classpath 有可用 gadget 时升至 RCE。
- **审计要点（通杀）**：凡「验签/解密/鉴权 → 业务」管道，失败路径必须中断；对安全补丁做回归 diff，盯控制流是否被挪出 try。
- **自测锚点**：在任意 Java 项目中找出一处「catch 后继续用未校验输入」的候选并标注文件:行号。

### 2026-08-09 · CI/CD 管理面未认证反序列化（TeamCity CVE-2026-63077 启示）

- **危险特征**：构建/CI 产品对 HTTP(S) 请求做 Java 原生反序列化或等价对象还原；端点无需登录或仅弱鉴权。
- **利用条件**：管理面或 Agent 通信口暴露；classpath 可构造 gadget（视实现而定）。
- **审计要点**：① 枚举所有 `ObjectInputStream` / 自定义反序列化读口；② 是否绑定本机、是否强制认证；③ 构建凭据与仓库令牌是否与执行面同进程。
- **自测**：对照官方 advisory，列出「应禁止公网」的端口/路径类清单（不写完整载荷）。

### 2026-08-12 · JWT/S2S「解析密钥 ≠ 验签」（SharePoint CVE-2026-55040 启示）

- **危险特征**：自建 Bearer/S2S 校验中显式 `RequireSignedTokens = false`；或仅用 `x5t`/密钥标识**解析** SigningToken，却从不对签名做密码学验证；「签名非空字符串」即视为通过。
- **利用条件**：未认证可取得可信证书指纹/元数据（如公开 JWKS/STS 元数据端点）；可提交自定义 JWT。
- **审计要点**：① 全库搜 `RequireSignedTokens`、自写 `ValidateToken`；② 确认 audience/issuer **与** 签名校验均启用且不可被配置关掉；③ 嵌套 actor/内部 token 须各自验签，禁止「外层 none + 内层假签」。
- **自测锚点**：在任意 Java/.NET 身份模块中标出「取密钥」与「验签」是否为两个独立、均不可跳过的步骤。

### 2026-08-12 · Apache Fury「关注册 + 不完整黑名单」（AliCTF Fileury 启示）

- **危险特征**：`Fury.builder().requireClassRegistration(false)`（或等价「允许未注册类」）；仅靠 `disallowed.txt`/类名黑名单拦 gadget；黑名单未覆盖 AspectJ `SimpleCache$StoreableCachingMap`、部分 CC LazyMap/TiedMapEntry 组合。
- **利用条件**：反序列化入口可达；classpath 含 AspectJ weaver / Commons Collections 等；黑名单非 allowlist。
- **审计要点**：① 搜 `requireClassRegistration`、`deserialize(`；② 生产必须 **白名单注册** 或等价 allowlist，禁止只靠 deny list；③ 评估「写文件链」与 RCE 链同等优先级（非 RCE 也可落马）。
- **自测锚点**：列出项目中一切二进制反序列化库（Fury/Hessian/Java 原生）及各自的类过滤策略类型（allow vs deny）。
- **局限**：WP 发布时间早于本周窗口；手法仍可迁移，标「复扫升格」。

## 14. 参考资料

- [Java 反序列化备忘录（GrrrDog）](https://github.com/GrrrDog/Java-Deserialization-Cheat-Sheet)
- [CC1 链逐行审计分析](https://www.cnblogs.com/kgty/p/18487179)、[CC6 链分析](https://www.cnblogs.com/kgty/p/18574218)
- [长亭：Java 代码审计不能忽略的思路](https://rivers.chaitin.cn/blog/cqcthkp0lnee0vjd57ig)
- [代码审计总结仓库（zxcvbn001/CodeReview）](https://github.com/zxcvbn001/CodeReview)
