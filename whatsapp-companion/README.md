# CareVoice

WhatsApp-based AI voice companion for seniors living alone.

## Features

- 🎤 Voice messages → AI responds naturally
- 💊 Medication reminders
- ❤️ Daily wellness check-ins
- 🚨 SOS emergency alerts ("help me")
- 📱 Caregiver dashboard (Flutter app)

## Tech Stack

- **Backend**: FastAPI (Python)
- **AI**: Google Gemini (FREE)
- **Speech-to-Text**: OpenAI Whisper
- **Database**: PostgreSQL
- **WhatsApp**: Evolution API
- **Frontend**: Flutter

## How to Run

### Prerequisites

- Docker Desktop installed
- Google AI Studio API key (FREE)

### Step 1: Get API Key

1. Go to https://aistudio.google.com
2. Sign in with Google account
3. Click "Get API key" → "Create API key"
4. Copy the key

### Step 2: Add API Key to docker-compose.yml

Open `docker-compose.yml` and add to `backend.environment`:

```yaml
- GOOGLE_API_KEY=AIzaSy...your_api_key_here
```

### Step 3: Start Docker Services

```bash
docker compose up -d
```

### Step 4: Test

Send a WhatsApp message to your CareVoice number:

- "Hello" → Bot greets you
- "taken" → Bot confirms medication
- "help me" → Bot alerts caregiver

## Troubleshooting

**Backend not responding?**
```bash
docker compose restart backend
```

**Check logs:**
```bash
docker compose logs backend
```
