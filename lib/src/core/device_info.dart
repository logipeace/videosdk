import 'package:videosdk_webrtc/flutter_webrtc.dart';

enum Permissions { audio, video, audio_video }

class DeviceInfo extends MediaDeviceInfo {
  DeviceInfo(
      {required String deviceId,
      String? groupId,
      String? kind,
      required String label})
      : super(deviceId: deviceId, groupId: groupId, kind: kind, label: label);
}

class VideoDeviceInfo extends DeviceInfo {
  VideoDeviceInfo(
      {required String deviceId,
      String? groupId,
      String? kind,
      required String label})
      : super(deviceId: deviceId, groupId: groupId, kind: kind, label: label);
}

class AudioDeviceInfo extends DeviceInfo {
  AudioDeviceInfo(
      {required String deviceId,
      String? groupId,
      String? kind,
      required String label})
      : super(deviceId: deviceId, groupId: groupId, kind: kind, label: label);
}
