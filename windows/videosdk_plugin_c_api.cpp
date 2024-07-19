#include "include/videosdk/videosdk_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "videosdk_plugin.h"

void VideosdkPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  videosdk::VideosdkPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
