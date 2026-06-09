class DeviceProfile {
  final int ramMB;
  final int cpuCores;
  final bool hasGpu;
  final String platform;

  DeviceProfile({
    required this.ramMB,
    required this.cpuCores,
    required this.hasGpu,
    required this.platform,
  });
}