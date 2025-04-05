import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebSocket {
  final String peerId;
  final String meetingId;
  final String token;
  final String baseUrl;
  final String mode;

  late IO.Socket _socket;
  Function()? onOpen;

  Function()? onReconnection;
  Function()? onDisconnected;
  Function()? onClose;
  Function(
    dynamic request,
    dynamic accept,
    dynamic reject,
  )? onRequest; // request, accept, reject
  Function(dynamic notification)? onNotification;

  IO.Socket get socket => _socket;
  WebSocket({
    required this.peerId,
    required this.meetingId,
    required this.token,
    required this.baseUrl,
    required this.mode,
  }) {
    _socket = IO.io(
      "https://$baseUrl/?roomId=$meetingId&peerId=$peerId&secret=$token&mode=$mode&lib=socket",
      IO.OptionBuilder()
          .setQuery({
            'roomId': meetingId,
            'peerId': peerId,
            'secret': token,
            'mode': mode,
          })
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(5000)
          .build(),
    );
    _setupListeners();
    _socket.connect();
  }

  void _setupListeners() {
    _socket.on('connect', (_) {});

    _socket.on('connectionSuccess', (data) {
      onOpen?.call();
    });

    _socket.on('connect_error', (error) {});

    _socket.on('disconnect', (reason) {
      print("Disconnected: $reason");
      onDisconnected?.call();
    });

    _socket.io.on('reconnect_attempt', (_) {
      onReconnection?.call();
    });

    _socket.on('close', (_) {
      onClose?.call();
    });

    _socket.io.on('reconnect_failed', (_) {
      onClose?.call();
    });

    _socket.io.on(('reconnect'), (_) {});

    _socket.io.on('reconnect_error', (error) {});

    _socket.on('newConsumer', (data) {
      if (data is List && data.isNotEmpty) {
        var firstItem = data.first; // Access the first map in the list

        // Extract the acknowledgment function (assumed to be the last element)
        final ack = data.last is Function ? data.last as Function : null;

        onRequest?.call(
          firstItem, // Passing only the first item (expected to be a Map)
          (responseData) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': true,
              'data': responseData,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
          (errorCode, errorReason) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': false,
              'errorCode': errorCode,
              'errorReason': errorReason,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
        );
      }
    });
    _socket.on('enableMic', (data) {
      if (data is List && data.isNotEmpty) {
        var firstItem = data.first; // Access the first map in the list

        // Extract the acknowledgment function (assumed to be the last element)
        final ack = data.last is Function ? data.last as Function : null;

        onRequest?.call(
          firstItem, // Passing only the first item (expected to be a Map)
          (responseData) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': true,
              'data': responseData,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
          (errorCode, errorReason) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': false,
              'errorCode': errorCode,
              'errorReason': errorReason,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
        );
      }
    });

    _socket.on('disableMic', (data) {
      if (data is List && data.isNotEmpty) {
        var firstItem = data.first; // Access the first map in the list

        // Extract the acknowledgment function (assumed to be the last element)
        final ack = data.last is Function ? data.last as Function : null;

        onRequest?.call(
          firstItem, // Passing only the first item (expected to be a Map)
          (responseData) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': true,
              'data': responseData,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
          (errorCode, errorReason) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': false,
              'errorCode': errorCode,
              'errorReason': errorReason,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
        );
      }
    });
    _socket.on('enableWebcam', (data) {
      if (data is List && data.isNotEmpty) {
        var firstItem = data.first; // Access the first map in the list

        // Extract the acknowledgment function (assumed to be the last element)
        final ack = data.last is Function ? data.last as Function : null;

        onRequest?.call(
          firstItem, // Passing only the first item (expected to be a Map)
          (responseData) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': true,
              'data': responseData,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
          (errorCode, errorReason) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': false,
              'errorCode': errorCode,
              'errorReason': errorReason,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
        );
      }
    });
    _socket.on('disableWebcam', (data) {
      if (data is List && data.isNotEmpty) {
        var firstItem = data.first;

        final ack = data.last is Function ? data.last as Function : null;

        onRequest?.call(
          firstItem,
          (responseData) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': true,
              'data': responseData,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
          (errorCode, errorReason) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': false,
              'errorCode': errorCode,
              'errorReason': errorReason,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
        );
      }
    });
    _socket.on('statsData', (data) {
      if (data is List && data.isNotEmpty) {
        var firstItem = data.first; // Access the first map in the list

        // Extract the acknowledgment function (assumed to be the last element)
        final ack = data.last is Function ? data.last as Function : null;

        onRequest?.call(
          firstItem, // Passing only the first item (expected to be a Map)
          (responseData) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': true,
              'data': responseData,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
          (errorCode, errorReason) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': false,
              'errorCode': errorCode,
              'errorReason': errorReason,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
        );
      }
    });

    _socket.on('pinStateChanged', (data) {
      if (data is List && data.isNotEmpty) {
        var firstItem = data.first; // Access the first map in the list

        // Extract the acknowledgment function (assumed to be the last element)
        final ack = data.last is Function ? data.last as Function : null;

        onRequest?.call(
          firstItem, // Passing only the first item (expected to be a Map)
          (responseData) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': true,
              'data': responseData,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
          (errorCode, errorReason) {
            _socket.emit('response', {
              'id': firstItem['id'],
              'ok': false,
              'errorCode': errorCode,
              'errorReason': errorReason,
            });

            // Call the ack function if it exists
            ack?.call("");
          },
        );
      }
    });
    _socket.on('notification', (data) {
      onNotification?.call(data);
    });
  }

  Future<dynamic> sendRequest(String method, dynamic data) {
    final request = {
      'method': method,
      'data': data,
    };

    final completer = Completer<dynamic>();

    _socket.emitWithAck('request', request, ack: (response) {
      if (response == null) {
        completer.completeError("No response received");
        return;
      }

      if (response['data']['status'] != 'error') {
        completer.complete(response['data']);
      } else {
        completer.completeError(response['errorReason']); // Complete with error
      }
    });

    return completer.future;
  }

  void sendNotification(String method, dynamic data) {
    final notification = {
      'method': method,
      'data': data,
    };
    _socket.emit('notification', notification);
  }

  void close() {
    _socket.close();
  }
}
