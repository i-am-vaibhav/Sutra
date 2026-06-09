package ai.sutra.app

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "sutra/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                if (call.method == "getDeviceProfile") {

                    val activityManager =
                        getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

                    val memoryInfo = ActivityManager.MemoryInfo()
                    activityManager.getMemoryInfo(memoryInfo)

                    val totalRamMB =
                        (memoryInfo.totalMem / (1024 * 1024)).toInt()

                    val runtime = Runtime.getRuntime()
                    val cpuCores = runtime.availableProcessors()

                    val response = hashMapOf(
                        "ramMB" to totalRamMB,
                        "cpuCores" to cpuCores,
                        "hasGpu" to false,
                        "platform" to "android"
                    )

                    result.success(response)
                } else {
                    result.notImplemented()
                }
            }
    }
}