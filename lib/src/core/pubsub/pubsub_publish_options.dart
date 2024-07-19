class PubSubPublishOptions {
  final bool persist;
  final List<String> sendOnly;

  const PubSubPublishOptions({this.persist = false, this.sendOnly = const []});

  Map<String, dynamic> toJson() => {"persist": persist, "sendOnly": sendOnly};
}
