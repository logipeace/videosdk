import 'package:videosdk/src/core/room/audio_html/audio_html_stub.dart'
    if (dart.library.io) 'package:videosdk/src/core/room/audio_html/providers/audio_html.dart'
    if (dart.library.html) 'package:videosdk/src/core/room/audio_html/providers/audio_html_web.dart';
import 'package:videosdk/src/core/webrtc/webrtc_client.dart';

abstract class AudioHTMLInterface {

  factory AudioHTMLInterface() => getInterface();

  Future<dynamic> startAudio(Consumer? audioConsumer);
  void stopAudio(String id);
  void setAudioOutputDevice(String deviceId);
}
