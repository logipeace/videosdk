import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:videosdk_webrtc/flutter_webrtc.dart';
import 'package:random_string/random_string.dart';
import 'package:videosdk/src/core/room/custom_track_configs.dart';
import 'package:videosdk/src/core/room/events.dart';
import 'package:videosdk/src/core/webrtc/src/handlers/unified_plan.dart';
import 'package:videosdk/videosdk_platform_interface.dart';
import 'package:events2/events2.dart';

import '../../videosdk.dart';
import '../utils/constants.dart';

class VideoSDK {
  // Method channel to  communicate with platform
  static const MethodChannel _channel = MethodChannel('videosdk');
  static const EventChannel _eventChannel = EventChannel('videosdk-event');

  // States for MediaDevices
  static final mediaDevices = <MediaDeviceType, List<MediaDeviceInfo>>{};

  static final _eventEmitter = EventEmitter();

  // Method to join Room
  static Room createRoom({
    required String roomId,
    required String displayName,
    required String token,
    bool micEnabled = true,
    bool camEnabled = true,
    String participantId = '',
    String maxResolution = 'sd',
    int defaultCameraIndex = 0,
    bool multiStream = true,
    CustomTrack? customCameraVideoTrack,
    CustomTrack? customMicrophoneAudioTrack,
    NotificationInfo notification = const NotificationInfo(
      title: "Video SDK",
      message: "Video SDK is sharing screen in the meeting",
      icon: "notification_share",
    ),
    Mode mode = Mode.CONFERENCE,
    Map<String, dynamic> metaData = const {},
    String signalingBaseUrl = '',
    PreferredProtocol preferredProtocol = PreferredProtocol.UDP_OVER_TCP,
  }) {
    //
    participantId = participantId.isNotEmpty ? participantId : randomAlpha(8);

    signalingBaseUrl =
        signalingBaseUrl.isNotEmpty ? signalingBaseUrl : "api.videosdk.live";

    //
    if (token.isEmpty) {
      //
      //
      // VideoSDKLog.createLog(
      //     message: "Token is empty or invalid.",
      //     logLevel: "ERROR");
      //
      throw "Token is empty or invalid.";
    }

    Room room = Room(
        participantId: participantId,
        displayName: displayName,
        maxResolution: maxResolution,
        camEnabled: camEnabled,
        micEnabled: micEnabled,
        meetingId: roomId,
        multiStream: multiStream,
        token: token,
        notification: notification,
        defaultCameraIndex: defaultCameraIndex,
        customCameraVideoTrack: customCameraVideoTrack,
        customMicrophoneAudioTrack: customMicrophoneAudioTrack,
        mode: mode,
        metaData: metaData,
        signalingBaseUrl: signalingBaseUrl,
        preferredProtocol: preferredProtocol);

    if (!kIsWeb) {
      if (!Platform.isMacOS && !Platform.isWindows) {
        _eventChannel.receiveBroadcastStream().listen((event) {
          if (event == "STOP_SCREENSHARE") {
            room.disableScreenShare();
          } else if (event == "START_SCREENSHARE") {
            room.enableShare(null, iosPermissionGiven: true);
          }
        });
      }
    }

    //
    return room;
  }

  static void registerForDeviceChange() async {
    navigator.mediaDevices.ondevicechange = (event) => {
          navigator.mediaDevices.enumerateDevices().then((devices) {
            updateDeviceList(devices);
            _eventEmitter.emit(Events.deviceChanged.parseToString(), devices);
            if (!kIsWeb) {
              if (Platform.isIOS) {
                // set videoChat mode whenever new device connected
                setAppleAudioConfiguration();
              }
            }
          })
        };
  }

  static on(Events event, Function handler) {
    if (event == Events.deviceChanged) {
      _eventEmitter.on(event.parseToString(), handler);
      registerForDeviceChange();
    } else {
      throw Error();
    }
  }

  static void requestIOSScreenSharePermission() {
    _channel.invokeMethod('requestScreenSharePermission');
  }

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    String platform;

    if (kIsWeb) {
      platform = "web";
    } else if (Platform.isAndroid) {
      platform = "android";
    } else if (Platform.isIOS) {
      platform = "ios";
    } else if (Platform.isMacOS) {
      platform = "macos";
    } else if (Platform.isWindows) {
      platform = "windows";
    } else {
      platform = "web";
    }

    final deviceInfo = LinkedHashMap<String, dynamic>();

    deviceInfo.addAll(<String, dynamic>{
      "sdkType": 'flutter',
      "sdkVersion": sdkVersion,
      "platform": platform
    });
    if (!kIsWeb) {
      var deviceUserAgent = await _channel.invokeMethod('getDeviceInfo');

      if (deviceUserAgent != null) {
        deviceInfo
            .addAll(<String, dynamic>{"deviceUserAgent": deviceUserAgent});
      }
    } else {
      var browserUserAgent = await VideosdkPlatform.instance.getDeviceInfo();
      if (browserUserAgent != null) {
        deviceInfo
            .addAll(<String, dynamic>{"browserUserAgent": browserUserAgent});
      }
    }
    return deviceInfo;
  }

  // Method used to load media devices
  static Future<Map<MediaDeviceType, List<MediaDeviceInfo>>>
      loadMediaDevices() async {
    // Load MediaDevices
    final List<MediaDeviceInfo> devices =
        await navigator.mediaDevices.enumerateDevices();

    updateDeviceList(devices);
    //Device Change Event, commonly made for inside meeting as well as for VideoSDK.ondeviceChange
    registerForDeviceChange();

    return mediaDevices;
  }

  static updateDeviceList(List<MediaDeviceInfo> devices) {
    // Clear Devices
    mediaDevices[MediaDeviceType.audioInput] = <MediaDeviceInfo>[];
    mediaDevices[MediaDeviceType.audioOutput] = <MediaDeviceInfo>[];
    mediaDevices[MediaDeviceType.videoInput] = <MediaDeviceInfo>[];

    log("Device List: ${devices.length} ${devices.map((e) => e.kind).join(" ")}");

    // Iterate MediaDevice
    for (MediaDeviceInfo device in devices) {
      // Conditional Checking
      switch (device.kind) {
        case 'audioinput':
          mediaDevices[MediaDeviceType.audioInput]!.add(device);
          break;
        case 'audiooutput':
          mediaDevices[MediaDeviceType.audioOutput]!.add(device);
          break;
        case 'videoinput':
          mediaDevices[MediaDeviceType.videoInput]!.add(device);
          break;
        default:
          break;
      }
    }
  }

  @Deprecated("Use getAudioDevices() method instead")
  static Future<List<MediaDeviceInfo>?> getAudioOutputDevices() async {
    await loadMediaDevices();
    return mediaDevices[MediaDeviceType.audioOutput];
  }

  static Future<List<VideoDeviceInfo>?> getVideoDevices() async {
    MediaStream? mediaStream;
    bool _isFirefox = await isFirefox();
    if (_isFirefox) {
      try {
        mediaStream = await navigator.mediaDevices
            .getUserMedia({'audio': false, 'video': true});
      } catch (e) {
        if (e ==
            "Unable to getUserMedia: NotAllowedError: The request is not allowed by the user agent or the platform in the current context.") {
          log("Error in getVideoDevices(): The request is not allowed by the user agent or the platform in the current context.");
          return null;
        }
      }
    }
    if (!_isFirefox && kIsWeb) {
      // The deviceId,label of the VideoDevice will be empty if the camera permission is not granted on the web.
      // checkPermission is not supported by Firefox
      final permissions = await checkPermissions(Permissions.video);
      if (!permissions['video']!) {
        log("You need camera permission to access list of Video devices.");
        return null;
      }
    }
    final List<MediaDeviceInfo> devices =
        await navigator.mediaDevices.enumerateDevices();
    final List<VideoDeviceInfo> videoDevices = [];
    for (MediaDeviceInfo device in devices) {
      if (device.kind == 'videoinput') {
        videoDevices.add(VideoDeviceInfo(
          deviceId: device.deviceId,
          label: device.label,
          groupId: device.groupId,
          kind: device.kind,
        ));
      }
    }

    if (mediaStream != null) {
      for (var track in mediaStream.getTracks()) {
        track.stop();
        mediaStream!.dispose();
        mediaStream = null;
      }
    }

    return videoDevices;
  }

  static Future<List<AudioDeviceInfo>?> getAudioDevices() async {
    MediaStream? mediaStream;
    bool _isFirefox = await isFirefox();
    if (_isFirefox) {
      try {
        mediaStream = await navigator.mediaDevices
            .getUserMedia({'audio': true, 'video': false});
      } catch (e) {
        if (e ==
            "Unable to getUserMedia: NotAllowedError: The request is not allowed by the user agent or the platform in the current context.") {
          log("Error in getAudioDevices(): The request is not allowed by the user agent or the platform in the current context.");
          return null;
        }
      }
    }

    if (!kIsWeb) {
      if (Platform.isIOS) {
        // setting AppleAudioConfiguration to get bluetooth device in the list
        setAppleAudioConfiguration();
      }
    }
    if (!_isFirefox && kIsWeb) {
      // The deviceId,label of the AudioDevice will be empty if the audio permission is not granted on the web.
      // checkPermission is not supported by Firefox
      final permissions = await checkPermissions(Permissions.audio);
      if (!permissions['audio']!) {
        log("You need microphone permission to access list of Audio Input devices.");
        return null;
      }
    }
    final List<MediaDeviceInfo> devices =
        await navigator.mediaDevices.enumerateDevices();
    final List<AudioDeviceInfo> audioDevices = [];

    for (MediaDeviceInfo device in devices) {
      if (kIsWeb || Platform.isMacOS || Platform.isWindows) {
        if (device.kind != 'videoinput') {
          audioDevices.add(AudioDeviceInfo(
            deviceId: device.deviceId,
            label: device.label,
            groupId: device.groupId,
            kind: device.kind,
          ));
        }
      } else {
        if (device.kind == 'audiooutput') {
          audioDevices.add(AudioDeviceInfo(
            deviceId: device.deviceId,
            label: device.label,
            groupId: device.groupId,
            kind: device.kind,
          ));
        }
      }
    }
    if (!kIsWeb) {
      if (Platform.isIOS) {
        if (audioDevices.length == 1) {
          AudioDeviceInfo mediaDeviceInfo = AudioDeviceInfo(
              label: "Receiver",
              deviceId: "Built-In Receiver",
              kind: "audiooutput");
          audioDevices.add(mediaDeviceInfo);
        }
      }
    }

    if (mediaStream != null) {
      for (var track in mediaStream.getTracks()) {
        track.stop();
        mediaStream!.dispose();
        mediaStream = null;
      }
    }
    return audioDevices;
  }

  static void setAppleAudioConfiguration() async {
    await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
        appleAudioCategory: AppleAudioCategory.playAndRecord,
        appleAudioCategoryOptions: {
          AppleAudioCategoryOption.allowBluetooth,
          AppleAudioCategoryOption.allowBluetoothA2DP
        },
        appleAudioMode: AppleAudioMode.voiceChat));
  }

  static Future<List<DeviceInfo>?> getDevices() async {
    bool _isFirefox = await isFirefox();

    final List<DeviceInfo> mediaDevices = [];

    if (!_isFirefox && kIsWeb) {
      var permissions = await checkPermissions();

      if (permissions['audio']! && !permissions['video']!) {
        log("You need camera permissions to access list of Video devices");
        return await _getAudioDevicesList();
      } else if (!permissions['audio']! && permissions['video']!) {
        log("You need microphone permissions to access list of Audio devices");
        return await _getVideoDevicesList();
      } else if (!permissions['audio']! && !permissions['video']!) {
        log("You need camera and microphone permissions to access list of devices");
        return null;
      }
    }

    // Add audio devices to the list
    mediaDevices.addAll(await _getAudioDevicesList());

    // Add video devices to the list
    mediaDevices.addAll(await _getVideoDevicesList());

    return mediaDevices;
  }

  static Future<List<DeviceInfo>> _getAudioDevicesList() async {
    final List<DeviceInfo> audioDevices = [];
    final audioDeviceList = await getAudioDevices();
    if (audioDeviceList != null) {
      for (var audioDevice in audioDeviceList) {
        audioDevices.add(DeviceInfo(
          deviceId: audioDevice.deviceId,
          label: audioDevice.label,
          groupId: audioDevice.groupId,
          kind: audioDevice.kind,
        ));
      }
    }
    return audioDevices;
  }

  static Future<List<DeviceInfo>> _getVideoDevicesList() async {
    final List<DeviceInfo> videoDevices = [];
    final videoDeviceList = await getVideoDevices();
    if (videoDeviceList != null) {
      for (var videoDevice in videoDeviceList) {
        videoDevices.add(DeviceInfo(
          deviceId: videoDevice.deviceId,
          label: videoDevice.label,
          groupId: videoDevice.groupId,
          kind: videoDevice.kind,
        ));
      }
    }
    return videoDevices;
  }

  static Future<bool> isFirefox() async {
    final deviceInfo = await VideoSDK.getDeviceInfo();
    return deviceInfo['browserUserAgent']?['browser']?['name'] == "Firefox";
  }

  static Future<Map<String, bool>> checkPermissions(
      [Permissions? permissions]) async {
    permissions ??= Permissions.audio_video;
    Map<String, bool> permissionMap = {};
    final _isFirefox = await isFirefox();
    if (_isFirefox) {
      throw UnsupportedError('Checking permission is not supported.');
    }
    if (!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows) {
        throw UnsupportedError('Checking permission is not supported.');
      }
    }

    if (permissions == Permissions.audio ||
        permissions == Permissions.audio_video) {
      bool allowed = false;
      try {
        var status = await Permission.microphone.status;
        if (status.isGranted) {
          allowed = true;
        }
      } catch (error) {
        allowed = false;
      }
      permissionMap["audio"] = allowed;
    }
    if (permissions == Permissions.video ||
        permissions == Permissions.audio_video) {
      bool allowed = false;
      try {
        var status = await Permission.camera.status;
        if (status.isGranted) {
          allowed = true;
        }
      } catch (error) {
        allowed = false;
      }
      permissionMap["video"] = allowed;
    }
    return permissionMap;
  }

  static Future<Map<String, bool>> requestPermissions(
      [Permissions? permissions]) async {
    permissions ??= Permissions.audio_video;
    Map<String, bool> permissionMap = {};
    bool _isFirefox = await isFirefox();
    if (_isFirefox) {
      throw UnsupportedError('Requesting permission is not supported');
    }
    if (!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows) {
        throw UnsupportedError('Requesting permission is not supported');
      }
    }
    if (permissions == Permissions.audio ||
        permissions == Permissions.audio_video) {
      bool allowed = false;
      try {
        var status = await Permission.microphone.request();
        if (status.isGranted) {
          allowed = true;
        }
      } catch (error) {
        allowed = false;
      }
      permissionMap["audio"] = allowed;
    }
    if (permissions == Permissions.video ||
        permissions == Permissions.audio_video) {
      bool allowed = false;
      try {
        var status = await Permission.camera.request();
        if (status.isGranted) {
          allowed = true;
        }
      } catch (error) {
        allowed = false;
      }
      permissionMap["video"] = allowed;
    }

    return permissionMap;
  }

  static Future<bool> checkBluetoothPermission() async {
    bool permAvailable = false;

    if (!kIsWeb) {
      // checking android version
      // Providing the checkBluetoothPermission() method for Android version 12 and higher.
      if (Platform.isAndroid) {
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
        if (int.parse(info.version.release) > 11) {
          permAvailable = true;
        }
      }
    }
    if (permAvailable == false) {
      throw UnsupportedError('Checking Bluetooth permission is not applicable');
    }

    bool allowed = false;

    try {
      var status = await Permission.bluetoothConnect.status;
      if (status.isGranted) {
        allowed = true;
      }
    } catch (error) {
      allowed = false;
    }

    return allowed;
  }

  static Future<bool> requestBluetoothPermission() async {
    bool permAvailable = false;

    if (!kIsWeb) {
      // checking android version
      // Providing the requestBluetoothPermission() method for Android version 12 and higher.
      if (Platform.isAndroid) {
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
        if (int.parse(info.version.release) > 11) {
          permAvailable = true;
        }
      }
    }
    if (permAvailable == false) {
      throw UnsupportedError(
          'Requesting Bluetooth permission is not applicable');
    }

    bool allowed = false;

    try {
      var status = await Permission.bluetoothConnect.request();

      if (status.isGranted) {
        allowed = true;
      }
    } catch (error) {
      allowed = false;
    }

    return allowed;
  }

  static createMicrophoneAudioTrack(
      {String? microphoneId,
      CustomAudioTrackConfig encoderConfig =
          CustomAudioTrackConfig.speech_standard,
      Map<String, bool> noiseConfig = const {}}) async {
    Map<String, dynamic>? config = customAudioTrackConfigMap[encoderConfig];
    late Map<String, dynamic> mediaConstraints;

    if (!kIsWeb) {
      mediaConstraints = <String, dynamic>{
        "audio": {
          "mandatory": {
            "googEchoCancellation": noiseConfig["echoCancellation"] ??
                config?["echoCancellation"] as bool,
            "googNoiseSuppression": noiseConfig["noiseSuppression"] ??
                config?["noiseSuppression"] as bool,
            "echoCancellation": noiseConfig["echoCancellation"] ??
                config?["echoCancellation"] as bool,
            "googEchoCancellation2": noiseConfig["echoCancellation"] ??
                config?["echoCancellation"] as bool,
            "googDAEchoCancellation": noiseConfig["echoCancellation"] ??
                config?["echoCancellation"] as bool,
            "googAutoGainControl": noiseConfig["autoGainControl"] ??
                config?["autoGainControl"] as bool,
          },
          'optional': microphoneId != null
              ? [
                  {
                    'sourceId': microphoneId,
                  }
                ]
              : [],
        },
        "video": false
      };
    } else {
      mediaConstraints = <String, dynamic>{
        "audio": {
          "googEchoCancellation": noiseConfig["echoCancellation"] ??
              config?["echoCancellation"] as bool,
          "googNoiseSuppression": noiseConfig["noiseSuppression"] ??
              config?["noiseSuppression"] as bool,
          "echoCancellation": noiseConfig["echoCancellation"] ??
              config?["echoCancellation"] as bool,
          "googEchoCancellation2": noiseConfig["echoCancellation"] ??
              config?["echoCancellation"] as bool,
          "googDAEchoCancellation": noiseConfig["echoCancellation"] ??
              config?["echoCancellation"] as bool,
          "googAutoGainControl": noiseConfig["autoGainControl"] ??
              config?["autoGainControl"] as bool,
          "deviceId": microphoneId
        },
        "video": false
      };
    }

    MediaStream mediaStream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    CustomTrack customAudioTrack = CustomTrack.audioTrack(
        mediaStream: mediaStream,
        audioEncoderConfig: encoderConfig,
        noiseConfig: noiseConfig);

    return customAudioTrack;
  }

  static createCameraVideoTrack(
      {String? cameraId,
      CustomVideoTrackConfig encoderConfig = CustomVideoTrackConfig.h360p_w640p,
      String facingMode = "user",
      // String optimizationMode = "motion",
      bool multiStream = true}) async {
    late Map<String, dynamic> mediaConstraints;
    if (!kIsWeb) {
      var optional = cameraId != null
          ? [
              {
                'sourceId': cameraId,
              }
            ]
          : [];

      if (cameraId != null && Platform.isAndroid) {
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
        var osVersion = info.version.sdkInt;
        if (mediaDevices.isEmpty) {
          await loadMediaDevices();
        }
        MediaDeviceInfo? device = mediaDevices[MediaDeviceType.videoInput]!
            .firstWhereOrNull((element) => element.deviceId == cameraId);
        if (device != null && Platform.isAndroid && osVersion <= 28) {
          if (info.supportedAbis.first != "arm64-v8a" &&
              info.supportedAbis.first != "x86_64") {
            optional = [
              {
                'sourceId': device.label,
              }
            ];
          }
        }
      }

      mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': {
          'facingMode': facingMode,
          'width': customVideotrackConfigMap[encoderConfig]!["width"],
          'height': customVideotrackConfigMap[encoderConfig]!["height"],
          'frameRate': customVideotrackConfigMap[encoderConfig]!["frameRate"],
          'optional': optional,
        },
      };
    } else {
      mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': {
          'facingMode': facingMode,
          'width': customVideotrackConfigMap[encoderConfig]!["width"],
          'height': customVideotrackConfigMap[encoderConfig]!["height"],
          'frameRate': customVideotrackConfigMap[encoderConfig]!["frameRate"],
          'deviceId': cameraId ?? 1,
        },
      };
    }

    MediaStream mediaStream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    CustomTrack customVideoTrack = CustomTrack.videoTrack(
      mediaStream: mediaStream,
      multiStream: multiStream,
      videoEncoderConfig: encoderConfig,
      // optimizationMode: optimizationMode
    );
    return customVideoTrack;
  }

  static void applyVideoProcessor({required String videoProcessorName}) async{
    await _channel.invokeMethod('processorMethod', {"videoProcessorName": videoProcessorName});
  }
  static void removeVideoProcessor() async{
    await _channel.invokeMethod('processorMethod', {"videoProcessorName": null});
  }
}

enum MediaDeviceType { audioInput, audioOutput, videoInput }

enum PreferredProtocol { UDP_ONLY, UDP_OVER_TCP, TCP_ONLY }
