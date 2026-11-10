package com.neofile.app.neofile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews

class FtpAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, FtpAppWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(componentName)
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
        }

        private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_ftp)
                val prefs = context.getSharedPreferences("neofile_widget_prefs", Context.MODE_PRIVATE)

                val isRunning = prefs.getBoolean("ftp_running", false)
                val url = prefs.getString("ftp_url", "ftp://192.168.1.1:2121") ?: "ftp://192.168.1.1:2121"
                val connections = prefs.getInt("ftp_connections", 0)

                if (isRunning) {
                    views.setTextViewText(R.id.widget_ftp_status, "RUNNING")
                    views.setTextColor(R.id.widget_ftp_status, Color.parseColor("#107C41"))
                    views.setTextViewText(R.id.widget_ftp_endpoint, url)
                    views.setTextViewText(
                        R.id.widget_ftp_connections,
                        if (connections > 0) "$connections client(s) connected" else "Listening for incoming connections"
                    )
                } else {
                    views.setTextViewText(R.id.widget_ftp_status, "STOPPED")
                    views.setTextColor(R.id.widget_ftp_status, Color.parseColor("#888888"))
                    views.setTextViewText(R.id.widget_ftp_endpoint, "Server offline")
                    views.setTextViewText(R.id.widget_ftp_connections, "Wi-Fi / Hotspot File Sharing")
                }

                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "OPEN_FTP_SCREEN"
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
                views.setOnClickPendingIntent(R.id.widget_ftp_root, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {}
        }
    }
}
