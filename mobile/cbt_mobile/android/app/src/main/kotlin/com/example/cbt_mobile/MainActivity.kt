package com.example.cbt_mobile

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "mcp.cbt/kiosk"
        private const val REQUEST_ENABLE_ADMIN = 1001
    }

    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName
    private var isKioskEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, CbtDeviceAdminReceiver::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceAdminActive" -> {
                    result.success(devicePolicyManager.isAdminActive(adminComponent))
                }
                "requestDeviceAdmin" -> {
                    if (!devicePolicyManager.isAdminActive(adminComponent)) {
                        val intent = android.content.Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                            putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                "CBT requires device admin to lock the screen and prevent cheating during exams.")
                        }
                        startActivityForResult(intent, REQUEST_ENABLE_ADMIN)
                    }
                    result.success(true)
                }
                "startLockTask" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        try {
                            startLockTask()
                            isKioskEnabled = true
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "stopLockTask" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        try {
                            stopLockTask()
                            isKioskEnabled = false
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isLockTaskActive" -> {
                    result.success(isKioskEnabled)
                }
                "keepScreenOn" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                }
                "clearScreenOn" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                }
                "setLockTaskPackages" -> {
                    if (devicePolicyManager.isAdminActive(adminComponent)) {
                        try {
                            devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf(packageName))
                            result.success(true)
                        } catch (e: SecurityException) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isScreenRecording" -> {
                    // Android 15+ (API 35) has WindowManager#addScreenRecordingCallback
                    // For older versions, we use heuristics
                    result.success(detectScreenRecording())
                }
                "getDeviceAttestInfo" -> {
                    result.success(mapOf(
                        "app_version" to packageManager.getPackageInfo(packageName, 0).versionName,
                        "app_signature" to getAppSignature(),
                        "is_debuggable" to (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0),
                        "is_emulator" to isEmulator(),
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun detectScreenRecording(): Boolean {
        // Heuristic: check if any secure flags are being bypassed
        // On some devices, we can detect via MediaProjection
        return try {
            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
            false // Stub — real detection requires Android 15+ API
        } catch (e: Exception) {
            false
        }
    }

    private fun getAppSignature(): String {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.GET_SIGNATURES)
            }
            val sig = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
            } else {
                @Suppress("DEPRECATION")
                info.signatures.firstOrNull()?.toByteArray()
            }
            sig?.let { bytes ->
                val md = java.security.MessageDigest.getInstance("SHA-256")
                md.update(bytes)
                md.digest().joinToString("") { "%02x".format(it) }
            } ?: "unknown"
        } catch (e: Exception) {
            "error"
        }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic") ||
                Build.FINGERPRINT.startsWith("unknown") ||
                Build.MODEL.contains("google_sdk") ||
                Build.MODEL.contains("Emulator") ||
                Build.MODEL.contains("Android SDK built for x86") ||
                Build.MANUFACTURER.contains("Genymotion") ||
                (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
                "google_sdk" == Build.PRODUCT)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ENABLE_ADMIN) {
            val active = devicePolicyManager.isAdminActive(adminComponent)
            // Notify Flutter via a pending result — handled by polling isDeviceAdminActive
        }
    }
}
