import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:videosdk/src/utils/constants.dart';

class VideoSDKLog {
  static String? meetingId;
  static String? sessionId;
  static String? peerId;
  static var logsConfig;
  static String? jwtKey;
  static Map<String, dynamic>? deviceInfo;
  static bool? debugMode;


  static createLog(
      {required String message, required String logLevel, Map? attributes, bool? dashboardLog }) {
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
              "logType": logLevel,
              "attributes": {
                "SDK": "flutter",
                "SDK_VERSION" : sdkVersion,
                "roomId": meetingId,
                "peerId": peerId,  
                "sessionId" : sessionId,
                ...?deviceInfo,
                ...?attributes,
              },
              "dashboardLog" : dashboardLog,
              "debugMode" : debugMode
            }));
      }
    } catch (error) {
    }
  }
}
