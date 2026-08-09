# OSINT 与资产测绘

## 1. 知识点讲解

资产测绘的核心思路是「以点扩面」：从一个根域名或公司名出发，沿六条线扩展——域名线（子域名）、IP 线（IP 反查、C 段）、组织线（子公司/工作室/关联品牌）、指纹线（组件/框架/CMS）、人员线（邮箱/员工/泄露）、页面线（页脚「家庭网站」、友链、JS 中隐藏域名）。实战中后三条线最容易出惊喜。

## 2. 子域名枚举

```bash
# 被动源聚合（不触目标）
subfinder -d example.com -all -silent -o subs.txt
amass enum -passive -d example.com -o amass.txt

# 证书透明度（浏览器直接查）
# https://crt.sh/?q=%25.example.com&output=json

# 爆破（递归、快）
ksubdomain -d example.com -f subnames.txt -silent
puredns bruteforce subnames.txt example.com -r resolvers.txt

# DNS 解析验证 + 探活
puredns resolve all.txt -r resolvers.txt --write alive.txt
httpx -l alive.txt -title -tech-detect -status-code -o web.txt
```

要点：多工具结果取并集；解析用公共 resolver 列表防污染；httpx 输出状态码、标题、指纹三列是后续排兵布阵的依据。

## 3. IP 反查与旁站

- 同 IP 站点反查：ViewDNS.info、ipchaxun、VirusTotal（passive DNS）、SecurityTrails。
- 已知 IP 段反查域名常能发现「官网以外」的测试站、旧站、供应商代维站。
- C 段与 ASN：bgp.he.net 查 ASN 与宣告网段，对集团型企业尤其有效。

## 4. 页面深挖（人工金矿）

- 页脚「Family Site / 家庭网站 / 旗下品牌」下拉：集团官网常见，直接给出子公司域名清单。
- 招聘页、投资者关系页、新闻稿：暴露内部系统名、供应商、技术栈关键词。
- JS 文件与 sourcemap：隐藏的 API 域名、测试环境地址、AKSK（见 08 分册）。
- robots.txt、sitemap.xml、.git 泄露、备份文件（www.zip、backup.tar.gz）。

## 5. 人员与邮箱情报

```bash
# 邮箱格式推断与验证
theHarvester -d example.com -b all -l 500
hunter.io / snov.io 查邮箱格式（f.last@ / flast@）
# GitHub 泄露检索
# "example.com" password | api_key | secret | BEGIN RSA PRIVATE KEY
```

拿到邮箱格式 + 泄露库密码（见 01-03），就是密码喷洒与钓鱼的弹药（注意授权）。

## 6. 常用工具命令速查

| 工具 | 用途 | 核心命令 |
| --- | --- | --- |
| subfinder | 被动子域 | `subfinder -d d.com -all -silent` |
| amass | 主被动枚举 | `amass enum -passive -d d.com` |
| ksubdomain | 无状态爆破 | `ksubdomain -d d.com -f dict.txt` |
| puredns | 解析/爆破净化 | `puredns resolve in.txt -r resolvers.txt` |
| httpx | Web 探活指纹 | `httpx -l in.txt -title -td -sc` |
| nmap | 端口服务 | `nmap -sV -Pn -p- --min-rate 5000 IP` |
| fscan | 内网一把梭 | `fscan -h 10.0.0.0/24 -nopoc` |
| theHarvester | 邮箱/主机情报 | `theHarvester -d d.com -b all` |

> 合规提醒：subfinder/amass 被动模式不触目标；nmap/fscan 属主动扫描，须有授权。

## 7. 使用场景

- 黑盒开局：根域名 → 子域并集 → httpx 指纹 → 挑软柿子（旧系统、测试站、后台）。
- 集团目标：页脚家庭网站 + IP 反查 + 招聘/新闻交叉，往往能翻出报告里漏掉的资产。
- 打点无门：转战泄露情报（01-03）与钓鱼（03-01），换条路拿第一落脚点。

## 自测锚点

- [ ] 给一个域名，30 分钟内产出 ≥3 个工具并集的子域清单并完成探活。
- [ ] 能解释为什么 crt.sh 能查到从未公开解析过的子域名。
- [ ] 能在目标官网页脚/JS 中人工找出至少 2 个测绘引擎没收录的关联资产。
