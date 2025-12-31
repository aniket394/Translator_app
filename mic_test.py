import speech_recognition as sr

recognizer = sr.Recognizer()

# List all available microphones
print("Available microphones:")
for i, name in enumerate(sr.Microphone.list_microphone_names()):
    print(f"{i}: {name}")

# You can set device_index if your headset mic is not default
mic_index = None  # None = default mic

with sr.Microphone(device_index=mic_index) as source:
    print("Adjusting for ambient noise, speak after this...")
    recognizer.adjust_for_ambient_noise(source, duration=1)
    audio = recognizer.listen(source, timeout=5, phrase_time_limit=10)

try:
    text = recognizer.recognize_google(audio)
    print("You said:", text)
except sr.UnknownValueError:
    print("Could not understand audio")
except sr.RequestError as e:
    print(f"Request error: {e}")
