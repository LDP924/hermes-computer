#!/bin/sh
exec /opt/google/chrome/chrome \
  --no-sandbox \
  --enable-unsafe-swiftshader \
  --disable-dev-shm-usage \
  "$@"
