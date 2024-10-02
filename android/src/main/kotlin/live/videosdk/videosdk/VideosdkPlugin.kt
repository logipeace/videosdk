package live.videosdk.videosdk
import live.videosdk.videosdk.VideoSDK;
import android.net.Uri;
import live.videosdk.webrtc.VideoProcessor;
import androidx.annotation.NonNull
import android.content.Context;

import java.util.HashMap
import java.util.HashSet;

import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.IOException
import android.os.Debug


import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel

/** VideosdkPlugin */
class VideosdkPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    override fun onCancel(arguments: Any?) {
        
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "videosdk")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "videosdk-event")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else if (call.method == "getDeviceInfo") {
            val deviceInfo = LinkedHashMap<String, String>()
            deviceInfo.put("brand", android.os.Build.BRAND.toString())
            deviceInfo.put("modelName", android.os.Build.MODEL.toString())
            deviceInfo.put("osVersion", android.os.Build.VERSION.RELEASE.toString())
            result.success(deviceInfo)
        } else if(call.method == "getCpuUsage"){
            val cpuUsage = getCpuProcessUsage()
            result.success(cpuUsage)
        }
        else if(call.method == "getMemoryUsage"){
            val memoryUsage = captureMemoryUsage()
            result.success(memoryUsage)
        }
        else if (call.method == "processorMethod") {
            val videoSDK = VideoSDK.getInstance()
            val bgProcessorName: String? = call.argument("videoProcessorName")
    
            if (bgProcessorName != null) {
                val videoProcessorMap: Map<String, VideoProcessor> = videoSDK.getRegisteredVideoProcessors()
                val bgProcessor = videoProcessorMap[bgProcessorName]
    
                if (bgProcessor != null) {
                    videoSDK.setVideoProcessor(bgProcessor)
                    result.success("Processor has been set")
                } else {
                    result.error("Processor not found", "No processor found with the name $bgProcessorName", null)
                }
            } else {
                videoSDK.setVideoProcessor(null)
            }
        }       
        else {
            result.notImplemented()
        }
    }


    private fun captureMemoryUsage(): Float {
        return try {
            val memoryInfo = Debug.MemoryInfo()
            Debug.getMemoryInfo(memoryInfo)
            val totalPss = memoryInfo.totalPss
            val totalPssMB = totalPss / 1024.0f
            totalPssMB
        } catch (e: Exception) {
            0f // Returning -1.0 to indicate an error occurred
        }
    }
   

    private fun getCpuProcessUsage(): Int {
        return try {
            val cores = Runtime.getRuntime().availableProcessors()
            val pid = android.os.Process.myPid()
            val process = Runtime.getRuntime().exec("top -n 1 -o PID,%CPU")
            val bufferedReader = BufferedReader(InputStreamReader(process.inputStream))
            var line: String?
            while (bufferedReader.readLine().also { line = it } != null) {
                if (line!!.contains(pid.toString())) {
                    val parts = line!!.split("\\s+".toRegex()).filter { it.isNotEmpty() }
                    val rawCpuString = parts[parts.size - 1]
                    val rawCpu = rawCpuString.toFloat() // Parse as float instead of int
                    val usage = (rawCpu / cores).toInt()
                    return usage// Convert the result back to int
                }
            }
            0
        } catch (e: IOException) {
            0
        } catch (e: NumberFormatException) {
            0
        }
    }
    
    

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }


}
