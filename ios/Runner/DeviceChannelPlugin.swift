import Flutter
import Metal
import UIKit

/// Registers the `sutra/device` method channel so the Dart side can query
/// device RAM, CPU cores, GPU availability, and platform at runtime.
///
/// This is a standalone FlutterPlugin — it does not depend on any
/// SceneDelegate / AppDelegate lifecycle timing and works regardless of
/// whether the app uses a UIWindowScene or the legacy AppDelegate-based
/// window setup.
class DeviceChannelPlugin: NSObject, FlutterPlugin {

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "sutra/device",
      binaryMessenger: registrar.messenger()
    )
    let instance = DeviceChannelPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getDeviceProfile" else {
      result(FlutterMethodNotImplemented)
      return
    }

    let processInfo = ProcessInfo.processInfo
    let ramMB = processInfo.physicalMemory / 1024 / 1024
    let cpuCores = processInfo.processorCount
    let device = MTLCreateSystemDefaultDevice()

    result([
      "ramMB": ramMB,
      "cpuCores": cpuCores,
      "hasGpu": device != nil,
      "gpuName": device?.name ?? "none",
      "gpuFamily": detectGpuFamily(device),
      "platform": "ios",
    ])
  }

  // MARK: - GPU Family Detection

  /// Map the highest supported `MTLGPUFamily` to a performance tier.
  ///
  /// | Tier  | Families  | Chips (examples)          |
  /// |-------|-----------|---------------------------|
  /// | high  | apple8+   | A15 / M1 and later        |
  /// | mid   | apple5-7  | A11 – A14                 |
  /// | low   | apple1-4  | A8 – A10                  |
  private func detectGpuFamily(_ device: MTLDevice?) -> String {
    guard let device else { return "none" }

    if device.supportsFamily(.apple8) { return "high" }
    if device.supportsFamily(.apple5) { return "mid" }
    if device.supportsFamily(.apple1) { return "low" }
    return "low"
  }
}
