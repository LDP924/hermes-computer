FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Singapore
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8
ENV DISPLAY=:1
ENV HOME=/root

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg ca-certificates curl \
    tzdata locales \
    dbus dbus-x11 \
    xdotool iproute2 wmctrl \
    python3-venv python3-pip \
    procps xdg-utils \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/share/zoneinfo/Asia/Singapore /etc/localtime && \
    echo "Asia/Singapore" > /etc/timezone

RUN sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

RUN apt-get update && apt-get install -y --no-install-recommends \
    xfwm4 xfce4-panel xfce4-session xfce4-settings \
    xfdesktop4 xfce4-terminal thunar \
    tigervnc-standalone-server tigervnc-common tigervnc-tools \
    novnc python3-websockify \
    fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 \
    fonts-noto-cjk fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O /tmp/chrome.deb \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/chrome.deb && \
    rm -f /tmp/chrome.deb && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/opt/chrome/policies/managed && \
    echo '{"CommandLineFlagSecurityWarningsEnabled":false}' \
    > /etc/opt/chrome/policies/managed/policy.json

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

ARG HERMES_PKG=hermes-agent
RUN python3 -m venv /root/.hermes/hermes-agent/venv && \
    /root/.hermes/hermes-agent/venv/bin/pip install --upgrade pip && \
    /root/.hermes/hermes-agent/venv/bin/pip install "$HERMES_PKG" && \
    ln -sf /root/.hermes/hermes-agent/venv/bin/hermes /root/.local/bin/hermes

COPY start-chrome.sh /usr/local/bin/start-chrome
RUN chmod +x /usr/local/bin/start-chrome

RUN mkdir -p /root/.vnc && \
    printf 'geometry=1920x1080\ndepth=24\n' > /root/.vnc/config

COPY vnc/xstartup /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup

RUN mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<channel name="xfwm4" version="1.0">\n  <property name="general" type="empty">\n    <property name="use_compositing" type="bool" value="false"/>\n  </property>\n</channel>\n' \
    > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7860

CMD ["/entrypoint.sh"]
