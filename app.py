from flask import Flask, request, jsonify
from flask_cors import CORS
from deep_translator import GoogleTranslator
import speech_recognition as sr
import sounddevice as sd
import numpy as np
import os  
import docx      # For reading .docx
import PyPDF2    # For reading .pdf
from PIL import Image, ImageOps, ImageEnhance
import pytesseract
import shutil
import socket
import threading

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# -------------------------------------------------------------------------
# WINDOWS CONFIGURATION: Check Tesseract Path
# -------------------------------------------------------------------------
possible_path = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

if os.path.exists(possible_path):
    pytesseract.pytesseract.tesseract_cmd = possible_path
    print(f"✅ Tesseract found at: {possible_path}")
elif shutil.which("tesseract"):
    print("✅ Tesseract found in system PATH.")
else:
    print("❌ CRITICAL WARNING: Tesseract-OCR not found! Image translation will fail.")
    print("   Please install it from: https://github.com/UB-Mannheim/tesseract/wiki")
# -------------------------------------------------------------------------

# Initialize recognizer
recognizer = sr.Recognizer()
fs = 16000  # Sample rate
duration = 5  # Seconds to record for voice input

# Optional: Language codes
lang_codes = {
    "English": "en",
    "Hindi": "hi",
    "Marathi": "mr",
    "Tamil": "ta",
    "Telugu": "te",
    "Kannada": "kn",
    "Gujarati": "gu",
    "Punjabi": "pa",
    "Malayalam": "ml",
    "Bengali": "bn",
    "Odia": "or",
    "Assamese": "as",
    "Urdu": "ur",
    "Chinese": "zh",
    "Japanese": "ja",
    "Spanish": "es",
}

# ==================================================
# FILE UPLOAD SETUP
# ==================================================
UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route("/upload_file", methods=["POST"])
def upload_file():
    try:
        if "file" not in request.files:
            return jsonify({"error": "No file found"}), 400

        file = request.files["file"]
        if file.filename == "":
            return jsonify({"error": "No selected file"}), 400

        file_path = os.path.join(UPLOAD_FOLDER, file.filename)
        file.save(file_path)

        return jsonify({
            "message": "File uploaded successfully",
            "file_name": file.filename,
            "saved_at": file_path
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==================================================
# NEW ENDPOINT: FILE TRANSLATE
# ==================================================
@app.route("/file_translate", methods=["POST"])
def file_translate():
    try:
        if "file" not in request.files:
            return jsonify({"error": "No file found"}), 400

        file = request.files["file"]
        target_lang = request.form.get("target_lang", "hi")  # default Hindi

        if file.filename == "":
            return jsonify({"error": "No selected file"}), 400

        text_content = ""

        # ------------------
        # TXT files
        # ------------------
        if file.filename.endswith(".txt"):
            text_content = file.read().decode("utf-8")

        # ------------------
        # DOCX files
        # ------------------
        elif file.filename.endswith(".docx"):
            doc = docx.Document(file)
            for para in doc.paragraphs:
                text_content += para.text + "\n"

        # ------------------
        # PDF files
        # ------------------
        elif file.filename.endswith(".pdf"):
            pdf_reader = PyPDF2.PdfReader(file)
            for page in pdf_reader.pages:
                page_text = page.extract_text()
                if page_text:
                    text_content += page_text + "\n"

        # ------------------
        # Image files
        # ------------------
        elif file.filename.lower().endswith((".png", ".jpg", ".jpeg")):
            try:
                image = Image.open(file)

                # 1. Fix orientation (crucial for mobile photos)
                image = ImageOps.exif_transpose(image) or image

                # 2. Preprocessing for better OCR accuracy
                image = ImageOps.grayscale(image)            # Convert to grayscale
                enhancer = ImageEnhance.Contrast(image)
                image = enhancer.enhance(2.0)                # Increase contrast

                text_content = pytesseract.image_to_string(image)
            except Exception as e:
                print(f"❌ OCR Error: {e}")
                return jsonify({"error": f"OCR failed: {str(e)}. Is Tesseract installed?"}), 500

        else:
            return jsonify({"error": "Unsupported file type"}), 400

        # Check if text was extracted
        if not text_content.strip():
            return jsonify({"error": "No text extracted from file"}), 400

        # Translate the extracted text
        try:
            translated_text = GoogleTranslator(source="auto", target=target_lang).translate(text_content)
        except Exception as e:
            print(f"❌ Translation Error: {e}")
            return jsonify({"error": f"Translation API failed: {str(e)}"}), 500

        return jsonify({
            "original_text": text_content,
            "translated_text": translated_text
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ---------------------------
# Endpoint 1: Text translation
# ---------------------------
@app.route('/translate', methods=['POST'])
def translate_text():
    try:
        data = request.json
        text = data.get("text")
        target_lang = data.get("target_lang", "hi")

        if not text:
            return jsonify({"error": "No text provided"}), 400

        translated_text = GoogleTranslator(
            source='auto',
            target=target_lang
        ).translate(text)

        return jsonify({"translated_text": translated_text})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ----------------------------------------
# Endpoint 2: Voice input + translation
# ----------------------------------------
@app.route('/voice_translate', methods=['GET'])
def voice_translate():
    try:
        target_lang = request.args.get("target_lang", "hi")

        print("Recording audio...")
        audio = sd.rec(int(duration * fs), samplerate=fs, channels=1)
        sd.wait()
        audio = audio.flatten().astype(np.float32)
        audio_data = sr.AudioData((audio * 32767).astype(np.int16).tobytes(), fs, 2)

        try:
            text = recognizer.recognize_google(audio_data)
            print(f"Recognized text: {text}")
        except sr.UnknownValueError:
            return jsonify({"error": "Could not understand audio"}), 400
        except sr.RequestError as e:
            return jsonify({"error": f"Google API error: {str(e)}"}), 500

        translated_text = GoogleTranslator(
            source='auto',
            target=target_lang
        ).translate(text)

        return jsonify({
            "original_text": text,
            "translated_text": translated_text
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# -------------------------------------------------------------------------
# AUTO-DISCOVERY SERVICE
# -------------------------------------------------------------------------
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Connect to a dummy external IP to get the interface IP
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def start_discovery_service():
    def listen():
        udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        udp.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        try:
            udp.bind(('0.0.0.0', 5005))
            print("📡 Discovery Service: Listening on UDP 5005")
        except Exception as e:
            print(f"⚠️ Discovery Service bind failed (might be running already): {e}")
            return

        while True:
            try:
                data, addr = udp.recvfrom(1024)
                if data.decode('utf-8').strip() == "DISCOVER_SERVER":
                    local_ip = get_local_ip()
                    udp.sendto(f"SERVER_IP:{local_ip}".encode('utf-8'), addr)
            except Exception:
                pass
    
    t = threading.Thread(target=listen, daemon=True)
    t.start()

# ---------------------------
if __name__ == '__main__':
    start_discovery_service()
    print(f"\n✅ SERVER RUNNING at: {get_local_ip()}:5000\n")
    app.run(host='0.0.0.0', port=5000, debug=True)
