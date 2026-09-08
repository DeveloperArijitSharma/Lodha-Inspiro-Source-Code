package com.example.lodha_inspiro

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "lodha_inspiro/native"
    private val notificationChannelId = "lodha_chat_messages"
    private val notificationPermissionRequestCode = 7001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(true)
                    }
                    "showChatNotification" -> {
                        val title = call.argument<String>("title") ?: "New message"
                        val body = call.argument<String>("body") ?: "You received a new message."
                        showChatNotification(title, body)
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(installApk(path))
                        }
                    }
                    "saveToDownloads" -> {
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType")
                        val bytes = call.argument<List<*>>("bytes")
                        if (fileName.isNullOrBlank() || mimeType.isNullOrBlank() || bytes == null) {
                            result.error("INVALID_ARGUMENTS", "A filename, MIME type, and bytes are required.", null)
                        } else {
                            result.success(saveToDownloads(fileName, mimeType, bytes))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequestCode
            )
        }
    }

    private fun showChatNotification(title: String, body: String) {
        createNotificationChannel()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val notification = NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(this).notify(
            (System.currentTimeMillis() % Int.MAX_VALUE).toInt(),
            notification
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                notificationChannelId,
                "Chat messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new Lodha Inspiro chat messages"
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun saveToDownloads(fileName: String, mimeType: String, bytes: List<*>): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null

        val safeName = fileName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, safeName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Lodha Inspiro")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val resolver = contentResolver
        val uri: Uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: return null

        return try {
            resolver.openOutputStream(uri)?.use { output ->
                bytes.forEach { value -> output.write((value as Number).toInt()) }
            } ?: throw IllegalStateException("Could not open Downloads output stream.")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri.toString()
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun installApk(path: String): Boolean {
        val apkFile = File(path)
        if (!apkFile.exists()) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
            return false
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile
        )

        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = uri
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return true
    }
}
