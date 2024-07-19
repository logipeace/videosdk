import 'dart:developer';

import 'package:events2/events2.dart';
import 'package:synchronized/synchronized.dart';
import 'package:videosdk/src/core/room/open_telemetry/videosdk_log.dart';

import 'pubsub_message.dart';
import 'pubsub_publish_options.dart';

class PubSub {
  //
  late Function _pubsubPublish;

  //
  late Function _pubsubSubscribe;

  //
  late Function _pubsubUnsubscribe;

  //
  late EventEmitter? _topicEventEmitter;

  //
  late final Lock _lock;

  PubSub({
    required Function pubsubPublish,
    required Function pubsubSubscribe,
    required Function pubsubUnsubscribe,
    required topicEventEmitter,
  }) {
    _topicEventEmitter = topicEventEmitter;
    _pubsubPublish = pubsubPublish;
    _pubsubSubscribe = pubsubSubscribe;
    _pubsubUnsubscribe = pubsubUnsubscribe;

    _lock = Lock();
  }

  Future<void> publish(String topic, String message,
      [PubSubPublishOptions? options,
      Map<String, dynamic> payload = const {}]) async {
        options ??= const PubSubPublishOptions();
    await _pubsubPublish(
      topic: topic,
      message: message,
      options: options.toJson(),
      payload: payload,
    );
  }

  Future<PubSubMessages> subscribe(
          String topic, Function(PubSubMessage) onMessageReceived) =>
      _lock.synchronized(() async {
        final msgs = (await _pubsubSubscribe(topic)) ??
            <String, dynamic>{"messages": []};

        var messages = PubSubMessages.fromJson(msgs);

        if (!_topicEventEmitter!.listeners(topic).contains(onMessageReceived)) {
          _topicEventEmitter!.on(topic, onMessageReceived);
        }

        return messages;
      });

  Future<void> unsubscribe(
      String topic, Function(PubSubMessage) onMessageReceived) async {
    try {
      _topicEventEmitter!.remove(topic, onMessageReceived);
    } catch (e) {
      //
      VideoSDKLog.createLog(
          message: "Error in pubSub unsubscribe \n ${e.toString()}",
          logLevel: "ERROR");
      //
      log("unsubscribe() | error: $e");
    }

    if (_topicEventEmitter!.listeners(topic).isEmpty) {
      await _pubsubUnsubscribe(topic);
    }
  }
}
