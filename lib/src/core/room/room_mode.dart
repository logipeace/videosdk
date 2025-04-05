// Mode
enum Mode {
  //  @deprecated CONFERENCE mode is deprecated and will be removed in future versions. Use SEND_AND_RECV mode instead.
  @deprecated
  CONFERENCE,
  // @deprecated CONFERENCE mode is deprecated and will be removed in future versions. Use SEND_AND_RECV mode instead. */
  @deprecated
  VIEWER,

  SEND_AND_RECV,
  SIGNALLING_ONLY,
  RECV_ONLY,
}

Map<Mode, String> modesMap = {
  Mode.CONFERENCE: 'CONFERENCE',
  Mode.VIEWER: 'VIEWER',
  Mode.SEND_AND_RECV: 'SEND_AND_RECV',
  Mode.SIGNALLING_ONLY: 'SIGNALLING_ONLY',
  Mode.RECV_ONLY: 'RECV_ONLY',
};

extension ModeExtension on Mode {
  String parseToString() => modesMap[this] ?? 'SEND_AND_RECV';
  static Mode parseToEnum(String mode) {
    print("Mode : ${mode}");
    return mode == "SEND_AND_RECV"
        ? Mode.SEND_AND_RECV
        : mode == "SIGNALLING_ONLY"
            ? Mode.SIGNALLING_ONLY
            : mode == "RECV_ONLY"
                ? Mode.RECV_ONLY
                : mode == "CONFERENCE"
                    ? Mode.CONFERENCE
                    : mode == "VIEWER"
                        ? Mode.VIEWER
                        : Mode.SEND_AND_RECV;
  }
}
