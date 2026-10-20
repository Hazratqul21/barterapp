#!/usr/bin/env bash
# Telefonda sinash uchun APK: kompyuterdagi API'ga ulanadi va Desktop'ga
# MAB.apk bo'lib tushadi. Istalgan papkadan ishga tushirsa bo'ladi:
#
#   bash app/scripts/build_apk.sh            # IP avtomatik
#   bash app/scripts/build_apk.sh 192.168.1.5 # IP qo'lda
#
# Har qadam tekshiriladi; xato bo'lsa nima qilish kerakligi yoziladi va
# eski APK Desktop'ga ko'chirilmaydi.
set -uo pipefail

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR" || { red "app papkasi topilmadi: $APP_DIR"; exit 1; }

step "Flutter"
if ! command -v flutter >/dev/null 2>&1; then
  red "flutter topilmadi. Terminalni qayta oching yoki PATH'ga Flutter'ni qo'shing."
  exit 1
fi
flutter --version | head -1

step "Kompyuter IP manzili"
IP="${1:-}"
if [ -z "$IP" ]; then
  # Avval internetga chiqayotgan interfeys, keyin odatiy en0…en3.
  DEF="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
  for iface in $DEF en0 en1 en2 en3 en4 en5; do
    IP="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    [ -n "$IP" ] && break
  done
fi
if [ -z "$IP" ]; then
  # Oxirgi chora: istalgan uy/ofis tarmog'i manzili (192.168.*, 10.*, 172.16–31.*).
  IP="$(ifconfig 2>/dev/null | awk '/inet /{print $2}' \
    | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | head -1)"
fi
if [ -z "$IP" ]; then
  red "IP topilmadi. Wi‑Fi yoqilganini tekshiring yoki IP'ni qo'lda bering"
  red "(System Settings → Wi‑Fi → Details → IP address):"
  red "  bash app/scripts/build_apk.sh 192.168.x.x"
  exit 1
fi
API="http://$IP:8010"
echo "API: $API"

step "Backend tekshiruvi"
if curl -s --max-time 4 "$API/health" | grep -q '"ok"'; then
  green "Backend $API da ishlayapti."
else
  red "Diqqat: $API/health javob bermadi. APK quriladi, lekin telefonda"
  red "ma'lumot chiqishi uchun backend shunday ishga tushirilgan bo'lishi kerak:"
  red "  cd api && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8010"
fi

step "Paketlar va tarjimalar"
flutter pub get || { red "flutter pub get xato berdi (yuqoridagi xabarga qarang)."; exit 1; }
flutter gen-l10n || { red "flutter gen-l10n xato berdi."; exit 1; }

step "APK qurish (birinchi marta 5–10 daqiqa)"
OUT="build/app/outputs/flutter-apk/app-profile.apk"
rm -f "$OUT"
# Google orqali kirish: deploy/google_client_id dagi Web client ID (bo'lsa).
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID:-$(cat "$APP_DIR/../deploy/google_client_id" 2>/dev/null || true)}
if ! flutter build apk --profile --dart-define=API_BASE_URL="$API" \
     --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"; then
  red "APK qurilmadi. Odatiy sabablar:"
  red "  • Android SDK/litsenziya:  flutter doctor --android-licenses"
  red "  • Java versiyasi:          flutter doctor -v  (JDK 17 kerak)"
  red "  • Gradle keshi buzilgan:   cd android && ./gradlew --stop; cd ..; flutter clean"
  red "Yuqoridagi oxirgi 30 qatorni yuboring — aniq tuzatib beraman."
  exit 1
fi
[ -f "$OUT" ] || { red "Build tugadi, lekin $OUT topilmadi."; exit 1; }

step "Desktop'ga ko'chirish"
DEST="$HOME/Desktop/MAB.apk"
cp -f "$OUT" "$DEST" || { red "Ko'chirib bo'lmadi: $DEST (ruxsat yoki joy yo'q)."; exit 1; }
green "Tayyor: $DEST ($(du -h "$DEST" | cut -f1))"
echo "Telefon shu Wi‑Fi'da bo'lsin. Telefon brauzerida $API/health ochilsa — ilova ham ulanadi."
