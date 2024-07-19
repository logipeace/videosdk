import 'dart:convert';

import 'package:http/http.dart' as http;

class VideoSDKLog {
  static String? meetingId;
  static String? peerId;
  static var logsConfig;
  static String? jwtKey;

  static createLog(
      {required String message, required String logLevel, Map? attributes}) {
    try {
      if (meetingId == null ||
          peerId == null ||
          logsConfig == null ||
          jwtKey == null) {
        return;
      }
      if (logsConfig['enabled']) {
        http.post(Uri.parse(logsConfig['endPoint']),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': jwtKey!,
            },
            body: json.encode({
              "logText": message,
              "logLevel": logLevel,
              "attributes": {
                "SDK": "flutter",
                "roomId": meetingId,
                "customerId": peerId,  
                ...?attributes,
              }
            }));
      }
    } catch (error) {}
  }
}
