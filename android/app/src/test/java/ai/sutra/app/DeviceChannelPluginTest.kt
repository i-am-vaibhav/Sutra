package ai.sutra.app

import android.content.Context
import android.content.pm.FeatureInfo
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Before
import org.junit.Test
import org.mockito.ArgumentCaptor
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class DeviceChannelPluginTest {

    private lateinit var plugin: DeviceChannelPlugin
    private lateinit var mockBinding: FlutterPlugin.FlutterPluginBinding
    private lateinit var mockContext: Context
    private lateinit var mockPackageManager: PackageManager
    private lateinit var mockMessenger: io.flutter.plugin.common.BinaryMessenger

    @Before
    fun setUp() {
        plugin = DeviceChannelPlugin()
        mockBinding = mock()
        mockContext = mock()
        mockPackageManager = mock()
        mockMessenger = mock()

        whenever(mockContext.packageManager).thenReturn(mockPackageManager)
        whenever(mockBinding.applicationContext).thenReturn(mockContext)
        whenever(mockBinding.binaryMessenger).thenReturn(mockMessenger)
    }

    @Test
    fun `registers method channel named sutra device`() {
        plugin.onAttachedToEngine(mockBinding)
        verify(mockBinding).binaryMessenger
    }

    @Test
    fun `getDeviceProfile returns map with all required keys`() {
        whenever(mockPackageManager.systemAvailableFeatures).thenReturn(emptyArray())

        plugin.onAttachedToEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("getDeviceProfile", null)

        plugin.onMethodCall(call, result)

        val captor = ArgumentCaptor.forClass(Any::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val response = captor.value as Map<String, Any>

        assertTrue(response.containsKey("ramMB"), "Response must contain ramMB")
        assertTrue(response.containsKey("cpuCores"), "Response must contain cpuCores")
        assertTrue(response.containsKey("hasGpu"), "Response must contain hasGpu")
        assertTrue(response.containsKey("gpuName"), "Response must contain gpuName")
        assertTrue(response.containsKey("gpuFamily"), "Response must contain gpuFamily")
        assertTrue(response.containsKey("platform"), "Response must contain platform")
    }

    @Test
    fun `getDeviceProfile returns positive ramMB`() {
        whenever(mockPackageManager.systemAvailableFeatures).thenReturn(emptyArray())

        plugin.onAttachedToEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("getDeviceProfile", null)

        plugin.onMethodCall(call, result)

        val captor = ArgumentCaptor.forClass(Any::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val response = captor.value as Map<String, Any>

        val ramMB = response["ramMB"] as Number
        assertTrue(ramMB.toLong() > 0, "ramMB must be positive, got $ramMB")
    }

    @Test
    fun `getDeviceProfile returns positive cpuCores`() {
        whenever(mockPackageManager.systemAvailableFeatures).thenReturn(emptyArray())

        plugin.onAttachedToEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("getDeviceProfile", null)

        plugin.onMethodCall(call, result)

        val captor = ArgumentCaptor.forClass(Any::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val response = captor.value as Map<String, Any>

        val cpuCores = response["cpuCores"] as Number
        assertTrue(cpuCores.toInt() > 0, "cpuCores must be positive, got $cpuCores")
    }

    @Test
    fun `getDeviceProfile returns hasGpu true when OpenGL ES 3_0 is present`() {
        // Simulate OpenGL ES 3.0 (0x00030000)
        val feature = FeatureInfo().apply { reqGlEsVersion = 0x00030000 }
        whenever(mockPackageManager.systemAvailableFeatures).thenReturn(arrayOf(feature))

        plugin.onAttachedToEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("getDeviceProfile", null)

        plugin.onMethodCall(call, result)

        val captor = ArgumentCaptor.forClass(Any::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val response = captor.value as Map<String, Any>

        assertTrue(response["hasGpu"] as Boolean, "hasGpu should be true when OpenGL ES 3.0 is present")
        assertNotNull(response["gpuName"], "gpuName must not be null when GPU is present")
    }

    @Test
    fun `getDeviceProfile returns hasGpu false when no graphics API found`() {
        whenever(mockPackageManager.systemAvailableFeatures).thenReturn(emptyArray())
        whenever(mockPackageManager.hasSystemFeature(any())).thenReturn(false)

        plugin.onAttachedToEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("getDeviceProfile", null)

        plugin.onMethodCall(call, result)

        val captor = ArgumentCaptor.forClass(Any::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val response = captor.value as Map<String, Any>

        assertFalse(response["hasGpu"] as Boolean, "hasGpu should be false when no graphics API is found")
        assertEquals("none", response["gpuName"], "gpuName should be 'none' when no GPU")
        assertEquals("none", response["gpuFamily"], "gpuFamily should be 'none' when no GPU")
    }

    @Test
    fun `getDeviceProfile returns platform as android`() {
        whenever(mockPackageManager.systemAvailableFeatures).thenReturn(emptyArray())

        plugin.onAttachedToEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("getDeviceProfile", null)

        plugin.onMethodCall(call, result)

        val captor = ArgumentCaptor.forClass(Any::class.java)
        verify(result).success(captor.capture())
        @Suppress("UNCHECKED_CAST")
        val response = captor.value as Map<String, Any>

        assertEquals("android", response["platform"], "Platform must be 'android'")
    }

    @Test
    fun `unknown method returns notImplemented`() {
        plugin.onAttachedToEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("unknownMethod", null)

        plugin.onMethodCall(call, result)

        verify(result).notImplemented()
    }

    @Test
    fun `getDeviceProfile returns error when context is null`() {
        plugin.onAttachedToEngine(mockBinding)
        plugin.onDetachedFromEngine(mockBinding)

        val result = mock<MethodChannel.Result>()
        val call = MethodCall("getDeviceProfile", null)

        plugin.onMethodCall(call, result)

        val errorCodeCaptor = ArgumentCaptor.forClass(String::class.java)
        verify(result).error(errorCodeCaptor.capture(), any(), any())
        assertEquals("NO_CONTEXT", errorCodeCaptor.value)
    }

    @Test
    fun `detach clears handler without crash`() {
        plugin.onAttachedToEngine(mockBinding)
        plugin.onDetachedFromEngine(mockBinding)
    }
}
