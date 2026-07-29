#!/bin/bash
# sync_daemon.sh — inotify 监控文件变化，实时备份

WATCH_FILE="/ldp/watch.txt"
RULES_FILE="/ldp/rules.txt"
WORKSPACE="/mnt/workspace/root"

do_sync() {
    echo "[sync_daemon] $(date '+%H:%M:%S') 触发同步..."
    sleep 6  # 防止 429 限流

    # ── S3 ───────────────────────────────────────────────────
    if [ -n "${S3_BUCKET:-}" ] && [ -n "${S3_ACCESS_KEY:-}" ]; then
        export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
        export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
        export AWS_DEFAULT_REGION="${S3_REGION:-us-east-1}"
        S3_ENDPOINT_ARG=""
        [ -n "${S3_ENDPOINT:-}" ] && S3_ENDPOINT_ARG="--endpoint-url ${S3_ENDPOINT}"

        rm -rf /tmp/root_sync/
        rclone copy /root/ /tmp/root_sync/ \
            --filter-from "$RULES_FILE" \
            --no-check-certificate --log-level ERROR 2>/dev/null || true
        tar -czf /tmp/data_hermes.tar.gz -C /tmp root_sync/ 2>/dev/null || true
        rm -rf /tmp/root_sync/

        if [ -n "${BACKUP_ENC_PASS:-}" ]; then
            echo "$BACKUP_ENC_PASS" | gpg --batch --yes --passphrase-fd 0 \
                --symmetric --cipher-algo AES256 \
                -o /tmp/data_hermes.tar.gz.gpg \
                /tmp/data_hermes.tar.gz 2>/dev/null
            mv /tmp/data_hermes.tar.gz.gpg /tmp/data_hermes.tar.gz
        fi

        aws s3 cp ${S3_ENDPOINT_ARG} \
            /tmp/data_hermes.tar.gz \
            "s3://${S3_BUCKET}/data_hermes.tar.gz" 2>/dev/null || true
        rm -f /tmp/data_hermes.tar.gz

    # ── WebDAV ───────────────────────────────────────────────
    elif [ -n "${WEBDAV_URL:-}" ] && [ -n "${WEBDAV_USER:-}" ]; then
        cat > /tmp/rclone-wd.conf << EOF
[webdav]
type = webdav
url = ${WEBDAV_URL}
vendor = other
user = ${WEBDAV_USER}
pass = $(rclone obscure "${WEBDAV_PASS:-}")
headers = User-Agent,Zotero/8.0
EOF
        rm -rf /tmp/root_sync/
        rclone copy /root/ /tmp/root_sync/ \
            --filter-from "$RULES_FILE" \
            --no-check-certificate --log-level ERROR 2>/dev/null || true
        tar -czf /tmp/data_hermes.tar.gz -C /tmp root_sync/ 2>/dev/null || true
        rm -rf /tmp/root_sync/

        if [ -n "${BACKUP_ENC_PASS:-}" ]; then
            echo "$BACKUP_ENC_PASS" | gpg --batch --yes --passphrase-fd 0 \
                --symmetric --cipher-algo AES256 \
                -o /tmp/data_hermes.tar.gz.gpg \
                /tmp/data_hermes.tar.gz 2>/dev/null
            mv /tmp/data_hermes.tar.gz.gpg /tmp/data_hermes.tar.gz
        fi

        rclone copy /tmp/data_hermes.tar.gz webdav: \
            --config /tmp/rclone-wd.conf \
            --no-check-certificate 2>/dev/null || true
        rm -f /tmp/data_hermes.tar.gz /tmp/rclone-wd.conf

    # ── ModelScope 本地 ──────────────────────────────────────
    else
        mkdir -p "$WORKSPACE"
        rclone sync /root/ "$WORKSPACE/" \
            --filter-from "$RULES_FILE" \
            --no-check-certificate \
            --log-level ERROR \
            2>&1 | grep -v "xattr" || true
    fi

    echo "[sync_daemon] $(date '+%H:%M:%S') 同步完成"
}

[ -f "$WATCH_FILE" ] || { echo "[sync_daemon] 未找到 $WATCH_FILE"; exit 1; }

mapfile -t WATCH_PATHS < <(grep -v '^#' "$WATCH_FILE" | grep -v '^$')
echo "[sync_daemon] 监控路径: ${WATCH_PATHS[*]}"

while true; do
    inotifywait -r -e modify,create,delete,move \
        --exclude '(\.git|\.venv|venv|node_modules)' \
        "${WATCH_PATHS[@]}" 2>/dev/null && do_sync
done
