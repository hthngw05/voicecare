"""
Wellness analysis for a transcribed check-in.

Turns a piece of text (what the senior said) into a structured assessment:
    {
        "alert_level": "info" | "concern" | "urgent" | "emergency",
        "sentiment_score": 0.0 - 1.0,
        "summary": "one-line summary for the caregiver",
        "risk_flags": ["cannot_move", "low_mood", ...],
        "language": "english" | "hokkien" | "malay" | ... | None,
        "medication_taken": True | False | None,
    }

It uses a fast keyword/dialect matcher that always works offline, and will
optionally upgrade the result with Gemini if GOOGLE_API_KEY is configured.
"""
from __future__ import annotations

import json
import os
import re

ALERT_ORDER = {"info": 0, "concern": 1, "urgent": 2, "emergency": 3}

# Phrase -> (risk_flag, alert_level). Lower-cased substring match.
# Includes Singlish / Hokkien / Malay phrases from the project docs.
_PHRASE_RULES: list[tuple[str, str, str]] = [
    # --- Emergency: physical incapacity / life threatening ---
    ("cannot get out of bed", "cannot_move", "emergency"),
    ("cannot get up", "cannot_move", "emergency"),
    ("can't get up", "cannot_move", "emergency"),
    ("cannot move", "cannot_move", "emergency"),
    ("can't move", "cannot_move", "emergency"),
    ("i fell", "fall", "emergency"),
    ("i've fallen", "fall", "emergency"),
    ("fallen down", "fall", "emergency"),
    ("fell down", "fall", "emergency"),
    ("collapsed", "fall", "emergency"),
    ("help me", "distress", "emergency"),
    ("tolong", "distress", "emergency"),          # Malay: help
    ("chest pain", "severe_pain", "emergency"),
    ("cannot breathe", "medical_concern", "emergency"),
    ("can't breathe", "medical_concern", "emergency"),
    ("susah nak nafas", "medical_concern", "emergency"),  # Malay: hard to breathe
    ("heart attack", "medical_concern", "emergency"),
    ("stroke", "medical_concern", "emergency"),
    ("bleeding", "medical_concern", "emergency"),
    # --- Urgent: serious but not immediately life-threatening ---
    ("severe pain", "severe_pain", "urgent"),
    ("very pain", "severe_pain", "urgent"),
    ("a lot of pain", "severe_pain", "urgent"),
    ("fainted", "medical_concern", "urgent"),
    ("vomiting", "medical_concern", "urgent"),
    ("cannot make it", "distress", "urgent"),
    # --- Concern: low mood / mild medical / missed meds ---
    ("very sian", "low_mood", "concern"),
    ("sian", "low_mood", "concern"),              # Singlish/Hokkien: bored/down
    ("bo lat", "weakness", "concern"),            # Hokkien: no energy
    ("boh lat", "weakness", "concern"),
    ("very tired", "low_mood", "concern"),
    ("so tired", "low_mood", "concern"),
    ("didn't sleep", "low_mood", "concern"),
    ("din sleep", "low_mood", "concern"),
    ("cannot sleep", "low_mood", "concern"),
    ("lonely", "low_mood", "concern"),
    ("very sad", "low_mood", "concern"),
    ("sad", "low_mood", "concern"),
    ("no appetite", "medical_concern", "concern"),
    ("don't want to eat", "medical_concern", "concern"),
    ("giddy", "medical_concern", "concern"),
    ("dizzy", "medical_concern", "concern"),
    ("headache", "medical_concern", "concern"),
    ("fever", "medical_concern", "concern"),
    ("cough", "medical_concern", "concern"),
    ("not feeling well", "medical_concern", "concern"),
    ("unwell", "medical_concern", "concern"),
    ("not so good", "low_mood", "concern"),
    ("forgot to take", "medical_concern", "concern"),
    ("didn't take", "medical_concern", "concern"),
    ("never take my medicine", "medical_concern", "concern"),
]

# Standalone Hokkien "boh sai" (cannot/unable). When near bed/up/move -> emergency,
# otherwise treat as weakness/concern.
_POSITIVE_WORDS = [
    "good", "great", "fine", "okay", "ok", "well", "happy", "better",
    "wonderful", "fantastic", "bagus", "ho",  # Malay/Hokkien: good
]
_MED_TAKEN = ["took my medicine", "taken my medicine", "took medicine", "taken", "took it", "sudah makan ubat"]
_MED_MISSED = ["forgot to take", "didn't take", "haven't take", "haven't taken", "never take my medicine", "belum makan ubat"]

_LANG_HINTS = {
    "hokkien": ["boh sai", "bo lat", "boh lat", "wa ", "lah", "leh", "sian", "ho "],
    "malay": ["tolong", "saya", "tidak", "makan", "ubat", "bagus", "susah"],
    "tamil": ["vanakkam", "saapad", "illai"],
    "mandarin": ["wo ", "bu hao", "hen "],
}


def _detect_language(text: str) -> str | None:
    t = f" {text.lower()} "
    for lang, hints in _LANG_HINTS.items():
        if any(h in t for h in hints):
            return lang
    # Default to english if it's mostly ascii letters
    if re.search(r"[a-z]", t):
        return "english"
    return None


def _medication_taken(text: str) -> bool | None:
    t = text.lower()
    if any(p in t for p in _MED_MISSED):
        return False
    if any(p in t for p in _MED_TAKEN):
        return True
    return None


def keyword_analysis(text: str) -> dict:
    t = (text or "").lower().strip()
    flags: list[str] = []
    level = "info"

    for phrase, flag, lvl in _PHRASE_RULES:
        if phrase in t:
            if flag not in flags:
                flags.append(flag)
            if ALERT_ORDER[lvl] > ALERT_ORDER[level]:
                level = lvl

    # Special-case Hokkien "boh sai"
    if "boh sai" in t:
        if any(w in t for w in ["bed", "up", "move", "stand", "walk"]):
            if "cannot_move" not in flags:
                flags.append("cannot_move")
            level = "emergency"
        else:
            if "weakness" not in flags:
                flags.append("weakness")
            if ALERT_ORDER["concern"] > ALERT_ORDER[level]:
                level = "concern"

    has_positive = any(w in f" {t} " for w in _POSITIVE_WORDS)

    # Sentiment heuristic from the resolved level.
    sentiment = {
        "emergency": 0.15,
        "urgent": 0.30,
        "concern": 0.45,
        "info": 0.85 if has_positive else 0.65,
    }[level]

    summary = _build_summary(text, level, flags)

    return {
        "alert_level": level,
        "sentiment_score": round(sentiment, 2),
        "summary": summary,
        "risk_flags": flags,
        "language": _detect_language(text),
        "medication_taken": _medication_taken(text),
    }


def _build_summary(text: str, level: str, flags: list[str]) -> str:
    snippet = (text or "").strip()
    if len(snippet) > 90:
        snippet = snippet[:87] + "..."
    if level == "info":
        return snippet or "Check-in completed, no concerns."
    flag_label = ", ".join(f.replace("_", " ") for f in flags) or level
    return f'"{snippet}" — {flag_label} detected.'


# --------------------------------------------------------------------------
# Optional Gemini upgrade
# --------------------------------------------------------------------------
def _gemini_analysis(text: str) -> dict | None:
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        return None
    try:
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.5-flash")
        prompt = (
            "You analyze a wellness check-in from an elderly person living alone "
            "in Singapore (may use English, Singlish, Hokkien, Malay, Mandarin or Tamil).\n"
            "Return ONLY strict JSON with keys: "
            "alert_level (one of info, concern, urgent, emergency), "
            "sentiment_score (number 0.0-1.0, higher = happier/healthier), "
            "summary (one short sentence for the caregiver), "
            "risk_flags (array of short snake_case tags like cannot_move, low_mood, fall, "
            "medical_concern, severe_pain, weakness, distress), "
            "language (lowercase language name), "
            "medication_taken (true, false, or null).\n"
            "emergency = fall / cannot move / chest pain / cannot breathe / asks for help.\n\n"
            f"Senior said: {text!r}"
        )
        resp = model.generate_content(prompt)
        raw = (resp.text or "").strip()
        raw = re.sub(r"^```(json)?|```$", "", raw, flags=re.MULTILINE).strip()
        data = json.loads(raw)
        # Validate / coerce
        level = str(data.get("alert_level", "info")).lower()
        if level not in ALERT_ORDER:
            level = "info"
        return {
            "alert_level": level,
            "sentiment_score": float(data.get("sentiment_score", 0.5)),
            "summary": str(data.get("summary") or "").strip() or _build_summary(text, level, []),
            "risk_flags": [str(f) for f in (data.get("risk_flags") or [])],
            "language": (str(data["language"]).lower() if data.get("language") else _detect_language(text)),
            "medication_taken": data.get("medication_taken"),
        }
    except Exception as e:  # noqa: BLE001 - never let analysis crash the webhook
        print(f"[analysis] Gemini analysis failed, using keyword fallback: {e}")
        return None


def analyze(text: str, *, use_gemini: bool = True) -> dict:
    """Analyze a check-in. Tries Gemini (if configured) then falls back to
    the offline keyword matcher. Emergencies from the keyword matcher are
    never downgraded by Gemini."""
    base = keyword_analysis(text)
    if use_gemini:
        upgraded = _gemini_analysis(text)
        if upgraded is not None:
            # Keep the higher severity of the two so we never miss a clear emergency.
            if ALERT_ORDER[base["alert_level"]] > ALERT_ORDER[upgraded["alert_level"]]:
                upgraded["alert_level"] = base["alert_level"]
                upgraded["sentiment_score"] = min(upgraded["sentiment_score"], base["sentiment_score"])
                for f in base["risk_flags"]:
                    if f not in upgraded["risk_flags"]:
                        upgraded["risk_flags"].append(f)
            return upgraded
    return base
