Map<int, Map<String, String>> VideoSDKErrors = {
  // server errors
  4002: {
    "code": "4002",
    "name": "INVALID_TOKEN",
    "message": "'token' is empty or invalid or might have expired.",
  },

  4001: {
    "code": "4001",
    "name": "INVALID_API_KEY",
    "message":
        "'apikey' provided in the token is empty or invalid, please verify it on the dashboard.",
  },

  4003: {
    "code": "4003",
    "name": "INVALID_MEETING_ID",
    "message":
        "'meetingId' is empty or invalid, please verify it or generate new meetingId using the API.",
  },

  4004: {
    "code": "4004",
    "name": "INVALID_PARTICIPANT_ID",
    "message":
        "'participantId' is empty or invalid, it shouldn't contain any whitespaces.",
  },

  //
  4005: {
    "code": "4005",
    "name": "DUPLICATE_PARTICIPANT",
    "message":
        "Leaving meeting, since this 'participantId' joined from another device.",
  },

  4006: {
    "code": "4006",
    "name": "ACCOUNT_DEACTIVATED",
    "message":
        "It seems your account is deactivated by VideoSDK for some reason, you can reach out to us at support@videosdk.live.",
  },

  4007: {
    "code": "4007",
    "name": "ACCOUNT_DISCONTINUED",
    "message":
        "It seems your account is discontinued by VideoSDK for some reason, you can reach out to us at support@videosdk.live.",
  },

  4008: {
    "code": "4008",
    "name": "INVALID_PERMISSIONS",
    "message":
        "'permissions' provided in the token are invalid, please don't use 'allow_join' or 'allow_mod' with 'ask_join'.",
  },
  4009: {
    "code": "4009",
    "name": "MAX_PARTCIPANT_REACHED",
    "message":
        "'You have reached max partcipant limit in a meeting to increase contact at support@videosdk.live :)'",
  },
  4010: {
    "code": "4009",
    "name": "MAX_SPEAKER_REACHED",
    "message":
        "'You have reached max speaker limit in a meeting to increase contact at support@videosdk.live :)'",
  },

  //
  4011: {
    "code": "4011",
    "name": "START_RECORDING_FAILED",
    "message": "Recording start request failed due to an unknown error.",
  },
  4012: {
    "code": "4012",
    "name": "STOP_RECORDING_FAILED",
    "message": "Recording stop request failed due to an unknown error.",
  },
  4013: {
    "code": "4013",
    "name": "START_LIVESTREAM_FAILED",
    "message": "Livestream start request failed due to an unknown error.",
  },
  4014: {
    "code": "4014",
    "name": "STOP_LIVESTREAM_FAILED",
    "message": "Livestream stop request failed due to an unknown error.",
  },
  4015: {
    "code": "4015",
    "name": "INVALID_LIVESTREAM_CONFIG",
    "message": "Livestream 'outputs' configuration provided was invalid.",
  },
  4016: {
    "code": "4016",
    "name": "START_HLS_FAILED",
    "message": "HLS start request failed due to an unknown error.",
  },
  4017: {
    "code": "4017",
    "name": "STOP_HLS_FAILED",
    "message": "HLS stop request failed due to an unknown error.",
  },
  4018: {
    "code": "4018",
    "name": "PREV_RECORDING_PROCESSING",
    "message":
        "Previous recording session is being processed, please try again after few seconds!",
  },
  4019: {
    "code": "4019",
    "name": "PREV_RTMP_RECORDING_PROCESSING",
    "message":
        "Previous RTMP recording session is being processed, please try again after few seconds!",
  },
  4020: {
    "code": "4020",
    "name": "PREV_HLS_STREAMING_PROCESSING",
    "message":
        "Previous HLS streaming session is being processed, please try again after few seconds!",
  },

  4031: {
    "code": "4031",
    "name": "START_TRANSCRIPTION_FAILED",
    "message": "Transcription start request failed due to an unknown error.",
  },

  4032: {
    "code": "4032",
    "name": "STOP_TRANSCRIPTION_FAILED",
    "message": "Transcription stop request failed due to an unknown error.",
  },

  // Critical errors
  5001: {
    "code": "5001",
    "name": "RECORDING_FAILED",
    "message": "Recording stopped due to an unknown error.",
  },
  5002: {
    "code": "5002",
    "name": "LIVESTREAM_FAILED",
    "message": "Livestream stopped due to an unknown error.",
  },
  5003: {
    "code": "5003",
    "name": "HLS_FAILED",
    "message": "HLS stopped due to an unknown error.",
  },

  5007: {
    "code": "5007",
    "name": "TRANSCRIPTION_FAILED",
    "message": "Transcription stopped due to an unknown error.",
  },

  //sdkError
  3011: {
    "code": "3011",
    "name": "ERROR_STARTING_VIDEO",
    "message": "Some error occurred during starting the video",
  },

  3012: {
    "code": "3012",
    "name": "ERROR_STARTING_AUDIO",
    "message": "Some error occurred during starting the audio",
  },

  3013: {
    "code": "3013",
    "name": "ERROR_STARTING_SCREENSHARE",
    "message": "Some error occurred during starting the screen share",
  },
  3014: {
    "code": "3014",
    "name": "ERROR_GET_DISPLAY_MEDIA_PERMISSION_DENIED",
    "message": "Screen sharing permission denied",
  },
  3015: {
    "code": "3015",
    "name": "ERROR_GET_DISPLAY_MEDIA_NOT_SUPPORTED",
    "message": "Screen share feature not supported",
  },
};
