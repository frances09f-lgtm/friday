class AppSettings {
  const AppSettings({
    this.openRouterKey = '',
    this.groqKey = '',
    this.openRouterModel = defaultOpenRouterModel,
    this.groqModel = defaultGroqModel,
    this.systemPrompt = defaultSystemPrompt,
  });

  static const defaultOpenRouterModel = 'openai/gpt-oss-120b:free';
  static const defaultGroqModel = 'llama-3.3-70b-versatile';
  static const defaultSystemPrompt =
      'You are Friday, a helpful personal assistant on the user\'s phone. '
      'Be concise and direct. Reply in the language the user writes in '
      '(English, Hindi or Marathi). If you do not know something, say so.';

  final String openRouterKey;
  final String groqKey;
  final String openRouterModel;
  final String groqModel;
  final String systemPrompt;

  AppSettings copyWith({
    String? openRouterKey,
    String? groqKey,
    String? openRouterModel,
    String? groqModel,
    String? systemPrompt,
  }) =>
      AppSettings(
        openRouterKey: openRouterKey ?? this.openRouterKey,
        groqKey: groqKey ?? this.groqKey,
        openRouterModel: openRouterModel ?? this.openRouterModel,
        groqModel: groqModel ?? this.groqModel,
        systemPrompt: systemPrompt ?? this.systemPrompt,
      );
}

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class MemorySettingsStore implements SettingsStore {
  AppSettings current = const AppSettings();
  @override
  Future<AppSettings> load() async => current;
  @override
  Future<void> save(AppSettings settings) async => current = settings;
}
