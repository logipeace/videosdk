import 'package:videosdk_webrtc/flutter_webrtc.dart';
import 'package:videosdk/src/core/room/room_mode.dart';

import '../../core/webrtc/webrtc_client.dart';
import 'peer_device.dart';

class Peer {
  final Consumer? audio;
  final Consumer? video;
  final Consumer? share;
  final PeerDevice? device;
  final String displayName;
  final Mode mode;
  final String id;
  final RTCVideoRenderer? audioRenderer;
  final RTCVideoRenderer? renderer;
  final RTCVideoRenderer? shareRenderer;
  final Map<String,dynamic>? metaData;

  const Peer({
    this.audio,
    this.video,
    this.share,
    this.audioRenderer,
    this.renderer,
    this.shareRenderer,
    required this.mode,
    required this.device,
    required this.displayName,
    required this.id,
    this.metaData,
  });

  Peer.fromMap(Map data)
      : id = data['id'],
        displayName = data['displayName'],
        device =
            null, // data['device'] != null ? PeerDevice.fromMap(data['device']) : null,
        mode = ModeExtension.parseToEnum(data['mode']),
        //
        audio = null,
        audioRenderer=null,
        //
        video = null,
        renderer = null,
        //
        share = null,
        shareRenderer = null,
        metaData = data['metaData'];


  List<String> get consumers => [
        if (audio != null) audio!.id,
        if (video != null) video!.id,
        if (share != null) share!.id,
      ];

  Peer copyWith({
    String? id,
    String? displayName,
    PeerDevice? device,
    //
    Consumer? audio,
    RTCVideoRenderer? audioRenderer,
    //
    Consumer? video,
    RTCVideoRenderer? renderer,
    //
    Consumer? share,
    RTCVideoRenderer? shareRenderer,
  }) {
    return Peer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      device: device ?? this.device,
      mode: mode,
      //
      audio: audio ?? this.audio,
      audioRenderer: audioRenderer ?? this.audioRenderer,
      //
      video: video ?? this.video,
      renderer: renderer ?? this.renderer,
      //
      share: share ?? this.share,
      shareRenderer: shareRenderer ?? this.shareRenderer,

      metaData: metaData
    );
  }

  Peer removeAudio({
    String? id,
    String? displayName,
    PeerDevice? device,
    //
    Consumer? audio,
    RTCVideoRenderer? audioRenderer,
    //
    Consumer? video,
    RTCVideoRenderer? renderer,
    //
    Consumer? share,
    RTCVideoRenderer? shareRenderer,
  }) {
    return Peer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      device: device ?? this.device,
      mode: mode,
      //
      audio: null,
      audioRenderer: null,
      //
      video: video ?? this.video,
      renderer: renderer ?? this.renderer,
      //
      share: share ?? this.share,
      shareRenderer: shareRenderer ?? this.shareRenderer,

      metaData: metaData,
    );
  }

  // // needs modification
  // Peer removeVideo({
  //   String? id,
  //   String? displayName,
  //   PeerDevice? device,
  //   //
  //   Consumer? audio,
  //   //
  //   Consumer? video,
  //   RTCVideoRenderer? renderer,
  //   //
  //   Consumer? share,
  //   RTCVideoRenderer? shareRenderer,
  // }) {
  //   return Peer(
  //     id: id ?? this.id,
  //     displayName: displayName ?? this.displayName,
  //     device: device ?? this.device,
  //     //
  //     audio: audio ?? this.audio,
  //     //
  //     video: null,
  //     renderer: renderer ?? this.renderer,
  //     //
  //     share: share ?? this.share,
  //     shareRenderer: shareRenderer ?? this.shareRenderer,
  //   );
  // }

  // // needs modification
  // Peer removeAudioAndRenderer({
  //   String? id,
  //   String? displayName,
  //   PeerDevice? device,
  //   //
  //   Consumer? audio,
  //   //
  //   Consumer? video,
  //   RTCVideoRenderer? renderer,
  //   //
  //   Consumer? share,
  //   RTCVideoRenderer? shareRenderer,
  // }) {
  //   return Peer(
  //     id: id ?? this.id,
  //     displayName: displayName ?? this.displayName,
  //     device: device ?? this.device,
  //     //
  //     audio: null,
  //     //
  //     video: video ?? this.video,
  //     renderer: null,
  //     //
  //     share: null,
  //     shareRenderer: null,
  //   );
  // }

  Peer removeVideoAndRenderer({
    String? id,
    String? displayName,
    PeerDevice? device,
    //
    Consumer? audio,
    RTCVideoRenderer? audioRenderer,
    //
    Consumer? video,
    RTCVideoRenderer? renderer,
    //
    Consumer? share,
    RTCVideoRenderer? shareRenderer,
  }) {
    return Peer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      device: device ?? this.device,
      mode: mode,
      //
      audio: audio ?? this.audio,
      audioRenderer: audioRenderer ?? this.audioRenderer,
      //
      video: null,
      renderer: null,
      //
      share: share ?? this.share,
      shareRenderer: shareRenderer ?? this.shareRenderer,

      metaData: metaData,
    );
  }

  Peer removeShareAndRenderer({
    String? id,
    String? displayName,
    PeerDevice? device,
    //
    Consumer? audio,
    RTCVideoRenderer? audioRenderer,
    //
    Consumer? video,
    RTCVideoRenderer? renderer,
    //
    Consumer? share,
    RTCVideoRenderer? shareRenderer,
  }) {
    return Peer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      device: device ?? this.device,
      mode: mode,
      //
      audio: audio ?? this.audio,
      audioRenderer: audioRenderer ?? this.audioRenderer,
      //
      video: video ?? this.video,
      renderer: renderer ?? this.renderer,
      //
      share: null,
      shareRenderer: null,

      metaData: metaData,
    );
  }
}
