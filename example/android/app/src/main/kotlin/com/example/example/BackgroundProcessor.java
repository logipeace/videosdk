
package com.exampleapp;

import live.videosdk.webrtc.VideoProcessor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import java.nio.Buffer;
import java.nio.ByteBuffer;
import android.net.Uri;
import android.os.AsyncTask;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import androidx.annotation.ColorInt;
import android.graphics.Color;
import org.webrtc.VideoFrame;

import android.graphics.Canvas;

import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.segmentation.Segmentation;
import com.google.mlkit.vision.segmentation.Segmenter;
import com.google.mlkit.vision.segmentation.SegmentationMask;
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions;
import android.opengl.GLES20;
import android.opengl.GLUtils;
import live.videosdk.webrtc.utils.EglUtils;
import org.webrtc.SurfaceTextureHelper;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URISyntaxException;
import android.graphics.Matrix;
import android.graphics.YuvImage;
import java.io.ByteArrayOutputStream;
import android.graphics.Rect;
import android.graphics.ImageFormat;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import org.webrtc.EglBase;

import org.webrtc.YuvConverter;
import org.webrtc.TextureBufferImpl;

public class BackgroundProcessor implements VideoProcessor {
    private Bitmap backgroundBitmap;
    private final EglBase base = EglBase.create();
    private EglBase.Context context;
    private SurfaceTextureHelper surfaceTextureHelper;
    private Segmenter segmenter;

    public BackgroundProcessor(Uri backgroundSource) {
        new DownloadImageTask().execute(backgroundSource.toString());
        context = base.getEglBaseContext();
        String threadName = Thread.currentThread().getName() + "_texture_camera_thread";
        surfaceTextureHelper = SurfaceTextureHelper.create(threadName, EglUtils.getRootEglBaseContext());
        SelfieSegmenterOptions options = new SelfieSegmenterOptions.Builder()
                .setDetectorMode(SelfieSegmenterOptions.STREAM_MODE)
                // .enableRawSizeMask()
                .build();
        segmenter = Segmentation.getClient(options);
    }

    @Override
    public VideoFrame onFrameReceived(VideoFrame videoFrame) {
        if (videoFrame != null) {
            VideoFrame.I420Buffer i420Buffer = videoFrame.getBuffer().toI420();
            final int width = i420Buffer.getWidth();
            final int height = i420Buffer.getHeight();
            // convert to nv21
            byte[] nv21Data = createNV21Data(i420Buffer);

            // converting the NV21 data to jpg
            YuvImage yuvImage = new YuvImage(nv21Data, ImageFormat.NV21, width, height, null);

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            yuvImage.compressToJpeg(new Rect(0, 0, width, height), 100, out);
            byte[] imageBytes = out.toByteArray();

            Bitmap inputBitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);

            // Use CompletableFuture to handle the asynchronous processing
            CompletableFuture<VideoFrame> futureBitmap = new CompletableFuture<>();
            applyVirtualBackgroundAsync(inputBitmap, new OnBackgroundAppliedListener() {
                @Override
                public void onBackgroundApplied(Bitmap processedBitmap) {
                    if (processedBitmap != null) {
                        YuvConverter yuvConverter = new YuvConverter();

                        int[] textures = new int[1];

                        TextureBufferImpl outputBuffer = new TextureBufferImpl(processedBitmap.getWidth(),
                                processedBitmap.getHeight(), VideoFrame.TextureBuffer.Type.RGB, textures[0],
                                new Matrix(),
                                surfaceTextureHelper.getHandler(), yuvConverter, null);

                        surfaceTextureHelper.getHandler().post(new Runnable() {
                            @Override
                            public void run() {
                                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER,
                                        GLES20.GL_NEAREST);
                                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER,
                                        GLES20.GL_NEAREST);
                                GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, processedBitmap, 0);
                                VideoFrame.I420Buffer i420Buf = yuvConverter.convert(outputBuffer);
                                VideoFrame outputVideoFrame = new VideoFrame(i420Buf, videoFrame.getRotation(),
                                        videoFrame.getTimestampNs());
                                futureBitmap.complete(outputVideoFrame);
                            }
                        });
                    } else{
                        futureBitmap.complete(null);
                    }

                }
            });

            try {
                // Block and wait for the future to complete
                VideoFrame processedBitmap = futureBitmap.get();
                return processedBitmap;

            } catch (InterruptedException | ExecutionException e) {
                Log.e("BackgroundProcessor", "Error waiting for background processing", e);
            }
        }
        return null;
    }

    private class DownloadImageTask extends AsyncTask<String, Void, Bitmap> {
        @Override
        protected Bitmap doInBackground(String... urls) {
            String url = urls[0];
            Bitmap bitmap = null;
            try {
                InputStream inputStream = new URI(url).toURL().openStream();
                bitmap = BitmapFactory.decodeStream(inputStream);
            } catch (IOException | URISyntaxException e) {
                Log.e("BackgroundProcessor", "Error downloading image", e);
            }
            return bitmap;
        }

        @Override
        protected void onPostExecute(Bitmap result) {
            backgroundBitmap = result;
        }
    }

    private byte[] createNV21Data(VideoFrame.I420Buffer i420Buffer) {
        final int width = i420Buffer.getWidth();
        final int height = i420Buffer.getHeight();
        final int chromaStride = width;
        final int chromaWidth = (width + 1) / 2;
        final int chromaHeight = (height + 1) / 2;
        final int ySize = width * height;
        final ByteBuffer nv21Buffer = ByteBuffer.allocateDirect(ySize + chromaStride * chromaHeight);
        @SuppressWarnings("ByteBufferBackingArray")
        final byte[] nv21Data = nv21Buffer.array();
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                final byte yValue = i420Buffer.getDataY().get(y * i420Buffer.getStrideY() + x);
                nv21Data[y * width + x] = yValue;
            }
        }
        for (int y = 0; y < chromaHeight; ++y) {
            for (int x = 0; x < chromaWidth; ++x) {
                final byte uValue = i420Buffer.getDataU().get(y * i420Buffer.getStrideU() + x);
                final byte vValue = i420Buffer.getDataV().get(y * i420Buffer.getStrideV() + x);
                nv21Data[ySize + y * chromaStride + 2 * x + 0] = vValue;
                nv21Data[ySize + y * chromaStride + 2 * x + 1] = uValue;
            }
        }
        return nv21Data;
    }

    private int[] maskColorsFromByteBuffer(ByteBuffer byteBuffer, int maskWidth, int maskHeight) {
        int[] colors = new int[maskWidth * maskHeight];
        for (int i = 0; i < maskWidth * maskHeight; i++) {
            float foregroundLikelihood = byteBuffer.getFloat();
            int alpha = (int) (foregroundLikelihood * 255);
            colors[i] = Color.argb(alpha, 255, 255, 255); // White color with varying alpha
        }
        return colors;
    }

    private void applyVirtualBackgroundAsync(Bitmap videoFrameBitmap, OnBackgroundAppliedListener listener) {
        if (backgroundBitmap != null && videoFrameBitmap != null) {
            // Scale backgroundBitmap to match videoFrame dimensions if necessary
            Bitmap scaledBackground = Bitmap.createScaledBitmap(backgroundBitmap,
                    videoFrameBitmap.getWidth(),
                    videoFrameBitmap.getHeight(), false);

            InputImage image = InputImage.fromBitmap(videoFrameBitmap, 0);

            segmenter.process(image)
                    .addOnSuccessListener(new OnSuccessListener<SegmentationMask>() {
                        @Override
                        public void onSuccess(SegmentationMask segmentationMask) {
                            // Create resultBitmap with ARGB_8888 configuration
                            Bitmap resultBitmap = Bitmap.createBitmap(videoFrameBitmap.getWidth(),
                                    videoFrameBitmap.getHeight(), Bitmap.Config.ARGB_8888);
                            Canvas canvas = new Canvas(resultBitmap);

                            // Draw scaledBackground as the background
                            canvas.drawBitmap(scaledBackground, 0, 0, null);

                            // Prepare to apply the mask
                            ByteBuffer mask = segmentationMask.getBuffer();
                            int maskWidth = segmentationMask.getWidth();
                            int maskHeight = segmentationMask.getHeight();
                            mask.rewind();
                            int[] arr = maskColorsFromByteBuffer(mask, maskWidth, maskHeight);

                            Bitmap maskBitmap = Bitmap.createBitmap(arr, maskWidth, maskHeight,
                                    Bitmap.Config.ARGB_8888);

                            // Apply mask to the videoFrameBitmap
                            Paint paint = new Paint();
                            Bitmap maskedBitmap = Bitmap.createBitmap(videoFrameBitmap.getWidth(),
                                    videoFrameBitmap.getHeight(), Bitmap.Config.ARGB_8888);
                            Canvas maskedCanvas = new Canvas(maskedBitmap);
                            maskedCanvas.drawBitmap(videoFrameBitmap, 0, 0, null);
                            paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.DST_IN));
                            maskedCanvas.drawBitmap(maskBitmap, 0, 0, paint);
                            paint.setXfermode(null);

                            // Draw the masked video frame on the result canvas
                            canvas.drawBitmap(maskedBitmap, 0, 0, null);

                            // Notify listener with the resultBitmap
                            listener.onBackgroundApplied(resultBitmap);

                            // Recycle bitmaps to free up memory
                            maskBitmap.recycle();
                            maskedBitmap.recycle();
                            scaledBackground.recycle();
                        }
                    })
                    .addOnFailureListener(new OnFailureListener() {
                        @Override
                        public void onFailure(Exception e) {
                            Log.e("BackgroundProcessor", "Error applying effect to video frame", e);
                            listener.onBackgroundApplied(null);
                        }
                    });
        } else {
            listener.onBackgroundApplied(null);
        }
    }

    public interface OnBackgroundAppliedListener {
        void onBackgroundApplied(Bitmap resultBitmap);
    }
}