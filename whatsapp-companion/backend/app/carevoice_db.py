"""
Writes wellness check-ins from the voicecare service into the shared CareVoice
PostgreSQL database (the same DB the Flutter caregiver app reads from).

Tables written: seniors (live status), checkins (history), alerts (when distress
is detected). Schema is owned by flutter/backend/app/models.py.

Connection comes from CAREVOICE_DATABASE_URL, e.g.
    postgresql://carevoice:carevoice@host.docker.internal:5432/carevoice
(host.docker.internal lets this container reach Postgres running on the host.)
"""
from __future__ import annotations

import os
import re
from datetime import datetime, timezone, timedelta

import psycopg
from psycopg.rows import dict_row

SGT = timezone(timedelta(hours=8))

DEFAULT_URL = "postgresql://carevoice:carevoice@host.docker.internal:5432/carevoice"

_ACTION_BY_LEVEL = {
    "emergency": "Auto-called caregiver. Emergency services (SCDF) notified.",
    "urgent": "SMS + call sent to caregiver. RC volunteer alerted.",
    "concern": "Push notification sent to caregiver.",
    "info": "Logged. No action needed.",
}


def _conn_url() -> str:
    return os.getenv("CAREVOICE_DATABASE_URL", DEFAULT_URL)


def normalize_phone(raw: str) -> str:
    """'6591234567@s.whatsapp.net' -> '6591234567'."""
    digits = re.sub(r"\D", "", raw or "")
    return digits


def _connect() -> psycopg.Connection:
    return psycopg.connect(_conn_url(), row_factory=dict_row)


def _get_or_create_senior(cur: psycopg.Cursor, phone: str) -> dict:
    cur.execute("SELECT * FROM seniors WHERE phone = %s", (phone,))
    row = cur.fetchone()
    if row:
        return row

    senior_id = f"s_{phone}" if phone else f"s_{int(datetime.now().timestamp())}"
    initials = (phone[-2:] if len(phone) >= 2 else "??").upper()
    now = datetime.now(SGT)
    cur.execute(
        """
        INSERT INTO seniors (
            id, name, age, address, avatar_initials, languages,
            preferred_check_in_time, rc_volunteer, phone,
            status, sentiment_score, last_check_in_summary, last_check_in,
            mood_history, meds_history
        ) VALUES (
            %(id)s, %(name)s, %(age)s, %(address)s, %(initials)s, %(languages)s,
            %(pref)s, %(rc)s, %(phone)s,
            %(status)s, %(sentiment)s, %(summary)s, %(last)s,
            %(mood)s, %(meds)s
        )
        RETURNING *
        """,
        {
            "id": senior_id,
            "name": f"New Senior (+{phone})" if phone else "New Senior",
            "age": 0,
            "address": "Unknown",
            "initials": initials,
            "languages": [],
            "pref": "09:00",
            "rc": None,
            "phone": phone or None,
            "status": "info",
            "sentiment": 0.5,
            "summary": "",
            "last": now,
            "mood": [],
            "meds": [],
        },
    )
    return cur.fetchone()


def _append_trim(values: list, new, keep: int = 7) -> list:
    out = list(values or [])
    out.append(new)
    return out[-keep:]


def record_checkin(
    *,
    phone: str,
    transcript: str,
    analysis: dict,
    source: str = "whatsapp",
) -> dict:
    """Persist one check-in. Returns a small summary dict of what was written.

    `analysis` is the dict returned by analysis.analyze().
    """
    phone = normalize_phone(phone)
    now = datetime.now(SGT)
    level = analysis.get("alert_level", "info")
    sentiment = float(analysis.get("sentiment_score", 0.5))
    summary = analysis.get("summary") or ""
    flags = list(analysis.get("risk_flags") or [])
    language = analysis.get("language")
    med_taken = analysis.get("medication_taken")

    with _connect() as conn:
        with conn.cursor() as cur:
            senior = _get_or_create_senior(cur, phone)
            senior_id = senior["id"]

            # 1) Insert the check-in row.
            cur.execute(
                """
                INSERT INTO checkins (
                    senior_id, transcript, summary, sentiment_score,
                    alert_level, risk_flags, language, source, medication_taken, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
                """,
                (senior_id, transcript, summary, sentiment, level, flags, language, source, med_taken, now),
            )
            checkin_id = cur.fetchone()["id"]

            # 2) Update the senior's live status snapshot + rolling histories.
            new_mood = _append_trim(senior.get("mood_history"), round(sentiment, 2))
            new_meds = senior.get("meds_history") or []
            if med_taken is not None:
                new_meds = _append_trim(new_meds, bool(med_taken))
            cur.execute(
                """
                UPDATE seniors
                   SET status = %s,
                       sentiment_score = %s,
                       last_check_in_summary = %s,
                       last_check_in = %s,
                       mood_history = %s,
                       meds_history = %s
                 WHERE id = %s
                """,
                (level, sentiment, summary, now, new_mood, new_meds, senior_id),
            )

            # 3) Raise an alert for anything above "info".
            alert_id = None
            if level != "info":
                alert_id = f"ck{checkin_id}"
                cur.execute(
                    """
                    INSERT INTO alerts (
                        id, senior_id, level, trigger, action,
                        responded_by, triggered_at, resolved_at
                    ) VALUES (%s, %s, %s, %s, %s, NULL, %s, NULL)
                    """,
                    (
                        alert_id,
                        senior_id,
                        level,
                        transcript if transcript else summary,
                        _ACTION_BY_LEVEL.get(level, _ACTION_BY_LEVEL["concern"]),
                        now,
                    ),
                )
            else:
                # A healthy ("info") check-in clears this senior's open alerts:
                # if they report they're fine, resolve any outstanding alerts.
                cur.execute(
                    """
                    UPDATE alerts
                       SET resolved_at = %s,
                           responded_by = COALESCE(responded_by, 'check-in')
                     WHERE senior_id = %s AND resolved_at IS NULL
                    """,
                    (now, senior_id),
                )

            # Any response from the senior acknowledges today's pending
            # medication reminders, stopping further follow-up prompts.
            acknowledge_reminders(cur, senior_id, taken=(med_taken is True))

        # context exit commits the transaction
    return {
        "senior_id": senior_id,
        "senior_name": senior["name"],
        "checkin_id": checkin_id,
        "alert_id": alert_id,
        "alert_level": level,
        "summary": summary,
    }


# Follow-up timing.
NO_ANSWER_MINUTES = 10   # re-prompt this soon if the senior doesn't respond
LATER_MINUTES = 30       # re-prompt this soon after they vote "I'll take it later"


def due_reminders(
    window_minutes: int = 30,
    max_followups: int = 4,
) -> list[dict]:
    """Return medication reminders to send right now (SGT). Each row has a
    `kind` of 'initial' or 'followup'.

    - initial: reminder_time has arrived (within window_minutes) and we haven't
      started today's cycle yet.
    - followup: today's cycle started, the senior hasn't responded, fewer than
      max_followups follow-ups have gone out, and the per-alarm next_prompt_at
      time has been reached (10 min after no answer, 30 min after a "later" vote).
    """
    now = datetime.now(SGT)
    today = now.date()
    now_minutes = now.hour * 60 + now.minute

    out: list[dict] = []
    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT a.id AS alarm_id, a.time, a.last_reminded_on, a.last_reminded_at,
                       a.next_prompt_at, a.followups, a.acknowledged,
                       m.id AS med_id, m.name, m.dose, m.photo, m.photo_mime,
                       s.id AS senior_id, s.name AS senior_name, s.phone
                  FROM medication_alarms a
                  JOIN medications m ON m.id = a.medication_id
                  JOIN seniors s ON s.id = m.senior_id
                 WHERE a.enabled = TRUE
                   AND s.phone IS NOT NULL
                """
            )
            for row in cur.fetchall():
                try:
                    hh, mm = row["time"].split(":")
                    rem_minutes = int(hh) * 60 + int(mm)
                except Exception:
                    continue

                cycle_started_today = row["last_reminded_on"] == today

                if not cycle_started_today:
                    delta = now_minutes - rem_minutes
                    if 0 <= delta <= window_minutes:
                        out.append({**row, "kind": "initial"})
                elif not row["acknowledged"] and (row["followups"] or 0) < max_followups:
                    # When the next prompt is due (set explicitly by the last send
                    # or the "later" vote). Fall back for older rows.
                    due_at = row["next_prompt_at"]
                    if due_at is None and row["last_reminded_at"] is not None:
                        due_at = row["last_reminded_at"] + timedelta(minutes=NO_ANSWER_MINUTES)
                    if due_at is not None and now >= due_at:
                        out.append({**row, "kind": "followup"})
    return out


def mark_reminded(alarm_id: int, kind: str = "initial") -> None:
    now = datetime.now(SGT)
    today = now.date()
    # After any prompt, the default next prompt is the no-answer interval (10 min).
    next_prompt = now + timedelta(minutes=NO_ANSWER_MINUTES)
    with _connect() as conn:
        with conn.cursor() as cur:
            if kind == "initial":
                cur.execute(
                    """
                    UPDATE medication_alarms
                       SET last_reminded_on = %s,
                           last_reminded_at = %s,
                           next_prompt_at = %s,
                           followups = 0,
                           acknowledged = FALSE
                     WHERE id = %s
                    """,
                    (today, now, next_prompt, alarm_id),
                )
            else:  # followup
                cur.execute(
                    """
                    UPDATE medication_alarms
                       SET last_reminded_at = %s,
                           next_prompt_at = %s,
                           followups = followups + 1
                     WHERE id = %s
                    """,
                    (now, next_prompt, alarm_id),
                )


def acknowledge_reminders(cur, senior_id: str, *, taken: bool) -> None:
    """Stop follow-ups: mark today's pending alarms for this senior's medications
    as acknowledged once they respond. If they confirmed taking it, also flag the
    relevant medications as taken today."""
    today = datetime.now(SGT).date()
    cur.execute(
        """
        UPDATE medication_alarms a
           SET acknowledged = TRUE
          FROM medications m
         WHERE a.medication_id = m.id
           AND m.senior_id = %s
           AND a.last_reminded_on = %s
           AND a.acknowledged = FALSE
        """,
        (senior_id, today),
    )
    if taken:
        cur.execute(
            """
            UPDATE medications
               SET taken_today = TRUE
             WHERE senior_id = %s
               AND id IN (
                   SELECT medication_id FROM medication_alarms
                    WHERE last_reminded_on = %s
               )
            """,
            (senior_id, today),
        )


def due_wellness(window_minutes: int = 5) -> list[dict]:
    """Seniors whose daily wellness check-in is due now (SGT) and not yet sent today."""
    now = datetime.now(SGT)
    today = now.date()
    now_minutes = now.hour * 60 + now.minute

    out: list[dict] = []
    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, name, phone, preferred_check_in_time
                  FROM seniors
                 WHERE wellness_enabled = TRUE
                   AND phone IS NOT NULL
                   AND preferred_check_in_time IS NOT NULL
                   AND (last_wellness_on IS NULL OR last_wellness_on <> %s)
                """,
                (today,),
            )
            for row in cur.fetchall():
                try:
                    hh, mm = row["preferred_check_in_time"].split(":")
                    due_min = int(hh) * 60 + int(mm)
                except Exception:
                    continue
                delta = now_minutes - due_min
                if 0 <= delta <= window_minutes:
                    out.append(row)
    return out


def mark_wellness_sent(senior_id: str) -> None:
    today = datetime.now(SGT).date()
    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE seniors SET last_wellness_on = %s WHERE id = %s",
                (today, senior_id),
            )


def _senior_id_by_phone(cur, phone: str) -> str | None:
    cur.execute("SELECT id FROM seniors WHERE phone = %s", (phone,))
    r = cur.fetchone()
    return r["id"] if r else None


def _pending_med_names(cur, senior_id: str) -> list[str]:
    """Medicines this senior was reminded about today but hasn't acknowledged."""
    today = datetime.now(SGT).date()
    cur.execute(
        """
        SELECT DISTINCT m.name
          FROM medication_alarms a
          JOIN medications m ON m.id = a.medication_id
         WHERE m.senior_id = %s AND a.last_reminded_on = %s AND a.acknowledged = FALSE
        """,
        (senior_id, today),
    )
    return [r["name"] for r in cur.fetchall()]


def _insert_checkin(cur, senior_id, transcript, summary, sentiment, level, med_taken):
    cur.execute(
        """
        INSERT INTO checkins (
            senior_id, transcript, summary, sentiment_score,
            alert_level, risk_flags, language, source, medication_taken, created_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (senior_id, transcript, summary, sentiment, level, [], None, "reminder",
         med_taken, datetime.now(SGT)),
    )


def mark_poll_taken(phone: str) -> str | None:
    """Senior voted 'taken' on a reminder poll → acknowledge, mark taken, and
    log a check-in so it appears in the caregiver's history."""
    phone = normalize_phone(phone)
    with _connect() as conn:
        with conn.cursor() as cur:
            sid = _senior_id_by_phone(cur, phone)
            if sid:
                names = _pending_med_names(cur, sid)  # before acknowledging
                acknowledge_reminders(cur, sid, taken=True)
                label = ", ".join(names) if names else "their medication"
                _insert_checkin(
                    cur, sid,
                    "Replied 'Yes, I've taken it' to a medication reminder.",
                    f"Confirmed taking {label}. ✅", 0.8, "info", True,
                )
            return sid


def snooze_reminders(phone: str) -> str | None:
    """Senior voted 'later' → restart the follow-up timer (re-prompt soon),
    log a check-in, without acknowledging."""
    phone = normalize_phone(phone)
    now = datetime.now(SGT)
    today = now.date()
    with _connect() as conn:
        with conn.cursor() as cur:
            sid = _senior_id_by_phone(cur, phone)
            if sid:
                names = _pending_med_names(cur, sid)
                # "Later" → next prompt in 30 minutes (vs 10 for no answer).
                next_prompt = now + timedelta(minutes=LATER_MINUTES)
                cur.execute(
                    """
                    UPDATE medication_alarms a
                       SET last_reminded_at = %s, next_prompt_at = %s
                      FROM medications m
                     WHERE a.medication_id = m.id
                       AND m.senior_id = %s
                       AND a.last_reminded_on = %s
                       AND a.acknowledged = FALSE
                    """,
                    (now, next_prompt, sid, today),
                )
                label = ", ".join(names) if names else "their medication"
                _insert_checkin(
                    cur, sid,
                    "Replied 'I'll take it later' to a medication reminder.",
                    f"Said they'll take {label} later. ⏰", 0.6, "info", None,
                )
            return sid


def healthcheck() -> bool:
    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return True
    except Exception as e:  # noqa: BLE001
        print(f"[carevoice_db] healthcheck failed: {e}")
        return False
