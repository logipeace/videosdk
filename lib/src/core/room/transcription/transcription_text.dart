class TranscriptionText {
  late final String? _participantId;
  late final String? _participantName;
  late final String? _text;
  late final int? _timestamp;
  late final String? _type;

  TranscriptionText(
      {String? participantId,
      String? participantName,
      String? text,
      int? timestamp,
      String? type}) {
    _participantId = participantId;
    _participantName = participantName;
    _text = text;
    _timestamp = timestamp;
    _type = type;
  }

  // Getter methods
  String? get participantId => _participantId;

  String? get participantName => _participantName;

  String? get text => _text;

  int? get timestamp => _timestamp;

  String? get type => _type;

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'participantName': participantName,
      'text': text,
      'timestamp': timestamp,
      'type': type
    };
  }
}
