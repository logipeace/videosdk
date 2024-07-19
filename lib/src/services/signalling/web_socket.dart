import './client/messaging_client.dart' as ProtooClient;

class WebSocket {
  final String peerId;
  final String meetingId;
  final String token;
  final String baseUrl;
  final String mode;

  late ProtooClient.Peer _protoo;
  Function()? onOpen;
  Function()? onFail;
  Function()? onDisconnected;
  Function()? onClose;
  Function(
    dynamic request,
    dynamic accept,
    dynamic reject,
  )? onRequest; // request, accept, reject
  Function(dynamic notification)? onNotification;

  ProtooClient.Peer get socket => _protoo;

  WebSocket({
    required this.peerId,
    required this.meetingId,
    required this.token,
    required this.baseUrl,
    required this.mode,
  }) {
    _protoo = ProtooClient.Peer(
      ProtooClient.Transport(
          "wss://$baseUrl/?roomId=$meetingId&peerId=$peerId&secret=$token&mode=$mode"),
    );

    _protoo.on('open', () => this.onOpen?.call());
    _protoo.on('failed', () => this.onFail?.call());
    _protoo.on('disconnected', () => this.onClose?.call());
    _protoo.on('close', () => this.onClose?.call());
    _protoo.on(
        'request',
        (request, accept, reject) =>
            this.onRequest?.call(request, accept, reject));
    _protoo.on('notification',
        (request, accept, reject) => onNotification?.call(request));
  }

  void close() {
    _protoo.close();
  }
}
