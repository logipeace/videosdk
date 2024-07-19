// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'videosdk_platform_interface.dart';
import 'package:platform_detect/platform_detect.dart';

/// A web implementation of the VideosdkPlatform of the Videosdk plugin.
class VideosdkWeb extends VideosdkPlatform {
  /// Constructs a VideosdkWeb
  VideosdkWeb();

  static void registerWith(Registrar registrar) {
    VideosdkPlatform.instance = VideosdkWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = html.window.navigator.userAgent;
    return version;
  }

  @override
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    Map<String, String> browserInfo = <String, String>{};
    browserInfo["name"] = browser.name;
    browserInfo["version"] = browser.version.toString();
    Map<String, String> osInfo = <String, String>{};
    osInfo["name"] = operatingSystem.name;
    osInfo["type"] = html.window.navigator.platform!;
    Map<String, dynamic> data = <String, dynamic>{};
    data["browser"] = browserInfo;
    data["os"] = osInfo;

    return data;
  }
}
