// Events
enum Events {
  // Room Events
  roomJoined,
  roomLeft,
  roomStateChanged,

  // Entry Events
  entryRequested,
  entryResponded,

  micRequested,
  cameraRequested,

  // Participant Events
  participantJoined,
  participantLeft,
  pinStateChanged,
  participantModeChanged,

  // Speaker Events
  speakerChanged,

  // Presenter Events
  presenterChanged,

  // Stream Events
  streamEnabled,
  streamDisabled,
  streamPaused,
  streamResumed,

  // Quality Change event
  videoQualityChanged,

  // Recording Events
  recordingStarted,
  recordingStopped,
  recordingStateChanged,

  // Live Stream Events
  liveStreamStarted,
  liveStreamStopped,
  liveStreamStateChanged,

  // HLS Events
  hlsStarted,
  hlsStopped,
  hlsStateChanged,

  transcriptionStateChanged,
  transcriptionText,

  error,

  deviceChanged,

  //Character Events 
  characterJoined,
  characterLeft,
  characterMessage,
  userMessage,
  characterStateChanged,
  
  //Whiteboard events
  whiteboardStarted,
  whiteboardStopped
  
}

Map<Events, String> eventsMap = {
  Events.roomJoined: 'meeting-joined',
  Events.roomLeft: 'meeting-left',
  Events.entryRequested: 'entry-requested',
  Events.entryResponded: 'entry-responded',
  Events.micRequested: 'mic-requested',
  Events.cameraRequested: 'webcam-requested',
  Events.participantJoined: 'participant-joined',
  Events.participantLeft: 'participant-left',
  Events.participantModeChanged: 'participant-mode-changed',
  Events.speakerChanged: 'speaker-changed',
  Events.presenterChanged: 'presenter-changed',
  Events.pinStateChanged: 'pin-state-changed',
  Events.streamEnabled: 'stream-enabled',
  Events.streamDisabled: 'stream-disabled',
  Events.streamPaused: 'stream-paused',
  Events.streamResumed: 'stream-resumed',
  Events.videoQualityChanged: 'video-quality-changed',
  Events.recordingStarted: 'recording-started',
  Events.recordingStopped: 'recording-stopped',
  Events.recordingStateChanged: 'recording-state-changed',
  Events.liveStreamStarted: 'livestream-started',
  Events.liveStreamStopped: 'livestream-stopped',
  Events.liveStreamStateChanged: 'livestream-state-changed',
  Events.hlsStarted: 'hls-started',
  Events.hlsStopped: 'hls-stopped',
  Events.hlsStateChanged: 'hls-state-changed',
  Events.transcriptionStateChanged: 'transcription-state-changed',
  Events.transcriptionText: 'transcription-text',
  Events.error: 'error',
  Events.deviceChanged: 'device-changed',
  Events.characterJoined: 'character-joined',
  Events.characterLeft: 'character-left',
  Events.characterMessage: 'character-message',
  Events.userMessage: 'user-message',
  Events.characterStateChanged: 'character-state-changed',
  Events.whiteboardStarted: 'whiteboard-started',
  Events.whiteboardStopped: 'whiteboard-stopped',
  Events.roomStateChanged: 'meeting-state-changed'
};

extension ParseToString on Events {
  String parseToString() => eventsMap[this] ?? 'unknown';
}
