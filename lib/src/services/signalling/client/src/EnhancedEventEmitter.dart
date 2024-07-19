import 'dart:async';

import 'package:events2/events2.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';

import 'logger.dart';

Logger _logger = Logger('EnhancedEventEmitter');

class EnhancedEventEmitter extends EventEmitter {
  EnhancedEventEmitter() : super();
  void safeEmit(String event, [Map<String, dynamic>? args]) {
    try {
      emit(event, args);
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message:
              "safeEmit() event listener threw an error [event:$event] \n ${error.toString()}",
          logLevel: "ERROR");
      //
      _logger.error(
        'safeEmit() event listener threw an error [event:$event]:$error',
      );
    }
  }

  Future<dynamic> safeEmitAsFuture(String event,
      [Map<String, dynamic>? args]) async {
    try {
      return emitAsFuture(event, args);
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message:
              "safeEmitAsFuture() event listener threw an error [event:$event] \n ${error.toString()}",
          logLevel: "ERROR");
      //
      _logger.error(
        'safeEmitAsFuture() event listener threw an error [event:$event]:$error',
      );
    }
  }
}
