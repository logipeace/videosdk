import 'package:collection/collection.dart';
import 'package:events2/events2.dart';
import 'package:videosdk/videosdk.dart';
import 'events.dart';

class Character extends Participant {
  late final EventEmitter _characterEventEmitter;
  late final EventEmitter _eventEmitter;

  CharacterConfig? _characterConfig;

  String? characterRole;
  CharacterMode? characterMode;
  List<dynamic>? knowledgeBases;
  String? interactionId;
  CharacterState? state;

  late Function _joinCharacter;
  late Function _removeCharacter;
  late Function _sendMessage;
  late Function _interruptCharacter;

  Character(
      {required CharacterConfig characterConfig,
      required EventEmitter eventEmitter,
      CharacterState? state,
      required Function enablePeerMic,
      required Function disablePeerMic,
      required Function enablePeerCamera,
      required Function disablePeerCamera,
      required Function joinCharacter,
      required Function removeCharacter,
      required Function sendMessage,
      required Function interruptCharacter})
      : super(
            id: characterConfig.toJson()['characterId'],
            displayName: characterConfig.toJson()['displayName'],
            isLocal: false,
            pinState: ParticipantPinState(),
            mode: Mode.SEND_AND_RECV,
            eventEmitter: eventEmitter,
            enablePeerMic: enablePeerMic,
            disablePeerMic: disablePeerMic,
            enablePeerCamera: disablePeerCamera,
            disablePeerCamera: disablePeerCamera,
            setConsumerQuality: () {},
            getStats: () {},
            setViewPort: () {},
            removePeer: () {},
            participantPinStateChanged: () {}) {
    //
    id = characterConfig.toJson()['characterId'];
    characterMode = CharacterMode.values.firstWhere((value) =>
        value.name.toLowerCase() == characterConfig.toJson()['characterMode']);
    interactionId = characterConfig.toJson()['interactionId'];
    metaData = characterConfig.toJson()['metaData'];
    _characterEventEmitter = EventEmitter();
    state = state ?? CharacterState.CHARACTER_LISTENING;

    _eventEmitter = eventEmitter;

    _joinCharacter = joinCharacter;
    _removeCharacter = removeCharacter;
    _sendMessage = sendMessage;
    _interruptCharacter = interruptCharacter;
    _characterConfig = characterConfig;

    _eventEmitter.on("CHARACTER-JOINED", (character) {
      _characterEventEmitter.emit("character-joined", character);
    });

    _eventEmitter.on("stream-enabled-character-$id",
        (stream) => {_characterEventEmitter.emit("stream-enabled", stream)});

    _eventEmitter.on("stream-disabled-character-$id",
        (stream) => {_characterEventEmitter.emit("stream-disabled", stream)});

    _eventEmitter.on("CHARACTER-LEFT", (character) {
      _characterEventEmitter.emit("character-left", character);
    });

    _eventEmitter.on("CHARACTER_MESSAGE", (message) {
      _characterEventEmitter.emit("character-message", message);
    });

    _eventEmitter.on("USER_MESSAGE", (message) {
      _characterEventEmitter.emit("user-message", message);
    });

    _eventEmitter.on("CHARACTER_STATE_CHANGED", (data) {
      if (CharacterState.values.any((value) => value.name == data['status'])) {
        this.state = CharacterState.values
            .firstWhere((value) => value.name == data['status']);
        _characterEventEmitter.emit("character-state-changed", this.state);
      }
    });
  }

  void join() async {
    var res = await _joinCharacter(characterConfig: _characterConfig);

    if (res != false) {
      id = res['characterId'];
      displayName = res['displayName'];
      characterMode = CharacterMode.values.firstWhere(
          (value) => value.name.toLowerCase() == res['characterMode']);
      characterRole = res['characterRole'];
      interactionId = res['interactionId'];
      knowledgeBases = res['knowledgeBases'] ?? [];
      state = CharacterState.values
          .firstWhereOrNull((value) => value.name == res['state']);

      _eventEmitter.emit("INIT_CHARACTER", this);
    }
  }

  void leave() async {
    await _removeCharacter({interactionId: interactionId});
  }

  void sendMessage({required String message}) async {
    await _sendMessage(interactionId, message);
  }

  void interrupt() async {
    await _interruptCharacter(interactionId);
  }

  @override
  void setQuality(quality) {
    throw UnsupportedError(
        "The setQuality() method is not supported for the character.");
  }

  @override
  void pin([PinType pinType = PinType.SHARE_AND_CAM]) {
    throw UnsupportedError(
        "The pin() method is not supported for the character.");
  }

  @override
  void unpin([PinType pinType = PinType.SHARE_AND_CAM]) {
    throw UnsupportedError(
        "The unpin() method is not supported for the character.");
  }

  @override
  void setViewPort(width, height) {
    throw UnsupportedError(
        "The setViewPort() method is not supported for the character.");
  }

  @override
  void remove() {
    throw UnsupportedError(
        "The remove() method is not supported for the character.");
  }

  @override
  List<dynamic>? getVideoStats() {
    throw UnsupportedError(
        "The getVideoStats() method is not supported for the character.");
  }

  @override
  List<dynamic>? getAudioStats() {
    throw UnsupportedError(
        "The getVideoStats() method is not supported for the character.");
  }

  @override
  List<dynamic>? getShareStats() {
    throw UnsupportedError(
        "The getVideoStats() method is not supported for the character.");
  }

  @override
  on(Events event, handler) {
    _characterEventEmitter.on(event.parseToString(), handler);
  }

  @override
  off(Events event, handler) {
    _characterEventEmitter.remove(event.parseToString(), handler);
  }
}
