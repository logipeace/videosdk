import 'dart:convert';

import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';

import 'logger.dart';
import 'utils.dart' as utils;

final logger = Logger('Message');

class Message {
  static JsonEncoder encoder = JsonEncoder();
  static JsonDecoder decoder = JsonDecoder();
  static Map<String, dynamic>? parse(dynamic raw) {
    var object;
    final message = Map<String, dynamic>();

    try {
      object = decoder.convert(raw);
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message:
              "error in Message :: parse() | invalid JSON \n ${error.toString()}",
          logLevel: "ERROR");

      //
      logger.error('parse() | invalid JSON: %s' + error.toString());

      return null;
    }

    // Request.
    if (object['request'] != null) {
      message['request'] = true;

      if (!(object['method'] is String)) {
        logger.failure('parse() | missing/invalid method field');
      }

      if (!(object['id'] is num)) {
        logger.failure('parse() | missing/invalid id field');
      }

      message['id'] = object['id'];
      message['method'] = object['method'];
      message['data'] = object['data'] ?? {};
    }
    // Response.
    else if (object['response'] != null) {
      message['response'] = true;
      if (!(object['id'] is num)) {
        logger.failure('parse() | missing/invalid id field');
      }

      message['id'] = object['id'];

      // Success.
      if (object['ok'] is bool) {
        message['ok'] = true;
        message['data'] = object['data'] ?? {};
      }
      // Error.
      else {
        message['errorCode'] = object['errorCode'];
        message['errorReason'] = object['errorReason'];
      }
    }
    // Notification.
    else if (object['notification'] != null) {
      message['notification'] = true;
      if (!(object['method'] is String)) {
        logger.failure('parse() | missing/invalid method field');
      }

      message['method'] = object['method'];
      message['data'] = object['data'] ?? {};
    }
    // Invalid.
    else {
      logger.failure('parse() | missing request/response field');
      return null;
    }

    return message;
  }

  static createRequest(method, data) {
    var requestObj = {
      'request': true,
      'id': utils.randomNumber,
      'method': method,
      'data': data ?? {}
    };
    return requestObj;
  }

  static createSuccessResponse(request, data) {
    var responseObj = {
      'response': true,
      'id': request['id'],
      'ok': true,
      'data': data ?? {}
    };

    return responseObj;
  }

  static createErrorResponse(request, errorCode, errorReason) {
    var responseObj = {
      'response': true,
      'id': request['id'],
      'errorCode': errorCode,
      'errorReason': errorReason
    };

    return responseObj;
  }

  static createNotification(method, data) {
    var notificationObj = {
      'notification': true,
      'method': method,
      'data ': data ?? {},
    };

    return notificationObj;
  }
}
