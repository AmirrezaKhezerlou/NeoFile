package com.neofile.app.neofile

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CancelReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_CANCEL = "com.neofile.app.ACTION_CANCEL_TRANSFER"
        const val NOTIFICATION_ID = 1001

        var onCancelListener: (() -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == ACTION_CANCEL) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(NOTIFICATION_ID)

            onCancelListener?.invoke()
        }
    }
}
