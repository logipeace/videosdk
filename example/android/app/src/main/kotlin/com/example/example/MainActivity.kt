package com.example.example

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import com.exampleapp.BackgroundProcessor;
import live.videosdk.videosdk.VideoSDK;
import android.net.Uri

class MainActivity : FlutterActivity() {

    private lateinit var bgProcessor: BackgroundProcessor

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val backgroundImageUri = Uri.parse("https://st.depositphotos.com/2605379/52364/i/450/depositphotos_523648932-stock-photo-concrete-rooftop-night-city-view.jpg");
        val bgProcessor = BackgroundProcessor(backgroundImageUri)
        val videoSDK = VideoSDK.getInstance()
        videoSDK.registerVideoProcessor("VirtualBGProcessor" , bgProcessor)
        print("bg processor instance created")

        // Additional setup code if necessary
    }
}

