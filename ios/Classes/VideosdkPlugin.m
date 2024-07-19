#import "VideosdkPlugin.h"
#if __has_include(<videosdk/videosdk-Swift.h>)
#import <videosdk/videosdk-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "videosdk-Swift.h"
#endif

@implementation VideosdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftVideosdkPlugin registerWithRegistrar:registrar];
}
@end
