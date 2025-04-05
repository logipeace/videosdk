## v2.0.0

**Release Date** : 1st March 2025

**Change Log** :

1. Enhanced Room/Meeting Connection Flow: 
  - A `RECONNECTING` state has been introduced that activates if the network connection is lost during a meeting. The SDK will automatically try to rejoin, enhancing reliability. 
  - The `FAILED`, `CLOSING`, and `CLOSED` states have been eliminated. All disconnection scenarios will now be managed by the `DISCONNECTED` state for a more streamlined experience.

## v1.3.2+1

**Release Date** : 31st March 2025

**Change Log** :

1. Updated internal dependencies.

## v1.3.1

**Release Date** : 25th February 2025

**Change Log** :

1. Updated internal dependencies.

## v1.3.0

**Release Date** : 22nd January 2025

**Change Log** :

1. Deprecated Modes: Replaced `CONFERENCE` with `SEND_AND_RECV` and `VIEWER` with `SIGNALLING_ONLY`.
2. New Mode: Added `RECV_ONLY` for live streaming, allowing participants to receive media without sending it.
3. Role Switching: Enabled seamless role switching between `SEND_AND_RECV` (host) and `RECV_ONLY` (audience) using `changeMode()` method.

## v1.2.5

**Release Date** : 18th December 2024

**Bug Fix**:

1. Fixed issues related to Flutter version 3.27.

**Change Log** :

1. Updated internal dependencies.


## v1.2.4

**Release Date** : 17th December 2024

**Change Log** :

1. Added `roomStateChanged` Event.


## v1.2.3

**Release Date** : 24th October 2024

**Change Log** :

1. Dependencies updated to latest version.

2. Provided event `onUserMessage` in `Character` class.


## v1.2.2

**Release Date** : 23rd September 2024

**Change Log** :

1. Provided methods and events for Whiteboard Management.


## v1.2.1

**Release Date** : 13th August 2024

**Change Log** :

1. Added support for CharacterSDK.


## v1.2.0+1

**Release Date** : 8th August 2024

**Change Log** :

1. Removed support for facingMode in desktop based applications.

2. Changed value of facingMode enum from `front` to `user`.


## v1.2.0

**Release Date** : 7th August 2024

**Change Log** :

1. Removed methods `getMics`, `getCameras` and `getAudioOutputDevices` of the `Room` class.

2. Changed return type of `createMicrophoneAudioTrack()` and `createCameraVideoTrack()` methods from CustomTrack to CustomTrack?.

3. Changed parameter type of `changeMic()`, `changeCam()` and `switchAudioDevice()` methods.

4. Improved error handling and emitting more precise errors on the event.

5. Changed type of post transcription config parameter in `startRecording()`, `startHls()` and `startLivesStream()` methods.

6. Changed type of transcription config parameter in `startTranscription()` method.

7. Provided debugMode parameter in `createRoom()` method for enabling users to view detailed error logs directly on the VideoSDK's dashboard and changed parameter type of facingMode.


## v1.1.13

**Release Date** : 17th July 2024

**Change Log** :

1. Added support for Custom Video Processors in iOS and Android.


## v1.1.12

**Release Date** : 31st May 2024

**Change Log** :

1. Provided getter for selected Audio Output Device as `selectedSpeakerId`.

2. Provided Built-In Receiver(Earpiece) support for iOS Devices.

3. Provided `transcription` parameter in `startLivestream()` method of the `Room` class.


**Bug Fix** :

1. Fixed bugs in getters of selected Audio Input(`selectedMicId`) and Video (`selectedCamId`) Devices.

2. Triggered the `streamdisabled` event of the participant object when a participant leaves the meeting.

3. Fixed an issue where users were unable to join meetings without media permissions.

4. Disposed media tracks for the Firefox browser in `getVideoDevices()` and `getAudioDevices()` methods.

## v1.1.11+1

**Release Date** : 21th May 2024

**Bug Fix** :

1. Changed the default value of preferredProtocol

## v1.1.11

**Release Date** : 20th May 2024

**Change Log** :

1. Provide Pre-Call Screen's features.
2. Provide `signalingBaseUrl` parameter in `createRoom()` method of VideoSDK class to enable the usage of a proxy server with the VideoSDK.
3. Provide `preferredProtocol` parameter in `createRoom()` method of VideoSDK class to select protocol for media transportion.

**Bug Fix** :

1. Fixed an issue related to switch audio device for Web.
2. Fixed an issue related to micEnabled and camEnabled getters.

## v1.1.10

**Release Date** : 6th May 2024

**Change Log** :

1. Added support for post and realtime transcription feature

**Bug Fix** :

1. Fixed an issue related to video and screenShare for firefox browser

## v1.1.9

**Release Date** : 25th Apr 2024

**Bug Fix** :

1. Fixed voice coming from earpiece issue for iOS.
2. Fixed not able to start screenShare issue for android 14

**Change Log** :

1. Upgraded internal dependencies

## v1.1.8

**Release Date** : 5th Apr 2024

**Bug Fix** :

1. Fixed Rendering issue with Windows Platform.

## v1.1.7

**Release Date** : 27th Oct 2023

**Change Log** :

1. Added metaData property associated with Participant to pass additional information.
2. Added payload feature in PubSub to pass additional payload data.
3. Added sendOnly feature to PubSub to Publish data for only Participants mentioned.

## v1.1.6

**Release Date** : 18th Sep 2023

**Bug Fix** :

1.  Fixed issues with mediaConstraints on the arm64-v8a and x86_64 architectures.[below Android version 10]

## v1.1.5

**Release Date** : 8th Aug 2023

**Change Log** :

1. Internal improvements

**Bug Fix** :

1.  Fixed issues related to audio while toggling

## v1.1.4+1

**Release Date** : 27th July 2023

**Bug Fix** :

1. Fixed audio issue with some devices

## v1.1.4

**Release Date** : 17th July 2023

**Change Log** :

1. Upgraded internal dependencies

**Bug Fix** :

1. Fixed mic state issue
2. Fixed crash issue for below Android 10
3. Fixed issue with screen share foreground service

## v1.1.3

**Release Date** : 2nd June 2023

**Bug Fix** :

1. Fixed VideoSDK Stats issues with latest chrome browser

## v1.1.2

**Release Date** : 19th May 2023

**Change Log** :

1. Added `screenShare` feature support for flutter Windows
2. Added `getScreenShareSources()` method for Desktop Apps

## v1.1.1

**Release Date** : 17th May 2023

**Change Log** :

1. Added `screenShare` feature support for flutter web & macOS
2. Added error code for screenShare permission denied error

**Bug Fix** :

1. Fixed `onPresenterChanged `event on presenter-left

## v1.1.0

**Release Date** : 25th Apr 2023

**Change Log** :

1. Added **Beta** support for Mac and Windows Platforms
2. Added **Beta** support for Flutter Web Platform

## v1.0.13+1

**Release Date** : 14th Apr 2023

**Bug Fix** :

1. Improved Audio Quality
2. Improved SDK Performance

## v1.0.13

**Release Date** : 1st Apr 2023

**Change Log** :

1. `HLS_PLAYABLE` state added in the `hlsStateChanged`.
2. `hlsUrls` getter added in the `Room`.

## v1.0.12

**Release Date** : 24rd Mar 2023

**Change Log** :

1. `pin()` added to pin a participant.
2. `unpin()` added to unpin a participant.
3. `changeMode()` allows the participant to switch mode between `CONFERENCE` and `VIEWER`.

## v1.0.11

**Release Date** : 03rd Mar 2023

**Bug Fix** :

1. Fixed room not closing if `leave()` called before meeting is joined.
2. Internal dependencies updated.

## v1.0.10

**Release Date** : 03rd Jan 2023

**Change log** :

1. Added `getVideoStats()`, `getAudioStats()` and `getShareStats()` to get the statistics for the video, audio and share stream of a participant.

## 1.0.9

- Added support for custom audio and video tracks.
- Added events for recording, live streaming and HLS status.
- Added event for participant notifying the change in video quality.
- Added `startHls()` and `stopHls()` methods.
- Updated `startRecording()` and `startLiveStream()` to accept `config` values for the feed.
- Fixed `unable to start video or mic` after turning them off.

## 1.0.8

- Added new flag `multiStream` for `createRoom()`

## 1.0.7

- Updated Gradle Version for Android

## 1.0.6

- Added ErrorEvents for Room.

- Fixed crash on `end()`, when the room is not joined yet.

## 1.0.5

- Added support for iOS ScreenSharing.

## 1.0.4

- Added support for changing audio device.

- Fixed issue: PrintDevLog issue

## 1.0.3

- Fixed issue: VideoRenderer.onFirstFrameRendered implementation.

## 1.0.2

- Fixed issue on room ends.
- Provides reason on room left.

## 1.0.1

- Fixed change webcam issue

## 1.0.0

- Renamed `Meeting` class to `Room` class.
- Changed import file `package:videosdk/rtc.dart` to `package:videosdk/videosdk.dart`
- Changed events:

  - `Events.meetingJoined` to `Events.roomJoined`
  - `Events.meetingLeft` to `Events.roomLeft`
  - `Events.webcamRequested` to `Events.cameraRequested`
    Changed properties and methods for `Room` class
  - `selectedWebcamId` to `selectedCamId`
  - `enableWebcam()` to `enableCam()`
  - `disableWebcam()` to `disableCam()`
  - `changeWebcam()` to `changeCam()`
  - `getWebcams()` to `getCameras()`
    Changed methods for `Participant` class
  - `enableMic()` to `unmuteMic()`
  - `disableMic()` to `muteMic()`
  - `enableWebcam()` to `enableCam()`
  - `disableWebcam()` to `disableCam()`

- Added `VideoSDK.createRoom()` to create VideoSDK Rooms. Use `join()` to join VideoSDK Room.
- Added `defaultCameraIndex` option to select default camera for `Room` Class.
- Added `micEnabled` property for `Room` Class.
- Added `camEnabled` property for `Room` Class.
- Added `end()` method for `Room` Class.
- Removed `MeetingBuilder` Widget.
- Fixed the issue of joining room (meeting) multiple time.
- Fixed issues related to resource consumption.

## 0.0.14

- `setViewport()` added for participant webcam streams

## 0.0.13

- Added support for region wise baseUrls
- Added support for Android 12
- Added support for custom ice-servers
- Performance improvements

## 0.0.12

- iOS mic issue resolved
- entry request event handled

## 0.0.11

- Handle Entry Request

## 0.0.10

- PubSub Message
- custom participnatId

## 0.0.9

- Android Screen Share
- Events Enums

## 0.0.8

- Added fix for Mic / Webcam enable request

## 0.0.7

- Participant can pause or resume all video, audio and shareshare streams.
- Participant can set quality of video stream of other participant.

## 0.0.6

- Participant can request to turn on any participants' webcam or mic and can turn off the same
- Participant can remove another participant from meeting.

## 0.0.5

- livestream, recording, change webcam, active speaker and presenter indication, remote share streams and example code improved

## 0.0.4

- example app, pub description added.

## 0.0.3

- Installation steps added for android in `README` file.

## 0.0.2

- Exporting Meeting, Participant, Stream classes and MeetingBuilder widget.

## 0.0.1

- videosdk rtc meeting library initial release.
