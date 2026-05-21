"""
SeniorCare WhatsApp Chatbot Backend
Handles incoming messages and transcribes voice messages using Whisper
Now with Gemini AI for natural conversations
"""

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
import requests
import base64
import json
import os

# Add Gemini imports
import google.generativeai as genai
from dotenv import load_dotenv

app = FastAPI(title="SeniorCare WhatsApp Chatbot")

# Configuration
EVOLUTION_URL = "http://evolution:8080"
EVOLUTION_API_KEY = "supersecretkey123"
WHISPER_URL = "http://whisper:8001" 
INSTANCE_NAME = "seniorcare"

load_dotenv()
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))

model = genai.GenerativeModel("gemini-2.5-flash")


def get_ai_reply(transcribed_text: str) -> str:
    """Get AI response from Gemini"""
    system_prompt = """You are a caring AI companion for seniors living alone.
Your name is SeniorCare Assistant.
You help seniors with:
- Medication reminders
- Daily wellness check-ins  
- Emergency assistance (SOS)

Be warm, patient, and concise.
Use simple language that seniors can understand.
Keep responses short (1-2 sentences).

IMPORTANT:
- If they say "help me", "I fell", or mention an emergency, immediately say you are alerting their caregiver.
- If they confirm taking medication, acknowledge and thank them.
- If they say they will take it later, say you will remind them again.
- If they express feeling unwell, show concern and offer to contact their caregiver.

Speak in a friendly, caring tone like a family member would."""

    prompt = f"{system_prompt}\n\nSenior says: {transcribed_text}"
    response = model.generate_content(prompt)
    return response.text


@app.get("/")
async def root():
    return {"message": "SeniorCare WhatsApp Chatbot Backend is running"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.post("/webhook")
async def webhook(request: Request):
    """
    Receive incoming messages from Evolution API
    Handles text messages and voice messages (transcription)
    """
    try:
        data = await request.json()
        
        # Log received message
        print(f"Received webhook: {json.dumps(data, indent=2)}")
        
        # Message is directly in data["data"]
        if "data" in data:
            message = data["data"]
            await handle_message(message)
        
        return {"status": "success"}
    
    except Exception as e:
        print(f"Error processing webhook: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def handle_message(message: dict):
    """Process incoming message"""
    
    # Get message type
    msg_type = message.get("type")
    from_number = message.get("key", {}).get("remoteJid")  # Sender's number
    message_id = message.get("key", {}).get("id")  # Message ID for audio download
    
    print(f"Processing message from {from_number}, type: {msg_type}, id: {message_id}")
    
    message_content = message.get("message", {})
    
    if msg_type == "텍스트" or "textMessage" in message_content:
        # Handle text message
        text = message_content.get("textMessage", {}).get("text")
        await handle_text_message(from_number, text)
    
    elif msg_type == "audio" or "audioMessage" in message_content:
        # Handle voice message - transcribe it
        print("Voice message detected - transcribing...")
        
        if message_id:
            text = await transcribe_voice_message(message_id)
            print(f"Transcribed text: {text}")
            await handle_text_message(from_number, text, is_voice=True)
        else:
            await send_message(from_number, "Sorry, I couldn't process your voice message.")


async def transcribe_voice_message(message_id: str) -> str:
    """Get audio from Evolution API and transcribe to text using Whisper"""
    
    try:
        # Get audio from Evolution API using message ID
        print(f"Downloading audio from Evolution API: {message_id}")
        
        body = {
            "message": {
                "key": {
                    "id": message_id
                }
            },
            "convertToMp4": False
        }
        
        response = requests.post(
            f"{EVOLUTION_URL}/chat/getBase64FromMediaMessage/{INSTANCE_NAME}",
            json=body,
            headers={"apikey": EVOLUTION_API_KEY},
            timeout=30
        )
        
        if response.status_code in [200, 201]:
            result = response.json()
            print(f"Got audio from Evolution: {result.get('mimetype', 'unknown')}")
            
            # Get base64 audio data
            audio_base64 = result.get("base64")
            
            if not audio_base64:
                raise Exception("No base64 data in response")
            
            # Send to Whisper service
            print("Sending to Whisper for transcription...")
            whisper_response = requests.post(
                f"{WHISPER_URL}/transcribe_bytes",
                json={"base64_audio": audio_base64},
                timeout=120  # 120 second timeout for transcription
            )
            
            if whisper_response.status_code == 200:
                transcription = whisper_response.json()
                text = transcription.get("text", "")
                print(f"Transcription result: '{text}'")
                return text
            else:
                raise Exception(f"Whisper failed: {whisper_response.status_code} - {whisper_response.text}")
        else:
            raise Exception(f"Failed to get audio from Evolution: {response.status_code} - {response.text}")
    
    except Exception as e:
        print(f"Transcription error: {e}")
        return f"Error transcribing audio: {str(e)}"


async def handle_text_message(from_number: str, text: str, is_voice: bool = False):
    """Process text message and send AI response"""
    
    # Remove @c.us or @s.whatsapp.net suffix if present
    phone_number = from_number.replace("@c.us", "").replace("@s.whatsapp.net", "")
    
    print(f"Processing text: {text}")
    
    # Get AI response from Gemini
    print("Getting AI reply from Gemini...")
    response_text = get_ai_reply(text)
    print(f"AI reply: {response_text}")
    
    await send_message(phone_number, response_text)


async def send_message(phone_number: str, message: str):
    """Send WhatsApp text message via Evolution API"""
    
    body = {
        "number": phone_number,
        "text": message
    }
    
    print(f"Sending message to {phone_number}: {message}")
    
    response = requests.post(
        f"{EVOLUTION_URL}/message/sendText/{INSTANCE_NAME}",
        json=body,
        headers={"apikey": EVOLUTION_API_KEY},
        timeout=30
    )
    
    if response.status_code == 200:
        print("Message sent successfully")
    else:
        print(f"Failed to send message: {response.status_code} - {response.text}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)