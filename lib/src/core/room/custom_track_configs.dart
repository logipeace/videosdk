enum CustomVideoTrackConfig {
  h90p_w160p,
  h180p_w320p,
  h216p_w384p,
  h360p_w640p,
  h540p_w960p,
  h720p_w1280p,
  h1080p_w1920p,
  h1440p_w2560p,
  h2160p_w3840p,
  h120p_w160p,
  h180p_w240p,
  h240p_w320p,
  h360p_w480p,
  h480p_w640p,
  h540p_w720p,
  h720p_w960p,
  h1080p_w1440p,
  h1440p_w1920p
}

enum CustomAudioTrackConfig {
  speech_low_quality,
  speech_standard,
  music_standard,
  standard_stereo,
  high_quality,
  high_quality_stereo
}

enum CustomScreenShareTrackConfig {
  h360p_30fps,
  h720p_5fps,
  h720p_15fps,
  h1080p_15fps,
  h1080p_30fps
}

Map<CustomAudioTrackConfig, Map<String, dynamic>> customAudioTrackConfigMap = {
  CustomAudioTrackConfig.speech_low_quality: {
    "sampleRate": 16000,
    "bitRate": 24,
    "sampleSize": 16,
    "stereo": false,
    "dtx": true,
    "fec": true,
    "maxPlaybackRate": 16000,
    "packetTime": 20,
    "autoGainControl": true,
    "echoCancellation": true,
    "noiseSuppression": true,
    "channelCount": 1
  },
  CustomAudioTrackConfig.speech_standard: {
    "sampleRate": 32000,
    "bitRate": 24,
    "sampleSize": 24,
    "stereo": false,
    "dtx": true,
    "fec": true,
    "maxPlaybackRate": 32000,
    "packetTime": 30,
    "autoGainControl": true,
    "echoCancellation": true,
    "noiseSuppression": true,
    "channelCount": 1
  },
  CustomAudioTrackConfig.music_standard: {
    "sampleRate": 48000,
    "bitRate": 40,
    "sampleSize": 32,
    "stereo": false,
    "dtx": false,
    "fec": true,
    "maxPlaybackRate": 48000,
    "packetTime": 40,
    "autoGainControl": false,
    "echoCancellation": false,
    "noiseSuppression": false,
    "channelCount": 1
  },
  CustomAudioTrackConfig.standard_stereo: {
    "sampleRate": 48000,
    "sampleSize": 32,
    "bitRate": 64,
    "stereo": true,
    "dtx": false,
    "fec": true,
    "maxPlaybackRate": 48000,
    "packetTime": 40,
    "autoGainControl": false,
    "echoCancellation": false,
    "noiseSuppression": false,
    "channelCount": 2
  },
  CustomAudioTrackConfig.high_quality: {
    "sampleRate": 48000,
    "sampleSize": 32,
    "bitRate": 128,
    "stereo": false,
    "dtx": false,
    "fec": true,
    "maxPlaybackRate": 48000,
    "packetTime": 60,
    "autoGainControl": false,
    "echoCancellation": false,
    "noiseSuppression": false,
    "channelCount": 1
  },
  CustomAudioTrackConfig.high_quality_stereo: {
    "sampleRate": 48000,
    "sampleSize": 32,
    "bitRate": 192,
    "stereo": true,
    "dtx": false,
    "fec": true,
    "maxPlaybackRate": 48000,
    "packetTime": 60,
    "autoGainControl": false,
    "echoCancellation": false,
    "noiseSuppression": false,
    "channelCount": 2
  }
};

Map<CustomVideoTrackConfig, Map<String, dynamic>> customVideotrackConfigMap = {
  // TODO: portrait mode
  CustomVideoTrackConfig.h90p_w160p: {
    "width": 160,
    "height": 90,
    "bitRate": 60 * 1000,
    "frameRate": 15,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h180p_w320p: {
    "width": 320,
    "height": 180,
    "bitRate": 120 * 1000,
    "frameRate": 15,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h216p_w384p: {
    "width": 384,
    "height": 216,
    "bitRate": 180 * 1000,
    "frameRate": 15,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h360p_w640p: {
    "width": 640,
    "height": 360,
    "bitRate": 300 * 1000,
    "frameRate": 20,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h540p_w960p: {
    "width": 960,
    "height": 540,
    "bitRate": 600 * 1000,
    "frameRate": 25,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h720p_w1280p: {
    "width": 1280,
    "height": 720,
    "bitRate": 2000 * 1000,
    "frameRate": 30,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h1080p_w1920p: {
    "width": 1920,
    "height": 1080,
    "bitRate": 3000 * 1000,
    "frameRate": 30,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h1440p_w2560p: {
    "width": 2560,
    "height": 1440,
    "bitRate": 5000 * 1000,
    "frameRate": 30,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h2160p_w3840p: {
    "width": 3840,
    "height": 2160,
    "bitRate": 8000 * 1000,
    "frameRate": 30,
    "aspectRatio": "oneSixNine"
  },
  CustomVideoTrackConfig.h120p_w160p: {
    "width": 160,
    "height": 120,
    "bitRate": 80 * 1000,
    "frameRate": 15,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h180p_w240p: {
    "width": 240,
    "height": 180,
    "bitRate": 100 * 1000,
    "frameRate": 15,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h240p_w320p: {
    "width": 320,
    "height": 240,
    "bitRate": 150 * 1000,
    "frameRate": 15,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h360p_w480p: {
    "width": 480,
    "height": 360,
    "bitRate": 225 * 1000,
    "frameRate": 20,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h480p_w640p: {
    "width": 640,
    "height": 480,
    "bitRate": 300 * 1000,
    "frameRate": 25,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h540p_w720p: {
    "width": 720,
    "height": 540,
    "bitRate": 450 * 1000,
    "frameRate": 30,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h720p_w960p: {
    "width": 960,
    "height": 720,
    "bitRate": 1500 * 1000,
    "frameRate": 30,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h1080p_w1440p: {
    "width": 1440,
    "height": 1080,
    "bitRate": 2500 * 1000,
    "frameRate": 30,
    "aspectRatio": "fourThree"
  },
  CustomVideoTrackConfig.h1440p_w1920p: {
    "width": 1920,
    "height": 1440,
    "bitRate": 3500 * 1000,
    "frameRate": 30,
    "aspectRatio": "fourThree"
  }
};

Map<CustomScreenShareTrackConfig, Map<String, dynamic>>
    customScreenShareTrackConfig = {
  CustomScreenShareTrackConfig.h360p_30fps: {
    "width": 640,
    "height": 360,
    "bitRate": 200 * 1000,
    "frameRate": 3
  },
  CustomScreenShareTrackConfig.h720p_5fps: {
    "width": 1280,
    "height": 720,
    "bitRate": 400 * 1000,
    "frameRate": 5
  },
  CustomScreenShareTrackConfig.h720p_15fps: {
    "width": 1280,
    "height": 720,
    "bitRate": 1000 * 1000,
    "frameRate": 15
  },
  CustomScreenShareTrackConfig.h1080p_15fps: {
    "width": 1920,
    "height": 1080,
    "bitRate": 1500 * 1000,
    "frameRate": 15
  },
  CustomScreenShareTrackConfig.h1080p_30fps: {
    "width": 1920,
    "height": 1080,
    "bitRate": 1000 * 1000,
    "frameRate": 15
  }
};
