<p align="center">
  <a href="https://videosdk.live">
  <img src="https://static.videosdk.live/videosdk_logo_website_black.png"/><br/>
  </a>
</p>

<!-- ![video-sdk-logo.png](https://static.videosdk.live/videosdk.live/videosdk_logo_circle_big.png) -->

<p align="center">
  <a href="https://discord.gg/kgAvyxtTxv">
    <img src="https://img.shields.io/discord/734858252939952248?logo=discord&style=flat" />
  </a>
<a href="https://pub.dev/packages/videosdk">
   <img src="https://img.shields.io/pub/likes/videosdk?label=Like&logo=Pubev&style=flat" alt="Pubev badge"/>
</a>
  <a href="https://twitter.com/intent/follow?original_referer=https%3A%2F%2Fpublish.twitter.com%2F&ref_src=twsrc%5Etfw%7Ctwcamp%5Ebuttonembed%7Ctwterm%5Efollow%7Ctwgr%5Evideo_sdk&screen_name=video_sdk">
    <img src="https://img.shields.io/twitter/follow/video_sdk?label=Twitter&logo=twitter&style=flat" />
  </a>
  <a href="http://youtube.com/videosdk?sub_confirmation=1">
    <img src="https://img.shields.io/youtube/channel/subscribers/UCuY7JzXnpp874oa7uQbUwsA?logo=Youtube&style=flat" />
  </a>
  <a href="https://github.com/videosdk-live/videosdk.live?tab=stars">
    <img src="https://img.shields.io/github/stars/videosdk-live/videosdk.live?label=Stars&logo=GitHub&style=flat" alt="GitHub badge" />
  </a>
</p>

# Video SDK Flutter

Video SDK Flutter to simply integrate Audio & Video Calling API or Live Video Streaming API to your app with just a few lines of code.

## Functionality

| Feature      | Android            | iOS                | Web                | MacOs              | Windows            |
|--------------|--------------------|--------------------|--------------------|--------------------|--------------------|
| Audio/Video  | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Recorder     | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| HLS          | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| RTMP Live    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Simulcast    | :heavy_check_mark: | :heavy_check_mark: | :hourglass:        | :heavy_check_mark: | :heavy_check_mark: |
| Screen Share | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |

## Getting Started

### Setup Guide

Add `videosdk` as a [dependency in your pubspec.yaml file](https://flutter.io/using-packages/).

## Android Setup

### Update AndroidManifest.xml file for the permissions

Ensure the following permission is present in your Android Manifest file, located in `<project root>/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

If you need to use a Bluetooth device, please add:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
```

The Flutter project template adds it, so it may already be there.

Also you will need to set your build settings to Java 8, because official WebRTC jar now uses static methods in `EglBase` interface. Just add this to your app level `build.gradle`:

```js
android {
    //...
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

> If necessary, in the same `build.gradle` you will need to increase `minSdkVersion` of `defaultConfig` up to `23` (currently default Flutter generator set it to `16`).

> If necessary, in the same `build.gradle` you will need to increase `compileSdkVersion` and `targetSdkVersion` up to `31` (currently default Flutter generator set it to `30`).

## iOS Setup

1. Add the following entry to your Info.plist file, located in `<project root>`/ios/Runner/Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) Camera Usage!</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) Microphone Usage!</string>
```

This entry allows your app to access camera and microphone.

2. Update the minimum iOS platform version to `12.0`. You can update it in the `ios/Podfile`.

```js title="Podfile"
platform: ios, "12.0";
```

## macOS Setup

These entries allows your app to access camera, microphone and open outgoing network connections.

1. Add the following entry to your `Info.plist` file, located in `<project root>`/macos/Runner/Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) Camera Usage!</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) Microphone Usage!</string>
````

2. Add the following entry to your `DebugProfile.entitlements` file, located in `<project root>`/macos/Runner/DebugProfile.entitlements:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
```

3. Add the following entry to your `Release.entitlements` file, located in `<project root>`/macos/Runner/Release.entitlements:

```xml
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
```

## Import it

Now in your Dart code, you can use:

```js
import "package:videosdk/videosdk.dart";
```
