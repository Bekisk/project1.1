package com.beki.personal_finance

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.beki.personal_finance/sms_tracker"
    private val SMS_PERMISSION_REQUEST_CODE = 4401

    private var methodChannel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    // In-process broadcast receiver for incoming SMS messages
    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages != null && messages.isNotEmpty()) {
                    val fullBody = StringBuilder()
                    var sender: String? = null
                    var timestamp: Long = System.currentTimeMillis()

                    for (sms in messages) {
                        sender = sms.displayOriginatingAddress ?: sms.originatingAddress
                        fullBody.append(sms.displayMessageBody ?: sms.messageBody ?: "")
                        timestamp = sms.timestampMillis
                    }

                    val smsData = mapOf(
                        "sender" to (sender ?: "Unknown"),
                        "body" to fullBody.toString(),
                        "timestamp" to timestamp
                    )

                    // Dispatch to Flutter parser service
                    activity.runOnUiThread {
                        methodChannel?.invokeMethod("onSmsReceived", smsData)
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    val isGranted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (isGranted) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECEIVE_SMS),
                            SMS_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "registerSmsReceiver" -> {
                    try {
                        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
                        // Priority 999 to receive incoming alerts promptly
                        filter.priority = 999
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            registerReceiver(smsReceiver, filter, Context.RECEIVER_EXPORTED)
                        } else {
                            registerReceiver(smsReceiver, filter)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "unregisterSmsReceiver" -> {
                    try {
                        unregisterReceiver(smsReceiver)
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(smsReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
