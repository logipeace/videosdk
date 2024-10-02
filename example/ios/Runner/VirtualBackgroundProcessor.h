//
//  VirtualBackgroundProcessor.h
//  Runner
//
//  Created by Halima Rajwani on 12/07/24.
//

#ifndef VirtualBackgroundProcessor_h
#define VirtualBackgroundProcessor_h

#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoFrame.h>
#import <WebRTC/RTCCVPixelBuffer.h>
#import <CoreImage/CoreImage.h>
#import <Vision/Vision.h>
#import "videosdk_webrtc/VideoProcessor.h"

@interface VirtualBackgroundProcessor : VideoProcessor

@property (nonatomic, strong) NSURL *backgroundSource; // Property to store background source URL

- (instancetype)initWithBackgroundSource:(NSURL *)backgroundSource;
- (RTCVideoFrame *)onFrameReceived:(RTCVideoFrame *)frame;
- (void)changeBackground:(NSURL *)backgroundSource;

@end


#endif /* VirtualBackgroundProcessor_h */




