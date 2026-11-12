#!/bin/sh
# Vite geliştirme sunucusunu bir Bagisto paketinin klasöründe başlatır
# (compose.yaml'daki vite servisi, working_dir ile paketi seçer).
set -e

if [ ! -f package.json ]; then
    echo "Bu klasörde package.json yok: $(pwd)" >&2
    exit 1
fi

npm install --no-audit --no-fund

node /usr/local/lib/bagisto-egitimi/vite-proxy.mjs &

# exec: Vite PID 1'in (init) doğrudan çocuğu olur ve SIGTERM'i alır; laravel-vite-plugin
# kapanırken public/*-vite.hot dosyasını siler.
exec ./node_modules/.bin/vite
