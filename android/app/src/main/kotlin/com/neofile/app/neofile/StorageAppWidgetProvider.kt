package com.neofile.app.neofile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.widget.RemoteViews
import java.util.Locale

class StorageAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, StorageAppWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(componentName)
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
        }

        private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_storage)

                val path = Environment.getExternalStorageDirectory().path
                val stat = StatFs(path)
                val blockSize = stat.blockSizeLong
                val totalBlocks = stat.blockCountLong
                val availableBlocks = stat.availableBlocksLong

                val totalBytes = totalBlocks * blockSize
                val freeBytes = availableBlocks * blockSize
                val usedBytes = if (totalBytes > freeBytes) totalBytes - freeBytes else 0L

                val usedPercent = if (totalBytes > 0) ((usedBytes * 100) / totalBytes).toInt() else 0

                val totalGb = totalBytes.toDouble() / (1024 * 1024 * 1024)
                val usedGb = usedBytes.toDouble() / (1024 * 1024 * 1024)
                val freeGb = freeBytes.toDouble() / (1024 * 1024 * 1024)

                views.setTextViewText(R.id.widget_storage_percent, "$usedPercent%")
                views.setProgressBar(R.id.widget_storage_progress, 100, usedPercent, false)
                views.setTextViewText(
                    R.id.widget_storage_used_text,
                    String.format(Locale.US, "Used: %.1f / %.1f GB", usedGb, totalGb)
                )
                views.setTextViewText(
                    R.id.widget_storage_free_text,
                    String.format(Locale.US, "Free: %.1f GB", freeGb)
                )

                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "OPEN_STORAGE_ANALYZER"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                views.setOnClickPendingIntent(R.id.widget_storage_root, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {}
        }
    }
}
