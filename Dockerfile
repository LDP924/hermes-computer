# ─────────────────────────────────────────────────────────────
#  hermes_computer — Xfce4 + VNC + Hermes (LDP自构建版)
#  Base: nikolaik/python-nodejs (python3最新 + nodejs最新)
#  所有组件均使用最新版，不锁定版本
# ─────────────────────────────────────────────────────────────
FROM nikolaik/python-nodejs:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    DISPLAY=:1 \
    PYTHONUNBUFFERED=1

# ── 1. 系统基础 + 时区 + 语言 ────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg \
    locales tzdata sudo \
    xz-utils bzip2 unzip zip \
    git procps \
    net-tools iproute2 netcat-openbsd \
    wmctrl \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && sed -i 's/# zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen \
    && locale-gen zh_CN.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Xfce4（最新可用版）───────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    xfce4-taskmanager \
    xfce4-genmon-plugin \
    xfce4-netload-plugin \
    mousepad \
    dbus-x11 \
    xdotool \
    && rm -rf /var/lib/apt/lists/*

# ── 3. TigerVNC + noVNC（最新）──────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# ── 4. Fcitx5 中文输入法（最新）────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    fcitx5 \
    fcitx5-chinese-addons \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    fcitx5-frontend-qt5 \
    fcitx5-module-cloudpinyin \
    fcitx5-config-qt \
    && rm -rf /var/lib/apt/lists/*

# ── 5. Google Chrome（最新稳定版）───────────────────────────
RUN wget -q -O /tmp/chrome.deb \
    "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# Chrome 首次启动跳过欢迎页、禁用更新提示
RUN mkdir -p /etc/opt/chrome/policies/managed && \
    cat > /etc/opt/chrome/policies/managed/policy.json << 'EOF'
{
    "DefaultBrowserSettingEnabled": false,
    "ChromeVariations": 1,
    "MetricsReportingEnabled": false,
    "BackgroundModeEnabled": false,
    "ShowHomeButton": false,
    "HomepageIsNewTabPage": false,
    "RestoreOnStartup": 4,
    "RestoreOnStartupURLs": ["http://127.0.0.1:9119"]
}
EOF

# ── 6. 持久化工具：rclone + inotify-tools ───────────────────
RUN curl -fsSL https://rclone.org/install.sh | bash \
    && apt-get update && apt-get install -y --no-install-recommends \
    inotify-tools \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# ── 7. 字体（中文显示）──────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# ── 8. Hermes Agent（最新版，每次构建重新clone）────────────
RUN mkdir -p /root/.hermes \
    && git clone --depth 1 https://github.com/NousResearch/hermes-agent.git \
       /root/.hermes/hermes-agent \
    && cd /root/.hermes/hermes-agent \
    && python3 -m venv venv \
    && venv/bin/pip install --no-cache-dir --upgrade pip \
    && venv/bin/pip install --no-cache-dir -e ".[all]" \
    && npm install --no-audit --prefer-offline \
    && mkdir -p /root/.local/bin \
    && ln -sf /root/.hermes/hermes-agent/venv/bin/hermes /root/.local/bin/hermes

# ── 9. Xfce4 配置：关闭合成器特效，设置默认壁纸 ───────────
RUN mkdir -p /root/.config/xfce4 &&     mkdir -p /root/.config/xfwm4 &&     cat > /root/.config/xfwm4/xfwm4rc << 'EOF'
use_compositing=false
EOF

# ── 10. VNC xstartup（精确复刻原版）────────────────────────
RUN mkdir -p /root/.vnc
COPY vnc/xstartup /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup

# ── 11. 桌面帮助文件 ────────────────────────────────────────
RUN mkdir -p /root/Desktop && cat > "/root/Desktop/使用帮助.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>Hermes Agent 使用帮助</title>
<style>
  body { font-family: "Noto Sans CJK SC", sans-serif; padding: 20px; background: #1e1e2e; color: #cdd6f4; }
  h2 { color: #89b4fa; }
  a { color: #89dceb; }
  code { background: #313244; padding: 2px 6px; border-radius: 4px; }
</style>
</head>
<body>
<h2>🪽 Hermes Agent 使用帮助</h2>
<p><strong>控制面板：</strong><a href="http://127.0.0.1:9119" target="_blank">http://127.0.0.1:9119</a></p>
<p><strong>输入法切换：</strong><code>Ctrl + Shift</code></p>
<p><strong>VNC分辨率：</strong>1920x1080</p>
<p><strong>时区：</strong>Asia/Shanghai (UTC+8)</p>
<hr>
<p>Hermes Agent 已在左侧终端中运行，可直接输入指令与 AI 对话。</p>
</body>
</html>
EOF

# ── 12. 复制脚本 ─────────────────────────────────────────────
COPY ldp/ /ldp/
COPY ldp-startup/ /root/ldp-startup/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chmod +x /ldp/*.sh \
    && chmod +x /root/ldp-startup/main.sh 2>/dev/null || true

# PATH 设置
ENV PATH="/root/.local/bin:/usr/local/node/bin:/root/.hermes/hermes-agent/venv/bin:$PATH"

EXPOSE 7860

ENTRYPOINT ["/entrypoint.sh"]
