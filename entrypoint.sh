#!/bin/bash
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/root-runtime
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
export PATH="/root/.local/bin:/usr/local/node/bin:$PATH"
export MODELSCOPE_API_KEY="${MODELSCOPE_API_KEY:-}"

rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

mkdir -p /root/.vnc
printf "${VNC_PW:-mscope01}" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

vncserver :1 \
  -geometry 1920x1080 \
  -depth 24 \
  -SecurityTypes VncAuth \
  -localhost no \
  -fg &

for i in $(seq 1 30); do
  if ss -tlnp 2>/dev/null | grep -q ':5901'; then break; fi
  sleep 1
done

websockify \
  --web /usr/share/novnc \
  --heartbeat 30 \
  0.0.0.0:7860 \
  localhost:5901 &

if [ "$SKIP_RESTORE" != "1" ] && [ -f /bz/auto_recover.sh ]; then
  /bz/auto_recover.sh
fi

nohup /root/.local/bin/hermes dashboard >/tmp/hermes-dashboard.log 2>&1 &
nohup /root/.local/bin/hermes gateway >/tmp/hermes-gateway.log 2>&1 &

for i in $(seq 1 120); do
  if (echo > /dev/tcp/127.0.0.1/9119) 2>/dev/null; then break; fi
  sleep 0.5
done

rm -f /root/.config/google-chrome/Singleton* 2>/dev/null

start-chrome "http://127.0.0.1:9119" >/dev/null 2>&1 &

xfce4-terminal --title="Hermes Agent" -e /root/.local/bin/hermes >/dev/null 2>&1 &

sleep 10
wmctrl -r "Hermes" -b add,above 2>/dev/null
sleep 30
wmctrl -r "Hermes" -b remove,above 2>/dev/null
wmctrl -a "Hermes" 2>/dev/null

tail -f /dev/null
