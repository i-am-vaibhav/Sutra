import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let channel = FlutterMethodChannel(
      name: "sutra/device",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in

      if call.method == "getDeviceProfile" {

        let processInfo = ProcessInfo.processInfo

        let ramMB = processInfo.physicalMemory / 1024 / 1024
        let cpuCores = processInfo.processorCount

        let response: [String: Any] = [
          "ramMB": ramMB,
          "cpuCores": cpuCores,
          "hasGpu": true, // Metal available on iOS (keep for now)
          "platform": "ios"
        ]

        result(response)

      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}