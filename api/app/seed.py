"""
Seed the database with the cast from the corrected React prototype.

The data here is deliberately the *fixed* version: every listing points at a real
owner, every review names a different author and subject, and every notification
carries an explicit destination.

Run with:  .venv/bin/python -m app.seed
"""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select

from app.db.session import SessionLocal
from app.models.listing import (
    Listing,
    ListingPhoto,
    ListingStatus,
    ListingTag,
    ListingTranslation,
    ListingWant,
    ListingWantTranslation,
)
from app.models.offer import Conversation, Message, Offer, OfferItem, OfferStatus
from app.models.review import Review
from app.models.social import Notification, PaymentMethod, VerificationStep
from app.models.desire import Desire
from app.models.listing import ListingTag as Tag
from app.models.user import User, UserType

NOW = datetime.now(UTC)


def img(photo_id: str, w: int, h: int) -> str:
    return f"https://images.unsplash.com/{photo_id}?w={w}&h={h}&fit=crop&auto=format"


IMG = {
    "rice": img("photo-1620844128640-fcd892760d53", 720, 520),
    "tractor": img("photo-1602446692855-6d096499f69b", 720, 520),
    "tractor_alt": img("photo-1606739211185-2c846d734a6d", 480, 480),
    "cattle": img("photo-1641062680671-fec389e4eeeb", 720, 520),
    "timber": img("photo-1634672652995-ee7525bce595", 720, 520),
    "laptop": img("photo-1511385348-a52b4a160dc2", 480, 480),
    "phone": img("photo-1616410011236-7a42121dd981", 480, 480),
    "crops": img("photo-1776582929662-4c33d0e7190b", 480, 480),
    "truck": img("photo-1729150781588-2405d7567d87", 480, 480),
    "avatar_me": img("photo-1507003211169-0a1dd7228f2d", 160, 160),
    "avatar_bek": img("photo-1500648767791-00dcc994a43e", 160, 160),
    "avatar_dilnoza": img("photo-1705645930353-0e335311ef20", 160, 160),
    "avatar_nodir": img("photo-1560250097-0b93528c311a", 160, 160),
    "avatar_sardor": img("photo-1519085360753-af0119f7cbe7", 160, 160),
}

PEOPLE = [
    {
        "key": "me", "lat": 39.9056, "lon": 66.5936,
        "phone": "+998901234122",
        "first_name": "Jasur",
        "last_name": "Toshmatov",
        "handle": "Oq Yer Agro",
        "avatar_url": IMG["avatar_me"],
        "cover_url": IMG["rice"],
        "region": "Samarqand",
        "district": "Kattaqo‘rg‘on",
        "address": "Navoiy ko‘chasi 14",
        "bio": "Guruch, don va quruq meva savdosi. Katta hajmli almashuvlarni afzal ko‘raman.",
        "trust_score": 92,
        "is_verified": True,
        "user_type": "business",
        "tax_id": "304512890",
        "responds_within_minutes": 120,
        "online": True,
    },
    {
        "key": "sardor", "lat": 39.718, "lon": 66.906,
        "phone": "+998901110001",
        "first_name": "Sardor",
        "last_name": "Choriyev",
        "avatar_url": IMG["avatar_sardor"],
        "cover_url": IMG["rice"],
        "region": "Samarqand",
        "district": "Jomboy",
        "bio": "Guruch va don savdosi bilan shug‘ullanaman. Texnika va transportga qiziqaman.",
        "trust_score": 78,
        "is_verified": True,
        "responds_within_minutes": 180,
        "online": False,
        "last_seen_hours": 4,
    },
    {
        "key": "bek", "lat": 41.367, "lon": 69.287,
        "phone": "+998901110002",
        "first_name": "Bekzod",
        "last_name": "Karimov",
        "handle": "Yog‘och Ustaxona",
        "user_type": "business",
        "tax_id": "301778432",
        "avatar_url": IMG["avatar_bek"],
        "cover_url": IMG["timber"],
        "region": "Toshkent",
        "district": "Yunusobod",
        "bio": "Yog‘och ustaxonasi. Xom yog‘och va mebelni elektronika hamda asbobga almashtiraman.",
        "trust_score": 85,
        "is_verified": True,
        "responds_within_minutes": 60,
        "online": True,
    },
    {
        "key": "nodir", "lat": 39.96, "lon": 68.39,
        "phone": "+998901110003",
        "first_name": "Nodir",
        "last_name": "Rasulov",
        "avatar_url": IMG["avatar_nodir"],
        "cover_url": IMG["cattle"],
        "region": "Jizzax",
        "district": "Zomin",
        "bio": "Chorvachilik fermasi. Qoramol va yemni transport hamda texnikaga almashtiramiz.",
        "trust_score": 90,
        "is_verified": True,
        "responds_within_minutes": 30,
        "online": True,
    },
    {
        "key": "dilnoza", "lat": 40.52, "lon": 72.07,
        "phone": "+998901110004",
        "first_name": "Dilnoza",
        "last_name": "Yusupova",
        "avatar_url": IMG["avatar_dilnoza"],
        "cover_url": IMG["crops"],
        "region": "Farg‘ona",
        "district": "Quva",
        "bio": "Bog‘dorchilik: o‘rik, olma, quruq meva. Logistika texnikasini meva partiyalariga almashtiraman.",
        "trust_score": 55,
        "is_verified": False,
        "responds_within_minutes": 120,
        "online": False,
        "last_seen_hours": 20,
    },
]


def t(uz: str, ru: str, en: str) -> dict[str, str]:
    return {"uz": uz, "ru": ru, "en": en}


# What each listing's owner will accept, in the form the matcher compares:
# a category (or None for "any offer"), a value band, and the cash direction.
DESIRES = {
    "cattle":    [(Tag.agri, 0.4, 1.3, False, False), (Tag.machinery, 0.3, 1.5, True, False)],
    "tractor":   [(Tag.agri, 0.6, 1.4, False, True), (Tag.livestock, 0.6, 1.4, False, True)],
    "timber":    [(Tag.electronics, 0.3, 1.6, True, False), (None, 0.5, 1.5, False, False)],
    "phone":     [(Tag.electronics, 0.5, 2.0, True, False)],
    "maize":     [(Tag.transport, 0.4, 2.0, True, False), (None, 0.5, 1.8, False, False)],
    "van":       [(Tag.agri, 0.5, 1.5, False, True)],
    "my_rice":   [(Tag.machinery, 0.6, 2.0, True, False), (Tag.transport, 0.5, 1.6, True, False)],
    "my_laptop": [(Tag.electronics, 0.4, 1.4, True, False)],
    # An open desire — any category, within reach of its own worth. The spec
    # expects this to be the common case, so the seed should contain one.
    "my_truck":  [(Tag.machinery, 0.5, 1.8, True, False),
                  (Tag.livestock, 0.5, 2.2, True, False),
                  (None, 0.4, 1.8, True, False)],
}

LISTINGS = [
    {
        "key": "cattle",
        "owner": "nodir",
        "tag": ListingTag.livestock,
        "value": 18_144_000_00,
        "cash_ok": True,
        "premium": False,
        "days_ago": 5,
        "photos": [IMG["cattle"], IMG["crops"]],
        "title": t("12 bosh Simmental qoramol", "12 голов симментальской породы", "12 head of Simmental cattle"),
        "wants_summary": t("Yem / Suv nasoslari", "Корм / Насосы для полива", "Feed / Irrigation pumps"),
        "image_alt": t("Yashil yaylovda o‘tlab yurgan qoramollar", "Коровы пасутся на зелёном лугу", "Cattle grazing on green pasture"),
        "category": t("Chorvachilik", "Животноводство", "Livestock"),
        "condition": t("Sog‘lom, emlangan", "Здоровые, вакцинированные", "Healthy, vaccinated"),
        "quantity": t("12 bosh", "12 голов", "12 head"),
        "description": t(
            "Yoshi 2–3 yil, o‘rtacha vazni 480 kg. Barchasi veterinar pasporti bilan, emlangan va chiplangan. Fermaga kelib ko‘rish mumkin.",
            "Возраст 2–3 года, средний вес 480 кг. У каждого ветеринарный паспорт, вакцинация и чип. Можно приехать на ферму.",
            "Two to three years old, 480 kg average. Each animal has a veterinary passport, vaccinated and tagged. Farm visits welcome.",
        ),
        "wants": [
            t("Qo‘shimcha yem (20+ tonna)", "Комбикорм (20+ тонн)", "Compound feed (20+ tons)"),
            t("Suv nasosi", "Насос для полива", "Irrigation pump"),
            t("Sut sog‘ish uskunasi", "Доильное оборудование", "Milking equipment"),
        ],
    },
    {
        "key": "tractor",
        "owner": "sardor",
        "tag": ListingTag.machinery,
        "value": 14_994_000_00,
        "cash_ok": True,
        "premium": True,
        "days_ago": 1,
        "photos": [IMG["tractor"], IMG["tractor_alt"]],
        "title": t("MTZ-892 traktor, 2019", "Трактор МТЗ-892, 2019", "MTZ-892 tractor, 2019"),
        "wants_summary": t("Don / Chorva", "Зерно / Скот", "Grain / Livestock"),
        "image_alt": t("Dalada turgan ko‘k traktor", "Синий трактор в поле", "Blue tractor in a field"),
        "category": t("Texnika", "Техника", "Machinery"),
        "condition": t("Yaxshi holatda", "В хорошем состоянии", "Good condition"),
        "quantity": t("1 dona", "1 шт.", "1 unit"),
        "description": t(
            "4200 soat ishlagan, ikkinchi egasi. Yangi gidravlika nasosi va shinalari. Plug va kultivator bilan.",
            "Отработано 4200 моточасов, второй владелец. Новый гидронасос и шины. С плугом и культиватором.",
            "4,200 engine hours, second owner. New hydraulic pump and tyres. Comes with a plough and cultivator.",
        ),
        "wants": [
            t("Don (30+ tonna)", "Зерно (30+ тонн)", "Grain (30+ tons)"),
            t("Qoramol", "Скот", "Cattle"),
            t("Yuk mashinasi", "Грузовик", "Truck"),
        ],
    },
    {
        "key": "timber",
        "owner": "bek",
        "tag": ListingTag.construction,
        "value": 2_709_000_00,
        "cash_ok": False,
        "premium": False,
        "days_ago": 7,
        "photos": [IMG["timber"], IMG["truck"]],
        "title": t("Qarag‘ay taxta, 8 m³ quritilgan", "Сосновая доска, 8 м³ камерной сушки", "Pine timber, 8 m³ kiln-dried"),
        "wants_summary": t("Elektr asboblar / Xizmatlar", "Электроинструмент / Услуги", "Power tools / Services"),
        "image_alt": t("Taxlab qo‘yilgan qarag‘ay taxtalari", "Штабель сосновых досок", "Stacked pine planks"),
        "category": t("Qurilish", "Стройматериалы", "Construction"),
        "condition": t("Quritilgan, saralangan", "Сушёная, сортированная", "Dried, graded"),
        "quantity": t("8 m³", "8 м³", "8 m³"),
        "description": t(
            "Kameralarda quritilgan, namligi 10–12%. O‘lchamlari 50×150×6000 mm. Yuklash uchun texnika bor.",
            "Камерная сушка до влажности 10–12%. Размер 50×150×6000 мм. На месте есть погрузчик.",
            "Kiln-dried to 10–12% moisture. Boards 50×150×6000 mm. A loader is available on site.",
        ),
        "wants": [
            t("Elektr asboblar", "Электроинструмент", "Power tools"),
            t("Qurilish xizmati", "Строительные работы", "Construction work"),
        ],
    },
    {
        "key": "phone",
        "owner": "bek",
        "tag": ListingTag.electronics,
        "value": 781_200_00,
        "cash_ok": True,
        "premium": False,
        "days_ago": 4,
        "photos": [IMG["phone"], IMG["laptop"]],
        "title": t("iPhone 13 · 256 GB", "iPhone 13 · 256 ГБ", "iPhone 13 · 256 GB"),
        "wants_summary": t("Noutbuk / Elektronika", "Ноутбук / Электроника", "Laptop / Electronics"),
        "image_alt": t("Qizil g‘ilofdagi kumushrang iPhone", "Серебристый iPhone в красном чехле", "A silver iPhone with a red case"),
        "category": t("Elektronika", "Электроника", "Electronics"),
        "condition": t("A’lo holatda", "В отличном состоянии", "Excellent condition"),
        "quantity": t("1 dona", "1 шт.", "1 unit"),
        "description": t(
            "Batareya holati 89%. Qutisi, kabeli va himoya oynasi bilan. Qo‘shimcha pul bilan noutbukka almashtiraman.",
            "Состояние батареи 89%. В комплекте коробка, кабель и стекло. Готов доплатить за ноутбук.",
            "Battery health 89%. Comes with box, cable and screen protector. Happy to add cash toward a laptop.",
        ),
        "wants": [
            t("MacBook yoki noutbuk", "MacBook или ноутбук", "MacBook or laptop"),
            t("Planshet", "Планшет", "Tablet"),
        ],
    },
    {
        "key": "phone_2",
        "owner": "sardor",
        "tag": ListingTag.electronics,
        "value": 1100_000_00,
        "cash_ok": True,
        "premium": True,
        "days_ago": 2,
        "photos": [IMG["phone"]],
        "title": t("Samsung S22 Ultra", "Samsung S22 Ultra", "Samsung S22 Ultra"),
        "wants_summary": t("Don / Texnika", "Зерно / Техника", "Grain / Machinery"),
        "image_alt": t("Qora telefon", "Черный телефон", "Black phone"),
        "category": t("Elektronika", "Электроника", "Electronics"),
        "condition": t("A’lo holatda", "В отличном состоянии", "Excellent condition"),
        "quantity": t("1 dona", "1 шт.", "1 unit"),
        "description": t(
            "Yangi holatida, qutisi bor.",
            "В новом состоянии, есть коробка.",
            "Like new, with box.",
        ),
        "wants": [
            t("Don (10+ tonna)", "Зерно (10+ тонн)", "Grain (10+ tons)"),
        ],
    },
    {
        "key": "timber_2",
        "owner": "nodir",
        "tag": ListingTag.construction,
        "value": 4_000_000_00,
        "cash_ok": True,
        "premium": False,
        "days_ago": 3,
        "photos": [IMG["timber"]],
        "title": t("Yong'oq taxtasi", "Доска из ореха", "Walnut timber"),
        "wants_summary": t("Chorva", "Скот", "Livestock"),
        "image_alt": t("Taxtalar", "Доски", "Planks"),
        "category": t("Qurilish", "Стройматериалы", "Construction"),
        "condition": t("Quritilgan", "Сушёная", "Dried"),
        "quantity": t("10 m³", "10 м³", "10 m³"),
        "description": t(
            "Juda sifatli yong'oq yog'ochi.",
            "Очень качественная древесина ореха.",
            "High quality walnut timber.",
        ),
        "wants": [
            t("Qo'y yoki echki", "Овцы или козы", "Sheep or goats"),
        ],
    },
    {
        "key": "cattle_2",
        "owner": "dilnoza",
        "tag": ListingTag.livestock,
        "value": 12_000_000_00,
        "cash_ok": False,
        "premium": True,
        "days_ago": 1,
        "photos": [IMG["cattle"]],
        "title": t("Sog'in sigirlar", "Дойные коровы", "Dairy cows"),
        "wants_summary": t("Meva", "Фрукты", "Fruit"),
        "image_alt": t("Sigirlar", "Коровы", "Cows"),
        "category": t("Chorvachilik", "Животноводство", "Livestock"),
        "condition": t("Sog'lom", "Здоровые", "Healthy"),
        "quantity": t("4 bosh", "4 головы", "4 head"),
        "description": t(
            "Kuniga 20 litr sut beradi.",
            "Дает 20 литров молока в день.",
            "Gives 20 liters of milk a day.",
        ),
        "wants": [
            t("Meva", "Фрукты", "Fruit"),
        ],
    },
    {
        "key": "maize",
        "owner": "sardor",
        "tag": ListingTag.agri,
        "value": 1_663_200_00,
        "cash_ok": False,
        "premium": False,
        "days_ago": 6,
        "photos": [IMG["crops"], IMG["rice"]],
        "title": t("6 tonna yem makkajo‘xori", "6 тонн фуражной кукурузы", "6 tons of feed maize"),
        "wants_summary": t("Transport / Xizmatlar", "Транспорт / Услуги", "Transport / Services"),
        "image_alt": t("Qatorlab quritilayotgan hosil", "Ряды сушащегося урожая", "Rows of drying crops"),
        "category": t("Qishloq xo‘jaligi", "Сельское хозяйство", "Agriculture"),
        "condition": t("Quritilgan", "Сушёная", "Dried"),
        "quantity": t("6 tonna", "6 тонн", "6 tons"),
        "description": t(
            "O‘tgan oy yig‘ilgan, quritilgan va elakdan o‘tkazilgan. Namligi 14%, big-beg qoplarda.",
            "Собрана в прошлом месяце, высушена и просеяна. Влажность 14%, в биг-бэгах.",
            "Harvested last month, dried and sieved. 14% moisture, packed in big bags.",
        ),
        "wants": [
            t("Yuk tashish xizmati", "Грузоперевозки", "Freight service"),
            t("Mini traktor", "Мини-трактор", "Compact tractor"),
        ],
    },
    {
        "key": "van",
        "owner": "dilnoza",
        "tag": ListingTag.transport,
        "value": 11_592_000_00,
        "cash_ok": True,
        "premium": False,
        "days_ago": 3,
        "photos": [IMG["truck"], IMG["crops"]],
        "title": t("Sovutgichli furgon, 2016", "Рефрижератор, 2016", "Refrigerated van, 2016"),
        "wants_summary": t("Meva / Quruq meva", "Фрукты / Сухофрукты", "Fruit / Dried fruit"),
        "image_alt": t("Ochiq maydonda turgan yuk furgoni", "Грузовой фургон на стоянке", "A delivery van parked outdoors"),
        "category": t("Transport", "Транспорт", "Vehicles"),
        "condition": t("Ishlab turgan", "В рабочем состоянии", "In service"),
        "quantity": t("1 dona", "1 шт.", "1 unit"),
        "description": t(
            "3 tonnalik sovutgichli furgon, −18°C gacha ushlaydi. Yugurgani 180 000 km. Bog‘ni kengaytirayotganimiz uchun almashtiramiz.",
            "Рефрижератор на 3 тонны, держит до −18°C. Пробег 180 000 км. Расширяем сад, поэтому меняем.",
            "3-ton refrigerated van holding down to −18°C. 180,000 km. We are expanding the orchard, so we will trade it.",
        ),
        "wants": [
            t("Quritilgan meva", "Сухофрукты", "Dried fruit"),
            t("Yangi meva partiyasi", "Партия свежих фруктов", "Fresh fruit lot"),
        ],
    },
    # The signed-in trader's own listings — these never appear in their feed.
    {
        "key": "my_rice",
        "owner": "me",
        "tag": ListingTag.agri,
        "value": 6_300_000_00,
        "cash_ok": True,
        "premium": True,
        "days_ago": 2,
        "photos": [IMG["rice"], IMG["crops"], IMG["truck"]],
        "title": t("40 tonna uzun donli guruch", "40 тонн длиннозёрного риса", "40 tons of long-grain rice"),
        "wants_summary": t("Traktor / Transport", "Трактор / Транспорт", "Tractors / Vehicles"),
        "image_alt": t("Ochiq maydonda quritilayotgan don", "Зерно сушится в открытом поле", "Grain drying in an open field"),
        "category": t("Qishloq xo‘jaligi", "Сельское хозяйство", "Agriculture"),
        "condition": t("Yangi hosil", "Свежий урожай", "Fresh harvest"),
        "quantity": t("40 tonna", "40 тонн", "40 tons"),
        "description": t(
            "Shu yil hosili, Samarqand viloyati. Namligi 13%, tozalangan, 50 kg li qoplarda. Kamida 10 tonnadan almashish mumkin.",
            "Урожай этого сезона, Самаркандская область. Влажность 13%, очищено, мешки по 50 кг. Партиями от 10 тонн.",
            "This season's harvest from Samarkand. 13% moisture, cleaned, 50 kg sacks. Can be split from 10 tons.",
        ),
        "wants": [
            t("Traktor (80+ ot kuchi)", "Трактор (80+ л.с.)", "Tractor (80+ hp)"),
            t("Yuk mashinasi", "Бортовой грузовик", "Flatbed truck"),
        ],
    },
    {
        # A third listing of my own, so the matcher has more than two pairs to
        # work with. Its desire is open — "any category, roughly this worth" —
        # which is the option the spec expects most people to pick, and it is
        # what lets a demo show the matcher doing something.
        "key": "my_truck",
        "owner": "me",
        "tag": ListingTag.transport,
        "value": 9_400_000_00,
        "cash_ok": True,
        "premium": False,
        "days_ago": 1,
        "photos": [IMG["truck"], IMG["crops"]],
        "title": t("Isuzu bortli yuk mashinasi, 2014", "Бортовой грузовик Isuzu, 2014", "Isuzu flatbed truck, 2014"),
        "wants_summary": t("Texnika / Chorva", "Техника / Скот", "Machinery / Livestock"),
        "image_alt": t("Yo‘l chetida turgan yuk mashinasi", "Грузовик на обочине", "A flatbed truck at the roadside"),
        "category": t("Transport", "Транспорт", "Transport"),
        "condition": t("Ishlab turgan", "В рабочем состоянии", "Working"),
        "quantity": t("1 dona", "1 шт.", "1 piece"),
        "description": t(
            "5 tonnalik bort, yugurgani 240 000 km. Yangi rezina va akkumulyator. Ikkinchi mashina kerak emas, shuning uchun almashtiraman.",
            "Борт на 5 тонн, пробег 240 000 км. Новая резина и аккумулятор. Вторая машина не нужна, поэтому меняю.",
            "Five-tonne bed, 240,000 km. New tyres and battery. I do not need a second vehicle, so I am swapping it.",
        ),
        "wants": [
            t("Traktor yoki mini-texnika", "Трактор или минитехника", "A tractor or compact machinery"),
            t("Qoramol", "Скот", "Cattle"),
        ],
    },
    {
        "key": "my_laptop",
        "owner": "me",
        "tag": ListingTag.electronics,
        "value": 1_486_800_00,
        "cash_ok": True,
        "premium": False,
        "days_ago": 0,
        "photos": [IMG["laptop"]],
        "title": t('MacBook Pro 14"', 'MacBook Pro 14"', 'MacBook Pro 14"'),
        "wants_summary": t("Telefon / Elektronika", "Телефон / Электроника", "Phone / Electronics"),
        "image_alt": t("Stol ustidagi MacBook Pro", "MacBook Pro на столе", "A MacBook Pro on a desk"),
        "category": t("Elektronika", "Электроника", "Electronics"),
        "condition": t("A’lo holatda", "В отличном состоянии", "Excellent condition"),
        "quantity": t("1 dona", "1 шт.", "1 unit"),
        "description": t(
            "14 dyuym, M3 Pro, 18 GB. Batareya sikli 84 ta. Qutisi bilan.",
            "14 дюймов, M3 Pro, 18 ГБ. Циклов батареи 84. С коробкой.",
            '14", M3 Pro, 18 GB. Battery cycles at 84. Boxed.',
        ),
        "wants": [t("iPhone 13 yoki 14", "iPhone 13 или 14", "iPhone 13 or 14")],
    },
]

REVIEWS = [
    ("dilnoza", "me", 5, 14, t(
        "Hammasi kelishilganidek bo‘ldi. Yuk o‘z vaqtida, hujjatlar toza.",
        "Всё прошло, как договаривались. Груз вовремя, документы чистые.",
        "Everything went as agreed. Cargo on time, papers clean.")),
    ("bek", "me", 5, 30, t(
        "Narxni ham, sifatni ham to‘g‘ri aytdi. Tez javob beradi.",
        "Честно описал и цену, и качество. Отвечает быстро.",
        "Described both price and quality honestly. Replies fast.")),
    ("nodir", "me", 4, 60, t(
        "Savdo yaxshi o‘tdi, faqat yuklash bir kun kechikdi.",
        "Сделка прошла хорошо, только погрузка задержалась на день.",
        "Good trade overall, loading was one day late.")),
    ("nodir", "sardor", 5, 21, t(
        "Donni o‘zi tashib keldi, tarozi to‘g‘ri chiqdi.",
        "Зерно привёз сам, вес сошёлся точно.",
        "Delivered the grain himself and the weight matched exactly.")),
    ("bek", "sardor", 4, 60, t(
        "Texnika tavsifga mos edi. Kelishuv biroz cho‘zildi.",
        "Техника соответствовала описанию. Договаривались долго.",
        "The machine matched the description. Agreeing took a while.")),
    ("dilnoza", "bek", 5, 7, t(
        "Taxta o‘lchamlari aniq. Bir soatda javob berdi.",
        "Размеры доски точные. Ответил в течение часа.",
        "Board sizes were exact. He replied within an hour.")),
    ("sardor", "bek", 5, 30, t(
        "Ustaxonaga borib ko‘rdim, hammasi aytilganidek.",
        "Съездил в мастерскую — всё как описано.",
        "Visited the workshop and everything was as described.")),
    ("sardor", "nodir", 5, 14, t(
        "Veterinar hujjatlari to‘liq, mollar sog‘lom. Escrow orqali ishladik.",
        "Ветеринарные документы полные, животные здоровые. Работали через escrow.",
        "Full veterinary paperwork and healthy animals. We used escrow.")),
    ("dilnoza", "nodir", 5, 60, t(
        "Fermaga borib ko‘rishga ruxsat berdi, savollarga sabr bilan javob berdi.",
        "Разрешил приехать на ферму и терпеливо ответил на все вопросы.",
        "He let me visit the farm and answered every question patiently.")),
    ("bek", "dilnoza", 5, 30, t(
        "Yangi a’zo bo‘lsa ham juda tartibli ishladi.",
        "Хоть и новый участник, работает очень аккуратно.",
        "A new member, but very organised.")),
]


async def run() -> None:
    async with SessionLocal() as db:
        # Idempotent: wipe the seeded world, keep the schema.
        for model in (
            Message, Conversation, OfferItem, Offer, Review, Notification,
            PaymentMethod, VerificationStep, Desire, ListingWantTranslation, ListingWant,
            ListingPhoto, ListingTranslation, Listing, User,
        ):
            await db.execute(delete(model))
        await db.commit()

        users: dict[str, User] = {}
        for spec in PEOPLE:
            last_seen = NOW
            if not spec.get("online"):
                last_seen = NOW - timedelta(hours=spec.get("last_seen_hours", 24))
            user = User(
                phone=spec["phone"],
                user_type=UserType(spec.get("user_type", "individual")),
                tax_id=spec.get("tax_id"),
                latitude=spec["lat"],
                longitude=spec["lon"],
                first_name=spec["first_name"],
                last_name=spec["last_name"],
                handle=spec.get("handle"),
                avatar_url=spec.get("avatar_url"),
                cover_url=spec.get("cover_url"),
                bio=spec.get("bio"),
                region=spec.get("region"),
                district=spec.get("district"),
                address=spec.get("address"),
                trust_score=spec["trust_score"],
                is_verified=spec["is_verified"],
                responds_within_minutes=spec.get("responds_within_minutes"),
                last_seen_at=last_seen,
            )
            db.add(user)
            users[spec["key"]] = user
        await db.flush()

        for spec in PEOPLE:
            for step, hint, weight in [
                ("phone", "SMS orqali tasdiqlangan", 20),
                ("passport", "Pasport yoki JSHSHIR", 25),
                ("business", "Korxona hujjatlari", 25),
                ("bank", "Escrow to‘lovlari uchun", 20),
                ("video", "30 soniyalik selfie video", 10),
            ]:
                done = spec["is_verified"] and step in {"phone", "passport", "business"}
                db.add(
                    VerificationStep(
                        user_id=users[spec["key"]].id,
                        step=step,
                        hint=hint,
                        weight=weight,
                        state="done" if done else ("pending" if step == "bank" else "todo"),
                    )
                )

        db.add_all([
            PaymentMethod(user_id=users["me"].id, brand="Humo", label="Oq Yer Agro · korporativ", last4="4412", expires="09/28", is_primary=True),
            PaymentMethod(user_id=users["me"].id, brand="Uzcard", label="Shaxsiy karta", last4="8703", expires="02/27", is_primary=False),
        ])

        coords_of = {p['key']: (p['lat'], p['lon']) for p in PEOPLE}
        listings: dict[str, Listing] = {}
        for spec in LISTINGS:
            listing = Listing(
                owner_id=users[spec["owner"]].id,
                tag=spec["tag"],
                status=ListingStatus.active,
                value_minor=spec["value"],
                currency="UZS",
                cash_ok=spec["cash_ok"],
                is_premium=spec["premium"],
                latitude=coords_of[spec["owner"]][0],
                longitude=coords_of[spec["owner"]][1],
                created_at=NOW - timedelta(days=spec["days_ago"]),
            )
            db.add(listing)
            await db.flush()
            listings[spec["key"]] = listing

            for code in ("uz", "ru", "en"):
                db.add(ListingTranslation(
                    listing_id=listing.id,
                    locale=code,
                    title=spec["title"][code],
                    description=spec["description"][code],
                    image_alt=spec["image_alt"][code],
                    category=spec["category"][code],
                    condition=spec["condition"][code],
                    quantity=spec["quantity"][code],
                    wants_summary=spec["wants_summary"][code],
                ))

            for position, url in enumerate(spec["photos"]):
                db.add(ListingPhoto(listing_id=listing.id, url=url, position=position))

            for position, (category, lo, hi, adds_cash, wants_cash) in enumerate(
                DESIRES.get(spec["key"], [])
            ):
                db.add(
                    Desire(
                        listing_id=listing.id,
                        category=category,
                        min_value_minor=int(spec["value"] * lo),
                        max_value_minor=int(spec["value"] * hi),
                        will_add_cash=adds_cash,
                        wants_cash=wants_cash,
                        position=position,
                    )
                )

            for position, want in enumerate(spec["wants"]):
                row = ListingWant(listing_id=listing.id, position=position)
                db.add(row)
                await db.flush()
                for code in ("uz", "ru", "en"):
                    db.add(ListingWantTranslation(want_id=row.id, locale=code, label=want[code]))

        await db.flush()

        # A completed deal is what unlocks a review, so every seeded review gets one.
        for author, about, rating, days, body in REVIEWS:
            offer = Offer(
                listing_id=listings["tractor"].id,
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
                body=body["uz"],
                created_at=NOW - timedelta(days=days),
            ))

        # A live negotiation: my MacBook + $100 against Bekzod's iPhone.
        live = Offer(
            listing_id=listings["phone"].id,
            from_user_id=users["me"].id,
            to_user_id=users["bek"].id,
            status=OfferStatus.pending,
            cash_delta_minor=1_260_000_00,
            expires_at=NOW + timedelta(hours=46),
            created_at=NOW - timedelta(hours=2),
        )
        db.add(live)
        await db.flush()
        db.add(OfferItem(offer_id=live.id, listing_id=listings["my_laptop"].id))

        thread = Conversation(
            offer_id=live.id,
            user_a_id=users["me"].id,
            user_b_id=users["bek"].id,
            last_message_at=NOW - timedelta(minutes=20),
        )
        db.add(thread)
        await db.flush()

        script = [
            ("bek", "Salom! MacBook hali ham barterga bormi?", 120),
            ("me", 'Ha — 14", M3 Pro, 18 GB. Batareya sikli 84 ta.', 105),
            ("bek", "Mening iPhone 13’im 256 GB, qutisi bilan. To‘g‘ridan-to‘g‘ri almashamizmi?", 90),
            ("me", "Noutbuk qimmatroq, shuning uchun sizning tomondan $100 qo‘shib taklif yubordim.", 45),
            ("bek", "To‘g‘ri. Shanba kuni ertalab Registonda ko‘rishsak bo‘ladimi?", 20),
        ]
        for sender, body, minutes_ago in script:
            db.add(Message(
                conversation_id=thread.id,
                sender_id=users[sender].id,
                body=body,
                created_at=NOW - timedelta(minutes=minutes_ago),
            ))

        # More threads, one per status, so every state the inbox can show has
        # something behind it: a demo that only ever shows "pending" leaves the
        # other five pills untested and unseen.
        #
        # These write the offer rows directly rather than going through the
        # API, exactly as the review fixtures above do. A completed offer made
        # through `PATCH /offers` closes both listings and empties the feed;
        # here the goods stay on the market.
        async def thread_for(
            *,
            wanted: str,
            offered: str,
            peer: str,
            status: OfferStatus,
            cash: int,
            hours_ago: int,
            script: list[tuple[str, str, int]],
            from_me: bool = True,
        ) -> Conversation:
            offer = Offer(
                listing_id=listings[wanted].id,
                from_user_id=users["me" if from_me else peer].id,
                to_user_id=users[peer if from_me else "me"].id,
                status=status,
                cash_delta_minor=cash,
                currency="UZS",
                expires_at=NOW + timedelta(hours=48 - hours_ago),
                created_at=NOW - timedelta(hours=hours_ago),
            )
            db.add(offer)
            await db.flush()
            db.add(OfferItem(offer_id=offer.id, listing_id=listings[offered].id))

            conversation = Conversation(
                offer_id=offer.id,
                user_a_id=users["me"].id,
                user_b_id=users[peer].id,
                last_message_at=NOW - timedelta(minutes=script[-1][2]),
            )
            db.add(conversation)
            await db.flush()

            for sender, body, minutes_ago in script:
                db.add(Message(
                    conversation_id=conversation.id,
                    sender_id=users[sender].id,
                    body=body,
                    # Everything but the newest thread is already read, so the
                    # unread badge means something when it does appear.
                    read_at=None if status is OfferStatus.talking else NOW,
                    created_at=NOW - timedelta(minutes=minutes_ago),
                ))
            return conversation

        await thread_for(
            wanted="tractor", offered="my_rice", peer="sardor",
            status=OfferStatus.talking, cash=3_200_000_00, hours_ago=9,
            script=[
                ("me", "Assalomu alaykum. 40 tonna guruchni traktorga almashtirmoqchiman.", 540),
                ("sardor", "Guruch qaysi navi? Traktor 2019-yil, soati 3 100.", 500),
                ("me", "Uzun donli, yangi hosil. Ustiga 3,2 mln qo‘shaman.", 420),
                ("sardor", "Kamroq bo‘lmaydimi? 4 mln bo‘lsa roziman.", 180),
            ],
        )

        await thread_for(
            wanted="maize", offered="my_rice", peer="nodir",
            status=OfferStatus.accepted, cash=0, hours_ago=30,
            script=[
                ("nodir", "Guruchingizga makkajo‘xori kerakmi? 6 tonna bor.", 1800),
                ("me", "Kerak. Tonnasi qancha turadi?", 1700),
                ("nodir", "Kelishdik. Chorshanba kuni Jomboyda topshiraman.", 1500),
                ("me", "Zo‘r, qabul qildim.", 1440),
            ],
        )

        await thread_for(
            wanted="timber", offered="my_laptop", peer="bek",
            status=OfferStatus.completed, cash=0, hours_ago=96,
            script=[
                ("me", "Yog‘och kerak edi, noutbuk taklif qilaman.", 5760),
                ("bek", "Ko‘rib chiqdim, bo‘ladi. Ustaxonaga olib keling.", 5700),
                ("me", "Topshirdim, rahmat!", 5000),
            ],
        )

        await thread_for(
            wanted="van", offered="my_rice", peer="dilnoza",
            status=OfferStatus.declined, cash=0, hours_ago=140,
            script=[
                ("me", "Furgonga guruch almashtirasizmi?", 8400),
                ("dilnoza", "Kechirasiz, menga transport kerak edi.", 8300),
            ],
            from_me=True,
        )

        db.add_all([
            Notification(
                user_id=users["me"].id, kind="offer", target_type="chat",
                target_id=thread.id,
                title="Bekzod Karimov yozdi",
                body="“Shanba kuni ertalab Registonda ko‘rishsak bo‘ladimi?”",
                avatar_url=IMG["avatar_bek"],
                created_at=NOW - timedelta(minutes=20),
            ),
            Notification(
                user_id=users["me"].id, kind="match", target_type="matches",
                target_id=None,
                title="95% moslik topildi",
                body="40 t guruch · MTZ-892 traktor",
                avatar_url=IMG["tractor_alt"],
                created_at=NOW - timedelta(hours=3),
            ),
            Notification(
                user_id=users["me"].id, kind="system", target_type="verification",
                target_id=users["me"].id,
                title="Korxona hujjatlari tasdiqlandi",
                body="Ishonch darajangiz 92/100 ga ko‘tarildi.",
                created_at=NOW - timedelta(days=2),
            ),
        ])

        await db.commit()

        total = await db.scalar(select(Listing).where(Listing.id == listings["cattle"].id))
        print(
            f"seeded: {len(PEOPLE)} users, {len(LISTINGS)} listings, "
            f"{len(REVIEWS)} reviews, 5 conversations "
            f"(sanity check {'ok' if total else 'failed'})"
        )
        print(f"sign in as: {PEOPLE[0]['phone']}  (OTP is returned by /auth/otp/request)")


if __name__ == "__main__":
    asyncio.run(run())
