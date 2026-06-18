import Flutter
import Metal
import XCTest
@testable import Runner

class DeviceChannelPluginTests: XCTestCase {

    // ── Helpers ────────────────────────────────────────────────

    private func makePlugin() -> DeviceChannelPlugin {
        return DeviceChannelPlugin()
    }

    /// Simulate a method call by directly invoking handle(_:result:).
    private func callGetDeviceProfile(
        on plugin: DeviceChannelPlugin
    ) -> [String: Any]? {
        let call = FlutterMethodCall(
            methodName: "getDeviceProfile",
            arguments: nil
        )
        var resultValue: Any?
        let expectation = self.expectation(description: "result")

        plugin.handle(call) { result in
            resultValue = result
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        return resultValue as? [String: Any]
    }

    // ── Tests ──────────────────────────────────────────────────

    func testGetDeviceProfileReturnsAllRequiredKeys() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        XCTAssertNotNil(response, "Response must not be nil")
        XCTAssertNotNil(response?["ramMB"], "Response must contain ramMB")
        XCTAssertNotNil(response?["cpuCores"], "Response must contain cpuCores")
        XCTAssertNotNil(response?["hasGpu"], "Response must contain hasGpu")
        XCTAssertNotNil(response?["gpuName"], "Response must contain gpuName")
        XCTAssertNotNil(response?["platform"], "Response must contain platform")
    }

    func testGetDeviceProfileReturnsPositiveRamMB() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        guard let ramMB = response?["ramMB"] as? Int else {
            XCTFail("ramMB must be an Int")
            return
        }
        XCTAssertGreaterThan(ramMB, 0, "ramMB must be positive")
    }

    func testGetDeviceProfileReturnsPositiveCpuCores() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        guard let cpuCores = response?["cpuCores"] as? Int else {
            XCTFail("cpuCores must be an Int")
            return
        }
        XCTAssertGreaterThan(cpuCores, 0, "cpuCores must be positive")
    }

    func testGetDeviceProfileHasGpuMatchesMetalAvailability() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        guard let hasGpu = response?["hasGpu"] as? Bool else {
            XCTFail("hasGpu must be a Bool")
            return
        }

        let metalDevice = MTLCreateSystemDefaultDevice()
        XCTAssertEqual(
            hasGpu, metalDevice != nil,
            "hasGpu (\(hasGpu)) must match Metal availability"
        )
    }

    func testGetDeviceProfileGpuNameMatchesMetalDeviceName() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        guard let gpuName = response?["gpuName"] as? String else {
            XCTFail("gpuName must be a String")
            return
        }

        let metalDevice = MTLCreateSystemDefaultDevice()
        let expected = metalDevice?.name ?? "none"
        XCTAssertEqual(
            gpuName, expected,
            "gpuName (\(gpuName)) must match MTLDevice.name (\(expected))"
        )
    }

    func testGetDeviceProfileReturnsPlatformIos() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        XCTAssertEqual(
            response?["platform"] as? String,
            "ios",
            "Platform must be 'ios'"
        )
    }

    func testUnknownMethodReturnsNotImplemented() {
        let plugin = makePlugin()
        let call = FlutterMethodCall(
            methodName: "unknownMethod",
            arguments: nil
        )
        var resultValue: Any?
        let expectation = self.expectation(description: "result")

        plugin.handle(call) { result in
            resultValue = result
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertTrue(
            resultValue is FlutterMethodNotImplemented,
            "Unknown method should return FlutterMethodNotImplemented"
        )
    }

    func testGetDeviceProfileRamMBMatchesPhysicalMemory() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        guard let ramMB = response?["ramMB"] as? Int else {
            XCTFail("ramMB must be an Int")
            return
        }
        let physicalMemoryMB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
        XCTAssertEqual(
            ramMB, physicalMemoryMB,
            "ramMB (\(ramMB)) must match ProcessInfo physical memory (\(physicalMemoryMB))"
        )
    }

    func testGetDeviceProfileCpuCoresMatchesProcessorCount() {
        let plugin = makePlugin()
        let response = callGetDeviceProfile(on: plugin)

        guard let cpuCores = response?["cpuCores"] as? Int else {
            XCTFail("cpuCores must be an Int")
            return
        }
        XCTAssertEqual(
            cpuCores, ProcessInfo.processInfo.processorCount,
            "cpuCores (\(cpuCores)) must match ProcessInfo processorCount (\(ProcessInfo.processInfo.processorCount))"
        )
    }
}
