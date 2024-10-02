//
//  VirtualBackgroundProcessor.m
//  Runner
//
//  Created by Halima Rajwani on 12/07/24.
//

#import "VirtualBackgroundProcessor.h"

@interface VirtualBackgroundProcessor ()

@property (nonatomic, strong) CIImage *backgroundCIImage;

@end

@implementation VirtualBackgroundProcessor

- (instancetype)initWithBackgroundSource:(NSURL *)backgroundSource {
    self = [super init];
    if (self) {
        [self downloadImageFromURL:backgroundSource completion:^(CIImage *image) {
            if (image) {
                self.backgroundCIImage = image;
            } else {
                NSLog(@"Error downloading image");
            }
        }];
    }
    return self;
}

- (RTCVideoFrame *)onFrameReceived:(RTCVideoFrame *)frame {
    RTCCVPixelBuffer *buffer = (RTCCVPixelBuffer *)frame.buffer;
    CVPixelBufferRef pixelBuffer = buffer.pixelBuffer;

    if (@available(iOS 15.0, *)) {
        VNGeneratePersonSegmentationRequest *request = [[VNGeneratePersonSegmentationRequest alloc] init];
        request.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelBalanced;
        VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];

        NSError *error = nil;
        [requestHandler performRequests:@[request] error:&error];

        if (error) {
            NSLog(@"Error performing person segmentation request: %@", error);
            return nil;
        }

        request.outputPixelFormat = kCVPixelFormatType_OneComponent8;
        VNPixelBufferObservation *result = (VNPixelBufferObservation *)request.results.firstObject;
        if (!result) {
            return nil;
        }

        CVPixelBufferRef maskPixelBuffer = result.pixelBuffer;
        CVPixelBufferRef compositedPixelBuffer = [self compositeImageWithOriginalPixelBuffer:pixelBuffer maskPixelBuffer:maskPixelBuffer];

        if (compositedPixelBuffer) {
            RTCCVPixelBuffer *rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:compositedPixelBuffer];
            RTCVideoFrame *rtcVideoFrame = [[RTCVideoFrame alloc] initWithBuffer:rtcPixelBuffer rotation:frame.rotation timeStampNs:frame.timeStampNs];
            //Release resource because of memory leak.
            CVPixelBufferRelease(compositedPixelBuffer);
            return rtcVideoFrame;
        }
    }
    return nil;
}

- (void)changeBackground:(NSURL *)backgroundSource {
    [self downloadImageFromURL:backgroundSource completion:^(CIImage *image) {
        if (image) {
            self.backgroundCIImage = image;
        }
    }];
}

- (void)downloadImageFromURL:(NSURL *)url completion:(void (^)(CIImage *image))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            CIImage *ciImage = [CIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(ciImage);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    });
}

- (CVPixelBufferRef)compositeImageWithOriginalPixelBuffer:(CVPixelBufferRef)originalPixelBuffer maskPixelBuffer:(CVPixelBufferRef)maskPixelBuffer {
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:originalPixelBuffer];
    CIImage *maskCIImage = [CIImage imageWithCVPixelBuffer:maskPixelBuffer];

    CGFloat maskScaleX = ciImage.extent.size.width / maskCIImage.extent.size.width;
    CGFloat maskScaleY = ciImage.extent.size.height / maskCIImage.extent.size.height;
    CIImage *maskScaled = [maskCIImage imageByApplyingTransform:CGAffineTransformMakeScale(maskScaleX, maskScaleY)];

    if (!self.backgroundCIImage) {
        return nil;
    }

    CGFloat backgroundScaleX = ciImage.extent.size.width / self.backgroundCIImage.extent.size.width;
    CGFloat backgroundScaleY = ciImage.extent.size.height / self.backgroundCIImage.extent.size.height;
    CIImage *backgroundScaled = [self.backgroundCIImage imageByApplyingTransform:CGAffineTransformMakeScale(backgroundScaleX, backgroundScaleY)];

    CIFilter *blendFilter = [CIFilter filterWithName:@"CIBlendWithMask"];
    [blendFilter setValue:ciImage forKey:kCIInputImageKey];
    [blendFilter setValue:maskScaled forKey:kCIInputMaskImageKey];
    [blendFilter setValue:backgroundScaled forKey:kCIInputBackgroundImageKey];

    CIImage *blendedImage = blendFilter.outputImage;
    CIContext *ciContext = [CIContext context];

    CVPixelBufferRef outputPixelBuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, ciImage.extent.size.width, ciImage.extent.size.height, kCVPixelFormatType_32BGRA, NULL, &outputPixelBuffer);

    if (outputPixelBuffer) {
        [ciContext render:blendedImage toCVPixelBuffer:outputPixelBuffer];
    }

    return outputPixelBuffer;
}

@end


