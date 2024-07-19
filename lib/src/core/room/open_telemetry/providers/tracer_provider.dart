import 'package:videosdk_otel/api.dart';
import 'package:videosdk_otel/sdk.dart';
import 'package:videosdk/src/core/room/open_telemetry/tracer_provider_interface.dart';

class TracerProvider implements TracerProviderInterface {
  @override
  TracerProviderBase get provider => _provider;

  late TracerProviderBase _provider;
  TracerProvider(BatchSpanProcessor processor) {
    _provider = TracerProviderBase(
      processors: [processor],
      resource: Resource(
        [
          Attribute.fromString("service.name", "videosdk-otel"),
          Attribute.fromString("service.version", "0.0.1")
        ],
      ),
    );
  }
}

TracerProviderInterface getTracerProvider(BatchSpanProcessor processor) =>
    TracerProvider(processor);
