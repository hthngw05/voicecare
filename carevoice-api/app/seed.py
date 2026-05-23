"""Reset and re-seed the database with the demo data the Flutter app used to
hard-code. Run with:  python -m app.seed
"""
from __future__ import annotations

from datetime import datetime, timezone, timedelta

from .database import Base, SessionLocal, engine
from .models import (
    AlertLevel,
    AlertRecord,
    CheckIn,
    EmergencyContact,
    Medication,
    MedicationAlarm,
    Senior,
)

SGT = timezone(timedelta(hours=8))


def _dt(year: int, month: int, day: int, hour: int = 0, minute: int = 0) -> datetime:
    return datetime(year, month, day, hour, minute, tzinfo=SGT)


def build_seniors() -> list[Senior]:
    return [
        Senior(
            id="s_lim",
            name="Mdm Lim Ah Choo",
            age=78,
            address="Blk 456 Tampines St 42, #08-123",
            avatar_initials="LM",
            languages=["Hokkien", "Mandarin"],
            preferred_check_in_time="09:00",
            rc_volunteer="Auntie Chua (RC Block 456)",
            phone="6591110001",
            status=AlertLevel.emergency.value,
            sentiment_score=0.18,
            last_check_in_summary='"Wa boh sai, I cannot get out of bed" — distress + weakness detected.',
            last_check_in=_dt(2026, 5, 14, 9, 4),
            mood_history=[0.78, 0.72, 0.65, 0.58, 0.41, 0.32, 0.18],
            meds_history=[True, True, True, True, False, True, False],
            medications=[
                Medication(name="Metformin", dose="1 tablet", time="08:00", taken_today=True),
                Medication(name="Amlodipine", dose="1 tablet", time="08:00", taken_today=True),
                Medication(name="Simvastatin", dose="1 tablet", time="21:00", taken_today=False),
            ],
            contacts=[
                EmergencyContact(name="Lim Mei Ling", relation="Daughter", phone="+65 9123 4567"),
                EmergencyContact(name="Dr Tan (Polyclinic)", relation="GP", phone="+65 6555 1234"),
            ],
        ),
        Senior(
            id="s_tan",
            name="Mr Tan Boon Huat",
            age=82,
            address="Blk 201 Tampines Ave 5, #04-56",
            avatar_initials="TB",
            languages=["Mandarin", "Singlish"],
            preferred_check_in_time="08:30",
            rc_volunteer="Mr Goh (RC Block 201)",
            phone="6597128022",
            status=AlertLevel.concern.value,
            sentiment_score=0.46,
            last_check_in_summary='"Very sian today, didn\'t sleep well" — low mood, 2-day decline.',
            last_check_in=_dt(2026, 5, 14, 8, 35),
            mood_history=[0.71, 0.68, 0.69, 0.60, 0.55, 0.48, 0.46],
            meds_history=[True, True, False, True, True, True, False],
            medications=[
                Medication(name="Losartan", dose="1 tablet", time="08:00", taken_today=True),
                Medication(name="Aspirin", dose="1 tablet", time="20:00", taken_today=False),
            ],
            contacts=[
                EmergencyContact(name="Tan Wei Jie", relation="Son", phone="+65 9876 5432"),
            ],
        ),
        Senior(
            id="s_rajan",
            name="Mr Rajan s/o Krishnan",
            age=75,
            address="Blk 803 Tampines Ave 4, #11-09",
            avatar_initials="RK",
            languages=["Tamil", "English"],
            preferred_check_in_time="10:00",
            phone="6591110003",
            status=AlertLevel.info.value,
            sentiment_score=0.84,
            last_check_in_summary='"Feeling good today, just had breakfast with my wife." All meds taken.',
            last_check_in=_dt(2026, 5, 14, 10, 12),
            mood_history=[0.80, 0.78, 0.82, 0.79, 0.81, 0.83, 0.84],
            meds_history=[True, True, True, True, True, True, True],
            medications=[
                Medication(name="Glipizide", dose="1 tablet", time="08:00", taken_today=True),
            ],
            contacts=[
                EmergencyContact(name="Priya Krishnan", relation="Daughter", phone="+65 9234 1122"),
            ],
        ),
        Senior(
            id="s_siti",
            name="Mdm Siti binte Rahman",
            age=71,
            address="Blk 124 Tampines St 11, #06-218",
            avatar_initials="SR",
            languages=["Malay", "English"],
            preferred_check_in_time="09:30",
            rc_volunteer="Cik Aminah (RC Block 124)",
            phone="6591110004",
            status=AlertLevel.urgent.value,
            sentiment_score=0.30,
            last_check_in_summary="No response to two retry calls at 09:30 and 10:00.",
            last_check_in=_dt(2026, 5, 13, 9, 32),
            mood_history=[0.65, 0.62, 0.58, 0.55, 0.50, 0.42, 0.30],
            meds_history=[True, True, True, False, True, False, False],
            medications=[
                Medication(name="Levothyroxine", dose="1 tablet", time="07:00", taken_today=True),
                Medication(name="Calcium", dose="1 tablet", time="12:00", taken_today=False),
            ],
            contacts=[
                EmergencyContact(name="Nurul Rahman", relation="Daughter", phone="+65 9445 7788"),
                EmergencyContact(name="Hafiz Rahman", relation="Son", phone="+65 9234 9911"),
            ],
        ),
    ]


def build_alerts() -> list[AlertRecord]:
    return [
        AlertRecord(
            id="a1",
            senior_id="s_lim",
            level=AlertLevel.emergency.value,
            trigger='Hokkien distress phrase: "Wa boh sai, cannot get up"',
            action="Auto-called daughter (Lim Mei Ling). SCDF notified.",
            triggered_at=_dt(2026, 5, 14, 9, 6),
        ),
        AlertRecord(
            id="a2",
            senior_id="s_siti",
            level=AlertLevel.urgent.value,
            trigger="No response after 2 retry calls",
            action="RC volunteer Cik Aminah dispatched. SMS sent to daughter.",
            triggered_at=_dt(2026, 5, 14, 10, 5),
        ),
        AlertRecord(
            id="a3",
            senior_id="s_tan",
            level=AlertLevel.concern.value,
            trigger="Sentiment declining 2 days in a row",
            action="Push notification + daily email to son.",
            triggered_at=_dt(2026, 5, 14, 8, 40),
        ),
        AlertRecord(
            id="a4",
            senior_id="s_lim",
            level=AlertLevel.concern.value,
            trigger="Missed evening medication (Simvastatin)",
            action="WhatsApp nudge sent.",
            triggered_at=_dt(2026, 5, 13, 21, 30),
            responded_by="Lim Mei Ling",
            resolved_at=_dt(2026, 5, 13, 21, 45),
        ),
        AlertRecord(
            id="a5",
            senior_id="s_rajan",
            level=AlertLevel.info.value,
            trigger="Missed morning medication",
            action="WhatsApp nudge sent. Senior confirmed taken.",
            triggered_at=_dt(2026, 5, 12, 8, 30),
            responded_by="Mr Rajan",
            resolved_at=_dt(2026, 5, 12, 8, 45),
        ),
        AlertRecord(
            id="a6",
            senior_id="s_tan",
            level=AlertLevel.urgent.value,
            trigger="Reported feeling giddy during morning call",
            action="Son called. GP appointment booked same day.",
            triggered_at=_dt(2026, 5, 11, 8, 35),
            responded_by="Tan Wei Jie",
            resolved_at=_dt(2026, 5, 11, 14, 20),
        ),
    ]


def build_checkins() -> list[CheckIn]:
    return [
        CheckIn(
            senior_id="s_lim",
            transcript="Wa boh sai, I cannot get out of bed.",
            summary='"Cannot get out of bed" — distress + weakness detected (Hokkien).',
            sentiment_score=0.18,
            alert_level=AlertLevel.emergency.value,
            risk_flags=["cannot_move", "distress", "weakness"],
            language="hokkien",
            source="whatsapp",
            created_at=_dt(2026, 5, 14, 9, 4),
        ),
        CheckIn(
            senior_id="s_tan",
            transcript="Very sian today, I didn't sleep well last night.",
            summary='"Very sian today" — low mood, 2-day decline.',
            sentiment_score=0.46,
            alert_level=AlertLevel.concern.value,
            risk_flags=["low_mood"],
            language="singlish",
            source="whatsapp",
            created_at=_dt(2026, 5, 14, 8, 35),
        ),
        CheckIn(
            senior_id="s_rajan",
            transcript="Feeling good today, just had breakfast with my wife. Took my medicine.",
            summary="Feeling good, had breakfast with wife. All meds taken.",
            sentiment_score=0.84,
            alert_level=AlertLevel.info.value,
            risk_flags=[],
            language="english",
            source="whatsapp",
            created_at=_dt(2026, 5, 14, 10, 12),
        ),
        CheckIn(
            senior_id="s_siti",
            transcript="(no response)",
            summary="No response to two retry calls at 09:30 and 10:00.",
            sentiment_score=0.30,
            alert_level=AlertLevel.urgent.value,
            risk_flags=["no_response"],
            language=None,
            source="system",
            created_at=_dt(2026, 5, 13, 9, 32),
        ),
    ]


def build_tan_history() -> list[CheckIn]:
    """A week+ of varied past check-ins for Mr Tan, dated relative to now so
    the Trends 'Check-in history' shows multiple days, not just today."""
    now = datetime.now(SGT)
    rows = [
        # (days_ago, transcript, summary, sentiment, level, flags, lang)
        (1, "Feeling good today, had my breakfast already.", "Feeling good, had breakfast.", 0.82, AlertLevel.info.value, [], "english"),
        (2, "A bit tired but I'm okay lah.", "A little tired but okay.", 0.60, AlertLevel.info.value, [], "singlish"),
        (3, "Very sian today, didn't sleep well last night.", '"Very sian today" — low mood.', 0.42, AlertLevel.concern.value, ["low_mood"], "singlish"),
        (4, "Took my medicine already, thank you.", "Confirmed medication taken.", 0.80, AlertLevel.info.value, [], "english"),
        (5, "My knee a bit pain when I walk.", "Mild knee pain reported.", 0.50, AlertLevel.concern.value, ["medical_concern"], "singlish"),
        (6, "Had a nice chat with my neighbour at the coffeeshop.", "Good social interaction, positive mood.", 0.86, AlertLevel.info.value, [], "english"),
        (7, "Feeling a bit lonely today.", '"Feeling lonely" — low mood.', 0.45, AlertLevel.concern.value, ["low_mood"], "english"),
        (8, "All good, went for my morning walk.", "Active morning, feeling well.", 0.88, AlertLevel.info.value, [], "english"),
        (9, "Slight headache in the morning but better now.", "Mild headache, resolved.", 0.55, AlertLevel.concern.value, ["medical_concern"], "english"),
    ]
    out: list[CheckIn] = []
    for days, transcript, summary, sentiment, level, flags, lang in rows:
        created = (now - timedelta(days=days)).replace(hour=8, minute=30, second=0, microsecond=0)
        med_taken = True if ("medicine" in transcript.lower() or "medication" in summary.lower()) else None
        out.append(CheckIn(
            senior_id="s_tan", transcript=transcript, summary=summary,
            sentiment_score=sentiment, alert_level=level, risk_flags=flags,
            language=lang, source="whatsapp", medication_taken=med_taken, created_at=created,
        ))
    return out


# Only seed these senior IDs. Set to None to seed everyone again.
# Currently limited to Mr Tan so the app shows a single senior.
KEEP_SENIOR_IDS: set[str] | None = {"s_tan"}


def main() -> None:
    # Rebuild the schema so new columns (seniors.phone) and the checkins table
    # are applied cleanly. Safe for dev — this wipes all data.
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    seniors = build_seniors()
    alerts = build_alerts()
    checkins = build_checkins() + build_tan_history()

    # Give each medication an alarm at its scheduled time.
    for s in seniors:
        for m in s.medications:
            if m.time and not m.alarms:
                m.alarms.append(MedicationAlarm(time=m.time))

    if KEEP_SENIOR_IDS is not None:
        seniors = [s for s in seniors if s.id in KEEP_SENIOR_IDS]
        alerts = [a for a in alerts if a.senior_id in KEEP_SENIOR_IDS]
        checkins = [c for c in checkins if c.senior_id in KEEP_SENIOR_IDS]

    with SessionLocal() as db:
        db.add_all(seniors)
        db.commit()  # seniors must exist before alerts/checkins FK
        db.add_all(alerts)
        db.add_all(checkins)
        db.commit()

    print(f"Seeded {len(seniors)} senior(s), {len(alerts)} alert(s), {len(checkins)} check-in(s).")


if __name__ == "__main__":
    main()
