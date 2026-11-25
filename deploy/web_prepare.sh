#!/usr/bin/env bash
# Flutter web build'ini tez yuklanadigan qiladi (deploy.sh chaqiradi).
#
#   bash deploy/web_prepare.sh app/build/web
#
# 1. main.dart.js va canvaskit/ nomiga mazmun heshi qo'shiladi: brauzer ularni
#    bir yil saqlaydi va qayta so'ramaydi; yangi versiyada nom o'zgaradi.
# 2. index.html ga preload: main.dart.js bootstrap'ni kutmay yuklana boshlaydi.
# 3. Har matnli fayl yonida .gz va (brotli bo'lsa) .br nusxa.
#
# Kutilgan satr topilmasa (Flutter formati o'zgargan bo'lsa) nomlar
# o'zgartirilmaydi: sayt sekinroq, lekin ishlaydi.
set -euo pipefail
WEB=${1:?build papkasi berilmadi}
cd "$WEB"

hash8() { cat "$@" | shasum -a 256 | cut -c1-12; }

BOOT=flutter_bootstrap.js
if [ -f main.dart.js ] && [ -f canvaskit/canvaskit.wasm ] \
   && grep -q '"mainJsPath":"main.dart.js"' "$BOOT" \
   && [ "$(grep -c '^_flutter.loader.load({$' "$BOOT")" = 1 ] \
   && ! grep -q 'canvasKitBaseUrl: ' "$BOOT"; then
  main="main.dart.$(hash8 main.dart.js).js"
  kit="canvaskit.$(hash8 canvaskit/*.wasm canvaskit/*.js canvaskit/chromium/*.wasm canvaskit/chromium/*.js)"
  # Avval havolalar, keyin fayllar: yozish yiqilsa build buzilmaydi.
  MAIN="$main" KIT="$kit" perl -pi -e '
    s/"mainJsPath":"main\.dart\.js"/"mainJsPath":"$ENV{MAIN}"/;
    s/^_flutter\.loader\.load\(\{$/_flutter.loader.load({\n  config: { canvasKitBaseUrl: "\/$ENV{KIT}\/" },/;
  ' "$BOOT"
  grep -q "$main" "$BOOT" && grep -q "/$kit/" "$BOOT" || { echo "web_prepare: bootstrap yozilmadi"; exit 1; }
  MAIN="$main" perl -pi -e \
    's/<link rel="manifest"/<link rel="preload" href="$ENV{MAIN}" as="script">\n  <link rel="manifest"/' index.html
  mv main.dart.js "$main"
  mv canvaskit "$kit"
  # Simvol fayllari faqat xatolarni o'qish uchun — saytga kerak emas.
  find "$kit" -name '*.symbols' -delete
  echo "Heshli nomlar: $main, $kit/"
else
  echo "DIQQAT: Flutter build formati boshqacha — heshli nomlar qo'yilmadi."
fi

# nginx gzip_static / brotli_static uchun tayyor nusxalar: har so'rovda siqmaydi.
find . -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' \
     -o -name '*.css' -o -name '*.svg' -o -name '*.ttf' -o -name '*.otf' -o -name '*.html' \) \
     -size +1k -print0 > .compress-list
xargs -0 -n 20 gzip -kf9 < .compress-list
if command -v brotli >/dev/null; then
  xargs -0 -n 20 -P 4 brotli -kf -q 11 < .compress-list
else
  echo "brotli topilmadi (brew install brotli) — faqat gzip."
fi
rm -f .compress-list
