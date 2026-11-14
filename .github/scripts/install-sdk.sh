#!/usr/bin/env bash
# Ставит iOS SDK в каталог Theos.
#
# Использование:
#   bash .github/scripts/install-sdk.sh "$THEOS/sdks"
#
# Если SDK там уже есть — выходит сразу. Иначе делает sparse-клон theos/sdks
# (репозиторий большой, полный клон в CI занимает много минут и места) и копирует
# самый свежий SDK 15.x, а если такого нет — 16.x.

set -euo pipefail

SDKS_DIR="${1:-${THEOS:-/opt/theos}/sdks}"
mkdir -p "$SDKS_DIR"

if ls "$SDKS_DIR"/*.sdk >/dev/null 2>&1; then
    echo "==> SDK уже установлен:"
    ls "$SDKS_DIR"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> клонирую theos/sdks (sparse, только 15.x/16.x)"
git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/theos/sdks.git "$WORK/sdks" >/dev/null
cd "$WORK/sdks"
git sparse-checkout set --no-cone 'iPhoneOS15.*' 'iPhoneOS16.*' >/dev/null 2>&1 || true

pick="$(ls -d iPhoneOS15.*.sdk 2>/dev/null | sort -V | tail -n 1 || true)"
if [ -z "$pick" ]; then
    pick="$(ls -d iPhoneOS16.*.sdk 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [ -z "$pick" ]; then
    echo "::error::В theos/sdks не нашлось SDK 15.x или 16.x" >&2
    ls
    exit 1
fi

cp -R "$pick" "$SDKS_DIR/"
echo "==> установлен: $pick"
