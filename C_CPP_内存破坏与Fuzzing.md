# C/C++ 内存破坏审计与 Fuzzing 分册

> 适用：C/C++ 服务端、解析库、中间件（Redis/Nginx 类目标）。
> 更新：2026-07-31（v1.0）

---

## 一、内存破坏模式清单

| 模式 | 典型成因 | 审计关注点 |
|---|---|---|
| 栈溢出 | strcpy/strcat/sprintf/gets/memcpy 定长目标 | 长度来源是否用户可控、有无边界检查 |
| 堆溢出 | malloc(n) 后写入 > n；n 计算溢出（见整数） | size 计算式、结构体+变长数组分配 |
| UAF | free 后指针未清空，回调/异常路径重复释放 | 错误处理分支里的 free、引用计数 |
| Double free | 同一指针两条路径 free；共享资源释放 | 错误清理路径与正常路径重叠 |
| OOB 读/写 | 索引/长度未校验（负数、过大） | 长度字段来自报文头、协议解析 |
| 整数溢出 | 有符号/无符号混用、乘法加法溢出后 malloc | `len*size+header` 式分配计算 |
| 类型混淆 | union/void* 强转、C++ 向下转型无 dynamic_cast | 虚表指针被控 → 劫持执行流 |
| 格式化字符串 | printf(user) 无格式串 | %n 写、%s 读，老代码仍有 |
| 未初始化使用 | 栈变量未初始化进条件/长度 | 编译器警告 -Wuninitialized |

**危险函数族（grep 清单）**：`strcpy strcat sprintf vsprintf gets scanf("%s") memcpy memmove strncpy(长度计算错误) realloc(旧指针失效) alloca(用户控大小)`

## 二、分配器与利用常识（glibc）

- chunk 结构（size/flags）、tcache（每线程缓存，无检查双重释放）→ tcache poisoning 是当今最常用入门利用
- fastbin dup、unsorted bin leak（拿 libc 地址）、house of 系列
- 防护对照：checksec 看 NX/Canary/PIE/Full RELRO，决定利用路径
- 审计结论写法：崩溃 ≠ 可利用；必须评估"数据可控程度 + 防护 + 稳定性"

## 三、Fuzzing 全流程（AFL++ 实战版）

1. **选目标**：有输入接口、逻辑独立、社区审计少的库/解析器成功率最高。
2. **插桩编译**：`afl-clang-fast/afl-clang-lto`（或 ASAN：`-fsanitize=address`，挖 UAF/堆溢出必备；UBSAN 挖整数/未定义行为）。ASAN 降速但崩溃报告质量极高。
3. **写 harness**：把库包成"读文件 → 调解析函数"的最小二进制；去掉 I/O 与随机性，保证可复现。
4. **种子与字典**：种子=合法且极简的样本（理解协议结构手工造）；字典=协议关键字/魔数（`-x dict`）。
5. **跑与监控**：多实例（-M/-S）；关注 exec speed 下跌与 hang 暴增（调 `-t`）；定期 `afl-cmin` 精简语料再开新轮。
6. **崩溃 triage**：`out/crashes/` 去重；GDB/ASAN 报告判型（SIGSEGV 不一定可利用，SIGABRT 多为断言）；区分"安全漏洞 / 普通 bug / 误报"。
7. **从崩溃到 PoC**：`checksec` 看防护 → 分析可控寄存器与内存布局 → 最小化输入（afl-tmin）→ 手工构造稳定触发 → 评估可控性 → 写报告。
8. **交叉复测**：AFL 语料喂给 libFuzzer/honggfuzz 互跑；`afl-cov` 看覆盖率盲区，定向补种子。

**AI 协同点**：harness 编写、字典提取、崩溃归因初判、PoC 骨架，都是可交给代理的环节；人类负责目标选择与最终利用评估。

## 四、从崩溃到利用链的推导步骤

1. 复现：同一输入 10 次稳定崩 → 进入分析
2. 归因：GDB `bt` + 内存布局，确定漏洞类型与可控变量
3. 可控性：输入哪些字节落到哪些寄存器/内存（pattern 偏移法）
4. 目标选择：返回地址 / 函数指针 / 虚表 / GOT（按防护定）
5. 信息泄露：没泄露先找泄露（格式化串、未初始化、OOB 读）
6. 拼接：泄露 + 写原语 → ROP/JOP → shellcode 或 system 调用
7. 稳定化：堆喷射/布局按摩，跨环境复测

## 五、审计 Checklist

- [ ] 危险函数族全文 grep，逐个看长度来源
- [ ] 所有 `malloc(len*size+k)` 式计算做整数溢出推演
- [ ] free 的所有路径（含错误分支）与指针清零
- [ ] 协议解析：报文头长度字段是否信任
- [ ] 编译选项：-fstack-protector/-D_FORTIFY_SOURCE=2/ASAN 测试构建
- [ ] 第三方内置库（miniz、libpng 老拷贝）版本核对

## 六、工具

AFL++（插桩 fuzzing）、libFuzzer/honggfuzz、ASAN/UBSAN/MSAN、GDB+pwndbg/gef、checksec、radare2/rizin、Valgrind、afl-cmin/afl-tmin/afl-cov

## 七、参考资料

- [从 AFL 模糊测试到 CVE 挖掘：实战全流程](https://blog.csdn.net/weixin_33801856/article/details/93088967)
- AFL++ 官方文档：https://aflplus.plus/
- pwndbg：https://github.com/pwndbg/pwndbg
- how2heap（glibc 利用练习）：https://github.com/shellphish/how2heap


---

## 时效条目（2026-07 批次）

### 基础设施组件 C 审计案例两则（本期重点）

**1. NGINX map 指令 15 年潜伏堆溢出（CVE-2026-42533）——"两遍求值信任自己的测量"**

- 成因（设计级缺陷）：NGINX 脚本引擎拼接字符串采用**两遍求值**（第一遍 LEN 测量所需缓冲区，第二遍 VALUE 写入），两遍共享 PCRE 捕获数组（`r->captures`）；当正则 `map` 的输出变量与前序正则捕获（如 location 的 `$1`）在同一字符串表达式中被引用、且捕获引用点晚于 map 变量时，map 正则的执行夹在两遍之间**覆写共享捕获状态**——LEN 遍按原捕获测量，VALUE 遍按攻击者可控的新捕获写入 → 长度与内容失配 → 堆溢出；反向情形（新捕获更短）泄露**未初始化堆数据**（默认 Ubuntu 24.04 单条未认证 GET 即可泄露堆/libc 指针，等于自带 ASLR 绕过，实验室 10/10）。
- 2011-03 引入，预认证、单请求触发；修复版本 1.30.4 / 1.31.3 / Plus 37.0.3.1。同根因家族两个月内第三枚（CVE-2026-42945 Rift 5 月已在野、CVE-2026-9256 rewrite 6 月）。
- **审计要点**：凡是"先测量后写入"的两遍式实现，检查两遍之间所有共享可变状态（正则捕获、缓存标志、迭代器）是否被快照/隔离——这是基础组件典型的潜伏型设计缺陷模式。
- 配置侧排查：正则捕获源（location/server_name/rewrite 带括号）与正则 map 变量同表达式混用的组合；临时缓解（改命名捕获）不完整，升级是唯一完整修复。

**2. Redis 认证后 RCE 双漏洞（CVE-2026-25589 等）**

- Stream consumer-group 共享 NACK 路径**双重释放**（6.2.22～8.8.0）；RedisBloom 模块 **TDigest 解析堆溢出**。认证后触发、复杂度低。
- **审计要点**：关注"共享结构体的销毁路径"——同一对象被两个逻辑所有者各释放一次，是长生命周期服务的高发模式；第三方模块解析器（TDigest、布隆过滤器参数解析）是堆溢出富矿区，模块与核心分开评估。

### 内核 CTF 技巧动向（2026 上半年）

- **eBPF variable-shift range confusion**（UofTCTF 2026）：验证器对可变移位运算的静态范围推导与运行时实际值不一致 → map value 越界读写 → `modprobe_path` 覆写提权；审计关注验证器 ALU 抽象解释精度。
- **per-CPU 栈指针破坏 + 栈 pivot**（TRX CTF 2026）：内核利用原语向"破坏每核私有状态"演进，绕过传统全局对象覆写检测。
- 经典路径仍有效：kmalloc UAF+竞争、`commit_creds(&init_cred)`、dirty pagetable。

### 补丁态势

微软 2026-07 单月修复 622 枚（Windows 416，约去年同期 3 倍），Win32k EoP 集群；厂商归因 AI 辅助挖洞规模化（详见综合分册）。Windows 内核方向关注：Win32k 句柄/对象引用计数、GDI 对象生命周期、驱动 IOCTL 校验与 double fetch。

> 来源：F5 公告 K000162097 与 Stan Shaw/Zhenpeng Lin 研究、friday-go.icu 攻击链分析、奇安信 CERT 通告、爱坤sec Redis PoC 分析、Rapid7/ZDI 补丁日评述、mito753/Kernel-Exploit-Dojo。
