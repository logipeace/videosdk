class UserMessage {
  UserMessage({
    required this.text,
    required this.participantId,
    required this.participantName,
    required this.timestamp,
  });

  String text;
  String participantId;
  String participantName;
  int timestamp;

  factory UserMessage.fromJson(Map<String, dynamic> json) =>
      UserMessage(
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
