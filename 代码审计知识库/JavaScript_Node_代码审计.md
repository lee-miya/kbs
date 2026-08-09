# JavaScript / Node.js 代码审计分册

> 适用：Node.js 后端（Express/Koa/Nest）、前端构建链、npm 生态。
> 更新：2026-08-09（v1.1：补时效条目区；与体例对齐）

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

（本批暂无新条。）

## 12. 参考资料

- 原型链污染到 RCE 链汇总（PortSwigger Research）：https://portswigger.net/research/server-side-prototype-pollution
- PayloadsAllTheThings（NoSQL 注入、SSTI）：https://github.com/swisskyrepo/PayloadsAllTheThings
- eslint-plugin-security：https://github.com/eslint-community/eslint-plugin-security
