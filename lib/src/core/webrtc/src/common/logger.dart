import 'dart:developer';

const String APP_NAME = 'videosdk-client';

typedef void LoggerDebug(dynamic message);

class Logger {
  final String? _prefix;

  late LoggerDebug debug;
  late LoggerDebug warn;
  late LoggerDebug error;

  Logger(this._prefix) {
    if (_prefix != null) {
      debug = (dynamic message) {
        log('$APP_NAME:$_prefix $message');
      };
      warn = (dynamic message) {
        log('$APP_NAME:WARN:$_prefix $message');
      };
      error = (dynamic message) {
        log('$APP_NAME:ERROR:$_prefix $message');
      };
    } else {
      debug = (dynamic message) {
        log('$APP_NAME $message');
      };
      warn = (dynamic message) {
        log('$APP_NAME:WARN $message');
      };
      error = (dynamic message) {
        log('$APP_NAME:ERROR $message');
      };
    }
  }
}
