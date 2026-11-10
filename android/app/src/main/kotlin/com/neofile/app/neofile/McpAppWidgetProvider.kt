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

class McpAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, McpAppWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(componentName)
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
        }

        private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_mcp)
                val prefs = context.getSharedPreferences("neofile_widget_prefs", Context.MODE_PRIVATE)

                val isRunning = prefs.getBoolean("mcp_running", false)
                val isPaused = prefs.getBoolean("mcp_paused", false)
                val url = prefs.getString("mcp_url", "http://127.0.0.1:8080") ?: "http://127.0.0.1:8080"

                if (isRunning) {
                    if (isPaused) {
                        views.setTextViewText(R.id.widget_mcp_status, "PAUSED")
                        views.setTextColor(R.id.widget_mcp_status, Color.parseColor("#FFA500"))
                    } else {
                        views.setTextViewText(R.id.widget_mcp_status, "RUNNING")
                        views.setTextColor(R.id.widget_mcp_status, Color.parseColor("#107C41"))
                    }
                    views.setTextViewText(R.id.widget_mcp_endpoint, url)
                    views.setTextViewText(R.id.widget_mcp_subtext, "Active • Tap to configure")
                } else {
                    views.setTextViewText(R.id.widget_mcp_status, "STOPPED")
                    views.setTextColor(R.id.widget_mcp_status, Color.parseColor("#888888"))
                    views.setTextViewText(R.id.widget_mcp_endpoint, "Server offline")
                    views.setTextViewText(R.id.widget_mcp_subtext, "AI Model Bridge & SSE")
                }

                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "OPEN_MCP_SCREEN"
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
                views.setOnClickPendingIntent(R.id.widget_mcp_root, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {}
        }
    }
}
