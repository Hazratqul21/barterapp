#!/usr/bin/env bash
# MAB'ni noutbukdan serverga chiqarish.
#
#   bash deploy/deploy.sh --setup     # birinchi marta: serverni tayyorlaydi + kod
#   bash deploy/deploy.sh             # keyingi har safar: API + web yangilanadi
#   bash deploy/deploy.sh --api       # faqat backend
#   bash deploy/deploy.sh --web       # faqat sayt
#
# Server manzili deploy/.server faylida (git'ga tushmaydi), bitta qator:
#   echo 'foydalanuvchi@ip' > deploy/.server
# yoki har safar: SERVER=foydalanuvchi@ip bash deploy/deploy.sh
# Parol so'ralmasligi uchun avval bir marta: ssh-copy-id "$SERVER"
set -euo pipefail

ROOT_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER=${SERVER:-$(cat "$ROOT_EARLY/deploy/.server" 2>/dev/null || true)}
if [ -z "$SERVER" ]; then
  echo "Server manzili yo'q. Bir marta yozing:  echo 'foydalanuvchi@ip' > deploy/.server"
  exit 1
fi
API_URL=${API_URL:-https://api.mab.uz}
EMAIL=${EMAIL:-}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }

DO_SETUP=0; DO_API=1; DO_WEB=1
case "${1:-}" in
  --setup) DO_SETUP=1 ;;
  --api) DO_WEB=0 ;;
  --web) DO_API=0 ;;
  "") ;;
  *) red "Noma'lum parametr: $1"; exit 1 ;;
esac

step "Server bilan aloqa: $SERVER"
ssh -o ConnectTimeout=10 "$SERVER" true \
  || { red "SSH ulanmadi. Tekshiring: ssh $SERVER"; exit 1; }

# Har deploy uchun yangi, faqat shu foydalanuvchiga ochiq papka (mktemp -d,
# 700). Ilgari doimiy /tmp/mab-* nomlari ishlatilardi: serverdagi boshqa
# foydalanuvchi o'sha nom bilan papka ochib qo'ysa, root uning fayllarini
# o'rnatib yuborardi.
STAGE=$(ssh "$SERVER" 'mktemp -d /tmp/mab-deploy.XXXXXXXX')

if [ "$DO_SETUP" = 1 ]; then
  step "Serverni tayyorlash (bir marta)"
  # scp, not rsync: a fresh server may not have rsync until this step runs.
  scp -q -r "$ROOT/deploy" "$SERVER:$STAGE/setup"
  ssh -t "$SERVER" "sudo EMAIL='$EMAIL' bash '$STAGE/setup/setup_server.sh'"
fi

if [ "$DO_WEB" = 1 ]; then
  step "Sayt (Flutter web) qurilmoqda"
  command -v flutter >/dev/null || { red "flutter topilmadi."; exit 1; }
  (cd "$ROOT/app" && flutter pub get >/dev/null && flutter gen-l10n >/dev/null \
    && flutter build web --release --no-web-resources-cdn \
         --dart-define=API_BASE_URL="$API_URL")
  # flutter build bu faylni o'zgartiradi; repoda o'zgarish qolmasin.
  (cd "$ROOT" && git checkout -q -- app/analysis_options.yaml 2>/dev/null || true)
  rsync -az --delete "$ROOT/app/build/web/" "$SERVER:$STAGE/web/"
fi

if [ "$DO_API" = 1 ]; then
  step "Backend fayllari yuborilmoqda"
  rsync -az --delete \
    --exclude '.venv' --exclude '.env*' --exclude 'media' --exclude '__pycache__' \
    --exclude 'tests' --exclude '*.pyc' \
    "$ROOT/api/" "$SERVER:$STAGE/api/"
fi

step "Serverda o'rnatish"
# Skript avval faylga yuboriladi, keyin `ssh -t` bilan ishga tushadi: sudo
# parol so'rashi uchun terminal kerak, stdin orqali yuborilgan skriptda u yo'q.
rsync -az "$ROOT/deploy/remote_install.sh" "$ROOT/deploy/backup.sh" \
  "$ROOT/deploy/nginx" "$ROOT/deploy/systemd" "$SERVER:$STAGE/"
ssh -t "$SERVER" "sudo STAGE='$STAGE' DO_API=$DO_API DO_WEB=$DO_WEB bash '$STAGE/remote_install.sh'"

green "Tayyor."
if [ "$DO_WEB" = 1 ]; then echo "  Sayt:  https://mab.uz"; fi
echo "  Hujjatlar: https://mab.uz/privacy  https://mab.uz/terms  https://mab.uz/offer"
if [ "$DO_API" = 1 ]; then echo "  API:   $API_URL/health   Admin: $API_URL/admin"; fi
