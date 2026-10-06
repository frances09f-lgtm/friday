import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'settings.dart';

/// API keys and settings live in Android Keystore-backed secure storage.
class SecureSettingsStore implements SettingsStore {
  SecureSettingsStore([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  @override
  Future<AppSettings> load() async {
    const d = AppSettings();
    return AppSettings(
      openRouterKey: await _s.read(key: 'openrouter_key') ?? '',
      groqKey: await _s.read(key: 'groq_key') ?? '',
      openRouterModel: await _s.read(key: 'openrouter_model') ?? d.openRouterModel,
      groqModel: await _s.read(key: 'groq_model') ?? d.groqModel,
      systemPrompt: await _s.read(key: 'system_prompt') ?? d.systemPrompt,
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    await _s.write(key: 'openrouter_key', value: s.openRouterKey.trim());
    await _s.write(key: 'groq_key', value: s.groqKey.trim());
    await _s.write(key: 'openrouter_model', value: s.openRouterModel.trim());
    await _s.write(key: 'groq_model', value: s.groqModel.trim());
    await _s.write(key: 'system_prompt', value: s.systemPrompt);
  }
}
