// Mode
enum Mode { CONFERENCE, VIEWER }

Map<Mode, String> modesMap = {
  Mode.CONFERENCE: 'CONFERENCE',
  Mode.VIEWER: 'VIEWER',
};

extension ModeExtension on Mode {
  String parseToString() => modesMap[this] ?? 'CONFERENCE';
  static Mode parseToEnum(String mode) => mode == "CONFERENCE"
      ? Mode.CONFERENCE
      : mode == "VIEWER"
          ? Mode.VIEWER
          : Mode.CONFERENCE;
}
