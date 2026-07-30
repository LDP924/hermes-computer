#!/bin/bash

start_services() {
    echo "[*] 启动服务..."

    export USER="${USER:-root}"
    export HOME="${HOME:-/root}"
    export DISPLAY=":1"
    export PATH="/root/.local/bin:/usr/local/node/bin:/root/.hermes/hermes-agent/venv/bin:$PATH"

    VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
    VNC_DEPTH="${VNC_DEPTH:-24}"
    VNC_PORT=5901
    NOVNC_PORT=7860
    NOVNC_PATH="/usr/share/novnc"

    # ── VNC 密码配置 ──────────────────────────────────────────
    # 按你的要求：没传密码就不设防，不再随机生成兜底密码。
    # 环境变量名是 VNC_PASSWD（没有 ORD），ModelScope 创空间的环境变量
    # 那边填的名字必须跟这个一字不差，填成 VNC_PASSWORD 之类的都读不到。
    if [ -n "${VNC_PASSWD}" ]; then
        mkdir -p "${HOME}/.vnc"
        # 直接用 tigervnc-common 自带的 vncpasswd，不再手写 DES——
        # 之前那版手写实现只做了位翻转，没有真正做 DES 加密，
        # 生成的文件从格式上就不是合法的密码文件，导致输入什么密码都提示不对。
        # Trixie 上 TigerVNC 1.15 把命令改名叫 tigervncpasswd 了（从 tigervnc-common
        # 挪到了 tigervnc-tools 包），Bookworm 上还是老名字 vncpasswd——两个都探测一下，
        # 不管以后跑在哪个 Debian 版本上都不用再改这一行。
        VNCPASSWD_BIN="$(command -v tigervncpasswd || command -v vncpasswd)"
        if [ -z "$VNCPASSWD_BIN" ]; then
            echo "[!] 找不到 tigervncpasswd/vncpasswd，VNC 密码没设上，请检查 tigervnc-tools 是否装了"
        else
            echo "${VNC_PASSWD}" | "$VNCPASSWD_BIN" -f > "${HOME}/.vnc/passwd"
        fi
        chmod 600 "${HOME}/.vnc/passwd"
        VNC_SECURITY_ARGS="-SecurityTypes VncAuth -rfbauth ${HOME}/.vnc/passwd"
    else
        VNC_SECURITY_ARGS="-SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
    fi


    # 清理残留锁文件（Docker 重启场景）
    vncserver -kill "${DISPLAY}" 2>/dev/null || true
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

    # ── 启动 TigerVNC ────────────────────────────────────────
    echo "[*] 启动 TigerVNC on ${DISPLAY} (${VNC_GEOMETRY})..."
    vncserver "${DISPLAY}" \
        -geometry "${VNC_GEOMETRY}" \
        -depth "${VNC_DEPTH}" \
        $VNC_SECURITY_ARGS \
        -localhost no \
        -fg \
        $DEMO_ARGS &

    # 等待 VNC 端口就绪（最多 30s）
    echo "[*] 等待 VNC 就绪（端口 ${VNC_PORT}）..."
    for i in $(seq 1 30); do
        if ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}" || \
           netstat -tlnp 2>/dev/null | grep -q ":${VNC_PORT}"; then
            echo "[✓] VNC 已就绪"
            break
        fi
        sleep 1
    done

    # 继承 dbus 环境（xstartup 写入的）
    source /tmp/dbus-session.env 2>/dev/null || true
    export DBUS_SESSION_BUS_ADDRESS

    # Xfce4 桌面环境变量
    export XDG_CURRENT_DESKTOP=XFCE
    export XDG_SESSION_TYPE=x11
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    export INPUT_METHOD=fcitx
    export SDL_IM_MODULE=fcitx
    mkdir -p /tmp/root-runtime
    chmod 700 /tmp/root-runtime
    export XDG_RUNTIME_DIR=/tmp/root-runtime

    # Demo 模式壁纸
    # ⚠ TODO(LDP924 待确认)：下面这行 rm -rf /mnt/workspace/root 会清空
    # ossfs 挂载的持久化 OSS 目录，而条件判断的是主机名包含 "-ldp924-"——
    # 目前看到的所有你自己的容器主机名都命中这个条件，这会导致每次启动都
    # 清掉 sync_init.sh 要恢复的历史数据。如果本意是"公开演示模式下清空"，
    # 这个判断条件方向反了；如果就是要在自己环境下清空，这行可以取消注释。
    # 确认清楚之前先注释掉，不替你做这个决定。
    if [[ "$(hostname)" == *"-ldp924-"* ]]; then
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -s /usr/share/xfce4/backdrops/xfce-verticals.png 2>/dev/null || true
        # rm -rf /mnt/workspace/root 2>/dev/null || true
    fi

    # ── 启动 noVNC ───────────────────────────────────────────
    echo "[*] 启动 noVNC，监听端口 ${NOVNC_PORT}..."
    # 创建自动跳转首页（viewport解决手机只显示一半的问题）
    cat > "${NOVNC_PATH}/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&reconnect=true&reconnect_delay=2000&resize=remote&view_only=false&quality=6&compression=2&show_dot=false">
<title>正在连接桌面...</title>
<style>
  body{background:#1a1a2e;color:#cdd6f4;font-family:sans-serif;
    display:flex;align-items:center;justify-content:center;
    height:100vh;margin:0;flex-direction:column;gap:12px;}
  .spinner{width:40px;height:40px;border:4px solid #313244;
    border-top-color:#89b4fa;border-radius:50%;animation:spin 0.8s linear infinite;}
  @keyframes spin{to{transform:rotate(360deg)}}
</style>
</head>
<body>
<div class="spinner"></div>
<p>⏳ 正在连接远程桌面...</p>
</body>
</html>
HTMLEOF

    websockify \
        --web "${NOVNC_PATH}" \
        --heartbeat 30 \
        "0.0.0.0:${NOVNC_PORT}" \
        "localhost:${VNC_PORT}" &

    echo ""
    echo "============================================"
    echo "  Xfce4 桌面已启动！"
    echo "  访问地址: http://<host>:${NOVNC_PORT}"
    echo "  分辨率:   ${VNC_GEOMETRY}"
    echo "  时区:     Asia/Shanghai (UTC+8)"
    echo "  语言:     zh_CN.UTF-8"
    echo "  特效:     已全部禁用（最流畅模式）"
    echo "  输入法:   Fcitx5 拼音（Ctrl+Shift 切换）"
    echo "  浏览器:   Google Chrome（默认）"
    echo "============================================"

    # 设置 root 密码
    echo "root:${ROOT_PASSWD:-123456}" | chpasswd

    # ── 出厂配置快照（KEEP_ORIGINAL_CONF）──────────────────
    # 必须放在下面 auto_recover.sh 之前执行：一旦恢复流程跑完，
    # /root/.hermes 就已经是"上次同步的状态"而不是镜像原生状态了。
    # 只在 /mnt/workspace 里第一次出现这个标记文件时执行一次，
    # 之后每次重启都不再覆盖，保证 hermes_origin 里永远是
    # 镜像刚构建出来、还没被任何恢复/同步动过的原始版本，
    # 可以用来跟当前配置 diff，或者出问题时一键切回。
    # ⚠ 没有确认过 /root/.hermes 除了 venv 之外是否还存了 hermes
    # 自己的配置文件，如果 hermes 的配置其实存在别的路径（比如
    # ~/.config/hermes），这里的源路径要相应改一下，命令本身照抄即可。
    if [ "${KEEP_ORIGINAL_CONF:-1}" = "1" ] && [ -d /mnt/workspace ] && [ ! -e /mnt/workspace/.hermes_origin_saved ]; then
        echo "[*] 首次启动，保存镜像自带的原版 Hermes 配置到 /mnt/workspace/hermes_origin..."
        mkdir -p /mnt/workspace/hermes_origin
        for f in config.yaml channel_directory.json SOUL.md; do
            [ -e "/root/.hermes/$f" ] && cp "/root/.hermes/$f" /mnt/workspace/hermes_origin/ 2>/dev/null
        done
        touch /mnt/workspace/.hermes_origin_saved
    fi

    # ── 恢复历史配置 + 用户自定义启动脚本 ──────────────────
    if [ "$SKIP_RESTORE" = "1" ]; then
        echo "[*] SKIP_RESTORE=1，跳过恢复和自定义脚本"
    else
        echo "[*] 开始恢复 Hermes 历史配置..."
        /ldp/auto_recover.sh
    fi

    # ── 启动 Hermes ──────────────────────────────────────────
    export MODELSCOPE_API_KEY="${MODELSCOPE_API_KEY:-not_set_yet}"

    echo "[*] 启动 Hermes dashboard..."
    nohup /root/.local/bin/hermes dashboard >/tmp/hermes-dashboard.log 2>&1 &

    echo "[*] 启动 Hermes gateway..."
    nohup /root/.local/bin/hermes gateway >/tmp/hermes-gateway.log 2>&1 &

    # 等待 Dashboard 端口 9119 就绪（最多 60s）
    echo "[*] 等待 Hermes Dashboard 就绪（端口 9119）..."
    elapsed=0
    while ! ss -tlnp 2>/dev/null | grep -q ':9119' && \
          ! netstat -tlnp 2>/dev/null | grep -q ':9119'; do
        sleep 0.5
        (( elapsed++ ))
        if (( elapsed >= 120 )); then
            echo "[!] Timeout: Hermes Dashboard 未在 60s 内就绪" >&2
            echo "    日志：" >&2
            tail -20 /tmp/hermes-dashboard.log >&2
            break
        fi
    done
    echo "[✓] Hermes Dashboard 就绪"

    # 清理 Chrome 单例锁（防止重启后 Chrome 拒绝启动）
    rm -f /root/.config/google-chrome/Singleton* 2>/dev/null

    # ── 启动 Chrome（打开控制面板 + 帮助文档）───────────────
    echo "[*] 启动 Chrome..."
    google-chrome-stable \
        --no-sandbox \
        --disable-dev-shm-usage \
        --enable-unsafe-swiftshader \
        --ignore-gpu-blocklist \
        --no-first-run \
        --disable-default-apps \
        --no-default-browser-check \
        --window-size=1400,860 \
        --window-position=100,80 \
        http://127.0.0.1:9119 \
        "file:///root/Desktop/%E4%BD%BF%E7%94%A8%E5%B8%AE%E5%8A%A9.html" \
        > /dev/null 2>&1 &

    # ── 在 xfce4-terminal 里启动 Hermes 交互模式 ───────────
    echo "[*] 启动 Hermes 交互终端..."
    xfce4-terminal --geometry=180x45 \
        -T "Hermes Agent" \
        --window-position=50,50 \
        -e /root/.local/bin/hermes \
        >/dev/null 2>&1 &

    # 等待窗口出现，然后置顶 30s 再恢复
    sleep 10
    wmctrl -r "Hermes Agent" -b add,above 2>/dev/null || true
    sleep 30
    wmctrl -r "Hermes Agent" -b remove,above 2>/dev/null || true
    wmctrl -a "Hermes Agent" 2>/dev/null || true

    echo "[✓] 所有服务已启动，容器运行中..."
    tail -f /dev/null
}

main() {
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export OPENCLAW_DISABLE_BONJOUR="${OPENCLAW_DISABLE_BONJOUR:-1}"
    export UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
    start_services
}

main "$@"
