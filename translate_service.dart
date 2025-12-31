import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TranslatorService {
  // Use localhost for Flutter Web
  static String baseUrl = "http://127.0.0.1:5000";

  Future<String> translateText(String text, String targetLang) async {
    try {
      print("Sending to backend: $text → $targetLang"); // Debug print

      final response = await http.post(
        Uri.parse("$baseUrl/translate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text, "target_lang": targetLang}),
      );

      print(
        "Response status: ${response.statusCode}, body: ${response.body}",
      ); // Debug print

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["translated_text"] ?? "No translation found";
      } else {
        return "Error: ${response.statusCode}";
      }
    } catch (e) {
      print("Exception: $e");
      return "Error: $e";
    }
  }

  Future<Map<String, dynamic>> translateImage(File imageFile, String targetLang) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/file_translate"),
      );

      request.fields['target_lang'] = targetLang;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      return json.decode(responseData);
    } catch (e) {
      return {"error": "Connection failed: $e"};
    }
  }
}
