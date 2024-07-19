import 'dart:developer';
import 'package:videosdk_otel/api.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:videosdk_otel/sdk.dart' as otel_sdk;
import 'package:videosdk/src/core/room/open_telemetry/tracer_provider_interface.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';

class VideoSDKTelemetery {
  late Span _rootSpan;
  late Tracer tracer;
  late otel_sdk.TracerProviderBase provider;
  static var _roomId;
  static var _peerId;

  VideoSDKTelemetery(
      {required roomId,
      required peerId,
      required observabilityJwt,
      required traces,
      required metaData}) {
    try {
      //
      if (!traces['enabled']) {
        return;
      }

      _roomId = roomId;
      _peerId = peerId;

      final exporter = otel_sdk.CollectorExporter(
          Uri.parse(traces['pbEndPoint']),
          jwtKey: observabilityJwt);

      final processor = otel_sdk.BatchSpanProcessor(exporter);

      provider = TracerProviderInterface(processor).provider;

      tracer = provider.getTracer(peerId);

      _rootSpan = tracer
          .startSpan('room_${roomId}_peer_${peerId}_sdk_flutter', attributes: [
        Attribute.fromString("roomId", roomId),
        Attribute.fromString("peerId", peerId),
        Attribute.fromString("sdkName", "flutter"),
        Attribute.fromString("userId", metaData['userId']),
        Attribute.fromString("email", metaData['email'])
      ]);
      _rootSpan.end();
    } catch (error) {
      //
      VideoSDKLog.createLog(
          message:
              "error in VideoSDKTelemetery :: setExporter \n ${error.toString()}",
          logLevel: "ERROR");
      //
      log("error in setExporter $error");
    }
  }

  Span trace(
      {required String spanName, List<Attribute>? attributes, Span? span}) {
    Span parentSpan;
    if (span != null) {
      parentSpan = span;
    } else {
      parentSpan = getCurrentSpan();
    }

    Span? createdSpan;
    Context.current.withSpan(parentSpan).execute(() {
      createdSpan = tracer.startSpan(spanName);
      attributes ??= [];
      attributes!.add(Attribute.fromString("roomId", _roomId));
      attributes!.add(Attribute.fromString("peerId", _peerId));
      attributes!.add(Attribute.fromString("sdkName", "flutter"));
      createdSpan!.setAttributes(attributes!);
    });
    return createdSpan!;
  }

  Span getCurrentSpan() {
    Span? immmediateParentSpan = Context.current.span;
    immmediateParentSpan ??= _rootSpan;
    return immmediateParentSpan;
  }

  traceAutoComplete({
    required String spanName,
    List<Attribute>? attributes,
    Span? span,
    StatusCode status = StatusCode.ok,
    String message = "SUCCESS",
  }) {
    Span parentSpan;
    if (span != null) {
      parentSpan = span;
    } else {
      parentSpan = _rootSpan;
    }
    Context.current.withSpan(parentSpan).execute(() {
      Span createdSpan = tracer.startSpan(spanName);
      attributes ??= [];
      attributes!.add(Attribute.fromString("roomId", _roomId));
      attributes!.add(Attribute.fromString("peerId", _peerId));
      attributes!.add(Attribute.fromString("sdkName", "flutter"));
      createdSpan.setAttributes(attributes!);
      createdSpan.setStatus(status, description: message);
      createdSpan.end();
    });
  }

  completeSpan(
      {required Span span,
      required StatusCode status,
      required String message}) {
    span.setStatus(status, description: message);
    span.end();
  }

  flush() {
    provider.shutdown();
  }
}
