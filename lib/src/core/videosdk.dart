import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';
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
  static Room createRoom(
      {required String roomId,
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
      bool debugMode = true}) {
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
        preferredProtocol: preferredProtocol,
        debugMode: debugMode);

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

  static void _registerForDeviceChange() async {
    navigator.mediaDevices.ondevicechange = (event) => {
          navigator.mediaDevices.enumerateDevices().then((devices) {
            updateDeviceList(devices);
            _eventEmitter.emit(Events.deviceChanged.parseToString(), devices);
            if (!kIsWeb) {
              if (Platform.isIOS) {
                // set videoChat mode whenever new device connected
                // setAppleAudioConfiguration();
              }
            }
          })
        };
  }

  static on(Events event, Function handler) {
    if (event == Events.deviceChanged) {
      _eventEmitter.on(event.parseToString(), handler);
      _registerForDeviceChange();
    } else if (event == Events.error) {
      _eventEmitter.on(event.parseToString(), handler);
    } else {
      throw Error();
    }
  }

  static off(Events event, Function handler) {
    if (event == Events.deviceChanged) {
      _eventEmitter.remove(event.parseToString(), handler);
    } else if (event == Events.error) {
      _eventEmitter.remove(event.parseToString(), handler);
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
    _registerForDeviceChange();

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

  // @Deprecated("Use getAudioDevices() method instead")
  // static Future<List<MediaDeviceInfo>?> getAudioOutputDevices() async {
  //   await loadMediaDevices();
  //   return mediaDevices[MediaDeviceType.audioOutput];
  // }

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
        // setAppleAudioConfiguration();
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
          audioDevices.insert(0, mediaDeviceInfo);
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
        appleAudioMode: AppleAudioMode.videoChat));
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
    String? selectedMicrophoneId;

    bool _isFirefox = await isFirefox();

    if (!_isFirefox && kIsWeb) {
      Map<String, bool>? audioPermissions =
          await VideoSDK.requestPermissions(Permissions.audio);
    } else {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        Map<String, bool>? audioPermissions =
            await VideoSDK.requestPermissions(Permissions.audio);
        if (audioPermissions['audio'] == false) {
          //Throwing error for Android and iOS directly
          _eventEmitter.emit("error", VideoSDKErrors[3008]);
          Map<String, String> attributes = {
            "error":
                "Error while creating Audio Track: Browser/Device Permissions denied."
          };
          VideoSDKLog.createLog(
              message: VideoSDKErrors[3008]!['message']!,
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred while creating Audio Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3008]?['code']}  :: ${VideoSDKErrors[3008]?['name']} :: ${VideoSDKErrors[3008]?['message']}");
          return null;
        }
      }
    }

    try {
      if (microphoneId != null) {
        List<AudioDeviceInfo>? audioDevices = await VideoSDK.getAudioDevices();
        if (audioDevices != null) {
          bool isMicrophone = kIsWeb || Platform.isMacOS || Platform.isWindows
              ? audioDevices.any((mic) =>
                  mic.deviceId == microphoneId && mic.kind == "audioinput")
              : audioDevices.any((mic) => mic.deviceId == microphoneId);
          if (isMicrophone) {
            selectedMicrophoneId =
                kIsWeb || Platform.isMacOS || Platform.isWindows
                    ? audioDevices
                        .firstWhere((mic) =>
                            mic.deviceId == microphoneId &&
                            mic.kind == "audioinput")
                        .deviceId
                    : audioDevices
                        .firstWhere((mic) => mic.deviceId == microphoneId)
                        .deviceId;
          } else {
            selectedMicrophoneId = audioDevices.first.deviceId;
            print(
                "No microphone device found for the specified microphoneId. Please verify the provided microphoneId. The default microphone will be used instead.");
          }
        } else {
          //For web if permission not available.
          selectedMicrophoneId = microphoneId;
        }
      }

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
            'optional': selectedMicrophoneId != null
                ? [
                    {
                      'sourceId': selectedMicrophoneId,
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
            "deviceId": selectedMicrophoneId
          },
          "video": false
        };
      }

      MediaStream mediaStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      CustomTrack customAudioTrack = CustomTrack.audioTrack(
          mediaStream: mediaStream,
          audioEncoderConfig: encoderConfig,
          noiseConfig: noiseConfig,
          microphoneId: selectedMicrophoneId);

      return customAudioTrack;
    } catch (e) {
      if (e == "Unable to getUserMedia: NotAllowedError: Permission denied" ||
          e ==
              "Unable to getUserMedia: NotAllowedError: The request is not allowed by the user agent or the platform in the current context." ||
          e ==
              "Unable to getUserMedia: getUserMedia(): DOMException, NotAllowedError" ||
          e == "Unable to getUserMedia: NotAllowedError") {
        _eventEmitter.emit("error", VideoSDKErrors[3008]);
        Map<String, String> attributes = {
          "error":
              "Error while creating Audio Track: Browser/Device Permissions denied."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3008]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Audio Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3008]?['code']}  :: ${VideoSDKErrors[3008]?['name']} :: ${VideoSDKErrors[3008]?['message']}");
      } else if (e ==
              "Unable to getUserMedia: NotAllowedError: Permission denied by system" ||
          e ==
              "Unable to getUserMedia: NotFoundError: The object can not be found here.") {
        _eventEmitter.emit("error", VideoSDKErrors[3010]);
        Map<String, String> attributes = {
          "error": "Error while creating Audio Track: Permissions denied by OS."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3010]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Audio Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3010]?['code']}  :: ${VideoSDKErrors[3010]?['name']} :: ${VideoSDKErrors[3010]?['message']}");
      } else if (e ==
              "Unable to getUserMedia: NotReadableError: Device in use" ||
          e.toString().contains("Unable to getUserMedia: AbortError")) {
        _eventEmitter.emit("error", VideoSDKErrors[3004]);
        Map<String, String> attributes = {
          "error": "Error while creating Audio Track: Microphone Device in use."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3004]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Audio Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3004]?['code']}  :: ${VideoSDKErrors[3004]?['name']} :: ${VideoSDKErrors[3004]?['message']}");
      } else if (e.toString().contains(
          "TypeError: null: type 'Null' is not a subtype of type 'JSObject'")) {
        _eventEmitter.emit("error", VideoSDKErrors[3006]);
        Map<String, String> attributes = {
          "error": "Error while creating Audio Track: Not a secure website."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3006]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Audio Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3006]?['code']}  :: ${VideoSDKErrors[3006]?['name']} :: ${VideoSDKErrors[3006]?['message']}");
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3018]);
        Map<String, String> attributes = {
          "error": "Error while creating Audio Track."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3018]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Audio Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3018]?['code']}  :: ${VideoSDKErrors[3018]?['name']} :: ${VideoSDKErrors[3018]?['message']}");
      }
      return null;
    }
  }

  static createCameraVideoTrack(
      {String? cameraId,
      CustomVideoTrackConfig encoderConfig = CustomVideoTrackConfig.h360p_w640p,
      FacingMode facingMode = FacingMode.user,
      // String optimizationMode = "motion",
      bool multiStream = true}) async {
    late Map<String, dynamic> mediaConstraints;
    String? selectedCameraId;

    bool _isFirefox = await isFirefox();

    if (!_isFirefox && kIsWeb) {
      Map<String, bool>? videoPermissions =
          await VideoSDK.requestPermissions(Permissions.video);
    } else {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        Map<String, bool>? videoPermissions =
            await VideoSDK.requestPermissions(Permissions.video);
        if (videoPermissions['video'] == false) {
          //Throwing error for Android and iOS directly
          _eventEmitter.emit("error", VideoSDKErrors[3007]);
          Map<String, String> attributes = {
            "error":
                "Error while creating Video Track: Browser/Device Permissions denied."
          };
          VideoSDKLog.createLog(
              message: VideoSDKErrors[3007]!['message']!,
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred while creating Video Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3007]?['code']}  :: ${VideoSDKErrors[3007]?['name']} :: ${VideoSDKErrors[3007]?['message']}");
          return null;
        }
      }
    }
    try {
      if (cameraId != null) {
        List<VideoDeviceInfo>? videoDevices = await VideoSDK.getVideoDevices();
        if (videoDevices != null) {
          bool isCamera =
              videoDevices.any((camera) => camera.deviceId == cameraId);
          if (isCamera) {
            for (var videoDevice in videoDevices) {
              if (videoDevice.deviceId == cameraId) {
                selectedCameraId = videoDevice.deviceId;
              }
            }
          } else {
            selectedCameraId = videoDevices.first.deviceId;
            print(
                "No camera device found for the specified cameraId. Please verify the provided cameraId. The default camera will be used instead.");
          }
        } else {
          //For web if permission not available.
          selectedCameraId = cameraId;
        }
      }

      if (!kIsWeb) {
        var optional = selectedCameraId != null
            ? [
                {
                  // 'sourceId': cameraId,
                  'sourceId': selectedCameraId,
                }
              ]
            : [];

        if (selectedCameraId != null && Platform.isAndroid) {
          final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
          final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
          var osVersion = info.version.sdkInt;
          if (mediaDevices.isEmpty) {
            await loadMediaDevices();
          }
          MediaDeviceInfo? device = mediaDevices[MediaDeviceType.videoInput]!
              .firstWhereOrNull(
                  (element) => element.deviceId == selectedCameraId);
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

        if (Platform.isAndroid || Platform.isIOS) {
          mediaConstraints = <String, dynamic>{
            'audio': false,
            'video': {
              'facingMode': facingMode.name,
              'width': customVideotrackConfigMap[encoderConfig]!["width"],
              'height': customVideotrackConfigMap[encoderConfig]!["height"],
              'frameRate':
                  customVideotrackConfigMap[encoderConfig]!["frameRate"],
              'optional': optional,
            },
          };
        } //In Desktop based applications, facingMode is not working and creates issues if passed as null
        else {
          mediaConstraints = <String, dynamic>{
            'audio': false,
            'video': {
              'width': customVideotrackConfigMap[encoderConfig]!["width"],
              'height': customVideotrackConfigMap[encoderConfig]!["height"],
              'frameRate':
                  customVideotrackConfigMap[encoderConfig]!["frameRate"],
              'optional': optional,
            },
          };
        }
      } else {
        mediaConstraints = <String, dynamic>{
          'audio': false,
          'video': {
            'facingMode': selectedCameraId != null ? null : facingMode,
            'width': customVideotrackConfigMap[encoderConfig]!["width"],
            'height': customVideotrackConfigMap[encoderConfig]!["height"],
            'frameRate': customVideotrackConfigMap[encoderConfig]!["frameRate"],
            'deviceId': selectedCameraId
          },
        };
      }

      MediaStream mediaStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (!kIsWeb) {
        if (Platform.isWindows) {
          var track = mediaStream.getVideoTracks().first;
        }
      }

      CustomTrack customVideoTrack = CustomTrack.videoTrack(
        mediaStream: mediaStream,
        multiStream: multiStream,
        videoEncoderConfig: encoderConfig,
        // optimizationMode: optimizationMode
      );
      return customVideoTrack;
    } catch (e) {
      if (e == "Unable to getUserMedia: NotAllowedError: Permission denied" ||
          e ==
              "Unable to getUserMedia: NotAllowedError: The request is not allowed by the user agent or the platform in the current context." ||
          e ==
              "Unable to getUserMedia: getUserMedia(): DOMException, NotAllowedError" ||
          e == "Unable to getUserMedia: NotAllowedError") {
        _eventEmitter.emit("error", VideoSDKErrors[3007]);
        Map<String, String> attributes = {
          "error":
              "Error while creating Video Track: Browser/Device Permissions denied."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3007]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Video Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3007]?['code']}  :: ${VideoSDKErrors[3007]?['name']} :: ${VideoSDKErrors[3007]?['message']}");
      } else if (e ==
              "Unable to getUserMedia: NotAllowedError: Permission denied by system" ||
          e ==
              "Unable to getUserMedia: NotFoundError: The object can not be found here.") {
        _eventEmitter.emit("error", VideoSDKErrors[3009]);
        Map<String, String> attributes = {
          "error": "Error while creating Video Track: Permissions denied by OS."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3009]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Video track: VIDEOSDK ERROR :: ${VideoSDKErrors[3009]?['code']}  :: ${VideoSDKErrors[3009]?['name']} :: ${VideoSDKErrors[3009]?['message']}");
      } else if (e ==
              "Unable to getUserMedia: NotReadableError: Device in use" ||
          e ==
              "Unable to getUserMedia: AbortError: Starting videoinput failed") {
        _eventEmitter.emit("error", VideoSDKErrors[3003]);
        Map<String, String> attributes = {
          "error": "Error while creating Video Track: Camera Device in use."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3003]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Video Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3003]?['code']}  :: ${VideoSDKErrors[3003]?['name']} :: ${VideoSDKErrors[3003]?['message']}");
      } else if (e.toString().contains(
          "TypeError: null: type 'Null' is not a subtype of type 'JSObject'")) {
        _eventEmitter.emit("error", VideoSDKErrors[3005]);
        Map<String, String> attributes = {
          "error": "Error while creating Video Track: Not a secure website."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3005]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Video Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3005]?['code']}  :: ${VideoSDKErrors[3005]?['name']} :: ${VideoSDKErrors[3005]?['message']}");
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3017]);
        Map<String, String> attributes = {
          "error": "Error while creating Video Track"
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3017]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred while creating Video Track: VIDEOSDK ERROR :: ${VideoSDKErrors[3017]?['code']}  :: ${VideoSDKErrors[3017]?['name']} :: ${VideoSDKErrors[3017]?['message']}");
      }
      return null;
    }
  }

  static void applyVideoProcessor({required String videoProcessorName}) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _channel.invokeMethod(
          'processorMethod', {"videoProcessorName": videoProcessorName});
    } else {
      throw UnsupportedError('Applying a video processor is not supported.');
    }
  }

  static void removeVideoProcessor() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _channel
          .invokeMethod('processorMethod', {"videoProcessorName": null});
    } else {
      throw UnsupportedError('Removing a video processor is not supported.');
    }
  }
}

enum MediaDeviceType { audioInput, audioOutput, videoInput }

enum PreferredProtocol { UDP_ONLY, UDP_OVER_TCP, TCP_ONLY }

enum FacingMode { environment, user }
