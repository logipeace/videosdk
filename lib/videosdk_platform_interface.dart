import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'videosdk_method_channel.dart';

abstract class VideosdkPlatform extends PlatformInterface {
  /// Constructs a VideosdkPlatform.
  VideosdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static VideosdkPlatform _instance = MethodChannelVideosdk();

  /// The default instance of [VideosdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelVideosdk].
  static VideosdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VideosdkPlatform] when
  /// they register themselves.
  static set instance(VideosdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Map<String, dynamic>?> getDeviceInfo();
}
