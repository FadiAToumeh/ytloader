package com.example.youtube_downloader

import android.content.ContentValues
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.youtube_downloader/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")
                    if (filePath != null && fileName != null) {
                        try {
                            val savedPath = saveToDownloads(filePath, fileName)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "filePath and fileName required", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(filePath: String, fileName: String): String {
        val sourceFile = File(filePath)
        if (!sourceFile.exists()) {
            throw Exception("Source file not found: $filePath")
        }

        val contentResolver = applicationContext.contentResolver
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val relativePath = Environment.DIRECTORY_DOWNLOADS

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "video/mp4")
            put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
        }

        val uri = contentResolver.insert(collection, values)
            ?: throw Exception("Failed to create MediaStore entry")

        contentResolver.openOutputStream(uri)?.use { outputStream ->
            FileInputStream(sourceFile).use { inputStream ->
                inputStream.copyTo(outputStream)
            }
        } ?: throw Exception("Failed to open output stream")

        sourceFile.delete()

        return "$relativePath/$fileName"
    }
}
