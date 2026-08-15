# JavaScript / Node.js 代码审计分册

> 适用：Node.js 后端（Express/Koa/Nest）、前端构建链、npm 生态。
> 更新：2026-08-15（v1.4：Nabi AI — deprecated Server Action + Vault 单段通配）

---

## 1. 原型链污染（Node 特色高危）

- 特征：递归 `merge/extend/clone/defaultsDeep` 处理用户 JSON；`obj[a][b] = value` 键名可控。
- 利用：`{"__proto__":{"isAdmin":true}}` → 污染 Object.prototype → 后续任意对象继承该属性。
- 链到 RCE：污染 `shell`（child_process 选项）、`NODE_OPTIONS`（env 注入 `--require`）、模板引擎选项（ejs `outputFunctionName`）、`main`（npm 包解析）。
- 审计要点：lodash<4.17.12（CVE-2019-10744）、minimist、hoek 等历史 CVE 先查依赖版本；自写 merge 函数基本必中。

## 2. 命令执行

- `child_process.exec(cmd)`：字符串拼接即注入（走 /bin/sh）。
- `execFile/spawn`（shell:false）：注入不了分隔符，但**选项注入**仍在（如 git clone 的 `--upload-pack`、tar 的 `--checkpoint-action`）。
- `spawn(cmd, args, {shell:true})`：等价 exec，同样危险。
- 审计要点：grep `child_process`，逐一看参数来源；查 GTFOBins 确认选项注入面。

## 3. 代码执行与沙箱

- `eval/new Function/setTimeout("字符串")`：直接执行。
- `vm` 模块：**不是安全沙箱**，逃逸链成熟（this.constructor.constructor('return process')()）；见到 vm 跑用户代码即报。
- `require(变量)`：模块路径可控 → 加载远程/本地任意 js（配合上传即 RCE）。
- serialize-javascript / node-serialize：反序列化 IIFE（`{"rce":"_$$ND_FUNC$$_function(){...}()"}`）。

## 4. 路径与文件

- `fs.readFile(path.join(__dirname, user))`：join 不防 `../` 与绝对路径；Express `res.sendFile` 需 `root` 选项且禁 `..`（老版本可绕）。
- 上传：multer `filename` 回调若用原始文件名拼接 → 穿越写；busboy 同理看落地路径。
- 解压：adm-zip/tar 历史 Zip Slip CVE。

## 5. NoSQL 注入

- 特征：`Model.find({username: req.body.username})`——body 传对象 `{"$gt":""}` 恒真绕过登录。
- `$where` / mapReduce 执行 JS：直接代码执行。
- 防御反推：mongoose 6+ 默认 sanitizeFilter？不是默认，必须显式开启；见到 express 的 extended parser + mongo 直连即可疑。

## 6. Web 框架与中间件

- 中间件顺序错误：鉴权中间件注册在路由之后 / 只挂了部分路由组。
- CORS 通配 + credentials；JWT：算法混淆（none/HS256 用 RS256 公钥当 HMAC 密钥）、弱密钥、不校验 exp。
- Express 4 路径解析与代理层（trust proxy 误判 → IP 白名单绕过）。
- SSRF：axios/got/node-fetch URL 可控；http.get 重定向不自动跟随（差异点）。

## 7. 供应链（Node 重灾区）

- package.json：`scripts`（preinstall/postinstall 安装即执行）、依赖混淆（内部包名在公网被抢注）、未锁版本（无 lock 文件）、git 依赖指向可变分支。
- 审计动作：`npm audit`、看 lock 文件是否提交、grep scripts、比对依赖域名拼写（typosquatting）。

## 8. 前端联动（后端项目里的前端代码）

- DOM XSS：innerHTML/insertAdjacentHTML/document.write 源可控；postMessage 未校验 origin。
- 敏感信息：打包产物里的 key、source map 泄露源码。

## 9. 审计 Checklist

- [ ] grep：`eval|new Function|child_process|vm\.|__proto__|require\(`变量
- [ ] 所有 merge/clone 递归函数审原型链
- [ ] Mongo/Redis 查询对象是否直接吃 req.body
- [ ] package.json scripts + lock 文件 + npm audit
- [ ] 中间件挂载顺序与鉴权覆盖面
- [ ] JWT 验签逻辑（算法、密钥来源、exp）

## 10. 工具

npm audit / osv-scanner（依赖）、Semgrep js/ts 规则、CodeQL（JS 规则好）、eslint-plugin-security、Burp（重放）、node --inspect 调试

## 11. 时效条目（周更回链）

> 新模式按日期追加。供应链与原型链污染手法也可对照红队 `02_Web` / `02-03`。

### 2026-08-12 · 请求头 CRLF → 拆分 / Desync（PortSwigger 启示）

- **危险特征**：路径、自定义头、上游转发头拼接用户输入；未规范化 `\r`/`\n`；前后端/CDN 对 CL/TE 或换行语义不一致。
- **利用条件**：存在反向代理或连接复用；注入点能影响「下游所见的原始字节流」。
- **审计要点**：① grep 头拼接与 `setHeader`/`writeHead` 类 API；② 单元测试投 `%0d%0a` 应被拒绝或编码；③ 勿把「只触发了反射」当成最高影响——评估是否可升格为请求拆分。
- **自测**：在 Node 反代/网关示例中标出一处头拼接并写出应加的拒绝条件（不写完整走私载荷）。

### 2026-08-15 · 部分请求 / dangling-byte（HTTP Terminator 启示）

- **危险特征**：反向代理或自写 HTTP 解析对「未收齐的 body / 缺最后一字节」仍保持连接复用；前后端对「一条报文何时结束」不一致。
- **利用条件**：HTTP/1 连接复用；后端对方法/长度解析宽松。
- **审计要点**：① 自写解析器是否在 Content-Length 未满足时就切下一条；② 反代超时/半包如何转发；③ 勿只测完整畸形头——补一组「少 1 字节」用例。
- **自测**：在授权实验室对比完整请求与缺尾字节时后端是否提前回第二响应（不写完整 RQP 链）。
- **链接**：https://portswigger.net/research/http-terminator

### 2026-08-15 · deprecated Server Action 字段 + Vault `+` 单段通配（UIUCTF Nabi AI）

- **危险特征**：① Next.js `productionBrowserSourceMaps` 把 TypeScript 类型（含 **deprecated 仍声明的字段**）暴露到 `*.js.map`；② Server Action 仍读取该字段并原样当作上游 URL（头一并转发）；③ OpenBao/Vault 策略 `path "secret/data/+"`——`+` 是**单段通配**，不是「只匹配本意路径」。
- **利用条件**：源码图可下载；服务端未丢弃弃用字段；应用 token 策略过宽。链：SSRF 泄 `X-Vault-Token` → 读同级 `secret/data/*`。
- **审计要点**：① 生产是否关源码图；② grep deprecated / 可选字段是否仍进服务端；③ Vault/OpenBao 策略用字面路径，禁止图省事写 `+`/`*`；④ RSC `Next-Action` 入参与类型声明是否一致。
- **自测**：在授权实验室对一份 Next.js + Vault 示例：标出「类型有、表单无、服务端仍读」的字段，并对照 HCL 是否可用字面路径收窄（不写完整 SSRF 载荷）。
- **链接**：https://cybersecurityelite.com/ctf-writeups/uiuctf-2026-web-nabi-ai-writeup/

## 12. 参考资料

- 原型链污染到 RCE 链汇总（PortSwigger Research）：https://portswigger.net/research/server-side-prototype-pollution
- PayloadsAllTheThings（NoSQL 注入、SSTI）：https://github.com/swisskyrepo/PayloadsAllTheThings
- eslint-plugin-security：https://github.com/eslint-community/eslint-plugin-security
