from __future__ import annotations

from sqlalchemy import Boolean, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps


class AppSetting(Base, Timestamps):
    """
    Ishlab turgan serverda o'zgartiriladigan sozlama.

    `.env` emas: `.env` ni o'zgartirish server fayllariga kirishni va qayta
    ishga tushirishni talab qiladi. Firebase kaliti esa mahsulot egasi
    qo'lida bo'ladi va u serverga kira olmaydi — natijada kalit bor-u,
    uni qo'yadigan odam yo'q holati chiqadi.

    Bu yerda faqat **sozlama** turadi. Foydalanuvchi ma'lumoti emas, va
    hech qachon `.env` dagi `JWT_SECRET` kabi tizim kaliti ham emas —
    ular joyida qoladi, chunki ularni almashtirish qayta ishga tushirishni
    talab qiladi.
    """

    __tablename__ = "app_settings"

    key: Mapped[str] = mapped_column(String(60), primary_key=True)
    value: Mapped[str] = mapped_column(Text, nullable=False)

    #: Maxfiy qiymat hech qachon o'qish uchun qaytarilmaydi. API faqat
    #: "sozlangan / sozlanmagan" deb javob beradi.
    #:
    #: Sabab: panelga kirish huquqi bo'lgan har qanday hisob — yoki
    #: o'g'irlangan sessiya — kalitni ko'chirib olib keta olardi. Yozish
    #: mumkin, o'qish mumkin emas: bu kalitni almashtirish uchun yetarli
    #: va uni sizdirish uchun yetarli emas.
    is_secret: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
