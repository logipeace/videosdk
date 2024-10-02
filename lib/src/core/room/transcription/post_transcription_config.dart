import 'package:videosdk/src/core/room/transcription/summary_config.dart';

class PostTranscriptionConfig {
    late final bool _enabled;
    late final SummaryConfig? _summary;
    late final String? _modelId;

    PostTranscriptionConfig({required bool enabled, SummaryConfig? summaryConfig, String? modelId}){
      _enabled = enabled;
      _summary = summaryConfig;
      _modelId = modelId;

    }

    Map<String, dynamic> toJson() {
    return {
      'enabled': _enabled,
      'summary': _summary?.toJson(),
      'modelId': _modelId
    };
  }
}