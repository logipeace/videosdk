class CharacterMessage {
  CharacterMessage({
    required this.text,
    required this.participantId,
    required this.participantName,
    required this.timestamp,
  });

  String text;
  String participantId;
  String participantName;
  int timestamp;

  factory CharacterMessage.fromJson(Map<String, dynamic> json) =>
      CharacterMessage(
        text: json["text"],
        participantId: json["participantId"],
        participantName: json["participantName"],
        timestamp: json["timestamp"],
      );

  Map<String, dynamic> toJson() => {
        "text": text,
        "participantId": participantId,
        "participantName": participantName,
        "timestamp": timestamp,
      };
}
