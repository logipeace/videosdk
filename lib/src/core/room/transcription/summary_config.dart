class SummaryConfig {
  late final bool _enabled;
  late final String _prompt;

  SummaryConfig({required bool enabled, required String prompt}) {
    _enabled = enabled;
    _prompt = prompt;
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': _enabled,
      'prompt': _prompt,
    };
  }
}
