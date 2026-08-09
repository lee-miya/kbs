# Python 代码审计分册

> 适用：Python Web（Flask/Django/FastAPI）、脚本与工具。
> 更新：2026-08-09（v1.2：Langflow 执行面时效）

---

## 1. 命令与代码执行

| 模式 | 危险特征 | 审计要点 |
|---|---|---|
| 命令注入 | `os.system(cmd)`、`subprocess.*(shell=True)`、`commands.getoutput` | 参数拼接即注入；shell=False 时检查首元素与选项注入 |
| eval/exec | `eval(`、`exec(` 直接吃用户输入 | 常见于"规则引擎""表达式配置"功能；沙箱逃逸手段极多，基本见到即高危 |
| 模板字符串执行 | `string.Template`、f-string 拼接后 eval | 与 SSTI 联动看 |
| import 劫持 | `__import__(可变字符串)`、sys.path 插入、pickle 反序列化触发 import | 模块名可控即 RCE |

## 2. 反序列化

- **pickle**：`pickle.loads(可控)` 即 RCE。原理：`__reduce__` 返回 `(callable, args)`，如 `(os.system, ("id",))`。变形：cPickle、pickletools 混淆、opcode 手工构造绕过简单黑名单。
- **yaml**：`yaml.load`（PyYAML<6 默认 FullLoader/UnsafeLoader）→ `!!python/object/apply:os.system ["id"]`；只应使用 `yaml.safe_load`。审计看到 `.load(` 不带 Loader 参数即报。
- 其他：marshal、shelve（底层 pickle）、dill、jsonpickle（可控 `py/object` 键）。
- **拦截点**：项目里凡是"缓存、session、任务队列（celery 早期 pickle 序列化器）"都可能有反序列化入口。

## 3. SSTI（模板注入）

- 探测：`{{7*7}}`（Jinja2/Twig 通用）、`${7*7}`（Mako）。
- Jinja2 利用链：`{{''.__class__.__mro__[1].__subclasses__()}}` 找到 `subprocess.Popen` / `os._wrap_close` 下标 → 执行命令；或 `{{self.__init__.__globals__}}` 拿 os。
- 审计要点：找 `render_template_string(用户输入)`、`Template(user_input)`——参数化传值安全，拼进模板本体才危险。

## 4. 路径与文件

- 路径穿越：`open(os.path.join(base, user))`——join 不防绝对路径（第二参数以 / 开头直接覆盖）；`werkzeug.utils.secure_filename` 才是正解。
- 解压穿越（Zip Slip）：`tarfile.extractall`（Python<3.12 默认不过滤，CVE-2007-4559 挂了 15 年才修）、`zipfile.extract` 成员名带 `../`。
- 临时文件：`tempfile.mktemp`（已废弃，可预测）。

## 5. SSRF

- `requests.get(用户URL)`、`urllib.request.urlopen`：审计重定向跟随（requests 默认跟随）、scheme 过滤是否只判 startswith("http")。
- 进阶：urllib 的 CRLF 注入（老版本）、gopher 打内网服务。

## 6. Web 框架特有

| 框架 | 高危点 |
|---|---|
| Flask | debug=True 上线（PIN 码可推算：机器名+MAC 等，/console 直接 RCE）；session cookie 弱 secret 可伪造（itsdangerous 签名）；`request.args` 进 eval |
| Django | ORM 的 `extra()/RawSQL()/raw()` 拼接；debug 页泄露配置；`pickle`  session 序列化器（早期） |
| FastAPI | 依赖注入链中被忽略的同步阻塞 SSRF；`FileResponse` 路径拼接 |
| Tornado | `xsrf` 配置缺失；模板 `{% raw %}` |

## 7. 依赖与供应链

- `pip-audit`、`safety check` 跑依赖；requirements.txt 未锁版本 = 供应链敞口。
- setup.py/安装脚本里藏命令执行（pip 安装即触发）。

## 8. 审计 Checklist

- [ ] grep：`eval|exec|os.system|subprocess|pickle|yaml.load|__import__|render_template_string|extractall`
- [ ] Flask debug / secret_key 硬编码检查
- [ ] 文件操作 join 绝对路径陷阱
- [ ] ORM 原生 SQL 拼接点
- [ ] requirements 与锁文件审计（pip-audit）
- [ ] 序列化器配置（celery/session/cache）

## 9. 工具

bandit（官方安全扫描）、Semgrep python 规则集、CodeQL、pip-audit、RIPS（不支持 py，用 Semgrep 补）、mitmproxy 看回调流量

## 10. 时效条目（周更回链）

> 新模式按日期追加。手法向内容见红队 `02_Web渗透`；此处只留代码特征。

### 2026-08-09 · Langflow / 低代码「校验即执行」面（CVE-2026-9198）

- **危险特征**：存在「校验/预览/试运行代码」类 API（如 `validate/code`）；装饰器或默认参数在导入/校验阶段即有副作用；`auto_login` / 默认超管令牌可对任意网络调用者签发。
- **利用条件**：API 对非本机可达；鉴权可关或默认可绕过；执行沙箱弱或无。
- **审计要点**：① 列出一切执行用户代码的端点；② 校验路径是否已 eval/exec；③ 默认鉴权与绑定地址；④ 升级优先于「加 WAF」。
- **自测**：在示例 Agent 项目中标出「只读校验」名不副实的函数。

（下期继续：其他 Python Agent 框架同类模式对照。）

## 11. 参考资料

- bandit 规则文档：https://bandit.readthedocs.io/
- pickle 安全模型：https://docs.python.org/3/library/pickle.html
- Jinja2 SSTI 经典利用链（payloadsallthethings）：https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Server%20Side%20Template%20Injection
