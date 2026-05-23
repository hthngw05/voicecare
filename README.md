# CareVoice

An AI **WhatsApp companion for seniors** + a **Flutter caregiver app**.

A senior sends a WhatsApp voice note or text → it's transcribed, analysed for
mood/risk, and stored → the caregiver sees live status, mood trends, alerts and
medication reminders in the app. All times are **Singapore time (UTC+8)**.

> **New here? Read [`SETUP.md`](SETUP.md)** — it walks through installing and
> running the whole system on a fresh machine, step by step.

## Architecture

```
                         ┌─────────────────────────────┐
   Senior's WhatsApp ───▶│ whatsapp-companion (Docker)  │
   (voice / text)        │  • Evolution API (WhatsApp)  │
                         │  • Whisper (speech-to-text)  │
                         │  • backend (FastAPI)         │
                         └───────────────┬──────────────┘
                                         │ writes check-ins / alerts
                                         ▼
                         ┌─────────────────────────────┐
                         │ PostgreSQL  (shared db)      │
                         └───────────────┬──────────────┘
                                         │ reads
                         ┌───────────────▼──────────────┐
   Caregiver's phone ───▶│ carevoice-api (FastAPI :8000)│
   (caregiver-app)       └──────────────────────────────┘
```

The two backends never call each other — they meet only at the shared
PostgreSQL `carevoice` database.

## Repository layout

| Folder                 | What it is                                                            |
|------------------------|-----------------------------------------------------------------------|
| `caregiver-app/`       | **Flutter caregiver app** — Home, Trends, Alerts, Community, Settings. |
| `carevoice-api/`       | **CareVoice API** (FastAPI, port 8000). The app talks only to this.    |
| `whatsapp-companion/`  | **WhatsApp companion** (Docker): Evolution API, Whisper, FastAPI backend, scheduler. |
| `SETUP.md`             | Full new-device setup guide.                                          |

## Quick start

```bash
# 1. PostgreSQL: create the carevoice database (see SETUP.md §3)
# 2. CareVoice API
cd carevoice-api && python -m venv .venv && . .venv/Scripts/activate
pip install -r requirements.txt && cp .env.example .env   # add your keys
python -m app.seed && uvicorn app.main:app --host 0.0.0.0 --port 8000
# 3. Flutter app
cd ../caregiver-app && flutter pub get && flutter run
# 4. (Optional) WhatsApp companion
cd ../whatsapp-companion && docker compose up -d
```

See [`SETUP.md`](SETUP.md) for prerequisites, configuration, the WhatsApp
companion, and troubleshooting.

## Tech stack

FastAPI · Flutter · PostgreSQL · Google Gemini (AI replies + OCR) ·
OpenAI Whisper (speech-to-text) · Evolution API (WhatsApp).
