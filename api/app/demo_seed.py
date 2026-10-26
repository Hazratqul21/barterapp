"""Demo ma'lumotlar: lenta, profillar va sharhlar jonli ko'rinsin.

`app.seed` dan farqi: bu skript bazani TOZALAMAYDI. U faqat o'zining demo
hisoblarini (telefon raqamlari `DEMO_PHONES` da) yaratadi, qayta ishga
tushirilsa ularni yangidan quradi, `--remove` bilan esa izsiz olib tashlaydi.
Haqiqiy foydalanuvchilar, ularning e'lonlari va savdolariga tegilmaydi.

Rasmlar Unsplash'dan bir marta yuklab olinib `media/demo/` ga saqlanadi va
API domenidan beriladi: veb-ilova boshqa domendagi rasmni yuklay olmaydi
(CSP), tashqi havola esa vaqt o'tib o'lishi mumkin.

    .venv/bin/python -m app.demo_seed            # qo'shish / yangilash
    .venv/bin/python -m app.demo_seed --remove   # hammasini olib tashlash
    .venv/bin/python -m app.demo_seed --no-photos  # rasmlarsiz (sinov)
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy import delete, select

from app.api.uploads import _process
from app.core.config import settings
from app.core.regions import coordinates_for
from app.db.session import SessionLocal
from app.models.desire import Desire
from app.models.listing import (
    Listing,
    ListingPhoto,
    ListingStatus,
    ListingTag as Tag,
    ListingTranslation,
    ListingWant,
    ListingWantTranslation,
)
from app.models.offer import Offer, OfferStatus
from app.models.review import Review
from app.models.user import User, UserType

NOW = datetime.now(UTC)
FOLDER = "demo"

#: Demo hisoblar faqat shu raqamlar bilan aniqlanadi. 77-kod — hech kimga
#: tegishli bo'lmagan ketma-ket raqamlar; SMS kodi baribir kelmaydi.
DEMO_PHONES = [f"+99877000{n:04d}" for n in range(101, 113)]

_U = "https://images.unsplash.com/"
PHOTOS = {
    "field": "photo-1560493676-04071c5f467b",
    "rice": "photo-1620844128640-fcd892760d53",
    "crops": "photo-1776582929662-4c33d0e7190b",
    "sheep": "photo-1516467508483-a7212febe31a",
    "cattle": "photo-1641062680671-fec389e4eeeb",
    "tractor": "photo-1602446692855-6d096499f69b",
    "tractor2": "photo-1606739211185-2c846d734a6d",
    "machine": "photo-1504307651254-35680f356dfd",
    "truck": "photo-1601584115197-04ecc0da31d7",
    "truck2": "photo-1729150781588-2405d7567d87",
    "circuit": "photo-1518770660439-4636190af475",
    "laptop": "photo-1511385348-a52b4a160dc2",
    "phone": "photo-1616410011236-7a42121dd981",
    "bricks": "photo-1518709268805-4e9042af9f23",
    "timber": "photo-1634672652995-ee7525bce595",
    "av1": "photo-1507003211169-0a1dd7228f2d",
    "av2": "photo-1500648767791-00dcc994a43e",
    "av3": "photo-1705645930353-0e335311ef20",
    "av4": "photo-1560250097-0b93528c311a",
    "av5": "photo-1519085360753-af0119f7cbe7",
}


def t(uz: str, ru: str, en: str) -> dict[str, str]:
    return {"uz": uz, "ru": ru, "en": en}


# key, ism, familiya, do'kon/brend, viloyat, tuman, bio, ishonch, tasdiqlangan, turi, avatar
PEOPLE = [
    ("aziz", "Aziz", "Karimov", "Karimov Agro", "Qashqadaryo", "Qarshi",
     "Bug‘doy va paxta yetishtiramiz. Texnikaga almashuvga doim ochiqmiz.", 94, True, "business", "av4"),
    ("malika", "Malika", "Yusupova", None, "Toshkent shahri", "Yunusobod",
     "Elektronika va maishiy texnika. Faqat yaxshi holatdagi buyumlar.", 88, True, "individual", "av3"),
    ("sherzod", "Sherzod", "Rahimov", "Rahimov Fermer", "Jizzax", "Zomin",
     "Qo‘y va qoramol boqamiz. Yem va texnikaga almashamiz.", 91, True, "business", "av2"),
    ("dilshod", "Dilshod", "Ergashev", "Ergashev Qurilish", "Samarqand", "Urgut",
     "Qurilish mollari ulgurji. Sement, g‘isht, armatura.", 86, True, "business", "av5"),
    ("nodira", "Nodira", "Saidova", None, "Farg‘ona", "Marg‘ilon",
     "Kichik ferma, sut mahsulotlari. Halol savdo.", 79, False, "individual", None),
    ("bobur", "Bobur", "Tursunov", "Tursunov Trans", "Andijon", "Asaka",
     "Yuk tashish va avtomobillar. Damas, Labo, Isuzu.", 90, True, "business", "av1"),
    ("javlon", "Javlon", "Mirzayev", None, "Buxoro", "G‘ijduvon",
     "Dehqonchilik texnikasi ta’miri va ehtiyot qismlar.", 83, True, "individual", None),
    ("gulnora", "Gulnora", "Abdullayeva", "Gulnora Market", "Namangan", "Chust",
     "Quruq meva, don va dukkaklilar.", 87, True, "business", None),
    ("rustam", "Rustam", "Xolmatov", None, "Navoiy", "Karmana",
     "Avtomobil va qishloq texnikasi. Kelishamiz.", 76, False, "individual", None),
    ("sevara", "Sevara", "Qodirova", None, "Toshkent viloyati", "Chirchiq",
     "Noutbuk va telefonlar, kafolat bilan.", 84, True, "individual", None),
]

# key, egasi, kategoriya, qiymat (so'm), premium, necha kun oldin, rasmlar,
# sarlavha, tavsif, holat, miqdor, evaziga, istaklar [(kategoriya, past, yuqori, pul qo'shadi)]
LISTINGS = [
    ("wheat", "aziz", Tag.agri, 95_000_000, True, 1, ["field", "crops"],
     t("Bug‘doy, 30 tonna (2026 hosili)", "Пшеница, 30 тонн (урожай 2026)", "Wheat, 30 tons (2026 harvest)"),
     t("Toza, quritilgan, omborda saqlangan. Laboratoriya xulosasi bor. Yuklab berish bizdan.",
       "Чистая, сухая, хранится на складе. Есть лабораторное заключение. Погрузка за наш счёт.",
       "Clean, dried, stored in a warehouse. Lab report available. Loading on us."),
     t("Yangi hosil", "Новый урожай", "New harvest"), t("30 tonna", "30 тонн", "30 tons"),
     [t("Traktor yoki seyalka", "Трактор или сеялка", "Tractor or seeder"), t("Mineral o‘g‘it", "Минеральные удобрения", "Fertiliser")],
     [(Tag.machinery, 0.5, 1.6, True)]),
    ("rice", "gulnora", Tag.agri, 42_000_000, False, 3, ["rice", "field"],
     t("Guruch «Lazer», 10 tonna", "Рис «Лазер», 10 тонн", "Lazer rice, 10 tons"),
     t("Chust guruchi, saralangan. Qoplarda 50 kg dan.", "Чустский рис, отборный. В мешках по 50 кг.", "Chust rice, graded. 50 kg sacks."),
     t("Saralangan", "Отборный", "Graded"), t("10 tonna", "10 тонн", "10 tons"),
     [t("Yuk mashinasi", "Грузовик", "Truck")], [(Tag.transport, 0.5, 2.0, True)]),
    ("cotton_seed", "aziz", Tag.agri, 18_500_000, False, 6, ["crops", "field"],
     t("Chigit, 8 tonna", "Хлопковые семена, 8 тонн", "Cotton seed, 8 tons"),
     t("Ekishga tayyor, dorilangan.", "Готовы к посеву, протравлены.", "Ready to sow, treated."),
     t("Ekishga tayyor", "Готовы к посеву", "Ready to sow"), t("8 tonna", "8 тонн", "8 tons"),
     [t("Chorva yemi", "Корм для скота", "Livestock feed")], [(Tag.livestock, 0.4, 1.5, False)]),
    ("apricot", "gulnora", Tag.agri, 26_000_000, True, 2, ["crops"],
     t("Quritilgan o‘rik, 2 tonna", "Курага, 2 тонны", "Dried apricots, 2 tons"),
     t("Eksport sifatida, qutilarda.", "Экспортного качества, в коробках.", "Export grade, boxed."),
     t("Eksport sifati", "Экспортное качество", "Export grade"), t("2 tonna", "2 тонны", "2 tons"),
     [t("Elektronika", "Электроника", "Electronics")], [(Tag.electronics, 0.5, 1.5, True)]),

    ("sheep", "sherzod", Tag.livestock, 64_000_000, True, 1, ["sheep"],
     t("Hisori qo‘y, 40 bosh", "Гиссарские овцы, 40 голов", "Hisori sheep, 40 head"),
     t("Sog‘lom, emlangan, vet pasporti bor. Zominga kelib ko‘rishingiz mumkin.",
       "Здоровые, вакцинированы, есть ветпаспорт. Можно приехать в Зомин.",
       "Healthy, vaccinated, with vet passports. Visit us in Zomin."),
     t("Sog‘lom", "Здоровые", "Healthy"), t("40 bosh", "40 голов", "40 head"),
     [t("Traktor", "Трактор", "Tractor"), t("Yem", "Корм", "Feed")], [(Tag.machinery, 0.5, 1.4, True), (Tag.agri, 0.5, 1.2, False)]),
    ("cattle", "nodira", Tag.livestock, 120_000_000, False, 4, ["cattle"],
     t("Golshteyn sigir, 6 bosh", "Голштинские коровы, 6 голов", "Holstein cows, 6 head"),
     t("Sut beradigan, kuniga 20 litrgacha.", "Дойные, до 20 литров в день.", "Milking, up to 20 litres a day."),
     t("Sut beradi", "Дойные", "Milking"), t("6 bosh", "6 голов", "6 head"),
     [t("Yuk mashinasi", "Грузовик", "Truck")], [(Tag.transport, 0.5, 1.5, True)]),
    ("calves", "sherzod", Tag.livestock, 38_000_000, False, 5, ["cattle", "sheep"],
     t("Buzoqlar, 8 bosh (6 oylik)", "Телята, 8 голов (6 месяцев)", "Calves, 8 head (6 months)"),
     t("Semirtirishga tayyor.", "Готовы к откорму.", "Ready for fattening."),
     t("Sog‘lom", "Здоровые", "Healthy"), t("8 bosh", "8 голов", "8 head"),
     [t("Don", "Зерно", "Grain")], [(Tag.agri, 0.6, 1.4, False)]),
    ("goats", "nodira", Tag.livestock, 22_000_000, False, 9, ["sheep"],
     t("Echki, 15 bosh", "Козы, 15 голов", "Goats, 15 head"),
     t("Sut zotli echkilar.", "Молочные козы.", "Dairy goats."),
     t("Sog‘lom", "Здоровые", "Healthy"), t("15 bosh", "15 голов", "15 head"),
     [t("Telefon yoki noutbuk", "Телефон или ноутбук", "Phone or laptop")], [(Tag.electronics, 0.5, 1.5, True)]),

    ("mtz", "javlon", Tag.machinery, 145_000_000, True, 1, ["tractor", "tractor2"],
     t("MTZ-82.1 traktor, 2018", "Трактор МТЗ-82.1, 2018", "MTZ-82.1 tractor, 2018"),
     t("3900 moto-soat, yangi shinalar. Plug va boronasi bilan.",
       "3900 моточасов, новые шины. С плугом и бороной.",
       "3,900 engine hours, new tyres. Comes with plough and harrow."),
     t("Yaxshi holatda", "В хорошем состоянии", "Good condition"), t("1 dona", "1 шт.", "1 unit"),
     [t("Qo‘y yoki qoramol", "Овцы или КРС", "Sheep or cattle"), t("Don", "Зерно", "Grain")],
     [(Tag.livestock, 0.4, 1.3, True), (Tag.agri, 0.5, 1.3, True)]),
    ("combine", "aziz", Tag.machinery, 320_000_000, False, 7, ["machine", "tractor"],
     t("Kombayn Claas Mega, 2011", "Комбайн Claas Mega, 2011", "Claas Mega combine, 2011"),
     t("Mavsumga tayyor, ta’mirlangan.", "Готов к сезону, после ремонта.", "Season-ready, freshly serviced."),
     t("Ta’mirlangan", "После ремонта", "Serviced"), t("1 dona", "1 шт.", "1 unit"),
     [t("Yuk mashinasi + pul", "Грузовик + доплата", "Truck + cash")], [(Tag.transport, 0.4, 1.2, False)]),
    ("seeder", "javlon", Tag.machinery, 34_000_000, False, 4, ["tractor2", "field"],
     t("Seyalka SZ-3.6", "Сеялка СЗ-3.6", "SZ-3.6 seed drill"),
     t("Ishlatishga tayyor.", "Готова к работе.", "Ready to work."),
     t("Ishlaydi", "Рабочая", "Working"), t("1 dona", "1 шт.", "1 unit"),
     [t("Bug‘doy", "Пшеница", "Wheat")], [(Tag.agri, 0.6, 1.5, False)]),
    ("pump", "rustam", Tag.machinery, 9_500_000, False, 10, ["machine"],
     t("Suv nasosi, 15 kVt", "Водяной насос, 15 кВт", "Water pump, 15 kW"),
     t("Sug‘orish uchun, kam ishlatilgan.", "Для полива, мало б/у.", "For irrigation, lightly used."),
     t("Kam ishlatilgan", "Мало б/у", "Lightly used"), t("1 dona", "1 шт.", "1 unit"),
     [t("Telefon", "Телефон", "Phone")], [(Tag.electronics, 0.6, 1.6, True)]),

    ("isuzu", "bobur", Tag.transport, 210_000_000, True, 2, ["truck", "truck2"],
     t("Isuzu NPR, 5 tonnalik, 2017", "Isuzu NPR, 5 тонн, 2017", "Isuzu NPR, 5-ton, 2017"),
     t("Furgon, holati a’lo. Hujjatlari joyida.", "Фургон, отличное состояние. Документы в порядке.", "Box van, excellent condition. Papers in order."),
     t("A’lo", "Отличное", "Excellent"), t("1 dona", "1 шт.", "1 unit"),
     [t("Bug‘doy yoki guruch", "Пшеница или рис", "Wheat or rice"), t("Traktor", "Трактор", "Tractor")],
     [(Tag.agri, 0.4, 1.2, True), (Tag.machinery, 0.5, 1.3, True)]),
    ("damas", "bobur", Tag.transport, 68_000_000, False, 3, ["truck2"],
     t("Damas, 2020, gaz-benzin", "Damas, 2020, газ-бензин", "Damas, 2020, gas/petrol"),
     t("Bir egasi, 90 ming km.", "Один владелец, 90 тыс. км.", "One owner, 90k km."),
     t("Yaxshi", "Хорошее", "Good"), t("1 dona", "1 шт.", "1 unit"),
     [t("Qo‘y", "Овцы", "Sheep")], [(Tag.livestock, 0.6, 1.4, False)]),
    ("labo", "rustam", Tag.transport, 59_000_000, False, 8, ["truck"],
     t("Labo, 2019", "Labo, 2019", "Labo, 2019"),
     t("Bortli, qishloq ishiga qulay.", "Бортовой, удобен для хозяйства.", "Flatbed, handy for farm work."),
     t("Yaxshi", "Хорошее", "Good"), t("1 dona", "1 шт.", "1 unit"),
     [t("Qurilish mollari", "Стройматериалы", "Building materials")], [(Tag.construction, 0.6, 1.5, True)]),
    ("trailer", "javlon", Tag.transport, 24_000_000, False, 12, ["truck2", "tractor"],
     t("Traktor tirkamasi 2PTS-4", "Тракторный прицеп 2ПТС-4", "2PTS-4 tractor trailer"),
     t("Ag‘dariladigan, 4 tonna.", "Самосвальный, 4 тонны.", "Tipping, 4 tons."),
     t("Ishlaydi", "Рабочий", "Working"), t("1 dona", "1 шт.", "1 unit"),
     [t("Buzoq", "Телята", "Calves")], [(Tag.livestock, 0.5, 1.6, False)]),

    ("macbook", "sevara", Tag.electronics, 16_500_000, True, 1, ["laptop", "circuit"],
     t("MacBook Air M2, 256 GB", "MacBook Air M2, 256 ГБ", "MacBook Air M2, 256 GB"),
     t("Batareya 96%, qutisi bilan.", "Батарея 96%, с коробкой.", "Battery 96%, boxed."),
     t("A’lo", "Отличное", "Excellent"), t("1 dona", "1 шт.", "1 unit"),
     [t("iPhone + pul", "iPhone + доплата", "iPhone + cash")], [(Tag.electronics, 0.4, 1.2, False)]),
    ("iphone", "malika", Tag.electronics, 11_800_000, False, 2, ["phone"],
     t("iPhone 14 Pro, 128 GB", "iPhone 14 Pro, 128 ГБ", "iPhone 14 Pro, 128 GB"),
     t("Batareya 88%, hech qayeri ochilmagan.", "Батарея 88%, не вскрывался.", "Battery 88%, never opened."),
     t("Yaxshi", "Хорошее", "Good"), t("1 dona", "1 шт.", "1 unit"),
     [t("Noutbuk", "Ноутбук", "Laptop")], [(Tag.electronics, 0.8, 1.6, True)]),
    ("tv", "malika", Tag.electronics, 7_200_000, False, 5, ["circuit"],
     t("Samsung Smart TV 55\"", "Samsung Smart TV 55\"", "Samsung Smart TV 55\""),
     t("4K, devorga osish moslamasi bilan.", "4K, с кронштейном.", "4K, wall mount included."),
     t("Yaxshi", "Хорошее", "Good"), t("1 dona", "1 шт.", "1 unit"),
     [t("Quruq meva", "Сухофрукты", "Dried fruit")], [(Tag.agri, 0.6, 1.6, True)]),
    ("laptop2", "sevara", Tag.electronics, 9_900_000, False, 7, ["laptop"],
     t("Lenovo Legion 5, RTX 3060", "Lenovo Legion 5, RTX 3060", "Lenovo Legion 5, RTX 3060"),
     t("O‘yin noutbuki, 16 GB RAM.", "Игровой ноутбук, 16 ГБ ОЗУ.", "Gaming laptop, 16 GB RAM."),
     t("Yaxshi", "Хорошее", "Good"), t("1 dona", "1 шт.", "1 unit"),
     [t("Echki yoki qo‘y", "Козы или овцы", "Goats or sheep")], [(Tag.livestock, 0.6, 1.6, True)]),

    ("cement", "dilshod", Tag.construction, 28_000_000, True, 1, ["bricks"],
     t("Sement M400, 400 qop", "Цемент М400, 400 мешков", "M400 cement, 400 sacks"),
     t("Zavoddan, yangi partiya. Yetkazib beramiz.", "С завода, свежая партия. Доставим.", "Fresh from the plant. We deliver."),
     t("Yangi", "Новый", "New"), t("400 qop", "400 мешков", "400 sacks"),
     [t("Yuk mashinasi", "Грузовик", "Truck"), t("Bug‘doy", "Пшеница", "Wheat")],
     [(Tag.transport, 0.3, 1.2, True), (Tag.agri, 0.5, 1.3, False)]),
    ("bricks", "dilshod", Tag.construction, 18_000_000, False, 3, ["bricks"],
     t("Pishiq g‘isht, 20 ming dona", "Жжёный кирпич, 20 тыс. шт.", "Fired brick, 20k pcs"),
     t("1-nav, poddonlarda.", "1 сорт, на поддонах.", "Grade 1, palletised."),
     t("1-nav", "1 сорт", "Grade 1"), t("20 000 dona", "20 000 шт.", "20,000 pcs"),
     [t("Qo‘y", "Овцы", "Sheep")], [(Tag.livestock, 0.5, 1.5, True)]),
    ("timber", "rustam", Tag.construction, 21_000_000, False, 6, ["timber"],
     t("Qarag‘ay taxta, 8 m³", "Сосновая доска, 8 м³", "Pine boards, 8 m³"),
     t("Quritilgan, 50×150×6000.", "Сушёная, 50×150×6000.", "Dried, 50×150×6000."),
     t("Quritilgan", "Сушёная", "Dried"), t("8 m³", "8 м³", "8 m³"),
     [t("Damas", "Damas", "Damas")], [(Tag.transport, 0.3, 1.0, True)]),
    ("rebar", "dilshod", Tag.construction, 33_000_000, False, 9, ["bricks", "timber"],
     t("Armatura A500, 5 tonna", "Арматура А500, 5 тонн", "A500 rebar, 5 tons"),
     t("12 mm, 11.7 m.", "12 мм, 11.7 м.", "12 mm, 11.7 m."),
     t("Yangi", "Новая", "New"), t("5 tonna", "5 тонн", "5 tons"),
     [t("Texnika", "Техника", "Machinery")], [(Tag.machinery, 0.4, 1.3, True)]),
]

CATEGORY = {
    Tag.agri: t("Qishloq xo‘jaligi", "Сельское хозяйство", "Agriculture"),
    Tag.livestock: t("Chorvachilik", "Животноводство", "Livestock"),
    Tag.machinery: t("Texnika", "Техника", "Machinery"),
    Tag.transport: t("Transport", "Транспорт", "Transport"),
    Tag.electronics: t("Elektronika", "Электроника", "Electronics"),
    Tag.construction: t("Qurilish", "Строительство", "Construction"),
}

# muallif, kim haqida, baho, necha kun oldin, matn
REVIEWS = [
    ("malika", "aziz", 5, 3, "Bug‘doy aytilganidek toza chiqdi, yuklab ham berishdi. Rahmat!"),
    ("bobur", "aziz", 5, 12, "Ishonchli hamkor, kelishuv tez yopildi."),
    ("aziz", "javlon", 5, 8, "Traktor hujjatlari joyida, holati aytilganidek."),
    ("dilshod", "bobur", 4, 6, "Mashina yaxshi, faqat biroz kechikib keldi."),
    ("sherzod", "dilshod", 5, 15, "Sement sifatli, o‘z vaqtida yetkazildi."),
    ("sevara", "malika", 5, 4, "Telefon zo‘r holatda, muomala yoqimli."),
    ("gulnora", "sherzod", 5, 10, "Qo‘ylar sog‘lom, vet hujjatlari bor edi."),
    ("javlon", "gulnora", 4, 20, "Guruch yaxshi, qadoqlash ham toza."),
]


def _photo_url(key: str) -> str:
    base = settings.public_api_url.rstrip("/") or "http://127.0.0.1:8010"
    return f"{base}{settings.media_url_prefix}/{FOLDER}/{key}.jpg"


async def fetch_photos(keys: set[str]) -> set[str]:
    """Yuklab olinganlari (yoki avvaldan bor) rasmlar kalitlari."""
    folder = settings.media_root / FOLDER
    folder.mkdir(parents=True, exist_ok=True)
    ready: set[str] = set()
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        for key in sorted(keys):
            path = folder / f"{key}.jpg"
            if path.is_file():
                ready.add(key)
                continue
            size = "w=480&h=480" if key.startswith("av") else "w=1200&h=900"
            try:
                response = await client.get(f"{_U}{PHOTOS[key]}?{size}&fit=crop&auto=format&q=80")
                response.raise_for_status()
                jpeg, _, _ = _process(response.content)
            except Exception as error:  # tarmoq yoki rasm xatosi — rasmsiz davom etamiz
                print(f"  ! {key}: rasm yuklanmadi ({error})")
                continue
            path.write_bytes(jpeg)
            ready.add(key)
    return ready


async def remove(db) -> int:
    ids = (await db.scalars(select(User.id).where(User.phone.in_(DEMO_PHONES)))).all()
    if ids:
        # E'lonlar, istaklar, takliflar, sharhlar foydalanuvchi bilan birga
        # (ON DELETE CASCADE) o'chadi.
        await db.execute(delete(User).where(User.id.in_(ids)))
        await db.commit()
    return len(ids)


async def add(db, photos: set[str]) -> tuple[int, int]:
    users: dict[str, User] = {}
    for index, (key, first, last, handle, region, district, bio, trust, verified, kind, avatar) in enumerate(PEOPLE):
        lat, lon = coordinates_for(region) or (41.2995, 69.2401)
        user = User(
            phone=DEMO_PHONES[index],
            user_type=UserType(kind),
            first_name=first,
            last_name=last,
            handle=handle,
            avatar_url=_photo_url(avatar) if avatar in photos else None,
            bio=bio,
            region=region,
            district=district,
            latitude=lat,
            longitude=lon,
            trust_score=trust,
            is_verified=verified,
            responds_within_minutes=30 + index * 15,
            last_seen_at=NOW - timedelta(hours=index * 3),
        )
        db.add(user)
        users[key] = user
    await db.flush()

    listings: dict[str, Listing] = {}
    for (key, owner, tag, value, premium, days, pics, title, description, condition,
         quantity, wants, desires) in LISTINGS:
        person = users[owner]
        value_minor = value * 100
        listing = Listing(
            owner_id=person.id,
            tag=tag,
            status=ListingStatus.active,
            value_minor=value_minor,
            currency="UZS",
            cash_ok=True,
            is_premium=premium,
            premium_until=NOW + timedelta(days=30) if premium else None,
            latitude=person.latitude,
            longitude=person.longitude,
            region=person.region,
            district=person.district,
            created_at=NOW - timedelta(days=days, hours=len(listings)),
        )
        db.add(listing)
        await db.flush()
        listings[key] = listing
        summary = {code: " / ".join(w[code] for w in wants) for code in ("uz", "ru", "en")}
        for code in ("uz", "ru", "en"):
            db.add(ListingTranslation(
                listing_id=listing.id,
                locale=code,
                title=title[code],
                description=description[code],
                image_alt=title[code],
                category=CATEGORY[tag][code],
                condition=condition[code],
                quantity=quantity[code],
                wants_summary=summary[code][:200],
            ))
        for position, pic in enumerate(p for p in pics if p in photos):
            db.add(ListingPhoto(listing_id=listing.id, url=_photo_url(pic), position=position))
        for position, (category, lo, hi, adds_cash) in enumerate(desires):
            db.add(Desire(
                listing_id=listing.id,
                category=category,
                min_value_minor=int(value_minor * lo),
                max_value_minor=int(value_minor * hi),
                will_add_cash=adds_cash,
                wants_cash=False,
                position=position,
            ))
        for position, want in enumerate(wants):
            row = ListingWant(listing_id=listing.id, position=position)
            db.add(row)
            await db.flush()
            for code in ("uz", "ru", "en"):
                db.add(ListingWantTranslation(want_id=row.id, locale=code, label=want[code]))

    # Sharh faqat yopilgan savdodan keyin yoziladi — har biriga bittadan.
    owned = {owner: key for key, owner, *_ in LISTINGS}
    for author, about, rating, days, body in REVIEWS:
        offer = Offer(
            listing_id=listings[owned[about]].id,
            from_user_id=users[author].id,
            to_user_id=users[about].id,
            status=OfferStatus.completed,
            cash_delta_minor=0,
            created_at=NOW - timedelta(days=days + 2),
        )
        db.add(offer)
        await db.flush()
        db.add(Review(
            offer_id=offer.id,
            author_id=users[author].id,
            about_id=users[about].id,
            rating=rating,
            body=body,
            created_at=NOW - timedelta(days=days),
        ))
    await db.commit()
    return len(users), len(listings)


async def main(remove_only: bool, with_photos: bool = True) -> None:
    async with SessionLocal() as db:
        removed = await remove(db)
        if removed:
            print(f"Eski demo hisoblar olib tashlandi: {removed}")
        if remove_only:
            print("Demo ma'lumotlar o'chirildi.")
            return
        needed = {p for row in LISTINGS for p in row[6]} | {row[10] for row in PEOPLE if row[10]}
        photos = await fetch_photos(needed) if with_photos else set()
        print(f"Rasmlar: {len(photos)}/{len(needed)}")
        people, listings = await add(db, photos)
        print(f"Qo'shildi: {people} ta demo hisob, {listings} ta e'lon, {len(REVIEWS)} ta sharh.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MAB demo ma'lumotlari")
    parser.add_argument("--remove", action="store_true", help="demo ma'lumotlarni olib tashlash")
    parser.add_argument("--no-photos", action="store_true", help="rasmlarsiz (sinov uchun)")
    args = parser.parse_args()
    asyncio.run(main(args.remove, with_photos=not args.no_photos))
