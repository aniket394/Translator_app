import 'package:flutter/material.dart';
import 'dart:async';
import 'translate_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'cameraUI.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
 // <-- for kIsWeb

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}

// ==========================================================
//                       SPLASH SCREEN
// ==========================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animCtrl;
  late Animation<double> fadeAnim;

  @override
  void initState() {
    super.initState();
    animCtrl = AnimationController(vsync: this, duration: Duration(seconds: 2));
    fadeAnim = CurvedAnimation(parent: animCtrl, curve: Curves.easeIn);
    animCtrl.forward();

    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeContainer()),
      );
    });
  }

  @override
  void dispose() {
    animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1C1D1D),
      body: Center(
        child: FadeTransition(
          opacity: fadeAnim,
          child: Image.asset('assets/Tr.png', height: 300),
        ),
      ),
    );
  }
}

// ==========================================================
//         MAIN CONTAINER → Handles Bottom Navigation
// ==========================================================

class HomeContainer extends StatefulWidget {
  const HomeContainer({super.key});

  @override
  _HomeContainerState createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> {
  int _selectedBottomIndex = 1;

  List<Widget> get screens => [
    const FilesScreen(), // Updated for file picker + translation
    const SplashscreenUI(),
    const CameraScreenUI(),
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _autoDiscoverServer();
    }
  }

  /// Automatically find the Python server on the network
  Future<void> _autoDiscoverServer() async {
    try {
      print("📡 Searching for Python server...");
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        socket.broadcastEnabled = true;
        // Send discovery packet
        List<int> data = utf8.encode("DISCOVER_SERVER");
        socket.send(data, InternetAddress("255.255.255.255"), 5005);

        socket.listen((RawSocketEvent e) {
          if (e == RawSocketEvent.read) {
            Datagram? d = socket.receive();
            if (d != null) {
              String message = utf8.decode(d.data).trim();
              if (message.startsWith("SERVER_IP:")) {
                String ip = message.split(":")[1];
                setState(() {
                  TranslatorService.baseUrl = "http://$ip:5000";
                });
                print("✅ Auto-connected to Server: $ip");
                socket.close();
              }
            }
          }
        });
      });
    } catch (e) {
      print("Auto-discovery failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color(0xff0f1b1e);

    return Scaffold(
      backgroundColor: bg,
      body: screens[_selectedBottomIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: bg,
        currentIndex: _selectedBottomIndex,
        onTap: (i) => setState(() => _selectedBottomIndex = i),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_file),
            label: "Files",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.text_fields), label: "Text"),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: "Camera",
          ),
        ],
      ),
    );
  }
}

// ==========================================================
//                       FILES SCREEN (Web + Android/iOS)
// ==========================================================

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  _FilesScreenState createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String fileName = "";
  String output = "";
  bool loading = false;

  final Map<String, String> langCode = {
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

  String toLang = "Marathi"; // default translation language

  Future<void> pickAndTranslateFile() async {
    setState(() {
      output = "";
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: kIsWeb, // important for Web
    );
    if (result == null) return; // user cancelled

    setState(() {
      loading = true;
    });

    try {
      final target = langCode[toLang] ?? "hi";

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${TranslatorService.baseUrl}/file_translate"),
      );

      if (kIsWeb) {
        // Web: use bytes
        final bytes = result.files.single.bytes!;
        request.files.add(
          http.MultipartFile.fromBytes(
            "file",
            bytes,
            filename: result.files.single.name,
          ),
        );
      } else {
        // Android/iOS: use File path
        final file = File(result.files.single.path!);
        request.files.add(await http.MultipartFile.fromPath("file", file.path));
      }

      request.fields['target_lang'] = target;

      var response = await request.send();

      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        var data = jsonDecode(respStr);
        setState(() {
          output = data['translated_text'] ?? "No translation found";
          fileName = result.files.single.name;
          loading = false;
        });
      } else {
        setState(() {
          output = "Error: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        output = "Error: $e";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color(0xff0f1b1e);

    return Scaffold(
      backgroundColor: bg,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.attach_file),
              label: Text(
                "Pick & Translate File",
                style: TextStyle(fontSize: 18),
              ),
              onPressed: pickAndTranslateFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            SizedBox(height: 20),
            if (fileName.isNotEmpty)
              Text(
                "Selected File: $fileName",
                style: TextStyle(color: Colors.white),
              ),
            SizedBox(height: 20),
            if (loading) CircularProgressIndicator(),
            if (output.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xff113033),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(output, style: TextStyle(color: Colors.white)),
              ),
            SizedBox(height: 20),
            // Language selector
            DropdownButton<String>(
              value: toLang,
              dropdownColor: bg,
              style: TextStyle(color: Colors.white),
              onChanged: (value) {
                if (value != null) setState(() => toLang = value);
              },
              items: langCode.keys
                  .map(
                    (lang) => DropdownMenuItem(value: lang, child: Text(lang)),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
//                      CAMERA SCREEN
// ==========================================================

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff0f1b1e),
      body: Center(
        child: Text(
          "Camera Screen",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),
    );
  }
}

// ==========================================================
//                  MAIN TRANSLATOR (TEXT) SCREEN
// ==========================================================

class SplashscreenUI extends StatefulWidget {
  const SplashscreenUI({super.key});

  @override
  _SplashscreenUIState createState() => _SplashscreenUIState();
}

class _SplashscreenUIState extends State<SplashscreenUI> {
  final TranslatorService translator = TranslatorService();

  final List<String> languages = [
    "English",
    "Hindi",
    "Marathi",
    "Tamil",
    "Telugu",
    "Kannada",
    "Gujarati",
    "Punjabi",
    "Malayalam",
    "Bengali",
    "Odia",
    "Assamese",
    "Urdu",
    "Chinese",
    "Japanese",
    "Spanish",
  ];

  final Map<String, String> flags = {
    "English": "🇬🇧",
    "Hindi": "🇮🇳",
    "Marathi": "🇮🇳",
    "Tamil": "🇮🇳",
    "Telugu": "🇮🇳",
    "Kannada": "🇮🇳",
    "Gujarati": "🇮🇳",
    "Punjabi": "🇮🇳",
    "Malayalam": "🇮🇳",
    "Bengali": "🇮🇳",
    "Odia": "🇮🇳",
    "Assamese": "🇮🇳",
    "Urdu": "🇵🇰",
    "Chinese": "🇨🇳",
    "Japanese": "🇯🇵",
    "Spanish": "🇪🇸",
  };

  String fromLang = "English";
  String toLang = "Marathi";

  TextEditingController input = TextEditingController();
  String output = "";

  Map<String, String> langCode = {
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

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _openLanguagePicker({required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xff0b1416),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Container(
          height: 380,
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: languages.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade800, height: 1),
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final selected = (isFrom ? fromLang : toLang) == lang;
                    return ListTile(
                      onTap: () {
                        setState(() {
                          if (isFrom) {
                            fromLang = lang;
                          } else {
                            toLang = lang;
                          }
                        });
                        Navigator.pop(context);
                      },
                      leading: Text(
                        flags[lang] ?? "🌐",
                        style: TextStyle(fontSize: 20),
                      ),
                      title: Text(lang, style: TextStyle(color: Colors.white)),
                      trailing: selected
                          ? Icon(Icons.check, color: Colors.green)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _langPill(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color(0xff12292b),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flags[text] ?? "🌐", style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text(text, style: TextStyle(color: Colors.white, fontSize: 14)),
            SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> doTranslate() async {
    final text = input.text.trim();
    if (text.isEmpty) {
      setState(() => output = "Please enter text!");
      return;
    }
    final target = langCode[toLang] ?? "hi";
    setState(() => output = "Translating...");
    final result = await translator.translateText(text, target);
    setState(() => output = result);
  }

  Future<void> doVoiceTranslate() async {
    final target = langCode[toLang] ?? "hi";
    setState(() {
      output = "Listening... Speak now";
    });

    try {
      final url = Uri.parse(
        '${TranslatorService.baseUrl}/voice_translate?target_lang=$target',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          input.text = data["original_text"] ?? "";
          output = data["translated_text"] ?? "";
        });
      } else {
        setState(() => output = "Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => output = "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color(0xff0f1b1e);
    final card = Color(0xff12292b);
    final panel = Color(0xff0f2629);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Language Translator",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _langPill(
                    fromLang,
                    () => _openLanguagePicker(isFrom: true),
                  ),
                ),
                SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      final t = fromLang;
                      fromLang = toLang;
                      toLang = t;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: card,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.swap_horiz, color: Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _langPill(
                    toLang,
                    () => _openLanguagePicker(isFrom: false),
                  ),
                ),
              ],
            ),
            SizedBox(height: 25),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.all(14),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 80, maxHeight: 160),
                    child: TextField(
                      controller: input,
                      maxLines: null,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "Type or speak here...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: card,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.mic, color: Colors.white),
                          onPressed: doVoiceTranslate,
                        ),
                      ),
                      Spacer(),
                      ElevatedButton(
                        onPressed: doTranslate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text("Translate"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            if (output.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Color(0xff113033),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(output, style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
