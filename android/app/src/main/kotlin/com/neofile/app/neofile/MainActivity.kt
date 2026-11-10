package com.neofile.app.neofile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val STORAGE_METHOD_CHANNEL = "com.neofile.app/storage"
    private val STORAGE_EVENT_CHANNEL = "com.neofile.app/storage_events"
    private val INTENT_EVENT_CHANNEL = "com.neofile.app/file_intent_events"
    private val NOTIFICATION_CHANNEL_ID = "neofile_transfers"
    private val NOTIFICATION_ID = 1001
    private val MCP_NOTIFICATION_CHANNEL_ID = "neofile_mcp"
    private val MCP_NOTIFICATION_ID = 1002
    private val FTP_NOTIFICATION_CHANNEL_ID = "neofile_ftp"
    private val FTP_NOTIFICATION_ID = 1003

    private var storageEventSink: EventChannel.EventSink? = null
    private var intentEventSink: EventChannel.EventSink? = null
    private var initialFilePath: String? = null

    private var mediaReceiver: BroadcastReceiver? = null
    private var storageMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        initialFilePath = extractPathFromIntent(intent)

        CancelReceiver.onCancelListener = {
            runOnUiThread {
                storageMethodChannel?.invokeMethod("cancelTransfer", null)
            }
        }

        CancelReceiver.onMcpStopListener = {
            runOnUiThread {
                storageMethodChannel?.invokeMethod("mcpStop", null)
            }
        }

        CancelReceiver.onMcpPauseListener = {
            runOnUiThread {
                storageMethodChannel?.invokeMethod("mcpPause", null)
            }
        }

        CancelReceiver.onMcpResumeListener = {
            runOnUiThread {
                storageMethodChannel?.invokeMethod("mcpResume", null)
            }
        }

        CancelReceiver.onFtpStopListener = {
            runOnUiThread {
                storageMethodChannel?.invokeMethod("ftpStop", null)
            }
        }

        val initialAction = intent.getStringExtra("action") ?: intent.action
        if (initialAction != null && (initialAction.startsWith("OPEN_") || initialAction == "SHOW_TRANSFER_SHEET")) {
            window?.decorView?.post {
                storageMethodChannel?.invokeMethod("openAction", initialAction)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "File Operations & Transfers"
            val descriptionText = "Shows real-time progress for copy, move, zip, and downloads"
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.createNotificationChannel(channel)

            val mcpChannel = NotificationChannel(MCP_NOTIFICATION_CHANNEL_ID, "MCP Server Service", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shows live status and controls for NeoFile MCP Server"
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(mcpChannel)

            val ftpChannel = NotificationChannel(FTP_NOTIFICATION_CHANNEL_ID, "FTP Server Service", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shows active FTP server connection details and disconnect control"
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(ftpChannel)
        }
    }

    private fun updateProgressNotification(title: String, message: String, progress: Int, isIndeterminate: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    return
                }
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "SHOW_TRANSFER_SHEET")
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            )

            val isDone = progress >= 100
            val iconRes = if (applicationInfo.icon != 0) applicationInfo.icon else android.R.drawable.stat_sys_download

            val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(iconRes)
                .setContentTitle(title)
                .setContentText(message)
                .setOngoing(!isDone)
                .setAutoCancel(isDone)
                .setOnlyAlertOnce(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)

            if (isIndeterminate) {
                builder.setProgress(0, 0, true)
            } else if (progress in 0..100) {
                builder.setProgress(100, progress, false)
            }

            if (!isDone) {
                val cancelIntent = Intent(this, CancelReceiver::class.java).apply {
                    action = CancelReceiver.ACTION_CANCEL
                    setPackage(packageName)
                }
                val cancelPendingIntent = PendingIntent.getBroadcast(
                    this,
                    101,
                    cancelIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                builder.addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Cancel",
                    cancelPendingIntent
                )
            }

            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, builder.build())
        } catch (_: Exception) {}
    }

    private fun cancelProgressNotification() {
        try {
            NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    private fun updateMcpNotification(title: String, message: String, isPaused: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    return
                }
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            )

            val iconRes = if (applicationInfo.icon != 0) applicationInfo.icon else android.R.drawable.stat_notify_sync

            val builder = NotificationCompat.Builder(this, MCP_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(iconRes)
                .setContentTitle(title)
                .setContentText(message)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)

            val toggleIntent = Intent(this, CancelReceiver::class.java).apply {
                action = if (isPaused) CancelReceiver.ACTION_MCP_RESUME else CancelReceiver.ACTION_MCP_PAUSE
                setPackage(packageName)
            }
            val togglePendingIntent = PendingIntent.getBroadcast(
                this,
                102,
                toggleIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            )
            builder.addAction(
                if (isPaused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause,
                if (isPaused) "Resume" else "Pause",
                togglePendingIntent
            )

            val stopIntent = Intent(this, CancelReceiver::class.java).apply {
                action = CancelReceiver.ACTION_MCP_STOP
                setPackage(packageName)
            }
            val stopPendingIntent = PendingIntent.getBroadcast(
                this,
                103,
                stopIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            )
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                stopPendingIntent
            )

            NotificationManagerCompat.from(this).notify(MCP_NOTIFICATION_ID, builder.build())
        } catch (_: Exception) {}
    }

    private fun cancelMcpNotification() {
        try {
            NotificationManagerCompat.from(this).cancel(MCP_NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    private fun updateFtpNotification(title: String, message: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    return
                }
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "OPEN_FTP_SCREEN")
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            )

            val iconRes = if (applicationInfo.icon != 0) applicationInfo.icon else android.R.drawable.stat_notify_sync

            val builder = NotificationCompat.Builder(this, FTP_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(iconRes)
                .setContentTitle(title)
                .setContentText(message)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)

            val stopIntent = Intent(this, CancelReceiver::class.java).apply {
                action = CancelReceiver.ACTION_FTP_STOP
                setPackage(packageName)
            }
            val stopPendingIntent = PendingIntent.getBroadcast(
                this,
                104,
                stopIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            )
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Disconnect",
                stopPendingIntent
            )

            NotificationManagerCompat.from(this).notify(FTP_NOTIFICATION_ID, builder.build())
        } catch (_: Exception) {}
    }

    private fun cancelFtpNotification() {
        try {
            NotificationManagerCompat.from(this).cancel(FTP_NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    private fun updateWidgetData(args: Map<*, *>?) {
        try {
            val prefs = getSharedPreferences("neofile_widget_prefs", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            if (args != null) {
                if (args.containsKey("mcp_running")) editor.putBoolean("mcp_running", args["mcp_running"] as? Boolean ?: false)
                if (args.containsKey("mcp_paused")) editor.putBoolean("mcp_paused", args["mcp_paused"] as? Boolean ?: false)
                if (args.containsKey("mcp_url")) editor.putString("mcp_url", args["mcp_url"] as? String ?: "")
                if (args.containsKey("ftp_running")) editor.putBoolean("ftp_running", args["ftp_running"] as? Boolean ?: false)
                if (args.containsKey("ftp_url")) editor.putString("ftp_url", args["ftp_url"] as? String ?: "")
                if (args.containsKey("ftp_connections")) editor.putInt("ftp_connections", args["ftp_connections"] as? Int ?: 0)
            }
            editor.apply()

            StorageAppWidgetProvider.updateAll(this)
            McpAppWidgetProvider.updateAll(this)
            FtpAppWidgetProvider.updateAll(this)
        } catch (_: Exception) {}
    }

    private fun pinWidget(widgetType: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val appWidgetManager = getSystemService(android.appwidget.AppWidgetManager::class.java)
            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                val provider = when (widgetType.lowercase()) {
                    "storage" -> android.content.ComponentName(this, StorageAppWidgetProvider::class.java)
                    "mcp" -> android.content.ComponentName(this, McpAppWidgetProvider::class.java)
                    "ftp" -> android.content.ComponentName(this, FtpAppWidgetProvider::class.java)
                    else -> null
                }
                if (provider != null) {
                    appWidgetManager.requestPinAppWidget(provider, null, null)
                    result.success(true)
                    return
                }
            }
        }
        result.success(false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val action = intent.getStringExtra("action") ?: intent.action
        if (action != null && (action.startsWith("OPEN_") || action == "SHOW_TRANSFER_SHEET")) {
            storageMethodChannel?.invokeMethod("openAction", action)
        }

        val path = extractPathFromIntent(intent)
        if (path != null) {
            intentEventSink?.success(path)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for Storage and Intent
        storageMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_METHOD_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStorageVolumes" -> {
                        val volumes = getMountedStorageVolumes()
                        result.success(volumes)
                    }
                    "getInitialIntentPath" -> {
                        val path = initialFilePath
                        initialFilePath = null // consume once
                        result.success(path)
                    }
                    "showNotification" -> {
                        val title = call.argument<String>("title") ?: "File Transfer"
                        val message = call.argument<String>("message") ?: ""
                        val progress = call.argument<Int>("progress") ?: 0
                        val isIndeterminate = call.argument<Boolean>("isIndeterminate") ?: false
                        updateProgressNotification(title, message, progress, isIndeterminate)
                        result.success(true)
                    }
                    "cancelNotification" -> {
                        cancelProgressNotification()
                        result.success(true)
                    }
                    "showMcpNotification" -> {
                        val title = call.argument<String>("title") ?: "NeoFile MCP Server"
                        val message = call.argument<String>("message") ?: "Running"
                        val isPaused = call.argument<Boolean>("isPaused") ?: false
                        updateMcpNotification(title, message, isPaused)
                        result.success(true)
                    }
                    "cancelMcpNotification" -> {
                        cancelMcpNotification()
                        result.success(true)
                    }
                    "showFtpNotification" -> {
                        val title = call.argument<String>("title") ?: "NeoFile FTP Server"
                        val message = call.argument<String>("message") ?: "Running"
                        updateFtpNotification(title, message)
                        result.success(true)
                    }
                    "cancelFtpNotification" -> {
                        cancelFtpNotification()
                        result.success(true)
                    }
                    "updateWidgetData" -> {
                        val map = call.arguments as? Map<*, *>
                        updateWidgetData(map)
                        result.success(true)
                    }
                    "pinWidget" -> {
                        val widgetType = call.argument<String>("type") ?: ""
                        pinWidget(widgetType, result)
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        val mimeType = call.argument<String>("mimeType")
                        val useChooser = call.argument<Boolean>("useChooser") ?: false
                        val success = openFileWithIntent(path, mimeType, useChooser)
                        result.success(success)
                    }
                    "openUrl" -> {
                        val url = call.argument<String>("url") ?: ""
                        try {
                            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(browserIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // EventChannel for storage mount / unmount events (OTG & SD card hotplug)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                storageEventSink = events
                registerMediaReceiver()
            }

            override fun onCancel(arguments: Any?) {
                storageEventSink = null
                unregisterMediaReceiver()
            }
        })

        // EventChannel for file open intents while app is active
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                intentEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                intentEventSink = null
            }
        })
    }

    private fun registerMediaReceiver() {
        if (mediaReceiver != null) return

        mediaReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val uri = intent.data
                val path = uri?.path ?: ""

                when (action) {
                    Intent.ACTION_MEDIA_MOUNTED -> {
                        storageEventSink?.success(mapOf("event" to "mounted", "path" to path))
                    }
                    Intent.ACTION_MEDIA_UNMOUNTED,
                    Intent.ACTION_MEDIA_EJECT,
                    Intent.ACTION_MEDIA_REMOVED,
                    Intent.ACTION_MEDIA_BAD_REMOVAL -> {
                        storageEventSink?.success(mapOf("event" to "unmounted", "path" to path))
                    }
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                        storageEventSink?.success(mapOf("event" to "usb_attached", "path" to path))
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        storageEventSink?.success(mapOf("event" to "usb_detached", "path" to path))
                    }
                }
            }
        }

        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_MEDIA_MOUNTED)
                addAction(Intent.ACTION_MEDIA_UNMOUNTED)
                addAction(Intent.ACTION_MEDIA_EJECT)
                addAction(Intent.ACTION_MEDIA_REMOVED)
                addAction(Intent.ACTION_MEDIA_BAD_REMOVAL)
                addDataScheme("file")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(mediaReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(mediaReceiver, filter)
            }
        } catch (_: Exception) {}

        try {
            val usbFilter = IntentFilter().apply {
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(mediaReceiver, usbFilter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(mediaReceiver, usbFilter)
            }
        } catch (_: Exception) {}
    }

    private fun unregisterMediaReceiver() {
        mediaReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            mediaReceiver = null
        }
    }

    private fun getMountedStorageVolumes(): List<Map<String, Any>> {
        val resultList = mutableListOf<Map<String, Any>>()
        val seenPaths = mutableSetOf<String>()

        val storageManager = getSystemService(Context.STORAGE_SERVICE) as? StorageManager
        if (storageManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val volumes = storageManager.storageVolumes
            for (volume in volumes) {
                val state = volume.state
                if (state != Environment.MEDIA_MOUNTED && state != Environment.MEDIA_MOUNTED_READ_ONLY) {
                    continue
                }

                val path = getVolumePath(volume) ?: continue
                val dir = File(path)
                if (!dir.exists() || !dir.canRead()) continue
                if (seenPaths.contains(path)) continue
                seenPaths.add(path)

                val isPrimary = volume.isPrimary
                val isRemovable = volume.isRemovable
                val description = volume.getDescription(applicationContext)

                var totalBytes: Long = 0
                var freeBytes: Long = 0
                try {
                    val stat = StatFs(path)
                    totalBytes = stat.totalBytes
                    freeBytes = stat.availableBytes
                } catch (_: Exception) {
                    totalBytes = dir.totalSpace
                    freeBytes = dir.freeSpace
                }

                val title = when {
                    isPrimary -> "Internal Storage"
                    description.contains("USB", ignoreCase = true) || description.contains("OTG", ignoreCase = true) -> description
                    isRemovable -> "External Storage ($description)"
                    else -> description
                }

                resultList.add(
                    mapOf(
                        "title" to title,
                        "path" to path,
                        "totalBytes" to totalBytes,
                        "freeBytes" to freeBytes,
                        "isRemovable" to isRemovable,
                        "isPrimary" to isPrimary
                    )
                )
            }
        }

        // Secondary fallback scanning /storage directory directly for OTG/SD mounts
        try {
            val storageDir = File("/storage")
            if (storageDir.exists() && storageDir.isDirectory) {
                val files = storageDir.listFiles()
                if (files != null) {
                    for (file in files) {
                        val path = file.absolutePath
                        if (file.isDirectory &&
                            !seenPaths.contains(path) &&
                            file.canRead() &&
                            !file.name.equals("emulated", ignoreCase = true) &&
                            !file.name.equals("self", ignoreCase = true) &&
                            !file.name.equals("knox", ignoreCase = true)
                        ) {
                            seenPaths.add(path)
                            var totalBytes: Long = 0
                            var freeBytes: Long = 0
                            try {
                                val stat = StatFs(path)
                                totalBytes = stat.totalBytes
                                freeBytes = stat.availableBytes
                            } catch (_: Exception) {
                                totalBytes = file.totalSpace
                                freeBytes = file.freeSpace
                            }

                            val isUsb = file.name.contains("usb", ignoreCase = true) || file.name.contains("otg", ignoreCase = true)
                            val title = if (isUsb) "External Storage (${file.name})" else "SD Card (${file.name})"

                            resultList.add(
                                mapOf(
                                    "title" to title,
                                    "path" to path,
                                    "totalBytes" to totalBytes,
                                    "freeBytes" to freeBytes,
                                    "isRemovable" to true,
                                    "isPrimary" to false
                                )
                            )
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        return resultList
    }

    private fun getVolumePath(volume: StorageVolume): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val dir = volume.directory
            if (dir != null) return dir.absolutePath
        }
        return try {
            val method = volume.javaClass.getMethod("getPath")
            method.invoke(volume) as? String
        } catch (_: Exception) {
            null
        }
    }

    private fun extractPathFromIntent(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        val uri: Uri = intent.data ?: return null

        // 1. file:// scheme
        if (uri.scheme.equals("file", ignoreCase = true)) {
            return uri.path
        }

        // 2. content:// scheme
        if (uri.scheme.equals("content", ignoreCase = true)) {
            val authority = uri.authority
            if (authority == "com.android.externalstorage.documents") {
                val docId = uri.lastPathSegment
                if (docId != null) {
                    val split = docId.split(":")
                    if (split.size >= 2) {
                        val type = split[0]
                        val relativePath = split[1]
                        return if ("primary".equals(type, ignoreCase = true)) {
                            "${Environment.getExternalStorageDirectory().absolutePath}/$relativePath"
                        } else {
                            "/storage/$type/$relativePath"
                        }
                    }
                }
            }

            // MediaStore query
            try {
                val projection = arrayOf(MediaStore.MediaColumns.DATA)
                val cursor = contentResolver.query(uri, projection, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val idx = it.getColumnIndex(MediaStore.MediaColumns.DATA)
                        if (idx != -1) {
                            val data = it.getString(idx)
                            if (!data.isNullOrEmpty() && File(data).exists()) {
                                return data
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        return uri.path
    }

    private fun openFileWithIntent(filePath: String, customMimeType: String?, useChooser: Boolean): Boolean {
        val file = File(filePath)
        if (!file.exists()) return false

        val ext = file.extension.lowercase()
        var mime = customMimeType
        if (mime.isNullOrEmpty() || mime == "*/*") {
            mime = getMimeTypeFromExtension(ext)
        }

        val uri: Uri = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                androidx.core.content.FileProvider.getUriForFile(
                    this,
                    "$packageName.fileProvider.com.crazecoder.openfile",
                    file
                )
            } else {
                Uri.fromFile(file)
            }
        } catch (e: Exception) {
            Uri.fromFile(file)
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addCategory(Intent.CATEGORY_DEFAULT)
        }

        return try {
            if (useChooser) {
                val chooser = Intent.createChooser(intent, "Open with").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(chooser)
            } else {
                startActivity(intent)
            }
            true
        } catch (e: Exception) {
            try {
                val broadMime = when {
                    mime.startsWith("video/") -> "video/*"
                    mime.startsWith("audio/") -> "audio/*"
                    mime.startsWith("image/") -> "image/*"
                    mime.startsWith("text/") -> "text/*"
                    else -> "*/*"
                }
                val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, broadMime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                val chooser = Intent.createChooser(fallbackIntent, "Open with").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(chooser)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun getMimeTypeFromExtension(ext: String): String {
        return when (ext) {
            // Video
            "mp4", "m4v" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "avi" -> "video/x-msvideo"
            "mov" -> "video/quicktime"
            "wmv" -> "video/x-ms-wmv"
            "flv", "f4v" -> "video/x-flv"
            "webm" -> "video/webm"
            "3gp", "3gpp" -> "video/3gpp"
            "3g2" -> "video/3gpp2"
            "ts", "mts", "m2ts" -> "video/mp2t"
            "vob" -> "video/x-ms-vob"
            "ogv" -> "video/ogg"
            "asf" -> "video/x-ms-asf"
            "mpg", "mpeg" -> "video/mpeg"

            // Audio
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "ogg", "oga" -> "audio/ogg"
            "m4a", "aac" -> "audio/aac"
            "flac" -> "audio/flac"
            "wma" -> "audio/x-ms-wma"
            "opus" -> "audio/opus"
            "amr" -> "audio/amr"
            "mid", "midi" -> "audio/midi"
            "aif", "aiff" -> "audio/x-aiff"
            "alac" -> "audio/alac"
            "mka" -> "audio/x-matroska"

            // Image
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "bmp" -> "image/bmp"
            "svg" -> "image/svg+xml"
            "heic" -> "image/heic"
            "heif" -> "image/heif"

            // Documents & Archives
            "pdf" -> "application/pdf"
            "apk" -> "application/vnd.android.package-archive"
            "zip" -> "application/zip"
            "rar" -> "application/x-rar-compressed"
            "7z" -> "application/x-7z-compressed"
            "tar" -> "application/x-tar"
            "gz" -> "application/gzip"
            "doc", "dot" -> "application/msword"
            "docx", "dotx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "xls", "xlt" -> "application/vnd.ms-excel"
            "xlsx", "xltx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            "ppt", "pot" -> "application/vnd.ms-powerpoint"
            "pptx", "potx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"

            // Text
            "txt", "log" -> "text/plain"
            "html", "htm" -> "text/html"
            "xml" -> "text/xml"
            "json" -> "application/json"
            "csv" -> "text/csv"

            else -> {
                val mapMime = android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
                mapMime ?: "*/*"
            }
        }
    }

    override fun onDestroy() {
        CancelReceiver.onCancelListener = null
        CancelReceiver.onMcpStopListener = null
        CancelReceiver.onMcpPauseListener = null
        CancelReceiver.onMcpResumeListener = null
        CancelReceiver.onFtpStopListener = null
        cancelProgressNotification()
        cancelMcpNotification()
        cancelFtpNotification()
        unregisterMediaReceiver()
        super.onDestroy()
    }
}
