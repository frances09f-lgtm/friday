import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/chat_controller.dart';
import 'data/chat_engine.dart';
import 'data/conversation_store.dart';
import 'data/secure_settings_store.dart';
import 'ui/chat_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final controller = ChatController(
    store: FileConversationStore(File('${dir.path}/friday_conversations.json')),
    settingsStore: SecureSettingsStore(),
    engine: ChatEngine((s) => buildRouter(s)),
  );
  await controller.init();
  runApp(FridayApp(controller: controller));
}

class FridayApp extends StatelessWidget {
  const FridayApp({super.key, required this.controller});
  final ChatController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Friday',
        debugShowCheckedModeBanner: false,
        theme: fridayTheme(),
        home: ChatScreen(controller: controller),
      );
}
