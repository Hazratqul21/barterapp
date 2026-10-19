# MAB'ni serverga chiqarish

Hammasi noutbukdan, bitta skript bilan bajariladi: `deploy/deploy.sh`.

```
mab.uz        → sayt (Flutter web)      /var/www/mab
api.mab.uz    → API (FastAPI, uvicorn)  /opt/mab/api  → 127.0.0.1:8010
              → admin panel             https://api.mab.uz/admin
              → Payme endpoint          https://api.mab.uz/payments/payme
PostgreSQL    → baza "mab", faqat lokal
```

## 0. DNS (domen panelida)

| Yozuv | Nom | Qiymat |
|---|---|---|
| A | `mab.uz` | server IP |
| A | `www.mab.uz` | server IP |
| A | `api.mab.uz` | server IP |

DNS tarqalishi bir necha daqiqadan bir necha soatgacha oladi. Tekshirish: `dig +short api.mab.uz`.

## 1. Server manzili va SSH kalit (bir marta)

```sh
cd ~/barter-platform
echo 'LOGIN@SERVER_IP' > deploy/.server     # git'ga tushmaydi
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C "mab-deploy"
ssh-copy-id "$(cat deploy/.server)"          # parol oxirgi marta so'raladi
ssh "$(cat deploy/.server)" 'sudo -v && echo ok'
```

Kalit ishlagach, parol bilan kirishni o'chirish tavsiya etiladi (serverda `/etc/ssh/sshd_config` → `PasswordAuthentication no`, keyin `sudo systemctl reload ssh`). Buni faqat kalit bilan kirish ishlayotganini tekshirgandan keyin qiling.

## 2. Birinchi o'rnatish

```sh
cd ~/barter-platform
git checkout develop && git pull
EMAIL=siz@mab.uz bash deploy/deploy.sh --setup
```

Skript serverga quyidagilarni o'rnatadi:
- PostgreSQL, Python 3.11+, nginx, certbot va firewall;
- `mab` foydalanuvchisi va `mab` bazasi (parol tasodifiy, `/opt/mab/.db_password`);
- `/opt/mab/api/.env` fayli — `JWT_SECRET` tasodifiy, `APP_ENV=production`;
- systemd: API, har daqiqalik push va kunlik tozalash;
- HTTPS sertifikat (DNS tayyor bo'lsa).

Keyin backend va saytni yuklaydi.

**Muhim.** Production rejimida SMS (Eskiz) sozlanmaguncha API ishga tushmaydi. Sababi oddiy: SMS bo'lmasa hech kim kira olmaydi. Serverda Eskiz ma'lumotini kiriting:

```sh
ssh "$(cat deploy/.server)"
sudo nano /opt/mab/api/.env        # ESKIZ_EMAIL, ESKIZ_PASSWORD
sudo systemctl restart mab-api
curl -s http://127.0.0.1:8010/health
```

## 3. Keyingi yangilanishlar

```sh
git checkout develop && git pull
bash deploy/deploy.sh            # API + sayt
bash deploy/deploy.sh --api      # faqat backend
bash deploy/deploy.sh --web      # faqat sayt
```

Migratsiyalar (`alembic upgrade head`) har deployda avtomatik bajariladi.

## Tekshirish va muammolar

```sh
ssh "$(cat deploy/.server)"
sudo systemctl status mab-api
sudo journalctl -u mab-api -n 100 --no-pager      # API loglari
sudo tail -n 50 /var/log/nginx/error.log
```

- **API ishga tushmasa:** loglarda `APP_ENV=production, lekin sozlamalar xavfsiz emas` degan yozuv bo'lsa, ro'yxatdagi har bir bandni `.env` da tuzating.
- **Sertifikat olinmagan bo'lsa:** DNS tayyor bo'lgach `sudo certbot --nginx -d mab.uz -d www.mab.uz -d api.mab.uz --redirect -m <email> --agree-tos -n`.
- **Moderator (admin) huquqi:** `sudo -u mab bash -c 'cd /opt/mab/api && set -a && . ./.env && set +a && .venv/bin/python -m app.grant_moderator +998XXXXXXXXX'`.

## Zaxira nusxa (tavsiya)

```sh
sudo -u postgres pg_dump mab | gzip > mab-$(date +%F).sql.gz
```

Ilova ID'si (`uz.mab.app`) va domenlar haqida: `README.md` → "Domen va identifikatorlar".
