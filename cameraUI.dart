import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'translate_service.dart';

class CameraScreenUI extends StatefulWidget {
  const CameraScreenUI({super.key});

  @override
  _CameraScreenUIState createState() => _CameraScreenUIState();
}

class _CameraScreenUIState extends State<CameraScreenUI> {
  final Color bg = const Color(0xff0f1b1e);
  final Color card = const Color(0xff12292b);

  XFile? imageFile;
  final ImagePicker _picker = ImagePicker();
  String translatedText = "";
  bool loading = false;
  String selectedLang = "mr";

  final Map<String, String> languages = {
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
  };

  /// Pick image from camera
  Future<void> openCamera() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 60, // Reduce quality to 60% (much smaller file)
            maxWidth: 1200,   // Limit width to 1200px (faster OCR)
          );
      if (pickedFile != null) {
        setState(() {
          imageFile = pickedFile;
          translatedText = "";
          loading = true;
        });
        await sendToAPI(pickedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening camera: $e")),
      );
    }
  }

  /// Pick image from gallery (mobile & web)
  Future<void> openGallery() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 60, // Reduce quality to 60%
            maxWidth: 1200,   // Limit width to 1200px
          );
      if (pickedFile != null) {
        setState(() {
          imageFile = pickedFile;
          translatedText = "";
          loading = true;
        });
        await sendToAPI(pickedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening gallery: $e")),
      );
    }
  }

  /// Show dialog to update Server IP
  void _showSettingsDialog() {
    // Extract just the IP from the baseUrl for display
    TextEditingController ipController = TextEditingController(text: TranslatorService.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Server IP Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the IP shown in your Python terminal:"),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(hintText: "http://192.168.1.10:5000"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() => TranslatorService.baseUrl = ipController.text.trim());
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// Send image to translation API
  Future<void> sendToAPI(XFile file) async {
    try {
      var uri = Uri.parse("${TranslatorService.baseUrl}/file_translate");
      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        Uint8List bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      request.fields['target_lang'] = selectedLang;

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var data = jsonDecode(respStr);
        setState(() {
          translatedText = data['translated_text'] ?? "No translation found";
          loading = false;
        });
      } else {
        setState(() {
          translatedText = "Error: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        translatedText = "Error: $e";
        loading = false;
      });
    }
  }

  Widget _displayImage() {
    if (imageFile == null) {
      return const Icon(Icons.camera_alt, color: Colors.white, size: 80);
    }

    if (kIsWeb) {
      return Image.network(imageFile!.path, height: 150);
    } else {
      return Image.file(
        File(imageFile!.path),
        height: 150,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: const Text("Camera", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettingsDialog,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _displayImage(),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedLang,
                  dropdownColor: card,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: languages.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.value,
                      child: Text(entry.key),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedLang = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: openCamera,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Open Camera", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: openGallery,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Open Gallery", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            if (loading) const CircularProgressIndicator(),
            if (translatedText.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xff113033), borderRadius: BorderRadius.circular(12)),
                child: Text(translatedText, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}
