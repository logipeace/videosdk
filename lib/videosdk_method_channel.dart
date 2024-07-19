import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'videosdk_platform_interface.dart';

/// An implementation of [VideosdkPlatform] that uses method channels.
class MethodChannelVideosdk extends VideosdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('videosdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    Map<String, dynamic> info =
        await methodChannel.invokeMethod('getDeviceInfo');
    return info;
  }
}
