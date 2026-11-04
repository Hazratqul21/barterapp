from __future__ import annotations

from sqlalchemy import Boolean, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps


class Category(Base, Timestamps):
    """
    E'lon kategoriyasi: lentadagi plitka, filtr va e'lon yaratishdagi tanlov.

    Kodda emas, bazada: admin panel yangisini qo'shadi, nomini yoki rasmini
    o'zgartiradi, keraksizini yashiradi — reliz kerak emas. `id` e'londagi
    `tag` qiymati va `/listings?tag=` filtri, shuning uchun bir marta
    berilgach o'zgarmaydi.
    """

    __tablename__ = "categories"

    #: `agri`, `livestock` … yoki admin qo'shgan nomdan yasalgan lotincha kod.
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    #: {"uz": ..., "ru": ..., "en": ...}; o'zbekchasi majburiy, qolgani bo'lmasa
    #: o'zbekchasi ko'rsatiladi.
    name: Mapped[dict] = mapped_column(JSONB, nullable=False)
    #: Admin yuklagan rasm, `media_root` ichidagi yo'l (`categories/<id>-<hex>.jpg`).
    #: Null — ilova o'z rasmini (bo'lmasa belgisini) ko'rsatadi.
    image: Mapped[str | None] = mapped_column(Text)
    #: Yashirilgan kategoriya ro'yxatda chiqmaydi va unga yangi e'lon
    #: qo'yib bo'lmaydi; eski e'lonlari joyida qoladi.
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    position: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
