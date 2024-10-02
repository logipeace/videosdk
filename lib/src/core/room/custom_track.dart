import 'dart:developer';

import 'package:videosdk_webrtc/flutter_webrtc.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';
import 'package:videosdk/videosdk.dart';

enum CustomTrackKind { AUDIO, VIDEO, SHARE }

class CustomTrack {
  late MediaStream mediaStream;
  late CustomVideoTrackConfig videoEncoderConfig;
  late CustomAudioTrackConfig audioEncoderConfig;
  late Map<String, bool>? noiseConfig;
  late CustomTrackKind kind;
  late bool multiStream;
  bool ended = false;
  String? microphoneId;
  // late String optimizationMode;

  CustomTrack.videoTrack({
    required this.mediaStream,
    this.kind = CustomTrackKind.VIDEO,
    this.videoEncoderConfig = CustomVideoTrackConfig.h720p_w1280p,
    this.multiStream = true,
    // this.optimizationMode = "motion",
  });

  CustomTrack.audioTrack({
    required this.mediaStream,
    this.audioEncoderConfig = CustomAudioTrackConfig.speech_standard,
    this.noiseConfig,
    this.kind = CustomTrackKind.AUDIO,
    this.microphoneId
  });

  dispose() async {
    try {
      mediaStream.getTracks().forEach((track) {
        track.onEnded = null;
        track.stop();
      });
      ended = true;
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message:
              "error in dispose() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("ERROR: Unable to dispose track :: $error");
    }
  }

  Map<String, String> toMap() {
    return {
      'kind': kind.toString(),
      if (kind.name == CustomTrackKind.AUDIO.name)
        'audioConfig': audioEncoderConfig.name,
      if (kind.name == CustomTrackKind.AUDIO.name)
        'noiseConfig': noiseConfig.toString(),
      if (kind.name == CustomTrackKind.VIDEO.name)
        'videoConfig': videoEncoderConfig.name,
      if (kind.name == CustomTrackKind.VIDEO.name)
        'multiStream': multiStream.toString(),
    };
  }
}
