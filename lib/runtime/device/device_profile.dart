class DeviceProfile {
  final int ramMB;
  final int cpuCores;
  final bool hasGpu;
  final String gpuName;
  final String gpuFamily;
  final String platform;
  final int? batteryPercent;
  final double? temperatureC;

  DeviceProfile({
    required this.ramMB,
    required this.cpuCores,
    required this.hasGpu,
    required this.gpuName,
    required this.gpuFamily,
    required this.platform,
    this.batteryPercent,
    this.temperatureC,
  });
}
