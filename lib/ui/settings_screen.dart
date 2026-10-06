import 'package:flutter/material.dart';

import '../data/chat_controller.dart';
import '../data/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final ChatController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _orKey, _orModel, _gqKey, _gqModel, _prompt;
  bool _showKeys = false;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _orKey = TextEditingController(text: s.openRouterKey);
    _orModel = TextEditingController(text: s.openRouterModel);
    _gqKey = TextEditingController(text: s.groqKey);
    _gqModel = TextEditingController(text: s.groqModel);
    _prompt = TextEditingController(text: s.systemPrompt);
  }

  @override
  void dispose() {
    for (final t in [_orKey, _orModel, _gqKey, _gqModel, _prompt]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await widget.controller.saveSettings(AppSettings(
      openRouterKey: _orKey.text.trim(),
      openRouterModel: _orModel.text.trim().isEmpty
          ? AppSettings.defaultOpenRouterModel
          : _orModel.text.trim(),
      groqKey: _gqKey.text.trim(),
      groqModel: _gqModel.text.trim().isEmpty
          ? AppSettings.defaultGroqModel
          : _gqModel.text.trim(),
      systemPrompt: _prompt.text,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Widget _field(String label, TextEditingController c,
      {bool secret = false, int lines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: secret && !_showKeys,
        maxLines: secret ? 1 : lines,
        minLines: 1,
        autocorrect: false,
        enableSuggestions: !secret,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), actions: [
        TextButton(onPressed: _save, child: const Text('Save')),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Replies try OpenRouter first, then Groq. Keys are stored in '
              'the Android Keystore on this phone and only sent to those providers.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          Text('OpenRouter (primary)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _field('API key', _orKey, secret: true),
          _field('Model', _orModel),
          Text('Groq (fallback)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _field('API key', _gqKey, secret: true),
          _field('Model', _gqModel),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show keys'),
            value: _showKeys,
            onChanged: (v) => setState(() => _showKeys = v),
          ),
          const SizedBox(height: 8),
          Text('On-device model', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Not installed yet. It will be the last fallback in a later stage.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          _field('System prompt', _prompt, lines: 6),
        ],
      ),
    );
  }
}
