package com.neofile.app.neofile

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CancelReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_CANCEL = "com.neofile.app.ACTION_CANCEL_TRANSFER"
        const val ACTION_MCP_STOP = "com.neofile.app.ACTION_MCP_STOP"
        const val ACTION_MCP_PAUSE = "com.neofile.app.ACTION_MCP_PAUSE"
        const val ACTION_MCP_RESUME = "com.neofile.app.ACTION_MCP_RESUME"
        const val ACTION_FTP_STOP = "com.neofile.app.ACTION_FTP_STOP"
        const val NOTIFICATION_ID = 1001
        const val MCP_NOTIFICATION_ID = 1002
        const val FTP_NOTIFICATION_ID = 1003

        var onCancelListener: (() -> Unit)? = null
        var onMcpStopListener: (() -> Unit)? = null
        var onMcpPauseListener: (() -> Unit)? = null
        var onMcpResumeListener: (() -> Unit)? = null
        var onFtpStopListener: (() -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            ACTION_CANCEL -> {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                notificationManager?.cancel(NOTIFICATION_ID)
                onCancelListener?.invoke()
            }
            ACTION_MCP_STOP -> {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                notificationManager?.cancel(MCP_NOTIFICATION_ID)
                onMcpStopListener?.invoke()
            }
            ACTION_MCP_PAUSE -> {
                onMcpPauseListener?.invoke()
            }
            ACTION_MCP_RESUME -> {
                onMcpResumeListener?.invoke()
            }
            ACTION_FTP_STOP -> {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                notificationManager?.cancel(FTP_NOTIFICATION_ID)
                onFtpStopListener?.invoke()
            }
        }
    }
}
