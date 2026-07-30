#!/bin/bash
# 恢复历史配置 + 执行用户自定义启动脚本 + 后台启动实时同步守护进程
# 顺序不能换：先恢复(sync_init) → 再跑用户脚本(ldp-startup) → 最后才起监控同步(sync_daemon)，
# 不然 sync_daemon 会在恢复完成前就监控到文件变化，触发一次没有意义的同步。

/ldp/sync_init.sh

if [ -x /root/ldp-startup/main.sh ]; then
    /root/ldp-startup/main.sh
fi

nohup /ldp/sync_daemon.sh > /tmp/sync_daemon.log 2>&1 &
