import Foundation
import videosdk_webrtc


public class VideoSDK {
    public static let getInstance: VideoSDK = {
        let instance = VideoSDK()
        return instance
    }()
    
    private let webRTCService: WebRTCService
    private var videoProcessorMap: [String: VideoProcessor]
    
    private init() {
        self.webRTCService = WebRTCService.sharedInstance()
        self.videoProcessorMap = [:]
    }
    
    public func setVideoProcessor(_ videoProcessor: VideoProcessor?) {
        self.webRTCService.videoProcessor = videoProcessor
    }
    
    public func registerVideoProcessor(videoProcessorName videoProcessorName: String, videoProcessor: VideoProcessor) {
        guard !videoProcessorName.isEmpty else { return }
        self.videoProcessorMap[videoProcessorName] = videoProcessor
    }
    
    public func getRegisteredVideoProcessors() -> [String: VideoProcessor] {
        return self.videoProcessorMap
    }
}
