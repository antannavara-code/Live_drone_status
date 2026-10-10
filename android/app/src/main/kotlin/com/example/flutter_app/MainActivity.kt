package com.example.flutter_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (bytes != null && fileName != null) {
                    try {
                        val path = saveToDownloads(bytes, fileName, mimeType)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "bytes and fileName are required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(bytes: ByteArray, fileName: String, mimeType: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/DroneLogs")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("Failed to create MediaStore entry for $fileName")

            contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw Exception("Failed to open output stream for $fileName")

            ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }.let { update ->
                contentResolver.update(uri, update, null, null)
            }
            return uri.toString()
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "DroneLogs")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            file.writeBytes(bytes)
            return file.absolutePath
        }
    }
}
