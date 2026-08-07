from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field

T = TypeVar("T")


class ApiModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Money(ApiModel):
    """
    Never a formatted string. The client formats with `intl` so "$5,000",
    "5 000 ₽" and "5 000 so'm" all come from one number.
    """

    minor: int = Field(description="Amount in the currency's smallest unit")
    currency: str = Field(min_length=3, max_length=3)


class Page(ApiModel, Generic[T]):
    items: list[T]
    next_cursor: str | None = Field(
        default=None, description="Pass back as ?cursor= to fetch the next page"
    )
