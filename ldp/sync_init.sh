#!/bin/bash
# sync_init.sh — 启动时从远程/本地恢复 Hermes 配置

WORKSPACE="/mnt/workspace/root"
TMP_HELP="/tmp/使用帮助.html"
DESKTOP_HELP="/root/Desktop/使用帮助.html"

# 临时移走桌面帮助文件，防止被恢复覆盖
[ -f "$DESKTOP_HELP" ] && mv "$DESKTOP_HELP" "$TMP_HELP" 2>/dev/null || true

restore_done=0

# ── 模式1：S3 远程恢复 ────────────────────────────────────
if [ -n "${S3_BUCKET:-}" ] && [ -n "${S3_ACCESS_KEY:-}" ]; then
    echo "[sync_init] S3 模式：从 ${S3_BUCKET} 拉取备份..."
    export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
    export AWS_DEFAULT_REGION="${S3_REGION:-us-east-1}"
    S3_ENDPOINT_ARG=""
    [ -n "${S3_ENDPOINT:-}" ] && S3_ENDPOINT_ARG="--endpoint-url ${S3_ENDPOINT}"

    if aws s3 cp ${S3_ENDPOINT_ARG} \
        "s3://${S3_BUCKET}/data_hermes.tar.gz" /tmp/data_hermes.tar.gz 2>/dev/null; then
        if [ -n "${BACKUP_ENC_PASS:-}" ]; then
            echo "[sync_init] GPG 解密..."
            echo "$BACKUP_ENC_PASS" | gpg --batch --yes --passphrase-fd 0 \
                -d /tmp/data_hermes.tar.gz > /tmp/data_dec.tar.gz 2>/dev/null
            mv /tmp/data_dec.tar.gz /tmp/data_hermes.tar.gz
        fi
        tar -xzf /tmp/data_hermes.tar.gz -C / 2>/dev/null || true
        rm -f /tmp/data_hermes.tar.gz
        restore_done=1
        echo "[sync_init] S3 恢复完成"
    else
        echo "[sync_init] S3 无历史备份，跳过"
    fi

# ── 模式2：WebDAV 远程恢复 ───────────────────────────────
elif [ -n "${WEBDAV_URL:-}" ] && [ -n "${WEBDAV_USER:-}" ]; then
    echo "[sync_init] WebDAV 模式：从 ${WEBDAV_URL} 拉取..."
    cat > /tmp/rclone-wd.conf << EOF
[webdav]
type = webdav
url = ${WEBDAV_URL}
vendor = other
user = ${WEBDAV_USER}
pass = $(rclone obscure "${WEBDAV_PASS:-}")
headers = User-Agent,Zotero/8.0
EOF
    if rclone copy webdav:data_hermes.tar.gz /tmp/ \
        --config /tmp/rclone-wd.conf \
        --no-check-certificate 2>/dev/null; then
        if [ -n "${BACKUP_ENC_PASS:-}" ]; then
            echo "$BACKUP_ENC_PASS" | gpg --batch --yes --passphrase-fd 0 \
                -d /tmp/data_hermes.tar.gz > /tmp/data_dec.tar.gz 2>/dev/null
            mv /tmp/data_dec.tar.gz /tmp/data_hermes.tar.gz
        fi
        tar -xzf /tmp/data_hermes.tar.gz -C / 2>/dev/null || true
        rm -f /tmp/data_hermes.tar.gz /tmp/rclone-wd.conf
        restore_done=1
        echo "[sync_init] WebDAV 恢复完成"
    else
        echo "[sync_init] WebDAV 无历史备份，跳过"
        rm -f /tmp/rclone-wd.conf
    fi

# ── 模式3：ModelScope /mnt/workspace 本地恢复 ───────────
elif [ -d "$WORKSPACE" ]; then
    echo "[sync_init] ModelScope 本地模式：从 ${WORKSPACE} 恢复..."
    rclone copy "$WORKSPACE/" /root/ \
        --no-check-certificate \
        --exclude ".hermes/hermes-agent/**" \
        --exclude ".git/**" \
        --exclude ".venv/**" \
        --exclude "venv/**" \
        --exclude "node_modules/**" \
        --log-level ERROR \
        2>&1 | grep -v "xattr" || true
    restore_done=1
    echo "[sync_init] 本地恢复完成"

else
    echo "[sync_init] 无历史数据，首次启动"
fi

# 还原桌面帮助文件
[ -f "$TMP_HELP" ] && mv "$TMP_HELP" "$DESKTOP_HELP" 2>/dev/null || true

echo "[sync_init] 完成（restore_done=${restore_done}）"
