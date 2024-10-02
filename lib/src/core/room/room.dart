import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:io' show Platform;
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:events2/events2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:videosdk_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:videosdk/src/core/room/audio_html/audio_html_interface.dart';
import 'package:videosdk_otel/api.dart';
import 'package:videosdk/src/core/room/custom_track_configs.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_telemetery.dart';
import 'package:videosdk/src/core/room/room_mode.dart';
import 'package:videosdk_room_stats/videosdk_room_stats.dart';

import '../../../videosdk.dart';
import '../../core/pubsub/pubsub.dart';
import '../../core/webrtc/src/handlers/handler_interface.dart';
import '../../core/webrtc/webrtc_client.dart';
import '../../services/signalling/web_socket.dart';
import '../../utils/constants.dart';
import '../webrtc/src/utils.dart';
import 'events.dart';
import 'peer.dart';
import 'sdk_capabilites.dart';

class Room {
  // Room Configuration Properties
  late final String id;
  late final String _token;
  late bool _micEnabled;
  late bool _camEnabled;
  late final bool _multiStream;
  late final NotificationInfo _notification;
  late String _maxResolution;
  late bool _debugMode;

  late CustomTrack? _customCameraVideoTrack;
  late CustomTrack? _customMicrophoneAudioTrack;

  late Mode _mode;

  // Event Emitters
  final _eventEmitter = EventEmitter();
  final _topicEventEmitter = EventEmitter();

  // Participant
  late final Participant localParticipant;
  final participants = <String, Participant>{};
  final pinnedParticipants = <String, ParticipantPinState>{};

  // PubSub
  late PubSub pubSub;

  // States for MediaDevices

  VideoDeviceInfo? _selectedVideoInput;
  List<VideoDeviceInfo>? videoDevices;
  List<AudioDeviceInfo>? audioDevices;

  AudioDeviceInfo? _selectedAudioOutput;
  AudioDeviceInfo? _selectedAudioInput;

  // States
  bool _cameraInProgress = false;
  bool _micInProgress = false;
  bool _screenShareInProgress = false;

  // Internal Components
  WebSocket? _webSocket;
  Device? _device;
  Transport? _sendTransport, _recvTransport;
  bool _produce = false;
  bool _consume = false;
  bool _joined = false, _closed = false;
  String? _activeSpeakerId, _activePresenterId;
  Producer? _micProducer,
      _cameraProducer,
      _screenshareProducer,
      _screenShareAudioProducer;
  RTCVideoRenderer? _cameraRenderer,
      _screenshareRenderer,
      _screenShareAudioRenderer;
  final List<RTCIceServer> _iceServers = [];
  final Map<String, Peer> _peers = {};
  DesktopCapturerSource? _selectedScreenSource;

  VideoSDKMetrics? _metricsCollector;
  var _stats = {};
  var _latestStats = {};

  String _recordingState = "RECORDING_STOPPED";
  String _hlsState = "HLS_STOPPED";
  String? _hlsDownstreamUrl;
  Map<String, String?> _hlsUrls = {
    "downstreamUrl": null,
    "playbackHlsUrl": null,
    "livestreamUrl": null,
  };
  String _livestreamState = "LIVESTREAM_STOPPED";
  late String _displayName;

  //open-telemetery
  VideoSDKTelemetery? videoSDKTelemetery;
  Span? _joinSpan;

  late Map<String, dynamic> _metaData;

  late Map<String, dynamic> deviceInfo;

  static bool _micState = false;
  static bool _camState = false;

  late String _signalingBaseUrl;

  late String _preferredProtocol;
  static const MethodChannel _channel = MethodChannel('videosdk');

  late int _defaultCameraIndex;

  Map<String, dynamic>? characters = {};

  //
  Room(
      {required String meetingId,
      required String token,
      required String participantId,
      required String displayName,
      required bool micEnabled,
      required bool camEnabled,
      required String maxResolution,
      required bool multiStream,
      required CustomTrack? customCameraVideoTrack,
      required CustomTrack? customMicrophoneAudioTrack,
      required NotificationInfo notification,
      required Mode mode,
      required Map<String, dynamic> metaData,
      int defaultCameraIndex = 0,
      required String signalingBaseUrl,
      required PreferredProtocol preferredProtocol,
      required bool debugMode}) {
    //
    id = meetingId;
    //
    _token = token;
    //
    _displayName = displayName;
    //
    _micEnabled = micEnabled;
    //
    _camEnabled = camEnabled;
    //
    _maxResolution = maxResolution;
    //
    _notification = notification;
    //
    _multiStream = multiStream;
    //
    _customCameraVideoTrack = customCameraVideoTrack;
    //
    _customMicrophoneAudioTrack = customMicrophoneAudioTrack;
    //
    _debugMode = debugMode;

    _mode = mode;
    if (mode == Mode.CONFERENCE) {
      _produce = true;
      _consume = true;
    } else {
      _produce = false;
      _consume = false;
    }

    _metaData = metaData;

    _signalingBaseUrl = signalingBaseUrl;

    _preferredProtocol = preferredProtocol.name;

    //
    localParticipant = Participant(
        id: participantId,
        displayName: displayName,
        isLocal: true,
        pinState: ParticipantPinState(),
        mode: _mode,
        eventEmitter: _eventEmitter,
        enablePeerMic: _enablePeerMic,
        disablePeerMic: _disablePeerMic,
        enablePeerCamera: _enablePeerCamera,
        disablePeerCamera: _disablePeerCamera,
        removePeer: _removePeer,
        setConsumerQuality: setConsumerQuality,
        setViewPort: setViewPort,
        getStats: _getStats,
        participantPinStateChanged: _participantPinStateChange,
        metaData: _metaData);

    //
    pubSub = PubSub(
      pubsubPublish: _pubsubPublish,
      pubsubSubscribe: _pubsubSubscribe,
      pubsubUnsubscribe: _pubsubUnsubscribe,
      topicEventEmitter: _topicEventEmitter,
    );

    _defaultCameraIndex = defaultCameraIndex;

    // now,calling in joinRoom()
    // getDefaultDevices(defaultCameraIndex);

    //
    _eventEmitter.on("peers-bloc-participant-joined", (Peer newPeer) {
      final newParticipant = Participant(
        id: newPeer.id,
        displayName: newPeer.displayName,
        isLocal: false,
        mode: newPeer.mode,
        pinState: ParticipantPinState(),
        eventEmitter: _eventEmitter,
        enablePeerMic: _enablePeerMic,
        disablePeerMic: _disablePeerMic,
        enablePeerCamera: _enablePeerCamera,
        disablePeerCamera: _disablePeerCamera,
        removePeer: _removePeer,
        setConsumerQuality: setConsumerQuality,
        setViewPort: setViewPort,
        getStats: _getStats,
        participantPinStateChanged: _participantPinStateChange,
        metaData: newPeer.metaData,
      );
      participants[newPeer.id] = newParticipant;
      _eventEmitter.emit('participant-joined', newParticipant);
    });

    //
    _eventEmitter.on("peers-bloc-participant-left", (peerId) {
      participants.remove(peerId);
      _eventEmitter.emit('participant-left', peerId);

      videoSDKTelemetery?.traceAutoComplete(
          spanName: 'Emitted `PARTICIPANT_LEFT` Event');
    });

    //
    _eventEmitter.on("pubsub-message", _handlePubSubMessage);

    //
    _eventEmitter.on("peers-bloc-presenter-changed", (peerId) {
      _activePresenterId = peerId;
      _eventEmitter.emit("presenter-changed", peerId);
      videoSDKTelemetery!
          .traceAutoComplete(spanName: 'Emitted `PRESENTER-CHANGED` Event');
    });

    _eventEmitter.on("INIT_CHARACTER", (character) {
      characters?[character.id] = character;
    });

    _eventEmitter.on("ADD_CHARACTER", (config) {
      var id = config['id'];
      Character? character = characters?[id];

      if (character == null) {
        CharacterConfig characterConfig = CharacterConfig.newInteraction(
            characterId: config['id'],
            characterMode: CharacterMode.values.firstWhere(
                (value) => value.name.toLowerCase() == config['characterMode']),
            displayName: config['displayName']);
        character = Character(
            characterConfig: characterConfig,
            eventEmitter: _eventEmitter,
            state: CharacterState.values
                .firstWhereOrNull((value) => value.name == config['state']),
            enablePeerMic: _enablePeerMic,
            disablePeerMic: _disablePeerMic,
            enablePeerCamera: _enablePeerCamera,
            disablePeerCamera: _disablePeerCamera,
            joinCharacter: _joinCharacter,
            removeCharacter: _removeCharacter,
            sendMessage: _sendCharacterMessage,
            interruptCharacter: _interruptCharacter);
        characters?[character.id] = character;
      }

      _eventEmitter.emit("character-joined", character);
      //To emit event from the character class
      _eventEmitter.emit("CHARACTER-JOINED", character);
    });

    _eventEmitter.on("REMOVE_CHARACTER", (config) {
      var id = config['id'];
      if (characters?.containsKey(id) == true) {
        Character character = characters?[id];
        _eventEmitter.emit("character-left", character);
        //To emit event from the character class
        _eventEmitter.emit("CHARACTER-LEFT", character);
        characters?.remove(id);
      }
    });

    _metricsCollector = VideoSDKMetrics(VideoSDKMetricsConfig(
        eventEmitter: _eventEmitter,
        name: "RoomMetrics",
        roomId: meetingId,
        peerId: participantId));
  }

  _getDefaultDevices(defaultCameraIndex) async {
    try {
      videoDevices = await VideoSDK.getVideoDevices();
      audioDevices = await VideoSDK.getAudioDevices();

      //If custom track is given, set the deviceId from custom track as the selected device.
      //Otherwise set the selected device as the first device, because
      //enableMicImpl needs a device to make a custom track
      if (_customMicrophoneAudioTrack != null) {
        _setSelectedMicId(customTrack: _customMicrophoneAudioTrack);
      } else {
        _selectedAudioInput = audioDevices
            ?.firstWhereOrNull((device) => device.kind == "audioinput");
      }

      //If custom track is given, set the deviceId from custom track as the selected device.
      //Otherwise set the selected device as the first device, because
      //enableCamImpl needs a device to make a custom track
      if (_customCameraVideoTrack != null) {
        _setSelectedCamId(customTrack: _customCameraVideoTrack);
      } else {
        _selectedVideoInput = videoDevices?[defaultCameraIndex];
      }

      //In windows, and iOS the newly connected devices are rendered at the last position.
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isIOS) {
          _selectedAudioOutput = audioDevices
              ?.lastWhereOrNull((device) => device.kind == "audiooutput");
        }
      }
      if (kIsWeb || Platform.isAndroid || Platform.isMacOS) {
        _selectedAudioOutput = audioDevices
            ?.firstWhereOrNull((device) => device.kind == "audiooutput");
      }

      List<AudioDeviceInfo>? tempAudioDevices =
          await VideoSDK.getAudioDevices();

      //Not available for MacOS
      VideoSDK.on(Events.deviceChanged, () async {
        videoDevices = await VideoSDK.getVideoDevices();
        audioDevices = await VideoSDK.getAudioDevices();
        if (!kIsWeb) {
          //In IOS and Windows the newly connected device is coming last in the list.
          if (Platform.isIOS || Platform.isWindows) {
            _selectedAudioOutput = audioDevices
                ?.lastWhereOrNull((device) => device.kind == "audiooutput");
            _selectedAudioInput = audioDevices
                ?.lastWhereOrNull((device) => device.kind == "audioinput");
          }
          //In android, deviceChange event coming even when switching from one device to another.
          // Change device id only when new device is connected/disconnected.
          else {
            //Get a new audio device list
            AudioDeviceInfo? device = audioDevices?.firstWhereOrNull(
                (newDevice) => !tempAudioDevices!.any(
                    (oldDevice) => oldDevice.deviceId == newDevice.deviceId));
            if (tempAudioDevices?.length != audioDevices?.length ||
                device?.deviceId != null) {
              _selectedAudioOutput = audioDevices
                  ?.firstWhereOrNull((device) => device.kind == "audiooutput");
              _selectedAudioInput = audioDevices
                  ?.firstWhereOrNull((device) => device.kind == "audioinput");
              tempAudioDevices = audioDevices;
            }
          }
        } else {
          _selectedAudioOutput = audioDevices
              ?.firstWhereOrNull((device) => device.kind == "audiooutput");
          _selectedAudioInput = audioDevices
              ?.firstWhereOrNull((device) => device.kind == "audioinput");
        }
      });
    } catch (error) {
      VideoSDKLog.createLog(
          message: "Error in get default media device \n ${error.toString()}",
          logLevel: "ERROR");

      log("Unable to set default media device $error");
    }
  }

  //
  String? get activeSpeakerId => _activeSpeakerId;

  //
  String? get activePresenterId => _activePresenterId;
  String get livestreamState => _livestreamState;
  String get hlsState => _hlsState;
  String get recordingState => _recordingState;
  String? get hlsDownstreamUrl => _hlsDownstreamUrl;
  Map<String, String?> get hlsUrls => _hlsUrls;

  //
  Future<void> muteMic() => _disableMic();

  //
  Future<void> unmuteMic([CustomTrack? customAudioTrack]) =>
      _enableMicImpl(customTrack: customAudioTrack);

  //
  Future<void> _disableMic({Span? parentSpan, bool trackEnded = false}) async {
    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in muteMic(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
      return;
    }
    Span? _disableMicSpan;

    try {
      _disableMicSpan = videoSDKTelemetery!.trace(
        spanName: 'disableMic() Calling',
        span: parentSpan,
      );
    } catch (error) {}

    //
    if (_micProducer != null) {
      //
      String micId = _micProducer!.id;

      _micInProgress = true;

      Span? internalSpan;
      try {
        if (_disableMicSpan != null) {
          internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Closing Mic Producer',
            span: _disableMicSpan,
          );
        }
      } catch (error) {}

      if (trackEnded) {
        _removeProducer(_micProducer!, _ProducerType.micProducer);
        _micProducer = null;
      } else {
        _micProducer!.pause();

        _eventEmitter.emit(
          "stream-disabled-${localParticipant.id}",
          {
            "audioConsumerId": _micProducer!.id,
          },
        );
      }

      try {
        //
        if (_webSocket != null) {
          await _webSocket!.socket.request(
            'closeProducer',
            {
              'producerId': micId,
            },
          );
        }

        if (internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: internalSpan,
            message: 'Requested Server to Close Producer',
            status: StatusCode.ok,
          );
          internalSpan = null;
        }

        if (_disableMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: _disableMicSpan,
            message: 'Mic Disabled Successfully',
            status: StatusCode.ok,
          );
          _disableMicSpan = null;
        }

        _micState = false;
      } catch (error) {
        Map<String, String> attributes = {
          "error": "Error in muteMic() :: Something went wrong.",
          "errorMessage": "Error in muteMic(): ${error.toString()}"
        };
        VideoSDKLog.createLog(
            message:
                "Something went wrong, and the microphone could not be disabled. Please try again.",
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in muteMic(): Something went wrong, and the microphone could not be disabled. Please try again.");

        if (internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: internalSpan,
            message:
                'Error closing server-side mic Producer \n ${error.toString()}',
            status: StatusCode.error,
          );
        }

        if (_disableMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: _disableMicSpan,
            message: 'Mic Disabled Failed',
            status: StatusCode.error,
          );
        }
      } finally {
        _micInProgress = false;
      }
    } else {
      //
      try {
        if (_disableMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: _disableMicSpan,
            message: 'Mic Producer Not found',
            status: StatusCode.error,
          );
        }
      } catch (e) {}

      Map<String, String> attributes = {
        "error": "Error in muteMic() :: Microphone is already disabled."
      };
      VideoSDKLog.createLog(
          message:
              "Attempted to call muteMic() while the microphone is already disabled",
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in muteMic(): Attempted to call muteMic() while the microphone is already disabled");
    }
  }

  //
  Future<void> _enableMicImpl(
      {CustomTrack? customTrack, Span? parentSpan}) async {
    //If method is called before meeting is joined
    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in unmuteMic(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
      if (customTrack != null) {
        customTrack.dispose();
      }
      return;
    }
    Span? enableMicSpan;
    Span? micProducerSpan;
    AudioDeviceInfo? deviceToSwitch;

    try {
      enableMicSpan = videoSDKTelemetery!.trace(
        spanName:
            'enableMic() Calling ${customTrack != null ? 'With Custom Audio Track' : 'Without Custom Audio Track'}',
        attributes: [
          Attribute.fromString(
              'customTrack',
              customTrack != null
                  ? customTrack.toMap().toString()
                  : 'Not Specify Custom Track'),
        ],
        span: parentSpan,
      );
    } catch (error) {}

    if (_micInProgress) {
      try {
        if (enableMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: enableMicSpan,
            status: StatusCode.error,
            message: 'enableMic() Failed | microphone is in progress',
          );
        }
        Map<String, String> attributes = {
          "error": "Error in unmuteMic() :: Microphone is already enabled."
        };
        VideoSDKLog.createLog(
            message:
                "Attempted to call unmuteMic() while the microphone is already enabled",
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in unmuteMic(): Attempted to call unmuteMic() while the microphone is already enabled");
      } catch (error) {}
      if (customTrack != null) {
        customTrack.dispose();
      }
      return;
    }

    _micInProgress = true;

    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isIOS) {
        if (customTrack != null && customTrack.microphoneId != null) {
          var speakers = await VideoSDK.getAudioDevices();
          deviceToSwitch = speakers?.firstWhereOrNull(
              (speaker) => speaker.deviceId == customTrack?.microphoneId);
        }
      }
    }

    if (customTrack != null) {
      if (customTrack.ended == true) {
        customTrack = null;
        _eventEmitter.emit("error", VideoSDKErrors[3002]);

        Map<String, String> attributes = {
          "error":
              "Error in unmuteMic(): Provided Custom Track has been disposed."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3002]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in unmuteMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3002]?['code']}  :: ${VideoSDKErrors[3002]?['name']} :: ${VideoSDKErrors[3002]?['message']}");
      }
    }

    //If mic is unmuted other than the first time.
    if (_micProducer != null) {
      try {
        if (enableMicSpan != null) {
          micProducerSpan = videoSDKTelemetery!.trace(
            spanName: 'Mic Producer found, Mic Producer Resuming Start',
            span: enableMicSpan,
          );
        }
      } catch (error) {}

      if (customTrack != null) {
        if (_customMicrophoneAudioTrack != null) {
          _customMicrophoneAudioTrack!.dispose();
          _customMicrophoneAudioTrack = null;
        }
        //This is because _customMicrophoneTrack is disposed here,
        //but used the next time as customTrack in case a track is not provided
        // (here : customTrack ??= _customMicrophoneAudioTrack;)
        _customMicrophoneAudioTrack = customTrack;
      }

      if (!_micProducer!.closed && _micProducer!.paused) {
        _micProducer!.resume();
      }

      //
      MediaStream? audioStream;
      MediaStreamTrack? track;
      Map<String, dynamic>? encoderConfig;
      ProducerCodecOptions? codecOptions;

      customTrack ??= _customMicrophoneAudioTrack;

      audioStream = customTrack!.mediaStream;
      track = audioStream.getAudioTracks().first;
      encoderConfig =
          customAudioTrackConfigMap[customTrack.audioEncoderConfig]!;

      if (encoderConfig != null) {
        codecOptions = ProducerCodecOptions(
          opusStereo: encoderConfig["stereo"] ? 1 : 0,
          opusFec: encoderConfig["fec"] ? 1 : 0,
          opusDtx: encoderConfig["dtx"] ? 1 : 0,
          opusMaxPlaybackRate: encoderConfig["maxPlaybackRate"],
          opusPtime: encoderConfig["packetTime"],
          // opusMaxAverageBitrate: encoderConfig["bitRate"]
        );
      }

      if (_sendTransport != null) {
        _sendTransport!.produce(
          track: track,
          codecOptions: codecOptions,
          stream: audioStream,
          appData: {
            'source': 'mic',
            'encoderConfig': encoderConfig,
          },
          stopTracks: false,
          source: 'mic',
        );
      } else {
        try {
          if (micProducerSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: micProducerSpan,
              status: StatusCode.error,
              message: 'Mic Producer Resuming failed',
            );
          }

          if (enableMicSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: enableMicSpan,
              status: StatusCode.error,
              message: 'Enable Mic UnSuccessful, _sendTransport is null.',
            );
          }
        } catch (error) {}

        _eventEmitter.emit("error", VideoSDKErrors[3012]);

        Map<String, String> attributes = {
          "error": "Error in unmuteMic(): Something went wrong.",
          "errorMessage": "unmuteMic(): _sendTransport is null."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3012]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in unmuteMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3012]?['code']}  :: ${VideoSDKErrors[3012]?['name']} :: ${VideoSDKErrors[3012]?['message']}");
        if (customTrack != null) {
          customTrack.dispose();
        }
        _micInProgress = false;
        return;
      }

      try {
        if (micProducerSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: micProducerSpan,
            status: StatusCode.ok,
            message: 'Mic Producer Resuming end',
          );
        }

        if (enableMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: enableMicSpan,
            status: StatusCode.ok,
            message: 'Enable Mic Successful',
          );
        }

        _micState = true;

        if (kIsWeb || Platform.isWindows || Platform.isMacOS) {
          _setSelectedMicId(customTrack: customTrack);
        } else {
          if (deviceToSwitch != null) {
            switchAudioDevice(deviceToSwitch);
          }
        }
      } catch (error) {}

      return;
    }

    _micInProgress = true;

    //
    if (_device?.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio) == false) {
      _eventEmitter.emit("error", VideoSDKErrors[3020]);
      //
      Map<String, String> attributes = {
        "error": "Error in unmuteMic(): Device cannot produce audio."
      };
      VideoSDKLog.createLog(
          message: VideoSDKErrors[3020]!['message']!,
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in unmuteMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3020]?['code']}  :: ${VideoSDKErrors[3020]?['name']} :: ${VideoSDKErrors[3020]?['message']}");

      //
      try {
        if (enableMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: enableMicSpan,
            status: StatusCode.error,
            message: 'enableMic() | cannot produce audio',
          );
        }
      } catch (error) {}
      if (customTrack != null) {
        customTrack.dispose();
      }
      _micInProgress = false;
      return;
    }

    if (customTrack == null) {
      Span? internalSpan;
      try {
        if (enableMicSpan != null) {
          internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Creating Track',
            span: enableMicSpan,
          );
        }
      } catch (error) {}

      customTrack = await VideoSDK.createMicrophoneAudioTrack(
          microphoneId: _selectedAudioInput?.deviceId,
          encoderConfig: CustomAudioTrackConfig.speech_standard);

      //If there is an error, createMicrophoneAudioTrack will return null.
      if (customTrack == null) {
        try {
          if (internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: internalSpan,
              status: StatusCode.error,
              message: 'enableMic() | Track could not be created',
            );
          }
          if (enableMicSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: enableMicSpan,
              status: StatusCode.error,
              message:
                  'enableMic() | Cannot produce audio, some error occured while creating audio track.',
            );
          }
        } catch (error) {}

        _eventEmitter.emit("error", VideoSDKErrors[3012]);
        Map<String, String> attributes = {
          "error": "Error in unmuteMic(): Something went wrong.",
          "errorMessage":
              "Error in unmuteMic() : Custom Track could not be created."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3012]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in unmuteMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3012]?['code']}  :: ${VideoSDKErrors[3012]?['name']} :: ${VideoSDKErrors[3012]?['message']}");

        _micInProgress = false;
        return;
      }

      try {
        if (internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
              message: 'Audio Track Generated',
              span: internalSpan,
              status: StatusCode.ok);
        }
      } catch (error) {}
    }

    _customMicrophoneAudioTrack = customTrack;

    //Updating the list, in case permission status has changed.
    //(As in web, device labels and ids are not available w/o media permissions.)
    //await VideoSDK.loadMediaDevices();
    audioDevices = await VideoSDK.getAudioDevices();

    //
    MediaStream? audioStream;
    MediaStreamTrack? track;

    Span? _internalSpan;
    //
    try {
      try {
        if (enableMicSpan != null) {
          _internalSpan = videoSDKTelemetery!.trace(
              spanName: 'Generating Producer Configuration',
              span: enableMicSpan);
        }
      } catch (error) {}
      //
      audioStream = customTrack.mediaStream;
      //
      track = audioStream.getAudioTracks().first;

      Map<String, dynamic> encoderConfig =
          customAudioTrackConfigMap[customTrack.audioEncoderConfig]!;

      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              message: 'Producer Configuration Generated',
              status: StatusCode.ok);
        }
      } catch (error) {}

      try {
        if (enableMicSpan != null) {
          videoSDKTelemetery!.traceAutoComplete(
              spanName:
                  'EncoderConfig Generated for ${customTrack.audioEncoderConfig}',
              span: enableMicSpan,
              attributes: [
                Attribute.fromString('encoderConfig', encoderConfig.toString())
              ]);
        }
      } catch (error) {}

      try {
        if (enableMicSpan != null) {
          _internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Creating Mic Producer',
            span: enableMicSpan,
          );
        }
      } catch (error) {}

      ProducerCodecOptions codecOptions = ProducerCodecOptions(
        opusStereo: encoderConfig["stereo"] ? 1 : 0,
        opusFec: encoderConfig["fec"] ? 1 : 0,
        opusDtx: encoderConfig["dtx"] ? 1 : 0,
        opusMaxPlaybackRate: encoderConfig["maxPlaybackRate"],
        opusPtime: encoderConfig["packetTime"],
        // opusMaxAverageBitrate: encoderConfig["bitRate"]
      );

      //
      if (_sendTransport != null) {
        _sendTransport!.produce(
          track: track,
          codecOptions: codecOptions,
          stream: audioStream,
          appData: {
            'source': 'mic',
            'encoderConfig': encoderConfig,
          },
          stopTracks: false,
          source: 'mic',
        );
      } else {
        try {
          if (_internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              status: StatusCode.error,
              message: 'Send transport is null',
            );
          }

          if (enableMicSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: enableMicSpan,
              status: StatusCode.error,
              message:
                  'Mic could not be enabled, method was called when send transport was null.',
            );
          }
        } catch (error) {}

        _eventEmitter.emit("error", VideoSDKErrors[3012]);

        Map<String, String> attributes = {
          "error": "Error in unmuteMic(): Something went wrong.",
          "errorMessage": "unmuteMic(): _sendTransport is null."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3012]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in unmuteMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3012]?['code']}  :: ${VideoSDKErrors[3012]?['name']} :: ${VideoSDKErrors[3012]?['message']}");
        if (customTrack != null) {
          customTrack.dispose();
        }
        if (audioStream != null) {
          await audioStream.dispose();
        }
        _micInProgress = false;
        return;
      }

      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: _internalSpan,
            status: StatusCode.ok,
            message: 'Mic Producer Created',
          );
        }
      } catch (error) {}

      try {
        if (enableMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: enableMicSpan,
            status: StatusCode.ok,
            message: 'Enable Mic Successful',
          );
        }

        _micState = true;

        if (kIsWeb || Platform.isWindows || Platform.isMacOS) {
          _setSelectedMicId(customTrack: customTrack);
        } else {
          if (deviceToSwitch != null) {
            switchAudioDevice(deviceToSwitch);
          }
        }
      } catch (error) {}
    } catch (error) {
      _micInProgress = false;
      //
      _eventEmitter.emit("error", VideoSDKErrors[3012]);
      Map<String, String> attributes = {
        "error": "Error in unmuteMic(): Something went wrong.",
        "errorMessage": "Error in unmuteMic() : ${error.toString()}."
      };
      VideoSDKLog.createLog(
          message: VideoSDKErrors[3012]!['message']!,
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in unmuteMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3012]?['code']}  :: ${VideoSDKErrors[3012]?['name']} :: ${VideoSDKErrors[3012]?['message']}");

      //
      if (audioStream != null) {
        await audioStream.dispose();
      }

      if (_internalSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: _internalSpan,
          status: StatusCode.error,
          message: 'Mic Producer Creation Failed',
        );
      }

      if (enableMicSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: enableMicSpan,
          status: StatusCode.error,
          message: 'Enable Mic Failed \n ${error.toString()}',
        );
      }
    }
  }

  Future<void> _setSelectedMicId({CustomTrack? customTrack}) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    try {
      MediaStreamTrack? track = customTrack?.mediaStream.getAudioTracks().first;
      if (!kIsWeb) {
        //For devices other than web directly getting deviceId on customTrack
        if (track != null && track.getSettings().containsKey("deviceId")) {
          AudioDeviceInfo? device = audioDevices?.firstWhereOrNull(
            (device) =>
                device.deviceId == track.getSettings()["deviceId"] &&
                device.kind == "audioinput",
          );
          _selectedAudioInput = device;
        }
      } else {
        if (track != null && track.label != null) {
          AudioDeviceInfo? device = audioDevices?.firstWhereOrNull(
            (device) =>
                device.label == track.label && device.kind == "audioinput",
          );
          _selectedAudioInput = device;
        }
      }
    } catch (e) {}
  }

  Future<void> enableCam([CustomTrack? customAudioTrack]) =>
      _enableCamImpl(customTrack: customAudioTrack);

  //
  Future<void> _enableCamImpl(
      {CustomTrack? customTrack, Span? parentSpan}) async {
    //If method is called before meeting is joined
    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in enableCam(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
      if (customTrack != null) {
        customTrack.dispose();
      }
      return;
    }
    // send trace enableCam
    Span? enableWebcamSpan;
    try {
      if (videoSDKTelemetery != null) {
        enableWebcamSpan = videoSDKTelemetery!.trace(
          spanName:
              'enableWebcam() Calling ${customTrack != null ? 'With Custom Video Track' : 'Without Custom Video Track'}',
          attributes: [
            Attribute.fromString(
                'customVideoConfig',
                customTrack != null
                    ? customTrack.toMap().toString()
                    : 'Not Specify Custom Track'),
          ],
          span: parentSpan,
        );
      }
    } catch (error) {}

    //If camera is already enabled, return without enabling it again
    if (_cameraInProgress) {
      try {
        if (enableWebcamSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: enableWebcamSpan,
            status: StatusCode.error,
            message: 'enableWebcam() Failed | camera is in progress',
          );
        }
        Map<String, String> attributes = {
          "error": "Error in enableCam() :: Webcam is already enabled."
        };
        VideoSDKLog.createLog(
            message:
                "Attempted to call enableCam() while the webcam is already enabled",
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableCam(): Attempted to call enableCam() while the webcam is already enabled");
      } catch (error) {}
      if (customTrack != null) {
        customTrack.dispose();
      }
      return;
    }

    _cameraInProgress = true;

    //If the device is incapable of producing video
    if (_device?.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo) == false) {
      _eventEmitter.emit("error", VideoSDKErrors[3019]);

      Map<String, String> attributes = {
        "error": "Error in enableCam(): Device cannot produce video."
      };
      VideoSDKLog.createLog(
          message: VideoSDKErrors[3019]!['message']!,
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in enableCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3019]?['code']}  :: ${VideoSDKErrors[3019]?['name']} :: ${VideoSDKErrors[3019]?['message']}");

      try {
        if (enableWebcamSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: enableWebcamSpan,
            status: StatusCode.error,
            message: 'enableWebcam() | device cannot produce video',
          );
        }
      } catch (error) {}

      if (customTrack != null) {
        customTrack.dispose();
      }
      _cameraInProgress = false;
      return;
    }

    //If user has given a track that has been disposed.
    if (customTrack != null) {
      if (customTrack.ended == true) {
        customTrack = null;
        _eventEmitter.emit("error", VideoSDKErrors[3001]);

        Map<String, String> attributes = {
          "error":
              "Error in enableCam(): Provided Custom Track has been disposed."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3001]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3001]?['code']}  :: ${VideoSDKErrors[3001]?['name']} :: ${VideoSDKErrors[3001]?['message']}");
      }
    }

    if (customTrack == null) {
      Span? _internalSpan;
      try {
        if (enableWebcamSpan != null) {
          _internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Creating Track',
            span: enableWebcamSpan,
          );
        }
      } catch (error) {}

      customTrack = await VideoSDK.createCameraVideoTrack(
          cameraId: _selectedVideoInput?.deviceId,
          multiStream: _multiStream,
          encoderConfig: CustomVideoTrackConfig.h720p_w1280p);

      //If there is an error, createCameraVideoTrack will return null.
      if (customTrack == null) {
        try {
          if (_internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              status: StatusCode.error,
              message: 'enableWebcam() | Track could not be created',
            );
          }
          if (enableWebcamSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: enableWebcamSpan,
              status: StatusCode.error,
              message:
                  'enableWebcam() | Cannot produce video, some error occured while creating video track.',
            );
          }
        } catch (error) {}

        _eventEmitter.emit("error", VideoSDKErrors[3011]);
        Map<String, String> attributes = {
          "error": "Error in enableCam(): Something went wrong.",
          "errorMessage":
              "Error in enableCam() : Custom Track could not be created."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3011]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3011]?['code']}  :: ${VideoSDKErrors[3011]?['name']} :: ${VideoSDKErrors[3011]?['message']}");

        _cameraInProgress = false;
        return;
      }

      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
              message: 'WebCam Track Generated',
              span: _internalSpan,
              status: StatusCode.ok);
        }
      } catch (error) {}
    }

    MediaStream? videoStream;
    MediaStreamTrack? track;
    Span? _internalSpan;

    //Updating the list, in case permission status has changed.
    //(As in web, device labels and ids are not available w/o media permissions.)
    //await VideoSDK.loadMediaDevices();
    videoDevices = await VideoSDK.getVideoDevices();

    try {
      try {
        if (enableWebcamSpan != null) {
          _internalSpan = videoSDKTelemetery!.trace(
              spanName: 'Generating Producer Configuration',
              span: enableWebcamSpan);
        }
      } catch (error) {}

      RtpCodecCapability? codec;
      // NOTE: prefer using h264
      if (_device != null) {
        codec = _device!.rtpCapabilities.codecs.firstWhere(
            (RtpCodecCapability c) {
          return c.mimeType.toLowerCase() == 'video/vp9' ||
              c.mimeType.toLowerCase() == 'video/vp8';
        },
            // (RtpCodecCapability c) => c.mimeType.toLowerCase() == 'video/h264',
            orElse: () {
          //
          VideoSDKLog.createLog(
              message:
                  "Error in enableCam() \n desired vp9 codec+configuration is not supported",
              logLevel: "ERROR");

          try {
            if (_internalSpan != null) {
              videoSDKTelemetery!.completeSpan(
                span: _internalSpan,
                status: StatusCode.error,
                message: 'Webcam Producer Creation Failed',
              );
            }

            if (enableWebcamSpan != null) {
              videoSDKTelemetery!.completeSpan(
                span: enableWebcamSpan,
                status: StatusCode.error,
                message:
                    'Enable Webcam Failed \n desired vp9 codec+configuration is not supported',
              );
            }
          } catch (e) {}
          //
          throw UnsupportedError(
              "Device does not support vp9 codec+configuration");
        });
      } else {
        try {
          if (_internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              status: StatusCode.error,
              message: 'MediaSoup device not found',
            );
          }

          if (enableWebcamSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: enableWebcamSpan,
              status: StatusCode.error,
              message: 'Enable Webcam Failed \n Mediasoup device not found',
            );
          }
        } catch (e) {}

        _eventEmitter.emit("error", VideoSDKErrors[3011]);

        Map<String, String> attributes = {
          "error": "Error in enableCam(): Something went wrong.",
          "errorMessage": "enableCam(): MediaSoup device not found."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3011]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3011]?['code']}  :: ${VideoSDKErrors[3011]?['name']} :: ${VideoSDKErrors[3011]?['message']}");
        if (customTrack != null) {
          customTrack.dispose();
        }
        _cameraInProgress = false;
        return;
      }

      videoStream = customTrack.mediaStream;

      track = videoStream.getVideoTracks().first;

      // check browser is Firefox or not
      bool isFirefox =
          deviceInfo['browserUserAgent']?['browser']?['name'] == "Firefox";

      List<RtpEncodingParameters> encodings =
          SdkCapabilities.computeVideoEncodings(
              false,
              customVideotrackConfigMap[customTrack.videoEncoderConfig]![
                  "width"],
              customVideotrackConfigMap[customTrack.videoEncoderConfig]![
                  "height"],
              {"simulcast": isFirefox ? false : customTrack.multiStream});

      if (kIsWeb) {
        encodings = encodings.reversed.toList();
      }

      Map<String, dynamic> appData = {
        'source': 'webcam',
        'width':
            customVideotrackConfigMap[customTrack.videoEncoderConfig]!["width"],
        'height': customVideotrackConfigMap[customTrack.videoEncoderConfig]![
            "height"],
      };
      appData['encodings'] = [];

      encodings.forEach((encoding) {
        appData['encodings'].add(encoding.toMap());
      });

      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              message: 'Producer Configuration Generated',
              status: StatusCode.ok);
        }
      } catch (error) {}

      try {
        if (enableWebcamSpan != null) {
          videoSDKTelemetery!.traceAutoComplete(
              spanName:
                  'Track Generated with height ${appData['height']} and width ${appData['width']} with multiStream ${customTrack.multiStream}',
              span: enableWebcamSpan,
              attributes: [
                Attribute.fromString('appData', appData.toString())
              ]);
        }
      } catch (error) {}

      try {
        if (enableWebcamSpan != null) {
          _internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Creating Webcam Producer',
            span: enableWebcamSpan,
          );
        }
      } catch (error) {}

      if (_sendTransport != null) {
        _sendTransport!.produce(
          track: track,
          codecOptions: ProducerCodecOptions(
            videoGoogleStartBitrate: 1000,
          ),
          encodings: encodings,
          stream: videoStream,
          appData: appData,
          source: 'webcam',
          codec: codec,
        );
      } else {
        try {
          if (_internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              status: StatusCode.error,
              message: 'Send transport is null',
            );
          }

          if (enableWebcamSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: enableWebcamSpan,
              status: StatusCode.error,
              message:
                  'Webcam could not be enabled, method was called when send transport was null.',
            );
          }
        } catch (error) {}

        _eventEmitter.emit("error", VideoSDKErrors[3011]);

        Map<String, String> attributes = {
          "error": "Error in enableCam(): Something went wrong.",
          "errorMessage": "enableCam(): _sendTransport is null."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3011]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3011]?['code']}  :: ${VideoSDKErrors[3011]?['name']} :: ${VideoSDKErrors[3011]?['message']}");
        if (customTrack != null) {
          customTrack.dispose();
        }
        if (videoStream != null) {
          await videoStream.dispose();
        }
        _cameraInProgress = false;
        return;
      }

      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: _internalSpan,
            status: StatusCode.ok,
            message: 'Webcam Producer Created',
          );
        }
      } catch (error) {}

      try {
        if (enableWebcamSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: enableWebcamSpan,
            status: StatusCode.ok,
            message: 'Enable Webcam Successful',
          );
        }

        _camState = true;
        _cameraInProgress = true;
        _setSelectedCamId(customTrack: customTrack);
      } catch (error) {}
    } catch (error) {
      //
      _cameraInProgress = false;

      if (videoStream != null) {
        await videoStream.dispose();
      }
      _eventEmitter.emit("error", VideoSDKErrors[3011]);
      Map<String, String> attributes = {
        "error": "Error in enableCam(): Something went wrong.",
        "errorMessage": "Error in enableCam() : ${error.toString()}."
      };
      VideoSDKLog.createLog(
          message: VideoSDKErrors[3011]!['message']!,
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in enableCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3011]?['code']}  :: ${VideoSDKErrors[3011]?['name']} :: ${VideoSDKErrors[3011]?['message']}");

      if (_internalSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: _internalSpan,
          status: StatusCode.error,
          message: 'Webcam Producer Creatation Failed',
        );
      }

      if (enableWebcamSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: enableWebcamSpan,
          status: StatusCode.error,
          message: 'Enable Webcam Failed \n ${error.toString()}',
        );
      }
    }
  }

  Future<void> _setSelectedCamId({CustomTrack? customTrack}) async {
    try {
      MediaStreamTrack? track = customTrack?.mediaStream.getVideoTracks().first;
      if (!kIsWeb) {
        //For devices other than web directly getting deviceId on customTrack
        if (track != null && track.getSettings().containsKey("deviceId")) {
          VideoDeviceInfo? device = videoDevices?.firstWhereOrNull(
            (device) => device.deviceId == track.getSettings()["deviceId"],
          );
          _selectedVideoInput = device;
        }
      } else {
        if (track != null && track.label != null) {
          VideoDeviceInfo? device = videoDevices?.firstWhereOrNull(
            (device) => device.label == track.label,
          );
          _selectedVideoInput = device;
        }
      }
    } catch (e) {}
  }

  Future<void> disableCam() => _disableCamImpl();

  //
  Future<void> _disableCamImpl({Span? parentSpan}) async {
    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in disableCam(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
      return;
    }

    Span? disableWebcamSpan;
    try {
      if (videoSDKTelemetery != null) {
        disableWebcamSpan = videoSDKTelemetery!.trace(
          spanName: 'disableWebcam() Calling',
          span: parentSpan,
        );
      }
    } catch (error) {}

    //
    if (_cameraProducer != null) {
      //
      String? cameraId = _cameraProducer?.id;
      //
      _cameraInProgress = true;

      //
      _removeProducer(_cameraProducer!, _ProducerType.cameraProducer);
      _cameraProducer = null;

      Span? internalSpan;
      try {
        if (disableWebcamSpan != null) {
          internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Closing Webcam Producer',
            span: disableWebcamSpan,
          );
        }
      } catch (error) {}

      try {
        //
        if (_webSocket != null) {
          await _webSocket!.socket.request('closeProducer', {
            'producerId': cameraId,
          });
        }

        if (internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: internalSpan,
            message: 'Requested Server to Close Producer',
            status: StatusCode.ok,
          );
        }

        if (disableWebcamSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: disableWebcamSpan,
            message: 'Webcam Disabled Successfully',
            status: StatusCode.ok,
          );
        }

        _camState = false;
      } catch (error) {
        Map<String, String> attributes = {
          "error": "Error in disableWebcam() :: Something went wrong.",
          "errorMessage": "Error in disableWebcam(): ${error.toString()}"
        };
        VideoSDKLog.createLog(
            message:
                "Something went wrong, and the webCam could not be disabled. Please try again.",
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in disableCam(): Something went wrong, and the webCam could not be disabled. Please try again.");

        if (internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: internalSpan,
            message: 'Close Producer Request Failed, WebCam disabled Failed ',
            status: StatusCode.error,
          );
        }

        if (disableWebcamSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: disableWebcamSpan,
            message: 'webcam Disabled failed \n ${error.toString()}',
            status: StatusCode.error,
          );
        }
      } finally {
        //
        _cameraInProgress = false;
      }
    } else {
      try {
        if (disableWebcamSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: disableWebcamSpan,
            message: 'Webcam Producer Not found',
            status: StatusCode.error,
          );
        }
      } catch (error) {}
      Map<String, String> attributes = {
        "error": "Error in disableCam() :: Webcam is already disabled."
      };
      VideoSDKLog.createLog(
          message:
              "Attempted to call disableCam() while the webcam is already disabled",
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in disableCam(): Attempted to call disableCam() while the webcam is already disabled");
    }
  }

  Future<List<DesktopCapturerSource>> getScreenShareSources() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      List<DesktopCapturerSource> sources = await desktopCapturer
          .getSources(types: [SourceType.Screen, SourceType.Window]);

      sources.asMap().forEach((key, value) {
        log("Screenshare source name:${value.name}");
      });

      return sources;
    } else {
      throw UnsupportedError(
          'The getScreenShareSources() method is only supported for desktop apps.');
    }
  }

  Future<void> enableScreenShare([DesktopCapturerSource? source]) async {
    await enableShare(source);
  }

  //
  Future<void> enableShare(DesktopCapturerSource? source,
      {bool iosPermissionGiven = false}) async {
    //
    if (_screenShareInProgress) {
      Map<String, String> attributes = {
        "error":
            "Error in enableScreenShare() :: Screenshare in already enabled."
      };
      VideoSDKLog.createLog(
          message:
              "Attempted to call enableScreenShare() while the screenshare is already enabled",
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in enableScreenShare(): Attempted to call enableScreenShare() while the screenshare is already enabled");

      return;
    }

    if (source == null) {
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
        var sources =
            await desktopCapturer.getSources(types: [SourceType.Screen]);

        _selectedScreenSource = sources.first;
      }
    } else {
      _selectedScreenSource = source;
    }

    Span? enableShareSpan;

    try {
      if (videoSDKTelemetery != null) {
        enableShareSpan = videoSDKTelemetery!.trace(
          spanName: 'enableShare() Calling',
        );
      }
    } catch (error) {}

    if (_isMobilePlatform()) {
      if (Platform.isIOS && !iosPermissionGiven) {
        VideoSDK.requestIOSScreenSharePermission();
        return;
      }

      if (Platform.isAndroid) {
        try {
          bool androidPermission = await Helper.requestCapturePermission();

          if (!androidPermission) {
            if (enableShareSpan != null) {
              videoSDKTelemetery!.completeSpan(
                  span: enableShareSpan,
                  message: 'Permission not granted in android',
                  status: StatusCode.error);
            }

            _eventEmitter.emit("error", VideoSDKErrors[3014]);
            Map<String, String> attributes = {
              "error":
                  "Error in enableScreenShare() : Screenshare Permission denied."
            };
            VideoSDKLog.createLog(
                message: VideoSDKErrors[3014]!['message']!,
                logLevel: "ERROR",
                attributes: attributes,
                dashboardLog: true);
            print(
                "An error occurred in enableScreenShare() : VIDEOSDK ERROR :: ${VideoSDKErrors[3014]?['code']}  :: ${VideoSDKErrors[3014]?['name']} :: ${VideoSDKErrors[3014]?['message']}");

            return;
          }

          //
          await FlutterForegroundTask.startService(
              notificationTitle: _notification.title,
              notificationText: _notification.message,
              callback: null);
        } catch (error) {
          _eventEmitter.emit("error", VideoSDKErrors[3016]);
          Map<String, String> attributes = {
            "error":
                "Error in enableScreenShare(): Failed to initialize the foreground service."
          };
          VideoSDKLog.createLog(
              message: VideoSDKErrors[3016]!['message']!,
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3016]?['code']}  :: ${VideoSDKErrors[3016]?['name']} :: ${VideoSDKErrors[3016]?['message']}");

          if (enableShareSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: enableShareSpan,
                message:
                    'error in starting foreground service ${error.toString()}',
                status: StatusCode.error);
          }
          return;
        }
      }
    }

    //
    _screenShareInProgress = true;

    //
    MediaStream? shareStream;
    MediaStreamTrack? videoTrack;
    MediaStreamTrack? audioTrack;

    Span? _internalSpan;
    Span? trackSpan;
    Span? producerSpan;
    Span? audioProducerSpan;
    try {
      try {
        if (enableShareSpan != null) {
          _internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Generating Producer Configuration',
            span: enableShareSpan,
          );
        }
      } catch (error) {}
      //
      RtpCodecCapability? videoCodec;

      if (_device != null) {
        videoCodec = _device!.rtpCapabilities.codecs.firstWhere(
            (RtpCodecCapability c) {
          return c.mimeType.toLowerCase() == 'video/vp9' ||
              c.mimeType.toLowerCase() == 'video/vp8';
        },
            // (RtpCodecCapability c) => c.mimeType.toLowerCase() == 'video/h264',
            orElse: () {
          //
          VideoSDKLog.createLog(
              message:
                  "Error in enableShare() \n desired vp9 codec+configuration is not supported",
              logLevel: "ERROR");

          if (_internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: _internalSpan,
                message: 'vp9 codec+configuration is not supported',
                status: StatusCode.error);
          }

          if (enableShareSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: enableShareSpan,
                message: 'vp9 codec+configuration is not supported',
                status: StatusCode.error);
          }
          //
          throw 'desired vp9 codec+configuration is not supported';
        });
      } else {
        try {
          if (_internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              status: StatusCode.error,
              message: 'MediaSoup device not found',
            );
          }

          if (enableShareSpan != null) {
            videoSDKTelemetery!.completeSpan(
              span: enableShareSpan,
              status: StatusCode.error,
              message:
                  'Enable Screenshare Failed \n Mediasoup device not found',
            );
          }
        } catch (e) {}

        _eventEmitter.emit("error", VideoSDKErrors[3013]);

        Map<String, String> attributes = {
          "error": "Error in enableScreenShare(): Something went wrong.",
          "errorMessage": "enableScreenShare(): MediaSoup device not found."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3013]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3013]?['code']}  :: ${VideoSDKErrors[3013]?['name']} :: ${VideoSDKErrors[3013]?['message']}");
        _screenShareInProgress = false;
        if (!kIsWeb) {
          if (Platform.isAndroid) {
            //
            FlutterForegroundTask.stopService();
          }
        }
        return;
      }

      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              message: 'Producer Configuration Generated',
              status: StatusCode.ok);

          _internalSpan = null;
        }
      } catch (error) {}

      //
      shareStream = await _createShareStream(enableShareSpan);

      if (shareStream != null) {
        try {
          if (enableShareSpan != null) {
            trackSpan = videoSDKTelemetery!.trace(
              spanName: 'Creating Track',
              span: enableShareSpan,
            );
          }
        } catch (error) {}

        //
        videoTrack = shareStream.getVideoTracks().first;
        if (shareStream.getAudioTracks().isNotEmpty) {
          audioTrack = shareStream.getAudioTracks().first;
        }

        try {
          if (trackSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: trackSpan,
                message:
                    'Track Generated with videoTrack ${videoTrack.toString()} & audioTrack ${audioTrack != null ? audioTrack.toString() : 'No audio'}',
                status: StatusCode.ok);

            trackSpan = null;
          }
        } catch (error) {}

        //
        _screenShareInProgress = true;

        try {
          if (enableShareSpan != null) {
            producerSpan = videoSDKTelemetery!.trace(
              spanName: 'Creating Share Producer',
              span: enableShareSpan,
            );
          }
        } catch (error) {}
        //
        if (_sendTransport != null) {
          _sendTransport!.produce(
            track: videoTrack,
            codecOptions: ProducerCodecOptions(
              videoGoogleStartBitrate: 1000,
            ),
            stream: shareStream,
            appData: {'share': true},
            source: 'screen',
            codec: videoCodec,
          );
        } else {
          try {
            if (producerSpan != null) {
              videoSDKTelemetery!.completeSpan(
                  span: producerSpan,
                  message:
                      'Screenshare Video Producer could not be Created, _sendTransport is null',
                  status: StatusCode.error);

              producerSpan = null;
            }
          } catch (error) {}

          _eventEmitter.emit("error", VideoSDKErrors[3013]);

          Map<String, String> attributes = {
            "error": "Error in enableScreenShare(): Something went wrong.",
            "errorMessage": "enableScreenShare(): _sendTransport is null."
          };
          VideoSDKLog.createLog(
              message: VideoSDKErrors[3013]!['message']!,
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3013]?['code']}  :: ${VideoSDKErrors[3013]?['name']} :: ${VideoSDKErrors[3013]?['message']}");
          if (shareStream != null) {
            await shareStream.dispose();
          }
          _screenShareInProgress = false;
          if (!kIsWeb) {
            if (Platform.isAndroid) {
              //
              FlutterForegroundTask.stopService();
            }
          }
          return;
        }

        try {
          if (producerSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: producerSpan,
                message: 'Share Producer Created',
                status: StatusCode.ok);

            producerSpan = null;
          }
        } catch (error) {}

        if (audioTrack != null) {
          try {
            if (enableShareSpan != null) {
              audioProducerSpan = videoSDKTelemetery!.trace(
                spanName: 'Creating Share Audio Producer',
                span: enableShareSpan,
              );
            }
          } catch (error) {}

          if (_sendTransport != null) {
            _sendTransport!.produce(
                track: audioTrack,
                codecOptions: ProducerCodecOptions(
                  opusStereo: 1,
                  opusDtx: 1,
                ),
                stream: shareStream,
                appData: {'share': true},
                source: 'screen-audio');
          } else {
            try {
              if (audioProducerSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: audioProducerSpan,
                    message:
                        'Screenshare Audio Producer could not be Created, _sendTransport is null',
                    status: StatusCode.error);

                audioProducerSpan = null;
              }
            } catch (error) {}

            _eventEmitter.emit("error", VideoSDKErrors[3013]);

            Map<String, String> attributes = {
              "error": "Error in enableScreenShare(): Something went wrong.",
              "errorMessage": "enableScreenShare(): _sendTransport is null."
            };
            VideoSDKLog.createLog(
                message: VideoSDKErrors[3013]!['message']!,
                logLevel: "ERROR",
                attributes: attributes,
                dashboardLog: true);
            print(
                "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3013]?['code']}  :: ${VideoSDKErrors[3013]?['name']} :: ${VideoSDKErrors[3013]?['message']}");

            if (shareStream != null) {
              await shareStream.dispose();
            }
            if (!kIsWeb) {
              if (Platform.isAndroid) {
                //
                FlutterForegroundTask.stopService();
              }
            }
            _screenShareInProgress = false;
            return;
          }

          if (audioProducerSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: audioProducerSpan,
                message: 'Share Audio Producer Created',
                status: StatusCode.ok);

            audioProducerSpan = null;
          }
        }
        if (enableShareSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: enableShareSpan,
              message: 'Enable ScreenShare Successful',
              status: StatusCode.ok);
        }
      } else {
        if (enableShareSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: enableShareSpan,
              message: 'Enable ScreenShare Failed due to stream null',
              status: StatusCode.error);
        }

        _eventEmitter.emit("error", VideoSDKErrors[3013]);

        Map<String, String> attributes = {
          "error": "Error in enableScreenShare(): Something went wrong.",
          "errorMessage": "enableScreenShare(): shareStream is null."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3013]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3013]?['code']}  :: ${VideoSDKErrors[3013]?['name']} :: ${VideoSDKErrors[3013]?['message']}");
        if (!kIsWeb) {
          if (Platform.isAndroid) {
            //
            FlutterForegroundTask.stopService();
          }
        }
        _screenShareInProgress = false;
        return;
      }
    } catch (error) {
      //
      _screenShareInProgress = false;

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          //
          FlutterForegroundTask.stopService();
        }
      }

      //
      if (shareStream != null) {
        await shareStream.dispose();
      }
      if (error.toString().contains("NotAllowedError")) {
        _eventEmitter.emit("error", VideoSDKErrors[3014]);
        Map<String, String> attributes = {
          "error": "Error in enableScreenShare(): Permissions denied."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3014]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3014]?['code']}  :: ${VideoSDKErrors[3014]?['name']} :: ${VideoSDKErrors[3014]?['message']}");
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3013]);
        Map<String, String> attributes = {
          "error": "Error in enableScreenShare(): Something went wrong.",
          "errorMessage": "Error in enableScreenShare(): ${error.toString()}."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3013]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3013]?['code']}  :: ${VideoSDKErrors[3013]?['name']} :: ${VideoSDKErrors[3013]?['message']}");
      }

      if (trackSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: trackSpan,
            message: 'Track Generation Failed',
            status: StatusCode.error);
      }
      if (producerSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: producerSpan,
            message: 'Share Producer Creation Failed',
            status: StatusCode.error);
      }

      if (audioProducerSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: audioProducerSpan,
            message: 'Share Audio Creation Failed',
            status: StatusCode.error);
      }

      if (enableShareSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: enableShareSpan,
            message: 'Enable ScreenShare Failed \n ${error.toString()}',
            status: StatusCode.error);
      }
    }
  }

  //
  Future<void> disableScreenShare() async {
    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in disableScreenShare(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
      return;
    }
    Span? disableShareSpan;
    try {
      if (videoSDKTelemetery != null) {
        disableShareSpan = videoSDKTelemetery!.trace(
          spanName: 'disableShare() Calling',
        );
      }
    } catch (error) {}

    //
    if (_screenshareProducer != null) {
      //
      _screenShareInProgress = true;

      Span? audioProducerTrack;
      Span? producerTrack;
      if (_screenShareAudioProducer != null) {
        try {
          if (disableShareSpan != null) {
            audioProducerTrack = videoSDKTelemetery!.trace(
              spanName: 'Closing Share Audio Producer',
              span: disableShareSpan,
            );
          }
        } catch (error) {}

        //
        String screenShareAudioId = _screenShareAudioProducer!.id;

        //
        _removeProducer(
            _screenShareAudioProducer!, _ProducerType.screenShareAudioProducer);

        //
        _screenShareAudioProducer = null;

        try {
          //
          if (_webSocket != null) {
            await _webSocket!.socket.request('closeProducer', {
              'producerId': screenShareAudioId,
            });
          }

          if (audioProducerTrack != null) {
            videoSDKTelemetery!.completeSpan(
                span: audioProducerTrack,
                message: 'Requested Server to Close Audio Producer',
                status: StatusCode.ok);

            audioProducerTrack = null;
          }
        } catch (error) {
          Map<String, String> attributes = {
            "error": "Error in disableScreenShare() :: Something went wrong.",
            "errorMessage": "Error in disableScreenShare(): ${error.toString()}"
          };
          VideoSDKLog.createLog(
              message:
                  "Something went wrong, and the screenshare audio could not be disabled. Please try again.",
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred in disableScreenShare()): Something went wrong, and the screenshare audio could not be disabled. Please try again.");

          if (audioProducerTrack != null) {
            videoSDKTelemetery!.completeSpan(
                span: audioProducerTrack,
                message: 'Close Audio Producer Request to Server Failed',
                status: StatusCode.error);

            audioProducerTrack = null;
          }
        }
      }

      try {
        if (disableShareSpan != null) {
          producerTrack = videoSDKTelemetery!.trace(
            spanName: 'Closing Share Producer',
            span: disableShareSpan,
          );
        }
      } catch (error) {}

      //
      String screenShareId = _screenshareProducer!.id;

      //
      _removeProducer(_screenshareProducer!, _ProducerType.screenshareProducer);

      //
      _screenshareProducer = null;

      try {
        //
        if (_webSocket != null) {
          await _webSocket!.socket.request('closeProducer', {
            'producerId': screenShareId,
          });
        }

        if (producerTrack != null) {
          videoSDKTelemetery!.completeSpan(
              span: producerTrack,
              message: 'Requested Server to Close Producer',
              status: StatusCode.ok);

          producerTrack = null;
        }

        if (disableShareSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: disableShareSpan,
              message: 'Disable ScreenShare Successful',
              status: StatusCode.ok);
        }
      } catch (error) {
        //
        Map<String, String> attributes = {
          "error": "Error in disableScreenShare() :: Something went wrong.",
          "errorMessage": "Error in disableScreenShare(): ${error.toString()}"
        };
        VideoSDKLog.createLog(
            message:
                "Error in disableScreenShare(): Something went wrong, and the screenshare could not be disabled. Please try again.",
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in disableScreenShare()): Something went wrong, and the screenshare could not be disabled. Please try again.");

        if (producerTrack != null) {
          videoSDKTelemetery!.completeSpan(
              span: producerTrack,
              message: 'Close Producer Request Failed',
              status: StatusCode.error);

          producerTrack = null;
        }

        if (disableShareSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: disableShareSpan,
              message: 'ScreenShare disabled Failed \n ${error.toString()}',
              status: StatusCode.error);
        }
        //
      } finally {
        _closeForegroundService();

        //
        _screenShareInProgress = false;
      }
    } else {
      if (disableShareSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: disableShareSpan,
            message: 'Share Producer Not found',
            status: StatusCode.error);
      }
      //
      Map<String, String> attributes = {
        "error":
            "Error in disableScreenShare() :: Screenshare is already disabled."
      };
      VideoSDKLog.createLog(
          message:
              "Attempted to call disableScreenShare() while the screenshare is already disabled",
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in disableScreenShare(): Attempted to call disableScreenShare() while the screenshare is already disabled");
    }
  }

  Future<void> _participantPinStateChange(
      String peerId, ParticipantPinState pinState) async {
    try {
      if (videoSDKTelemetery != null) {
        videoSDKTelemetery!.traceAutoComplete(
            spanName: 'Pin state Change for $peerId',
            attributes: [
              Attribute.fromString('state', pinState.toJson().toString())
            ]);
      }

      _webSocket?.socket.request(
          'pinStateChanged', {'peerId': peerId, 'state': pinState.toJson()});
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in pinStateChange() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Error Setting Pin State $error");
    }
  }

  //
  Future<void> join() async {
    if (_joined) {
      //
      log("Already Joined");
      return;
    }

    //
    String baseUrl;
    try {
      String initConfigUrl =
          "https://$_signalingBaseUrl/infra/v1/meetings/sdk-init-config";
      //
      final jsonRes = await http.post(Uri.parse(initConfigUrl), body: {
        'roomId': id,
      }, headers: {
        'Authorization': _token,
      });

      final jsonData = json.decode(jsonRes.body);

      if (jsonRes.statusCode != 200) {
        //
        throw jsonData['error'] ?? "Error while getting baseUrl";
      }

      //
      final data = jsonData['data'];
      baseUrl = data['baseUrl'];

      //
      try {
        String decryptedIceServer = decrypt(data['iceServers']);
        //
        List<dynamic> iceServers = json.decode(decryptedIceServer.substring(
            0, decryptedIceServer.lastIndexOf(']') + 1)) as List;
        //
        iceServers.asMap().forEach((key, value) {
          //
          if (value['url'].toString().contains("stun")) {
            //
            RTCIceServer iceServer = RTCIceServer(
                credentialType: RTCIceCredentialType.password,
                username: "",
                urls: [value['url']],
                credential: "");
            _iceServers.add(iceServer);
          } else {
            //
            RTCIceServer iceServer = RTCIceServer(
                credentialType: RTCIceCredentialType.password,
                username: value['username'],
                urls: [value['url']],
                credential: value['credential']);
            _iceServers.add(iceServer);
          }
        });
        final observability = data['observability'];
        // set meetingId, peerId for Logs
        VideoSDKLog.meetingId = id;
        VideoSDKLog.peerId = localParticipant.id;
        VideoSDKLog.logsConfig = observability['logs'];
        VideoSDKLog.jwtKey = observability['jwt'];
        VideoSDKLog.debugMode = _debugMode;

        // open-telemeetry
        videoSDKTelemetery = VideoSDKTelemetery(
          roomId: id,
          peerId: localParticipant.id,
          observabilityJwt: observability['jwt'],
          traces: observability['traces'],
          metaData: observability['metaData'],
        );
      } catch (error) {
        //
        VideoSDKLog.createLog(
            message: "Error in join() \n ${error.toString()}",
            logLevel: "ERROR");

        //
        log(error.toString());
      }
    } catch (err) {
      //
      VideoSDKLog.createLog(
          message: "Error while getting baseUrl \n ${err.toString()}",
          logLevel: "ERROR");

      final error = <String, dynamic>{};

      error.addAll(<String, dynamic>{
        "code": "3023",
        "name": "ERROR_JOINING_MEETING",
        "message":
            "An error occured while joining the meeting :  ${err.toString()}"
      });

      _eventEmitter.emit("error", error);

      print(
          "An error occured while joining the meeting : VIDEOSDK ERROR :: 3023  :: ERROR_JOINING_MEETING :: ${err.toString()}");

      throw "Error while getting baseUrl";
    }

    // send trace roomConfig
    try {
      deviceInfo = await VideoSDK.getDeviceInfo();

      final logDeviceInfo = <String, dynamic>{};
      if (deviceInfo.containsKey("browserUserAgent")) {
        logDeviceInfo.addAll(<String, dynamic>{
          "browserName": deviceInfo['browserUserAgent']['browser']['name'],
          "browserVersion": deviceInfo['browserUserAgent']['browser']
              ['version'],
          "osName": deviceInfo['browserUserAgent']['os']['name'],
          "osVersion": deviceInfo['browserUserAgent']['os']['type'],
          "platform": deviceInfo['platform']
        });
      }
      if (deviceInfo.containsKey("deviceUserAgent")) {
        logDeviceInfo.addAll(<String, dynamic>{
          "brand": deviceInfo['deviceUserAgent']['brand'],
          "model": deviceInfo['deviceUserAgent']['modelName'],
          "osVersion": deviceInfo['deviceUserAgent']['osVersion'],
          "platform": deviceInfo['platform']
        });
      }

      VideoSDKLog.deviceInfo = logDeviceInfo;
      _joinSpan = videoSDKTelemetery!.trace(
        spanName: 'Join() Calling',
        span: null,
        attributes: [
          Attribute.fromString('deviceInfo', deviceInfo.toString()),
          Attribute.fromString('displayName', _displayName),
          Attribute.fromBoolean('micEnabled', micEnabled),
          Attribute.fromBoolean('camEnabled', _camEnabled),
          Attribute.fromString('maxResolution', _maxResolution),
          Attribute.fromBoolean('multiStream', _multiStream),
          Attribute.fromString('mode', _mode.name.toString()),
          if (_customCameraVideoTrack != null)
            Attribute.fromString('customCameraVideoTrack',
                _customCameraVideoTrack!.toMap().toString()),
          if (_customMicrophoneAudioTrack != null)
            Attribute.fromString('customMicrophoneAudioTrack',
                _customMicrophoneAudioTrack!.toMap().toString()),
          if (_selectedAudioInput != null)
            Attribute.fromString(
                'selectedAudioInput', _selectedAudioInput!.label),
          if (_selectedVideoInput != null)
            Attribute.fromString(
                'selectedVideoInput', _selectedVideoInput!.label),
        ],
      );
    } catch (error) {
      VideoSDKLog.createLog(
          message: "Error while getting deviceInfo \n ${error.toString()}",
          logLevel: "ERROR");
    }

    //
    _webSocket = WebSocket(
        baseUrl: baseUrl,
        peerId: localParticipant.id,
        meetingId: id,
        token: _token,
        mode: _mode.parseToString());

    try {
      if (videoSDKTelemetery != null) {
        videoSDKTelemetery!.traceAutoComplete(
          spanName: 'Meeting is in CONNECTING State',
        );
      }
    } catch (error) {
      VideoSDKLog.createLog(
          message: "Error in webSocket OnConnecting \n ${error.toString()}",
          logLevel: "ERROR");

      log("Error in webSocket OnConnecting $error");
    }

    //
    _webSocket!.onOpen = () {
      try {
        if (videoSDKTelemetery != null) {
          videoSDKTelemetery!.traceAutoComplete(
            spanName: 'Meeting is in CONNECTED State',
          );
        }
      } catch (error) {
        VideoSDKLog.createLog(
            message: "Error in webSocket onOpen \n ${error.toString()}",
            logLevel: "ERROR");
        log("Error in webSocket onOpen $error");
      }

      _requestEntry();
    };

    //
    _webSocket!.onFail = () {
      try {
        if (videoSDKTelemetery != null) {
          videoSDKTelemetery!.traceAutoComplete(
              spanName: 'Meeting is in FAILED State',
              status: StatusCode.error,
              message: 'WebSocket Connection Failed');
        }
      } catch (error) {
        VideoSDKLog.createLog(
            message: "Error in webSocket onFail \n ${error.toString()}",
            logLevel: "ERROR");
        log("Error in webSocket onFail $error");
      }
    };

    //
    _webSocket!.onDisconnected = () {
      try {
        if (videoSDKTelemetery != null) {
          videoSDKTelemetery!.traceAutoComplete(
            spanName: 'Meeting is in DISCONNECTED State',
          );
        }
      } catch (error) {
        VideoSDKLog.createLog(
            message: "Error in webSocket onDisconnected \n ${error.toString()}",
            logLevel: "ERROR");
        log("Error in webSocket onDisconnected $error");
      }

      if (_micProducer != null) {
        if (!_micProducer!.closed && _micProducer!.paused) {
          _micProducer!.resume();
        }
        _micProducer!.track.stop();
        _micProducer!.close();
        _micProducer = null;
      }

      if (_sendTransport != null) {
        _sendTransport!.close();
        _sendTransport = null;
      }
      if (_recvTransport != null) {
        _recvTransport!.close();
        _recvTransport = null;
      }
    };

    //
    _webSocket!.onClose = () {
      //
      if (_closed) return;
      //
      try {
        if (videoSDKTelemetery != null) {
          videoSDKTelemetery!.traceAutoComplete(
            spanName: 'Meeting is in CLOSED State',
          );
        }
      } catch (error) {
        VideoSDKLog.createLog(
            message: "Error in webSocket onClose \n ${error.toString()}",
            logLevel: "ERROR");
        log("Error in webSocket onClose $error");
      }
      //
      _close();
    };

    //
    _webSocket!.onRequest = (request, accept, reject) async {
      switch (request['method']) {
        case "close":
          {
            _close();
            break;
          }

        case 'newConsumer':
          {
            Span? newConsumerSpan;
            Span? span;

            try {
              if (videoSDKTelemetery != null) {
                newConsumerSpan = videoSDKTelemetery!.trace(
                  spanName: 'Protoo REQ: newConsumer',
                  attributes: [
                    Attribute.fromString('request', request.toString())
                  ],
                );
              }
            } catch (error) {}

            if (!_consume) {
              reject(403, 'I do not want to consume');
              if (newConsumerSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: newConsumerSpan,
                    message: 'Do not want to consume',
                    status: StatusCode.ok);
              }
              break;
            }
            try {
              try {
                if (newConsumerSpan != null) {
                  span = videoSDKTelemetery!.trace(
                    spanName: 'Creating Consumer',
                    span: newConsumerSpan,
                  );
                }
              } catch (error) {}

              _recvTransport!.consume(
                id: request['data']['id'],
                producerId: request['data']['producerId'],
                kind: RTCRtpMediaTypeExtension.fromString(
                    request['data']['kind']),
                rtpParameters:
                    RtpParameters.fromMap(request['data']['rtpParameters']),
                appData: Map<String, dynamic>.from(request['data']['appData']),
                peerId: request['data']['peerId'],
                accept: accept,
              );

              if (span != null) {
                videoSDKTelemetery!.completeSpan(
                    span: span,
                    message: 'Consumer Created',
                    status: StatusCode.ok);
                span = null;
              }

              if (newConsumerSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: newConsumerSpan,
                    message: 'New Consumer Created Successfully',
                    status: StatusCode.ok);
              }
            } catch (error) {
              //
              VideoSDKLog.createLog(
                  message: "Error in newConsumer \n ${error.toString()}",
                  logLevel: "ERROR");

              //
              log(error.toString());

              if (span != null) {
                videoSDKTelemetery!.completeSpan(
                    span: span,
                    message: 'Consumer Creation Failed',
                    status: StatusCode.error);
                span = null;
              }

              if (newConsumerSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: newConsumerSpan,
                    message:
                        'New Consumer Creation Failed \n ${error.toString()}',
                    status: StatusCode.error);
              }
              rethrow;
            }
            break;
          }

        case 'enableMic':
          {
            Span? enableMicSpan;
            try {
              try {
                if (videoSDKTelemetery != null) {
                  enableMicSpan = videoSDKTelemetery!.trace(
                    spanName: 'Protoo REQ: enableMic',
                  );
                }
              } catch (error) {}

              _eventEmitter.emit('mic-requested', {
                // 'participantId': peerId,
                "accept": () {
                  try {
                    if (enableMicSpan != null) {
                      videoSDKTelemetery!.traceAutoComplete(
                        spanName: 'Accept Request of EnableMic',
                        span: enableMicSpan,
                      );
                    }
                  } catch (error) {}
                  _enableMicImpl(parentSpan: enableMicSpan);
                },
                "reject": () {
                  try {
                    if (enableMicSpan != null) {
                      videoSDKTelemetery!.traceAutoComplete(
                        spanName: 'Reject Request of EnableMic',
                        span: enableMicSpan,
                      );
                    }
                  } catch (error) {}
                },
              });

              accept();

              if (enableMicSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: enableMicSpan,
                    message: 'EnableMic Request Completed',
                    status: StatusCode.ok);
              }
            } catch (error) {
              //
              VideoSDKLog.createLog(
                  message: "Error in mic-requested \n ${error.toString()}",
                  logLevel: "ERROR");

              //
              if (enableMicSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: enableMicSpan,
                    message: 'EnableMic Request Failed \n ${error.toString()}',
                    status: StatusCode.error);
              }

              rethrow;
            }
            break;
          }
        case 'disableMic':
          {
            Span? disableMicSpan;
            try {
              try {
                if (videoSDKTelemetery != null) {
                  disableMicSpan = videoSDKTelemetery!.trace(
                    spanName: 'Protoo REQ: disableMic',
                  );
                }
              } catch (error) {}

              _disableMic(parentSpan: disableMicSpan);
              accept();

              if (disableMicSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: disableMicSpan,
                    message: 'DisableMic Request Completed',
                    status: StatusCode.ok);
              }
            } catch (error) {
              //
              VideoSDKLog.createLog(
                  message:
                      "error in request disableMic() \n ${error.toString()}",
                  logLevel: "ERROR");

              if (disableMicSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: disableMicSpan,
                    message: 'DisableMic Request Failed \n ${error.toString()}',
                    status: StatusCode.error);
              }

              rethrow;
            }
            break;
          }
        case 'enableWebcam':
          {
            Span? enableWebcam;
            try {
              if (videoSDKTelemetery != null) {
                enableWebcam = videoSDKTelemetery!.trace(
                  spanName: 'Protoo REQ: enableWebcam',
                );
              }
            } catch (error) {}

            try {
              _eventEmitter.emit('webcam-requested', {
                // "participantId": peerId,
                "accept": () {
                  _enableCamImpl(parentSpan: enableWebcam);
                  try {
                    if (enableWebcam != null) {
                      videoSDKTelemetery!.traceAutoComplete(
                        spanName: 'Accept Request of EnableWebCam',
                        span: enableWebcam,
                      );
                    }
                  } catch (error) {}
                },
                "reject": () {
                  if (enableWebcam != null) {
                    videoSDKTelemetery!.traceAutoComplete(
                      spanName: 'Reject Request of EnableWebCam',
                      span: enableWebcam,
                    );
                  }
                },
              });

              accept();

              if (enableWebcam != null) {
                videoSDKTelemetery!.completeSpan(
                  message: 'EnableWebCam Request Completed',
                  span: enableWebcam,
                  status: StatusCode.ok,
                );
              }
            } catch (error) {
              //
              VideoSDKLog.createLog(
                  message: "Error in webcam-requested \n ${error.toString()}",
                  logLevel: "ERROR");

              if (enableWebcam != null) {
                videoSDKTelemetery!.completeSpan(
                  message: 'EnableWebCam Request Failed \n ${error.toString()}',
                  span: enableWebcam,
                  status: StatusCode.error,
                );
              }
              rethrow;
            }
            break;
          }
        case 'disableWebcam':
          {
            Span? disableWebcamSpan;

            try {
              try {
                if (videoSDKTelemetery != null) {
                  disableWebcamSpan = videoSDKTelemetery!.trace(
                    spanName: 'Protoo REQ: disableWebcam',
                  );
                }
              } catch (error) {}

              _disableCamImpl(parentSpan: disableWebcamSpan);
              accept();

              if (disableWebcamSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: disableWebcamSpan,
                    message: 'DisableWebCam Request Completed',
                    status: StatusCode.ok);
              }
            } catch (error) {
              //
              VideoSDKLog.createLog(
                  message: "Error in request disableCam \n ${error.toString()}",
                  logLevel: "ERROR");

              if (disableWebcamSpan != null) {
                videoSDKTelemetery!.completeSpan(
                    span: disableWebcamSpan,
                    message:
                        'DisableWebCam Request Failed \n ${error.toString()}',
                    status: StatusCode.error);
              }

              rethrow;
            }
            break;
          }
        case "statsData":
          {
            if (!kIsWeb) {
              if (Platform.isAndroid || Platform.isIOS) {
                final usage = await _getCpuAndMemoryUsage();
                if (usage != null) {
                  _stats['deviceStats'] = [];
                  _stats['deviceStats'].add({
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                    'cpuUsage': usage['cpuUsage'],
                    'memoryUsage': usage['memoryUsage'],
                  });
                }
              }
            }

            accept({
              "peerId": localParticipant.id,
              "statsData": _stats,
            });
            _stats = {};
            break;
          }
        case "pinStateChanged":
          {
            String peerId = request["data"]['peerId'];
            Map<dynamic, dynamic> state = request["data"]['state'];
            String? pinnedBy = request["data"]['pinnedBy'];

            Span? pinStateChangedSpan;

            try {
              if (videoSDKTelemetery != null) {
                pinStateChangedSpan = videoSDKTelemetery!.trace(
                    spanName: 'Protoo REQ: pinStateChanged',
                    attributes: [
                      Attribute.fromString('peerId', peerId),
                      Attribute.fromString('state', state.toString()),
                      if (pinnedBy != null)
                        Attribute.fromString('pinnedBy', pinnedBy),
                    ]);
              }
            } catch (error) {}

            // Update current State of participant pin
            if (!pinnedParticipants.containsKey(peerId)) {
              pinnedParticipants.putIfAbsent(
                  peerId,
                  () => ParticipantPinState(
                        cam: state['cam'],
                        share: state['share'],
                      ));
            }

            pinnedParticipants[peerId] = ParticipantPinState(
              cam: state['cam'],
              share: state['share'],
            );

            ParticipantPinState pinParticipantState =
                pinnedParticipants[peerId]!;

            // delete if both were false or current state is false
            if (!pinParticipantState.cam && !pinParticipantState.share) {
              pinnedParticipants.remove(peerId);
            }

            _eventEmitter.emit('pin-state-changed-$peerId', {
              'participantId': peerId,
              'state': state,
              'pinnedBy': pinnedBy,
            });

            _eventEmitter.emit('pin-state-changed', {
              'participantId': peerId,
              'state': state,
              'pinnedBy': pinnedBy,
            });

            if (pinStateChangedSpan != null) {
              videoSDKTelemetery!.traceAutoComplete(
                spanName: 'Emitted `pin-state-changed` Event',
                span: pinStateChangedSpan,
              );
            }

            accept();

            if (pinStateChangedSpan != null) {
              videoSDKTelemetery!.completeSpan(
                  span: pinStateChangedSpan,
                  message: 'PinStateChange Request Completed',
                  status: StatusCode.ok);
            }
            break;
          }
        default:
          break;
      }
    };

    //
    _webSocket!.onNotification = (notification) async {
      switch (notification['method']) {
        case 'error':
          {
            dynamic error = notification['data'];
            //
            VideoSDKLog.createLog(
                message: "Error from server \n ${error.toString()}",
                logLevel: "ERROR");
            //
            if (VideoSDKErrors.containsKey(error['code'])) {
              _eventEmitter.emit("error", VideoSDKErrors[error['code']]);
            } else {
              _eventEmitter.emit("error", error);
            }

            try {
              if (videoSDKTelemetery != null) {
                videoSDKTelemetery!.traceAutoComplete(
                    spanName: 'Emitted `ERROR` Event',
                    attributes: [
                      Attribute.fromString('error', error.toString()),
                    ],
                    status: StatusCode.error,
                    message: 'Error from server');
              }
            } catch (error) {}

            break;
          }

        case 'producerScore':
          {
            break;
          }

        case 'consumerClosed':
          {
            String consumerId = notification['data']['consumerId'];
            _removePeerConsumer(consumerId);

            try {
              if (videoSDKTelemetery != null) {
                videoSDKTelemetery!.traceAutoComplete(
                  spanName: 'Protoo Noti: consumerClosed for $consumerId',
                );
              }
            } catch (error) {}

            break;
          }

        case 'consumerPaused':
          {
            // String consumerId = notification['data']['consumerId'];
            // peersBloc.add(PeerPausedConsumer(consumerId: consumerId));
            break;
          }

        case 'consumerResumed':
          {
            // String consumerId = notification['data']['consumerId'];
            // peersBloc.add(PeerResumedConsumer(consumerId: consumerId));
            break;
          }

        case "consumerLayersChanged":
          {
            String consumerId = notification['data']['consumerId'];
            int spatialLayer = notification['data']['spatialLayer'] ?? -1;
            int temporalLayer = notification['data']['temporalLayer'] ?? -1;

            _changePeerConsumerQuality(
              consumerId,
              spatialLayer: spatialLayer,
              temporalLayer: temporalLayer,
            );

            Consumer? consumer = _recvTransport?.getConsumer(consumerId);

            if (consumer != null) {
              consumer.spatialLayer = spatialLayer;
              consumer.temporalLayer = temporalLayer;
            }

            break;
          }

        case "entryRequested":
          {
            var id = notification['data']['id'];
            var name = notification['data']['name'];

            Span? entryRequestedSpan;
            try {
              if (videoSDKTelemetery != null && _joinSpan != null) {
                entryRequestedSpan = videoSDKTelemetery!.trace(
                  spanName: 'Protoo Noti: entryRequested',
                  attributes: [
                    Attribute.fromString('peerId', id.toString()),
                    Attribute.fromString('name', name.toString())
                  ],
                  span: _joinSpan,
                );
              }
            } catch (error) {}

            if (id != localParticipant.id) {
              _eventEmitter.emit("entry-requested", <String, dynamic>{
                'participantId': id,
                'name': name,
                'allow': () {
                  _respondEntry(id, "allowed", entryRequestedSpan);
                },
                'deny': () {
                  _respondEntry(id, "denied", entryRequestedSpan);
                },
              });

              if (entryRequestedSpan != null) {
                videoSDKTelemetery!.completeSpan(
                  span: entryRequestedSpan,
                  message: 'EntryRequested Received',
                  status: StatusCode.ok,
                );
              }
            } else {
              if (entryRequestedSpan != null) {
                videoSDKTelemetery!.completeSpan(
                  span: entryRequestedSpan,
                  message: 'EntryRequested Failed',
                  status: StatusCode.error,
                );
              }
            }
            break;
          }

        case "entryResponded":
          {
            var id = notification['data']['id'];
            var decision = notification['data']['decision'];
            var sessionId = notification['data']['sessionId'];
            VideoSDKLog.sessionId = sessionId;

            Span? entryRespondedSpan;
            try {
              if (videoSDKTelemetery != null && _joinSpan != null) {
                entryRespondedSpan = videoSDKTelemetery!.trace(
                  spanName: 'Protoo Noti: entryResponded',
                  attributes: [
                    Attribute.fromString('peerId', id.toString()),
                    Attribute.fromString('decision', decision.toString()),
                    Attribute.fromString('sessionId', sessionId.toString())
                  ],
                  span: _joinSpan,
                );
              }
            } catch (error) {}

            _eventEmitter.emit(
              "entry-responded",
              <String, dynamic>{
                "id": id,
                "decision": decision,
              },
            );

            if (id == localParticipant.id && decision == "allowed") {
              _joinRoom();
              if (entryRespondedSpan != null) {
                videoSDKTelemetery!.completeSpan(
                  span: entryRespondedSpan,
                  message: 'EntryResponded Received',
                  status: StatusCode.ok,
                );
              }
            } else {
              if (entryRespondedSpan != null) {
                videoSDKTelemetery!.completeSpan(
                  span: entryRespondedSpan,
                  message: 'Join Request Denied',
                  status: StatusCode.error,
                );
              }
            }

            break;
          }

        case 'newPeer':
          {
            final Map<String, dynamic> newPeer =
                Map<String, dynamic>.from(notification['data']);

            Span? newPeerSpan;

            if (videoSDKTelemetery != null) {
              newPeerSpan = videoSDKTelemetery!.trace(
                spanName: 'Protoo Noti: newPeer for ${newPeer.toString()}',
                attributes: [
                  Attribute.fromString('newPeer', newPeer.toString()),
                ],
              );
            }

            _addPeer(newPeer, newPeerSpan);

            if (newPeerSpan != null) {
              videoSDKTelemetery!.completeSpan(
                message:
                    'Protoo Noti: newPeer for ${newPeer.toString()} Completed',
                status: StatusCode.ok,
                span: newPeerSpan,
              );
            }

            break;
          }

        case 'peerClosed':
          {
            String peerId = notification['data']['peerId'];

            Span? peerClosedSpan;

            if (videoSDKTelemetery != null) {
              peerClosedSpan = videoSDKTelemetery!.trace(
                spanName: 'Protoo Noti: peerClosed for $peerId',
              );
            }

            __removePeer(peerId, peerClosedSpan);

            if (peerClosedSpan != null) {
              videoSDKTelemetery!.completeSpan(
                message: 'Protoo Noti: peerClosed for $peerId Completed',
                span: peerClosedSpan,
                status: StatusCode.ok,
              );
            }

            break;
          }

        case 'recordingStarted':
          {
            _eventEmitter.emit('recording-started');
            break;
          }

        case 'recordingStopped':
          {
            _eventEmitter.emit('recording-stopped');
            break;
          }

        case 'recordingStateChanged':
          {
            _recordingState = notification['data']['status'];

            _eventEmitter.emit('recording-state-changed', _recordingState);

            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName:
                      'Emitted RECORDING_STATE_CHANGED, status : ${notification['data']['status']}',
                  attributes: [
                    Attribute.fromString(
                        'data', notification['data'].toString())
                  ]);
            }

            break;
          }

        case "livestreamStarted":
          {
            _eventEmitter.emit('livestream-started');

            break;
          }

        case "livestreamStopped":
          {
            _eventEmitter.emit('livestream-stopped');

            break;
          }

        case 'livestreamStateChanged':
          {
            _livestreamState = notification['data']['status'];

            _eventEmitter.emit('livestream-state-changed', _livestreamState);

            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName:
                      'Emitted LIVESTREAM_STATE_CHANGED, status : ${notification['data']['status']}',
                  attributes: [
                    Attribute.fromString(
                        'data', notification['data'].toString())
                  ]);
            }
            break;
          }

        case "hlsStarted":
          {
            var downstreamUrl = notification['data']['downstreamUrl'];
            _eventEmitter.emit('hls-started', downstreamUrl);

            break;
          }

        case "hlsStopped":
          {
            _eventEmitter.emit('hls-stopped');

            break;
          }

        case 'hlsStateChanged':
          {
            _hlsState = notification['data']['status'];

            var downstreamUrl = notification['data']['downstreamUrl'];
            var playbackHlsUrl = notification['data']['playbackHlsUrl'];
            var livestreamUrl = notification['data']['livestreamUrl'];

            if (_hlsState == "HLS_STARTED") {
              _hlsDownstreamUrl = downstreamUrl;
              _hlsUrls = {
                "downstreamUrl": downstreamUrl,
                "playbackHlsUrl": playbackHlsUrl,
                "livestreamUrl": livestreamUrl,
              };
            } else if (_hlsState == "HLS_STOPPED") {
              _hlsDownstreamUrl = null;
              _hlsUrls = _hlsUrls = {
                "downstreamUrl": null,
                "playbackHlsUrl": null,
                "livestreamUrl": null,
              };
            }

            _eventEmitter.emit('hls-state-changed', <String, dynamic>{
              "status": _hlsState,
              "downstreamUrl": downstreamUrl,
              "playbackHlsUrl": playbackHlsUrl,
              "livestreamUrl": livestreamUrl,
            });

            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                spanName:
                    'Emitted HLS_STATE_CHANGED, status : ${notification['data']['status']}',
                attributes: [
                  Attribute.fromString('data', notification['data'].toString())
                ],
              );
            }

            break;
          }

        case 'hlsPlayableStateChanged':
          {
            bool isPlayable = notification["data"]["isPlayable"];
            if (isPlayable) {
              _hlsState = "HLS_PLAYABLE";
              var downstreamUrl = notification['data']['downstreamUrl'];
              var playbackHlsUrl = notification['data']['playbackHlsUrl'];
              var livestreamUrl = notification['data']['livestreamUrl'];

              _hlsUrls = {
                "downstreamUrl": downstreamUrl,
                "playbackHlsUrl": playbackHlsUrl,
                "livestreamUrl": livestreamUrl,
              };
              _eventEmitter.emit('hls-state-changed', <String, dynamic>{
                "status": _hlsState,
                "downstreamUrl": downstreamUrl,
                "playbackHlsUrl": playbackHlsUrl,
                "livestreamUrl": livestreamUrl,
              });

              if (videoSDKTelemetery != null) {
                videoSDKTelemetery!.traceAutoComplete(
                  spanName: 'Protoo Noti: hlsPlayableStateChanged',
                );
              }
            }

            break;
          }

        case 'whiteboardStarted':
          {
            _eventEmitter.emit(
                'whiteboard-started', notification['data']['url']);
            break;
          }

        case 'whiteboardStopped':
          {
            _eventEmitter.emit('whiteboard-stopped');
            break;
          }

        case "activeSpeaker":
          {
            String? peerId = notification['data']['peerId'];

            if (peerId != _activeSpeakerId) {
              _activeSpeakerId = peerId;
              _eventEmitter.emit("speaker-changed", peerId);
            }

            break;
          }
        case "pubsubMessage":
          {
            _eventEmitter.emit("pubsub-message", notification['data']);
            break;
          }

        case "peerModeChanged":
          {
            _eventEmitter.emit(
                "participant-mode-changed-${notification['data']['peerId']}", {
              'participantId': notification['data']['peerId'],
              'mode': notification['data']['mode'],
            });
            _eventEmitter.emit("participant-mode-changed", {
              'participantId': notification['data']['peerId'],
              'mode': notification['data']['mode'],
            });

            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                spanName: 'Emitted PEER_MODE_CHANGED',
                attributes: [
                  Attribute.fromString('data', notification['data'].toString())
                ],
              );
            }

            break;
          }
        case "restartIce":
          {
            String transportId = notification['data']['transportId'];
            IceParameters iceParameters =
                IceParameters.fromMap(notification['data']['iceParameters']);

            Span? restartIceSpan;
            if (videoSDKTelemetery != null) {
              restartIceSpan = videoSDKTelemetery!.trace(
                spanName:
                    'Protoo Noti: restartIce for transportId : $transportId',
                attributes: [
                  Attribute.fromString(
                      'iceParameters', iceParameters.toString())
                ],
              );
            }
            _handleRemoteRestartIce(transportId, iceParameters, restartIceSpan);
            break;
          }

        case 'transcriptionStateChanged':
          {
            _eventEmitter.emit(
                "transcription-state-changed", notification['data']);

            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                spanName:
                    'Emitted TRANSCRIPTION_STATE_CHANGED, status: ${notification['data']['status']}',
                attributes: [
                  Attribute.fromString('data', notification['data'].toString())
                ],
              );
            }

            break;
          }

        case 'transcriptionText':
          {
            var data = notification['data'];
            String participantId = data["participantId"];
            String participantName = data["participantName"];
            String text = data["text"];
            int timestamp = data["timestamp"];
            String type = data["type"];

            TranscriptionText transcriptionText = TranscriptionText(
                participantId: participantId,
                participantName: participantName,
                text: text,
                timestamp: timestamp,
                type: type);

            _eventEmitter.emit("transcription-text", transcriptionText);
            break;
          }

        case 'addCharacter':
          {
            final Map<String, dynamic> newCharacter =
                Map<String, dynamic>.from(notification['data']);

            Span? characterSpan;

            if (videoSDKTelemetery != null) {
              characterSpan = videoSDKTelemetery!.trace(
                spanName:
                    'Protoo Noti: newCharacter for ${newCharacter.toString()}',
                attributes: [
                  Attribute.fromString('newCharacter', newCharacter.toString()),
                ],
              );
            }

            _addCharacterPeer(newCharacter, characterSpan);

            if (characterSpan != null) {
              videoSDKTelemetery!.completeSpan(
                message:
                    'Protoo Noti: newCharacter for ${newCharacter.toString()} Completed',
                status: StatusCode.ok,
                span: characterSpan,
              );
            }

            _eventEmitter.emit("ADD_CHARACTER", notification['data']);

            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName: 'Emitted ADD_CHARACTER : ${notification['data']}',
                  attributes: [
                    Attribute.fromString(
                        'data', notification['data'].toString())
                  ],
                  status: StatusCode.ok);
            }

            break;
          }

        case 'removeCharacter':
          {
            String id = notification['data']['id'];

            Span? characterRemovedSpan;

            if (videoSDKTelemetery != null) {
              characterRemovedSpan = videoSDKTelemetery!.trace(
                spanName: 'Protoo Noti: Character Removed for $id',
              );
            }

            __removePeer(id, characterRemovedSpan);

            if (characterRemovedSpan != null) {
              videoSDKTelemetery!.completeSpan(
                message: 'Protoo Noti: Character Removed for $id Completed',
                span: characterRemovedSpan,
                status: StatusCode.ok,
              );
            }

            _eventEmitter.emit("REMOVE_CHARACTER", notification['data']);

            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName:
                      'Emitted REMOVE_CHARACTER : ${notification['data']}',
                  attributes: [
                    Attribute.fromString(
                        'data', notification['data'].toString())
                  ],
                  status: StatusCode.ok);
            }
            break;
          }
        case "characterStateChanged":
          {
            _eventEmitter.emit("CHARACTER_STATE_CHANGED", notification['data']);
            videoSDKTelemetery!.traceAutoComplete(
                spanName:
                    'Emitted CHARACTER_STATE_CHANGED, status : : ${notification['data']['status']}',
                attributes: [
                  Attribute.fromString('data', notification['data'].toString())
                ],
                status: StatusCode.ok);

            break;
          }
        case 'characterMessage':
          {
            _eventEmitter.emit("CHARACTER_MESSAGE",
                CharacterMessage.fromJson(notification['data']));

            break;
          }

        default:
          break;
      }
    };
  }

  void _handleRemoteRestartIce(String transportId, IceParameters iceParameters,
      Span? restartIceSpan) async {
    try {
      if (_webSocket == null) {
        if (restartIceSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: restartIceSpan,
            status: StatusCode.error,
            message: "iceRestart Failed Websocket was null",
          );
        }
        return;
      }

      if (_sendTransport?.id == transportId) {
        _sendTransport!.restartIce(iceParameters);
        _webSocket!.socket
            .request('iceRestarted', {"transportId": _sendTransport!.id});
      }
      if (_recvTransport?.id == transportId) {
        _recvTransport!.restartIce(iceParameters);
        _webSocket!.socket
            .request('iceRestarted', {"transportId": _recvTransport!.id});
      }

      if (restartIceSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: restartIceSpan,
          status: StatusCode.ok,
          message: "iceRestarted",
        );
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in restartICE() \n ${error.toString()}",
          logLevel: "ERROR");

      log("Error in iceRestart $error");

      if (restartIceSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: restartIceSpan,
          status: StatusCode.error,
          message: "iceRestart Failed \n ${error.toString()}",
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getCpuAndMemoryUsage() async {
    try {
      final cpuUsage = await _channel.invokeMethod('getCpuUsage');
      final memoryUsage = await _channel.invokeMethod('getMemoryUsage');
      return {
        "cpuUsage": cpuUsage,
        "memoryUsage": Platform.isIOS ? memoryUsage['used'] : memoryUsage
      };
    } catch (err) {}
    return null;
  }

//
  Future<void> _joinRoom() async {
    if (_webSocket == null) {
      return;
    }
    try {
      _device = Device();

      Span? routerSpan;
      try {
        if (videoSDKTelemetery != null) {
          routerSpan = videoSDKTelemetery!
              .trace(spanName: 'Loading Router Capabilities', span: _joinSpan);
        }
      } catch (error) {}

      dynamic routerRtpCapabilities =
          await _webSocket!.socket.request('getRouterRtpCapabilities', {});

      final rtpCapabilities = RtpCapabilities.fromMap(routerRtpCapabilities);
      rtpCapabilities.headerExtensions
          .removeWhere((he) => he.uri == 'urn:3gpp:video-orientation');

      await _device!.load(routerRtpCapabilities: rtpCapabilities);

      if (routerSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: routerSpan,
            message:
                'Router Capabilities Loaded ${routerRtpCapabilities.toString()}',
            status: StatusCode.ok);
      }

      if ((_device!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio) == true ||
              _device!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo) ==
                  true) &&
          _mode == Mode.CONFERENCE) {
        _produce = true;
      }

      await _createSendTransport(parentSpan: _joinSpan);

      await _createReceiveTransport(parentSpan: _joinSpan);

      Map response = await _webSocket!.socket.request('join', {
        'displayName': localParticipant.displayName,
        'device': {
          'name': "Flutter",
          'flag': 'flutter',
          'version': sdkVersion,
        },
        'rtpCapabilities': _device!.rtpCapabilities.toMap(),
        'sctpCapabilities': _device!.sctpCapabilities.toMap(),
        'deviceInfo': deviceInfo,
        'metaData': _metaData
      });

      response['peers'].forEach((value) {
        _addPeer(value, _joinSpan);
      });

      if (!kIsWeb) {
        if (Platform.isIOS) {
          VideoSDK.setAppleAudioConfiguration();
        }
      }

      //Request permission before setting default device for web
      //As in web, device labels and ids are not available w/o media permissions.
      bool audioPermission = false;
      bool videoPermission = false;

      // check browser is Firefox or not
      bool isFirefox =
          deviceInfo['browserUserAgent']?['browser']?['name'] == "Firefox";

      if (!isFirefox && kIsWeb) {
        if (_produce) {
          if (_micEnabled) {
            Map<String, bool> requestAudioPermission =
                await VideoSDK.requestPermissions(Permissions.audio);
            audioPermission = requestAudioPermission['audio']!;
            _micEnabled = audioPermission;
          }
          if (_camEnabled) {
            Map<String, bool> requestVideoPermission =
                await VideoSDK.requestPermissions(Permissions.video);
            videoPermission = requestVideoPermission['video']!;
            _camEnabled = videoPermission;
          }
        }
      }

      await _getDefaultDevices(_defaultCameraIndex);

      try {
        if (_produce) {
          if (_micEnabled) {
            await _enableMicImpl(
                customTrack: _customMicrophoneAudioTrack,
                parentSpan: _joinSpan);
          } else {
            if (_customMicrophoneAudioTrack != null) {
              _customMicrophoneAudioTrack?.dispose();
              _customMicrophoneAudioTrack = null;
            }
          }
          if (_camEnabled) {
            await _enableCamImpl(
                customTrack: _customCameraVideoTrack, parentSpan: _joinSpan);
          } else {
            if (_customCameraVideoTrack != null) {
              _customCameraVideoTrack?.dispose();
              _customCameraVideoTrack = null;
            }
          }
        } else {
          if (_customMicrophoneAudioTrack != null) {
            _customMicrophoneAudioTrack?.dispose();
            _customMicrophoneAudioTrack = null;
          }
          if (_customCameraVideoTrack != null) {
            _customCameraVideoTrack?.dispose();
            _customCameraVideoTrack = null;
          }
        }

        _eventEmitter.emit('meeting-joined');
        try {
          if (videoSDKTelemetery != null) {
            videoSDKTelemetery!.traceAutoComplete(
              spanName: 'Emitted `MEETING_JOINED` Event',
            );
          }
        } catch (error) {}
        _joined = true;

        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'notification_share_screen',
            channelName: 'Foreground Notification',
            channelDescription:
                'This notification appears when the foreground service is running.',
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
            iconData: NotificationIconData(
              resType: ResourceType.drawable,
              resPrefix: ResourcePrefix.ic,
              name: _notification.icon,
            ),
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: true,
            playSound: false,
          ),
          foregroundTaskOptions: const ForegroundTaskOptions(
            interval: 5000,
            autoRunOnBoot: true,
            allowWifiLock: true,
          ),
          // printDevLog: true,
        );
      } catch (err) {
        //
        VideoSDKLog.createLog(
            message: "Error in foreground notification \n ${err.toString()}",
            logLevel: "WARN");
        //
        log(err.toString());
      }

      try {
        if (_joinSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: _joinSpan!,
            message: 'Room Joined',
            status: StatusCode.ok,
          );
        }
      } catch (error) {}
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in joinRoom() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log(error.toString());

      if (_joinSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: _joinSpan!,
          message: 'Room Join Failed \n ${error.toString()}',
          status: StatusCode.error,
        );
      }

      _close();
    }
  }

  Future<void> _createSendTransport({Span? parentSpan}) async {
    if (_webSocket == null) {
      return;
    }

    log("Send Transport $_produce");
    Span? sendTransportSpan;
    try {
      if (_produce) {
        try {
          if (videoSDKTelemetery != null && parentSpan != null) {
            sendTransportSpan = videoSDKTelemetery!
                .trace(spanName: 'Create Send Transport', span: parentSpan);
          }
        } catch (error) {}

        Map transportInfo =
            await _webSocket!.socket.request('createWebRtcTransport', {
          'preferredProtocol': _preferredProtocol,
          'producing': true,
          'consuming': false,
          'sctpCapabilities': _device!.sctpCapabilities.toMap(),
        });

        _sendTransport = _device!.createSendTransportFromMap(
          transportInfo,
          producerCallback: _producerCallback,
          iceServers: _iceServers,
        );

        _sendTransport!.on('connect', (Map data) {
          try {
            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName:
                      'this._sendTransport `connect` Event : Transport is about to establish the ICE+DTLS connection');
            }
          } catch (error) {}

          //
          _webSocket!.socket
              .request('connectWebRtcTransport', {
                'transportId': _sendTransport!.id,
                'dtlsParameters': data['dtlsParameters'].toMap(),
              })
              .then(data['callback'])
              .catchError((error) {
                data['callback'];
                //
                VideoSDKLog.createLog(
                    message:
                        "Error in sendTransport connect \n ${error.toString()}",
                    logLevel: "ERROR");
              });
        });

        _sendTransport!.on('produce', (Map data) async {
          try {
            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName:
                      'this._sendTransport `produce` Event : Transmit information about a new producer');
            }
          } catch (error) {}

          try {
            Map response = await _webSocket!.socket.request(
              'produce',
              {
                'transportId': _sendTransport!.id,
                'kind': data['kind'],
                'rtpParameters': data['rtpParameters'].toMap(),
                if (data['appData'] != null)
                  'appData': Map<String, dynamic>.from(data['appData'])
              },
            );

            data['callback'](response['id']);
          } catch (error) {
            data['errback'](error);
            //
            VideoSDKLog.createLog(
                message:
                    "Error in sendTransport produce \n ${error.toString()}",
                logLevel: "ERROR");
          }
        });

        _sendTransport!.on('producedata', (data) async {
          try {
            Map response = await _webSocket!.socket.request('produceData', {
              'transportId': _sendTransport!.id,
              'sctpStreamParameters': data['sctpStreamParameters'].toMap(),
              'label': data['label'],
              'protocol': data['protocol'],
              'appData': data['appData'],
            });

            data['callback'](response['id']);
          } catch (error) {
            data['errback'](error);
            //
            VideoSDKLog.createLog(
                message:
                    "Error in sendTransport produceData \n ${error.toString()}",
                logLevel: "ERROR");
          }
        });

        _sendTransport!.on('connectionstatechange', (connectionState) {
          try {
            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName:
                      '_sendTransport Event connectionStateChange $connectionState');
            }
          } catch (error) {}

          //
          if (connectionState['connectionState'] == 'failed') {
            _close("Network Error");
          }
        });

        var reportCounter = 0;
        Probe probe =
            _metricsCollector!.addNewProbe(_sendTransport!, "sendTransport");
        _eventEmitter.on("stats-collected-${probe.id}", (report) {
          try {
            if (_stats['producerStats'] == null) {
              _stats['producerStats'] = {};
            }
            if (_stats['producerStats']['audio'] == null) {
              _stats['producerStats']['audio'] = [];
            }
            _latestStats[_micProducer?.id] = [];
            report['audio'].forEach((stat) {
              if (stat['trackId'] == _micProducer?.track.id) {
                _latestStats[_micProducer?.id].add(stat);
                if (reportCounter % 5 == 0) {
                  _stats['producerStats']['audio'].add(stat);
                }
              }
            });
            if (_stats['producerStats']['video'] == null) {
              _stats['producerStats']['video'] = [];
            }
            if (_stats['producerStats']['share'] == null) {
              _stats['producerStats']['share'] = [];
            }
            _latestStats[_cameraProducer?.id] = [];
            _latestStats[_screenshareProducer?.id] = [];
            report['video'].forEach((stat) {
              if (stat['trackId'] == _cameraProducer?.track.id) {
                _latestStats[_cameraProducer?.id].add(stat);
              } else if (stat['trackId'] == _screenshareProducer?.track.id) {
                _latestStats[_screenshareProducer?.id].add(stat);
              }
            });

            if (reportCounter % 5 == 0 && _cameraProducer != null) {
              _stats['producerStats']['video'].add({
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'stats': _latestStats[_cameraProducer?.id],
              });
            }
            if (reportCounter % 5 == 0 && _screenshareProducer != null) {
              _stats['producerStats']['share'].add({
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'stats': _latestStats[_screenshareProducer?.id],
              });
            }
            reportCounter++;
          } catch (error) {
            //
            VideoSDKLog.createLog(
                message: "Error in stats-collected \n ${error.toString()}",
                logLevel: "DEBUG");

            //
            log("PART ERRO :: ${error.toString()}");
          }
        });
        probe.start();
        _sendTransport!.observer.on('close', () {
          probe.stop();
          _metricsCollector!.removeExistingProbe(probe);
        });

        if (sendTransportSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: sendTransportSpan,
            message: 'Send Transport Created Successfully',
            status: StatusCode.ok,
          );
        }
      }
    } catch (error) {
      VideoSDKLog.createLog(
          message: "Error in _createSendTransport ${error.toString()}",
          logLevel: "ERROR");

      if (sendTransportSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: sendTransportSpan,
          message: 'Send Transport failed with error: ${error.toString()}',
          status: StatusCode.error,
        );
      }
    }
  }

  Future<void> _createReceiveTransport({Span? parentSpan}) async {
    if (_webSocket == null) {
      return;
    }
    Span? receiveTransportSpan;
    try {
      if (_consume) {
        try {
          if (videoSDKTelemetery != null) {
            receiveTransportSpan = videoSDKTelemetery!
                .trace(spanName: 'Create Receive Transport', span: parentSpan);
          }
        } catch (error) {}

        Map transportInfo = await _webSocket!.socket.request(
          'createWebRtcTransport',
          {
            'preferredProtocol': _preferredProtocol,
            'producing': false,
            'consuming': true,
            'sctpCapabilities': _device!.sctpCapabilities.toMap(),
          },
        );

        _recvTransport = _device!.createRecvTransportFromMap(
          transportInfo,
          consumerCallback: _consumerCallback,
          iceServers: _iceServers,
        );

        _recvTransport!.on(
          'connect',
          (data) {
            try {
              if (videoSDKTelemetery != null) {
                videoSDKTelemetery!.traceAutoComplete(
                    spanName:
                        'this._recvTransport `connect` Event : Receive Transport is about to establish the ICE+DTLS connection');
              }
            } catch (error) {}

            //
            _webSocket!.socket
                .request(
                  'connectWebRtcTransport',
                  {
                    'transportId': _recvTransport!.id,
                    'dtlsParameters': data['dtlsParameters'].toMap(),
                  },
                )
                .then(data['callback'])
                .catchError((error) {
                  data['callback'];
                  //
                  VideoSDKLog.createLog(
                      message:
                          "Error in receiveTransport connect \n ${error.toString()}",
                      logLevel: "ERROR");
                });
          },
        );

        _recvTransport!.on('connectionstatechange', (connectionState) {
          try {
            if (videoSDKTelemetery != null) {
              videoSDKTelemetery!.traceAutoComplete(
                  spanName:
                      '_recvTransport Event connectionStateChange $connectionState');
            }
          } catch (error) {}

          if (connectionState['connectionState'] == 'failed') {
            _close("Network Error");
          }
        });

        var reportCounter = 0;
        Probe probe =
            _metricsCollector!.addNewProbe(_recvTransport!, "transport");
        _eventEmitter.on("stats-collected-${probe.id}", (report) {
          report['audio'].forEach((stat) {
            Consumer? consumer = _recvTransport?.consumers[stat['trackId']];
            if (consumer != null) {
              var consumerType = consumer.appData['share'] == true
                  ? consumer.kind == "audio"
                      ? "shareAudio"
                      : "share"
                  : consumer.kind;
              if (_stats['consumerStats'] == null) {
                _stats['consumerStats'] = {};
              }
              if (_stats['consumerStats'][consumer.peerId] == null) {
                _stats['consumerStats'][consumer.peerId] = {};
              }
              if (_stats['consumerStats'][consumer.peerId][consumerType] ==
                  null) {
                _stats['consumerStats'][consumer.peerId][consumerType] = [];
              }
              if (stat['trackId'] == consumer.id) {
                _latestStats[consumer.id] = [];

                _latestStats[consumer.id].add(stat);
                if (reportCounter % 5 == 0) {
                  _stats['consumerStats'][consumer.peerId][consumerType]
                      .add(stat);
                }
              }
            }
          });
          report['video'].forEach((stat) {
            Consumer? consumer = _recvTransport?.consumers[stat['trackId']];
            if (consumer != null) {
              var consumerType = consumer.appData['share'] == true
                  ? consumer.kind == "audio"
                      ? "shareAudio"
                      : "share"
                  : consumer.kind;
              if (_stats['consumerStats'] == null) {
                _stats['consumerStats'] = {};
              }
              if (_stats['consumerStats'][consumer.peerId] == null) {
                _stats['consumerStats'][consumer.peerId] = {};
              }
              if (_stats['consumerStats'][consumer.peerId][consumerType] ==
                  null) {
                _stats['consumerStats'][consumer.peerId][consumerType] = [];
              }
              if (stat['trackId'] == consumer.id) {
                _latestStats[consumer.id] = [];

                _latestStats[consumer.id].add(stat);
                if (reportCounter % 5 == 0) {
                  _stats['consumerStats'][consumer.peerId][consumerType]
                      .add(stat);
                }
              }
            }
          });
          reportCounter++;
        });
        probe.start();
        _recvTransport?.observer.on('close', () {
          probe.stop();
          _metricsCollector!.removeExistingProbe(probe);
        });

        if (receiveTransportSpan != null) {
          videoSDKTelemetery!.completeSpan(
            span: receiveTransportSpan,
            message: 'Receive Transport Created Successfully',
            status: StatusCode.ok,
          );
        }
      }
    } catch (error) {
      VideoSDKLog.createLog(
          message: "Error in receiveTransport ${error.toString()}",
          logLevel: "ERROR");

      if (receiveTransportSpan != null) {
        videoSDKTelemetery!.completeSpan(
          span: receiveTransportSpan,
          message: 'Receive Transport failed with error: ${error.toString()}',
          status: StatusCode.error,
        );
      }
    }
  }

  void end() {
    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in end(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");

      return;
    }
    if (_closed) {
      return;
    }
    if (videoSDKTelemetery != null) {
      videoSDKTelemetery!.traceAutoComplete(
        spanName: 'end() method called \n closeRoom request send',
      );
    }
    _webSocket?.socket.request('closeRoom', {});
    _close();
  }

  void leave() {
    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in leave(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");

      return;
    }
    if (videoSDKTelemetery != null) {
      videoSDKTelemetery!.traceAutoComplete(
        spanName: 'leave() method called',
      );
    }
    _close();
  }

  void _closeForegroundService() async {
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        //
        if (await FlutterForegroundTask.isRunningService) {
          FlutterForegroundTask.stopService();
        }
      }
    }
  }

  void _close([String? errorMsg]) {
    if (_closed) {
      return;
    }

    try {
      if (videoSDKTelemetery != null) {
        videoSDKTelemetery!.traceAutoComplete(
          spanName: 'Meeting is in CLOSING State',
        );
      }
    } catch (error) {}

    if (_micProducer != null) {
      if (!_micProducer!.closed && _micProducer!.paused) {
        _micProducer!.resume();
      }
      _micProducer!.track.stop();
      _micProducer!.close();
      _micProducer = null;
    }

    _closed = true;

    _closeForegroundService();

    _webSocket?.close();
    _metricsCollector?.stopAllProbes();

    Span? closeSpan;
    try {
      if (videoSDKTelemetery != null) {
        closeSpan = videoSDKTelemetery!.trace(
          spanName: 'Closing Trasnport',
        );
      }
    } catch (error) {}

    _sendTransport?.close();
    _recvTransport?.close();

    if (closeSpan != null && videoSDKTelemetery != null) {
      videoSDKTelemetery!.completeSpan(
          span: closeSpan, status: StatusCode.ok, message: 'Closed Trasnport');
    }

    _eventEmitter.emit("meeting-left", errorMsg);
    try {
      if (videoSDKTelemetery != null) {
        videoSDKTelemetery!.traceAutoComplete(
          spanName: 'Emitted MEETING_LEFT Event',
        );
        videoSDKTelemetery!.traceAutoComplete(
          spanName: 'Meeting is in CLOSED State',
        );

        videoSDKTelemetery!.flush();
      }
    } catch (error) {}
  }

  Future<void> changeMode(Mode requestedMode) async {
    Mode currentMode = _mode;
    Span? changeModeSpan;
    Span? routerSpan;
    Span? requestSpan;

    if (_webSocket == null) {
      _eventEmitter.emit("error", VideoSDKErrors[3022]);
      print(
          "An error occurred in changeMode(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
      return;
    }

    try {
      if (videoSDKTelemetery != null) {
        changeModeSpan =
            videoSDKTelemetery!.trace(spanName: 'Changing Mode', attributes: [
          Attribute.fromString('peer.currentMode', currentMode.toString()),
          Attribute.fromString('peer.requestedMode', requestedMode.toString())
        ]);
      }
    } catch (error) {}

    try {
      if (currentMode == requestedMode) {
        //
        _eventEmitter.emit("error", VideoSDKErrors[3021]);
        Map<String, String> attributes = {
          "error": "Error in changeMode() : Already in the $requestedMode mode"
        };
        VideoSDKLog.createLog(
            message:
                "Mode change failed. You are already in the $requestedMode mode. Please select a different mode and try again.",
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in changeMode(): You are already in the $requestedMode mode. Please select a different mode and try again.");

        //
        if (changeModeSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: changeModeSpan,
              status: StatusCode.error,
              message: 'Already in the $requestedMode mode');
        }

        return;
      }
      _mode = requestedMode;
      if (requestedMode == Mode.CONFERENCE) {
        log("Changing mode to Conference");
        _consume = true;

        try {
          if (changeModeSpan != null) {
            routerSpan = videoSDKTelemetery!.trace(
                spanName: 'Loading Router Capabilities', span: changeModeSpan);
          }
        } catch (error) {}

        dynamic routerRtpCapabilities =
            await _webSocket!.socket.request('getRouterRtpCapabilities', {});

        final rtpCapabilities = RtpCapabilities.fromMap(routerRtpCapabilities);
        rtpCapabilities.headerExtensions
            .removeWhere((he) => he.uri == 'urn:3gpp:video-orientation');

        _device = Device();

        if (_device != null) {
          await _device!.load(routerRtpCapabilities: rtpCapabilities);
        } else {
          try {
            if (routerSpan != null) {
              videoSDKTelemetery!.completeSpan(
                span: routerSpan,
                status: StatusCode.error,
                message:
                    'Loading Router Capabilities Failed \n Mediasoup device not found',
              );
            }
          } catch (e) {}

          _eventEmitter.emit("error", VideoSDKErrors[3021]);
          Map<String, String> attributes = {
            "error": "Error in changeMode(): Something went wrong.",
            "errorMessage": "Error in changeMode(): MediaSoup device not found."
          };
          VideoSDKLog.createLog(
              message: VideoSDKErrors[3021]!['message']!,
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred in changeMode(): VIDEOSDK ERROR :: ${VideoSDKErrors[3021]?['code']}  :: ${VideoSDKErrors[3021]?['name']} :: ${VideoSDKErrors[3021]?['message']}");
          return;
        }

        try {
          if (routerSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: routerSpan,
                message:
                    'Router Capabilities Loaded ${routerRtpCapabilities.toString()}',
                status: StatusCode.ok);
            routerSpan = null;
          }
        } catch (error) {}

        if (_device!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio) == true ||
            _device!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo) == true) {
          _produce = true;
        } else {
          _produce = false;
        }

        await _createSendTransport(parentSpan: changeModeSpan);

        await _createReceiveTransport(parentSpan: changeModeSpan);

        try {
          if (changeModeSpan != null) {
            requestSpan = videoSDKTelemetery!.trace(
                spanName: 'Sending changeMode request to server',
                span: changeModeSpan);
          }
        } catch (error) {}

        _webSocket?.socket
            .request("changeMode", {"mode": requestedMode.parseToString()});

        try {
          if (requestSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: requestSpan,
                message: 'ChangeMode Request To Server Sent Successfully',
                status: StatusCode.ok);
            requestSpan = null;
          }
        } catch (error) {}

        if (_produce) {
          if (_micEnabled) {
            await _enableMicImpl(
              parentSpan: changeModeSpan,
            );
          } else {
            if (_customMicrophoneAudioTrack != null) {
              _customMicrophoneAudioTrack?.dispose();
            }
          }
          if (_camEnabled) {
            await _enableCamImpl(parentSpan: changeModeSpan);
          } else {
            if (_customCameraVideoTrack != null) {
              _customCameraVideoTrack?.dispose();
            }
          }
        }

        _eventEmitter.emit("participant-mode-changed-${localParticipant.id}",
            {'participantId': localParticipant.id, 'mode': 'CONFERENCE'});
        _eventEmitter.emit("participant-mode-changed",
            {'participantId': localParticipant.id, 'mode': 'CONFERENCE'});

        try {
          if (changeModeSpan != null) {
            videoSDKTelemetery!.traceAutoComplete(
                span: changeModeSpan,
                spanName:
                    "Emitting 'PEER_MODE_CHANGED' for Peer : ${localParticipant.id}");
            requestSpan = null;
          }
        } catch (error) {}
      } else if (requestedMode == Mode.VIEWER) {
        try {
          if (changeModeSpan != null) {
            requestSpan = videoSDKTelemetery!.trace(
                spanName: 'Sending changeMode request to server',
                span: changeModeSpan);
          }
        } catch (error) {}

        _webSocket?.socket
            .request("changeMode", {"mode": requestedMode.parseToString()});

        try {
          if (requestSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: requestSpan,
                message: 'ChangeMode Request To Server Sent Successfully',
                status: StatusCode.ok);
            requestSpan = null;
          }
        } catch (error) {}

        _consume = false;
        _produce = false;

        _sendTransport?.close();
        _sendTransport = null;

        _recvTransport?.close();
        _recvTransport = null;
      }

      if (changeModeSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: changeModeSpan,
            status: StatusCode.ok,
            message: 'Change Mode Successfully');
      }
    } catch (error) {
      //
      _eventEmitter.emit("error", VideoSDKErrors[3021]);
      Map<String, String> attributes = {
        "error": "Error in changeMode(): Something went wrong.",
        "errorMessage": "Error in changeMode(): ${error.toString()}"
      };
      VideoSDKLog.createLog(
          message: VideoSDKErrors[3021]!['message']!,
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in changeMode(): VIDEOSDK ERROR :: ${VideoSDKErrors[3021]?['code']}  :: ${VideoSDKErrors[3021]?['name']} :: ${VideoSDKErrors[3021]?['message']}");

      if (routerSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: routerSpan,
            status: StatusCode.error,
            message: 'Router Capabilities Loading Failed');
      }
      if (requestSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: requestSpan,
            status: StatusCode.error,
            message: 'Sending Request to the Server Failed');
      }
      if (changeModeSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: changeModeSpan,
            status: StatusCode.error,
            message: 'Change Mode Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> _requestEntry() async {
    if (_closed) {
      Timer(const Duration(seconds: 2), () {
        _webSocket?.close();
      });
      return;
    }

    Span? requestEntrySpan;

    try {
      if (videoSDKTelemetery != null && _joinSpan != null) {
        requestEntrySpan = videoSDKTelemetery!.trace(
          spanName: 'Requesting Entry',
          span: _joinSpan,
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request("requestEntry", <String, dynamic>{
          'name': localParticipant.displayName,
        });
      } else {
        try {
          if (requestEntrySpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: requestEntrySpan,
                status: StatusCode.error,
                message: 'Entry Requested Failed, websocket was null');
          }
        } catch (error) {}
        return;
      }

      try {
        if (requestEntrySpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: requestEntrySpan,
              status: StatusCode.ok,
              message: 'Entry Requested Successfully');
        }
      } catch (error) {}
    } catch (error) {
      VideoSDKLog.createLog(
          message: "Error in _requestEntry() \n ${error.toString()}",
          logLevel: "ERROR");

      try {
        if (requestEntrySpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: requestEntrySpan,
              status: StatusCode.error,
              message: 'Entry Requested Failed, \n ${error.toString()}');
        }
      } catch (error) {}
    }
  }

  Future<void> _respondEntry(peerId, decision, Span? span) async {
    Span? respondEntrySpan;
    try {
      if (videoSDKTelemetery != null) {
        respondEntrySpan = videoSDKTelemetery!.trace(
          spanName: 'Responding Entry',
          attributes: [
            Attribute.fromString('peerId', peerId),
            Attribute.fromString('decision', decision),
          ],
          span: span,
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request("respondEntry",
            <String, dynamic>{'id': peerId, 'decision': decision});
      } else {
        try {
          if (respondEntrySpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: respondEntrySpan,
                status: StatusCode.error,
                message: 'Entry Responded Failed, websocket was null');
          }
        } catch (error) {}
        return;
      }

      try {
        if (respondEntrySpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: respondEntrySpan,
              status: StatusCode.ok,
              message: 'Entry Responded Successfully');
        }
      } catch (error) {}
    } catch (error) {
      VideoSDKLog.createLog(
          message: "Error in _respondEntry() \n ${error.toString()}",
          logLevel: "ERROR");

      try {
        if (respondEntrySpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: respondEntrySpan,
              status: StatusCode.error,
              message: 'Entry Responded Failed, \n ${error.toString()}');
        }
      } catch (error) {}
    }
  }

  Future<void> startRecording(
      {String? webhookUrl,
      String? awsDirPath,
      Map<String, dynamic>? config,
      PostTranscriptionConfig? postTranscriptionConfig}) async {
    Map<String, dynamic> data = {};
    if (webhookUrl != null) data["webhookUrl"] = webhookUrl;
    if (awsDirPath != null) data["awsDirPath"] = awsDirPath;
    if (config != null) data["config"] = config;
    if (postTranscriptionConfig != null) {
      data["transcription"] = postTranscriptionConfig;
    }

    Span? startRecordingSpan;

    try {
      if (videoSDKTelemetery != null) {
        startRecordingSpan = videoSDKTelemetery!.trace(
          spanName: 'startRecording() Start',
          attributes: [
            Attribute.fromString(
                'webhookUrl', webhookUrl ?? 'webhookUrl Not Specify'),
            Attribute.fromString(
                'awsDirPath', awsDirPath ?? 'awsDirPath Not Specify'),
            Attribute.fromString('config',
                config != null ? config.toString() : 'config Not Specify'),
            Attribute.fromString(
                'transcription',
                postTranscriptionConfig != null
                    ? postTranscriptionConfig.toString()
                    : 'transcription not started'),
          ],
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('startRecording', data);

        if (startRecordingSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: startRecordingSpan,
              status: StatusCode.ok,
              message: 'startRecording() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in startRecording(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in startRecording() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Recording start request failed due to an error : $error");

      if (startRecordingSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: startRecordingSpan,
            status: StatusCode.error,
            message: 'startRecording() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> stopRecording() async {
    Span? stopRecordingSpan;
    try {
      if (videoSDKTelemetery != null) {
        stopRecordingSpan = videoSDKTelemetery!.trace(
          spanName: 'stopRecording() Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('stopRecording', {});

        if (stopRecordingSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: stopRecordingSpan,
              status: StatusCode.ok,
              message: 'stopRecording() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in stopRecording(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in stopRecording() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while stopping recording $error");

      if (stopRecordingSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: stopRecordingSpan,
            status: StatusCode.error,
            message: 'stopRecording() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> startLivestream(outputs,
      {Map<String, dynamic>? config,
      PostTranscriptionConfig? postTranscriptionConfig}) async {
    Map<String, dynamic> data = {};
    if (outputs != null) data["outputs"] = outputs;
    if (config != null) data["config"] = config;
    if (postTranscriptionConfig != null) {
      data["transcription"] = postTranscriptionConfig;
    }

    Span? startLivestreamSpan;
    try {
      if (videoSDKTelemetery != null) {
        startLivestreamSpan = videoSDKTelemetery!.trace(
          spanName: 'startLivestream() Start',
          attributes: [
            Attribute.fromString('outputs',
                outputs != null ? outputs.toString() : 'outputs Not Specify'),
            Attribute.fromString('config',
                config != null ? config.toString() : 'config Not Specify'),
            Attribute.fromString(
                'transcription',
                postTranscriptionConfig != null
                    ? postTranscriptionConfig.toString()
                    : 'transcription not started'),
          ],
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('startLivestream', data);

        if (startLivestreamSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: startLivestreamSpan,
              status: StatusCode.ok,
              message: 'startLivestream() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in startLivestream(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in startLivestream() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while starting livestreaming $error");

      if (startLivestreamSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: startLivestreamSpan,
            status: StatusCode.error,
            message: 'startLivestream() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> stopLivestream() async {
    Span? stopLivestreamSpan;
    try {
      if (videoSDKTelemetery != null) {
        stopLivestreamSpan = videoSDKTelemetery!.trace(
          spanName: 'stopLivestream() Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('stopLivestream', {});

        if (stopLivestreamSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: stopLivestreamSpan,
              status: StatusCode.ok,
              message: 'stopLivestream() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in stopLivestream(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in stopLivestream() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while stopping livestreaming $error");

      if (stopLivestreamSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: stopLivestreamSpan,
            status: StatusCode.error,
            message: 'stopLivestream() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> startHls(
      {Map<String, dynamic>? config,
      PostTranscriptionConfig? postTranscriptionConfig}) async {
    Map<String, dynamic> data = {};
    if (config != null) data["config"] = config;
    if (postTranscriptionConfig != null) {
      data["transcription"] = postTranscriptionConfig;
    }

    Span? startHlsSpan;
    try {
      if (videoSDKTelemetery != null) {
        startHlsSpan = videoSDKTelemetery!.trace(
          spanName: 'startHls() Start',
          attributes: [
            Attribute.fromString('config',
                config != null ? config.toString() : 'config Not Specify'),
            Attribute.fromString(
                'transcription',
                postTranscriptionConfig != null
                    ? postTranscriptionConfig.toString()
                    : 'transcription not started'),
          ],
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('startHls', data);

        if (startHlsSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: startHlsSpan,
              status: StatusCode.ok,
              message: 'startHls() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in startHls(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in startHls() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while starting HLS $error");

      if (startHlsSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: startHlsSpan,
            status: StatusCode.error,
            message: 'startHls() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> stopHls() async {
    Span? stopHlsSpan;
    try {
      if (videoSDKTelemetery != null) {
        stopHlsSpan = videoSDKTelemetery!.trace(
          spanName: 'stopHls() Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('stopHls', {});

        if (stopHlsSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: stopHlsSpan,
              status: StatusCode.ok,
              message: 'stopHls() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in stopHls(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in stopHls() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Error while stopping HLS $error");

      if (stopHlsSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: stopHlsSpan,
            status: StatusCode.error,
            message: 'stopHls() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> startTranscription(
      {TranscriptionConfig? transcriptionConfig}) async {
    Map<String, dynamic> data = {};
    if (transcriptionConfig != null) {
      data["config"] = transcriptionConfig;
    }
    ;

    Span? startTranscriptionSpan;
    try {
      if (videoSDKTelemetery != null) {
        startTranscriptionSpan = videoSDKTelemetery!.trace(
          spanName: 'startTranscription() Start',
          attributes: [
            Attribute.fromString(
                'config',
                transcriptionConfig != null
                    ? transcriptionConfig.toString()
                    : 'config Not Specify'),
          ],
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('startTranscription', data);

        if (startTranscriptionSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: startTranscriptionSpan,
              status: StatusCode.ok,
              message: 'startTranscription() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in startTranscription(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      _eventEmitter.emit("error", VideoSDKErrors[4031]);

      //
      VideoSDKLog.createLog(
          message: "Error in startTranscription() \n ${error.toString()}",
          logLevel: "ERROR");

      //

      if (startTranscriptionSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: startTranscriptionSpan,
            status: StatusCode.error,
            message: 'startTranscription() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> stopTranscription() async {
    Span? stopTranscriptionSpan;
    try {
      if (videoSDKTelemetery != null) {
        stopTranscriptionSpan = videoSDKTelemetery!.trace(
          spanName: 'stopTranscription() Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('stopTranscription', {});

        if (stopTranscriptionSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: stopTranscriptionSpan,
              status: StatusCode.ok,
              message: 'stopTranscription() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in stopTranscription(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      _eventEmitter.emit("error", VideoSDKErrors[4032]);
      //
      VideoSDKLog.createLog(
          message: "Error in stopTranscription() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Error while stopping transcription $error");

      if (stopTranscriptionSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: stopTranscriptionSpan,
            status: StatusCode.error,
            message: 'stopTranscription() Failed \n ${error.toString()}');
      }
    }
  }

  Future<void> changeCam(VideoDeviceInfo device,
      [CustomTrack? customTrack]) async {
    if (_selectedVideoInput?.deviceId == device.deviceId) {
      return;
    }

    Span? changeCamSpan;
    try {
      if (videoSDKTelemetery != null) {
        changeCamSpan =
            videoSDKTelemetery!.trace(spanName: 'Changing Webcam', attributes: [
          Attribute.fromString(
              'customTrack',
              customTrack != null
                  ? customTrack.toString()
                  : 'Not using customTrack'),
          Attribute.fromString('deviceId', device.deviceId),
        ]);
      }
    } catch (error) {}

    try {
      //
      _cameraInProgress = true;

      if (customTrack != null) {
        if (customTrack.ended == true) {
          customTrack = null;
          _eventEmitter.emit("error", VideoSDKErrors[3001]);

          Map<String, String> attributes = {
            "error":
                "Error in changeCam(): Provided Custom Track has been disposed."
          };
          VideoSDKLog.createLog(
              message: VideoSDKErrors[3001]!['message']!,
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred in changeCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3001]?['code']}  :: ${VideoSDKErrors[3001]?['name']} :: ${VideoSDKErrors[3001]?['message']}");
        }
      }
      //
      await _disableCamImpl(parentSpan: changeCamSpan);

      customTrack ??= await VideoSDK.createCameraVideoTrack(
          cameraId: device.deviceId,
          multiStream: _multiStream,
          encoderConfig: CustomVideoTrackConfig.h720p_w1280p);

      //If there is an error, createCameraVideoTrack will return null.
      if (customTrack == null) {
        if (changeCamSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: changeCamSpan,
              status: StatusCode.error,
              message: 'Change Webcam Failed, could not create Video Track');
        }
        _eventEmitter.emit("error", VideoSDKErrors[3011]);
        Map<String, String> attributes = {
          "error": "Error in changeCam(): Something went wrong.",
          "errorMessage":
              "Error in changeCam() : Custom Track could not be created."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3011]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in changeCam(): VIDEOSDK ERROR :: ${VideoSDKErrors[3011]?['code']}  :: ${VideoSDKErrors[3011]?['name']} :: ${VideoSDKErrors[3011]?['message']}");

        _cameraInProgress = false;
        return;
      }

      _enableCamImpl(customTrack: customTrack, parentSpan: changeCamSpan);

      //
      _cameraInProgress = false;

      if (changeCamSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: changeCamSpan,
            status: StatusCode.ok,
            message: 'Change Webcam Successful');
      }
    } catch (err) {
      //
      Map<String, String> attributes = {
        "error": "Error in changeCam(): Something went wrong.",
        "errorMessage": "Error in changeCam(): ${err.toString()}"
      };
      VideoSDKLog.createLog(
          message:
              "Something went wrong, and the camera could not be changed. Please try again.",
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "An error occurred in changeCam(): Something went wrong, and the camera could not be changed. Please try again.");

      //
      if (changeCamSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: changeCamSpan,
            status: StatusCode.error,
            message: 'Change Webcam Failed \n ${err.toString()}');
      }
    }
  }

  //
  // @Deprecated("Use VideoSDK.getVideoDevices() method instead")
  // List<MediaDeviceInfo> getCameras() =>
  //     VideoSDK.mediaDevices[MediaDeviceType.videoInput]!;

  @Deprecated("Use selectedCam instead")
  String? get selectedCamId => _selectedVideoInput?.deviceId;

  VideoDeviceInfo? get selectedCam => _selectedVideoInput;

  bool _isMobilePlatform() {
    if (kIsWeb) {
      return false;
    } else {
      if (Platform.isMacOS || Platform.isWindows) {
        return false;
      }
    }
    return true;
  }

  //
  // @Deprecated("Use VideoSDK.getAudioDevices() method instead")
  // List<MediaDeviceInfo> getMics() {
  //   if (!_isMobilePlatform()) {
  //     return VideoSDK.mediaDevices[MediaDeviceType.audioInput]!;
  //   }
  //   return [];
  // }

  // @Deprecated("Use VideoSDK.getAudioDevices() method instead")
  // List<MediaDeviceInfo> getAudioOutputDevices() {
  //   List<MediaDeviceInfo> audioOutputDevices =
  //       VideoSDK.mediaDevices[MediaDeviceType.audioOutput]!;
  //   if (!kIsWeb) {
  //     if (Platform.isIOS) {
  //       if (audioOutputDevices.length == 1) {
  //         MediaDeviceInfo mediaDeviceInfo = MediaDeviceInfo(
  //             label: "Receiver",
  //             deviceId: "Built-In Receiver",
  //             kind: "audiooutput");
  //         audioOutputDevices.add(mediaDeviceInfo);
  //       }
  //     }
  //   }
  //   return audioOutputDevices;
  // }

  Future<void> switchAudioDevice(AudioDeviceInfo device) async {

    Span? switchAudioDeviceSpan;
    try {
      if (videoSDKTelemetery != null) {
        switchAudioDeviceSpan =
            videoSDKTelemetery!.trace(spanName: 'Switching AudioDevice');
      }
    } catch (error) {}

    try {
      if (!kIsWeb) {
        if (Platform.isIOS && device.deviceId == "Built-In Receiver") {
          await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
              appleAudioCategory: AppleAudioCategory.playAndRecord,
              appleAudioCategoryOptions: {
                AppleAudioCategoryOption.allowBluetooth,
                AppleAudioCategoryOption.allowBluetoothA2DP
              },
              appleAudioMode: AppleAudioMode.voiceChat));
        } else {
          await navigator.mediaDevices
              .selectAudioOutput(AudioOutputOptions(deviceId: device.deviceId));
        }
      } else {
        AudioHTMLInterface().setAudioOutputDevice(device.deviceId);
      }

      _selectedAudioOutput = device;

      if (switchAudioDeviceSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: switchAudioDeviceSpan,
            status: StatusCode.ok,
            message: 'Switching AudioDevice Successful');
      }
    } catch (e) {
      if (switchAudioDeviceSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: switchAudioDeviceSpan,
            status: StatusCode.ok,
            message: 'Switching AudioDevice UnSuccessful');
      }
      Map<String, String> attributes = {
        "error": "Error in switchAudioDevice(): Something went wrong.",
        "errorMessage": "Error in switchAudioDevice(): ${e.toString()}."
      };
      VideoSDKLog.createLog(
          message:
              "Something went wrong, and the audio device could not be switched. Please try again.",
          logLevel: "ERROR",
          attributes: attributes,
          dashboardLog: true);
      print(
          "Something went wrong, and the audio device could not be switched. Please try again.");
    }
  }

  @Deprecated("Use selectedSpeaker instead")
  String? get selectedSpeakerId => _selectedAudioOutput?.deviceId;

  AudioDeviceInfo? get selectedSpeaker => _selectedAudioOutput;

  Future<void> changeMic(AudioDeviceInfo device,
      [CustomTrack? customTrack]) async {
    if (!_isMobilePlatform()) {
      if (_selectedAudioInput == device) {
        return;
      }

      Span? changeMicSpan;
      try {
        if (videoSDKTelemetery != null) {
          changeMicSpan =
              videoSDKTelemetery!.trace(spanName: 'Changing Mic', attributes: [
            Attribute.fromString(
                'customTrack',
                customTrack != null
                    ? customTrack.toString()
                    : "Not using customTrack"),
            Attribute.fromString("deviceId", device.deviceId),
            Attribute.fromString("deviceLabel", device.label)
          ]);
        }
      } catch (error) {}

      try {
        if (customTrack != null) {
          if (customTrack.ended == true) {
            customTrack = null;
            _eventEmitter.emit("error", VideoSDKErrors[3002]);

            Map<String, String> attributes = {
              "error":
                  "Error in changeMic(): Provided Custom Track has been disposed."
            };
            VideoSDKLog.createLog(
                message: VideoSDKErrors[3002]!['message']!,
                logLevel: "ERROR",
                attributes: attributes,
                dashboardLog: true);
            print(
                "An error occurred in changeMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3002]?['code']}  :: ${VideoSDKErrors[3002]?['name']} :: ${VideoSDKErrors[3002]?['message']}");
          }
        }

        await _disableMic(parentSpan: changeMicSpan);

        customTrack ??= await VideoSDK.createMicrophoneAudioTrack(
            microphoneId: device.deviceId,
            encoderConfig: CustomAudioTrackConfig.speech_standard);

        if (customTrack == null) {
          try {
            if (changeMicSpan != null) {
              videoSDKTelemetery!.completeSpan(
                  span: changeMicSpan,
                  status: StatusCode.error,
                  message:
                      'Change Mic Unsuccessful, custom track couldnt be created.');
            }
          } catch (error) {}

          _eventEmitter.emit("error", VideoSDKErrors[3012]);
          Map<String, String> attributes = {
            "error": "Error in changeMic(): Something went wrong.",
            "errorMessage":
                "Error in changeMic() : Custom Track could not be created."
          };
          VideoSDKLog.createLog(
              message: VideoSDKErrors[3012]!['message']!,
              logLevel: "ERROR",
              attributes: attributes,
              dashboardLog: true);
          print(
              "An error occurred in changeMic(): VIDEOSDK ERROR :: ${VideoSDKErrors[3012]?['code']}  :: ${VideoSDKErrors[3012]?['name']} :: ${VideoSDKErrors[3012]?['message']}");

          return;
        }

        await _enableMicImpl(
            customTrack: customTrack, parentSpan: changeMicSpan);

        if (changeMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: changeMicSpan,
              status: StatusCode.ok,
              message: 'Change Mic Successful');
        }
      } catch (e) {
        Map<String, String> attributes = {
          "error": "Error in changeMic(): Something went wrong.",
          "errorMessage": "Error in changeMic(): ${e.toString()}"
        };
        VideoSDKLog.createLog(
            message:
                "Something went wrong, and the microphone could not be changed. Please try again.",
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in changeMic(): Something went wrong, and the microphone could not be changed. Please try again.");

        //
        if (changeMicSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: changeMicSpan,
              status: StatusCode.error,
              message: 'Change Mic Failed \n ${e.toString()}');
        }
      }
    } else {
      throw UnsupportedError(
          'The changeMic() method is not supported for Mobile devices, Use switchAudioDevice() method instead.');
    }
  }

  //for mobile return audio output
  @Deprecated("Use selectedMic Instead")
  String? get selectedMicId {
    if (_isMobilePlatform()) {
      return _selectedAudioOutput?.deviceId;
    } else {
      return _selectedAudioInput?.deviceId;
    }
  }

  AudioDeviceInfo? get selectedMic {
    if (_isMobilePlatform()) {
      return _selectedAudioOutput;
    } else {
      return _selectedAudioInput;
    }
  }

  //
  bool get micEnabled => _micState;

  //
  bool get camEnabled => _camState;

  //
  Future<void> _enablePeerMic(String peerId) async {
    Span? enablePeerMic;
    try {
      if (videoSDKTelemetery != null) {
        enablePeerMic = videoSDKTelemetery!.trace(
          spanName: 'Enable Peer Mic for $peerId Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('enablePeerMic', {
          "peerId": peerId,
        });
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in enabling participant.unmuteMic(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        if (enablePeerMic != null) {
          videoSDKTelemetery!.completeSpan(
              span: enablePeerMic,
              status: StatusCode.error,
              message:
                  'Enable Peer Mic for $peerId Failed, websocket was null');
        }
        return;
      }

      if (enablePeerMic != null) {
        videoSDKTelemetery!.completeSpan(
            span: enablePeerMic,
            status: StatusCode.ok,
            message: 'Enable Peer Mic for $peerId Completed');
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in enablePeerMic() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while enabling peer's mic: $error");

      if (enablePeerMic != null) {
        videoSDKTelemetery!.completeSpan(
            span: enablePeerMic,
            status: StatusCode.error,
            message:
                'Enable Peer Mic for $peerId Failed \n ${error.toString()}');
      }
    }
  }

  //
  Future<void> _disablePeerMic(String peerId) async {
    Span? disablePeerMic;

    try {
      if (videoSDKTelemetery != null) {
        disablePeerMic = videoSDKTelemetery!.trace(
          spanName: 'Disable Peer Mic for $peerId Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('disablePeerMic', {
          "peerId": peerId,
        });
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in participant.muteMic(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        try {
          if (disablePeerMic != null) {
            videoSDKTelemetery!.completeSpan(
                span: disablePeerMic,
                status: StatusCode.error,
                message:
                    'Disable Peer Mic for $peerId Failed, websocket was null');
          }
        } catch (e) {}
        return;
      }

      if (disablePeerMic != null) {
        videoSDKTelemetery!.completeSpan(
            span: disablePeerMic,
            status: StatusCode.ok,
            message: 'Disable Peer Mic for $peerId Completed');
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in disablePeerMic() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while disabling peer's mic: $error");

      try {
        if (disablePeerMic != null) {
          videoSDKTelemetery!.completeSpan(
              span: disablePeerMic,
              status: StatusCode.error,
              message:
                  'Disable Peer Mic for $peerId Failed \n ${error.toString()}');
        }
      } catch (e) {}
    }
  }

  //
  Future<void> _enablePeerCamera(String peerId) async {
    Span? enablePeerCameraSpan;
    try {
      if (videoSDKTelemetery != null) {
        enablePeerCameraSpan = videoSDKTelemetery!.trace(
          spanName: 'Enable Peer Camera for $peerId Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('enablePeerWebcam', {
          "peerId": peerId,
        });
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in participant.enableCam(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        try {
          if (enablePeerCameraSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: enablePeerCameraSpan,
                status: StatusCode.error,
                message:
                    'Enable Peer Camera for $peerId Failed, websocket was null');
          }
        } catch (e) {}
        return;
      }

      if (enablePeerCameraSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: enablePeerCameraSpan,
            status: StatusCode.ok,
            message: 'Enable Peer Camera for $peerId Completed');
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in enablePeerCamera() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Error while enabling peer's camera $error");

      try {
        if (enablePeerCameraSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: enablePeerCameraSpan,
              status: StatusCode.error,
              message:
                  'Enable Peer Camera for $peerId Failed \n ${error.toString()}');
        }
      } catch (e) {}
    }
  }

  //
  Future<void> _disablePeerCamera(String peerId) async {
    Span? disablePeerCameraSpan;
    try {
      if (videoSDKTelemetery != null) {
        disablePeerCameraSpan = videoSDKTelemetery!.trace(
          spanName: 'Disable Peer Camera for $peerId Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('disablePeerWebcam', {
          "peerId": peerId,
        });
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in participant.disableCam(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        try {
          if (disablePeerCameraSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: disablePeerCameraSpan,
                status: StatusCode.error,
                message:
                    'Disable Peer Camera for $peerId Failed \n websocket was null');
          }
        } catch (error) {}
        return;
      }

      if (disablePeerCameraSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: disablePeerCameraSpan,
            status: StatusCode.ok,
            message: 'Disable Peer Camera for $peerId Completed');
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in disablePeerCamera() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Error while disabling peer's camera $error");

      try {
        if (disablePeerCameraSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: disablePeerCameraSpan,
              status: StatusCode.error,
              message:
                  'Disable Peer Camera for $peerId Failed \n ${error.toString()}');
        }
      } catch (error) {}
    }
  }

  //
  Future<void> _removePeer(String peerId) async {
    Span? removePeer;
    try {
      if (videoSDKTelemetery != null) {
        removePeer = videoSDKTelemetery!.trace(
          spanName: 'Remove $peerId Peer Start',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('removePeer', {
          "peerId": peerId,
        });
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in participant.remove(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        try {
          if (removePeer != null) {
            videoSDKTelemetery!.completeSpan(
                span: removePeer,
                status: StatusCode.error,
                message: 'Remove $peerId Peer Failed \n websocket was null');
          }
        } catch (e) {}
        return;
      }

      if (removePeer != null) {
        videoSDKTelemetery!.completeSpan(
            span: removePeer,
            status: StatusCode.ok,
            message: 'Remove $peerId Peer Completed');
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in removePeer() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while removing peer $error");

      try {
        if (removePeer != null) {
          videoSDKTelemetery!.completeSpan(
              span: removePeer,
              status: StatusCode.error,
              message: 'Remove $peerId Peer Failed \n ${error.toString()}');
        }
      } catch (e) {}
    }
  }

  Future<void> _addProducer(Producer producer) async {
    try {
      final Consumer consumer = Consumer(
        peerId: localParticipant.id,
        appData: producer.appData,
        localId: producer.localId,
        producerId: producer.id,
        id: producer.id,
        stream: producer.stream,
        rtpParameters: producer.rtpParameters,
        track: producer.track,
        closed: producer.closed,
        rtpReceiver: null,
      );

      switch (producer.source) {
        case 'mic':
          {
            _eventEmitter.emit(
              "stream-enabled-${localParticipant.id}",
              {
                "audio": consumer,
              },
            );

            Producer? oldProducer = _micProducer;

            _micProducer = producer;

            if (oldProducer != null) {
              // oldProducer.track.stop();
              oldProducer.close();
            }

            break;
          }
        case 'webcam':
          {
            _cameraRenderer = RTCVideoRenderer();
            await _cameraRenderer?.initialize();

            _cameraRenderer?.srcObject = consumer.stream;

            _eventEmitter.emit(
              "stream-enabled-${localParticipant.id}",
              {
                "video": consumer,
                "renderer": _cameraRenderer as RTCVideoRenderer,
              },
            );

            _cameraProducer = producer;
            break;
          }
        case 'screen':
          {
            _screenshareRenderer = RTCVideoRenderer();
            await _screenshareRenderer!.initialize();

            _screenshareRenderer!.setSrcObject(
                stream: consumer.stream, trackId: consumer.track.id);

            _eventEmitter.emit(
              "stream-enabled-${localParticipant.id}",
              {
                "share": consumer,
                "shareRenderer": _screenshareRenderer as RTCVideoRenderer,
              },
            );

            _screenshareProducer = producer;
            break;
          }
        case 'screen-audio':
          {
            _screenShareAudioRenderer = RTCVideoRenderer();
            await _screenShareAudioRenderer!.initialize();

            _screenShareAudioRenderer!.srcObject = consumer.stream;

            _eventEmitter.emit(
              "stream-enabled-${localParticipant.id}",
              {
                "share": consumer,
                "audioRenderer": _screenShareAudioRenderer as RTCVideoRenderer,
              },
            );
            _screenShareAudioProducer = producer;
            break;
          }
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _addProducer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  void _removeProducer(Producer producer, _ProducerType type) {
    try {
      String? producerId = producer.id;
      switch (type) {
        case _ProducerType.micProducer:
          producer.close();

          _eventEmitter.emit(
            "stream-disabled-${localParticipant.id}",
            {
              "audioConsumerId": producerId,
            },
          );

          break;
        case _ProducerType.cameraProducer:
          //
          producer.close();
          _cameraRenderer?.dispose();

          //
          _eventEmitter.emit(
            "stream-disabled-${localParticipant.id}",
            {
              "renderer": _cameraRenderer,
              "videoConsumerId": producerId,
            },
          );
          break;
        case _ProducerType.screenshareProducer:

          //
          producer.close();
          _screenshareRenderer?.dispose();
          //
          _eventEmitter.emit(
            "stream-disabled-${localParticipant.id}",
            {
              "shareRenderer": _screenshareRenderer,
              "shareConsumerId": producerId,
            },
          );
          break;
        case _ProducerType.screenShareAudioProducer:

          //
          producer.close();
          _screenShareAudioRenderer?.dispose();

          _eventEmitter.emit(
            "stream-disabled-${localParticipant.id}",
            {
              "audioRenderer": _screenShareAudioRenderer,
              "shareConsumerId": producerId,
            },
          );
          break;
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _removeProducer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  // Peer
  //
  void _addPeer(Map<String, dynamic> newPeer, Span? span) {
    try {
      final Peer peer = Peer.fromMap(newPeer);
      //
      _peers[peer.id] = peer;
      //
      _eventEmitter.emit("peers-bloc-participant-joined", peer);

      if (span != null) {
        videoSDKTelemetery!.traceAutoComplete(
            spanName: 'Emitted `PARTICIPANT_JOINED` Event', span: span);
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _addPeer() \n ${e.toString()}", logLevel: "ERROR");
    }
  }

  void _addCharacterPeer(Map<String, dynamic> newPeer, Span? span) {
    try {
      newPeer.addAll({"mode": Mode.CONFERENCE.name});
      final Peer peer = Peer.fromMap(newPeer);
      //
      _peers[peer.id] = peer;
      //
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _addCharacterPeer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  //
  void __removePeer(String peerId, Span? span) {
    try {
      final removedPeer = _peers.remove(peerId);

      if (removedPeer?.audio != null) {
        _eventEmitter.emit("stream-disabled-${peerId}",
            {"audioConsumerId": removedPeer?.audio?.id});
      }

      if (removedPeer?.video != null) {
        _eventEmitter.emit("stream-disabled-${peerId}", {
          "videoConsumerId": removedPeer?.video?.id,
          "renderer": removedPeer?.renderer
        });
      }

      if (removedPeer?.share != null) {
        _eventEmitter.emit("stream-disabled-${peerId}", {
          "shareConsumerId": removedPeer?.share?.id,
          "shareRenderer": removedPeer?.shareRenderer
        });
      }

      //presenter left
      if (peerId == _activePresenterId) {
        _eventEmitter.emit("peers-bloc-presenter-changed", null);
      }

      _eventEmitter.emit("peers-bloc-participant-left", peerId);

      if (span != null) {
        videoSDKTelemetery!.traceAutoComplete(
            spanName: 'Emitted `PARTICIPANT_LEFT` Event', span: span);
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in __removePeer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  //
  Future<void> _addPeerConsumer(String peerId, Consumer consumer) async {
    try {
      log("_addPeerConsumer ${consumer.kind} $peerId ${consumer.appData['share']}");
      if (consumer.kind == 'video' && consumer.appData['share'] == true) {
        //
        _peers[peerId] = _peers[peerId]!.copyWith(
          shareRenderer: RTCVideoRenderer(),
          share: consumer,
        );

        //
        await _peers[peerId]!.shareRenderer!.initialize();

        //
        _peers[peerId]!.shareRenderer!.setSrcObject(
            stream: _peers[peerId]!.share!.stream,
            trackId: _peers[peerId]!.share!.track.id);

        //
        _eventEmitter.emit("stream-enabled-$peerId", {
          "shareRenderer": _peers[peerId]!.shareRenderer,
          "share": _peers[peerId]!.share
        });

        //
        _eventEmitter.emit("peers-bloc-presenter-changed", peerId);

        consumer.on('transportclose', () {
          try {
            _peers[peerId]?.shareRenderer?.dispose();
          } catch (error) {
            //
            VideoSDKLog.createLog(
                message:
                    "error in consumer transportclose share \n ${error.toString()}",
                logLevel: "ERROR");
          }
        });
      } else if (consumer.kind == 'video') {
        //
        _peers[peerId] = _peers[peerId]!.copyWith(
          renderer: RTCVideoRenderer(),
          video: consumer,
        );

        //
        await _peers[peerId]!.renderer!.initialize();

        //
        _peers[peerId]!.renderer!.setSrcObject(
            stream: _peers[peerId]!.video!.stream,
            trackId: _peers[peerId]!.video!.track.id);

        //
        _eventEmitter.emit("stream-enabled-$peerId", {
          "renderer": _peers[peerId]!.renderer,
          "video": _peers[peerId]!.video
        });
        //
        consumer.on('transportclose', () {
          try {
            _peers[peerId]?.renderer?.dispose();
          } catch (error) {
            //
            VideoSDKLog.createLog(
                message:
                    "error in consumer transportclose video \n ${error.toString()}",
                logLevel: "ERROR");
          }
        });
      } else if (consumer.kind == 'audio' &&
          consumer.appData['share'] == true) {
        _peers[peerId] = _peers[peerId]!.copyWith(
          audio: consumer,
          audioRenderer: RTCVideoRenderer(),
        );

        //
        await _peers[peerId]!.audioRenderer!.initialize();

        //
        _peers[peerId]!.audioRenderer!.srcObject =
            _peers[peerId]!.audio!.stream;

        //
        _eventEmitter.emit("stream-enabled-$peerId", {
          "audioRenderer": _peers[peerId]!.audioRenderer,
          "shareAudio": _peers[peerId]!.audio
        });

        if (_selectedAudioOutput != null) {
          _peers[peerId]!
              .audioRenderer!
              .audioOutput(_selectedAudioOutput!.deviceId);
        }

        consumer.on('transportclose', () {
          try {
            _peers[peerId]?.audioRenderer?.dispose();
          } catch (error) {
            //
            VideoSDKLog.createLog(
                message:
                    "error in consumer transportclose shareAudio \n ${error.toString()}",
                logLevel: "ERROR");
          }
        });
      } else if (consumer.kind == 'audio') {
        if (kIsWeb) {
          _peers[peerId] = _peers[peerId]!.copyWith(
            audio: consumer,
            audioRenderer: RTCVideoRenderer(),
          );

          AudioHTMLInterface().startAudio(_peers[peerId]!.audio);

          //
          _eventEmitter.emit("stream-enabled-$peerId", {
            "audioRenderer": _peers[peerId]!.audioRenderer,
            "audio": _peers[peerId]!.audio
          });

          if (_selectedAudioOutput != null) {
            AudioHTMLInterface()
                .setAudioOutputDevice(_selectedAudioOutput!.deviceId);
          }

          consumer.on('transportclose', () {
            try {
              _peers[peerId]?.audioRenderer?.dispose();
            } catch (error) {
              //
              VideoSDKLog.createLog(
                  message:
                      "error in consumer transportclose audio \n ${error.toString()}",
                  logLevel: "ERROR");
            }
          });
        } else {
          _peers[peerId] = _peers[peerId]!.copyWith(
            audio: consumer,
          );

          if (!kIsWeb) {
            if (Platform.isIOS) {
              if (_selectedAudioOutput != null) {
                switchAudioDevice(_selectedAudioOutput!);
              }
            }
          }

          _eventEmitter.emit("stream-enabled-$peerId", {
            "audio": consumer,
          });
        }
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _addPeerConsumer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  //
  Future<void> _removePeerConsumer(String consumerId) async {
    try {
      final Peer? peer = _peers.values.firstWhereOrNull(
        (p) => p.consumers.contains(
          consumerId,
        ),
      );

      //
      if (peer != null) {
        if (peer.audio?.id == consumerId) {
          final consumer = peer.audio;
          if (kIsWeb) {
            AudioHTMLInterface().stopAudio(peer.audio!.track.id!);
          }

          _peers[peer.id] = _peers[peer.id]!.removeAudio();

          await consumer?.close();

          _eventEmitter.emit(
            "stream-disabled-${peer.id}",
            {
              "audioConsumerId": consumer?.id,
            },
          );
        } else if (peer.video?.id == consumerId) {
          final consumer = peer.video;
          final renderer = peer.renderer;
          _peers[peer.id] = _peers[peer.id]!.removeVideoAndRenderer();

          await consumer?.close();

          await renderer?.dispose();

          _eventEmitter.emit(
            "stream-disabled-${peer.id}",
            {
              "renderer": renderer,
              "videoConsumerId": consumer?.id,
            },
          );
        } else if (peer.share?.id == consumerId) {
          final consumer = peer.share;
          final renderer = peer.shareRenderer;

          _peers[peer.id] = _peers[peer.id]!.removeShareAndRenderer();

          await consumer?.close();

          await renderer?.dispose();

          _eventEmitter.emit(
            "stream-disabled-${peer.id}",
            {
              "shareRenderer": renderer,
              "shareConsumerId": consumer?.id,
            },
          );

          _eventEmitter.emit("peers-bloc-presenter-changed");
        }
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _removePeerConsumer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  //
  // ignore: unused_element
  Future<void> _pausePeerConsumer(String consumerId) async {
    try {
      final Peer? peer = _peers.values.firstWhereOrNull(
        (p) => p.consumers.contains(
          consumerId,
        ),
      );

      //
      if (peer != null) {
        //
        if (peer.audio?.id == consumerId) {
          //
          Peer newPeer = _peers[peer.id]!.copyWith(
            audio: peer.audio!.pauseCopy(),
          );

          //
          _peers[peer.id] = newPeer;

          //
          _eventEmitter.emit("stream-paused-${peer.id}", {
            "audioConsumerId": consumerId,
            "consumer": newPeer.audio,
          });
        } else if (peer.video?.id == consumerId) {
          //
          Peer newPeer = _peers[peer.id]!.copyWith(
            video: peer.video!.pauseCopy(),
          );

          //
          _peers[peer.id] = newPeer;

          //
          _eventEmitter.emit("stream-paused-${peer.id}", {
            "videoConsumerId": consumerId,
            "consumer": newPeer.video,
          });
        } else if (peer.share?.id == consumerId) {
          //
          Peer newPeer = _peers[peer.id]!.copyWith(
            share: peer.share!.pauseCopy(),
          );

          //
          _peers[peer.id] = newPeer;

          //
          _eventEmitter.emit("stream-paused-${peer.id}", {
            "shareConsumerId": consumerId,
            "consumer": newPeer.share,
          });
        }
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _pausePeerConsumer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  //
  // ignore: unused_element
  Future<void> _resumePeerConsumer(String consumerId) async {
    try {
      final Peer? peer = _peers.values.firstWhereOrNull(
        (p) => p.consumers.contains(
          consumerId,
        ),
      );

      if (peer != null) {
        if (peer.audio?.id == consumerId) {
          Peer newPeer = _peers[peer.id]!.copyWith(
            audio: peer.audio!.resumeCopy(),
          );

          _peers[peer.id] = newPeer;

          _eventEmitter.emit("stream-resumed-${peer.id}", {
            "audioConsumerId": consumerId,
            "consumer": newPeer.audio,
          });
        } else if (peer.video?.id == consumerId) {
          Peer newPeer = _peers[peer.id]!.copyWith(
            video: peer.video!.resumeCopy(),
          );

          _peers[peer.id] = newPeer;

          _eventEmitter.emit("stream-resumed-${peer.id}", {
            "videoConsumerId": consumerId,
            "consumer": newPeer.video,
          });
        } else if (peer.share?.id == consumerId) {
          Peer newPeer = _peers[peer.id]!.copyWith(
            share: peer.share!.resumeCopy(),
          );

          _peers[peer.id] = newPeer;

          _eventEmitter.emit("stream-resumed-${peer.id}", {
            "shareConsumerId": consumerId,
            "consumer": newPeer.share,
          });
        }
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _resumePeerConsumer() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  //
  void _changePeerConsumerQuality(
    String consumerId, {
    required int spatialLayer,
    required int temporalLayer,
  }) {
    try {
      final Peer? peer = _peers.values.firstWhereOrNull(
        (p) => p.consumers.contains(
          consumerId,
        ),
      );

      //
      if (peer != null) {
        //
        if (peer.video?.id == consumerId) {
          //
          Peer newPeer = _peers[peer.id]!.copyWith(
              video: peer.video!.copyWith(
            spatialLayer: spatialLayer,
            temporalLayer: temporalLayer,
          ));

          //
          _peers[peer.id] = newPeer;

          String prevQuality = "";
          String currentQuality = "HIGH";

          int totalSpatialLayers = peer.video!.appData['encodings'].length;
          if (totalSpatialLayers > 1) {
            prevQuality = totalSpatialLayers - 1 - peer.video!.spatialLayer == 0
                ? "HIGH"
                : totalSpatialLayers - 1 - peer.video!.spatialLayer == 1
                    ? "MEDIUM"
                    : "LOW";
            currentQuality = totalSpatialLayers - 1 - spatialLayer == 0
                ? "HIGH"
                : totalSpatialLayers - 1 - spatialLayer == 1
                    ? "MEDIUM"
                    : "LOW";
          } else {
            prevQuality = "HIGH";
            currentQuality = "HIGH";
          }

          try {
            VideoSDKLog.createLog(
                message: "Protoo Noti: consumerLayersChanged for $consumerId",
                logLevel: "INFO",
                attributes: {
                  'prevQuality': prevQuality,
                  'currentQuality': currentQuality
                });
          } catch (error) {}

          //
          _eventEmitter.emit("quality-changed-${peer.id}", {
            "spatialLayer": spatialLayer,
            "temporalLayer": temporalLayer,
            "prevQuality": prevQuality,
            "currentQuality": currentQuality
          });
        }
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _changePeerConsumerQuality() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  List<dynamic> _getStats(String id, String type) {
    try {
      if (type == "producer") {
        return _latestStats[id] ?? [];
      } else if (type == "consumer") {
        Consumer? consumer = _recvTransport?.consumers[id];

        if (consumer != null) {
          List<dynamic> stats = _latestStats[id] ?? [];
          if (consumer.track.kind == "video" && stats.length > 0) {
            stats[0]['spatialLayer'] = consumer.spatialLayer;
            stats[0]['temporalLayer'] = consumer.temporalLayer;
          }
          return stats;
        } else {
          return [];
        }
      }
      return [];
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _getStats() \n ${e.toString()}",
          logLevel: "ERROR");
      return [];
    }
  }

  //
  void _producerCallback(Producer producer) {
    try {
      if (producer.source == 'mic') {
        producer.on('transportclose', () {
          _removeProducer(_micProducer!, _ProducerType.micProducer);
        });

        producer.on('trackended', () {
          _disableMic(trackEnded: true).catchError((data) {
            //
            VideoSDKLog.createLog(
                message:
                    "Error in micProducer trackended \n ${data.toString()}",
                logLevel: "ERROR");
          });
        });
        _micInProgress = false;
      } else if (producer.source == 'webcam') {
        producer.on('transportclose', () {
          _removeProducer(_cameraProducer!, _ProducerType.cameraProducer);
        });

        producer.on('trackended', () {
          _disableCamImpl().catchError((data) {
            //
            VideoSDKLog.createLog(
                message:
                    "Error in camProducer trackended \n ${data.toString()}",
                logLevel: "ERROR");
          });
        });
        _cameraInProgress = false;
      } else if (producer.source == 'share') {
        producer.on('transportclose', () {
          _closeForegroundService();
          _removeProducer(
              _screenshareProducer!, _ProducerType.screenshareProducer);
        });

        producer.on('trackended', () {
          _closeForegroundService();
          disableScreenShare().catchError((data) {
            //
            VideoSDKLog.createLog(
                message:
                    "error in shareProducer trackended \n ${data.toString()}",
                logLevel: "ERROR");
          });
        });
        _screenShareInProgress = false;
      }
      _addProducer(producer);
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _producerCallback() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  void _consumerCallback(Consumer consumer, [dynamic accept]) {
    accept({});

    _addPeerConsumer(consumer.peerId, consumer);
  }

  //Not using anymore.
  Future<MediaStream> _createAudioStream() async {
    //
    Map<String, dynamic> mediaConstraints = {
      'audio': {
        'optional': [
          {
            'sourceId': _selectedAudioInput?.deviceId,
          },
        ],
      },
    };

    //
    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    //
    return stream;
  }

  //Not using anymore.
  Future<MediaStream> _createVideoStream() async {
    //
    Map<String, dynamic> mediaConstraints = <String, dynamic>{
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth':
              '1280', // Provide your own width, height and frame rate here
          'minHeight': '720',
          'minFrameRate': '30',
        },
        'optional': [
          {
            'sourceId': _selectedVideoInput?.deviceId,
          },
        ],
      },
    };
    //
    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    //
    return stream;
  }

  Future<MediaStream?> _createShareStream(Span? span) async {
    Span? _internalSpan;
    try {
      if (span != null) {
        try {
          _internalSpan = videoSDKTelemetery!.trace(
            spanName: 'Creating Stream',
            span: span,
          );
        } catch (error) {}
      }
      //
      var mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': _selectedScreenSource == null
            ? true
            : {
                'deviceId': {'exact': _selectedScreenSource!.id},
              }
      };

      if (!kIsWeb) {
        if (Platform.isIOS) {
          mediaConstraints['video'] = {'deviceId': 'broadcast'};
          mediaConstraints = {
            'video': {'deviceId': 'broadcast'}
          };
        }
      }
      //
      MediaStream? stream;

      final isWebMobile = kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);

      if (isWebMobile) {
        _eventEmitter.emit("error", VideoSDKErrors[3015]);
        Map<String, String> attributes = {
          "error": "Error in enableScreenShare(): Device not compatible."
        };
        VideoSDKLog.createLog(
            message: VideoSDKErrors[3015]!['message']!,
            logLevel: "ERROR",
            attributes: attributes,
            dashboardLog: true);
        print(
            "An error occurred in enableScreenShare(): VIDEOSDK ERROR :: ${VideoSDKErrors[3015]?['code']}  :: ${VideoSDKErrors[3015]?['name']} :: ${VideoSDKErrors[3015]?['message']}");

        try {
          if (_internalSpan != null) {
            videoSDKTelemetery!.completeSpan(
                span: _internalSpan,
                message: 'Stream Creation Failed due to platform not support',
                status: StatusCode.error);
          }
        } catch (e) {}
        return null;
      } else {
        stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
        stream.getVideoTracks().first.onEnded = () => disableScreenShare();
      }
      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              message: 'Stream Creation Completed',
              status: StatusCode.ok);
        }
      } catch (e) {}

      //
      return stream;
    } catch (e) {
      VideoSDKLog.createLog(
          message: "Error in _createShareStream() \n ${e.toString()}",
          logLevel: "ERROR");

      try {
        if (_internalSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: _internalSpan,
              message: 'Stream Creation Failed due to error : ${e.toString()}',
              status: StatusCode.error);
        }
      } catch (e) {}
      return null;
    }
  }

  // PubSub
  Future<void> _pubsubPublish({topic, message, options, payload}) async {
    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('pubsubPublish', {
          'topic': topic,
          'message': message,
          'options': options,
          'payload': payload
        });
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in pubSub.publish(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in pubsubPublish() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("pubsubPublish() | failed: $error");
    }
  }

  Future<dynamic> _pubsubSubscribe(topic) async {
    try {
      if (_webSocket != null) {
        var msgList = await _webSocket!.socket
            .request('pubsubSubscribe', {'topic': topic});
        return msgList;
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in pubSub.subscribe(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return null;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in pubsubSubscribe() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("pubsubSubscribe() | failed: $error");
    }
  }

  Future<void> _pubsubUnsubscribe(topic) async {
    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('pubsubUnsubscribe', {'topic': topic});
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in pubSub.unsubscribe(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in pubsubUnsubscribe() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("pubsubUnsubscribe() | failed: $error");
    }
  }

  void _handlePubSubMessage(data) {
    _topicEventEmitter.emit(
      data['topic'],
      PubSubMessage.fromJson(data),
    );
  }

  Future<void> setConsumerQuality(consumerId, String quality) async {
    late int? spatialLayers;
    late int? temporalLayers;

    try {
      if (videoSDKTelemetery != null) {
        videoSDKTelemetery!.traceAutoComplete(
          spanName: 'Setting "$quality" Quality for consumerId $consumerId',
        );
      }

      if (quality == 'low' || quality == 'med' || quality == 'high') {
        final layers = VIDEO_LAYERS[_maxResolution]![quality];
        spatialLayers = layers?['s'];
        temporalLayers = layers?['t'];
      } else {
        String sCh = quality[0];
        String tCh = quality[2];
        int s = int.parse(quality[1]);
        int t = int.parse(quality[3]);

        if (s > 2 || t > 2 || sCh != "s" || tCh != "t") {
          throw ("");
        }

        spatialLayers = s;
        temporalLayers = t;
      }

      _setConsumerPreferredLayers(consumerId, spatialLayers, temporalLayers);
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in setConsumerQuality() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("invalid quality");
    }
  }

  Future<void> _setConsumerPreferredLayers(
    consumerId,
    spatialLayer,
    temporalLayer,
  ) async {
    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('setConsumerPreferredLayers', {
          "consumerId": consumerId,
          "spatialLayer": spatialLayer,
          "temporalLayer": temporalLayer,
        });
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in setConsumerQuality(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message:
              "error in setConsumerPreferredLayers() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Error while setting consumer preferred layers $error");
    }
  }

  void setViewPort(consumerId, viewportWidth, viewportHeight) {
    try {
      Consumer? consumer = _recvTransport?.getConsumer(consumerId);
      if (consumer == null) {
        return;
      }
      Map<String, dynamic>? layers = SdkCapabilities.getAdaptivePreferredLayers(
        consumer,
        viewportWidth,
        viewportHeight,
      );
      if (layers != null) {
        _setConsumerPreferredLayers(
          consumerId,
          layers['newPreferredSpatialLayer'],
          layers['newPreferredTemporalLayer'],
        );
      }
    } catch (e) {
      VideoSDKLog.createLog(
          message: "error in setViewPort() \n ${e.toString()}",
          logLevel: "ERROR");
    }
  }

  on(Events event, Function handler) {
    _eventEmitter.on(event.parseToString(), handler);
  }

  off(Events event, Function handler) {
    _eventEmitter.remove(event.parseToString(), handler);
  }

  Character createCharacter({required CharacterConfig characterConfig}) {
    var character = Character(
        characterConfig: characterConfig,
        eventEmitter: _eventEmitter,
        enablePeerMic: _enablePeerMic,
        disablePeerMic: _disablePeerMic,
        enablePeerCamera: _enablePeerCamera,
        disablePeerCamera: _disablePeerCamera,
        joinCharacter: _joinCharacter,
        removeCharacter: _removeCharacter,
        sendMessage: _sendCharacterMessage,
        interruptCharacter: _interruptCharacter);

    return character;
  }

  dynamic _joinCharacter({CharacterConfig? characterConfig}) async {
    Span? joinCharacterSpan;
    Map<String, dynamic> data = {};
    if (characterConfig != null) data["config"] = characterConfig.toJson();

    try {
      if (videoSDKTelemetery != null) {
        joinCharacterSpan = videoSDKTelemetery!.trace(
          spanName: 'joinCharacter() Started',
          attributes: [
            Attribute.fromString(
                'config',
                characterConfig != null
                    ? jsonEncode(characterConfig.toJson())
                    : "Config not specified"),
          ],
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        var response = await _webSocket!.socket.request("joinCharacter", data);

        if (joinCharacterSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: joinCharacterSpan,
              status: StatusCode.ok,
              message: 'joinCharacter() End');
        }
        return response;
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in Character.join(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in joinCharacter() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Character join request failed due to an error : $error");

      if (joinCharacterSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: joinCharacterSpan,
            status: StatusCode.error,
            message: 'joinCharacter() Failed \n ${error.toString()}');
      }
      return false;
    }
  }

  void _removeCharacter(config) async {
    Span? removeCharacterSpan;
    Map<String, dynamic> data = {};
    if (config != null) data["config"] = config;

    try {
      if (videoSDKTelemetery != null) {
        removeCharacterSpan = videoSDKTelemetery!.trace(
          spanName: 'removeCharacter() Started',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request("leaveCharacter", data);

        if (removeCharacterSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: removeCharacterSpan,
              status: StatusCode.ok,
              message: 'removeCharacter() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in Character.leave(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in removeCharacter() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Character leave request failed due to an error : $error");

      if (removeCharacterSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: removeCharacterSpan,
            status: StatusCode.error,
            message: 'removeCharacter() Failed \n ${error.toString()}');
      }
    }
  }

  void _sendCharacterMessage(interactionId, text) async {
    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request("sendCharacterMessage",
            {"interactionId": interactionId, "text": text});
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in Character.sendMessage(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in sendCharacterMessage() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Character send message request failed due to an error : $error");
    }
  }

  void _interruptCharacter(interactionId) async {
    try {
      if (_webSocket != null) {
        await _webSocket!.socket
            .request("interruptCharacter", {"interactionId": interactionId});
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in Character.interrupt(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in interruptCharacter() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Character interrupt request failed due to an error : $error");
    }
  }

  void startWhiteboard() async {
    Span? startWBSpan;

    try {
      if (videoSDKTelemetery != null) {
        startWBSpan = videoSDKTelemetery!.trace(
          spanName: 'startWhiteboard() called',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request("startWhiteboard", {
          "version": "v2",
        });

        if (startWBSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: startWBSpan,
              status: StatusCode.ok,
              message: 'startWhiteboard() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in startWhiteboard(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in startWhiteboard() \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("Whiteboard start request failed due to an error : $error");

      if (startWBSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: startWBSpan,
            status: StatusCode.error,
            message: 'startWhiteboard() Failed \n ${error.toString()}');
      }
    }
  }

  void stopWhiteboard() async {
    Span? stopWBSpan;
    try {
      if (videoSDKTelemetery != null) {
        stopWBSpan = videoSDKTelemetery!.trace(
          spanName: 'stopWhiteboard() Called',
        );
      }
    } catch (error) {}

    try {
      if (_webSocket != null) {
        await _webSocket!.socket.request('stopWhiteboard', {});

        if (stopWBSpan != null) {
          videoSDKTelemetery!.completeSpan(
              span: stopWBSpan,
              status: StatusCode.ok,
              message: 'stopWhiteboard() End');
        }
      } else {
        _eventEmitter.emit("error", VideoSDKErrors[3022]);
        print(
            "An error occurred in stopWhiteboard(): the method was called while the meeting was in the connecting state. Please try again after joining the meeting.");
        return;
      }
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message: "Error in stopWhiteboard() \n ${error.toString()}",
          logLevel: "ERROR");

      //
      log("Error while stopping whiteboard $error");

      if (stopWBSpan != null) {
        videoSDKTelemetery!.completeSpan(
            span: stopWBSpan,
            status: StatusCode.error,
            message: 'stopWhiteboard() Failed \n ${error.toString()}');
      }
    }
  }
}

enum _ProducerType {
  micProducer,
  cameraProducer,
  screenshareProducer,
  screenShareAudioProducer
}
