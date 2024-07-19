import Cocoa
import FlutterMacOS

public class VideosdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "videosdk", binaryMessenger: registrar.messenger)
    let instance = VideosdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "getDeviceInfo":
      var deviceInfo = [String: String]()
      deviceInfo["brand"] = "MacOS"
      deviceInfo["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
      result(deviceInfo)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
