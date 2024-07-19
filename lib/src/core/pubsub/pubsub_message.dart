import 'dart:convert';

PubSubMessages pubSubMessagesFromJson(String str) =>
    PubSubMessages.fromJson(json.decode(str));

String pubSubMessagesToJson(PubSubMessages data) => json.encode(data.toJson());

class PubSubMessages {
  PubSubMessages({
    required this.messages,
  });

  late List<PubSubMessage> messages;

  factory PubSubMessages.fromJson(Map<String, dynamic> json) => PubSubMessages(
        messages: List<PubSubMessage>.from(
            json["messages"].map((x) => PubSubMessage.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "messages": List<dynamic>.from(messages.map((x) => x.toJson())),
      };
}

class PubSubMessage {
  PubSubMessage({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.topic,
    required this.payload
  });

  String id;
  String message;
  String senderId;
  String senderName;
  DateTime timestamp;
  String topic;
  Map<String,dynamic>? payload;

  factory PubSubMessage.fromJson(Map<String, dynamic> json) => PubSubMessage(
        id: json["id"],
        message: json["message"],
        senderId: json["senderId"],
        senderName: json["senderName"],
        timestamp: DateTime.parse(json["timestamp"]),
        topic: json["topic"],
        payload: json["payload"]
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "message": message,
        "senderId": senderId,
        "senderName": senderName,
        "timestamp": timestamp.toIso8601String(),
        "topic": topic,
        "payload": payload,
      };
}
