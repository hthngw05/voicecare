# CareVoice backend

FastAPI + PostgreSQL (via SQLAlchemy 2 / psycopg 3) backend for the CareVoice
Flutter app.

## 1. Prerequisites

- Python 3.11+
- A running PostgreSQL 14+ instance

Create a database and role:

```sql
CREATE ROLE carevoice WITH LOGIN PASSWORD 'carevoice';
CREATE DATABASE carevoice OWNER carevoice;
```

## 2. Setup

```powershell
cd C:\Users\bryan\Downloads\flutter\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env       # edit DATABASE_URL if your Postgres isn't local
```

## 3. Seed sample data

This creates the tables and inserts the same 4 seniors + 6 alerts the Flutter
app was using as hardcoded data:

```powershell
python -m app.seed
```

Re-running `seed.py` wipes and re-creates the data — safe for dev.

## 4. Run

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open <http://localhost:8000/docs> for the Swagger UI.

## 5. Point the Flutter app at it

- **Android emulator:** the host machine's `localhost` is `10.0.2.2` from
  inside the emulator. The Flutter app defaults to `http://10.0.2.2:8000`.
- **Physical phone on the same Wi-Fi:** find your PC's LAN IP (`ipconfig`)
  and override the base URL — see `lib/api/api_config.dart` in the Flutter
  project.
- **iOS simulator / desktop / web:** use `http://localhost:8000`.

## Endpoints

| Method | Path                       | Purpose                       |
|--------|----------------------------|-------------------------------|
| GET    | `/api/seniors`             | List all seniors (with status)|
| GET    | `/api/seniors/{id}`        | Full senior profile           |
| POST   | `/api/alerts/{id}/ack`     | Acknowledge an alert          |
| GET    | `/api/alerts`              | Alert history (filter `state=active\|resolved`) |
| GET    | `/healthz`                 | Liveness                      |
