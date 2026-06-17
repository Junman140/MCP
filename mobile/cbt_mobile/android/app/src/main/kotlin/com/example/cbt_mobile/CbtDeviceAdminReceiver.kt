package com.example.cbt_mobile

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class CbtDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        // Immediately set lock-task packages when device admin is enabled
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(context, CbtDeviceAdminReceiver::class.java)
        try {
            dpm.setLockTaskPackages(admin, arrayOf(context.packageName))
        } catch (_: SecurityException) {
            // Silently fail — the app will request lock-task at exam start
        }
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }

    override fun onLockTaskModeEntering(context: Context, intent: Intent, pkg: String) {
        super.onLockTaskModeEntering(context, intent, pkg)
    }

    override fun onLockTaskModeExiting(context: Context, intent: Intent) {
        super.onLockTaskModeExiting(context, intent)
        // Student exited lock task mode — this is a serious violation
        // The Flutter side will detect this via periodic checking
    }
}
