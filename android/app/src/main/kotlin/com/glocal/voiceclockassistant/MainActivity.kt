package com.glocal.voiceclockassistant

import android.os.Bundle
import androidx.health.connect.client.PermissionController
import androidx.core.view.WindowCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private lateinit var healthConnectStepChannel: HealthConnectStepChannel

    private val healthPermissionLauncher =
        registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { granted: Set<String> ->
            if (::healthConnectStepChannel.isInitialized) {
                healthConnectStepChannel.onPermissionResult(granted)
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        healthConnectStepChannel = HealthConnectStepChannel(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            requestPermissionsLauncher = healthPermissionLauncher,
        )
    }
}


