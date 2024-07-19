#ifndef FLUTTER_PLUGIN_VIDEOSDK_PLUGIN_H_
#define FLUTTER_PLUGIN_VIDEOSDK_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace videosdk {

class VideosdkPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  VideosdkPlugin();

  virtual ~VideosdkPlugin();

  // Disallow copy and assign.
  VideosdkPlugin(const VideosdkPlugin&) = delete;
  VideosdkPlugin& operator=(const VideosdkPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace videosdk

#endif  // FLUTTER_PLUGIN_VIDEOSDK_PLUGIN_H_
