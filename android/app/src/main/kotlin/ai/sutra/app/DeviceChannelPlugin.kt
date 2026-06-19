package ai.sutra.app

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Registers the `sutra/device` method channel so the Dart side can query
 * device RAM, CPU cores, GPU availability, and platform at runtime.
 *
 * This is a standalone FlutterPlugin — it does not depend on any
 * Activity lifecycle and works regardless of whether the host is
 * a FlutterActivity, FlutterFragmentActivity, or a headless engine.
 */
class DeviceChannelPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "sutra/device")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getDeviceProfile") {
            val ctx = applicationContext
            if (ctx == null) {
                result.error("NO_CONTEXT", "Application context is not available", null)
                return
            }

            val activityManager =
                ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)

            val totalRamMB = (memoryInfo.totalMem / (1024 * 1024)).toInt()
            val cpuCores = Runtime.getRuntime().availableProcessors()
            val hasGpu = detectGpu(ctx)

            val response = hashMapOf(
                "ramMB" to totalRamMB,
                "cpuCores" to cpuCores,
                "hasGpu" to hasGpu,
                "gpuName" to detectGpuName(ctx, hasGpu),
                "gpuFamily" to detectGpuFamily(ctx),
                "platform" to "android"
            )

            result.success(response)
        } else if (call.method == "getFreeDiskSpace") {
            try {
                // Use the app's own files directory to match the actual
                // partition the app writes to (handles split-storage devices).
                val ctx = applicationContext
                if (ctx == null) {
                    result.error("NO_CONTEXT", "Application context is not available", null)
                    return
                }
                val stat = StatFs(ctx.filesDir.path)
                val freeBytes = stat.blockSizeLong * stat.availableBlocksLong
                result.success(freeBytes)
            } catch (e: Exception) {
                result.error("DISK_SPACE_ERROR", e.message, null)
            }
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    // ── GPU Detection ──────────────────────────────────────────

    private fun detectGpu(context: Context): Boolean {
        return getMaxGlEsVersion(context) > 0 || hasVulkan(context)
    }

    /**
     * Return the maximum OpenGL ES version supported by the device,
     * encoded as `(major << 16) | minor` (e.g. 3.2 → 0x00030002).
     * Returns 0 if no OpenGL ES is available.
     */
    private fun getMaxGlEsVersion(context: Context): Int {
        val pm = context.packageManager
        var maxVersion = 0

        for (feature in pm.systemAvailableFeatures) {
            if (feature.name == null) {
                // A null feature name indicates an OpenGL ES version entry.
                val version = feature.reqGlEsVersion
                if (version > maxVersion) {
                    maxVersion = version
                }
            }
        }

        return maxVersion
    }

    private fun hasVulkan(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL
            )
        }
        return false
    }

    private fun detectGpuName(context: Context, hasGpu: Boolean): String {
        if (!hasGpu) return "none"
        if (hasVulkan(context)) return "Vulkan GPU"
        val version = getMaxGlEsVersion(context)
        val major = (version and -0x10000) ushr 16
        val minor = version and 0xFFFF
        return if (major > 0) "OpenGL ES $major.$minor" else "GPU"
    }

    /**
     * Map GPU capability to a performance tier.
     *
     * | Tier  | Signal                                         |
     * |-------|------------------------------------------------|
     * | high  | Vulkan hardware support                         |
     * | mid   | OpenGL ES 3.0+  (reqGlEsVersion >= 0x00030000) |
     * | low   | OpenGL ES 2.0   (baseline)                     |
     */
    private fun detectGpuFamily(context: Context): String {
        if (hasVulkan(context)) return "high"
        val version = getMaxGlEsVersion(context)
        if (version >= 0x00030000) return "mid"
        if (version > 0) return "low"
        return "none"
    }
}
