#!/usr/bin/env bash
# Har bir sinov toza bazadan boshlanadi, chunki ular bir-birining
# ma'lumotiga tegadi (savdo yakunlansa e'lonlar lentadan chiqadi).
#
#   cd api && ./tests/run_all.sh
#
# Talab: docker compose up -d, va uvicorn 8010-portda ishlab turishi.
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
fail=0
for t in tests/test_trade_loop.py \
         tests/test_uploads_and_desires.py \
         tests/test_profile_and_regions.py \
         tests/test_create_listing.py \
         tests/test_counter_offer.py \
         tests/test_reviews.py \
         tests/test_otp_security.py \
         tests/test_token_security.py; do
  $PY -m app.seed >/dev/null 2>&1
  printf '%-42s ' "$(basename "$t")"
  if out=$($PY "$t" 2>&1); then
    echo "OK   ($(echo "$out" | grep -c PASS) ta tekshiruv)"
  else
    echo "FAIL"; echo "$out" | tail -5; fail=1
  fi
done
$PY -m app.seed >/dev/null 2>&1
exit $fail
