#!/bin/bash
/ldp/sync_init.sh
/root/ldp-startup/main.sh
nohup /ldp/sync_daemon.sh >/dev/null 2>&1 &
