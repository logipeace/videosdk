import Flutter
import UIKit
import ReplayKit
import Foundation


public class SwiftVideosdkPlugin: NSObject, FlutterPlugin {
    let videoSDK = VideoSDK.getInstance

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "videosdk", binaryMessenger: registrar.messenger())
    let instance = SwiftVideosdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)


    let eventChannel = FlutterEventChannel(name: "videosdk-event", binaryMessenger: registrar.messenger())
    let streamHandler = ScreenShareEventStreamHandler();
    eventChannel.setStreamHandler(streamHandler)    
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      if(call.method == "getPlatformVersion"){
          result("iOS " + UIDevice.current.systemVersion)
      return
          
      }else if(call.method == "getDeviceInfo") {
              var deviceInfo = [String: String]()
              deviceInfo["brand"] = "Apple"
          deviceInfo["modelName"] = UIDevice.modelName
              deviceInfo["osVersion"] = UIDevice.current.systemVersion
              result(deviceInfo)
          return
          }
          else if(call.method == "requestScreenSharePermission") {
              DispatchQueue.main.async { [self] in
            let pickerView = RPSystemBroadcastPickerView(
                frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            var tap = pickerView.subviews.first as! UIButton
            pickerView.translatesAutoresizingMaskIntoConstraints = false
            let extensionId = Bundle.main.object(forInfoDictionaryKey: "RTCScreenSharingExtension") as? String
            pickerView.preferredExtension = extensionId
            tap.sendActions(for: .touchUpInside)
            
            }
          return
          } else if(call.method == "getCpuUsage")
          {
            let cpuUsage = cpuUsage();
            return result(cpuUsage);
          } else if(call.method == "getMemoryUsage")
          {
            let memoryUsage = memoryUsage();
            return result(memoryUsage);
          }
        else if call.method == "processorMethod" {
    if let args = call.arguments as? [String: Any],
       let videoProcessorName = args["videoProcessorName"] as? String {
        
        let videoProcessorMap = videoSDK.getRegisteredVideoProcessors()
        if let bgProcessor = videoProcessorMap[videoProcessorName] {
            videoSDK.setVideoProcessor(bgProcessor)
            result("Processor has been set")
        } else {
            result(FlutterError(code: "ProcessorNotFound", message: "No processor found with the name \(videoProcessorName)", details: nil))
        }
    } else {
        videoSDK.setVideoProcessor(nil)
    }
}



  }



public typealias MemoryUsage = (used: Int64, total: Int64)

func cpuUsage() -> Double {
    var totalUsageOfCPU: Double = 0.0
    var threadsList: thread_act_array_t?
    var threadsCount = mach_msg_type_number_t(0)
    let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
        return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
            task_threads(mach_task_self_, $0, &threadsCount)
        }
    }
    
    if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
        for index in 0..<threadsCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            guard infoResult == KERN_SUCCESS else {
                break
            }
            
            let threadBasicInfo = threadInfo as thread_basic_info
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
            }
        }
    }
    
    vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
    return totalUsageOfCPU
}

func memoryUsage() -> [String: UInt64] {
    var taskInfo = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
    let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }

    var used: UInt64 = 0
    if result == KERN_SUCCESS {
        used = UInt64(taskInfo.phys_footprint)
        used = used / (1024 * 1024);
    }

    let total = ProcessInfo.processInfo.physicalMemory
    return ["used": used, "total": total]
}

}



public class ScreenShareEventStreamHandler: NSObject, FlutterStreamHandler {
    var _eventSink: FlutterEventSink?

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _eventSink = events
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let notificationStartName = "videosdk.flutter.startScreenShare"as CFString
        let notificationStopName = "videosdk.flutter.stopScreenShare"as CFString

        CFNotificationCenterAddObserver(notificationCenter,
                                        observer,
                                        { (_, observer, name, _, _) -> Void in
                                            let mySelf = Unmanaged<ScreenShareEventStreamHandler>.fromOpaque(
                    observer!).takeUnretainedValue()
                                            mySelf.sendEvent(event:"STOP_SCREENSHARE")
                                        },
                                        notificationStopName,
                                        nil,
                                        CFNotificationSuspensionBehavior.deliverImmediately)
        
        CFNotificationCenterAddObserver(notificationCenter,
                                        observer,
                                        { (_, observer, name, _, _) -> Void in
                                            let mySelf = Unmanaged<ScreenShareEventStreamHandler>.fromOpaque(
                    observer!).takeUnretainedValue()
                                            mySelf.sendEvent(event:"START_SCREENSHARE")
                                        },
                                        notificationStartName,
                                        nil,
                                        CFNotificationSuspensionBehavior.deliverImmediately)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _eventSink = nil
        return nil
    }
    // This method is called by the speech controller as mentioned above
    @objc func sendEvent(event: String) {
        _eventSink?(event)
    }
}

public extension UIDevice {

    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return identifier
    }()

}
