"""Shared request/response models."""
from __future__ import annotations

import re

from pydantic import BaseModel, Field, field_validator

USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,20}$")


class DevLoginBody(BaseModel):
    username: str
    avatarEmoji: str = "🎯"
    avatarColor: str = "FF4655"

    @field_validator("username")
    @classmethod
    def _valid_username(cls, v: str) -> str:
        if not USERNAME_RE.match(v):
            raise ValueError("username must be 3–20 chars: letters, numbers, underscore")
        return v


class AppleLoginBody(BaseModel):
    identityToken: str
    nonce: str | None = None
    username: str | None = None  # only used on first sign-in


class ProfilePatch(BaseModel):
    username: str | None = None
    avatarEmoji: str | None = None
    avatarColor: str | None = None

    @field_validator("username")
    @classmethod
    def _valid_username(cls, v: str | None) -> str | None:
        if v is not None and not USERNAME_RE.match(v):
            raise ValueError("username must be 3–20 chars: letters, numbers, underscore")
        return v


class FavoritesBody(BaseModel):
    favorite: str | None = None
    secondaries: list[str] = Field(default_factory=list)


class PostBody(BaseModel):
    body: str = Field(min_length=1, max_length=2000)
    parentId: str | None = None


class ReportBody(BaseModel):
    reason: str = Field(default="", max_length=280)
