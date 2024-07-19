import 'package:flutter/foundation.dart';
import 'package:videosdk_otel/api.dart';
import 'package:videosdk_otel/sdk.dart';
import 'package:videosdk_otel/web_sdk.dart';
import 'package:videosdk/src/core/room/open_telemetry/tracer_provider_interface.dart';

class TracerProviderWeb implements TracerProviderInterface {
  @override
  WebTracerProvider get provider => _provider;

  late WebTracerProvider _provider;

  TracerProviderWeb(BatchSpanProcessor processor) {
    if (kIsWeb) {
      _provider = WebTracerProvider(
        processors: [processor],
        timeProvider: WebTimeProvider(),
        resource: Resource(
          [
            Attribute.fromString("service.name", "videosdk-otel"),
            Attribute.fromString("service.version", "0.0.1")
          ],
        ),
      );
    }
  }
}

TracerProviderInterface getTracerProvider(BatchSpanProcessor processor) =>
    TracerProviderWeb(processor);
