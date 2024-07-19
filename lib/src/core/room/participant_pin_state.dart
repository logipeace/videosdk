enum PinType { SHARE_AND_CAM, CAM, SHARE }

class ParticipantPinState {
  bool cam;
  bool share;

  ParticipantPinState({this.cam = false, this.share = false});

  factory ParticipantPinState.fromJson(Map<String, dynamic> json) =>
      ParticipantPinState(
        cam: json["cam"],
        share: json["share"],
      );

  Map<String, dynamic> toJson() => {
        "cam": cam,
        "share": share,
      };
}
