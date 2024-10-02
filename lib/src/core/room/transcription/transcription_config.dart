
import 'package:videosdk/src/core/room/transcription/summary_config.dart';

class TranscriptionConfig {
    late final String? _webhookUrl;
    late final SummaryConfig? _summary;

    TranscriptionConfig({String? webhookUrl, SummaryConfig? summaryConfig}){
      _webhookUrl = webhookUrl;
      _summary = summaryConfig;

    }

    Map<String, dynamic> toJson() {
    return {
      'webhookUrl': _webhookUrl,
      'summary': _summary?.toJson(),
    };
  }
}