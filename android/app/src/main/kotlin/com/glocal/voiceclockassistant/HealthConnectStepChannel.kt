package com.glocal.voiceclockassistant

import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.launch

class HealthConnectStepChannel(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
    private val requestPermissionsLauncher: ActivityResultLauncher<Set<String>>,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val channelName = "glocal/steps/health_connect"
        private const val providerPackageName = "com.google.android.apps.healthdata"
        private val permissions = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
        )
    }

    private val methodChannel = MethodChannel(messenger, channelName)
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler(this)
    }

    fun onPermissionResult(granted: Set<String>) {
        pendingPermissionResult?.success(granted.containsAll(permissions))
        pendingPermissionResult = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "availability" -> activity.lifecycleScope.launch {
                result.success(availabilityValue())
            }
            "requestAccess" -> activity.lifecycleScope.launch {
                handleRequestAccess(result)
            }
            "readTodaySteps" -> activity.lifecycleScope.launch {
                val atMillis = call.argument<Number>("atMillis")?.toLong()
                result.success(readTodaySteps(atMillis))
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun availabilityValue(): String {
        return when (HealthConnectClient.getSdkStatus(activity, providerPackageName)) {
            HealthConnectClient.SDK_UNAVAILABLE -> "unsupported"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "unavailable"
            else -> {
                val client = healthConnectClient() ?: return "unavailable"
                val granted = client.permissionController.getGrantedPermissions()
                if (granted.containsAll(permissions)) {
                    "available"
                } else {
                    "permission_required"
                }
            }
        }
    }

    private suspend fun handleRequestAccess(result: MethodChannel.Result) {
        when (HealthConnectClient.getSdkStatus(activity, providerPackageName)) {
            HealthConnectClient.SDK_UNAVAILABLE -> {
                result.success(false)
                return
            }
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                openHealthConnectStorePage()
                result.success(false)
                return
            }
            else -> Unit
        }

        val client = healthConnectClient()
        if (client == null) {
            result.success(false)
            return
        }

        val granted = client.permissionController.getGrantedPermissions()
        if (granted.containsAll(permissions)) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "request_in_progress",
                "A Health Connect permission request is already in progress.",
                null,
            )
            return
        }

        pendingPermissionResult = result
        requestPermissionsLauncher.launch(permissions)
    }

    private suspend fun readTodaySteps(atMillis: Long?): Map<String, Any>? {
        val client = healthConnectClient() ?: return null
        val granted = client.permissionController.getGrantedPermissions()
        if (!granted.containsAll(permissions)) {
            return null
        }

        val nowInstant = Instant.ofEpochMilli(atMillis ?: System.currentTimeMillis())
        val zoneId = ZoneId.systemDefault()
        val startInstant = nowInstant
            .atZone(zoneId)
            .toLocalDate()
            .atStartOfDay(zoneId)
            .toInstant()

        val response = client.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(startInstant, nowInstant),
            ),
        )
        val stepsToday = response[StepsRecord.COUNT_TOTAL] ?: 0L
        return mapOf(
            "stepsToday" to stepsToday.toInt(),
            "capturedAtMillis" to nowInstant.toEpochMilli(),
        )
    }

    private fun healthConnectClient(): HealthConnectClient? {
        return if (HealthConnectClient.getSdkStatus(activity, providerPackageName) ==
            HealthConnectClient.SDK_AVAILABLE
        ) {
            HealthConnectClient.getOrCreate(activity)
        } else {
            null
        }
    }

    private fun openHealthConnectStorePage() {
        val uriString =
            "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
        activity.startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setPackage("com.android.vending")
                data = Uri.parse(uriString)
                putExtra("overlay", true)
                putExtra("callerId", activity.packageName)
            },
        )
    }
}

