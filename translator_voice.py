from flask import Flask, request, jsonify
import speech_recognition as sr
from googletrans import Translator

app = Flask(__name__)

# Initialize recognizer and translator
recognizer = sr.Recognizer()
translator = Translator()

# Language codes
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

# Optional: Speech-to-text from microphone
def get_voice_input():
    with sr.Microphone() as source:
        print("Adjusting for ambient noise... Please wait.")
        recognizer.adjust_for_ambient_noise(source)
        print("Speak now:")
        audio = recognizer.listen(source)

    try:
        text = recognizer.recognize_google(audio)
        print(f"You said: {text}")
        return text
    except sr.UnknownValueError:
        return None
    except sr.RequestError:
        return None

# API endpoint for text translation
@app.route("/translate", methods=["POST"])
def translate_text():
    data = request.json
    text = data.get("text")
    target_lang = data.get("target_lang", "hi")  # default Hindi

    if not text:
        return jsonify({"error": "No text provided"}), 400

    try:
        translated = translator.translate(text, dest=target_lang)
        return jsonify({"translated_text": translated.text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Optional API endpoint for voice input + translation
@app.route("/voice_translate", methods=["GET"])
def voice_translate():
    text = get_voice_input()
    if not text:
        return jsonify({"error": "Could not recognize speech"}), 400
    
    target_lang = request.args.get("target_lang", "hi")
    try:
        translated = translator.translate(text, dest=target_lang)
        return jsonify({"original_text": text, "translated_text": translated.text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)
