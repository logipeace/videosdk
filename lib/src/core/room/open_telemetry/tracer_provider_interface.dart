import 'package:videosdk_otel/sdk.dart';
import 'package:videosdk/src/core/room/open_telemetry/tracer_provider_stub.dart'
    if (dart.library.io) 'package:videosdk/src/core/room/open_telemetry/providers/tracer_provider.dart'
    if (dart.library.html) 'package:videosdk/src/core/room/open_telemetry/providers/tracer_provider_web.dart';

abstract class TracerProviderInterface {
  factory TracerProviderInterface(BatchSpanProcessor processor) => getTracerProvider(processor);

  TracerProviderBase get provider; 
}