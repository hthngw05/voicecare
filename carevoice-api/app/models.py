from __future__ import annotations

from datetime import date, datetime
from enum import Enum

from sqlalchemy import ARRAY, Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class AlertLevel(str, Enum):
    info = "info"
    concern = "concern"
    urgent = "urgent"
    emergency = "emergency"


class Senior(Base):
    __tablename__ = "seniors"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    age: Mapped[int] = mapped_column(Integer, nullable=False)
    address: Mapped[str] = mapped_column(String, nullable=False)
    avatar_initials: Mapped[str] = mapped_column(String(4), nullable=False)
    languages: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    preferred_check_in_time: Mapped[str] = mapped_column(String, nullable=False)
    rc_volunteer: Mapped[str | None] = mapped_column(String, nullable=True)

    # WhatsApp number (digits only, e.g. "6591234567") used to match incoming
    # check-ins from the voicecare service to this senior.
    phone: Mapped[str | None] = mapped_column(String, nullable=True, unique=True, index=True)

    # Daily wellness check-in (a "How are you feeling?" WhatsApp message sent at
    # preferred_check_in_time). last_wellness_on dedupes to once per day.
    wellness_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    last_wellness_on: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Live status snapshot
    status: Mapped[AlertLevel] = mapped_column(String, nullable=False, default=AlertLevel.info.value)
    sentiment_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.5)
    last_check_in_summary: Mapped[str] = mapped_column(Text, nullable=False, default="")
    last_check_in: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    # 7-day rolling history (oldest -> newest)
    mood_history: Mapped[list[float]] = mapped_column(ARRAY(Float), nullable=False, default=list)
    meds_history: Mapped[list[bool]] = mapped_column(ARRAY(Boolean), nullable=False, default=list)

    medications: Mapped[list["Medication"]] = relationship(
        back_populates="senior", cascade="all, delete-orphan", order_by="Medication.time"
    )
    contacts: Mapped[list["EmergencyContact"]] = relationship(
        back_populates="senior", cascade="all, delete-orphan"
    )
    alerts: Mapped[list["AlertRecord"]] = relationship(
        back_populates="senior", cascade="all, delete-orphan", order_by="AlertRecord.triggered_at.desc()"
    )
    checkins: Mapped[list["CheckIn"]] = relationship(
        back_populates="senior", cascade="all, delete-orphan", order_by="CheckIn.created_at.desc()"
    )


class Medication(Base):
    __tablename__ = "medications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    senior_id: Mapped[str] = mapped_column(ForeignKey("seniors.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    dose: Mapped[str] = mapped_column(String, nullable=False)
    # Legacy single time/reminder columns kept for compatibility; reminders are
    # now driven by the medication_alarms table (one medicine -> many alarms).
    time: Mapped[str | None] = mapped_column(String, nullable=True)
    taken_today: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    # Optional photo of the medication (base64-encoded image + its MIME type),
    # shown in the app and sent before the WhatsApp reminder poll.
    photo: Mapped[str | None] = mapped_column(Text, nullable=True)
    photo_mime: Mapped[str | None] = mapped_column(String, nullable=True)

    senior: Mapped[Senior] = relationship(back_populates="medications")
    alarms: Mapped[list["MedicationAlarm"]] = relationship(
        back_populates="medication", cascade="all, delete-orphan", order_by="MedicationAlarm.time"
    )


class MedicationAlarm(Base):
    """One reminder time for a medication. A medication taken multiple times a
    day has multiple alarms."""

    __tablename__ = "medication_alarms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    medication_id: Mapped[int] = mapped_column(ForeignKey("medications.id", ondelete="CASCADE"), nullable=False)
    time: Mapped[str] = mapped_column(String, nullable=False)  # "HH:MM" in SGT
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    # Per-day reminder + follow-up state.
    last_reminded_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    last_reminded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    next_prompt_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    followups: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    acknowledged: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    medication: Mapped[Medication] = relationship(back_populates="alarms")


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    senior_id: Mapped[str] = mapped_column(ForeignKey("seniors.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    relation: Mapped[str] = mapped_column(String, nullable=False)
    phone: Mapped[str] = mapped_column(String, nullable=False)

    senior: Mapped[Senior] = relationship(back_populates="contacts")


class AlertRecord(Base):
    __tablename__ = "alerts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    senior_id: Mapped[str] = mapped_column(ForeignKey("seniors.id", ondelete="CASCADE"), nullable=False)
    level: Mapped[AlertLevel] = mapped_column(String, nullable=False)
    trigger: Mapped[str] = mapped_column(Text, nullable=False)
    action: Mapped[str] = mapped_column(Text, nullable=False)
    responded_by: Mapped[str | None] = mapped_column(String, nullable=True)
    triggered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    senior: Mapped[Senior] = relationship(back_populates="alerts")


class CheckIn(Base):
    """One wellness check-in produced by the voicecare service (a transcribed
    WhatsApp voice/text message plus its AI analysis)."""

    __tablename__ = "checkins"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    senior_id: Mapped[str] = mapped_column(ForeignKey("seniors.id", ondelete="CASCADE"), nullable=False)
    transcript: Mapped[str] = mapped_column(Text, nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False, default="")
    sentiment_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.5)
    alert_level: Mapped[AlertLevel] = mapped_column(String, nullable=False, default=AlertLevel.info.value)
    risk_flags: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    language: Mapped[str | None] = mapped_column(String, nullable=True)
    source: Mapped[str] = mapped_column(String, nullable=False, default="whatsapp")
    medication_taken: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    senior: Mapped[Senior] = relationship(back_populates="checkins")
