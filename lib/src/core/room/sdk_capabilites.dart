import 'dart:developer';
import 'dart:math' as Math;

import 'package:videosdk/src/core/room/custom_track_configs.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';
import 'package:videosdk/src/core/webrtc/webrtc_client.dart';

class SdkCapabilities {
  static var videoRids = ['q', 'h', 'f'];

  static List<dynamic> getResolutionScalings(List<dynamic> encodings) {
    List<dynamic> resolutionScalings = [];

    if (encodings.length == 0) {
      return resolutionScalings;
    }

    if (encodings.length == 1) {
      const spatialLayers = 3;
      for (int i = 0; i < spatialLayers; i++) {
        resolutionScalings.add(Math.pow(2, (spatialLayers - i - 1)));
      }

      return resolutionScalings;
    }

    // Simulcast encodings
    bool scaleResolutionDownByDefined = false;

    encodings.forEach((encoding) {
      if (encoding['scaleResolutionDownBy'] != null) {
        // at least one scaleResolutionDownBy is defined
        scaleResolutionDownByDefined = true;
        // scaleResolutionDownBy must be >= 1.0
        resolutionScalings
            .add(Math.max(1, encoding['scaleResolutionDownBy'] as num));
      } else {
        // If encodings contains any encoding whose scaleResolutionDownBy
        // attribute is defined, set any undefined scaleResolutionDownBy
        // of the other encodings to 1.0.
        resolutionScalings.add(1.0);
      }
    });

    // If the scaleResolutionDownBy attribues of sendEncodings are
    // still undefined, initialize each encoding's scaleResolutionDownBy
    // to 2^(length of sendEncodings - encoding index - 1).
    if (!scaleResolutionDownByDefined) {
      for (var i = 0; i < encodings.length; i++) {
        resolutionScalings[i] = Math.pow(2, encodings.length - i - 1);
      }
    }

    return resolutionScalings;
  }

  static Map<String, dynamic>? getAdaptivePreferredLayers(
      Consumer consumer, viewportWidth, viewportHeight) {
    Map<String, dynamic> result = new Map();
    result.putIfAbsent('consumerId', () => consumer.id);
    try {
      int width = consumer.appData['width'];
      int height = consumer.appData['height'];
      List<dynamic> encodings = consumer.appData['encodings'];

      List<dynamic> resolutionScalings = getResolutionScalings(encodings);
      log(resolutionScalings.toString());
      const adaptiveScalingFactor = 0.75;

      int newPreferredSpatialLayer = 0;
      for (int i = 0; i < resolutionScalings.length; i++) {
        var levelWidth = adaptiveScalingFactor * width / resolutionScalings[i];
        var levelHeight =
            adaptiveScalingFactor * height / resolutionScalings[i];
        log("levelWidth = $levelWidth");
        log("levelHeight = $levelHeight");
        if (viewportWidth >= levelWidth && viewportHeight >= levelHeight) {
          newPreferredSpatialLayer = i;
        } else {
          break;
        }
      }

      var newPreferredTemporalLayer = consumer.temporalLayer;
      log(consumer.temporalLayer.toString());

      if (newPreferredSpatialLayer == 0 && newPreferredTemporalLayer > 0) {
        var lowestLevelWidth = width / resolutionScalings[0];
        var lowestLevelHeight = height / resolutionScalings[0];

        if (viewportWidth < lowestLevelWidth * 0.5 &&
            viewportHeight < lowestLevelHeight * 0.5) {
          newPreferredTemporalLayer -= 1;
        }
        if (newPreferredTemporalLayer > 0 &&
            viewportWidth < lowestLevelWidth * 0.25 &&
            viewportHeight < lowestLevelHeight * 0.25) {
          newPreferredTemporalLayer -= 1;
        }
      }

      result.addAll({
        'newPreferredSpatialLayer': newPreferredSpatialLayer,
        'newPreferredTemporalLayer': newPreferredTemporalLayer,
      });
    } catch (exception) {
      //
      VideoSDKLog.createLog(
          message:
              "error in SdkCapabilities :: getAdaptivePreferredLayers() \n ${exception.toString()}",
          logLevel: "ERROR");
      //
      log("Exception ${exception.toString()}");
      return null;
    }
    return result;
  }

  static List<RtpEncodingParameters> computeVideoEncodings(
      bool isScreenShare, int width, int height, Map<String, dynamic> options) {
    List<RtpEncodingParameters> encodings = [];
    encodings.add(determineAppropriateEncoding(isScreenShare, width, height));

    bool useSimulcast = options["simulcast"];
    if (!useSimulcast) {
      return encodings;
    }

    Map<String, dynamic> original = {
      "width": width,
      "height": height,
      "encoding": RtpEncodingParameters(
          maxBitrate: encodings.first.maxBitrate,
          maxFramerate: encodings.first.maxFramerate)
    };

    List<Map<String, dynamic>> presets =
        defaultSimulcastLayers(isScreenShare, original);

    Map<String, dynamic>? midPreset;
    Map<String, dynamic> lowPreset = presets.first;

    if (presets.length > 1) {
      midPreset = presets.elementAt(1);
    }

    int size = Math.max(width, height);
    if (size >= 960 && midPreset != null) {
      return encodingsFromPresets(
          width, height, [lowPreset, midPreset, original]);
    }

    if (size >= 480) {
      return encodingsFromPresets(width, height, [lowPreset, original]);
    }

    return encodingsFromPresets(width, height, [original]);
  }

  static List<Map<String, dynamic>> defaultSimulcastLayers(
      bool isScreenShare, Map<String, dynamic> original) {
    double aspectRatio = original["width"] > original["height"]
        ? original["width"] / original["height"]
        : original["height"] / original["width"];
    if ((aspectRatio - 16.0 / 9).abs() < (aspectRatio - 4.0 / 3).abs()) {
      Map<String, Map<String, dynamic>> preset169 = _getPresets169();
      return [
        preset169[CustomVideoTrackConfig.h180p_w320p.name]!,
        preset169[CustomVideoTrackConfig.h360p_w640p.name]!,
      ];
    }
    Map<String, Map<String, dynamic>> preset43 = _getPresets43();
    return [
      preset43[CustomVideoTrackConfig.h180p_w240p.name]!,
      preset43[CustomVideoTrackConfig.h360p_w480p.name]!,
    ];
  }

  static List<RtpEncodingParameters> encodingsFromPresets(
      int width, int height, List<Map<String, dynamic>> presets) {
    List<RtpEncodingParameters> encodings = [];

    for (int i = 0; i < presets.length; i++) {
      if (i >= videoRids.length) {
        continue;
      }
      Map<String, dynamic> preset = presets[i];

      int size = Math.max(width, height);
      String rid = videoRids[i];

      RtpEncodingParameters encoding = RtpEncodingParameters(
          rid: rid,
          scaleResolutionDownBy:
              size / Math.min(preset['width'], preset['height']),
          maxBitrate: (preset["encoding"] as RtpEncodingParameters).maxBitrate,
          maxFramerate:
              (preset["encoding"] as RtpEncodingParameters).maxFramerate);
      encodings.add(encoding);
    }

    return encodings;
  }

  static RtpEncodingParameters determineAppropriateEncoding(
      bool isScreenShare, int width, int height) {
    List<Map<String, dynamic>> presets =
        presetsForResolution(isScreenShare, width, height);
    RtpEncodingParameters encoding = presets[0]['encoding'];

    int size = Math.max(width, height);

    for (int i = 0; i < presets.length; i++) {
      Map<String, dynamic> preset = presets[i];
      encoding = preset['encoding'];
      if (preset['width'] >= size) {
        break;
      }
    }

    return encoding;
  }

  static List<Map<String, dynamic>> presetsForResolution(
      bool isScreenShare, int width, int height) {
    if (isScreenShare) {
      return _getScreenSharePreset().values.toList();
    }

    double aspectRatio = width > height ? width / height : height / width;
    if ((aspectRatio - 16.0 / 9).abs() < (aspectRatio - 4.0 / 3).abs()) {
      return _getPresets169().values.toList();
    }
    return _getPresets43().values.toList();
  }

  static Map<String, Map<String, dynamic>> _getScreenSharePreset() {
    Map<String, Map<String, dynamic>> presets = {};
    for (var config in customScreenShareTrackConfig.entries) {
      presets.putIfAbsent(config.key.name, () {
        return {
          "height": config.value["height"],
          "width": config.value["width"],
          "encoding": RtpEncodingParameters(
              maxBitrate: config.value['bitRate'],
              maxFramerate: config.value['frameRate'])
        };
      });
    }
    return presets;
  }

  static Map<String, Map<String, dynamic>> _getPresets169() {
    Map<String, Map<String, dynamic>> presets = {};
    for (var config in customVideotrackConfigMap.entries) {
      if (config.value["aspectRatio"] == "oneSixNine") {
        presets.putIfAbsent(config.key.name, () {
          return {
            "height": config.value["height"],
            "width": config.value["width"],
            "encoding": RtpEncodingParameters(
                maxBitrate: config.value['bitRate'],
                maxFramerate: config.value['frameRate'])
          };
        });
      }
    }

    return presets;
  }

  static Map<String, Map<String, dynamic>> _getPresets43() {
    Map<String, Map<String, dynamic>> presets = {};
    for (var config in customVideotrackConfigMap.entries) {
      if (config.value["aspectRatio"] == "fourThree") {
        presets.putIfAbsent(config.key.name, () {
          return {
            "height": config.value["height"],
            "width": config.value["width"],
            "encoding": RtpEncodingParameters(
                maxBitrate: config.value['bitRate'],
                maxFramerate: config.value['frameRate'])
          };
        });
      }
    }

    return presets;
  }
}
