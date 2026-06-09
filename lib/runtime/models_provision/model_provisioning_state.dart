class ModelProvisioningState {
  final Map<String, double> progress;
  final Set<String> downloading;
  final Set<String> installed;

  const ModelProvisioningState({
    required this.progress,
    required this.downloading,
    required this.installed,
  });

  factory ModelProvisioningState.empty() {
    return const ModelProvisioningState(
      progress: {},
      downloading: {},
      installed: {},
    );
  }

  ModelProvisioningState copyWith({
    Map<String, double>? progress,
    Set<String>? downloading,
    Set<String>? installed,
  }) {
    return ModelProvisioningState(
      progress: progress ?? this.progress,
      downloading: downloading ?? this.downloading,
      installed: installed ?? this.installed,
    );
  }
}