class CharacterConfig {
  String? _characterId;
  String? _interactionId;
  String? _displayName;
  String? _characterRole;
  CharacterMode? _characterMode;
  Map<String, dynamic>? _metaData;

  CharacterConfig.newInteraction(
      {required String characterId,
      String? displayName,
      CharacterMode? characterMode,
      String? characterRole,
      String? interactionId,
      Map<String, dynamic>? metaData}) {
    _characterId = characterId;
    _displayName = displayName;
    _characterMode = characterMode;
    _characterRole = characterRole;
    _metaData = metaData;
    _interactionId = interactionId;
  }

  CharacterConfig.resumeInteraction({
    required String interactionId,
  }) {
    _interactionId = interactionId;
  }

  Map<String, dynamic> toJson() {
    return {
      'characterId': _characterId,
      'interactionId': _interactionId,
      'displayName': _displayName,
      'characterRole' : _characterRole,
      'characterMode': _characterMode?.name.toLowerCase(),
      'metaData': _metaData,
    };
  }
}

enum CharacterMode { TEXT, CO_PILOT, AUTO_PILOT, VISION_PILOT }

enum CharacterState {
  CHARACTER_SPEAKING,
  CHARACTER_THINKING,
  CHARACTER_LISTENING
}
