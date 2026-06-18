class ModelProvisioningState {
  final Map<String, double> progress;
  final Set<String> downloading;
  final Set<String> installed;

  /// Models whose download failed after all retries.
  final Set<String> failed;

  /// Retry attempt number per model (1-based while retrying).
  final Map<String, int> retryAttempts;

  const ModelProvisioningState({
    required this.progress,
    required this.downloading,
    required this.installed,
    required this.failed,
    required this.retryAttempts,
  });

  factory ModelProvisioningState.empty() {
    return const ModelProvisioningState(
      progress: {},
      downloading: {},
      installed: {},
      failed: {},
      retryAttempts: {},
    );
  }

  ModelProvisioningState copyWith({
    Map<String, double>? progress,
    Set<String>? downloading,
    Set<String>? installed,
    Set<String>? failed,
    Map<String, int>? retryAttempts,
  }) {
    return ModelProvisioningState(
      progress: progress ?? this.progress,
      downloading: downloading ?? this.downloading,
      installed: installed ?? this.installed,
      failed: failed ?? this.failed,
      retryAttempts: retryAttempts ?? this.retryAttempts,
    );
  }
}