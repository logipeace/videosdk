import 'dart:convert';
import 'dart:html';

import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';

import '../logger.dart';
import '../message.dart';
import 'TransportInterface.dart';

final _logger = Logger('Logger::WebTransport');

class Transport extends TransportInterface {
  late bool _closed;
  late String _url;
  late dynamic _options;
  WebSocket? _ws;

  Transport(String url, {dynamic options}) : super(url, options: options) {
    _logger.debug('constructor() [url:$url, options:$options]');
    this._closed = false;
    this._url = url;
    this._options = options ?? {};
    this._ws = null;

    this._runWebSocket();
  }

  get closed => _closed;

  @override
  close() {
    _logger.debug('close()');

    this._closed = true;
    this.safeEmit('close');

    try {
      this._ws?.close();
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message:
              "error in WebTransport :: closing the WebSocket \n ${error.toString()}",
          logLevel: "ERROR");
      //
      _logger.error('close() | error closing the WebSocket: $error');
    }
  }

  @override
  Future send(message) async {
    try {
      this._ws?.send(jsonEncode(message));
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in WebTransport :: send()-${jsonEncode(message)} \n ${error.toString()}",
          logLevel: "ERROR");
      //
      _logger.warn('send() failed:$error');
    }
  }

  _runWebSocket() {
    this._ws = new WebSocket(this._url, 'protoo');
    this._ws?.onOpen.listen((e) {
      _logger.debug('onOpen');
      this.safeEmit('open');
    });

    this._ws?.onClose.listen((e) {
      _logger.warn(
          'WebSocket "close" event [wasClean:${e.wasClean}, code:${e.code}, reason:"${e.reason}"]');
      this._closed = true;

      this.safeEmit('close');
    });

    this._ws?.onError.listen((e) {
      //
      VideoSDKLog.createLog(
          message: "Error in WebTransport :: error event \n ${e.toString()}",
          logLevel: "ERROR");
      //
      _logger.error('WebSocket "error" event');
    });

    this._ws?.onMessage.listen((e) {
      final message = Message.parse(e.data);

      if (message == null) return;

      this.safeEmit('message', message);
    });
  }
}
