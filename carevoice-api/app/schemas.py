from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from .models import AlertLevel


class _Base(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class SeniorUpdate(BaseModel):
    preferred_check_in_time: str | None = None  # "HH:MM"
    wellness_enabled: bool | None = None


class SeniorCreate(BaseModel):
    name: str
    phone: str | None = None
    age: int = 0
    languages: list[str] = []
    address: str = ""
    preferred_check_in_time: str = "09:00"
    rc_volunteer: str | None = None


class EventOut(BaseModel):
    id: str
    title: str
    date: str       # "Sat, 24 May"
    time: str       # "10:00 AM"
    location: str
    category: str   # e.g. "Exercise", "Social", "Health"
    description: str
    url: str = ""   # link to the event listing (e.g. Eventbrite)


class AlarmOut(_Base):
    id: int
    time: str
    enabled: bool
    status: str  # "scheduled" | "awaiting" | "done"


class MedicationOut(_Base):
    id: int
    name: str
    dose: str
    taken_today: bool = Field(serialization_alias="takenToday")
    has_photo: bool = Field(serialization_alias="hasPhoto")
    alarms: list[AlarmOut]


class MedicationCreate(BaseModel):
    name: str
    dose: str
    times: list[str] = []  # one or more "HH:MM" alarm times
    photo: str | None = None        # base64-encoded image (no data: prefix)
    photo_mime: str | None = None   # e.g. "image/jpeg"


class AlarmCreate(BaseModel):
    time: str  # "HH:MM"


class OcrRequest(BaseModel):
    photo: str            # base64 (no data: prefix)
    photo_mime: str = "image/jpeg"


class OcrResult(BaseModel):
    name: str
    dose: str
    times: list[str]


class AlarmUpdate(BaseModel):
    time: str | None = None
    enabled: bool | None = None


class ContactOut(_Base):
    name: str
    relation: str
    phone: str


class ActiveAlertOut(_Base):
    message: str
    level: AlertLevel
    triggered_at: datetime = Field(serialization_alias="triggeredAt")


class SeniorOut(_Base):
    """Full senior payload used by both the dashboard list and the detail screen."""

    id: str
    name: str
    age: int
    address: str
    avatar_initials: str = Field(serialization_alias="avatarInitials")
    languages: list[str]
    preferred_check_in_time: str = Field(serialization_alias="preferredCheckInTime")
    wellness_enabled: bool = Field(serialization_alias="wellnessEnabled")
    rc_volunteer: str | None = Field(default=None, serialization_alias="rcVolunteer")

    phone: str | None = None
    status: AlertLevel
    sentiment_score: float = Field(serialization_alias="sentimentScore")
    last_check_in_summary: str = Field(serialization_alias="lastCheckInSummary")
    last_check_in: datetime = Field(serialization_alias="lastCheckIn")
    active_alert: ActiveAlertOut | None = Field(default=None, serialization_alias="activeAlert")

    medications: list[MedicationOut]
    contacts: list[ContactOut]
    mood_history: list[float] = Field(serialization_alias="moodHistory")
    meds_history: list[bool] = Field(serialization_alias="medsHistory")
    chart_labels: list[str] = Field(default_factory=list, serialization_alias="chartLabels")


class EscalationStep(BaseModel):
    label: str
    done: bool
    at: datetime | None = None


class AlertOut(_Base):
    id: str
    senior_id: str = Field(serialization_alias="seniorId")
    senior_name: str = Field(serialization_alias="seniorName")
    level: AlertLevel
    trigger: str
    action: str
    responded_by: str | None = Field(default=None, serialization_alias="respondedBy")
    triggered_at: datetime = Field(serialization_alias="triggeredAt")
    resolved_at: datetime | None = Field(default=None, serialization_alias="resolvedAt")
    escalation: list[EscalationStep] = []


class CheckInOut(_Base):
    id: int
    senior_id: str = Field(serialization_alias="seniorId")
    transcript: str
    summary: str
    sentiment_score: float = Field(serialization_alias="sentimentScore")
    alert_level: AlertLevel = Field(serialization_alias="alertLevel")
    risk_flags: list[str] = Field(serialization_alias="riskFlags")
    language: str | None = None
    source: str
    created_at: datetime = Field(serialization_alias="createdAt")
