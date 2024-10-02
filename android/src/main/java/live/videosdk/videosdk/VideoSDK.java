package live.videosdk.videosdk;

import live.videosdk.webrtc.WebRTCService;
import live.videosdk.webrtc.VideoProcessor;
import java.util.HashMap;
import java.util.Map; // Import Map from java.util

public class VideoSDK {

    private static VideoSDK instance;
    private WebRTCService webRTCService;
    private Map<String, VideoProcessor> videoProcessorMap = new HashMap<>(); // Use Map from java.util

    // Private constructor to prevent instantiation from outside
    private VideoSDK() {
        webRTCService = WebRTCService.getInstance(); // Accessing the singleton instance of WebRTCService
    }

    // Static method to get the singleton instance
    public static synchronized VideoSDK getInstance() {
        if (instance == null) {
            instance = new VideoSDK();
        }
        return instance;
    }

    // Method to set the VideoProcessor
    public void setVideoProcessor(VideoProcessor videoProcessor) {
        webRTCService.setVideoProcessor(videoProcessor);
    }
    
    // Method to register a processor
    public void registerVideoProcessor(String videoProcessorName, VideoProcessor videoProcessor) {
        if (videoProcessorName != null && videoProcessorName != null) {
            videoProcessorMap.put(videoProcessorName, videoProcessor);
        }
    }

    // Method to get the registered processors map
    public Map<String, VideoProcessor> getRegisteredVideoProcessors() {
        return new HashMap<>(videoProcessorMap); // Return a copy of the map to prevent external modifications
    }
}
