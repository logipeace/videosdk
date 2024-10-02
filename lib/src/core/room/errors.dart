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
  3001: {
    "code": "3001",
    "name": "ERROR_CUSTOM_VIDEO_TRACK_DISPOSED",
    "message":
        "The provided custom video track has been disposed of, and is now in an ended state. Reverting to the default video track."
  },
  3002: {
    "code": "3002",
    "name": "ERROR_CUSTOM_AUDIO_TRACK_DISPOSED",
    "message":
        "The provided custom audio track has been disposed of, and is now in an ended state. Reverting to the default audio track."
  },
  3003: {
    "code": "3003",
    "name": "ERROR_CAMERA_IN_USE",
    "message":
        "The camera is being used by another application. Please close any programs utilizing the camera, such as video conferencing tools, screen recording software, or other browsers. Restart your browser and attempt again.",
  },
  3004: {
    "code": "3004",
    "name": "ERROR_MICROPHONE_IN_USE",
    "message":
        "The microphone is being used by another application. Please close any programs utilizing the microphone, such as video conferencing tools, screen recording software, or other browsers. Restart your browser and attempt again.",
  },
  3005: {
    "code": "3005",
    "name": "ERROR_CAMERA_ACCESS_UNAVAILABLE",
    "message":
        "Camera access unavailable: Please ensure your device is compatible and that you're on a secure website (https://).",
  },
  3006: {
    "code": "3006",
    "name": "ERROR_MICROPHONE_ACCESS_UNAVAILABLE",
    "message":
        "Microphone access unavailable: Please ensure your device is compatible and that you're on a secure website (https://).",
  },
  3007: {
    "code": "3007",
    "name": "ERROR_CAMERA_ACCESS_DENIED_OR_DISMISSED",
    "message":
        "Camera access was denied or dismissed. To proceed, kindly grant access manually through your device/browser settings.",
  },
  3008: {
    "code": "3008",
    "name": "ERROR_MICROPHONE_ACCESS_DENIED_OR_DISMISSED",
    "message":
        "Microphone access was denied or dismissed. To proceed, kindly grant access through your device/browser settings.",
  },
  3009: {
    "code": "3009",
    "name": "ERROR_CAMERA_PERMISSION_DENIED_BY_OS",
    "message":
        "Camera permission denied by OS system settings. Please check the system settings and grant permission for this browser.",
  },
  3010: {
    "code": "3010",
    "name": "ERROR_MICROPHONE_PERMISSION_DENIED_BY_OS",
    "message":
        "Microphone permission denied by OS system settings. Please check the system settings and grant permission for this browser.",
  },
  3011: {
    "code": "3011",
    "name": "ERROR_STARTING_VIDEO",
    "message":
        "Something went wrong, and the webCam could not be enabled. Please try again.",
  },

  3012: {
    "code": "3012",
    "name": "ERROR_STARTING_AUDIO",
    "message":
        "Something went wrong, and the microphone could not be enabled. Please try again.",
  },

  3013: {
    "code": "3013",
    "name": "ERROR_STARTING_SCREENSHARE",
    "message":
        "Something went wrong, and the screenshare could not be enabled. Please try again.",
  },
  3014: {
    "code": "3014",
    "name": "ERROR_SCREENSHARE_PERMISSION_DENIED",
    "message":
        "Screen sharing permission was denied. To enable screen sharing, please try again and grant the necessary permissions.",
  },
  3015: {
    "code": "3015",
    "name": "ERROR_SCREENSHARE_NOT_SUPPORTED",
    "message":
        "Screenshare not supported: Unable to generate a screenshare stream. Please ensure your device/browser is compatible.",
  },
  3016: {
    "code": "3016",
    "name": "ERROR_STARTING_FOREGROUND_SERVICE",
    "message":
        "An error occurred while initializing the foreground service, preventing screenshare from being enabled. Please try again."
  },
  3017: {
    "code": "3017",
    "name": "ERROR_CREATING_VIDEO_TRACK",
    "message":
        "An error occurred while creating the video track. Please try again.",
  },
  3018: {
    "code": "3018",
    "name": "ERROR_CREATING_AUDIO_TRACK",
    "message":
        "An error occurred while creating the audio track. Please try again.",
  },
  3019: {
    "code": "3019",
    "name": "ERROR_CAMERA_DEVICE_INCOMPATIBLE",
    "message":
        "Camera device cannot produce video: Unable to produce video stream. Please ensure your device is compatible."
  },
  3020: {
    "code": "3020",
    "name": "ERROR_MICROPHONE_DEVICE_INCOMPATIBLE",
    "message":
        "Microphone device cannot produce audio: Unable to produce audio stream. Please ensure your device is compatible."
  },
  3021: {
    "code": "3021",
    "name": "ERROR_CHANGING_MODE",
    "message":
        "Something went wrong, and the mode could not be changed. Please try again.",
  },
  3022: {
    "code": "3022",
    "name": "ERROR_ACTION_PERFORMED_BEFORE_MEETING_JOINED",
    "message":
        "Something went wrong. The room was in a connecting state, and during that time, an action encountered an issue. Please try again after joining a meeting.",
  },
  3023: {
    "code": "3023",
    "name": "ERROR_JOINING_MEETING",
    "message":
        "Something went wrong. The meeting could not be joined. Please try again.",
  },
};
