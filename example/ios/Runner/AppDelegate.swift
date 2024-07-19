import UIKit
import Flutter
import videosdk
import Foundation 

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

     if let backgroundURL = URL(string: "https://images.rawpixel.com/image_social_landscape/czNmcy1wcml2YXRlL3Jhd3BpeGVsX2ltYWdlcy93ZWJzaXRlX2NvbnRlbnQvbHIvdjU0NmJhdGNoMy1teW50LTM0LWJhZGdld2F0ZXJjb2xvcl8xLmpwZw.jpg") {
         let bgProcessor = VirtualBackgroundProcessor(backgroundSource: backgroundURL)
         let videoSDK = VideoSDK.getInstance
         videoSDK.registerVideoProcessor(videoProcessorName: "VirtualBGProcessor", videoProcessor: bgProcessor!)
     }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
 
