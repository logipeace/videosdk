class CharacterMessage {
  CharacterMessage({
    required this.text,
    required this.characterId,
    required this.characterName,
    required this.timestamp,
  });

  String text;
  String characterId;
  String characterName;
  int timestamp;

  factory CharacterMessage.fromJson(Map<String, dynamic> json) =>
      CharacterMessage(
        text: json["text"],
        characterId: json["characterId"],
        characterName: json["characterName"],
        timestamp: json["timestamp"],
      );

  Map<String, dynamic> toJson() => {
        "text": text,
        "characterId": characterId,
        "characterName": characterName,
        "timestamp": timestamp,
      };
}
