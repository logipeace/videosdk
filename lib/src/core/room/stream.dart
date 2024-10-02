import 'package:videosdk_webrtc/flutter_webrtc.dart';

import '../webrtc/webrtc_client.dart';

enum StreamKind { video, audio, share }

class Stream {
  late String id;
  late Consumer track;
  late String? kind;
  late RTCVideoRenderer? renderer;

  Stream({required consumer, this.renderer}) {
    track = consumer;
    id = track.id;
    kind = track.appData['share'] == true ? "share" : track.kind;
  }

  Stream copyWith({
    Consumer? track,
    RTCVideoRenderer? renderer,
  }) {
    return Stream(
      consumer: track ?? this.track,
      renderer: renderer ?? this.renderer,
    );
  }
}
