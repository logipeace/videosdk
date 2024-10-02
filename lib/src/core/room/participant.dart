import 'package:events2/events2.dart';
import 'package:videosdk/src/core/room/room_mode.dart';

import 'events.dart';
import 'stream.dart';
import 'participant_pin_state.dart';

class Participant {
  late final EventEmitter _participantEventEmitter;
  late final EventEmitter _eventEmitter;
  int? _spatialLayer;
  int? _temporalLayer;

  String? _preferredQuality;

  late String id;
  late String displayName;
  late Map<String, Stream> streams;
  late bool isLocal;
  late Mode mode;
  late Function _enablePeerMic,
      _disablePeerMic,
      _enablePeerCamera,
      _disablePeerCamera,
      _setConsumerQuality,
      _setViewPort,
      _getStats,
      _removePeer,
      _participantPinStateChanged;
  late ParticipantPinState pinState;
  Map<String,dynamic>? metaData;

  Participant({
    required this.id,
    required this.displayName,
    required this.isLocal,
    required this.pinState,
    required this.mode,
    required EventEmitter eventEmitter,
    required Function enablePeerMic,
    required Function disablePeerMic,
    required Function enablePeerCamera,
    required Function disablePeerCamera,
    required Function setConsumerQuality,
    required Function getStats,
    required Function setViewPort,
    required Function removePeer,
    required Function participantPinStateChanged,
    this.metaData
  }) {
    //
    _eventEmitter = eventEmitter;
    //
    _enablePeerMic = enablePeerMic;
    //
    _disablePeerMic = disablePeerMic;
    //
    _enablePeerCamera = enablePeerCamera;
    //
    _disablePeerCamera = disablePeerCamera;
    //
    _setConsumerQuality = setConsumerQuality;
    //
    _setViewPort = setViewPort;
    //
    _removePeer = removePeer;
    //
    _getStats = getStats;
    _participantPinStateChanged = participantPinStateChanged;
    //
    _participantEventEmitter = EventEmitter();
    //
    streams = {};

    // handle stream-enabled
    _eventEmitter.on(
      "stream-enabled-$id",
      (data) {
        if (data['audio'] != null) {
          final consumer = data["audio"];

          final Stream newStream = Stream(
            consumer: consumer,
          );

          _addConsumer(newStream);
        } else if (data["renderer"] != null && data["video"] != null) {
          final consumer = data["video"];
          final renderer = data["renderer"];

          final Stream newStream = Stream(
            consumer: consumer,
            renderer: renderer,
          );

          _addConsumer(newStream);
        } else if (data["shareRenderer"] != null && data["share"] != null) {
          final consumer = data["share"];
          final shareRenderer = data["shareRenderer"];

          final Stream newStream = Stream(
            consumer: consumer,
            renderer: shareRenderer,
          );

          _addConsumer(newStream);
        }
      },
    );

    // handle stream-disabled
    _eventEmitter.on(
      "stream-disabled-$id",
      (data) {
        if (data['audioConsumerId'] != null) {
          final consumerId = data['audioConsumerId'];
          _removeConsumer(consumerId);
        } else if (data["renderer"] != null &&
            data["videoConsumerId"] != null) {
          final consumerId = data['videoConsumerId'];
          _removeConsumer(consumerId);
        } else if (data["shareRenderer"] != null &&
            data["shareConsumerId"] != null) {
          final consumerId = data['shareConsumerId'];
          _removeConsumer(consumerId);
        }
      },
    );

    // handle stream-paused
    _eventEmitter.on(
      "stream-paused-$id",
      (data) {
        String audioKeyType = 'audioConsumerId';
        String videoKeyType = 'videoConsumerId';
        String shareKeyType = 'shareConsumerId';

        if (data[audioKeyType] != null) {
          _pauseConsumer(audioKeyType, data);
        } else if (data[videoKeyType] != null) {
          _pauseConsumer(videoKeyType, data);
        } else if (data[shareKeyType] != null) {
          _pauseConsumer(shareKeyType, data);
        }
      },
    );

    // handle stream-resumed
    _eventEmitter.on(
      "stream-resumed-$id",
      (data) {
        String audioKeyType = 'audioConsumerId';
        String videoKeyType = 'videoConsumerId';
        String shareKeyType = 'shareConsumerId';

        if (data[audioKeyType] != null) {
          _resumeConsumer(audioKeyType, data);
        } else if (data[videoKeyType] != null) {
          _resumeConsumer(videoKeyType, data);
        } else if (data[shareKeyType] != null) {
          _resumeConsumer(shareKeyType, data);
        }
      },
    );

    // handle quality-changed
    _eventEmitter.on(
      "quality-changed-$id",
      (data) {
        _setLayers(data['spatialLayer'], data['temporalLayer'],
            data['prevQuality'], data['currentQuality']);
      },
    );

    _eventEmitter.on("pin-state-change-$id", (data) {
      _setPinState(data['state']);
    });

    _eventEmitter.on("participant-mode-changed-$id", (data) {
      mode = ModeExtension.parseToEnum(data['mode']);
    });
  }

  String? get quality => _preferredQuality;

  on(Events event, handler) {
    _participantEventEmitter.on(event.parseToString(), handler);
  }
  off(Events event, Function handler) {
    _participantEventEmitter.remove(event.parseToString(), handler);
  }

  _setLayers(int? spatialLayer, int? temporalLayer, String prevQuality,
      String currentQuality) {
    if (spatialLayer != null && temporalLayer != null) {
      _spatialLayer = spatialLayer;
      _temporalLayer = temporalLayer;
    }
    _participantEventEmitter.emit("video-quality-changed", <String, dynamic>{
      "prevQuality": prevQuality,
      "currentQuality": currentQuality,
    });
  }

  _pauseConsumer(String idKeyType, data) {
    final consumer = data['consumer'];

    Stream? stream = streams[data[idKeyType]];

    if (stream != null) {
      Stream newStream = stream.copyWith(track: consumer);

      streams[newStream.id] = newStream;

      _participantEventEmitter.emit(
        "stream-paused",
        newStream,
      );
    }
  }

  _resumeConsumer(String idKeyType, data) {
    final consumer = data['consumer'];

    Stream? stream = streams[data[idKeyType]];

    if (stream != null) {
      Stream newStream = stream.copyWith(track: consumer);

      streams[newStream.id] = newStream;

      _participantEventEmitter.emit(
        "stream-resumed",
        newStream,
      );
    }
  }

  _addConsumer(Stream stream) {
    streams[stream.id] = stream;

    if (stream.kind == 'video' &&
        !isLocal &&
        _spatialLayer != null &&
        _temporalLayer != null) {
      _setConsumerQuality(stream.id, "s${_spatialLayer}t$_temporalLayer");
    }

    _participantEventEmitter.emit(
      "stream-enabled",
      stream,
    );
    _eventEmitter.emit("stream-enabled-character-$id", stream);
  }

  _removeConsumer(String consumerId) {
    final Stream? streamToRemove = streams[consumerId];

    if (streamToRemove != null) {
      streams.remove(consumerId);

      _participantEventEmitter.emit(
        "stream-disabled",
        streamToRemove,
      );
      _eventEmitter.emit("stream-disabled-character-$id", streamToRemove);
    }
  }

  unmuteMic() => _enablePeerMic(id);

  muteMic() => _disablePeerMic(id);

  enableCam() => _enablePeerCamera(id);

  disableCam() => _disablePeerCamera(id);

  pin([PinType pinType = PinType.SHARE_AND_CAM]) => _setPin(pinType);
  unpin([PinType pinType = PinType.SHARE_AND_CAM]) => _setUnPin(pinType);

  _setPinState(data) {
    bool? cam = data['cam'];
    bool? share = data['share'];

    if (cam != null) {
      pinState.cam = cam;
    }
    if (share != null) {
      pinState.share = share;
    }
  }

  _setPin(PinType pinType) {
    switch (pinType) {
      case PinType.SHARE_AND_CAM:
        _setPinState({'share': true, 'cam': true});
        break;
      case PinType.CAM:
        _setPinState({'cam': true});

        break;
      case PinType.SHARE:
        _setPinState({'share': true});

        break;
      default:
        break;
    }
    _participantPinStateChanged(id, pinState);
  }

  _setUnPin(PinType pinType) {
    switch (pinType) {
      case PinType.SHARE_AND_CAM:
        _setPinState({'share': false, 'cam': false});
        break;
      case PinType.CAM:
        _setPinState({'cam': false});

        break;
      case PinType.SHARE:
        _setPinState({'share': false});

        break;
      default:
        break;
    }
    _participantPinStateChanged(id, pinState);
  }

  List<dynamic>? getVideoStats() {
    if (isLocal) {
      for (var entry in streams.entries) {
        if (entry.value.kind == "video") {
          return _getStats(entry.key, "producer");
        }
      }
    } else {
      for (var entry in streams.entries) {
        if (entry.value.kind == "video") {
          return _getStats(entry.key, "consumer");
        }
      }
    }
    return null;
  }

  List<dynamic>? getAudioStats() {
    if (isLocal) {
      for (var entry in streams.entries) {
        if (entry.value.kind == "audio") {
          return _getStats(entry.key, "producer");
        }
      }
    } else {
      for (var entry in streams.entries) {
        if (entry.value.kind == "audio") {
          return _getStats(entry.key, "consumer");
        }
      }
    }
    return null;
  }

  List<dynamic>? getShareStats() {
    if (isLocal) {
      for (var entry in streams.entries) {
        if (entry.value.kind == "share") {
          return _getStats(entry.key, "producer");
        }
      }
    } else {
      for (var entry in streams.entries) {
        if (entry.value.kind == "share") {
          return _getStats(entry.key, "consumer");
        }
      }
    }
    return null;
  }

  setQuality(quality) {
    _preferredQuality = quality;
    streams.forEach((key, stream) {
      if (stream.kind == 'video' && !isLocal) {
        _setConsumerQuality(stream.id, quality);
      }
    });
  }

  setViewPort(width, height) {
    streams.forEach((key, stream) {
      if (stream.kind == 'video' && !isLocal) {
        _setViewPort(stream.id, width, height);
      }
    });
  }

  remove() => _removePeer(id);
}
